import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

// ---------------------------------------------------------------------------
// Auth step enum — each value maps to a distinct UI page.
// ---------------------------------------------------------------------------
enum AuthStep {
  /// TDLib is still initializing or connecting to Telegram servers.
  loading,

  /// User picks between phone-number login and QR-code login.
  loginMethodSelection,

  /// Phone number input page.
  waitPhoneNumber,

  /// Verification code input page.
  waitCode,

  /// Two-step verification (cloud password) page.
  waitPassword,

  /// QR code display page.
  waitQrCode,

  /// Fully authenticated — redirect to home.
  authenticated,

  /// An unrecoverable or connection error occurred.
  error,
}

// ---------------------------------------------------------------------------
// Immutable auth state.
// ---------------------------------------------------------------------------
class AuthState {
  final AuthStep step;
  final String? phoneNumber;
  final String? qrCodeLink;
  final String? errorMessage;
  final String statusMessage;
  final bool isSubmitting;

  const AuthState({
    required this.step,
    this.phoneNumber,
    this.qrCodeLink,
    this.errorMessage,
    this.statusMessage = 'Connecting to Telegram...',
    this.isSubmitting = false,
  });

  AuthState copyWith({
    AuthStep? step,
    String? phoneNumber,
    String? qrCodeLink,
    String? errorMessage,
    String? statusMessage,
    bool? isSubmitting,
  }) {
    return AuthState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      qrCodeLink: qrCodeLink ?? this.qrCodeLink,
      errorMessage: errorMessage ?? this.errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  AuthState clearError() {
    return AuthState(
      step: step,
      phoneNumber: phoneNumber,
      qrCodeLink: qrCodeLink,
      errorMessage: null,
      statusMessage: statusMessage,
      isSubmitting: isSubmitting,
    );
  }
}

// ---------------------------------------------------------------------------
// AuthController — drives the login and connection workflow.
// ---------------------------------------------------------------------------
class AuthController extends Notifier<AuthState> {
  late TdlibService _tdlib;
  StreamSubscription? _authSub;
  StreamSubscription? _statusSub;
  Timer? _timeoutTimer;

  @override
  AuthState build() {
    _tdlib = ref.watch(tdlibServiceProvider);

    _authSub = _tdlib.authStateStream.listen(_onTdlibAuthState);
    _statusSub = _tdlib.statusMessageStream.listen((msg) {
      if (state.step == AuthStep.loading) {
        state = state.copyWith(statusMessage: msg);
      }
    });

    ref.onDispose(() {
      _authSub?.cancel();
      _statusSub?.cancel();
      _timeoutTimer?.cancel();
    });

    // Start a timeout monitor for connection
    _startConnectionTimeout();

    // Check cached state
    final cached = _tdlib.currentAuthState;
    if (cached != null) {
      final resolved = _tdlibStateToStep(cached);
      if (resolved != null) {
        _timeoutTimer?.cancel();
        return resolved;
      }
    }

    return AuthState(
      step: AuthStep.loading,
      statusMessage: _tdlib.lastStatusMessage,
    );
  }

