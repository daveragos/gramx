import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// How the mark moves.
enum TrokMarkMotion {
  still,

  /// Blinks now and then, waiting for a question.
  idle,

  /// Looks around and blinks, while Trok works on an answer.
  thinking,
}

/// Trok's mark: an open eye, after Argus, the giant with a hundred of them.
class TrokMark extends StatefulWidget {
  final double size;

  /// Drawn in this colour; null draws the brand gradient.
  final Color? color;

  /// Solid, for a selected tab.
  final bool filled;
  final TrokMarkMotion motion;

  const TrokMark({
    super.key,
    this.size = 24,
    this.color,
    this.filled = false,
    this.motion = TrokMarkMotion.still,
  });

  @override
  State<TrokMark> createState() => _TrokMarkState();
}

class _TrokMarkState extends State<TrokMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(TrokMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) _run();
  }

  void _run() {
    switch (widget.motion) {
      case TrokMarkMotion.still:
        _clock
          ..stop()
          ..value = 0;
      case TrokMarkMotion.idle:
        _clock
          ..duration = const Duration(milliseconds: 4200)
          ..repeat();
      case TrokMarkMotion.thinking:
        _clock
          ..duration = const Duration(milliseconds: 1800)
          ..repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final t = _clock.value;
            final thinking = widget.motion == TrokMarkMotion.thinking;
            return CustomPaint(
              painter: _EyePainter(
                color: widget.color,
                filled: widget.filled,
                look: thinking ? math.sin(t * 2 * math.pi) : 0,
                open: switch (widget.motion) {
                  TrokMarkMotion.still => 1,
                  TrokMarkMotion.idle => _blink(t, at: 0.9),
                  TrokMarkMotion.thinking => _blink(t, at: 0.55),
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// How open the eye is at [t], shutting briefly from [at].
  static double _blink(double t, {required double at}) {
    const length = 0.07;
    if (t < at || t > at + length) return 1;
    return 1 - math.sin((t - at) / length * math.pi);
  }
}

class _EyePainter extends CustomPainter {
  final Color? color;
  final bool filled;

  /// Where the iris looks, from -1 (left) to 1 (right).
  final double look;

  /// 1 open, 0 shut.
  final double open;

  const _EyePainter({
    required this.color,
    required this.filled,
    required this.look,
    required this.open,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final bounds = Offset.zero & Size.square(s);

    final paint = Paint()..isAntiAlias = true;
    if (color != null) {
      paint.color = color!;
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.accent, AppColors.accentDark],
      ).createShader(bounds);
    }

    // Two lids meeting at the corners; each control point sits twice as far
    // out as the lid's peak.
    final lift = s * 0.44 * open;
    final eye = Path()
      ..moveTo(s * 0.06, s * 0.5)
      ..quadraticBezierTo(s * 0.5, s * 0.5 - lift, s * 0.94, s * 0.5)
      ..quadraticBezierTo(s * 0.5, s * 0.5 + lift, s * 0.06, s * 0.5)
      ..close();
    final iris = Offset(s * (0.5 + look * 0.1), s * 0.5);

    if (filled) {
      canvas.saveLayer(bounds, Paint());
      canvas.drawPath(eye, paint);
      canvas.clipPath(eye);
      canvas.drawCircle(iris, s * 0.17, Paint()..blendMode = BlendMode.clear);
      canvas.drawCircle(iris, s * 0.085, paint);
      canvas.restore();
      return;
    }

    canvas.drawPath(
      eye,
      Paint()
        ..isAntiAlias = true
        ..shader = paint.shader
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.08
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.save();
    canvas.clipPath(eye);
    canvas.drawCircle(iris, s * 0.14, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EyePainter old) =>
      old.color != color ||
      old.filled != filled ||
      old.look != look ||
      old.open != open;
}

/// The mark with Trok's name beside it, for headers.
class TrokWordmark extends StatelessWidget {
  final TrokMarkMotion motion;

  const TrokWordmark({super.key, this.motion = TrokMarkMotion.still});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: AppStrings.trokName,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrokMark(size: 28, motion: motion),
            const SizedBox(width: 6),
            Text(
              AppStrings.trokName,
              style: AppTypography.heading(
                color: Theme.of(context).colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
            ),
          ],
        ),
      ),
    );
  }
}
