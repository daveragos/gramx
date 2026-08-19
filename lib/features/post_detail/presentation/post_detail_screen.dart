import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_picker_overlay.dart';
import 'package:gramx/features/feed/presentation/widgets/link_preview_card.dart';
import 'package:gramx/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final bool autoFocusReply;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.autoFocusReply = false,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  Post? _replyTargetPost;
  final Set<String> _expandedCommentIds = {};

  StreamSubscription<LivePostUpdate>? _liveSub;
  Timer? _refreshDebounce;

  /// Replies arrive in bursts. Waiting a beat turns a conversation into one
  /// refetch instead of one per message.
  static const Duration _commentsRefreshDebounce = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    if (widget.autoFocusReply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _commentFocusNode.requestFocus();
        }
      });
    }
    _watchForNewComments();
  }

  /// Keeps an open thread current.
  ///
  /// Comments live in the channel's linked discussion group, not the channel
  /// itself, so we match on the chat id of the comments already loaded. Only
  /// runs while this screen is mounted.
  void _watchForNewComments() {
    _liveSub = ref.read(syncServiceProvider).livePostUpdates.listen((update) {
      if (update is! LiveNewMessage) return;

      final loaded = ref.read(postCommentsProvider(widget.postId)).value;
      if (loaded == null || loaded.isEmpty) return;
      if (update.message.chatId != loaded.first.chatId) return;

      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(_commentsRefreshDebounce, () {
        if (mounted) ref.invalidate(postCommentsProvider(widget.postId));
      });
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _refreshDebounce?.cancel();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleShare(BuildContext context, Post post) async {
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
    ref.read(optimisticPostUpdatesProvider.notifier).toggleReaction(post.id, emoji, post);
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
    } else if (post.reactions.keys.isNotEmpty) {
      _toggleReaction(post, post.reactions.keys.first);
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
            content: Text(AppStrings.commentPosted),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.commentFailed(e))),
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
        title: Text(AppStrings.postTitle, style: AppTypography.heading(color: primaryColor)),
      ),
      body: postAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (post) {
          if (post == null) {
            // Usually a forward from a private channel, or a deleted post.
            // Telegram itself may still be able to show it, so offer that
            // rather than leaving a dead end.
            return _UnreachablePost(postId: widget.postId);
          }

          final totalReactions =
              post.reactions.values.fold<int>(0, (a, b) => a + b);
          final activeEmoji = post.chosenReactions.isNotEmpty
              ? post.chosenReactions.first
              : (post.reactions.keys.isNotEmpty ? post.reactions.keys.first : null);
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
                                  onHashtagTap: (tag) =>
                                      openHashtagSearch(context, ref, tag),
                                  text: post.text!,
                                  entities: post.entities,
                                  style: AppTypography.bodyLarge(color: primaryColor),
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
                              // Horizontal Reactions Scroll Bar
                              if (post.reactions.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                SingleChildScrollView(
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
                                          onTap: () => _toggleReaction(post, emoji),
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
                                                    style: const TextStyle(fontSize: 14)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  TimeUtils.formatCount(count),
                                                  style: AppTypography.actionCount(
                                                          color: isChosen
                                                              ? AppColors.accent
                                                              : secondaryColor)
                                                      .copyWith(
                                                    fontWeight: isChosen
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
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
                                  } else if (!post.hasDiscussionGroup) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Comments are disabled for this channel.'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
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
                                  child: activeEmoji != null
                                      ? Text(activeEmoji, style: const TextStyle(fontSize: 20))
                                      : Icon(
                                          post.chosenReactions.isNotEmpty
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: post.chosenReactions.isNotEmpty
                                              ? AppColors.like
                                              : secondaryColor,
                                          size: 22,
                                        ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ref.read(optimisticPostUpdatesProvider.notifier).toggleBookmark(post.id, post);
                                  ref.read(feedPostsProvider.notifier).toggleBookmarkOptimistic(post.id);
                                  ref.read(feedRepositoryProvider).toggleBookmark(post.chatId, post.messageId);
                                  ref.invalidate(bookmarkedPostsProvider);
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

                                     final commentMap = {for (var c in comments) c.messageId: c};
                                     final Map<int, List<Post>> subMap = {};

                                     for (final comment in comments) {
                                       final replyId = comment.replyToMessageId;
                                       if (replyId != null && replyId != post.messageId && commentMap.containsKey(replyId)) {
                                         int rootId = replyId;
                                         int depth = 0;
                                         while (commentMap.containsKey(rootId) && depth < 10) {
                                           final parent = commentMap[rootId]!;
                                           if (parent.replyToMessageId == null ||
                                               parent.replyToMessageId == post.messageId ||
                                               !commentMap.containsKey(parent.replyToMessageId)) {
                                             break;
                                           }
                                           rootId = parent.replyToMessageId!;
                                           depth++;
                                         }
                                         subMap.putIfAbsent(rootId, () => []).add(comment);
                                       }
                                     }

                                     final childIds = subMap.values.expand((list) => list.map((c) => c.messageId)).toSet();
                                     final topLevelComments = comments.where((c) => !childIds.contains(c.messageId)).toList();

                                     final List<Widget> commentWidgets = [];

                                     for (int i = 0; i < topLevelComments.length; i++) {
                                       final topComment = topLevelComments[i];
                                       final subReplies = subMap[topComment.messageId] ?? [];
                                       final isExpanded = _expandedCommentIds.contains(topComment.id);
                                       final isLastTopComment = i == topLevelComments.length - 1;

                                       commentWidgets.add(
                                         _buildXCommentItem(
                                           context: context,
                                           comment: topComment,
                                           isLast: isLastTopComment && subReplies.isEmpty,
                                           isDark: isDark,
                                           primaryColor: primaryColor,
                                           secondaryColor: secondaryColor,
                                         ),
                                       );

                                       if (subReplies.isNotEmpty) {
                                         if (!isExpanded) {
                                           commentWidgets.add(
                                             Padding(
                                               padding: const EdgeInsets.only(left: 46, top: 0, bottom: 16),
                                               child: InkWell(
                                                 onTap: () {
                                                   HapticFeedback.lightImpact();
                                                   setState(() => _expandedCommentIds.add(topComment.id));
                                                 },
                                                 borderRadius: BorderRadius.circular(16),
                                                 child: Padding(
                                                   padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                                   child: Row(
                                                     mainAxisSize: MainAxisSize.min,
                                                     children: [
                                                       Container(
                                                         width: 20,
                                                         height: 1.5,
                                                         color: AppColors.accent.withValues(alpha: 0.6),
                                                       ),
                                                       const SizedBox(width: 8),
                                                       Text(
                                                         subReplies.length == 1
                                                             ? 'Show 1 reply'
                                                             : 'Show ${subReplies.length} replies',
                                                         style: const TextStyle(
                                                           color: AppColors.accent,
                                                           fontSize: 13,
                                                           fontWeight: FontWeight.w600,
                                                         ),
                                                       ),
                                                       const Icon(
                                                         Icons.keyboard_arrow_down_rounded,
                                                         size: 18,
                                                         color: AppColors.accent,
                                                       ),
                                                     ],
                                                   ),
                                                 ),
                                               ),
                                             ),
                                           );
                                         } else {
                                           for (int j = 0; j < subReplies.length; j++) {
                                             final sub = subReplies[j];
                                             final isLastSub = j == subReplies.length - 1;
                                             commentWidgets.add(
                                               Padding(
                                                 padding: const EdgeInsets.only(left: 32),
                                                 child: _buildXCommentItem(
                                                   context: context,
                                                   comment: sub,
                                                   isLast: isLastSub && isLastTopComment,
                                                   isDark: isDark,
                                                   primaryColor: primaryColor,
                                                   secondaryColor: secondaryColor,
                                                 ),
                                               ),
                                             );
                                           }

                                           commentWidgets.add(
                                             Padding(
                                               padding: const EdgeInsets.only(left: 46, top: 0, bottom: 16),
                                               child: InkWell(
                                                 onTap: () {
                                                   HapticFeedback.lightImpact();
                                                   setState(() => _expandedCommentIds.remove(topComment.id));
                                                 },
                                                 borderRadius: BorderRadius.circular(16),
                                                 child: Padding(
                                                   padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                                   child: Row(
                                                     mainAxisSize: MainAxisSize.min,
                                                     children: [
                                                       Container(
                                                         width: 20,
                                                         height: 1.5,
                                                         color: secondaryColor.withValues(alpha: 0.4),
                                                       ),
                                                       const SizedBox(width: 8),
                                                       Text(
                                                         subReplies.length == 1 ? 'Hide reply' : 'Hide replies',
                                                         style: TextStyle(
                                                           color: secondaryColor,
                                                           fontSize: 12.5,
                                                           fontWeight: FontWeight.w500,
                                                         ),
                                                       ),
                                                       Icon(
                                                         Icons.keyboard_arrow_up_rounded,
                                                         size: 18,
                                                         color: secondaryColor,
                                                       ),
                                                     ],
                                                   ),
                                                 ),
                                               ),
                                             ),
                                           );
                                         }
                                       }
                                     }

                                     return Column(children: commentWidgets);
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
                _buildCommentInputBar(
                  context: context,
                  post: post,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildXCommentItem({
    required BuildContext context,
    required Post comment,
    required bool isLast,
    required bool isDark,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final isReply = comment.replyToMessageId != null ||
        comment.replyToText != null ||
        comment.replyToAuthorTitle != null;
    final replyAuthor = comment.replyToAuthorTitle ?? 'post';

    final totalReactions = comment.reactions.values.fold<int>(0, (a, b) => a + b);
    final isLiked = comment.chosenReactions.isNotEmpty || totalReactions > 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column: Avatar + Thread Connector Line
          Column(
            children: [
              ChannelAvatar(
                title: comment.channelTitle,
                avatarPath: comment.channelAvatarUrl,
                avatarFileId: comment.channelAvatarFileId,
                avatarColorHex: comment.channelAvatarColor,
                radius: 18,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),

          // Right Column: Content + Header + Actions
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Name @Username · Time
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.channelTitle,
                          style: AppTypography.displayName(color: primaryColor).copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (comment.channelUsername != null && comment.channelUsername!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '@${comment.channelUsername}',
                            style: AppTypography.username(color: secondaryColor).copyWith(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      Text('·', style: AppTypography.username(color: secondaryColor)),
                      const SizedBox(width: 4),
                      Text(
                        TimeUtils.relativeTime(comment.publishedAt),
                        style: AppTypography.timestamp(color: secondaryColor).copyWith(fontSize: 12),
                      ),
                    ],
                  ),

                  // Replying to @Author Tag
                  if (isReply) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Replying to ',
                          style: AppTypography.body(color: secondaryColor).copyWith(fontSize: 12.5),
                        ),
                        Text(
                          '@$replyAuthor',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Quoted reply card snippet (if present)
                  if (comment.replyToText != null && comment.replyToText!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2836) : const Color(0xFFEAF2FB),
                        borderRadius: BorderRadius.circular(6),
                        border: const Border(
                          left: BorderSide(color: AppColors.accent, width: 2.5),
                        ),
                      ),
                      child: Text(
                        comment.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(color: secondaryColor).copyWith(fontSize: 12),
                      ),
                    ),
                  ],

                  // Text Content
                  if (comment.text != null && comment.text!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    TextEntityRenderer(
                      text: comment.text!,
                      entities: comment.entities,
                      style: AppTypography.body(color: primaryColor).copyWith(fontSize: 14, height: 1.3),
                    ),
                  ],

                  // Media Attachments
                  if (comment.media.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: PostMediaGrid(media: comment.media),
                    ),
                  ],

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Reply Icon + Count
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _replyTargetPost = comment);
                          _commentFocusNode.requestFocus();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                                color: secondaryColor,
                              ),
                              if (comment.replyCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  TimeUtils.formatCount(comment.replyCount),
                                  style: AppTypography.actionCount(color: secondaryColor).copyWith(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Like / Reaction Icon + Count
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final emoji = comment.chosenReactions.isNotEmpty
                              ? comment.chosenReactions.first
                              : '❤️';
                          _toggleReaction(comment, emoji);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: isLiked ? AppColors.like : secondaryColor,
                              ),
                              if (totalReactions > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  TimeUtils.formatCount(totalReactions),
                                  style: AppTypography.actionCount(
                                    color: isLiked ? AppColors.like : secondaryColor,
                                  ).copyWith(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Share Icon
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleShare(context, comment);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.ios_share,
                            size: 16,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputBar({
    required BuildContext context,
    required Post post,
    required bool isDark,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
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
                        'Replying to @${_replyTargetPost!.channelTitle}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _replyTargetPost = null),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 16, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ChannelAvatar(
                    title: post.channelTitle,
                    radius: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTypography.body(color: primaryColor),
                      decoration: InputDecoration(
                        hintText: _replyTargetPost != null
                            ? 'Post your reply...'
                            : 'Add a comment...',
                        hintStyle: AppTypography.body(color: secondaryColor),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurfaceVariant
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _sendComment(post.chatId, post.messageId),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// Shown when a post can't be loaded — typically a forward whose origin is a
/// channel the user isn't in.
class _UnreachablePost extends StatelessWidget {
  final String postId;

  const _UnreachablePost({required this.postId});

  Future<void> _openInTelegram(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final parts = postId.split('_');
    final chatId = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final messageId = parts.length == 2 ? int.tryParse(parts[1]) : null;

    final link = chatId == null || messageId == null
        ? null
        : TelegramIds.postLink(chatId: chatId, messageId: messageId);

    if (link == null || !await launchUrl(Uri.parse(link),
        mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.postCannotOpenTelegram)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: secondary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.postNotFound,
              style: AppTypography.subheading(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.postUnreachableBody,
              style: AppTypography.body(color: secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () => _openInTelegram(context),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text(AppStrings.postOpenInTelegram),
            ),
          ],
        ),
      ),
    );
  }
}
