import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_picker_overlay.dart';

/// The reaction button for posts and comments. Tapping with no reaction
/// opens the picker, tapping your own reaction removes it, and a long press
/// always opens the picker.
class ReactionControl extends ConsumerStatefulWidget {
  /// The post or comment being reacted to.
  final Post post;

  /// Colour when the user has not reacted.
  final Color color;

  /// Applies the choice. The caller handles optimistic state and the TDLib
  /// call.
  final ValueChanged<String> onSelectReaction;

  final double iconSize;
  final double emojiSize;
  final double? countFontSize;

  const ReactionControl({
    super.key,
    required this.post,
    required this.color,
    required this.onSelectReaction,
    this.iconSize = 18,
    this.emojiSize = 16,
    this.countFontSize,
  });

  @override
  ConsumerState<ReactionControl> createState() => _ReactionControlState();
}

class _ReactionControlState extends ConsumerState<ReactionControl> {
  /// Anchors the picker to this button. Held in state so it survives
  /// rebuilds.
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _showPicker() async {
    final post = widget.post;
    final renderBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final availableEmojis = await ref
        .read(feedRepositoryProvider)
        .getAvailableReactions(post.chatId);
    if (!mounted) return;

    ReactionPickerOverlay.show(
      context: context,
      targetRect: rect,
      availableEmojis: availableEmojis,
      selectedEmoji: post.chosenReactions.isNotEmpty
          ? post.chosenReactions.first
          : null,
      onEmojiSelected: widget.onSelectReaction,
    );
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    final chosen = widget.post.chosenReactions;
    if (chosen.isNotEmpty) {
      widget.onSelectReaction(chosen.first);
      return;
    }
    _showPicker();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final totalReactions = post.reactions.values.fold<int>(0, (a, b) => a + b);
    final hasOwnReaction = post.chosenReactions.isNotEmpty;
    // The user's own reaction, or else the most common one.
    final activeEmoji = hasOwnReaction
        ? post.chosenReactions.first
        : (post.reactions.keys.isNotEmpty ? post.reactions.keys.first : null);

    final countStyle = AppTypography.actionCount(
      color: hasOwnReaction ? AppColors.like : widget.color,
    ).copyWith(fontSize: widget.countFontSize);

    return KeyedSubtree(
      key: _anchorKey,
      child: Semantics(
        button: true,
        label: hasOwnReaction
            ? AppStrings.a11yCurrentReaction(post.chosenReactions.first)
            : AppStrings.a11yReact,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: _handleTap,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showPicker();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeEmoji != null)
                Text(activeEmoji, style: TextStyle(fontSize: widget.emojiSize))
              else
                // Filled only when the user has reacted.
                Icon(
                  hasOwnReaction ? Icons.favorite : Icons.favorite_border,
                  color: hasOwnReaction ? AppColors.like : widget.color,
                  size: widget.iconSize,
                ),
              if (totalReactions > 0) ...[
                const SizedBox(width: 4),
                Text(TimeUtils.formatCount(totalReactions), style: countStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
