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
