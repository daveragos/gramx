import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/link_preview_card.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

class PostCard extends ConsumerWidget {
  final Post post;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final VoidCallback? onChannelTap;
  final VoidCallback? onBookmarkTap;
  final ValueChanged<String>? onLikeEmojiTap;
  final VoidCallback? onShareTap;

  const PostCard({
    super.key,
    required this.post,
    this.isHighlighted = false,
    this.onTap,
    this.onChannelTap,
    this.onBookmarkTap,
    this.onLikeEmojiTap,
    this.onShareTap,
  });

  Future<void> _handleForwardedTap(BuildContext context, WidgetRef ref) async {
    if (post.forwardedFromChatId != null) {
      NavigationUtils.openChannel(context, post.forwardedFromChatId!);
      return;
    }

    final title = post.forwardedFromTitle;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(title != null ? 'Channel "$title" is private or unavailable' : 'Original channel is unavailable'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
            content: Text('Comments are disabled for this channel.'),
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
            content: Text("This post can't be linked to."),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: link));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Post link copied to clipboard.'),
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.postPadding),
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
                                 '~ ${post.authorSignature}',
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
                               Container(
                                 width: 7,
                                 height: 7,
                                 decoration: const BoxDecoration(
                                   color: AppColors.accent,
                                   shape: BoxShape.circle,
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

                        if (post.replyToText != null || post.replyToAuthorTitle != null || post.replyToMessageId != null) ...[
                          _buildQuotedReplyCard(context, ref, post, isDark, secondaryColor),
                        ],

                        // Text content with link launcher
                        if (post.text != null && post.text!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          TextEntityRenderer(
                            text: post.text!,
                            entities: post.entities,
                            style: AppTypography.body(color: primaryTextColor),
                          ),
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
                          PollCard(
                            poll: post.poll!,
                            channelId: post.channelId,
                            messageId: post.messageId,
                          ),
                        ],

                        // Media Grid
                        if (post.media.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          PostMediaGrid(media: post.media),
                        ],

                        // Horizontal Reactions Scroll Bar
                        if (post.reactions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
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
            Divider(color: theme.dividerTheme.color, height: 0.5, thickness: 0.5),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotedReplyCard(
      BuildContext context, WidgetRef ref, Post post, bool isDark, Color secondaryColor) {
    final replyTitle = post.replyToAuthorTitle ?? post.channelTitle;
    final replyText = post.replyToText ?? 'Original post';
    final hasThumbnail = post.replyToThumbnailFileId != null ||
        (post.replyToThumbnailUrl != null && post.replyToThumbnailUrl!.isNotEmpty);

    void goToOriginalPost() {
      if (post.replyToMessageId != null) {
        final targetPostId = '${post.chatId}_${post.replyToMessageId}';
        NavigationUtils.openPost(context, targetPostId);
      } else {
        NavigationUtils.openChannel(context, post.channelId);
      }
    }

    void goToOriginalChannel() {
      NavigationUtils.openChannel(context, post.channelId);
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: goToOriginalPost,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2733) : const Color(0xFFEFF5FC),
            borderRadius: BorderRadius.circular(10),
            border: const Border(
              left: BorderSide(color: AppColors.accent, width: 3.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: goToOriginalChannel,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              replyTitle,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      replyText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: secondaryColor).copyWith(
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasThumbnail) ...[
                const SizedBox(width: 8),
                _buildReplyThumbnail(ref, post, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyThumbnail(WidgetRef ref, Post post, bool isDark) {
    final fileId = post.replyToThumbnailFileId;
    final directUrl = post.replyToThumbnailUrl;

    Widget imageWidget;
    if (fileId != null && fileId != 0) {
      final fileState = ref.watch(fileDownloadProvider(fileId));
      final resolvedPath = fileState.value ?? directUrl;
      if (resolvedPath != null && resolvedPath.isNotEmpty && File(resolvedPath).existsSync()) {
        imageWidget = Image.file(
          File(resolvedPath),
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildReplyThumbnailPlaceholder(isDark),
        );
      } else {
        imageWidget = _buildReplyThumbnailPlaceholder(isDark);
      }
    } else if (directUrl != null && directUrl.isNotEmpty && File(directUrl).existsSync()) {
      imageWidget = Image.file(
        File(directUrl),
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildReplyThumbnailPlaceholder(isDark),
      );
    } else {
      imageWidget = _buildReplyThumbnailPlaceholder(isDark);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 42,
        height: 42,
        child: imageWidget,
      ),
    );
  }

  Widget _buildReplyThumbnailPlaceholder(bool isDark) {
    return Container(
      width: 42,
      height: 42,
      color: isDark ? const Color(0xFF283647) : Colors.grey.shade300,
      child: const Icon(
        Icons.image_outlined,
        size: 18,
        color: AppColors.accent,
      ),
    );
  }
}
