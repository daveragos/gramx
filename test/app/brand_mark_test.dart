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
    // The widget hides a failed load, so this checks the asset decodes, has
    // several frames and loops forever.
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

    // Otherwise the layout would shift when the first frame decodes.
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
    // LaunchReveal draws the mark above every route.
    testWidgets('draws nothing of its own', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.byType(BrandMark), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // The launch opens the app through LaunchMark.formedFrame, so LaunchMark's
  // numbers must match that frame.
  group('the launch mark', () {
    Future<ui.Image> frame(int index) async {
      final bytes = await rootBundle.load(BrandAssets.markAnimation);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      late ui.Image image;
      for (var i = 0; i <= index; i++) {
        image = (await codec.getNextFrame()).image;
      }
      return image;
    }

    Future<Uint8List> pixels(ui.Image image) async =>
        (await image.toByteData())!.buffer.asUint8List();

    Future<Rect> opaqueBounds(ui.Image image) async {
      final data = await pixels(image);
      var left = image.width, top = image.height, right = -1, bottom = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (data[(y * image.width + x) * 4 + 3] == 0) continue;
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

    testWidgets('is the finished ribbon of the drawing', (tester) async {
      await tester.runAsync(() async {
        final formed = await frame(LaunchMark.formedFrame);

        expect(await opaqueBounds(formed), LaunchMark.source);
      });
    });

    testWidgets('is a frame the drawing has settled on', (tester) async {
      await tester.runAsync(() async {
        final formed = await pixels(await frame(LaunchMark.formedFrame));
        final later = await pixels(await frame(LaunchMark.formedFrame + 15));

        var difference = 0;
        for (var i = 3; i < formed.length; i += 4) {
          difference += (formed[i] - later[i]).abs();
        }
        expect(difference / (formed.length / 4), lessThan(1));
      });
    });

    // The zoom is centred on the anchor, and only a solid panel grows to
    // cover the screen.
    testWidgets('opens from a solid part of the ribbon', (tester) async {
      await tester.runAsync(() async {
        final formed = await frame(LaunchMark.formedFrame);
        final data = await pixels(formed);
        final source = LaunchMark.source;
        final x = (source.left + source.width * LaunchMark.anchor.dx).floor();
        final y = (source.top + source.height * LaunchMark.anchor.dy).floor();

        expect(data[(y * formed.width + x) * 4 + 3], 255);
      });
    });
  });
}

/// The header glyph is pale on a dark theme and grey on a light one.
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
