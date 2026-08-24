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

  // A guest has no session and never will, so the signed-out rules above would
  // bounce them to sign-in forever. The shell has to stand on its own footing.
  group('guest mode', () {
    test('a guest reaches the shell without a session', () {
      for (final location in ['/home', '/search', '/channels', '/bookmarks']) {
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

    // Guest mode is a way in, not a one-way door.
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

    // Leaving guest mode has to strand nobody in the shell — the same fault
    // T8-37 fixed for a hung sign-out.
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

  group('guest routing', () {
    // The bug: entering guest mode set the flag and trusted the redirect to
    // move the reader. It cannot — a guest is deliberately allowed to stand on
    // the sign-in screen so they can stop being one, so the honest answer here
    // is "stay put" and the browse button has to navigate for itself.
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

    // Signing in wins over a leftover flag: isGuestModeProvider clears it, and
    // an authenticated reader sitting on /auth belongs in the shell.
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
