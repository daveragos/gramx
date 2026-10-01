import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

/// Where a cold start waits while the session's state is worked out.
const String splashLocation = SplashScreen.route;

/// Where a navigation should land given the session's state, or null to stay
/// put.
///
/// [hasSignedIn]: before any session, loading means TDLib has not answered
/// and the app waits; afterwards it means signing out and goes to sign-in.
/// [isGuest]: a user browsing without an account, who can reach the shell.
/// [isSettled]: false while TDLib passes through its startup authorization
/// states; until then only `authenticated` redirects.
String? authRedirect({
  required AuthStep step,
  required String location,
  required bool hasSignedIn,
  bool isGuest = false,
  bool isSettled = true,
}) {
  // Legal pages are linked from the sign-in screen.
  if (location.startsWith('/legal/')) return null;

  final isOnAuth = location == '/auth';
  final isOnSplash = location == splashLocation;

  if (step == AuthStep.authenticated) {
    return isOnAuth || isOnSplash ? '/home' : null;
  }

  // A guest on /auth may be signing in, so they stay put. Entering guest mode
  // navigates on its own (see auth_selection_page.dart).
  if (isGuest) return isOnSplash ? '/home' : null;

  // Startup, before the session is known: stay on the splash or deep link.
  if (!hasSignedIn && (step == AuthStep.loading || !isSettled)) return null;

  return isOnAuth ? null : '/auth';
}
