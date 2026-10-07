import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/feed/presentation/reaction_controller.dart';
import 'package:gramx/infrastructure/telegram/chat_identity.dart';
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
import 'package:gramx/features/bookmarks/presentation/bookmark_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/widgets/post_menu_sheet.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_chips_row.dart';

class PostCard extends ConsumerWidget {
  final Post post;
  final bool isHighlighted;

  /// Whether to draw the bottom divider. Off inside a thread, which draws its
  /// own after the "earlier posts" toggle.
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

  /// Opens a forwarded post's origin: the original post if known, else its
  /// channel, else a message that the origin is hidden.
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
        content: Text(
          title != null
              ? AppStrings.feedPrivateChannel(title)
              : AppStrings.feedOriginalChannelUnavailable,
        ),
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

    // Read state is not marked here: Flutter builds items ahead of the
    // viewport. FeedFocusController marks it after an on-screen dwell.

    final defaultBookmarkHandler =
        onBookmarkTap ??
        () => ref.read(bookmarkControllerProvider.notifier).toggle(post);

    void defaultReactionHandler(String emoji) {
      if (onLikeEmojiTap != null) {
        onLikeEmojiTap!(emoji);
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      ref.read(reactionControllerProvider.notifier).react(post, emoji).then((
        sent,
      ) {
        if (!sent && isSendableReaction(emoji)) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(AppStrings.reactionFailed),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
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

    final defaultShareHandler =
        onShareTap ??
        () async {
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

    // The original channel of a forward, as TDLib knows it now: the name the
    // post was mapped with can be missing.
    final originChatId = int.tryParse(post.forwardedFromChatId ?? '');
    final origin = originChatId == null
        ? null
        : ref.watch(chatIdentityProvider(originChatId));

    final forwardedText =
        origin?.title ??
        post.forwardedFromTitle ??
        post.forwardedFromUsername ??
        (post.forwardedFromChatId != null ? 'Original Channel' : null);

    // A forward is drawn the way X draws a repost: who reposted it on a line
    // of its own, then the post under its original author.
    final isRepost = forwardedText != null && forwardedText.isNotEmpty;
    final authorTitle = isRepost ? forwardedText : post.channelTitle;
    final isAuthorVerified = isRepost
        ? (origin?.isVerified ?? false)
        : post.isChannelVerified;
    final openPoster =
        onChannelTap ??
        () => NavigationUtils.openChannel(context, post.channelId);
    final VoidCallback openAuthor = isRepost
        ? () => _handleForwardedTap(context, ref)
        : openPoster;
    final authorUsername = isRepost
        ? (post.forwardedFromUsername ?? origin?.username)
        : post.channelUsername;

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
            if (isRepost)
              _RepostedBy(
                channelTitle: post.channelTitle,
                color: secondaryColor,
                onTap: openPoster,
              ),
            // Drawn above the row so its connector runs into the avatar.
            if (showsQuotedPassage)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.postPadding,
                  isRepost ? AppSpacing.xs : AppSpacing.postPadding,
                  AppSpacing.postPadding,
                  0,
                ),
                child: _quotedPassage(context),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.postPadding,
                // No top padding under a passage, to keep the connector
                // continuous.
                showsQuotedPassage
                    ? 0
                    : (isRepost ? AppSpacing.xs : AppSpacing.postPadding),
                AppSpacing.postPadding,
                // The action bar's tap areas reach into this.
                AppSpacing.postPadding - PostActionBar.touchSlop,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChannelAvatar(
                    title: authorTitle,
                    avatarPath: isRepost
                        ? origin?.avatarPath
                        : post.channelAvatarUrl,
                    avatarFileId: isRepost
                        ? origin?.avatarFileId
                        : post.channelAvatarFileId,
                    avatarColorHex: isRepost ? null : post.channelAvatarColor,
                    onTap: openAuthor,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title, username and time, with "…" at the far edge.
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: GestureDetector(
                                      onTap: openAuthor,
                                      child: Text(
                                        authorTitle,
                                        style: AppTypography.displayName(
                                          color: primaryTextColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (isAuthorVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified,
                                      color: AppColors.verified,
                                      size: 16,
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  if (authorUsername != null) ...[
                                    Flexible(
                                      child: Text(
                                        '@$authorUsername',
                                        style: AppTypography.username(
                                          color: secondaryColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (!isRepost &&
                                      post.authorSignature != null &&
                                      post.authorSignature!.isNotEmpty) ...[
                                    Text(
                                      // Shown as a handle, not "~ name".
                                      '@${post.authorSignature}',
                                      style:
                                          AppTypography.actionCount(
                                            color: AppColors.accent,
                                          ).copyWith(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    '·',
                                    style: AppTypography.username(
                                      color: secondaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    TimeUtils.relativeTime(post.publishedAt),
                                    style: AppTypography.timestamp(
                                      color: secondaryColor,
                                    ),
                                  ),
                                  if (!post.isRead) ...[
                                    const SizedBox(width: 6),
                                    // The dot is colour only, so label it.
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
                            ),
                            _MoreButton(
                              color: secondaryColor,
                              onTap: () =>
                                  PostMenuSheet.show(context, ref, post),
                            ),
                          ],
                        ),

                        // The "Replying to" line goes above the body; the
                        // quote card goes below it (see ReplySlot).
                        ReplyTarget(
                          post: post,
                          onOpenPost: () => _openReplyTarget(context),
                          onOpenAuthor: () => NavigationUtils.openChannel(
                            context,
                            post.channelId,
                          ),
                        ),

                        // Long posts collapse behind "Show more".
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

                        // Content the app can't draw, with a way to open it in
                        // Telegram.
                        if (post.unsupportedKind != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _OpenInTelegramButton(post: post),
                        ],

                        if (post.linkPreviewUrl != null &&
                            post.linkPreviewUrl!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          LinkPreviewCard(
                            url: post.linkPreviewUrl!,
                            title: post.linkPreviewTitle,
                            description: post.linkPreviewDescription,
                            imageUrl: post.linkPreviewImageUrl,
                            imageFileId: post.linkPreviewFileId,
                          ),
                        ],

                        if (post.poll != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          FeedPollCard(
                            poll: post.poll!,
                            channelId: post.channelId,
                            messageId: post.messageId,
                          ),
                        ],

                        if (post.media.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          PostMediaGrid(
                            media: post.media,
                            post: post,
                            bleed: AppSpacing.postPadding,
                          ),
                        ],

                        // The quoted post being answered, below the answer.
                        ReplyTarget(
                          post: post,
                          slot: ReplySlot.belowBody,
                          onOpenPost: () => _openReplyTarget(context),
                          onOpenAuthor: () => NavigationUtils.openChannel(
                            context,
                            post.channelId,
                          ),
                        ),

                        if (post.reactions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          ReactionChipsRow(
                            reactions: post.reactions,
                            chosen: post.chosenReactions,
                            onTap: defaultReactionHandler,
                            enabled: ref
                                .watch(readerCapabilitiesProvider)
                                .canReact,
                            compact: true,
                          ),
                        ],

                        const SizedBox(
                          height: AppSpacing.md - PostActionBar.touchSlop,
                        ),

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

  /// The quoted passage with its author's byline. For a reply into another
  /// chat, the avatar falls back to an initial instead of this channel's
  /// picture.
  Widget _quotedPassage(BuildContext context) {
    final isSameChat = post.replyToChatId == null;
    return QuotedPassage(
      authorTitle: post.replyToAuthorTitle,
      authorChatId: post.replyToChatId,
      authorUsername: isSameChat ? post.channelUsername : null,
      isAuthorVerified: isSameChat && post.isChannelVerified,
      avatarPath: isSameChat ? post.channelAvatarUrl : null,
      avatarFileId: isSameChat ? post.channelAvatarFileId : null,
      avatarColorHex: isSameChat ? post.channelAvatarColor : null,
      passage: post.replyToText!,
      onTap: () => _openReplyTarget(context),
      // The passage's own chat, which may not be this one.
      onAuthorTap: () => NavigationUtils.openChannel(
        context,
        '${post.replyToChatId ?? post.chatId}',
      ),
    );
  }

  /// Opens the message this post answers, which may be in another chat.
  void _openReplyTarget(BuildContext context) {
    final messageId = post.replyToMessageId;
    if (messageId == null) {
      NavigationUtils.openChannel(context, post.channelId);
      return;
    }
    NavigationUtils.openPost(
      context,
      '${post.replyToChatId ?? post.chatId}_$messageId',
    );
  }
}

/// Opens in Telegram a message the app can't render.
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
          // Guest posts have no TDLib message, and their ids are not shifted
          // like TDLib's, so they build their own link.
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

/// The small "…" at the top right of every card, with a hit target the full
/// height of the row.
class _MoreButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _MoreButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.postMenuTooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            0,
            AppSpacing.xs,
          ),
          child: Icon(Icons.more_horiz_rounded, size: 18, color: color),
        ),
      ),
    );
  }
}

/// The line above a repost naming the channel that reposted it, with the
/// repost mark right-aligned in the avatar column, as X lays it out.
class _RepostedBy extends StatelessWidget {
  final String channelTitle;
  final Color color;
  final VoidCallback onTap;

  const _RepostedBy({
    required this.channelTitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.postPadding,
        AppSpacing.postPadding,
        AppSpacing.postPadding,
        0,
      ),
      child: Semantics(
        button: true,
        label: AppStrings.feedReposted(channelTitle),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: AppSpacing.avatarSize,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.repeat_rounded, size: 16, color: color),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  AppStrings.feedReposted(channelTitle),
                  style: AppTypography.timestamp(
                    color: color,
                  ).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
