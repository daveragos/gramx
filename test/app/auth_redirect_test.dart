import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/auth_redirect.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

void main() {
  group('at startup, before any session has existed', () {
    // TDLib hasn't answered yet, so don't flash the sign-in screen.
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

  // TDLib can report a sign-in step during startup and replace it with Ready a
  // moment later, so sign-in steps wait for the state to settle.
  group('while the session state is still settling', () {
    test('a sign-in step does not move anybody off the splash', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: splashLocation,
          hasSignedIn: false,
          isSettled: false,
        ),
        isNull,
      );
    });

    test('nor off wherever else they were', () {
      expect(
        authRedirect(
          step: AuthStep.waitQrCode,
          location: '/post/7_1',
          hasSignedIn: false,
          isSettled: false,
        ),
        isNull,
      );
    });

    test('but being signed in leaves immediately', () {
      expect(
        authRedirect(
          step: AuthStep.authenticated,
          location: splashLocation,
          hasSignedIn: false,
          isSettled: false,
        ),
        '/home',
      );
    });

    test('and once it settles a signed-out reader goes to sign-in', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: splashLocation,
          hasSignedIn: false,
          isSettled: true,
        ),
        '/auth',
      );
    });

    // Only startup waits; a sign-out redirects immediately.
    test('a sign-out is never held back by it', () {
      expect(
        authRedirect(
          step: AuthStep.loading,
          location: '/home',
          hasSignedIn: true,
          isSettled: false,
        ),
        '/auth',
      );
    });
  });

  group('the splash is a waiting room, not a destination', () {
    test('a guest is sent into the shell', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: splashLocation,
          hasSignedIn: false,
          isGuest: true,
        ),
        '/home',
      );
    });

    test('and stays put anywhere they actually chose', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: '/auth',
          hasSignedIn: false,
          isGuest: true,
        ),
        isNull,
      );
    });

    test('legal pages are readable from it, signed out', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: '/legal/terms',
          hasSignedIn: false,
          isSettled: false,
        ),
        isNull,
      );
    });
  });

  // After sign-out the state can sit in `loading`; that must not keep the user
  // in the shell.
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

  // A guest has no session, so the signed-out rules must not apply.
  group('guest mode', () {
    test('a guest reaches the shell without a session', () {
      for (final location in ['/home', '/search', '/channels', '/messages']) {
        expect(
          authRedirect(
            step: AuthStep.loginMethodSelection,
            location: location,
            hasSignedIn: false,
            isGuest: true,
          ),
          isNull,
          reason: location,
        );
      }
    });

    test('a guest can still reach the sign-in screen', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: '/auth',
          hasSignedIn: false,
          isGuest: true,
        ),
        isNull,
      );
    });

    test('signing in still lands on the feed, guest flag or not', () {
      expect(
        authRedirect(
          step: AuthStep.authenticated,
          location: '/auth',
          hasSignedIn: true,
          isGuest: true,
        ),
        '/home',
      );
    });

    test('dropping the flag sends them back to sign-in', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: '/home',
          hasSignedIn: false,
          isGuest: false,
        ),
        '/auth',
      );
    });
  });

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

  group('guest routing', () {
    // The redirect leaves a guest on sign-in, so the browse button must
    // navigate itself.
    test('a guest on the sign-in screen is left there', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: '/auth',
          hasSignedIn: false,
          isGuest: true,
        ),
        isNull,
      );
    });

    test('a guest reaches the shell instead of being bounced to sign-in', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: '/home',
          hasSignedIn: false,
          isGuest: true,
        ),
        isNull,
      );
    });

    test('without the guest flag the shell still bounces to sign-in', () {
      expect(
        authRedirect(
          step: AuthStep.loginMethodSelection,
          location: '/home',
          hasSignedIn: false,
        ),
        '/auth',
      );
    });

    test('signing in from guest mode lands in the shell', () {
      expect(
        authRedirect(
          step: AuthStep.authenticated,
          location: '/auth',
          hasSignedIn: true,
          isGuest: false,
        ),
        '/home',
      );
    });
  });
}
