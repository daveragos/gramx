import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/core/text/emoji_presentation.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';

class ReactionPickerOverlay extends StatelessWidget {
  final List<String> availableEmojis;
  final String? selectedEmoji;
  final ValueChanged<String> onEmojiSelected;

  static const List<String> defaultEmojis = [
    '👍',
    '\u2764', // TDLib's key for the heart has no U+FE0F.
    '🔥',
    '🎉',
    '👏',
    '😂',
    '😮',
    '😢',
    '💩',
    '🙏',
  ];

  const ReactionPickerOverlay({
    super.key,
    this.availableEmojis = defaultEmojis,
    this.selectedEmoji,
    required this.onEmojiSelected,
  });

  static void show({
    required BuildContext context,
    required Rect targetRect,
    List<String> availableEmojis = defaultEmojis,
    String? selectedEmoji,
    required ValueChanged<String> onEmojiSelected,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final double top = (targetRect.top - 60) < 40
            ? (targetRect.bottom + 8)
            : (targetRect.top - 60);

        return Stack(
          children: [
            Positioned(
              top: top,
              left: (targetRect.left - 40).clamp(16.0, screenSize.width - 280),
              child: Material(
                color: Colors.transparent,
                child: ReactionPickerOverlay(
                  availableEmojis: availableEmojis,
                  selectedEmoji: selectedEmoji,
                  onEmojiSelected: (emoji) {
                    Navigator.of(context).pop();
                    onEmojiSelected(emoji);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final screenWidth = MediaQuery.of(context).size.width;
    final emojis = availableEmojis.isEmpty ? defaultEmojis : availableEmojis;

    return Container(
      constraints: BoxConstraints(maxWidth: screenWidth - 32),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: emojis.map((emoji) {
            final isSelected = emoji == selectedEmoji;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();
                onEmojiSelected(emoji);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  emojiForDisplay(emoji),
                  style: emojiStyle(fontSize: isSelected ? 24 : 20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
