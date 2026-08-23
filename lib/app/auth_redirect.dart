import 'package:gramx/features/auth/presentation/auth_providers.dart';

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
String? authRedirect({
  required AuthStep step,
  required String location,
  required bool hasSignedIn,
}) {
  // Readable signed out: the sign-in screen links to them.
  if (location.startsWith('/legal/')) return null;

  final isOnAuth = location == '/auth';
  if (step == AuthStep.authenticated) return isOnAuth ? '/home' : null;

  if (step == AuthStep.loading && !hasSignedIn) return null;

  return isOnAuth ? null : '/auth';
}
