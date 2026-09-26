import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/auth/presentation/auth_providers.dart';

/// What one TDLib announcement should do to the screen.
///
/// A null [state] means leave the screen as it is.
class AuthTransition {
  final AuthState? state;

  /// Whether the reader should still be held at the method chooser.
  final bool stayAtChooser;

  const AuthTransition({this.state, required this.stayAtChooser});
}

/// Turns a TDLib authorization state into the page the reader should see.
///
/// Pure, because this is where the sign-in flow went wrong and the failure was
/// invisible in a widget: TDLib owns the authorization state and re-announces
/// it — a pending QR is reissued every few seconds — so every announcement
/// dragged the reader back onto the page they had just left. Backing out of a
/// method cannot cancel the attempt (TDLib has no call for it), so instead the
/// attempt stops driving the screen, which is what [stayAtChooser] tracks.
///
/// `AuthorizationStateReady` and `...Closed` are not handled here: they have
/// side effects the controller owns.
AuthTransition resolveAuthState({
  required AuthState current,
  required td.AuthorizationState tdState,
  required bool stayAtChooser,
}) {
  if (tdState is td.AuthorizationStateWaitPhoneNumber) {
    // A fresh attempt is possible again, so nothing is being held back.
    return const AuthTransition(
      state: AuthState(step: AuthStep.loginMethodSelection),
      stayAtChooser: false,
    );
  }

  if (tdState is td.AuthorizationStateWaitOtherDeviceConfirmation) {
    if (stayAtChooser) {
      // Keep the link current — the reader may come back to it — without
      // moving them onto the page.
      return AuthTransition(
        state: current.copyWith(qrCodeLink: tdState.link, isSubmitting: false),
        stayAtChooser: true,
      );
    }
    return AuthTransition(
      state: current.copyWith(
        step: AuthStep.waitQrCode,
        qrCodeLink: tdState.link,
        isSubmitting: false,
      ),
      stayAtChooser: false,
    );
  }

  if (tdState is td.AuthorizationStateWaitCode) {
    if (stayAtChooser) return const AuthTransition(stayAtChooser: true);
    return AuthTransition(
      state: current.copyWith(step: AuthStep.waitCode, isSubmitting: false),
      stayAtChooser: false,
    );
  }

  if (tdState is td.AuthorizationStateWaitPassword) {
    // Never held back. Reaching this means the sign-in actually progressed —
    // someone confirmed the QR, or the code was accepted — and that outranks
    // whichever page the reader had wandered to.
    return AuthTransition(
      state: current.copyWith(step: AuthStep.waitPassword, isSubmitting: false),
      stayAtChooser: false,
    );
  }

  return AuthTransition(stayAtChooser: stayAtChooser);
}

/// Whether a QR code has to be asked for, or one is already in hand.
///
/// `requestQrCodeAuthentication` is rejected outright while TDLib is already
/// holding a QR open — "Call to requestQrCodeAuthentication unexpected" — and
/// TDLib refreshes the link on its own, so there is never anything to ask for
/// in that state.
bool shouldRequestQrCode({
  required bool tdlibIsShowingQr,
  required String? knownLink,
}) => !(tdlibIsShowingQr && knownLink != null);
