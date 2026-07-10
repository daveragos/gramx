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
  /// TDLib is still initializing or we haven't received a user-facing state.
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

  /// An unrecoverable error occurred.
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
  final bool isSubmitting;

  const AuthState({
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

  /// Returns a copy with errorMessage explicitly set to null.
  AuthState clearError() {
    return AuthState(
      step: step,
      phoneNumber: phoneNumber,
      qrCodeLink: qrCodeLink,
      errorMessage: null,
      isSubmitting: isSubmitting,
    );
  }
}

// ---------------------------------------------------------------------------
// Raw TDLib auth stream (kept for anything that needs it directly).
// ---------------------------------------------------------------------------
final telegramAuthStateProvider = StreamProvider<td.AuthorizationState>((ref) {
  final tdlib = ref.watch(tdlibServiceProvider);
  return tdlib.authStateStream;
});

// ---------------------------------------------------------------------------
// AuthController — drives the entire login flow.
// ---------------------------------------------------------------------------
class AuthController extends Notifier<AuthState> {
  late TdlibService _tdlib;
  StreamSubscription? _authSub;

  @override
  AuthState build() {
    _tdlib = ref.watch(tdlibServiceProvider);

    // Subscribe to future auth-state events from TDLib.
    _authSub = _tdlib.authStateStream.listen(_onTdlibAuthState);

    ref.onDispose(() {
      _authSub?.cancel();
    });

    // Attempt to resolve an initial step from the cached TDLib state.
    final cached = _tdlib.currentAuthState;
    if (cached != null) {
      final resolved = _tdlibStateToStep(cached);
      if (resolved != null) return resolved;

      // Cached state is an intermediate one (e.g. WaitTdlibParameters).
      // Stay on loading — the stream listener will move us forward.
      debugPrint(
        '[AuthCtrl] Cached state is intermediate: ${cached.runtimeType}. '
        'Waiting for stream…',
      );
    }

    return const AuthState(step: AuthStep.loading);
  }

  // -----------------------------------------------------------------------
  // TDLib state → AuthState mapping (pure, no side-effects).
  // Returns null for intermediate/unhandled states.
  // -----------------------------------------------------------------------
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
      // Return loading — the caller triggers _handleAuthReady().
      return const AuthState(step: AuthStep.loading);
    }
    return null; // intermediate / unhandled
  }

  // -----------------------------------------------------------------------
  // Stream callback — maps every incoming TDLib auth event to a UI step.
  // -----------------------------------------------------------------------
  void _onTdlibAuthState(td.AuthorizationState tdState) {
    debugPrint('[AuthCtrl] TDLib auth event: ${tdState.runtimeType}');

    if (tdState is td.AuthorizationStateWaitPhoneNumber) {
      // Only jump to selection if we're currently loading (first arrival)
      // or in an unexpected step. If the user is already on the phone-input
      // page, leave them there.
      if (state.step == AuthStep.loading || state.step == AuthStep.error) {
        state = const AuthState(step: AuthStep.loginMethodSelection);
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
    // All other states (WaitTdlibParameters, Closing, etc.) are ignored —
    // TdlibService handles them internally.
  }

  // -----------------------------------------------------------------------
  // Post-authentication: store account info & kick off background sync.
  // -----------------------------------------------------------------------
  Future<void> _handleAuthReady() async {
    state = state.copyWith(step: AuthStep.loading, isSubmitting: false);
    try {
      final me = await _tdlib.sendRequest(const td.GetMe());
      if (me is td.User) {
        final db = ref.read(databaseProvider);

        // Deactivate all accounts first.
        await (db.update(db.accounts)).write(
          const AccountsCompanion(isActive: Value(false)),
        );

        final String? username =
            (me.usernames?.activeUsernames != null &&
                    me.usernames!.activeUsernames.isNotEmpty)
                ? me.usernames!.activeUsernames.first
                : me.usernames?.editableUsername;

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
              avatarPath: Value(
                me.profilePhoto?.small.local.path.isNotEmpty == true
                    ? me.profilePhoto?.small.local.path
                    : null,
              ),
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
                  avatarPath: Value(
                    me.profilePhoto?.small.local.path.isNotEmpty == true
                        ? me.profilePhoto?.small.local.path
                        : null,
                  ),
                  isActive: const Value(true),
                ),
              );
        }
      }

      // Transition to authenticated IMMEDIATELY.
      state = state.copyWith(step: AuthStep.authenticated);

      // Kick off background sync (fire-and-forget).
      final syncService = ref.read(syncServiceProvider);
      syncService.syncSubscribedChannels().then((_) {
        return syncService.syncFeedHistory();
      }).catchError((e) {
        debugPrint('[Auth] Background sync error: $e');
      });
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: 'Failed to retrieve profile: $e',
      );
    }
  }

  // -----------------------------------------------------------------------
  // User actions
  // -----------------------------------------------------------------------

  /// Navigate to the phone-number input page.
  void selectPhoneLogin() {
    state = state.clearError().copyWith(step: AuthStep.waitPhoneNumber);
  }

  /// Submit a phone number to TDLib.
  Future<void> submitPhoneNumber(String phone) async {
    state = state.clearError().copyWith(isSubmitting: true);
    try {
      await _tdlib.sendRequest(
        td.SetAuthenticationPhoneNumber(
          phoneNumber: phone,
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
      state = state.copyWith(phoneNumber: phone, isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to submit phone number: $e',
      );
    }
  }

  /// Start QR-code login flow.
  Future<void> requestQrLogin() async {
    state = state.clearError().copyWith(isSubmitting: true);
    try {
      await _tdlib.sendRequest(
        td.RequestQrCodeAuthentication(otherUserIds: []),
      );
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to request QR login: $e',
      );
    }
  }

  /// Submit verification code.
  Future<void> submitCode(String code) async {
    state = state.clearError().copyWith(isSubmitting: true);
    try {
      await _tdlib.sendRequest(td.CheckAuthenticationCode(code: code));
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Invalid verification code: $e',
      );
    }
  }

  /// Submit 2FA password.
  Future<void> submitPassword(String password) async {
    state = state.clearError().copyWith(isSubmitting: true);
    try {
      await _tdlib.sendRequest(
        td.CheckAuthenticationPassword(password: password),
      );
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Incorrect password: $e',
      );
    }
  }

  /// Reset to method-selection page.
  void reset() {
    state = const AuthState(step: AuthStep.loginMethodSelection);
  }

  /// Log out, clear database, return to login.
  Future<void> logout() async {
    state = const AuthState(step: AuthStep.loading);
    try {
      await _tdlib.sendRequest(const td.LogOut());
      final db = ref.read(databaseProvider);

      await db.delete(db.bookmarkEntries).go();
      await db.delete(db.mediaItems).go();
      await db.delete(db.posts).go();
      await db.delete(db.channels).go();
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
