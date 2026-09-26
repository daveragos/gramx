import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

/// A poll, drawn and votable.
///
/// Deliberately knows nothing about where the poll came from. It used to reach
/// into the feed's own provider to record a vote, which is why a poll in a
/// conversation could not use it — and a conversation is now the second place
/// polls appear. [onVote] is the whole of its relationship with the outside:
/// the caller decides what a vote *means* (optimistic update, then the
/// request), and this decides what it looks like.
///
/// [FeedPollCard] is the feed's binding of that callback, so the feed's call
/// sites did not have to learn the plumbing.
class PollCard extends StatefulWidget {
  final Poll poll;

  /// Records the reader's answer. The options are indices into [Poll.options].
  final Future<void> Function(List<int> optionIds) onVote;

  /// Drops the card's own border and fill.
  ///
  /// A chat bubble is already a surface, and a bordered box drawn inside one is
  /// a box inside a box — which is what Telegram avoids by letting the poll
  /// simply be the bubble's contents.
  final bool isEmbedded;

  /// The bubble's own foreground, when embedded. An outgoing bubble *is* the
  /// accent colour, so a poll drawn in accent-on-accent is invisible.
  final Color? foregroundColor;
  final Color? mutedColor;

  /// What a chosen option and the progress bars are tinted with. Falls back to
  /// the app accent, which is right everywhere except on an outgoing bubble.
  final Color? accentColor;

  const PollCard({
    super.key,
    required this.poll,
    required this.onVote,
    this.isEmbedded = false,
    this.foregroundColor,
    this.mutedColor,
    this.accentColor,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  bool _isVoting = false;

  /// What the reader has ticked but not yet sent, on a multiple-answer poll.
  ///
  /// Empty for every other poll, where a tap *is* the vote. Telegram splits the
  /// two the same way, and it has to: with several answers allowed there is no
  /// other moment at which the reader can say they are finished choosing.
  final Set<int> _selected = {};

  bool get _hasVoted => widget.poll.chosenOptionIds.isNotEmpty;

  bool get _isMultiple =>
      widget.poll.allowsMultipleAnswers && !widget.poll.isQuiz;

  Future<void> _submit(List<int> optionIds) async {
    if (_isVoting || widget.poll.isClosed || _hasVoted) return;
    if (optionIds.isEmpty) return;

    setState(() => _isVoting = true);
    try {
      await widget.onVote(optionIds);
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

  void _onOptionTap(int index) {
    if (_isVoting || widget.poll.isClosed || _hasVoted) return;

    if (_isMultiple) {
      setState(() {
        if (!_selected.remove(index)) _selected.add(index);
      });
      return;
    }
    _submit([index]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = widget.foregroundColor ?? theme.colorScheme.onSurface;
    final secondaryColor =
        widget.mutedColor ??
        (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accent = widget.accentColor ?? AppColors.accent;

    final isClosed = widget.poll.isClosed;
    final showResults = _hasVoted || isClosed;

    final body = Column(
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
                ? _buildResultOption(
                    idx,
                    option,
                    isChosen,
                    primaryColor,
                    secondaryColor,
                    accent,
                  )
                : _buildInteractiveOption(idx, option, primaryColor, accent),
          );
        }),
        // Only a multiple-answer poll has a moment between choosing and
        // voting. Everywhere else the tap already did it, and a button that
        // does nothing is a control that lies.
        if (_isMultiple && !showResults)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TextButton(
              onPressed: _selected.isEmpty || _isVoting
                  ? null
                  : () => _submit(_selected.toList()..sort()),
              style: TextButton.styleFrom(foregroundColor: accent),
              child: const Text(AppStrings.pollVote),
            ),
          ),
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
              widget.poll.isQuiz ? AppStrings.pollQuiz : AppStrings.pollPoll,
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
                AppStrings.pollFinalResults,
                style: AppTypography.actionCount(color: accent),
              ),
            ],
          ],
        ),
      ],
    );

    if (widget.isEmbedded) return body;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 0.5),
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      child: body,
    );
  }

  Widget _buildInteractiveOption(
    int index,
    PollOption option,
    Color primaryColor,
    Color accent,
  ) {
    final isSelected = _selected.contains(index);

    return InkWell(
      onTap: () => _onOptionTap(index),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(24),
          color: isSelected ? accent.withValues(alpha: 0.15) : null,
        ),
        child: Row(
          children: [
            // The tick is the only thing that says a selection was registered
            // on a multiple-answer poll, where the vote has not gone yet.
            if (_isMultiple) ...[
              Icon(
                isSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                option.text,
                style: AppTypography.body(
                  color: primaryColor,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (_isVoting)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
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
    Color accent,
  ) {
    final pct = option.votePercentage;
    final displayPercent = '${pct.toStringAsFixed(0)}%';

    Color barColor = accent.withValues(alpha: 0.15);
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
      barColor = accent.withValues(alpha: 0.3);
      textColor = accent;
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
                  color: isChosen
                      ? accent.withValues(alpha: 0.5)
                      : Colors.transparent,
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
                          fontWeight: isChosen
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      displayPercent,
                      style: AppTypography.body(color: textColor).copyWith(
                        fontWeight: isChosen
                            ? FontWeight.bold
                            : FontWeight.normal,
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

/// A [PollCard] wired to the feed.
///
/// The optimistic update and the `SetPollAnswer` that used to live inside the
/// card, moved out to the one surface that has a feed provider to update.
class FeedPollCard extends ConsumerWidget {
  final Poll poll;
  final String channelId;
  final int messageId;

  const FeedPollCard({
    super.key,
    required this.poll,
    required this.channelId,
    required this.messageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PollCard(
      poll: poll,
      onVote: (optionIds) async {
        final chatId = int.tryParse(channelId);
        final postId = chatId != null ? '${chatId}_$messageId' : channelId;

        // Instant, then persisted. The real counts arrive back on
        // `updateMessageContent` and replace these.
        ref
            .read(feedPostsProvider.notifier)
            .votePollOptimistic(postId, optionIds);

        if (chatId != null && chatId != 0) {
          await ref
              .read(syncServiceProvider)
              .voteInPoll(
                chatId: chatId,
                messageId: messageId,
                optionIds: optionIds,
              );
        }
      },
    );
  }
}
