import 'package:flutter/material.dart';

import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The gramX mark, animating. Used wherever the app is busy and has nothing
/// yet to show: the splash, and the connecting screen behind sign-in.
///
/// Nothing here drives the animation. The asset is an animated WebP whose own
/// loop count is infinite, so `Image` plays it and keeps playing it — which is
/// also why a test must never `pumpAndSettle` through this widget.
///
/// Both screens that draw it are on the cold-start path, and the second gets
/// the frames the first already decoded: `ImageCache` is keyed by the asset, so
/// the handover costs nothing.
class BrandMark extends StatelessWidget {
  /// The side of the square the mark is drawn into. The artwork is portrait, so
  /// it fits to the height and leaves the width short of this.
  final double size;

  const BrandMark({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        BrandAssets.markAnimation,
        fit: BoxFit.contain,
        semanticLabel: AppStrings.appName,
        // Nothing if it fails. This sits on a screen that is already only a
        // holding pattern; a broken-image glyph there would say something about
        // the app that isn't true. The box above keeps its size either way, so
        // the wordmark under it does not move.
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}

/// The mark, flat and still, at a given height. The feed header's wordmark.
///
/// the same idea with gramX's own mark. Flat and monochrome rather than the
/// coloured mark the splash animates: that is how the brand draws its own
/// header, and on a row that already carries an avatar and a bell it is the
/// one that reads as a title. Which of the two it is follows
/// the theme — see [BrandAssets.glyphFor]. The artwork is portrait, so it is
/// sized by height and takes the width that gives it.
///
/// The default is sized for the 56-point header: tall enough that the mark
/// is the thing you see on the row, with a margin above and below that keeps
/// it off the avatar and the bell.
class BrandGlyph extends StatelessWidget {
  final double height;

  const BrandGlyph({super.key, this.height = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandAssets.glyphFor(Theme.of(context).brightness),
      height: height,
      fit: BoxFit.contain,
      semanticLabel: AppStrings.appName,
      // The word, if the picture cannot be had. Better than a broken glyph in
      // the one spot on the page that names the app.
      errorBuilder: (context, error, stackTrace) => Text(
        AppStrings.appName,
        style: TextStyle(
          fontSize: height * 0.75,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
