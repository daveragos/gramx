import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/post_detail/domain/comment_threads.dart';
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
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_attachment_strip.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_media_kind_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_sticker_sheet.dart';
import 'package:gramx/features/compose/presentation/widgets/composer_tools.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/stats/presentation/post_stats_screen.dart';
import 'package:gramx/features/stats/presentation/stats_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/feed/domain/reply_presentation.dart';
import 'package:gramx/features/feed/presentation/widgets/reply_target.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_control.dart';
import 'package:gramx/features/feed/presentation/widgets/link_preview_card.dart';
import 'package:gramx/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_chips_row.dart';
import 'package:gramx/features/feed/presentation/widgets/post_menu_sheet.dart';
import 'package:gramx/app/widgets/app_sheet.dart';
import 'package:gramx/app/widgets/edit_text_dialog.dart';

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

  /// Pictures and videos attached to the comment but not yet posted.
  final List<ComposeAttachment> _attachments = [];

  bool _isSending = false;

  /// Whether the attach and sticker buttons are unfolded while typing.
  bool _commentToolsExpanded = false;

  StreamSubscription<LivePostUpdate>? _liveSub;
  Timer? _refreshDebounce;

  /// Replies arrive in bursts, so a short wait batches them into one refetch.
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

  /// Keeps an open thread current, matching updates on the comments' chat id.
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
    // No invalidate: the update stream reconciles the optimistic override.
  }

  bool get _canSendComment =>
      !_isSending &&
      (_commentController.text.trim().isNotEmpty || _attachments.isNotEmpty);

  /// Attaches a picture or a video through the shared media picker.
  Future<void> _attachToComment() async {
    final choice = await ComposeMediaKindSheet.show(context);
    if (choice == null || !mounted) return;

    final picker = ref.read(composeMediaPickerProvider);
    final attachment = choice == ComposeAttachChoice.photo
        ? await picker.pickPhoto()
        : await picker.pickVideo();
    if (attachment == null || !mounted) return;
    setState(() => _attachments.add(attachment));
  }

  /// Picks a sticker or a GIF and sends it at once, on its own:
  /// `inputMessageSticker` has no caption field, so typed text would be lost.
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
    _commentFocusNode.unfocus();
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
        // Restore the typed text so a failed send does not lose it.
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

  /// The long-press menu on a comment: reply, copy, and edit where allowed.
  Future<void> _openCommentActions(Post comment) async {
    HapticFeedback.mediumImpact();
    final rights = await ref
        .read(chatsRepositoryProvider)
        .messageActions(chatId: comment.chatId, messageId: comment.messageId);
    if (!mounted) return;

    final text = comment.text;
    final choice = await showAppSheet<_CommentAction>(
      context,
      haptic: false,
      children: [
        if (rights.canReply)
          const AppSheetRow<_CommentAction>(
            icon: Icons.reply_rounded,
            label: AppStrings.chatActionReply,
            value: _CommentAction.reply,
          ),
        if (text != null && text.isNotEmpty)
          const AppSheetRow<_CommentAction>(
            icon: Icons.copy_rounded,
            label: AppStrings.chatActionCopy,
            value: _CommentAction.copy,
          ),
        if (rights.canEdit)
          const AppSheetRow<_CommentAction>(
            icon: Icons.edit_outlined,
            label: AppStrings.chatActionEdit,
            value: _CommentAction.edit,
          ),
      ],
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case _CommentAction.reply:
        setState(() => _replyTargetPost = comment);
        _commentFocusNode.requestFocus();
      case _CommentAction.copy:
        await Clipboard.setData(ClipboardData(text: text ?? ''));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.chatCopied),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case _CommentAction.edit:
        await _editComment(comment);
    }
  }

  /// Edits a comment's text, shown at once without a refetch.
  Future<void> _editComment(Post comment) async {
    final isCaption = comment.media.isNotEmpty;
    final updated = await EditTextDialog.show(
      context,
      initialText: comment.text ?? '',
      title: AppStrings.commentEditTitle,
      allowsEmpty: isCaption,
    );
    if (updated == null || !mounted) return;

    final ok = await ref
        .read(chatsRepositoryProvider)
        .editText(
          chatId: comment.chatId,
          messageId: comment.messageId,
          text: updated,
          isCaption: isCaption,
        );
    if (!mounted) return;

    if (ok) {
      ref
          .read(optimisticPostUpdatesProvider.notifier)
          .setText(comment.id, updated);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? AppStrings.chatEditSaved : AppStrings.chatEditFailed,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      // A guest has no account to write read state to, and the message id is
      // made up locally. See ReaderCapabilities.
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
            // Telegram may still be able to show it, so offer that.
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
                    // iOS has no back key to put the keyboard away.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.postPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                    // The same "…" menu as the feed card.
                                    IconButton(
                                      tooltip: AppStrings.postMenuTooltip,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => PostMenuSheet.show(
                                        context,
                                        ref,
                                        post,
                                      ),
                                      icon: Icon(
                                        Icons.more_horiz_rounded,
                                        color: secondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              // The "Replying to" line, above the body. The
                              // card form sits below it; see ReplySlot.
                              ReplyTarget(
                                post: post,
                                onOpenPost: () =>
                                    _openReplyTarget(context, post),
                                onOpenAuthor: () =>
                                    context.push('/channel/${post.channelId}'),
                              ),
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
                              // The post being answered, under the answer.
                              ReplyTarget(
                                post: post,
                                slot: ReplySlot.belowBody,
                                onOpenPost: () =>
                                    _openReplyTarget(context, post),
                                onOpenAuthor: () =>
                                    context.push('/channel/${post.channelId}'),
                              ),
                              if (post.reactions.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                ReactionChipsRow(
                                  reactions: post.reactions,
                                  chosen: post.chosenReactions,
                                  onTap: (emoji) =>
                                      _toggleReaction(post, emoji),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
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
                        // The same action bar as the feed card, whose tap
                        // areas make its vertical padding.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.postPadding,
                          ),
                          child: PostActionBar(
                            post: post,
                            secondaryColor: secondaryColor,
                            // Opens the post's stats, if Telegram has any.
                            onViewsTap:
                                ref
                                        .watch(
                                          canViewPostStatsProvider((
                                            chatId: post.chatId,
                                            messageId: post.messageId,
                                          )),
                                        )
                                        .value ==
                                    true
                                ? () => context.push(
                                    PostStatsScreen.routeFor(
                                      post.chatId,
                                      post.messageId,
                                    ),
                                  )
                                : null,
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

                                    final threads = threadComments(comments);

                                    final List<Widget> commentWidgets = [];

                                    for (int i = 0; i < threads.length; i++) {
                                      final topComment = threads[i].root;
                                      final subReplies = threads[i].replies;
                                      final isExpanded = _expandedCommentIds
                                          .contains(topComment.id);
                                      final isLastTopComment =
                                          i == threads.length - 1;

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
                                                  replyingTo: replyingToLabel(
                                                    sub,
                                                    j == 0
                                                        ? topComment
                                                        : subReplies[j - 1],
                                                    comments,
                                                  ),
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
              // Comment input bar
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

    /// The comment this one answers. Null for top-level comments, which
    /// Telegram records as replies to the post.
    Post? replyingTo,
  }) {
    // A comment posted by a channel has no sender user and opens the channel.
    final senderUserId = comment.senderUserId;
    void openAuthor() {
      if (senderUserId != null) {
        context.push(UserProfileScreen.routeFor(senderUserId));
      } else {
        context.push('/channel/${comment.channelId}');
      }
    }

    return GestureDetector(
      // Translucent, so taps on the author, media and action bar still work.
      behavior: HitTestBehavior.translucent,
      onLongPress: () => _openCommentActions(comment),
      child: IntrinsicHeight(
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

                    // Always the one-line form, never the card, since a
                    // comment already sits inside a thread. See [replyingTo].
                    if (replyingTo != null)
                      ReplyTarget(
                        post: comment.copyWith(
                          replyToAuthorTitle: replyingTo.channelTitle,
                        ),
                        compact: true,
                        onOpenPost: () => _openReplyTarget(context, comment),
                        onOpenAuthor: openAuthor,
                      ),

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

                    if (comment.media.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      PostMediaGrid(
                        media: comment.media,
                        post: comment,
                        maxVisualHeight: 220,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Action bar: reply, react, share
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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

                        // Offers any reaction the chat allows.
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
            // A plain "Replying to" line, as in conversations.
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
                  // The user's own avatar, not the channel's.
                  _CommenterAvatar(),
                  const SizedBox(width: 6),
                  // Attach and stickers fold into one chevron while the field
                  // has text, so the field keeps its width.
                  CollapsibleComposerTools(
                    collapsed: composerToolsFolded(
                      hasText: _commentController.text.isNotEmpty,
                      expandedByHand: _commentToolsExpanded,
                      toolCount: 2,
                    ),
                    onExpand: () =>
                        setState(() => _commentToolsExpanded = true),
                    tools: [
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
                        tooltip: AppStrings.chatStickers,
                        visualDensity: VisualDensity.compact,
                        onPressed: _isSending
                            ? null
                            : () => _sendStickerComment(
                                post.chatId,
                                post.messageId,
                              ),
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          color: AppColors.accent,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      onTapOutside: (_) => _commentFocusNode.unfocus(),
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTypography.body(color: primaryColor),
                      // Updates the send button's enabled state. An emptied
                      // field unfolds the tools again.
                      onChanged: (value) => setState(() {
                        if (value.isEmpty) _commentToolsExpanded = false;
                      }),
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
                    // Disabled rather than hidden, so the layout stays put.
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

  /// The quoted passage above a post, sized to this screen's larger avatar so
  /// the connector runs straight down the gutter.
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

  /// Opens the message [post] answers, which may be in another chat (see
  /// `Post.replyToChatId`).
  void _openReplyTarget(BuildContext context, Post post) {
    final messageId = post.replyToMessageId;
    if (messageId == null) {
      context.push('/channel/${post.channelId}');
      return;
    }
    context.push('/post/${post.replyToChatId ?? post.chatId}_$messageId');
  }
}

/// The user's avatar beside the comment field. A separate widget so the
/// account lookup rebuilds only this, not the whole input bar.
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

/// Shown when a post can't be loaded, typically a forward from a channel the
/// user isn't in.
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

/// The actions in a comment's long-press menu.
enum _CommentAction { reply, copy, edit }
