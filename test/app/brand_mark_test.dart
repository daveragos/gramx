import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/launch_reveal.dart';
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
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());

      expect(codec.frameCount, greaterThan(1));
      expect(codec.repetitionCount, -1, reason: 'infinite');
    });

    testWidgets('names the app for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BrandMark())),
      );
      // Not pumpAndSettle: the mark loops, so it never settles.
      await tester.pump();

      expect(find.bySemanticsLabel(AppStrings.appName), findsOneWidget);
      handle.dispose();
    });

    // It draws nothing until the first frame is decoded, which is the moment
    // the splash exists to fill. Laying out a zero-sized box there would move
    // the wordmark once the mark arrived.
    testWidgets('holds its size before the first frame arrives', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: BrandMark(size: 120))),
        ),
      );

      expect(tester.getSize(find.byType(BrandMark)), const Size(120, 120));
    });
  });

  _glyphTests();

  group('the splash screen', () {
    // LaunchReveal draws the mark above every route; the splash is the black
    // behind it. A mark here as well would be a second one to line up.
    testWidgets('draws nothing of its own', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.byType(BrandMark), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // Android's launch screen and the app's first frame have to draw the same
  // picture in the same place, or the mark jumps at the handover. They are
  // two files, a PNG under android/ and the numbers in LaunchMark, and nothing
  // but this would notice them drifting apart.
  group('the launch mark', () {
    Future<ui.Image> decode(Uint8List bytes) async {
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    }

    Future<Rect> opaqueBounds(ui.Image image) async {
      final data = await image.toByteData();
      final pixels = data!.buffer.asUint8List();
      var left = image.width, top = image.height, right = -1, bottom = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (pixels[(y * image.width + x) * 4 + 3] == 0) continue;
          left = math.min(left, x);
          right = math.max(right, x);
          top = math.min(top, y);
          bottom = math.max(bottom, y);
        }
      }
      return Rect.fromLTRB(
        left.toDouble(),
        top.toDouble(),
        right + 1.0,
        bottom + 1.0,
      );
    }

    testWidgets('is the visible part of the still artwork', (tester) async {
      await tester.runAsync(() async {
        final bytes = await rootBundle.load(BrandAssets.markStatic);
        final image = await decode(bytes.buffer.asUint8List());

        expect(await opaqueBounds(image), LaunchMark.source);
      });
    });

    // 288 dp is the square Android 12 draws a launch icon without a
    // background into.
    testWidgets('is the size and place Android draws it', (tester) async {
      await tester.runAsync(() async {
        final file = File(
          'android/app/src/main/res/drawable-nodpi/splash_mark.png',
        );
        final image = await decode(await file.readAsBytes());
        final bounds = await opaqueBounds(image);
        final dp = 288 / image.width;

        expect(image.width, image.height);
        expect(bounds.height * dp, closeTo(LaunchMark.height, 0.5));
        expect(bounds.width * dp, closeTo(LaunchMark.width, 0.5));
        expect(bounds.center.dx * dp, closeTo(144, 0.5));
        expect(bounds.center.dy * dp, closeTo(144, 0.5));
      });
    });

    // The zoom is centred on the anchor, and only a solid panel grows to
    // cover the screen.
    testWidgets('opens from a solid part of the ribbon', (tester) async {
      await tester.runAsync(() async {
        final bytes = await rootBundle.load(BrandAssets.markStatic);
        final image = await decode(bytes.buffer.asUint8List());
        final data = await image.toByteData();
        final source = LaunchMark.source;
        final x = (source.left + source.width * LaunchMark.anchor.dx).floor();
        final y = (source.top + source.height * LaunchMark.anchor.dy).floor();

        expect(data!.getUint8((y * image.width + x) * 4 + 3), 255);
      });
    });
  });
}

/// The header glyph follows the theme: pale on the dark screen and grey on
/// the light one, because a pale mark on an off-white header would be the one
/// thing on the row you could not see.
void _glyphTests() {
  group('the header glyph', () {
    Future<String> assetShown(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: BrandGlyph()),
        ),
      );
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
