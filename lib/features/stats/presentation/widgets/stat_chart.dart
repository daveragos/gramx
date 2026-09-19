import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';
import 'package:gramx/features/stats/presentation/stat_chart_geometry.dart';

/// One statistics graph, drawn.
///
/// abbreviated y axis, a handful of dates along the bottom, and a legend when
/// there is more than one series. The shape of each series is Telegram's own
/// choice — see [StatGraphShape] — so a growth chart is a line and a day's
/// joins are columns without this widget being told which is which.
///
/// here would mean either a real hit-test over every point or a control that
/// responds and says nothing, and the hard rules are clear about the second.
/// The numbers a reader actually needs are in the tiles above the chart.
class StatChart extends StatelessWidget {
  final StatGraph graph;

  /// Spoken description. A chart is unreachable without one.
  final String semanticLabel;

  final double height;

  const StatChart({
    super.key,
    required this.graph,
    required this.semanticLabel,
    this.height = 168,
  });

  /// Used for a series Telegram sent no colour for, in order.
  static const List<Color> fallbackPalette = [
    AppColors.accent,
    AppColors.repost,
    AppColors.like,
    AppColors.warning,
    AppColors.accentLight,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final grid = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final colors = [
      for (var i = 0; i < graph.lines.length; i++)
        graph.lines[i].color ?? fallbackPalette[i % fallbackPalette.length],
    ];

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (graph.lines.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 0; i < graph.lines.length; i++)
                    _LegendChip(label: graph.lines[i].name, color: colors[i]),
                ],
              ),
            ),
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: StatChartPainter(
                graph: graph,
                colors: colors,
                gridColor: grid,
                labelStyle: AppTypography.timestamp(color: secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

///
/// The swatch is not decoration: two lines on one chart are told apart by
/// colour and nothing else, which is exactly the case `docs/UI.md` says needs
/// a label rather than a hue.
class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.timestamp(color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }
}

/// Puts the ink where [StatChartGeometry] says.
///
/// Every arithmetic decision belongs to the geometry, which is testable
/// without a canvas; what is left here is stroking and filling.
@visibleForTesting
class StatChartPainter extends CustomPainter {
  final StatGraph graph;
  final List<Color> colors;
  final Color gridColor;
  final TextStyle labelStyle;

  /// Room for the y-axis labels, which sit outside the plot on the left.
  static const double leftGutter = 44;

  /// Room for the dates under it.
  static const double bottomGutter = 18;

  const StatChartPainter({
    required this.graph,
    required this.colors,
    required this.gridColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Size(
      (size.width - leftGutter).clamp(1.0, double.infinity),
      (size.height - bottomGutter).clamp(1.0, double.infinity),
    );
    final geometry = StatChartGeometry.of(graph, plot);
    if (geometry.isEmpty) return;

    _paintGrid(canvas, geometry, plot);

    canvas.save();
    canvas.translate(leftGutter, 0);
    _paintSeries(canvas, geometry);
    canvas.restore();

    _paintDates(canvas, geometry, plot);
  }

  void _paintGrid(Canvas canvas, StatChartGeometry geometry, Size plot) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (final value in geometry.gridValues()) {
      final y = geometry.yFor(value);
      canvas.drawLine(
        Offset(leftGutter, y),
        Offset(leftGutter + plot.width, y),
        paint,
      );

      final label = graph.isPercentage
          ? AppStrings.statsPercent(value.round().toString())
          : TimeUtils.formatCount(value.round());
      final painter = _text(label);
      painter.paint(
        canvas,
        Offset(leftGutter - painter.width - AppSpacing.xs, y - painter.height),
      );
    }
  }

  void _paintSeries(Canvas canvas, StatChartGeometry geometry) {
    // Grouped bars share a slot. Stacked ones do not — they sit on each
    // other's shoulders, which the geometry has already worked out.
    final barLines = [
      for (var i = 0; i < graph.lines.length; i++)
        if (graph.lines[i].shape.isColumnar) i,
    ];
    final grouped = !graph.isStacked && !graph.isPercentage;
    final slots = grouped ? barLines.length : 1;

    for (var index = 0; index < graph.lines.length; index++) {
      final line = graph.lines[index];
      final color = colors[index];

      if (line.shape.isColumnar) {
        final slot = grouped ? barLines.indexOf(index) : 0;
        _paintBars(canvas, geometry, index, color, slot, slots);
      } else {
        _paintStroke(canvas, geometry, index, color, line.shape);
      }
    }
  }

  void _paintBars(
    Canvas canvas,
    StatChartGeometry geometry,
    int index,
    Color color,
    int slot,
    int slots,
  ) {
    final paint = Paint()..color = color;

    for (var i = 0; i < geometry.pointCount; i++) {
      final rect = geometry.barRect(index, i, gap: 1);
      final width = rect.width / slots;
      final bar = Rect.fromLTRB(
        rect.left + width * slot,
        rect.top,
        rect.left + width * (slot + 1),
        rect.bottom,
      );
      // A bar for a real but tiny value must still be visible, or a quiet day
      // reads as a day with no data at all.
      final drawn = bar.height < 1 && geometry.plotted[index][i] != 0
          ? Rect.fromLTRB(bar.left, bar.bottom - 1, bar.right, bar.bottom)
          : bar;
      canvas.drawRect(drawn, paint);
    }
  }

  void _paintStroke(
    Canvas canvas,
    StatChartGeometry geometry,
    int index,
    Color color,
    StatGraphShape shape,
  ) {
    final path = Path();
    for (var i = 0; i < geometry.pointCount; i++) {
      final point = geometry.pointAt(index, i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        continue;
      }
      if (shape == StatGraphShape.step) {
        path.lineTo(point.dx, geometry.pointAt(index, i - 1).dy);
      }
      path.lineTo(point.dx, point.dy);
    }

    if (shape == StatGraphShape.area) {
      final fill = Path.from(path)
        ..lineTo(geometry.xAt(geometry.pointCount - 1), geometry.size.height)
        ..lineTo(geometry.xAt(0), geometry.size.height)
        ..close();
      canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.18));
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintDates(Canvas canvas, StatChartGeometry geometry, Size plot) {
    final first = geometry.dateAt(0);
    final last = geometry.dateAt(geometry.pointCount - 1);
    final span = last.difference(first);

    for (final index in geometry.labelIndices()) {
      final painter = _text(
        TimeUtils.axisLabel(geometry.dateAt(index), span),
      );
      // The first and last labels are pulled inside the plot so neither hangs
      // off the edge of the card.
      var x = leftGutter + geometry.xAt(index) - painter.width / 2;
      x = x.clamp(0.0, leftGutter + plot.width - painter.width);
      painter.paint(canvas, Offset(x, plot.height + AppSpacing.xs));
    }
  }

  TextPainter _text(String value) {
    return TextPainter(
      text: TextSpan(text: value, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(StatChartPainter old) =>
      old.graph != graph ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle ||
      !listEquals(old.colors, colors);
}
