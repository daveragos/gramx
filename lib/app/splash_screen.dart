import 'package:flutter/material.dart';

/// Where the app sits while it works out whether anybody is signed in.
///
/// It exists because the alternative was a *guess*. The router used to open
/// straight onto the feed and let the auth rules move the reader off it, which
/// meant that any authorization state TDLib announced on the way up — and it
/// announces several while it starts, some of them immediately superseded —
/// could paint the sign-in screen for a frame or two before the feed arrived.
/// That flash is what this removes: there is now a destination that means
/// "not decided yet", and it is neither of the two screens that would be wrong.
///
/// Nothing is drawn on it. While it is the route, `LaunchReveal` covers the
/// whole app with the launch screen's mark on black, and it opens the app
/// through that mark once the router has moved on; this is the black behind
/// it, in case a frame ever shows through.
class SplashScreen extends StatelessWidget {
  /// The route. Also the router's initial location, so it is the first thing
  /// every cold start lands on.
  static const String route = '/';

  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}
