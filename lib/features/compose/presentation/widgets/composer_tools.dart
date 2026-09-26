import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The buttons beside a message field, which fold away while somebody types.
///
/// A composer wants an attach button and a sticker button, and a field wide
/// enough to see what is being written. On a phone those three fight for the
/// same row, and with both buttons out the field was a slot two words wide.
/// the field is empty, because that is when somebody is choosing what to
/// send, and fold into a single chevron once words appear, because that is
/// when the words are the point. Tapping the chevron brings them back for
/// the reader who wants a picture mid-sentence.
///
/// This widget only draws the fold; the owner decides when, because the
/// owner has the text. [collapsed] true draws the chevron, false the tools.
class CollapsibleComposerTools extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onExpand;
  final List<Widget> tools;

  /// How long the fold takes. Quick — it happens on the first keystroke and
  /// must not lag behind the letter.
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

/// Whether the tools should be folded right now.
///
/// Pure, and the one rule both composers share: folded while there are words
/// and the reader has not asked for the tools back, and only when there is
/// more than one tool to fold — a single button folded into a single chevron
/// saves nothing and moves a control for no reason.
bool composerToolsFolded({
  required bool hasText,
  required bool expandedByHand,
  required int toolCount,
}) => hasText && !expandedByHand && toolCount > 1;
