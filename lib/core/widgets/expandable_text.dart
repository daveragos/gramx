import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/text/text_clamp.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

export 'package:gramx/core/text/text_clamp.dart';

///
/// Only long posts get the control: a four-line post with a "Show more" that
/// reveals nothing is worse than no control at all.
class ExpandableText extends StatefulWidget {
  final String text;
  final List<TextEntity> entities;
  final TextStyle style;
  final ValueChanged<String>? onHashtagTap;
  final int maxLines;

  /// Colour for the toggle. Defaults to the accent.
  final Color? linkColor;

  const ExpandableText({
    super.key,
    required this.text,
    required this.entities,
    required this.style,
    this.onHashtagTap,
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
    // A recycled list item showing a different post must not inherit the
    // previous one's expanded state.
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final clampable =
        shouldClampText(widget.text, maxLines: widget.maxLines);
    final collapsed = clampable && !_expanded;

    final body = TextEntityRenderer(
      text: widget.text,
      entities: widget.entities,
      style: widget.style,
      onHashtagTap: widget.onHashtagTap,
      maxLines: collapsed ? widget.maxLines : null,
    );

    if (!clampable) return body;

    final label =
        _expanded ? AppStrings.postShowLess : AppStrings.postShowMore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label,
                style: AppTypography.body(
                  color: widget.linkColor ?? AppColors.accent,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
