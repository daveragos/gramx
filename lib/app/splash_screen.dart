import 'package:flutter/material.dart';

/// The route shown while the app works out whether anyone is signed in, so a
/// transient TDLib authorization state cannot flash the wrong screen.
///
/// It is plain black; `LaunchReveal` draws the mark over it.
class SplashScreen extends StatelessWidget {
  /// The route, and the router's initial location.
  static const String route = '/';

  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}
