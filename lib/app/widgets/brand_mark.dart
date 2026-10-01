import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/app/widgets/mark_player.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The gramX mark, animating. Used wherever the app is busy and has nothing
/// yet to show: the connecting screen behind sign-in, and the feed while the
/// first channels arrive.
///
/// Played by [MarkPlayer], on the clock, and looped. An animated `Image` played
/// it before, and both screens are ones where the app is working hard — that
/// player fell to about half speed exactly when the mark was on screen.
///
/// Draws nothing until the first frame is decoded, at its full size, so what
/// sits under it does not move when the mark arrives — and nothing at all if
/// the file cannot be played: this sits on a screen that is already only a
/// holding pattern, and a broken-image glyph there would say something about
/// the app that is not true. A test must never `pumpAndSettle` through this
/// widget: it loops.
class BrandMark extends StatefulWidget {
  /// The side of the square the mark is drawn into. The artwork is portrait, so
  /// it fits to the height and leaves the width short of this.
  final double size;

  const BrandMark({super.key, this.size = 96});

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<ui.Image?> _frame = ValueNotifier(null);
  late final MarkPlayer _player = MarkPlayer(
    asset: BrandAssets.markAnimation,
    vsync: this,
    onFrame: (image) {
      // The painter reads the notifier when it paints, so the frame it
      // replaces is no longer drawn and can go now.
      _frame.value?.dispose();
      _frame.value = image;
    },
  );

  @override
  void initState() {
    super.initState();
    _player.start();
  }

  @override
  void dispose() {
    _player.stop();
    _frame.value?.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.appName,
      image: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _FramePainter(_frame)),
      ),
    );
  }
}

/// Draws the current frame, fitted inside the box and centred.
class _FramePainter extends CustomPainter {
  final ValueListenable<ui.Image?> frame;

  _FramePainter(this.frame) : super(repaint: frame);

  @override
  void paint(Canvas canvas, Size size) {
    final image = frame.value;
    if (image == null) return;
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate.frame != frame;
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
