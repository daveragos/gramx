import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/app/widgets/mark_player.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The animated gramX mark, looped, for loading screens. It never settles,
/// so tests must not `pumpAndSettle` through it.
class BrandMark extends StatefulWidget {
  /// The side of the square the mark is fitted into.
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
      // The painter reads the notifier when painting, so this is safe.
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

/// The flat, still mark used as the feed header's title.
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
      // Falls back to the app name as text.
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