  void _startConnectionTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (state.step == AuthStep.loading) {
        state = state.copyWith(
          step: AuthStep.error,
          errorMessage:
              'Connection to Telegram timed out. Please check your internet connection or reset the session.',
        );
      }
    });
  }

  AuthState? _tdlibStateToStep(td.AuthorizationState tdState) {
    if (tdState is td.AuthorizationStateWaitPhoneNumber) {
      return const AuthState(step: AuthStep.loginMethodSelection);
    } else if (tdState is td.AuthorizationStateWaitCode) {
      return AuthState(
        step: AuthStep.waitCode,
        phoneNumber: state.phoneNumber,
      );
    } else if (tdState is td.AuthorizationStateWaitPassword) {
      return AuthState(
        step: AuthStep.waitPassword,
        phoneNumber: state.phoneNumber,
      );
    } else if (tdState is td.AuthorizationStateWaitOtherDeviceConfirmation) {
      return AuthState(
        step: AuthStep.waitQrCode,
        qrCodeLink: tdState.link,
      );
    } else if (tdState is td.AuthorizationStateReady) {
      return const AuthState(step: AuthStep.loading);
    }
    return null;
  }

  void _onTdlibAuthState(td.AuthorizationState tdState) {
    debugPrint('[AuthCtrl] TDLib state received: ${tdState.runtimeType}');
    _timeoutTimer?.cancel();

    if (tdState is td.AuthorizationStateWaitPhoneNumber) {
      state = const AuthState(step: AuthStep.loginMethodSelection);
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
    } else if (tdState is td.AuthorizationStateClosed) {
      state = const AuthState(
        step: AuthStep.error,
        errorMessage: 'Telegram session closed.',
      );
    }
  }

  Future<void> _handleAuthReady() async {
    state = state.copyWith(step: AuthStep.loading, isSubmitting: false, statusMessage: 'Loading account profile...');
    try {
      final me = await _tdlib.sendRequest(const td.GetMe());
      if (me is td.User) {
        final db = ref.read(databaseProvider);

        await (db.update(db.accounts)).write(
          const AccountsCompanion(isActive: Value(false)),
        );

        final String? username =
            (me.usernames?.activeUsernames != null &&
                    me.usernames!.activeUsernames.isNotEmpty)
                ? me.usernames!.activeUsernames.first
                : me.usernames?.editableUsername;

        if (me.profilePhoto != null) {
          try {
            await _tdlib.sendRequest(td.DownloadFile(
              fileId: me.profilePhoto!.small.id,
              priority: 1,
              offset: 0,
              limit: 0,
              synchronous: false,
            ));
          } catch (e) {
            debugPrint('[Auth] Failed to request user avatar download: $e');
          }
        }

        final avatarPathValue = me.profilePhoto?.small.local.path.isNotEmpty == true
            ? me.profilePhoto?.small.local.path
            : (me.profilePhoto?.small.remote.id.isNotEmpty == true
                ? me.profilePhoto?.small.remote.id
                : me.profilePhoto?.small.id.toString());

        final existingAccount = await (db.select(db.accounts)
              ..where((a) => a.telegramUserId.equals(me.id.toString())))
            .getSingleOrNull();

        if (existingAccount != null) {
          await (db.update(db.accounts)
                ..where((a) => a.id.equals(existingAccount.id)))
              .write(
            AccountsCompanion(
              displayName:
                  Value('${me.firstName} ${me.lastName}'.trim()),
              username: Value(username),
              phoneNumber: Value(me.phoneNumber),
              avatarPath: Value(avatarPathValue),
              isActive: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
        } else {
          await db.into(db.accounts).insert(
                AccountsCompanion.insert(
                  telegramUserId: me.id.toString(),
                  displayName:
                      Value('${me.firstName} ${me.lastName}'.trim()),
                  username: Value(username),
                  phoneNumber: Value(me.phoneNumber),
                  avatarPath: Value(avatarPathValue),
                  isActive: const Value(true),
                ),
              );
        }
      }

      state = state.copyWith(step: AuthStep.authenticated);

      // Trigger background channel & feed sync
      final syncService = ref.read(syncServiceProvider);
      syncService.markAuthReady();
      syncService.startListening();
      syncService.triggerInitialSync();
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: 'Failed to retrieve user profile: $e',
      );
    }
  }

  void selectPhoneLogin() {
    state = state.clearError().copyWith(step: AuthStep.waitPhoneNumber);
  }

  Future<void> submitPhoneNumber(String phone) async {
    var formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+$formattedPhone';
    }
    state = state.clearError().copyWith(isSubmitting: true);
    try {
      final res = await _tdlib.sendRequest(
        td.SetAuthenticationPhoneNumber(
          phoneNumber: formattedPhone,
          settings: td.PhoneNumberAuthenticationSettings(
            allowFlashCall: false,
            allowMissedCall: false,
            isCurrentPhoneNumber: false,
            allowSmsRetrieverApi: false,
            hasUnknownPhoneNumber: false,
            authenticationTokens: [],
          ),
        ),
      );
      if (res is td.TdError) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: res.message,
        );
      } else {
        state = state.copyWith(phoneNumber: formattedPhone, isSubmitting: false);
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> requestQrLogin() async {
    state = state.clearError().copyWith(isSubmitting: true);
    try {
      final res = await _tdlib.sendRequest(
        td.RequestQrCodeAuthentication(otherUserIds: []),
      );
      if (res is td.TdError) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: res.message,
        );
      } else {
        state = state.copyWith(isSubmitting: false);
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> submitCode(String code) async {
    state = state.clearError().copyWith(isSubmitting: true);
    try {
      final res = await _tdlib.sendRequest(td.CheckAuthenticationCode(code: code));
      if (res is td.TdError) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: res.message,
        );
      } else {
        state = state.copyWith(isSubmitting: false);
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> submitPassword(String password) async {
    state = state.clearError().copyWith(isSubmitting: true);
    try {
      final res = await _tdlib.sendRequest(
        td.CheckAuthenticationPassword(password: password),
      );
      if (res is td.TdError) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: res.message,
        );
      } else {
        state = state.copyWith(isSubmitting: false);
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void retryConnection() {
    state = const AuthState(step: AuthStep.loading, statusMessage: 'Retrying connection...');
    _startConnectionTimeout();
    _tdlib.initialize().catchError((e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: 'Retry failed: $e',
      );
    });
  }

  Future<void> resetSession() async {
    state = const AuthState(step: AuthStep.loading, statusMessage: 'Resetting session...');
    _startConnectionTimeout();
    await _tdlib.resetSession();
  }

  void reset() {
    state = const AuthState(step: AuthStep.loginMethodSelection);
  }

  Future<void> logout() async {
    state = const AuthState(step: AuthStep.loading, statusMessage: 'Logging out...');
    try {
      await _tdlib.sendRequest(const td.LogOut());
      final db = ref.read(databaseProvider);

      await db.delete(db.bookmarkEntries).go();
      await db.delete(db.accounts).go();

      state = const AuthState(step: AuthStep.loginMethodSelection);
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.authenticated,
        errorMessage: 'Failed to log out: $e',
      );
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
