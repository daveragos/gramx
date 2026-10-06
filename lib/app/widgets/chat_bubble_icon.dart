import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Messages tab's icon: a round speech bubble with its tail at the bottom
/// left, outlined, or solid when [filled]. Takes size and color from the
/// surrounding [IconTheme], like an [Icon].
class ChatBubbleIcon extends StatelessWidget {
  final bool filled;

  const ChatBubbleIcon({super.key, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return CustomPaint(
      size: Size.square(size),
      painter: _ChatBubblePainter(
        color: theme.color ?? DefaultTextStyle.of(context).style.color!,
        filled: filled,
      ),
    );
  }
}

class _ChatBubblePainter extends CustomPainter {
  final Color color;
  final bool filled;

  const _ChatBubblePainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 24-unit grid, the size Material icons are designed on.
    final scale = size.width / 24;
    canvas.scale(scale);

    const center = Offset(12.6, 11.4);
    const radius = 8.6;
    const tip = Offset(3.4, 20.6);
    // Where the tail leaves and rejoins the circle, either side of the tip.
    const tailStart = 158 * math.pi / 180;
    const tailEnd = 112 * math.pi / 180;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        center.dx + radius * math.cos(tailStart),
        center.dy + radius * math.sin(tailStart),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        tailStart,
        2 * math.pi - (tailStart - tailEnd),
        false,
      )
      ..close();

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
    if (filled) {
      // The stroke as well, so the solid icon is as large as the outline.
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_ChatBubblePainter old) =>
      old.color != color || old.filled != filled;
}
