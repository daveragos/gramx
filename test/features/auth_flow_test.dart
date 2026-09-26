import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/auth_state_rules.dart';
import 'package:handy_tdlib/api.dart' as td;

td.AuthorizationState qr([String link = 'tg://login?token=abc']) =>
    td.AuthorizationStateWaitOtherDeviceConfirmation(link: link);

final waitCode = td.AuthorizationStateWaitCode(
  codeInfo: td.AuthenticationCodeInfo(
    phoneNumber: '+100',
    type: const td.AuthenticationCodeTypeSms(length: 5),
    timeout: 60,
  ),
);

const waitPassword = td.AuthorizationStateWaitPassword(
  passwordHint: '',
  hasRecoveryEmailAddress: false,
  hasPassportData: false,
  recoveryEmailAddressPattern: '',
);

void main() {
  group('while a method is being used', () {
    test('a QR announcement opens the QR page and carries the link', () {
      final transition = resolveAuthState(
        current: const AuthState(step: AuthStep.loginMethodSelection),
        tdState: qr(),
        stayAtChooser: false,
      );

      expect(transition.state!.step, AuthStep.waitQrCode);
      expect(transition.state!.qrCodeLink, 'tg://login?token=abc');
    });

    test('a code announcement opens the code page', () {
      final transition = resolveAuthState(
        current: const AuthState(step: AuthStep.waitPhoneNumber),
        tdState: waitCode,
        stayAtChooser: false,
      );

      expect(transition.state!.step, AuthStep.waitCode);
    });
  });

  // The reported failure: TDLib reissues a pending QR every few seconds, and
  // each announcement put the reader straight back on the page they had left.
  group('after backing out to the chooser', () {
    test('a refreshed QR link does not reopen the QR page', () {
      final transition = resolveAuthState(
        current: const AuthState(step: AuthStep.loginMethodSelection),
        tdState: qr('tg://login?token=def'),
        stayAtChooser: true,
      );

      expect(transition.state!.step, AuthStep.loginMethodSelection);
      expect(transition.stayAtChooser, isTrue);
      expect(
        transition.state!.qrCodeLink,
        'tg://login?token=def',
        reason: 'kept current for when they come back to it',
      );
    });

    test('a re-announced code state does not reopen the code page', () {
      final transition = resolveAuthState(
        current: const AuthState(step: AuthStep.loginMethodSelection),
        tdState: waitCode,
        stayAtChooser: true,
      );

      expect(transition.state, isNull, reason: 'leave the screen alone');
      expect(transition.stayAtChooser, isTrue);
    });

    // Someone confirmed the QR on their other device: that outranks whichever
    // page the reader had wandered to.
    test('real progress takes the screen back', () {
      final transition = resolveAuthState(
        current: const AuthState(step: AuthStep.loginMethodSelection),
        tdState: waitPassword,
        stayAtChooser: true,
      );

      expect(transition.state!.step, AuthStep.waitPassword);
      expect(transition.stayAtChooser, isFalse);
    });

    test('TDLib returning to wait-for-number lets the screen follow again', () {
      final transition = resolveAuthState(
        current: const AuthState(step: AuthStep.loginMethodSelection),
        tdState: const td.AuthorizationStateWaitPhoneNumber(),
        stayAtChooser: true,
      );

      expect(transition.state!.step, AuthStep.loginMethodSelection);
      expect(transition.stayAtChooser, isFalse);
    });
  });

  group('shouldRequestQrCode', () {
    // "Refresh QR code" asked for a new one while TDLib was already holding
    // one, which TDLib rejects: "Call to requestQrCodeAuthentication
    // unexpected". It refreshes the link itself, so there is nothing to ask.
    test('no request while TDLib is already holding a code', () {
      expect(
        shouldRequestQrCode(tdlibIsShowingQr: true, knownLink: 'tg://login'),
        isFalse,
      );
    });

    test('requests one when there is none', () {
      expect(
        shouldRequestQrCode(tdlibIsShowingQr: false, knownLink: null),
        isTrue,
      );
    });

    // Holding the state without a link to show is not something to sit on.
    test('requests one if the link never arrived', () {
      expect(
        shouldRequestQrCode(tdlibIsShowingQr: true, knownLink: null),
        isTrue,
      );
    });
  });
}
