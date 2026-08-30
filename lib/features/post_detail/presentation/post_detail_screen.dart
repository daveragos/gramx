import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_attachment_strip.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_media_kind_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_sticker_sheet.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/feed/domain/reply_presentation.dart';
import 'package:gramx/features/feed/presentation/widgets/reply_target.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_control.dart';
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

  /// Pictures and videos picked but not yet posted. A comment can carry the
  /// same things a post can now, and these ride along with the words the way
  /// they do everywhere else in the app.
  final List<ComposeAttachment> _attachments = [];

  bool _isSending = false;

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
        if (mounted) ref.invalidate(postCommentsFetchProvider(widget.postId));
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

  void _toggleReaction(Post post, String emoji) {
    ref
        .read(optimisticPostUpdatesProvider.notifier)
        .toggleReaction(post.id, emoji, post);
    ref
        .read(feedPostsProvider.notifier)
        .toggleReactionOptimistic(post.id, emoji);
    ref
        .read(syncServiceProvider)
        .togglePostReaction(
          chatId: post.chatId,
          messageId: post.messageId,
          reactionEmoji: emoji,
          isCurrentlyLiked: post.chosenReactions.contains(emoji),
        );
    // No invalidate: the optimistic override is applied synchronously and the
    // live update stream reconciles it. Refetching here dropped the screen —
    // post, thread and scroll position — back to a spinner on every tap.
  }

  /// Whether there is anything to post: words, or something attached.
  bool get _canSendComment =>
      !_isSending &&
      (_commentController.text.trim().isNotEmpty || _attachments.isNotEmpty);

  /// Attaches a picture or a video, through the same picker the post composer
  /// and the message composer use.
  Future<void> _attachToComment() async {
    final choice = await ComposeMediaKindSheet.show(context);
    if (choice == null || !mounted) return;

    final picker = ref.read(composeMediaPickerProvider);
    final attachment = choice == ComposeMediaKind.photo
        ? await picker.pickPhoto()
        : await picker.pickVideo();
    if (attachment == null || !mounted) return;
    setState(() => _attachments.add(attachment));
  }

  /// Picks a sticker or a GIF and posts it on its own.
  ///
  /// Sent immediately rather than staged beside the text, because
  /// `inputMessageSticker` has no caption field at all — anything typed would
  /// be silently dropped. Telegram sends on tap here too, so the gesture reads
  /// the same way it does everywhere else.
  Future<void> _sendStickerComment(int chatId, int messageId) async {
    final media = await ComposeStickerSheet.show(
      context,
      initialKind: ComposeRemoteKind.sticker,
    );
    if (media == null || !mounted) return;
    await _postComment(chatId, messageId, remote: media);
  }

  void _sendComment(int chatId, int messageId) {
    if (!_canSendComment) return;
    _postComment(chatId, messageId);
  }

  Future<void> _postComment(
    int chatId,
    int messageId, {
    ComposeRemoteMedia? remote,
  }) async {
    final text = remote != null ? '' : _commentController.text.trim();
    final attachments = remote != null
        ? const <ComposeAttachment>[]
        : List<ComposeAttachment>.from(_attachments);
    if (remote == null && text.isEmpty && attachments.isEmpty) return;

    final targetReply = _replyTargetPost;
    setState(() {
      _isSending = true;
      if (remote == null) {
        _commentController.clear();
        _attachments.clear();
      }
      _replyTargetPost = null;
    });

    try {
      await ref
          .read(feedRepositoryProvider)
          .sendComment(
            chatId,
            messageId,
            text,
            replyToMessageId: targetReply?.messageId,
            attachments: attachments,
            remote: remote,
          );
      ref.invalidate(postCommentsFetchProvider(widget.postId));
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
        // Put back what was typed. Losing a comment to a failed send is the
        // worst outcome here, and the text is the only part that cannot be
        // picked again.
        setState(() {
          if (remote == null) {
            _commentController.text = text;
            _attachments.addAll(attachments);
          }
          _replyTargetPost = targetReply;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.commentFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A guest has no Telegram account to write read state to, and the
      // message id is one this app invented — see ReaderCapabilities.
      if (ref.read(readerCapabilitiesProvider).canMarkRead) {
        ref.read(markPostAsReadProvider(widget.postId));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.postTitle,
          style: AppTypography.heading(color: primaryColor),
        ),
      ),
      body: postAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text(AppStrings.postError(err))),
        data: (post) {
          if (post == null) {
            // Usually a forward from a private channel, or a deleted post.
            // Telegram itself may still be able to show it, so offer that
            // rather than leaving a dead end.
            return _UnreachablePost(postId: widget.postId);
          }

          final totalReactions = post.reactions.values.fold<int>(
            0,
            (a, b) => a + b,
          );

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () async {
                    ref.invalidate(postDetailFetchProvider(widget.postId));
                    ref.invalidate(postCommentsFetchProvider(widget.postId));
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
                              // The passage this post singles out stands above
                              // it, on a connector running into its avatar.
                              if (replyPresentationFor(post) ==
                                  ReplyPresentation.passage)
                                _quotedPassage(context, post),
                              // Channel header
                              GestureDetector(
                                onTap: () =>
                                    context.push('/channel/${post.channelId}'),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                post.channelTitle,
                                                style:
                                                    AppTypography.displayName(
                                                      color: primaryColor,
                                                    ),
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
                                                color: secondaryColor,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              ReplyTarget(
                                post: post,
                                onOpenPost: () => _openReplyTarget(context, post),
                                onOpenAuthor: () =>
                                    context.push('/channel/${post.channelId}'),
                              ),
                              // Post text
                              if (post.text != null &&
                                  post.text!.isNotEmpty) ...[
                                TextEntityRenderer(
                                  onHashtagTap: (tag) =>
                                      openHashtagSearch(context, ref, tag),
                                  text: post.text!,
                                  entities: post.entities,
                                  style: AppTypography.bodyLarge(
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                              // Link preview
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
                                PostMediaGrid(media: post.media, post: post),
                              ],
                              // Horizontal Reactions Scroll Bar
                              if (post.reactions.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: post.reactions.entries.map((
                                      entry,
                                    ) {
                                      final emoji = entry.key;
                                      final count = entry.value;
                                      final isChosen = post.chosenReactions
                                          .contains(emoji);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: InkWell(
                                          onTap: () =>
                                              _toggleReaction(post, emoji),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isChosen
                                                  ? AppColors.accent.withValues(
                                                      alpha: 0.18,
                                                    )
                                                  : (isDark
                                                        ? AppColors
                                                              .darkSurfaceVariant
                                                        : Colors.grey.shade100),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isChosen
                                                    ? AppColors.accent
                                                    : (isDark
                                                          ? AppColors.darkBorder
                                                          : AppColors
                                                                .lightBorder),
                                                width: isChosen ? 1.2 : 0.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  emoji,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  TimeUtils.formatCount(count),
                                                  style:
                                                      AppTypography.actionCount(
                                                        color: isChosen
                                                            ? AppColors.accent
                                                            : secondaryColor,
                                                      ).copyWith(
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
                                style: AppTypography.timestamp(
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Stats row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.postPadding,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              if (post.forwardCount > 0) ...[
                                Text(
                                  TimeUtils.formatCount(post.forwardCount),
                                  style: AppTypography.displayName(
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppStrings.statReposts,
                                  style: AppTypography.body(
                                    color: secondaryColor,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                              ],
                              if (totalReactions > 0) ...[
                                Text(
                                  TimeUtils.formatCount(totalReactions),
                                  style: AppTypography.displayName(
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppStrings.statLikes,
                                  style: AppTypography.body(
                                    color: secondaryColor,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                              ],
                              if (post.viewCount > 0) ...[
                                Text(
                                  TimeUtils.formatCount(post.viewCount),
                                  style: AppTypography.displayName(
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppStrings.statViews,
                                  style: AppTypography.body(
                                    color: secondaryColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // The feed's own action bar, rather than a second copy
                        // that drifted: the repeat icon here used to copy a
                        // link instead of forwarding, and the reaction button
                        // could only ever add the channel's top reaction.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.postPadding,
                            vertical: AppSpacing.sm,
                          ),
                          child: PostActionBar(
                            post: post,
                            secondaryColor: secondaryColor,
                            onBookmarkTap: () {
                              ref
                                  .read(optimisticPostUpdatesProvider.notifier)
                                  .toggleBookmark(post.id, post);
                              ref
                                  .read(feedPostsProvider.notifier)
                                  .toggleBookmarkOptimistic(post.id);
                              ref
                                  .read(feedRepositoryProvider)
                                  .toggleBookmark(post.chatId, post.messageId);
                              ref.invalidate(bookmarkedPostsProvider);
                            },
                            onSelectReaction: (emoji) =>
                                _toggleReaction(post, emoji),
                            onReplyTap: () {
                              if (post.hasDiscussionGroup && isLoggedIn) {
                                _commentFocusNode.requestFocus();
                              } else if (!post.hasDiscussionGroup) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      AppStrings.feedCommentsDisabled,
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            onShareTap: () => _handleShare(context, post),
                          ),
                        ),
                        const Divider(height: 1),
                        // Comments section
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.postPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.commentsHeading,
                                style: AppTypography.subheading(
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (!post.hasDiscussionGroup)
                                Center(
                                  child: Text(
                                    AppStrings.feedCommentsDisabled,
                                    style: AppTypography.body(
                                      color: secondaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else if (!isLoggedIn)
                                Center(
                                  child: Text(
                                    AppStrings.commentsLoginPrompt,
                                    style: AppTypography.body(
                                      color: secondaryColor,
                                    ),
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
                                    style: AppTypography.body(
                                      color: secondaryColor,
                                    ),
                                  ),
                                  data: (comments) {
                                    if (comments.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'No comments on this post yet. Be the first to comment!',
                                          style: AppTypography.body(
                                            color: secondaryColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }

                                    final commentMap = {
                                      for (var c in comments) c.messageId: c,
                                    };
                                    final Map<int, List<Post>> subMap = {};

                                    for (final comment in comments) {
                                      final replyId = comment.replyToMessageId;
                                      if (replyId != null &&
                                          replyId != post.messageId &&
                                          commentMap.containsKey(replyId)) {
                                        int rootId = replyId;
                                        int depth = 0;
                                        while (commentMap.containsKey(rootId) &&
                                            depth < 10) {
                                          final parent = commentMap[rootId]!;
                                          if (parent.replyToMessageId == null ||
                                              parent.replyToMessageId ==
                                                  post.messageId ||
                                              !commentMap.containsKey(
                                                parent.replyToMessageId,
                                              )) {
                                            break;
                                          }
                                          rootId = parent.replyToMessageId!;
                                          depth++;
                                        }
                                        subMap
                                            .putIfAbsent(rootId, () => [])
                                            .add(comment);
                                      }
                                    }

                                    final childIds = subMap.values
                                        .expand(
                                          (list) =>
                                              list.map((c) => c.messageId),
                                        )
                                        .toSet();
                                    final topLevelComments = comments
                                        .where(
                                          (c) =>
                                              !childIds.contains(c.messageId),
                                        )
                                        .toList();

                                    final List<Widget> commentWidgets = [];

                                    for (
                                      int i = 0;
                                      i < topLevelComments.length;
                                      i++
                                    ) {
                                      final topComment = topLevelComments[i];
                                      final subReplies =
                                          subMap[topComment.messageId] ?? [];
                                      final isExpanded = _expandedCommentIds
                                          .contains(topComment.id);
                                      final isLastTopComment =
                                          i == topLevelComments.length - 1;

                                      commentWidgets.add(
                                        _buildXCommentItem(
                                          context: context,
                                          comment: topComment,
                                          isLast:
                                              isLastTopComment &&
                                              subReplies.isEmpty,
                                          isDark: isDark,
                                          primaryColor: primaryColor,
                                          secondaryColor: secondaryColor,
                                        ),
                                      );

                                      if (subReplies.isNotEmpty) {
                                        if (!isExpanded) {
                                          commentWidgets.add(
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 46,
                                                top: 0,
                                                bottom: 16,
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  setState(
                                                    () => _expandedCommentIds
                                                        .add(topComment.id),
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                        horizontal: 6,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 20,
                                                        height: 1.5,
                                                        color: AppColors.accent
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        subReplies.length == 1
                                                            ? 'Show 1 reply'
                                                            : 'Show ${subReplies.length} replies',
                                                        style: const TextStyle(
                                                          color:
                                                              AppColors.accent,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const Icon(
                                                        Icons
                                                            .keyboard_arrow_down_rounded,
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
                                          for (
                                            int j = 0;
                                            j < subReplies.length;
                                            j++
                                          ) {
                                            final sub = subReplies[j];
                                            final isLastSub =
                                                j == subReplies.length - 1;
                                            commentWidgets.add(
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 32,
                                                ),
                                                child: _buildXCommentItem(
                                                  context: context,
                                                  comment: sub,
                                                  isLast:
                                                      isLastSub &&
                                                      isLastTopComment,
                                                  isDark: isDark,
                                                  primaryColor: primaryColor,
                                                  secondaryColor:
                                                      secondaryColor,
                                                ),
                                              ),
                                            );
                                          }

                                          commentWidgets.add(
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 46,
                                                top: 0,
                                                bottom: 16,
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  setState(
                                                    () => _expandedCommentIds
                                                        .remove(topComment.id),
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                        horizontal: 6,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 20,
                                                        height: 1.5,
                                                        color: secondaryColor
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        subReplies.length == 1
                                                            ? 'Hide reply'
                                                            : 'Hide replies',
                                                        style: TextStyle(
                                                          color: secondaryColor,
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons
                                                            .keyboard_arrow_up_rounded,
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
    // A commenter is a person, and gramX has somewhere to put one now. The
    // channel screen is still where a comment posted *by a channel* leads,
    // which is what the null case is.
    final senderUserId = comment.senderUserId;
    void openAuthor() {
      if (senderUserId != null) {
        context.push(UserProfileScreen.routeFor(senderUserId));
      } else {
        context.push('/channel/${comment.channelId}');
      }
    }

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
                onTap: openAuthor,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
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
                        child: GestureDetector(
                          onTap: openAuthor,
                          child: Text(
                            comment.channelTitle,
                            style:
                                AppTypography.displayName(
                                  color: primaryColor,
                                ).copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (comment.channelUsername != null &&
                          comment.channelUsername!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '@${comment.channelUsername}',
                            style: AppTypography.username(
                              color: secondaryColor,
                            ).copyWith(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      Text(
                        '·',
                        style: AppTypography.username(color: secondaryColor),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        TimeUtils.relativeTime(comment.publishedAt),
                        style: AppTypography.timestamp(
                          color: secondaryColor,
                        ).copyWith(fontSize: 12),
                      ),
                    ],
                  ),

                  // A comment is already inside a thread, under a
                  // connector, inside this screen. The card form would be a
                  // fourth box, so it stays the line whatever it has.
                  ReplyTarget(
                    post: comment,
                    compact: true,
                    onOpenPost: () => _openReplyTarget(context, comment),
                    onOpenAuthor: openAuthor,
                  ),

                  // Text Content
                  if (comment.text != null && comment.text!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    TextEntityRenderer(
                      text: comment.text!,
                      entities: comment.entities,
                      style: AppTypography.body(
                        color: primaryColor,
                      ).copyWith(fontSize: 14, height: 1.3),
                    ),
                  ],

                  // Media Attachments
                  if (comment.media.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: PostMediaGrid(media: comment.media, post: comment),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
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
                                  style: AppTypography.actionCount(
                                    color: secondaryColor,
                                  ).copyWith(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Reactions, with the post's own control: any reaction
                      // the chat allows, not a hard-coded heart.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: ReactionControl(
                          post: comment,
                          color: secondaryColor,
                          iconSize: 16,
                          emojiSize: 15,
                          countFontSize: 12,
                          onSelectReaction: (emoji) =>
                              _toggleReaction(comment, emoji),
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
            // answered, with no tinted band behind it. The bubble in a
            // conversation and the composer in one both say it this way now,
            // so the three places a reply is named all look like each other.
            if (_replyTargetPost != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 0),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 14, color: secondaryColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        AppStrings.chatReplyingToName(
                          _replyTargetPost!.channelTitle,
                        ),
                        style: AppTypography.timestamp(
                          color: AppColors.accent,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.chatCancelReply,
                      onPressed: () => setState(() => _replyTargetPost = null),
                      icon: Icon(Icons.close, size: 16, color: secondaryColor),
                    ),
                  ],
                ),
              ),
            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ComposeAttachmentStrip(
                  attachments: _attachments,
                  onRemove: (index) =>
                      setState(() => _attachments.removeAt(index)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // The reader's own face, not the channel's. This is where
                  // *you* are about to say something, and the channel's
                  // initial sitting there made every comment box look like the
                  // channel was about to answer itself.
                  _CommenterAvatar(),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: AppStrings.chatAttach,
                    visualDensity: VisualDensity.compact,
                    onPressed: _isSending ? null : _attachToComment,
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.composeStickersTab,
                    visualDensity: VisualDensity.compact,
                    onPressed: _isSending
                        ? null
                        : () =>
                              _sendStickerComment(post.chatId, post.messageId),
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTypography.body(color: primaryColor),
                      // Rebuilds the send button's enabled state; the field
                      // itself stays uncontrolled, so this costs one setState
                      // per keystroke and no request at all.
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: _replyTargetPost != null
                            ? AppStrings.commentReplyHint
                            : AppStrings.commentHint,
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
                    tooltip: AppStrings.chatSend,
                    // Disabled rather than hidden, so the button does not move
                    // out from under a thumb that is already on it.
                    onPressed: _canSendComment
                        ? () => _sendComment(post.chatId, post.messageId)
                        : null,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _canSendComment
                                  ? AppColors.accent
                                  : secondaryColor.withValues(alpha: 0.4),
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

  /// The passage a post singles out of what it answers, above the post.
  ///
  /// Sized to this screen's larger avatar so the connector runs straight down
  /// the gutter instead of stepping sideways where it meets the post.
  Widget _quotedPassage(BuildContext context, Post post) {
    final isSameChat = post.replyToChatId == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: QuotedPassage(
        authorTitle: post.replyToAuthorTitle,
        authorUsername: isSameChat ? post.channelUsername : null,
        isAuthorVerified: isSameChat && post.isChannelVerified,
        avatarPath: isSameChat ? post.channelAvatarUrl : null,
        avatarFileId: isSameChat ? post.channelAvatarFileId : null,
        avatarColorHex: isSameChat ? post.channelAvatarColor : null,
        passage: post.replyToText!,
        avatarRadius: AppSpacing.avatarSizeLarge / 2,
        gutterGap: AppSpacing.avatarGap,
        onTap: () => _openReplyTarget(context, post),
        onAuthorTap: () => context.push('/channel/${post.channelId}'),
      ),
    );
  }

  /// Opens the message [post] answers.
  ///
  /// The reply may live in another chat — see `Post.replyToChatId`. Assuming
  /// this one asks for a message id that does not exist there, which reports
  /// itself as "post not found" however reachable the real one is.
  void _openReplyTarget(BuildContext context, Post post) {
    final messageId = post.replyToMessageId;
    if (messageId == null) {
      context.push('/channel/${post.channelId}');
      return;
    }
    context.push('/post/${post.replyToChatId ?? post.chatId}_$messageId');
  }
}

/// The reader's own face, beside the comment field.
///
/// Its own `ConsumerWidget` so the account lookup rebuilds this alone rather
/// than the whole input bar on every frame of the stream behind it.
class _CommenterAvatar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider).value;
    return ChannelAvatar(
      title: account?.displayName ?? AppStrings.drawerAccountFallback,
      avatarPath: account?.avatarPath,
      radius: 16,
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

    if (link == null ||
        !await launchUrl(
          Uri.parse(link),
          mode: LaunchMode.externalApplication,
        )) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.postCannotOpenTelegram)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

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
              style: AppTypography.subheading(
                color: theme.colorScheme.onSurface,
              ),
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
