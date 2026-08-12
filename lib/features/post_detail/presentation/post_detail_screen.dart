import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:go_router/go_router.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_picker_overlay.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  Post? _replyTargetPost;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _handleShare(BuildContext context, Post post) {
    final postUrl = 'https://t.me/c/${post.channelId}/${post.messageId}';
    Clipboard.setData(ClipboardData(text: postUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showReactionPicker(BuildContext context, Post post, GlobalKey key) async {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final rect = offset & renderBox.size;
      final availableEmojis = await ref.read(feedRepositoryProvider).getAvailableReactions(post.chatId);
      final selectedEmoji = post.chosenReactions.isNotEmpty ? post.chosenReactions.first : null;
      if (context.mounted) {
        ReactionPickerOverlay.show(
          context: context,
          targetRect: rect,
          availableEmojis: availableEmojis,
          selectedEmoji: selectedEmoji,
          onEmojiSelected: (emoji) => _toggleReaction(post, emoji),
        );
      }
    }
  }

  void _toggleReaction(Post post, String emoji) {
    ref.read(feedPostsProvider.notifier).toggleReactionOptimistic(post.id, emoji);
    ref.read(syncServiceProvider).togglePostReaction(
      chatId: post.chatId,
      messageId: post.messageId,
      reactionEmoji: emoji,
      isCurrentlyLiked: post.chosenReactions.contains(emoji),
    );
    ref.invalidate(postDetailProvider(widget.postId));
  }

  void _handleReactionTap(BuildContext context, Post post, GlobalKey key) {
    HapticFeedback.lightImpact();
    if (post.chosenReactions.isNotEmpty) {
      _toggleReaction(post, post.chosenReactions.first);
    } else {
      _showReactionPicker(context, post, key);
    }
  }

  void _sendComment(int chatId, int messageId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    final targetReply = _replyTargetPost;
    setState(() => _replyTargetPost = null);
    try {
      await ref.read(feedRepositoryProvider).sendComment(
        chatId,
        messageId,
        text,
        replyToMessageId: targetReply?.messageId,
      );
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
          final reactionKey = GlobalKey();

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
                              GestureDetector(
                                onTap: () => context.push('/channel/${post.channelId}'),
                                child: Row(
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
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              // Quoted Reply Preview Card
                              if (post.replyToText != null || post.replyToAuthorTitle != null || post.replyToMessageId != null) ...[
                                _buildQuotedReplyCard(context, post, isDark, secondaryColor),
                              ],
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
                              GestureDetector(
                                onTap: () {
                                  if (post.hasDiscussionGroup && isLoggedIn) {
                                    _commentFocusNode.requestFocus();
                                  }
                                },
                                child: Icon(Icons.chat_bubble_outline,
                                    color: secondaryColor, size: 22),
                              ),
                              GestureDetector(
                                onTap: () => _handleShare(context, post),
                                child: Icon(Icons.repeat, color: secondaryColor, size: 22),
                              ),
                              KeyedSubtree(
                                key: reactionKey,
                                child: GestureDetector(
                                  onTap: () => _handleReactionTap(context, post, reactionKey),
                                  onLongPress: () {
                                    HapticFeedback.mediumImpact();
                                    _showReactionPicker(context, post, reactionKey);
                                  },
                                  child: Icon(
                                    post.chosenReactions.isNotEmpty || totalReactions > 0
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: post.chosenReactions.isNotEmpty || totalReactions > 0
                                        ? AppColors.like
                                        : secondaryColor,
                                    size: 22,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ref.read(feedPostsProvider.notifier).toggleBookmarkOptimistic(post.id);
                                  ref.read(feedRepositoryProvider).toggleBookmark(post.chatId, post.messageId);
                                  ref.invalidate(postDetailProvider(widget.postId));
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
                              GestureDetector(
                                onTap: () => _handleShare(context, post),
                                child: Icon(Icons.ios_share,
                                    color: secondaryColor, size: 22),
                              ),
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
                                         final isReply = comment.replyToMessageId != null ||
                                             comment.replyToText != null ||
                                             comment.replyToAuthorTitle != null;

                                         return Padding(
                                           padding: EdgeInsets.only(
                                             bottom: 12.0,
                                             left: isReply ? 16.0 : 0.0,
                                           ),
                                           child: Container(
                                             padding: isReply
                                                 ? const EdgeInsets.only(left: 8)
                                                 : EdgeInsets.zero,
                                             decoration: isReply
                                                 ? BoxDecoration(
                                                     border: Border(
                                                       left: BorderSide(
                                                         color: AppColors.accent.withValues(alpha: 0.4),
                                                         width: 2.0,
                                                       ),
                                                     ),
                                                   )
                                                 : null,
                                             child: Row(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 ChannelAvatar(
                                                   title: comment.channelTitle,
                                                   avatarPath: comment.channelAvatarUrl,
                                                   avatarFileId: comment.channelAvatarFileId,
                                                   avatarColorHex: comment.channelAvatarColor,
                                                   radius: isReply ? 15 : 18,
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
                                                             style: TextStyle(
                                                               fontWeight: FontWeight.bold,
                                                               fontSize: isReply ? 12.5 : 13.5,
                                                             ),
                                                           ),
                                                           Text(
                                                             TimeUtils.relativeTime(comment.publishedAt),
                                                             style: AppTypography.timestamp(color: secondaryColor),
                                                           ),
                                                         ],
                                                       ),
                                                       if (isReply &&
                                                           (comment.replyToAuthorTitle != null ||
                                                               comment.replyToText != null)) ...[
                                                         const SizedBox(height: 3),
                                                         Container(
                                                           padding: const EdgeInsets.symmetric(
                                                               horizontal: 8, vertical: 4),
                                                           decoration: BoxDecoration(
                                                             color: isDark
                                                                 ? const Color(0xFF1E2836)
                                                                 : const Color(0xFFEAF2FB),
                                                             borderRadius: BorderRadius.circular(6),
                                                             border: const Border(
                                                               left: BorderSide(
                                                                   color: AppColors.accent, width: 2.5),
                                                             ),
                                                           ),
                                                           child: Column(
                                                             crossAxisAlignment: CrossAxisAlignment.start,
                                                             children: [
                                                               Text(
                                                                 comment.replyToAuthorTitle ?? 'Comment',
                                                                 style: const TextStyle(
                                                                   color: AppColors.accent,
                                                                   fontSize: 11.5,
                                                                   fontWeight: FontWeight.bold,
                                                                 ),
                                                               ),
                                                               if (comment.replyToText != null)
                                                                 Text(
                                                                   comment.replyToText!,
                                                                   maxLines: 1,
                                                                   overflow: TextOverflow.ellipsis,
                                                                   style: TextStyle(
                                                                     color: secondaryColor,
                                                                     fontSize: 11,
                                                                   ),
                                                                 ),
                                                             ],
                                                           ),
                                                         ),
                                                       ],
                                                       const SizedBox(height: 3),
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
                                                       const SizedBox(height: 4),
                                                       GestureDetector(
                                                         onTap: () {
                                                           setState(() => _replyTargetPost = comment);
                                                           _commentFocusNode.requestFocus();
                                                         },
                                                         child: Row(
                                                           mainAxisSize: MainAxisSize.min,
                                                           children: [
                                                             Icon(Icons.reply_rounded,
                                                                 size: 13, color: AppColors.accent),
                                                             const SizedBox(width: 3),
                                                             Text(
                                                               'Reply',
                                                               style: AppTypography.actionCount(
                                                                   color: AppColors.accent).copyWith(
                                                                 fontWeight: FontWeight.w600,
                                                               ),
                                                             ),
                                                           ],
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                 ),
                                               ],
                                             ),
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTargetPost != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        color: isDark ? const Color(0xFF1E2836) : const Color(0xFFEAF2FB),
                        child: Row(
                          children: [
                            const Icon(Icons.reply_rounded, size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Replying to ${_replyTargetPost!.channelTitle}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _replyTargetPost = null),
                              child: const Icon(Icons.close, size: 16, color: AppColors.accent),
                            ),
                          ],
                        ),
                      ),
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
                          focusNode: _commentFocusNode,
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
            ),
          ],
        );
        },
      ),
    );
  }

  Widget _buildQuotedReplyCard(
      BuildContext context, Post post, bool isDark, Color secondaryColor) {
    final replyTitle = post.replyToAuthorTitle ?? post.channelTitle;
    final replyText = post.replyToText ?? 'Original post';

    void goToOriginalPost() {
      if (post.replyToMessageId != null) {
        final targetPostId = '${post.chatId}_${post.replyToMessageId}';
        context.push('/post/$targetPostId');
      } else {
        context.push('/channel/${post.channelId}');
      }
    }

    void goToOriginalChannel() {
      context.push('/channel/${post.channelId}');
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 10),
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
            ],
          ),
        ),
      ),
    );
  }
}
