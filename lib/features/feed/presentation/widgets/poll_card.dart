import 'package:flutter/material.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

class PollCard extends ConsumerStatefulWidget {
  final Poll poll;
  final String channelId;
  final int messageId;

  const PollCard({
    super.key,
    required this.poll,
    required this.channelId,
    required this.messageId,
  });

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  bool _isVoting = false;

  Future<void> _onOptionTap(int optionIndex) async {
    if (_isVoting || widget.poll.isClosed || widget.poll.chosenOptionIds.isNotEmpty) return;

    setState(() => _isVoting = true);

    try {
      final chatIdInt = int.tryParse(widget.channelId);
      final compositePostId = chatIdInt != null ? '${chatIdInt}_${widget.messageId}' : widget.channelId;

      // 1. Instant optimistic UI update
      ref.read(feedPostsProvider.notifier).votePollOptimistic(compositePostId, [optionIndex]);

      // 2. Persist asynchronously via TDLib
      if (chatIdInt != null && chatIdInt != 0) {
        await ref.read(syncServiceProvider).voteInPoll(
          chatId: chatIdInt,
          messageId: widget.messageId,
          optionIds: [optionIndex],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.pollVoteFailed(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final hasVoted = widget.poll.chosenOptionIds.isNotEmpty;
    final isClosed = widget.poll.isClosed;
    final showResults = hasVoted || isClosed;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 0.5),
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.poll.question,
            style: AppTypography.subheading(color: primaryColor),
          ),
          const SizedBox(height: AppSpacing.md),
          ...widget.poll.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final option = entry.value;
            final isChosen = widget.poll.chosenOptionIds.contains(idx);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: showResults
                  ? _buildResultOption(idx, option, isChosen, primaryColor, secondaryColor)
                  : _buildInteractiveOption(idx, option, primaryColor),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                AppStrings.pollVoteCount(
                  TimeUtils.formatCount(widget.poll.totalVoterCount),
                ),
                style: AppTypography.actionCount(color: secondaryColor),
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.inlineSeparatorBare,
                style: TextStyle(color: secondaryColor),
              ),
              const SizedBox(width: 8),
              Text(
                widget.poll.isQuiz ? 'Quiz' : 'Poll',
                style: AppTypography.actionCount(color: secondaryColor),
              ),
              if (isClosed) ...[
                const SizedBox(width: 8),
                Text(
                AppStrings.inlineSeparatorBare,
                style: TextStyle(color: secondaryColor),
              ),
                const SizedBox(width: 8),
                Text(
                  'Final results',
                  style: AppTypography.actionCount(color: AppColors.accent),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveOption(int index, PollOption option, Color primaryColor) {
    return InkWell(
      onTap: () => _onOptionTap(index),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.text,
                style: AppTypography.body(color: primaryColor).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (_isVoting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultOption(
    int index,
    PollOption option,
    bool isChosen,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final pct = option.votePercentage;
    final displayPercent = '${pct.toStringAsFixed(0)}%';

    Color barColor = AppColors.accent.withValues(alpha: 0.15);
    Color textColor = primaryColor;
    IconData? optionIcon;

    if (widget.poll.isQuiz) {
      final isCorrect = index == widget.poll.correctOptionId;
      if (isCorrect) {
        barColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green[700]!;
        optionIcon = Icons.check_circle_outline;
      } else if (isChosen) {
        barColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        optionIcon = Icons.highlight_off;
      }
    } else if (isChosen) {
      barColor = AppColors.accent.withValues(alpha: 0.3);
      textColor = AppColors.accent;
      optionIcon = Icons.check;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth * (pct / 100);

        return Stack(
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isChosen ? AppColors.accent.withValues(alpha: 0.5) : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]
                    : Colors.grey[100],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              width: barWidth,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: barColor,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    if (optionIcon != null) ...[
                      Icon(optionIcon, color: textColor, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        option.text,
                        style: AppTypography.body(color: textColor).copyWith(
                          fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      displayPercent,
                      style: AppTypography.body(color: textColor).copyWith(
                        fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
