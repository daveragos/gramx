import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// State of the authentication flow.
enum AuthStep {
  loading,
  loginMethodSelection, // Phone vs QR selection
  waitPhoneNumber,
  waitCode,
  waitPassword,
  waitQrCode,
  authenticated,
  error,
}

class AuthState {
  final AuthStep step;
  final String? phoneNumber;
  final String? qrCodeLink;
  final String? errorMessage;
  final bool isSubmitting;

  AuthState({
    required this.step,
    this.phoneNumber,
    this.qrCodeLink,
    this.errorMessage,
    this.isSubmitting = false,
  });

  AuthState copyWith({
    AuthStep? step,
    String? phoneNumber,
    String? qrCodeLink,
    String? errorMessage,
    bool? isSubmitting,
  }) {
    return AuthState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      qrCodeLink: qrCodeLink ?? this.qrCodeLink,
      errorMessage: errorMessage ?? this.errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Provides the current raw TDLib AuthorizationState stream.
final telegramAuthStateProvider = StreamProvider<td.AuthorizationState>((ref) {
  final tdlib = ref.watch(tdlibServiceProvider);
  return tdlib.authStateStream;
});

class AuthController extends Notifier<AuthState> {
  late final TdlibService _tdlib;
  StreamSubscription? _authSub;

  @override
  AuthState build() {
    _tdlib = ref.watch(tdlibServiceProvider);
    
    // Automatically listen to auth updates
    _authSub = _tdlib.authStateStream.listen((tdState) {
      _mapTdlibStateToStep(tdState);
    });
    
    ref.onDispose(() {
      _authSub?.cancel();
    });

    final lastState = _tdlib.currentAuthState;
    if (lastState != null) {
      if (lastState is td.AuthorizationStateWaitPhoneNumber) {
        return AuthState(step: AuthStep.loginMethodSelection);
      } else if (lastState is td.AuthorizationStateWaitCode) {
        return AuthState(step: AuthStep.waitCode);
      } else if (lastState is td.AuthorizationStateWaitPassword) {
        return AuthState(step: AuthStep.waitPassword);
      } else if (lastState is td.AuthorizationStateWaitOtherDeviceConfirmation) {
        return AuthState(
          step: AuthStep.waitQrCode,
          qrCodeLink: lastState.link,
        );
      } else if (lastState is td.AuthorizationStateReady) {
        Future.microtask(() => _handleAuthReady());
        return AuthState(step: AuthStep.loading);
      }
    }
    return AuthState(step: AuthStep.loading);
  }

  void _mapTdlibStateToStep(td.AuthorizationState tdState) {
    debugPrint('[AuthCtrl] Mapping TDLib State: ${tdState.runtimeType}');
    if (tdState is td.AuthorizationStateWaitPhoneNumber) {
      if (state.step == AuthStep.loading) {
        state = AuthState(step: AuthStep.loginMethodSelection);
      } else if (state.step != AuthStep.loginMethodSelection && state.step != AuthStep.waitPhoneNumber) {
        state = state.copyWith(step: AuthStep.waitPhoneNumber);
      }
    } else if (tdState is td.AuthorizationStateWaitCode) {
      state = state.copyWith(step: AuthStep.waitCode, isSubmitting: false);
    } else if (tdState is td.AuthorizationStateWaitPassword) {
      state = state.copyWith(step: AuthStep.waitPassword, isSubmitting: false);
    } else if (tdState is td.AuthorizationStateWaitOtherDeviceConfirmation) {
      state = state.copyWith(
        step: AuthStep.waitQrCode,
        qrCodeLink: tdState.link,
        isSubmitting: false,
      );
    } else if (tdState is td.AuthorizationStateReady) {
      _handleAuthReady();
    }
  }

  Future<void> _handleAuthReady() async {
    state = state.copyWith(step: AuthStep.loading);
    try {
      final me = await _tdlib.sendRequest(const td.GetMe());
      if (me is td.User) {
        final db = ref.read(databaseProvider);
        
        // Deactivate all accounts first
        await db.customStatement('UPDATE accounts SET is_active = 0');
        
        final String? username = (me.usernames?.activeUsernames != null && me.usernames!.activeUsernames.isNotEmpty)
            ? me.usernames!.activeUsernames.first
            : me.usernames?.editableUsername;
        
        final existingAccount = await (db.select(db.accounts)..where((a) => a.telegramUserId.equals(me.id.toString()))).getSingleOrNull();
        if (existingAccount != null) {
          // Update existing account
          await (db.update(db.accounts)..where((a) => a.id.equals(existingAccount.id))).write(
            AccountsCompanion(
              displayName: Value('${me.firstName} ${me.lastName}'.trim()),
              username: Value(username),
              phoneNumber: Value(me.phoneNumber),
              avatarPath: Value(me.profilePhoto?.small.local.path.isNotEmpty == true ? me.profilePhoto?.small.local.path : null),
              isActive: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
        } else {
          // Insert new account
          await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              telegramUserId: me.id.toString(),
              displayName: Value('${me.firstName} ${me.lastName}'.trim()),
              username: Value(username),
              phoneNumber: Value(me.phoneNumber),
              avatarPath: Value(me.profilePhoto?.small.local.path.isNotEmpty == true ? me.profilePhoto?.small.local.path : null),
              isActive: const Value(true),
            ),
          );
        }
        
        // Start full sync in background
        final syncService = ref.read(syncServiceProvider);
        await syncService.syncSubscribedChannels();
        await syncService.syncFeedHistory();
      }
      state = state.copyWith(step: AuthStep.authenticated);
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: 'Failed to retrieve profile: $e',
      );
    }
  }

  /// Start Phone Number login flow
  Future<void> submitPhoneNumber(String phone) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final request = td.SetAuthenticationPhoneNumber(
        phoneNumber: phone,
        settings: td.PhoneNumberAuthenticationSettings(
          allowFlashCall: false,
          allowMissedCall: false,
          isCurrentPhoneNumber: false,
          allowSmsRetrieverApi: false,
          hasUnknownPhoneNumber: false,
          authenticationTokens: [],
        ),
      );
      // Await directly via TDLib service
      await _tdlib.sendRequest(request);
      state = state.copyWith(phoneNumber: phone, isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false, 
        errorMessage: 'Failed to submit phone number: $e',
      );
    }
  }

  /// Start QR Code login flow
  Future<void> requestQrLogin() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final request = td.RequestQrCodeAuthentication(otherUserIds: []);
      await _tdlib.sendRequest(request);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to request QR login: $e',
      );
    }
  }

  /// Submit verification code
  Future<void> submitCode(String code) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final request = td.CheckAuthenticationCode(code: code);
      await _tdlib.sendRequest(request);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Invalid verification code: $e',
      );
    }
  }

  /// Submit 2FA password
  Future<void> submitPassword(String password) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final request = td.CheckAuthenticationPassword(password: password);
      await _tdlib.sendRequest(request);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Incorrect password: $e',
      );
    }
  }

  /// Select Phone login method
  void selectPhoneLogin() {
    state = state.copyWith(step: AuthStep.waitPhoneNumber);
  }

  /// Reset state to return to login method selection
  void reset() {
    state = AuthState(step: AuthStep.loginMethodSelection);
  }

  /// Log out and clean database
  Future<void> logout() async {
    state = AuthState(step: AuthStep.loading);
    try {
      await _tdlib.sendRequest(const td.LogOut());
      final db = ref.read(databaseProvider);
      
      // Clear database tables
      await db.customStatement('DELETE FROM bookmark_entries');
      await db.customStatement('DELETE FROM media_items');
      await db.customStatement('DELETE FROM posts');
      await db.customStatement('DELETE FROM channels');
      await db.customStatement('DELETE FROM accounts');
      
      state = AuthState(step: AuthStep.loginMethodSelection);
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.authenticated, // fallback
        errorMessage: 'Failed to log out: $e',
      );
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
