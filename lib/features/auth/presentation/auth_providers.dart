import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';
import 'package:gramx/features/auth/presentation/auth_state_rules.dart';
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/features/feed/presentation/seen_posts_provider.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

/// A step of sign-in, each with its own page.
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

  /// Signed in; the router moves on to home.
  authenticated,

  /// An unrecoverable or connection error occurred.
  error,
}

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

/// Drives sign-in and the connection to Telegram.
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

    _startConnectionTimeout();

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

  /// Leaves a sign-in attempt and returns to the method chooser. TDLib can't
  /// cancel a pending attempt and keeps re-announcing its state, so the
  /// attempt stays open and just stops driving the screen.
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

  /// The last authorization state TDLib announced. Differs from the visible
  /// step after the user backs out of a sign-in method.
  td.AuthorizationState? _lastTdState;

  /// Set when the user goes back to the method chooser, so TDLib's repeated
  /// state updates don't move the screen. Cleared when a method is picked.
  bool _stayAtChooser = false;

  /// Whether the client has already been restarted after TDLib closed it.
  /// Reset once a healthy state arrives, so a later close gets its own retry.
  bool _restartedAfterClose = false;

  /// Whether TDLib is holding a QR code open. TDLib refuses QR and phone
  /// requests in that state, so leaving it takes a client restart.
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

    // States with side effects; the rest go through resolveAuthState.
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

      // Expected after a log out: restart once, which reopens at sign-in.
      // A second close in a row is an error.
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

      // In the background, so the splash waits only on GetMe.
      if (me is td.User) unawaited(_saveAccount(me));

      state = state.copyWith(step: AuthStep.authenticated);
      StartupTrace.mark('account loaded, leaving the splash');

      final syncService = ref.read(syncServiceProvider);
      syncService.markAuthReady();
      syncService.startListening();

      // The only `LoadChats` at sign-in. Each one pulls in another hundred
      // chats, so extra calls here slow the feed's first paint.
      unawaited(ref.read(chatCacheProvider).ensureLoaded());
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: 'Failed to retrieve user profile: $e',
      );
    }
  }

  /// Records the signed-in account in the app's database, in one transaction
  /// so watchers never see a moment with no active account.
  Future<void> _saveAccount(td.User me) async {
    final photo = me.profilePhoto?.small;
    if (photo != null) {
      // Not awaited: this only asks TDLib to start fetching the picture.
      unawaited(
        _tdlib
            .sendRequest(
              td.DownloadFile(
                fileId: photo.id,
                priority: 1,
                offset: 0,
                limit: 0,
                synchronous: false,
              ),
            )
            .then<void>(
              (_) {},
              onError: (Object e) => debugPrint(
                '[Auth] Failed to request user avatar download: $e',
              ),
            ),
      );
    }

    final usernames = me.usernames;
    final String? username = (usernames?.activeUsernames.isNotEmpty ?? false)
        ? usernames!.activeUsernames.first
        : usernames?.editableUsername;

    final avatarPathValue = photo == null
        ? null
        : photo.local.path.isNotEmpty
        ? photo.local.path
        : photo.remote.id.isNotEmpty
        ? photo.remote.id
        : photo.id.toString();

    final displayName = '${me.firstName} ${me.lastName}'.trim();
    final db = ref.read(databaseProvider);
    try {
      await db.transaction(() async {
        await db
            .update(db.accounts)
            .write(const AccountsCompanion(isActive: Value(false)));

        final existingAccount =
            await (db.select(db.accounts)
                  ..where((a) => a.telegramUserId.equals(me.id.toString())))
                .getSingleOrNull();

        if (existingAccount != null) {
          await (db.update(
            db.accounts,
          )..where((a) => a.id.equals(existingAccount.id))).write(
            AccountsCompanion(
              displayName: Value(displayName),
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
                  displayName: Value(displayName),
                  username: Value(username),
                  phoneNumber: Value(me.phoneNumber),
                  avatarPath: Value(avatarPathValue),
                  isActive: const Value(true),
                ),
              );
        }
      });
    } catch (e) {
      debugPrint('[Auth] Could not save the account: $e');
    }
  }

  /// Opens the phone-number page, restarting the client first if TDLib is
  /// holding a QR code (safe, as no account is signed in yet).
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
    // The restart lands on the chooser, so go straight to the phone page.
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

  /// Shows a QR code, requesting one only if TDLib isn't already holding one
  /// (it rejects a second request and refreshes the link itself).
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

  /// Signs out locally first and then tells Telegram, so a slow or failed
  /// `LogOut` request can't leave the app stuck half signed in.
  Future<void> logout() async {
    state = const AuthState(
      step: AuthStep.loading,
      statusMessage: 'Logging out…',
    );

    final db = ref.read(databaseProvider);
    await db.delete(db.bookmarkEntries).go();
    await db.delete(db.accounts).go();

    // Chats and seen posts are per account.
    ref.read(chatCacheProvider).clear();
    await ref.read(seenPostsProvider.notifier).clear();

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
