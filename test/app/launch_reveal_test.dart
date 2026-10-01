import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/launch_reveal.dart';
import 'package:gramx/app/router.dart';
import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// The cover LaunchReveal paints over the app, found by where it sits.
Finder _cover() => find.descendant(
  of: find.byType(LaunchReveal),
  matching: find.byType(CustomPaint),
);

void main() {
  // A guest's home does not wait on the feed, so these run the reveal without
  // standing up TDLib.
  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: SplashScreen.route,
      routes: [
        GoRoute(
          path: SplashScreen.route,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('feed')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(router),
          isGuestModeProvider.overrideWithValue(true),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => LaunchReveal(child: child!),
        ),
      ),
    );
    return router;
  }

  testWidgets('covers the app while it is still on the splash', (tester) async {
    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(_cover(), findsWidgets);
  });

  // The router moves on from inside its own notification; opening the app
  // from there must not rebuild anything mid-build.
  testWidgets('opens the app once the router leaves the splash', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    router.go('/home');
    await tester.pump();
    // The ribbon finishes forming first; a test cannot decode the drawing, so
    // this is the limit that lets the app open without it.
    await tester.pump(LaunchMark.drawingLimit);
    await tester.pump(const Duration(seconds: 1));

    expect(_cover(), findsNothing);
    expect(find.text('feed'), findsOneWidget);
  });

  testWidgets('waits for the ribbon to finish forming', (tester) async {
    final router = await pumpApp(tester);

    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(_cover(), findsWidgets);
  });

  testWidgets('with reduced motion, simply fades', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = await pumpApp(tester);

    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_cover(), findsNothing);
  });

  // Nothing to tap until the app shows through, and everything after.
  testWidgets('lets touches through once the reveal starts', (tester) async {
    final router = await pumpApp(tester);
    router.go('/home');
    await tester.pump();
    await tester.pump(LaunchMark.drawingLimit);
    await tester.pump(const Duration(milliseconds: 100));

    final ignoring = tester
        .widgetList<IgnorePointer>(
          find.descendant(
            of: find.byType(LaunchReveal),
            matching: find.byType(IgnorePointer),
          ),
        )
        .any((widget) => widget.ignoring);
    expect(ignoring, isTrue);
  });
}
