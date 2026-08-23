import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/auth_redirect.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

void main() {
  group('at startup, before any session has existed', () {
    // TDLib has not answered yet. Flashing a sign-in screen at someone who is
    // signed in is worse than a beat of nothing.
    test('a loading state stays where it is', () {
      expect(
        authRedirect(
          step: AuthStep.loading,
          location: '/home',
          hasSignedIn: false,
        ),
        isNull,
      );
    });

    test('a signed-out state goes to sign-in', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: '/home',
          hasSignedIn: false,
        ),
        '/auth',
      );
    });
  });

  // The reported failure: signing out left the reader inside the shell,
  // looking at a signed-out feed with the bottom bar under it, because the
  // sign-out sat in `loading` and every loading state was left alone.
  group('once a session has existed', () {
    test('a loading state goes to sign-in', () {
      expect(
        authRedirect(
          step: AuthStep.loading,
          location: '/home',
          hasSignedIn: true,
        ),
        '/auth',
      );
    });

    test('so does an error', () {
      expect(
        authRedirect(
          step: AuthStep.error,
          location: '/settings',
          hasSignedIn: true,
        ),
        '/auth',
      );
    });

    test('and it does not bounce once it is there', () {
      expect(
        authRedirect(
          step: AuthStep.loading,
          location: '/auth',
          hasSignedIn: true,
        ),
        isNull,
      );
    });
  });

  group('signed in', () {
    test('stays wherever it is', () {
      expect(
        authRedirect(
          step: AuthStep.authenticated,
          location: '/channels',
          hasSignedIn: true,
        ),
        isNull,
      );
    });

    test('leaves the sign-in screen', () {
      expect(
        authRedirect(
          step: AuthStep.authenticated,
          location: '/auth',
          hasSignedIn: true,
        ),
        '/home',
      );
    });
  });

  // Nobody should have to agree to something they cannot read.
  group('the legal documents', () {
    test('are readable signed out', () {
      for (final step in [
        AuthStep.loginMethodSelection,
        AuthStep.loading,
        AuthStep.error,
      ]) {
        expect(
          authRedirect(
            step: step,
            location: '/legal/privacy',
            hasSignedIn: true,
          ),
          isNull,
          reason: '$step',
        );
      }
    });
  });
}
