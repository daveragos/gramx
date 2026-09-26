import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/app/widgets/brand_mark.dart';
import 'package:gramx/core/l10n/app_strings.dart';

void main() {
  group('the brand mark animation', () {
    // The file is the designer's export, and nothing else in the app would
    // notice if it stopped being readable — the widget swallows a failed load
    // so the splash never shows a broken glyph. This is the check that would.
    //
    // It also pins the two properties that make it play on its own: more than
    // one frame, and a repetition count the framework reads as "forever". A
    // still image loads perfectly well and would sit there.
    testWidgets('is a moving image that loops by itself', (tester) async {
      final bytes = await rootBundle.load(BrandAssets.markAnimation);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
      );

      expect(codec.frameCount, greaterThan(1));
      expect(codec.repetitionCount, -1, reason: 'infinite');
    });

    testWidgets('names the app for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BrandMark()),
      ));
      // Not pumpAndSettle: the mark loops, so it never settles.
      await tester.pump();

      expect(find.bySemanticsLabel(AppStrings.appName), findsOneWidget);
      handle.dispose();
    });

    // It draws nothing until the first frame is decoded, which is the moment
    // the splash exists to fill. Laying out a zero-sized box there would move
    // the wordmark once the mark arrived.
    testWidgets('holds its size before the first frame arrives',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: BrandMark(size: 120))),
      ));

      expect(tester.getSize(find.byType(BrandMark)), const Size(120, 120));
    });
  });

  _glyphTests();

  group('the splash screen', () {
    testWidgets('carries the animated mark and the wordmark', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.byType(BrandMark), findsOneWidget);
      expect(find.text(AppStrings.appName), findsOneWidget);
    });

    // The mark's own motion replaced it. Two things moving on a screen that is
    // deliberately almost nothing read as two separate waits.
    testWidgets('has no spinner beside the mark', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

/// The header glyph follows the theme: the designer's boards draw it pale on
/// the dark screen and grey on the light one, and a pale mark on an off-white
/// header would be the one thing on the row you could not see.
void _glyphTests() {
  group('the header glyph', () {
    Future<String> assetShown(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const Scaffold(body: BrandGlyph()),
      ));
      final image = tester.widget<Image>(find.byType(Image));
      return (image.image as AssetImage).assetName;
    }

    testWidgets('is the pale mark on a dark theme', (tester) async {
      expect(
        await assetShown(tester, ThemeData.dark()),
        BrandAssets.glyphFor(Brightness.dark),
      );
    });

    testWidgets('is the grey mark on a light theme', (tester) async {
      expect(
        await assetShown(tester, ThemeData.light()),
        BrandAssets.glyphFor(Brightness.light),
      );
    });

    testWidgets('the two are different files', (tester) async {
      expect(
        BrandAssets.glyphFor(Brightness.dark),
        isNot(BrandAssets.glyphFor(Brightness.light)),
      );
    });
  });
}
