import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment(int chatId, int messageId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    try {
      await ref.read(feedRepositoryProvider).sendComment(chatId, messageId, text);
      ref.invalidate(postCommentsProvider(widget.postId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final accountAsync = ref.watch(activeAccountProvider);
    final isLoggedIn = accountAsync.value != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markPostAsReadProvider(widget.postId));
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Post', style: AppTypography.heading(color: primaryColor)),
      ),
      body: postAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (post) {
          if (post == null) {
            return Center(
              child: Text(
                'Post not found',
                style: AppTypography.body(color: secondaryColor),
              ),
            );
          }

          final totalReactions =
              post.reactions.values.fold<int>(0, (a, b) => a + b);

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () async {
                    ref.invalidate(postDetailProvider(widget.postId));
                    ref.invalidate(postCommentsProvider(widget.postId));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.postPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Channel header
                              Row(
                                children: [
                                  ChannelAvatar(
                                    title: post.channelTitle,
                                    avatarPath: post.channelAvatarUrl,
                                    avatarFileId: post.channelAvatarFileId,
                                    avatarColorHex: post.channelAvatarColor,
                                    radius: AppSpacing.avatarSizeLarge / 2,
                                  ),
                                  const SizedBox(width: AppSpacing.avatarGap),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              post.channelTitle,
                                              style: AppTypography.displayName(
                                                  color: primaryColor),
                                            ),
                                            if (post.isChannelVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.verified,
                                                color: AppColors.verified,
                                                size: 18,
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (post.channelUsername != null)
                                          Text(
                                            '@${post.channelUsername}',
                                            style: AppTypography.username(
                                                color: secondaryColor),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              // Post text
                              if (post.text != null && post.text!.isNotEmpty) ...[
                                TextEntityRenderer(
                                  text: post.text!,
                                  entities: post.entities,
                                  style: AppTypography.bodyLarge(color: primaryColor),
                                ),
                              ],
                              // Poll display
                              if (post.poll != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                PollCard(
                                  poll: post.poll!,
                                  channelId: post.channelId,
                                  messageId: post.messageId,
                                ),
                              ],
                              // Media
                              if (post.media.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                PostMediaGrid(media: post.media),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              // Full timestamp
                              Text(
                                TimeUtils.fullDateTime(post.publishedAt),
                                style: AppTypography.timestamp(color: secondaryColor),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Stats row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.postPadding,
                              vertical: AppSpacing.sm),
                          child: Row(
                            children: [
                              if (post.forwardCount > 0) ...[
                                Text(
                                  TimeUtils.formatCount(post.forwardCount),
                                  style: AppTypography.displayName(
                                      color: primaryColor),
                                ),
                                const SizedBox(width: 4),
                                Text('Reposts',
                                    style: AppTypography.body(
                                        color: secondaryColor)),
                                const SizedBox(width: AppSpacing.lg),
                              ],
                              if (totalReactions > 0) ...[
                                Text(
                                  TimeUtils.formatCount(totalReactions),
                                  style: AppTypography.displayName(
                                      color: primaryColor),
                                ),
                                const SizedBox(width: 4),
                                Text('Likes',
                                    style: AppTypography.body(
                                        color: secondaryColor)),
                                const SizedBox(width: AppSpacing.lg),
                              ],
                              if (post.viewCount > 0) ...[
                                Text(
                                  TimeUtils.formatCount(post.viewCount),
                                  style: AppTypography.displayName(
                                      color: primaryColor),
                                ),
                                const SizedBox(width: 4),
                                Text('Views',
                                    style: AppTypography.body(
                                        color: secondaryColor)),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Action bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxxl,
                              vertical: AppSpacing.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  color: secondaryColor, size: 22),
                              Icon(Icons.repeat, color: secondaryColor, size: 22),
                              GestureDetector(
                                onTap: () {
                                  ref.read(bookmarkToggleProvider(widget.postId));
                                },
                                child: Icon(
                                  totalReactions > 0
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: totalReactions > 0
                                      ? AppColors.like
                                      : secondaryColor,
                                  size: 22,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ref.read(bookmarkToggleProvider(widget.postId));
                                },
                                child: Icon(
                                  post.isBookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: post.isBookmarked
                                      ? AppColors.accent
                                      : secondaryColor,
                                  size: 22,
                                ),
                              ),
                              Icon(Icons.ios_share,
                                  color: secondaryColor, size: 22),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Comments section
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.postPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Comments',
                                  style: AppTypography.subheading(
                                      color: primaryColor)),
                              const SizedBox(height: AppSpacing.lg),
                              if (!post.hasDiscussionGroup)
                                Center(
                                  child: Text(
                                    'Comments are disabled for this channel.',
                                    style: AppTypography.body(color: secondaryColor),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else if (!isLoggedIn)
                                Center(
                                  child: Text(
                                    'Log in to Telegram to post comments.',
                                    style: AppTypography.body(color: secondaryColor),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                commentsAsync.when(
                                  loading: () => const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(
                                        color: AppColors.accent,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  error: (err, _) => Text(
                                    'Error loading comments: $err',
                                    style: AppTypography.body(color: secondaryColor),
                                  ),
                                  data: (comments) {
                                    if (comments.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'No comments on this post yet. Be the first to comment!',
                                          style: AppTypography.body(color: secondaryColor),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }

                                    return Column(
                                      children: comments.map((comment) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ChannelAvatar(
                                                title: comment.channelTitle,
                                                avatarPath: comment.channelAvatarUrl,
                                                avatarFileId: comment.channelAvatarFileId,
                                                avatarColorHex: comment.channelAvatarColor,
                                                radius: 18,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          comment.channelTitle,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        Text(
                                                          TimeUtils.relativeTime(comment.publishedAt),
                                                          style: AppTypography.timestamp(color: secondaryColor),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    if (comment.text != null && comment.text!.isNotEmpty)
                                                      TextEntityRenderer(
                                                        text: comment.text!,
                                                        entities: comment.entities,
                                                        style: AppTypography.body(color: primaryColor),
                                                      ),
                                                    if (comment.media.isNotEmpty) ...[
                                                      const SizedBox(height: 6),
                                                      ConstrainedBox(
                                                        constraints: const BoxConstraints(maxHeight: 220),
                                                        child: PostMediaGrid(media: comment.media),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Comment Input Bar for Logged-In Users on discussion enabled posts
              if (isLoggedIn && post.hasDiscussionGroup)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerTheme.color ?? AppColors.darkBorder,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle:
                                AppTypography.body(color: secondaryColor),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkSurfaceVariant
                                : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _sendComment(post.chatId, post.messageId),
                        icon: const Icon(Icons.send_rounded,
                            color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
