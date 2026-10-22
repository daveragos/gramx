import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/feed/presentation/copy_post_link.dart';
import 'package:gramx/features/feed/presentation/reaction_controller.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/features/post_detail/domain/comment_threads.dart';
import 'package:gramx/features/post_detail/presentation/widgets/comment_sender_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/trok/data/trok_mention.dart';
import 'package:gramx/features/trok/presentation/trok_inline_translation.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mention_suggestion.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_sheets.dart';
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
import 'package:gramx/features/bookmarks/presentation/bookmark_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_chips_row.dart';
import 'package:gramx/features/feed/presentation/widgets/post_menu_sheet.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/app/widgets/app_sheet.dart';
import 'package:gramx/app/widgets/edit_text_dialog.dart';
import 'package:gramx/features/feed/presentation/media_seek.dart';

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
  /// The page's side margins, and the space above media, a link preview or
  /// a poll.
  static const double _inset = 8;
  static const double _blockGap = 16;

  /// The reply bar's pill.
  static const double _replyBarHeight = 56.4;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  Post? _replyTargetPost;
  final Set<String> _expandedCommentIds = {};

  /// Pictures and videos attached to the comment but not yet posted.
  final List<ComposeAttachment> _attachments = [];

  bool _isSending = false;

  StreamSubscription<LivePostUpdate>? _liveSub;
  Timer? _refreshDebounce;

  /// The chat the comments are in, looked up so that an empty thread still
  /// shows the first comment as it arrives.
  int? _threadChatId;

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
    final parts = widget.postId.split('_');
    final chatId = int.tryParse(parts.first);
    final messageId = parts.length == 2 ? int.tryParse(parts.last) : null;
    if (chatId != null && messageId != null) {
      ref
          .read(feedRepositoryProvider)
          .commentsChatId(chatId, messageId)
          .then((id) => _threadChatId = id);
    }

    _liveSub = ref.read(syncServiceProvider).livePostUpdates.listen((update) {
      if (update is! LiveNewMessage) return;

      final loaded = ref.read(postCommentsProvider(widget.postId)).value;
      final threadChatId = loaded?.firstOrNull?.chatId ?? _threadChatId;
      if (threadChatId == null || update.message.chatId != threadChatId) {
        return;
      }

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

  /// Reacts to the post or a comment. The update stream reconciles it.
  Future<void> _toggleReaction(Post post, String emoji) async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await ref
        .read(reactionControllerProvider.notifier)
        .react(post, emoji);
    if (!sent && isSendableReaction(emoji)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.reactionFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            // @Trok goes to the bot that calls Trok to answer under the post.
            TrokMention.resolve(text),
            replyToMessageId: targetReply?.messageId,
            attachments: attachments,
            remote: remote,
          );
      if (mounted) {
        ref.invalidate(postCommentsFetchProvider(widget.postId));
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
        title: const Text(AppStrings.postTitle),
        actions: [
          // Trok on this post, where X puts Grok. It answers through the
          // reader's account.
          if (postAsync.value case final post?
              when ref.watch(readerCapabilitiesProvider).canMessage)
            Padding(
              padding: const EdgeInsets.only(right: 8.4),
              child: IconButton(
                tooltip: AppStrings.trokAskAboutPost,
                onPressed: () => TrokPostSheet.show(context, ref, post),
                icon: TrokMark(size: 24, color: primaryColor),
              ),
            ),
        ],
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

          final canViewStats =
              ref
                  .watch(
                    canViewPostStatsProvider((
                      chatId: post.chatId,
                      messageId: post.messageId,
                    )),
                  )
                  .value ==
              true;

          final screen = Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () async {
                    // Waits for both, so the spinner shows until they're in.
                    await Future.wait<Object?>([
                      ref.refresh(
                        postDetailFetchProvider(widget.postId).future,
                      ),
                      ref.refresh(
                        postCommentsFetchProvider(widget.postId).future,
                      ),
                    ]).catchError((_) => <Object?>[]);
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
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            _inset,
                            PostLayout.insetTop,
                            _inset,
                            0,
                          ),
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
                                    const SizedBox(width: PostLayout.avatarGap),
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
                                                const SizedBox(width: 2.5),
                                                Icon(
                                                  Icons.verified,
                                                  color: AppColors.verified,
                                                  size: MediaQuery.textScalerOf(
                                                    context,
                                                  ).scale(16.3),
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
                                    // The same "⋮" menu as the feed card,
                                    // reaching into the page's margin.
                                    Transform.translate(
                                      offset: const Offset(_inset - 4.4, 0),
                                      child: SizedBox(
                                        width: PostLayout.moreWidth,
                                        height: 40,
                                        child: PostMoreButton(
                                          color: secondaryColor,
                                          onTap: () => PostMenuSheet.show(
                                            context,
                                            ref,
                                            post,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 7.8),
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
                                // A context under the MediaSeekScope.
                                Builder(
                                  builder: (context) => TextEntityRenderer(
                                    onHashtagTap: (tag) =>
                                        openHashtagSearch(context, ref, tag),
                                    onMediaTimestampTap: playFromTimestamp(
                                      context,
                                      post.media,
                                      post: post,
                                    ),
                                    text: post.text!,
                                    entities: post.entities,
                                    style: AppTypography.detailBody(
                                      color: primaryColor,
                                    ),
                                    fullWidth: true,
                                  ),
                                ),
                                TrokInlineTranslation(
                                  post: post,
                                  style: AppTypography.detailBody(
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                              if (post.linkPreviewUrl != null &&
                                  post.linkPreviewUrl!.isNotEmpty) ...[
                                const SizedBox(height: _blockGap),
                                LinkPreviewCard(
                                  url: post.linkPreviewUrl!,
                                  title: post.linkPreviewTitle,
                                  description: post.linkPreviewDescription,
                                  imageUrl: post.linkPreviewImageUrl,
                                  imageFileId: post.linkPreviewFileId,
                                ),
                              ],
                              if (post.poll != null) ...[
                                const SizedBox(height: _blockGap),
                                FeedPollCard(
                                  poll: post.poll!,
                                  channelId: post.channelId,
                                  messageId: post.messageId,
                                ),
                              ],
                              if (post.media.isNotEmpty) ...[
                                const SizedBox(height: _blockGap),
                                PostMediaGrid(
                                  media: post.media,
                                  post: post,
                                  bleed: _inset,
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
                                  enabled: ref
                                      .watch(readerCapabilitiesProvider)
                                      .canReact,
                                ),
                              ],
                              const SizedBox(height: 12.7),
                              // The time, then the views, which open the
                              // post's stats where Telegram has them.
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: canViewStats
                                    ? () => context.push(
                                        PostStatsScreen.routeFor(
                                          post.chatId,
                                          post.messageId,
                                        ),
                                      )
                                    : null,
                                child: Text.rich(
                                  TextSpan(
                                    text: TimeUtils.fullDateTime(
                                      post.publishedAt,
                                    ),
                                    children: [
                                      if (post.viewCount > 0) ...[
                                        const TextSpan(text: ' · '),
                                        TextSpan(
                                          text: TimeUtils.formatCount(
                                            post.viewCount,
                                          ),
                                          style: AppTypography.displayName(
                                            color: primaryColor,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' ${AppStrings.statViews}',
                                        ),
                                      ],
                                    ],
                                  ),
                                  style: AppTypography.timestamp(
                                    color: secondaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // The feed card's actions, spread across the page.
                        // Their tap areas make its vertical padding.
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            13.2,
                            2.6,
                            12.3,
                            0,
                          ),
                          child: PostActionBar(
                            post: post,
                            secondaryColor: secondaryColor,
                            spread: true,
                            onBookmarkTap: () => ref
                                .read(bookmarkControllerProvider.notifier)
                                .toggle(post),
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
                            onShareTap: () => copyPostLink(
                              ref,
                              ScaffoldMessenger.of(context),
                              post,
                            ),
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
                                  error: (_, _) => Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          AppStrings.commentsLoadFailed,
                                          style: AppTypography.body(
                                            color: secondaryColor,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => ref.invalidate(
                                            postCommentsFetchProvider(
                                              widget.postId,
                                            ),
                                          ),
                                          child: const Text(AppStrings.retry),
                                        ),
                                      ],
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
                                          rootPost: post,
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
                                                  rootPost: post,
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

          // Timestamps in the post or its comments play the post's track.
          return MediaSeekScope(child: screen);
        },
      ),
    );
  }

  Widget _buildXCommentItem({
    required BuildContext context,

    /// The post the comments are under.
    required Post rootPost,
    required Post comment,
    required bool isLast,
    required bool isDark,
    required Color primaryColor,
    required Color secondaryColor,

    /// The comment this one answers. Null for top-level comments, which
    /// Telegram records as replies to the post.
    Post? replyingTo,
  }) {
    // What a timestamp in the comment plays: its own media, else that of the
    // comment it answers, else the post's, as in Telegram.
    final timestampOwner = [comment, ?replyingTo, rootPost].firstWhere(
      (p) => timestampTarget(p.media) != null,
      orElse: () => rootPost,
    );

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
                      // A context under the screen's MediaSeekScope.
                      Builder(
                        builder: (context) => TextEntityRenderer(
                          onMediaTimestampTap: playFromTimestamp(
                            context,
                            timestampOwner.media,
                            post: timestampOwner,
                          ),
                          text: comment.text!,
                          entities: comment.entities,
                          style: AppTypography.body(
                            color: primaryColor,
                          ).copyWith(fontSize: 14, height: 1.3),
                        ),
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
                            copyPostLink(
                              ref,
                              ScaffoldMessenger.of(context),
                              comment,
                            );
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
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fill =
        Theme.of(context).scaffoldBackgroundColor == AppColors.darkBackground
        ? AppColors.darkIncomingBubble
        : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100);
    final hasText = _commentController.text.isNotEmpty;

    return SafeArea(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
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
            TrokMentionSuggestion(controller: _commentController),
            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ComposeAttachmentStrip(
                  attachments: _attachments,
                  onRemove: (index) =>
                      setState(() => _attachments.removeAt(index)),
                ),
              ),
            // One floating pill, the user's picture at its start and the
            // tools at its end, as X's reply bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8.4),
              child: Container(
                constraints: const BoxConstraints(minHeight: _replyBarHeight),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(_replyBarHeight / 2),
                ),
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(_replyBarHeight / 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      // Centred on a one-line pill.
                      padding: const EdgeInsets.fromLTRB(7.2, 0, 9.9, 12.2),
                      // Whoever the comment comes from: the reader, or a
                      // channel they chose to comment as.
                      child: CommentSenderButton(postId: widget.postId),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        onTapOutside: (_) => _commentFocusNode.unfocus(),
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppTypography.body(
                          color: primaryColor,
                        ).copyWith(height: 1.2),
                        // Updates the send button.
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: _replyTargetPost != null
                              ? AppStrings.commentReplyHint
                              : AppStrings.commentHint,
                          hintStyle: AppTypography.username(
                            color: secondaryColor,
                          ),
                          // The pill is the field; the theme's outlines
                          // would box it.
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 20.7,
                          ),
                        ),
                      ),
                    ),
                    // Centred on a one-line pill, like the picture.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!hasText) ...[
                            IconButton(
                              tooltip: AppStrings.chatAttach,
                              onPressed: _isSending ? null : _attachToComment,
                              icon: Icon(
                                Icons.image_outlined,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            IconButton(
                              tooltip: AppStrings.chatStickers,
                              onPressed: _isSending
                                  ? null
                                  : () => _sendStickerComment(
                                      post.chatId,
                                      post.messageId,
                                    ),
                              icon: Icon(
                                Icons.gif_box_outlined,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                          ] else
                            IconButton(
                              tooltip: AppStrings.chatSend,
                              onPressed: _canSendComment
                                  ? () => _sendComment(
                                      post.chatId,
                                      post.messageId,
                                    )
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
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: _canSendComment
                                            ? AppColors.accent
                                            : secondaryColor.withValues(
                                                alpha: 0.4,
                                              ),
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
                    const SizedBox(width: 7.6),
                  ],
                ),
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
        authorChatId: post.replyToChatId,
        authorUsername: isSameChat ? post.channelUsername : null,
        isAuthorVerified: isSameChat && post.isChannelVerified,
        avatarPath: isSameChat ? post.channelAvatarUrl : null,
        avatarFileId: isSameChat ? post.channelAvatarFileId : null,
        avatarColorHex: isSameChat ? post.channelAvatarColor : null,
        passage: post.replyToText!,
        avatarRadius: AppSpacing.avatarSizeLarge / 2,
        gutterGap: AppSpacing.avatarGap,
        onTap: () => _openReplyTarget(context, post),
        // The passage's own chat, which may not be this one.
        onAuthorTap: () => NavigationUtils.openChannel(
          context,
          '${post.replyToChatId ?? post.chatId}',
        ),
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
