import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/expandable_text.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/reply_presentation.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/feed/presentation/widgets/link_preview_card.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/feed/presentation/widgets/reply_target.dart';
import 'package:gramx/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

class PostCard extends ConsumerWidget {
  final Post post;
  final bool isHighlighted;

  /// Whether to draw the hairline that closes the card.
  ///
  /// A thread draws its own after the "earlier posts" toggle, so the post it
  /// belongs to must not close the group early.
  final bool showDivider;
  final VoidCallback? onTap;
  final VoidCallback? onChannelTap;
  final VoidCallback? onBookmarkTap;
  final ValueChanged<String>? onLikeEmojiTap;
  final VoidCallback? onShareTap;

  const PostCard({
    super.key,
    required this.post,
    this.isHighlighted = false,
    this.showDivider = true,
    this.onTap,
    this.onChannelTap,
    this.onBookmarkTap,
    this.onLikeEmojiTap,
    this.onShareTap,
  });

  /// Opens what a forwarded post came from.
  ///
  /// Three cases, in descending order of usefulness:
  ///  1. Telegram told us the original post — open that post directly.
  ///  2. We only know the channel — open the channel.
  ///  3. The origin was hidden (a private channel, or a sender who forbids
  ///     linking) — say so, rather than doing nothing on tap.
  void _handleForwardedTap(BuildContext context, WidgetRef ref) {
    final chatId = post.forwardedFromChatId;
    final messageId = post.forwardedFromMessageId;

    if (chatId != null && messageId != null) {
      context.push('/post/${chatId}_$messageId');
      return;
    }

    if (chatId != null) {
      NavigationUtils.openChannel(context, chatId);
      return;
    }

    final title = post.forwardedFromTitle;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(title != null
            ? AppStrings.feedPrivateChannel(title)
            : AppStrings.feedOriginalChannelUnavailable),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    // Read state is NOT marked here. Flutter builds list items ahead of the
    // viewport, so doing it in build() marked posts the user never saw — and
    // ViewMessages propagates that to every Telegram client they own.
    // FeedFocusController handles it, after a real on-screen dwell.

    final defaultBookmarkHandler = onBookmarkTap ?? () {
      ref.read(optimisticPostUpdatesProvider.notifier).toggleBookmark(post.id, post);
      ref.read(feedPostsProvider.notifier).toggleBookmarkOptimistic(post.id);
      ref.read(feedRepositoryProvider).toggleBookmark(post.chatId, post.messageId);
      ref.invalidate(bookmarkedPostsProvider);
    };

    void defaultReactionHandler(String emoji) {
      if (onLikeEmojiTap != null) {
        onLikeEmojiTap!(emoji);
        return;
      }
      ref.read(optimisticPostUpdatesProvider.notifier).toggleReaction(post.id, emoji, post);
      ref.read(feedPostsProvider.notifier).toggleReactionOptimistic(post.id, emoji);

      ref.read(syncServiceProvider).togglePostReaction(
        chatId: post.chatId,
        messageId: post.messageId,
        reactionEmoji: emoji,
        isCurrentlyLiked: post.chosenReactions.contains(emoji),
      );
    }

    void defaultReplyHandler() {
      if (post.hasDiscussionGroup) {
        context.push('/post/${post.id}?focusReply=true');
      } else {
        context.push('/post/${post.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.feedCommentsDisabled),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    final defaultShareHandler = onShareTap ?? () async {
      final messenger = ScaffoldMessenger.of(context);
      final link = await ref.read(feedRepositoryProvider).postLink(post);
      if (link == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(AppStrings.postNotLinkable),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: link));
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.postLinkCopied),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    };

    final forwardedText = post.forwardedFromTitle ?? post.forwardedFromUsername ?? (post.forwardedFromChatId != null ? 'Original Channel' : null);

    return InkWell(
      onTap: onTap ?? defaultReplyHandler,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.accent.withValues(alpha: 0.12)
              : theme.scaffoldBackgroundColor,
          border: isHighlighted
              ? Border.all(color: AppColors.accent, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            // A quoted passage stands above the post that answers it, on a
            // connector running down into this card's own avatar — so it is
            // drawn here rather than inside the column below. See
            // QuotedPassage.
            if (showsQuotedPassage)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.postPadding,
                  AppSpacing.postPadding,
                  AppSpacing.postPadding,
                  0,
                ),
                child: _quotedPassage(context),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.postPadding,
                // The passage above already opened the card; a second top
                // padding here would break the connector's run.
                showsQuotedPassage ? 0 : AppSpacing.postPadding,
                AppSpacing.postPadding,
                AppSpacing.postPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular avatar on top left
                  ChannelAvatar(
                    title: post.channelTitle,
                    avatarPath: post.channelAvatarUrl,
                    avatarFileId: post.channelAvatarFileId,
                    avatarColorHex: post.channelAvatarColor,
                    onTap: onChannelTap ?? () => NavigationUtils.openChannel(context, post.channelId),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + Username + Timestamp Header Row
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: onChannelTap ?? () => NavigationUtils.openChannel(context, post.channelId),
                                child: Text(
                                  post.channelTitle,
                                  style: AppTypography.displayName(color: primaryTextColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (post.isChannelVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: AppColors.verified,
                                size: 16,
                              ),
                            ],
                            const SizedBox(width: 4),
                            if (post.channelUsername != null) ...[
                              Flexible(
                                child: Text(
                                  '@${post.channelUsername}',
                                  style: AppTypography.username(color: secondaryColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                             if (post.authorSignature != null && post.authorSignature!.isNotEmpty) ...[
                               Text(
                                 '@${post.authorSignature}',
                                 style: AppTypography.actionCount(color: AppColors.accent)
                                     .copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
                               ),
                               const SizedBox(width: 4),
                             ],
                             Text(
                               '·',
                               style: AppTypography.username(color: secondaryColor),
                             ),
                             const SizedBox(width: 4),
                             Text(
                               TimeUtils.relativeTime(post.publishedAt),
                               style: AppTypography.timestamp(color: secondaryColor),
                             ),
                             if (!post.isRead) ...[
                               const SizedBox(width: 6),
                               // State carried by colour alone needs a label.
                               Semantics(
                                 label: AppStrings.a11yUnread,
                                 child: Container(
                                   width: 7,
                                   height: 7,
                                   decoration: const BoxDecoration(
                                     color: AppColors.accent,
                                     shape: BoxShape.circle,
                                   ),
                                 ),
                               ),
                             ],
                          ],
                        ),

                        // Clickable Forwarded Banner Header
                        if (forwardedText != null && forwardedText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          GestureDetector(
                            onTap: () => _handleForwardedTap(context, ref),
                            child: Row(
                              children: [
                                Icon(Icons.repeat, size: 13, color: AppColors.repost),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Forwarded from $forwardedText',
                                    style: AppTypography.actionCount(color: AppColors.accent).copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // "Replying to Ada" — context for words not read yet,
                        // so it goes before them. The quote card is the other
                        // shape and sits below the body; see ReplySlot.
                        ReplyTarget(
                          post: post,
                          onOpenPost: () => _openReplyTarget(context),
                          onOpenAuthor: () => NavigationUtils.openChannel(
                              context, post.channelId),
                        ),

                        // Text content with link launcher. Long posts clamp
                        // with a "Show more" rather than pushing every other
                        // channel off the screen.
                        if (post.text != null && post.text!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          ExpandableText(
                            onHashtagTap: (tag) =>
                                openHashtagSearch(context, ref, tag),
                            text: post.text!,
                            entities: post.entities,
                            style: AppTypography.body(color: primaryTextColor),
                          ),
                        ],

                        // Content this build can't draw. The label alone was a
                        // dead end; Telegram itself can still show it.
                        if (post.unsupportedKind != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _OpenInTelegramButton(post: post),
                        ],

                        // Link preview
                        if (post.linkPreviewUrl != null && post.linkPreviewUrl!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          LinkPreviewCard(
                            url: post.linkPreviewUrl!,
                            title: post.linkPreviewTitle,
                            description: post.linkPreviewDescription,
                            imageUrl: post.linkPreviewImageUrl,
                            imageFileId: post.linkPreviewFileId,
                          ),
                        ],

                        // Poll
                        if (post.poll != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          FeedPollCard(
                            poll: post.poll!,
                            channelId: post.channelId,
                            messageId: post.messageId,
                          ),
                        ],

                        // Media Grid
                        if (post.media.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          PostMediaGrid(media: post.media, post: post),
                        ],

                        // order, and the whole point of the card.
                        ReplyTarget(
                          post: post,
                          slot: ReplySlot.belowBody,
                          onOpenPost: () => _openReplyTarget(context),
                          onOpenAuthor: () => NavigationUtils.openChannel(
                              context, post.channelId),
                        ),

                        // Horizontal Reactions Scroll Bar
                        if (post.reactions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          // Swallows taps so scrolling the reaction strip, or
                          // missing a chip, doesn't open the post. Not a
                          // control: it has no affordance of its own.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {},
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: post.reactions.entries.map((entry) {
                                  final emoji = entry.key;
                                  final count = entry.value;
                                  final isChosen = post.chosenReactions.contains(emoji);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () => defaultReactionHandler(emoji),
                                      borderRadius: BorderRadius.circular(16),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isChosen
                                              ? AppColors.accent.withValues(alpha: 0.18)
                                              : (isDark
                                                  ? AppColors.darkSurfaceVariant
                                                  : Colors.grey.shade100),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isChosen
                                                ? AppColors.accent
                                                : (isDark
                                                    ? AppColors.darkBorder
                                                    : AppColors.lightBorder),
                                            width: isChosen ? 1.2 : 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(emoji,
                                                style: const TextStyle(
                                                    fontSize: 14)),
                                            const SizedBox(width: 4),
                                            Text(
                                              TimeUtils.formatCount(count),
                                              style: AppTypography.actionCount(
                                                  color: isChosen ? AppColors.accent : secondaryColor).copyWith(
                                                fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.md),

                        // Action Bar
                        PostActionBar(
                          post: post,
                          secondaryColor: secondaryColor,
                          onBookmarkTap: defaultBookmarkHandler,
                          onSelectReaction: defaultReactionHandler,
                          onReplyTap: defaultReplyHandler,
                          onShareTap: defaultShareHandler,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showDivider)
              Divider(
                color: theme.dividerTheme.color,
                height: 0.5,
                thickness: 0.5,
              ),
          ],
        ),
      ),
    );
  }

  /// Whether this post singles out a passage of what it answers.
  bool get showsQuotedPassage =>
      replyPresentationFor(post) == ReplyPresentation.passage;

  /// The passage, with the byline of whoever wrote it.
  ///
  /// A reply inside this channel is answering this channel, so the face and
  /// handle already on the card are the right ones. Across chats they belong
  /// to somebody else and the avatar falls back to its initial rather than
  /// wearing the wrong channel's picture — the same fault `PostSender` exists
  /// to prevent, one level down.
  Widget _quotedPassage(BuildContext context) {
    final isSameChat = post.replyToChatId == null;
    return QuotedPassage(
      authorTitle: post.replyToAuthorTitle,
      authorUsername: isSameChat ? post.channelUsername : null,
      isAuthorVerified: isSameChat && post.isChannelVerified,
      avatarPath: isSameChat ? post.channelAvatarUrl : null,
      avatarFileId: isSameChat ? post.channelAvatarFileId : null,
      avatarColorHex: isSameChat ? post.channelAvatarColor : null,
      passage: post.replyToText!,
      onTap: () => _openReplyTarget(context),
      onAuthorTap: () => NavigationUtils.openChannel(context, post.channelId),
    );
  }

  /// Opens the message this post answers.
  ///
  /// A reply can point into another chat. Assuming it points into this one
  /// asked for a message id that does not exist there, which reports itself as
  /// "post not found" however reachable the real one is.
  void _openReplyTarget(BuildContext context) {
    final messageId = post.replyToMessageId;
    if (messageId == null) {
      NavigationUtils.openChannel(context, post.channelId);
      return;
    }
    NavigationUtils.openPost(
        context, '${post.replyToChatId ?? post.chatId}_$messageId');
  }
}

/// Sends the reader to Telegram for a message this build cannot render.
class _OpenInTelegramButton extends ConsumerWidget {
  final Post post;

  const _OpenInTelegramButton({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text(AppStrings.postOpenInTelegram),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          // A guest post has no TDLib message behind it to ask for a link, and
          // TelegramIds cannot build one either — it un-shifts a TDLib message
          // id, and a guest id is unshifted already, so it came back null and
          // the button did nothing at all.
          final link = GuestPostMapper.isSynthetic(post.chatId)
              ? GuestPostMapper.postLink(post)
              : await ref.read(feedRepositoryProvider).postLink(post) ??
                  TelegramIds.postLink(
                    chatId: post.chatId,
                    messageId: post.messageId,
                    username: post.channelUsername,
                  );
          final opened =
              link != null && await openExternalUrl(normalizeUrl(link));
          if (!opened) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(AppStrings.postCannotOpenTelegram),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}
