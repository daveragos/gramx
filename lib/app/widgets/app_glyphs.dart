import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The drawn icons of a post's actions and the tab bar: one even line
/// weight, round joins and full, open shapes, which Material's icons lack.
enum AppGlyphs {
  reply,
  repost,
  like,
  views,
  bookmark,
  share,
  home,
  search,
  bell,
  more,
  newChat,
}

/// Draws an [AppGlyphs] the way [Icon] draws an [IconData], taking size and
/// colour from the surrounding [IconTheme] when not given.
class Glyph extends StatelessWidget {
  final AppGlyphs glyph;
  final double? size;
  final Color? color;

  /// The solid form, for a selected tab or a chosen action.
  final bool filled;

  /// The line weight in logical pixels. By default a twelfth of [size], so
  /// 1.5 at the action bar's 18 and 2 at the tab bar's 24.
  final double? strokeWidth;

  const Glyph(
    this.glyph, {
    super.key,
    this.size,
    this.color,
    this.filled = false,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? 24;
    final paint = color ?? iconTheme.color ?? const Color(0xFF000000);
    final drawn = SizedBox.square(
      dimension: side,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph: glyph,
          color: paint,
          filled: filled,
          strokeWidth: strokeWidth ?? side / 12,
        ),
      ),
    );
    // Centred at its own size when made to fill a larger box, as an Icon is
    // in a text field's prefix.
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: side,
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: side,
          maxHeight: side,
          child: drawn,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final AppGlyphs glyph;
  final Color color;
  final bool filled;
  final double strokeWidth;

  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.filled,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Every glyph is laid out on a 24-unit square.
    final scale = size.width / 24;
    canvas.scale(scale);
    final stroke = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case AppGlyphs.reply:
        final path = _reply();
        if (filled) canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case AppGlyphs.repost:
        canvas.drawPath(_repost(), stroke);
      case AppGlyphs.like:
        final path = _heart();
        if (filled) canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case AppGlyphs.views:
        canvas.drawPath(_bars(), stroke);
      case AppGlyphs.bookmark:
        final path = _bookmark();
        if (filled) canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case AppGlyphs.share:
        _share(canvas, stroke);
      case AppGlyphs.home:
        _home(canvas, stroke, fill);
      case AppGlyphs.search:
        _search(canvas, stroke);
      case AppGlyphs.bell:
        _bell(canvas, stroke, fill);
      case AppGlyphs.more:
        for (final y in const [6.0, 12.0, 18.0]) {
          canvas.drawCircle(Offset(12, y), 1.6, fill);
        }
      case AppGlyphs.newChat:
        canvas
          ..drawPath(_openBubble(), stroke)
          ..drawLine(const Offset(18.4, 15.2), const Offset(18.4, 22.0), stroke)
          ..drawLine(
            const Offset(15.0, 18.6),
            const Offset(21.8, 18.6),
            stroke,
          );
    }
  }

  /// A wide oval with its tail dropping from the lower left.
  static Path _reply() {
    const center = Offset(12, 10.7);
    const rx = 9.0, ry = 6.7;
    const tip = Offset(9.3, 20.6);
    final oval = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
    // Where the tail leaves the oval and where it rejoins it.
    const leave = 107.5 * math.pi / 180;
    const rejoin = 84.9 * math.pi / 180;
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        center.dx + rx * math.cos(leave),
        center.dy + ry * math.sin(leave),
      )
      ..arcTo(oval, leave, 2 * math.pi - (leave - rejoin), false)
      ..close();
  }

  /// Two arms chasing each other round a rectangle, one rising at the left,
  /// one falling at the right.
  static Path _repost() {
    const r = 2.0;
    return Path()
      // Left arm: head, then down and along the bottom.
      ..moveTo(1.4, 8.7)
      ..lineTo(4.7, 5.4)
      ..lineTo(8.0, 8.7)
      ..moveTo(4.7, 5.6)
      ..lineTo(4.7, 18.6 - r)
      ..arcToPoint(
        const Offset(4.7 + r, 18.6),
        radius: const Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(12.6, 18.6)
      // Right arm: along the top, then down to its head.
      ..moveTo(11.4, 5.4)
      ..lineTo(19.3 - r, 5.4)
      ..arcToPoint(
        const Offset(19.3, 5.4 + r),
        radius: const Radius.circular(r),
      )
      ..lineTo(19.3, 18.4)
      ..moveTo(16.0, 15.1)
      ..lineTo(19.3, 18.4)
      ..lineTo(22.6, 15.1);
  }

  /// A round bubble with its tail at the lower left, left open at the lower
  /// right for a plus.
  static Path _openBubble() {
    const center = Offset(11.2, 10.7);
    const r = 8.0;
    final circle = Rect.fromCircle(center: center, radius: r);
    Offset at(double degrees) {
      final a = degrees * math.pi / 180;
      return center + Offset(math.cos(a), math.sin(a)) * r;
    }

    const tip = Offset(3.0, 20.0);
    final start = at(95);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..arcTo(circle, 95 * math.pi / 180, 23 * math.pi / 180, false)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(at(150).dx, at(150).dy)
      ..arcTo(circle, 150 * math.pi / 180, 215 * math.pi / 180, false);
  }

  static Path _heart() => Path()
    ..moveTo(12, 19.9)
    ..cubicTo(12, 19.9, 3, 14.6, 3, 9.0)
    ..cubicTo(3, 6.3, 5.1, 4.3, 7.7, 4.3)
    ..cubicTo(9.6, 4.3, 11.2, 5.4, 12, 7.0)
    ..cubicTo(12.8, 5.4, 14.4, 4.3, 16.3, 4.3)
    ..cubicTo(18.9, 4.3, 21, 6.3, 21, 9.0)
    ..cubicTo(21, 14.6, 12, 19.9, 12, 19.9)
    ..close();

  /// Four bars standing on one line.
  static Path _bars() {
    const bottom = 19.5;
    const tops = [11.8, 4.5, 14.7, 8.8];
    final path = Path();
    for (var i = 0; i < tops.length; i++) {
      final x = 5.4 + i * 4.39;
      path
        ..moveTo(x, bottom)
        ..lineTo(x, tops[i]);
    }
    return path;
  }

  static Path _bookmark() {
    const r = 2.0;
    return Path()
      ..moveTo(4.95, 20.3)
      ..lineTo(4.95, 3.7 + r)
      ..arcToPoint(
        const Offset(4.95 + r, 3.7),
        radius: const Radius.circular(r),
      )
      ..lineTo(19.05 - r, 3.7)
      ..arcToPoint(
        const Offset(19.05, 3.7 + r),
        radius: const Radius.circular(r),
      )
      ..lineTo(19.05, 20.3)
      ..lineTo(12, 15.7)
      ..close();
  }

  /// Three rings, the left one joined to the other two.
  static void _share(Canvas canvas, Paint stroke) {
    const r = 2.4;
    const top = Offset(17.6, 5.9);
    const left = Offset(6.4, 12);
    const bottom = Offset(17.6, 18.1);
    for (final c in const [top, left, bottom]) {
      canvas.drawCircle(c, r, stroke);
    }
    void link(Offset a, Offset b) {
      final d = b - a;
      final unit = d / d.distance;
      canvas.drawLine(a + unit * r, b - unit * r, stroke);
    }

    link(left, top);
    link(left, bottom);
  }

  /// A house with an arched door; solid when [filled], with the door cut out.
  void _home(Canvas canvas, Paint stroke, Paint fill) {
    final house = _roundedPolygon(const [
      Offset(12, 3),
      Offset(21, 9.6),
      Offset(21, 21),
      Offset(3, 21),
      Offset(3, 9.6),
    ], 2.2);
    if (filled) {
      final door = Path()
        ..moveTo(9.6, 22.5)
        ..lineTo(9.6, 16.6)
        ..arcToPoint(
          const Offset(14.4, 16.6),
          radius: const Radius.circular(2.4),
        )
        ..lineTo(14.4, 22.5)
        ..close();
      // In a layer of its own, so cutting the door out of the stroke leaves
      // what is behind the icon.
      canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
      canvas
        ..drawPath(house, fill)
        ..drawPath(house, stroke)
        ..drawPath(door, Paint()..blendMode = BlendMode.clear);
      canvas.restore();
      return;
    }
    canvas.drawPath(house, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(9.6, 21)
        ..lineTo(9.6, 16.6)
        ..arcToPoint(
          const Offset(14.4, 16.6),
          radius: const Radius.circular(2.4),
        )
        ..lineTo(14.4, 21),
      stroke,
    );
  }

  void _search(Canvas canvas, Paint stroke) {
    // Selected, the lens is drawn heavier rather than filled.
    if (filled) stroke.strokeWidth *= 1.3;
    canvas
      ..drawCircle(const Offset(10.6, 10.6), 7.4, stroke)
      ..drawLine(const Offset(16.0, 16.0), const Offset(21.2, 21.2), stroke);
  }

  void _bell(Canvas canvas, Paint stroke, Paint fill) {
    final body = Path()
      ..moveTo(3.7, 17.4)
      ..cubicTo(5.0, 16.6, 5.6, 15.6, 5.6, 14.0)
      ..lineTo(5.6, 10.0)
      ..cubicTo(5.6, 6.1, 8.5, 3.0, 12, 3.0)
      ..cubicTo(15.5, 3.0, 18.4, 6.1, 18.4, 10.0)
      ..lineTo(18.4, 14.0)
      ..cubicTo(18.4, 15.6, 19.0, 16.6, 20.3, 17.4)
      ..close();
    final clapper = Path()
      ..moveTo(9.4, 17.6)
      ..arcToPoint(
        const Offset(14.6, 17.6),
        radius: const Radius.circular(2.6),
        clockwise: false,
      );
    if (filled) {
      canvas.drawPath(body, fill);
      canvas.drawPath(clapper..close(), fill);
    }
    canvas
      ..drawPath(body, stroke)
      ..drawPath(clapper, stroke);
  }

  /// [points] joined in order, each corner rounded by [radius].
  static Path _roundedPolygon(List<Offset> points, double radius) {
    final path = Path();
    final n = points.length;
    for (var i = 0; i < n; i++) {
      final prev = points[(i - 1 + n) % n];
      final corner = points[i];
      final next = points[(i + 1) % n];
      final inDir = (corner - prev) / (corner - prev).distance;
      final outDir = (next - corner) / (next - corner).distance;
      final start = corner - inDir * radius;
      final end = corner + outDir * radius;
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(corner.dx, corner.dy, end.dx, end.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.filled != filled ||
      old.strokeWidth != strokeWidth;
}
