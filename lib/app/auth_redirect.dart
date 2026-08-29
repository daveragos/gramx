import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

/// Where a cold start waits while the session's state is worked out.
const String splashLocation = SplashScreen.route;

/// Where a navigation should actually land, given the session's state.
///
/// Pure, because getting it wrong strands someone in a shell they are no
/// longer signed in to — which is exactly what happened: the rule let *any*
/// loading state stay where it was, so a sign-out whose request hung left the
/// reader looking at a signed-out feed, bottom bar and all, with no route to
/// the sign-in screen.
///
/// The distinction that fixes it is [hasSignedIn]: at startup, loading means
/// "TDLib hasn't answered yet" and the app should sit still rather than flash
/// a sign-in screen at someone who is signed in. Once a session has existed in
/// this run, loading means "the session is going away", and the sign-in screen
/// — which draws its own connecting state — is where that belongs.
///
/// Returns null to stay put.
///
/// [isGuest] is the reader who chose to browse without an account. They have
/// no session and never will, so the signed-out rules below would bounce them
/// to sign-in forever — the shell has to be reachable on its own footing. They
/// keep their way *to* the sign-in screen: guest mode is a way in, not a
/// one-way door.
///
/// [isSettled] is the second half of the same idea as [hasSignedIn], and it
/// closes the gap that one left. `loading` was treated as "TDLib has not
/// answered"; the trouble is that TDLib announces *several* authorization
/// states while it starts up, and a state that is not `loading` — a sign-in
/// step, superseded a moment later by `Ready` — was taken as a final answer.
/// The reader saw the sign-in screen flash by on the way to their own feed.
/// So before the session's state has settled, **nothing but `authenticated`
/// moves anybody**: the app waits on [splashLocation], which is neither of
/// the two screens that would be wrong.
String? authRedirect({
  required AuthStep step,
  required String location,
  required bool hasSignedIn,
  bool isGuest = false,
  bool isSettled = true,
}) {
  // Readable signed out: the sign-in screen links to them.
  if (location.startsWith('/legal/')) return null;

  final isOnAuth = location == '/auth';
  final isOnSplash = location == splashLocation;

  // The splash means "not decided yet", so an answer of any kind leaves it.
  if (step == AuthStep.authenticated) {
    return isOnAuth || isOnSplash ? '/home' : null;
  }

  // A guest goes wherever they asked, including to /auth to stop being one.
  //
  // Note this is deliberately "stay put" and not "go to /home": a guest
  // standing on the sign-in screen is a guest in the middle of upgrading, and
  // bouncing them off it would make that impossible. Entering guest mode
  // therefore has to navigate for itself — see the browse button in
  // auth_selection_page.dart. The one exception is the splash, which nobody
  // chose and which has nothing on it.
  if (isGuest) return isOnSplash ? '/home' : null;

  // Startup, before anything has been established. Both arms are "stay put":
  // on the splash that is the splash, and on a deep link it is the link.
  if (!hasSignedIn && (step == AuthStep.loading || !isSettled)) return null;

  return isOnAuth ? null : '/auth';
}
