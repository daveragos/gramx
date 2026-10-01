import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/auth/presentation/auth_providers.dart';

/// What one TDLib announcement does to the screen. A null [state] leaves the
/// screen as it is.
class AuthTransition {
  final AuthState? state;

  /// Whether the user is still held at the method chooser.
  final bool stayAtChooser;

  const AuthTransition({this.state, required this.stayAtChooser});
}

/// Maps a TDLib authorization state to the page to show. While [stayAtChooser]
/// is set, TDLib's repeated announcements don't move the screen. Ready and
/// Closed are handled by the controller.
AuthTransition resolveAuthState({
  required AuthState current,
  required td.AuthorizationState tdState,
  required bool stayAtChooser,
}) {
  if (tdState is td.AuthorizationStateWaitPhoneNumber) {
    // A fresh attempt is possible, so the hold is released.
    return const AuthTransition(
      state: AuthState(step: AuthStep.loginMethodSelection),
      stayAtChooser: false,
    );
  }

  if (tdState is td.AuthorizationStateWaitOtherDeviceConfirmation) {
    if (stayAtChooser) {
      // Keep the link current without moving to the QR page.
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
    // Never held: sign-in has moved past the chosen method.
    return AuthTransition(
      state: current.copyWith(step: AuthStep.waitPassword, isSubmitting: false),
      stayAtChooser: false,
    );
  }

  return AuthTransition(stayAtChooser: stayAtChooser);
}

/// Whether a QR code needs requesting. TDLib rejects a request while one is
/// open, and refreshes the link itself.
bool shouldRequestQrCode({
  required bool tdlibIsShowingQr,
  required String? knownLink,
}) => !(tdlibIsShowingQr && knownLink != null);
