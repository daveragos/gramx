import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';
import 'package:gramx/features/auth/presentation/auth_state_rules.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

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

  /// Return back to login method selection step
  /// Leaves a sign-in attempt and returns to the method chooser.
  ///
  /// Painting a different page was not enough. TDLib owns the authorization
  /// state and keeps announcing it — a QR link refreshes every few seconds —
  /// so the reader was put straight back on the page they had just left. There
  /// is no TDLib call that cancels a pending attempt: `logOut` destroys the
  /// local database and needs a network connection, and neither QR nor phone
  /// may be requested from a QR state at all. So the attempt is left standing
  /// and simply stops driving the screen.
  void goBackToSelection() {
    _stayAtChooser = true;
    state = state.copyWith(
      step: AuthStep.loginMethodSelection,
      errorMessage: null,
      isSubmitting: false,
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

  /// The last authorization state TDLib announced.
  ///
  /// The controller's own step is what the reader is looking at; this is what
  /// TDLib will actually accept a request in. The two diverge whenever someone
  /// backs out of a sign-in method, and every rule below depends on knowing
  /// which is which.
  td.AuthorizationState? _lastTdState;

  /// True when the reader deliberately came back to the method chooser.
  ///
  /// TDLib re-announces the state it is holding — a QR link is refreshed every
  /// few seconds — and each announcement used to move the UI back onto the page
  /// they had just left. Cleared as soon as they pick a method again.
  bool _stayAtChooser = false;

  /// Whether the client has already been restarted after TDLib closed it.
  /// Reset once a healthy state arrives, so a later close gets its own retry.
  bool _restartedAfterClose = false;

  /// Whether TDLib is holding a QR code open.
  ///
  /// It is the one authorization state with no way out: `requestQrCode` and
  /// `setAuthenticationPhoneNumber` both refuse to run in it, by TDLib's own
  /// documentation. Anything that needs to leave has to restart the client.
  bool get _isShowingQr =>
      _lastTdState is td.AuthorizationStateWaitOtherDeviceConfirmation;

  AuthState? _tdlibStateToStep(td.AuthorizationState tdState) {
    if (tdState is td.AuthorizationStateWaitPhoneNumber) {
      return const AuthState(step: AuthStep.loginMethodSelection);
    } else if (tdState is td.AuthorizationStateWaitCode) {
      return AuthState(step: AuthStep.waitCode, phoneNumber: state.phoneNumber);
    } else if (tdState is td.AuthorizationStateWaitPassword) {
      return AuthState(
        step: AuthStep.waitPassword,
        phoneNumber: state.phoneNumber,
      );
    } else if (tdState is td.AuthorizationStateWaitOtherDeviceConfirmation) {
      return AuthState(step: AuthStep.waitQrCode, qrCodeLink: tdState.link);
    } else if (tdState is td.AuthorizationStateReady) {
      return const AuthState(step: AuthStep.loading);
    }
    return null;
  }

  void _onTdlibAuthState(td.AuthorizationState tdState) {
    debugPrint('[AuthCtrl] TDLib state received: ${tdState.runtimeType}');
    _timeoutTimer?.cancel();
    _lastTdState = tdState;

    // The two with side effects stay here; the rest is a pure decision — see
    // resolveAuthState, which is where the "it keeps sending me back to the QR
    // page" bug lived.
    if (tdState is td.AuthorizationStateReady) {
      _stayAtChooser = false;
      _restartedAfterClose = false;
      _handleAuthReady();
      return;
    }
    if (tdState is td.AuthorizationStateWaitPhoneNumber) {
      _restartedAfterClose = false;
    }
    if (tdState is td.AuthorizationStateClosed) {
      _stayAtChooser = false;

      // Closing is what TDLib does after a log out, so on the next launch this
      // is the *expected* state — not a failure to show someone alongside a
      // button offering to wipe their data. A fresh client on the same
      // database comes back at "waiting for a phone number", which is the
      // sign-in screen. One attempt: if it closes again, something is really
      // wrong and the error is the honest answer.
      if (!_restartedAfterClose) {
        _restartedAfterClose = true;
        state = const AuthState(
          step: AuthStep.loading,
          statusMessage: 'Reconnecting to Telegram...',
        );
        _tdlib.restartClient();
        return;
      }

      state = const AuthState(
        step: AuthStep.error,
        errorMessage: 'Telegram session closed.',
      );
      return;
    }

    final transition = resolveAuthState(
      current: state,
      tdState: tdState,
      stayAtChooser: _stayAtChooser,
    );
    _stayAtChooser = transition.stayAtChooser;
    final next = transition.state;
    if (next != null) state = next;
  }

  Future<void> _handleAuthReady() async {
    StartupTrace.mark('Telegram session ready');
    state = state.copyWith(
      step: AuthStep.loading,
      isSubmitting: false,
      statusMessage: 'Loading account profile...',
    );
    try {
      final me = await _tdlib.sendRequest(const td.GetMe());
      if (me is td.User) {
        final db = ref.read(databaseProvider);

        await (db.update(
          db.accounts,
        )).write(const AccountsCompanion(isActive: Value(false)));

        final String? username =
            (me.usernames?.activeUsernames != null &&
                me.usernames!.activeUsernames.isNotEmpty)
            ? me.usernames!.activeUsernames.first
            : me.usernames?.editableUsername;

        if (me.profilePhoto != null) {
          try {
            await _tdlib.sendRequest(
              td.DownloadFile(
                fileId: me.profilePhoto!.small.id,
                priority: 1,
                offset: 0,
                limit: 0,
                synchronous: false,
              ),
            );
          } catch (e) {
            debugPrint('[Auth] Failed to request user avatar download: $e');
          }
        }

        final avatarPathValue =
            me.profilePhoto?.small.local.path.isNotEmpty == true
            ? me.profilePhoto?.small.local.path
            : (me.profilePhoto?.small.remote.id.isNotEmpty == true
                  ? me.profilePhoto?.small.remote.id
                  : me.profilePhoto?.small.id.toString());

        final existingAccount =
            await (db.select(db.accounts)
                  ..where((a) => a.telegramUserId.equals(me.id.toString())))
                .getSingleOrNull();

        if (existingAccount != null) {
          await (db.update(
            db.accounts,
          )..where((a) => a.id.equals(existingAccount.id))).write(
            AccountsCompanion(
              displayName: Value('${me.firstName} ${me.lastName}'.trim()),
              username: Value(username),
              phoneNumber: Value(me.phoneNumber),
              avatarPath: Value(avatarPathValue),
              isActive: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
        } else {
          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  telegramUserId: me.id.toString(),
                  displayName: Value('${me.firstName} ${me.lastName}'.trim()),
                  username: Value(username),
                  phoneNumber: Value(me.phoneNumber),
                  avatarPath: Value(avatarPathValue),
                  isActive: const Value(true),
                ),
              );
        }
      }

      state = state.copyWith(step: AuthStep.authenticated);
      StartupTrace.mark('account loaded, leaving the splash');

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

  /// Opens the phone-number page, restarting the client first if a QR is in
  /// the way.
  ///
  /// TDLib will not accept `setAuthenticationPhoneNumber` while it is holding
  /// a QR code open, and offers no way to cancel one — so the only route from
  /// a QR back to a phone number is a fresh client. That is safe here and only
  /// here: nobody is signed in yet, so the local data being cleared is an
  /// empty database.
  Future<void> selectPhoneLogin() async {
    _stayAtChooser = false;

    if (!_isShowingQr) {
      state = state.clearError().copyWith(step: AuthStep.waitPhoneNumber);
      return;
    }

    state = const AuthState(
      step: AuthStep.loading,
      statusMessage: 'Switching to phone sign-in…',
    );
    await resetSession();
    // The reset lands on WaitPhoneNumber, which puts the chooser back up; go
    // straight to the page they asked for.
    state = const AuthState(step: AuthStep.waitPhoneNumber);
  }

  Future<void> submitPhoneNumber(String phone) async {
    _stayAtChooser = false;
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
        state = state.copyWith(isSubmitting: false, errorMessage: res.message);
      } else {
        state = state.copyWith(
          phoneNumber: formattedPhone,
          isSubmitting: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Shows a QR code to scan, asking TDLib for one only if it isn't already
  /// holding one open.
  ///
  /// `requestQrCodeAuthentication` refuses to run while a QR is already
  /// pending — TDLib answers "Call to requestQrCodeAuthentication unexpected",
  /// which is what the "Refresh QR code" button produced every time. TDLib
  /// refreshes the link itself; there is nothing to ask for.
  Future<void> requestQrLogin() async {
    _stayAtChooser = false;

    if (!shouldRequestQrCode(
      tdlibIsShowingQr: _isShowingQr,
      knownLink: state.qrCodeLink,
    )) {
      state = state.clearError().copyWith(
        step: AuthStep.waitQrCode,
        isSubmitting: false,
      );
      return;
    }

    state = state.clearError().copyWith(isSubmitting: true);
    try {
      final res = await _tdlib.sendRequest(
        td.RequestQrCodeAuthentication(otherUserIds: []),
      );
      if (res is td.TdError) {
        state = state.copyWith(isSubmitting: false, errorMessage: res.message);
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
      final res = await _tdlib.sendRequest(
        td.CheckAuthenticationCode(code: code),
      );
      if (res is td.TdError) {
        state = state.copyWith(isSubmitting: false, errorMessage: res.message);
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
        state = state.copyWith(isSubmitting: false, errorMessage: res.message);
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
    state = const AuthState(
      step: AuthStep.loading,
      statusMessage: 'Retrying connection...',
    );
    _startConnectionTimeout();
    _tdlib.initialize().catchError((e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: 'Retry failed: $e',
      );
    });
  }

  Future<void> resetSession() async {
    state = const AuthState(
      step: AuthStep.loading,
      statusMessage: 'Resetting session...',
    );
    _startConnectionTimeout();
    await _tdlib.resetSession();
  }

  /// Ends the session, locally first.
  ///
  /// The old order made the local state wait on the round trip, and set the
  /// step back to `authenticated` if it failed — so a `LogOut` that hung (it
  /// needs a network connection) left the app sitting in `loading` inside the
  /// shell, showing a signed-out feed with a "log in" button and no way to the
  /// sign-in screen. Someone who asked to be logged out is logged out here
  /// whatever the network does; the request is still sent, and its failure is
  /// reported rather than reversing the decision.
  Future<void> logout() async {
    state = const AuthState(
      step: AuthStep.loading,
      statusMessage: 'Logging out…',
    );

    final db = ref.read(databaseProvider);
    await db.delete(db.bookmarkEntries).go();
    await db.delete(db.accounts).go();

    // Chats are account-scoped — a stale cache would leak the previous
    // account's channels into the next sign-in's feed.
    ref.read(chatCacheProvider).clear();

    // The step moves before the request, so the router can act on it even if
    // the request never comes back.
    state = const AuthState(step: AuthStep.loginMethodSelection);

    try {
      await _tdlib.sendRequest(const td.LogOut());
    } catch (e) {
      debugPrint('[AuthCtrl] LogOut failed after local sign-out: $e');
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
