import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The buttons beside a message field, which fold into a chevron while the
/// user types so the field has room. Tapping the chevron brings them back.
///
/// The owner decides when to fold: [collapsed] true draws the chevron, false
/// the tools.
class CollapsibleComposerTools extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onExpand;
  final List<Widget> tools;

  /// How long the fold takes. Short, so it keeps up with the first keystroke.
  static const Duration duration = Duration(milliseconds: 160);

  const CollapsibleComposerTools({
    super.key,
    required this.collapsed,
    required this.onExpand,
    required this.tools,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: collapsed
          ? IconButton(
              key: const ValueKey('composer-tools-folded'),
              tooltip: AppStrings.chatComposerMoreTools,
              visualDensity: VisualDensity.compact,
              onPressed: onExpand,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.accent,
              ),
            )
          : Row(
              key: const ValueKey('composer-tools-open'),
              mainAxisSize: MainAxisSize.min,
              children: tools,
            ),
    );
  }
}

/// Whether the tools should be folded: there is text, the user hasn't
/// expanded them, and there is more than one tool to fold.
bool composerToolsFolded({
  required bool hasText,
  required bool expandedByHand,
  required int toolCount,
}) => hasText && !expandedByHand && toolCount > 1;
