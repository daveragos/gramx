import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/text/text_clamp.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

export 'package:gramx/core/text/text_clamp.dart';

/// Post text clamped to [maxLines], with "Show more" only when it is long.
class ExpandableText extends StatefulWidget {
  final String text;
  final List<TextEntity> entities;
  final TextStyle style;
  final ValueChanged<String>? onHashtagTap;

  /// See [TextEntityRenderer.onMediaTimestampTap].
  final ValueChanged<int>? onMediaTimestampTap;
  final int maxLines;

  /// Colour for the toggle. Defaults to the accent.
  final Color? linkColor;

  const ExpandableText({
    super.key,
    required this.text,
    required this.entities,
    required this.style,
    this.onHashtagTap,
    this.onMediaTimestampTap,
    this.maxLines = kCollapsedPostLines,
    this.linkColor,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  void didUpdateWidget(ExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled list item showing a different post starts collapsed.
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final clampable = shouldClampText(widget.text, maxLines: widget.maxLines);
    final collapsed = clampable && !_expanded;
    final linkStyle = AppTypography.body(
      color: widget.linkColor ?? AppColors.accent,
    );

    if (collapsed) {
      // Cut short, with "Show more" straight after the last word, as X shows
      // a long post.
      final shown = widget.text
          .substring(0, collapsedLength(widget.text, maxLines: widget.maxLines))
          .trimRight();
      return TextEntityRenderer(
        text: shown,
        entities: [
          for (final entity in widget.entities)
            if (entity.offset < shown.length) entity,
        ],
        style: widget.style,
        onHashtagTap: widget.onHashtagTap,
        onMediaTimestampTap: widget.onMediaTimestampTap,
        maxLines: widget.maxLines,
        fullWidth: true,
        trailing: [
          TextSpan(text: ' ', style: widget.style),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _Toggle(
              label: AppStrings.postShowMore,
              style: linkStyle,
              onTap: () => setState(() => _expanded = true),
            ),
          ),
        ],
      );
    }

    final body = TextEntityRenderer(
      text: widget.text,
      entities: widget.entities,
      style: widget.style,
      onHashtagTap: widget.onHashtagTap,
      onMediaTimestampTap: widget.onMediaTimestampTap,
      fullWidth: true,
    );
    if (!clampable) return body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _Toggle(
            label: AppStrings.postShowLess,
            style: linkStyle,
            onTap: () => setState(() => _expanded = false),
          ),
        ),
      ],
    );
  }
}

/// "Show more" or "Show less", in the link colour.
class _Toggle extends StatelessWidget {
  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  const _Toggle({
    required this.label,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(label, style: style),
      ),
    );
  }
}
