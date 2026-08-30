import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/data/conversation_rows.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/chats/presentation/chat_search_providers.dart';
import 'package:gramx/features/chats/presentation/conversation_providers.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_date_separator.dart';
import 'package:gramx/features/chats/presentation/widgets/message_actions_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/message_bubble.dart';
import 'package:gramx/features/chats/presentation/widgets/message_composer.dart';

/// One conversation, open.
///
/// A plain `Scaffold` with a real `AppBar`, not a `ChromeScaffold`. The sliding
/// chrome exists so a *reading* surface gives its height back to the content
/// being scrolled through; a conversation is anchored to its bottom, and a
/// header that slid away while somebody typed would take the name of the person
/// they are talking to with it.
class ConversationScreen extends ConsumerStatefulWidget {
  final int chatId;

  const ConversationScreen({super.key, required this.chatId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  /// How close to the top the reader has to get before the next page is asked
  /// for. Far enough that the page usually lands before they reach the end of
  /// what is loaded.
  static const double _loadOlderThreshold = 400;

  /// How far off the bottom counts as "not at the bottom", which is what puts
  /// the jump-to-latest button on screen.
  static const double _atBottomSlack = 200;

  final ScrollController _scroll = ScrollController();

  /// The search field's own controller, so closing the field clears it.
  final TextEditingController _searchController = TextEditingController();

  /// Attached to the unread band, so the first frame can bring it into view.
  final GlobalKey _unreadBandKey = GlobalKey();

  /// Attached to whichever message a reply is currently jumping to.
  ///
  /// One key rather than one per message: there is only ever one target at a
  /// time, and a key per bubble would hold a `GlobalKey` for every message
  /// loaded.
  final GlobalKey _jumpKey = GlobalKey();

  /// The message a tapped reply points at, flashed while it is found.
  int? _jumpTargetId;

  ChatMessage? _replyTo;
  bool _showJumpButton = false;
  bool _hasMarkedRead = false;
  bool _hasAnchoredToUnread = false;
  bool _hasCheckedViewport = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Read state is written to every client the account owns, so the notifier
    // acknowledges nothing until a screen says it is actually showing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(conversationProvider(widget.chatId).notifier)
          .setVisible(isVisible: true);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// The list is `reverse: true`, so offset 0 is the newest message and the
  /// *maximum* extent is the oldest — which is why paging back watches the far
  /// end rather than the near one.
  void _onScroll() {
    if (!_scroll.hasClients) return;

    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels < _loadOlderThreshold) {
      _loadOlder();
    }

    final shouldShow = position.pixels > _atBottomSlack;
    if (shouldShow != _showJumpButton) {
      setState(() => _showJumpButton = shouldShow);
    }
  }

  /// Asks for the page above, then checks whether it was enough.
  ///
  /// The scroll listener alone was not: it only fires while something is
  /// *being* scrolled, and a page that does not fill the viewport can never be
  /// scrolled. TDLib chooses its own batch size and will happily answer a
  /// forty-message request with three, so a chat could open, show three
  /// messages and sit there — the history was there, nothing had asked for it.
  /// So each page ends by asking whether the list can scroll at all, and pulls
  /// again until it can or the chat runs out.
  Future<void> _loadOlder() async {
    final notifier = ref.read(conversationProvider(widget.chatId).notifier);
    await notifier.loadOlder();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final state = ref.read(conversationProvider(widget.chatId)).value;
      if (state == null || !state.hasMoreOlder) return;
      // Nothing to scroll means nothing will ever ask again.
      if (_scroll.position.maxScrollExtent <= 0) _loadOlder();
    });
  }

  void _jumpToLatest() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Acknowledges the backlog once, after the first page is on screen.
  ///
  /// Deliberately not in `build`, and deliberately not per visible bubble: read
  /// state is pushed to every client this account owns. Opening a conversation
  /// *is* reading it, which is the one place the feed's dwell rules do not
  /// apply — a feed is a list you scroll past, a chat is a thing you opened.
  /// How many times the anchor will step up the scrollback looking for the
  /// band before it gives up and leaves the reader at the newest message.
  ///
  /// Bounded so a chat whose band is not in the loaded window cannot spin. Ten
  /// viewports is far more than `historyAround` ever puts between the read
  /// cursor and the bottom.
  static const int _anchorSteps = 10;

  /// Brings the unread band to the top of the viewport, once.
  ///
  /// This is the whole point of loading a window around the read cursor: an
  /// unread chat opens *at the line*, and the reader goes down from there to
  /// the latest. Landing them on the newest message means scrolling up through
  /// a conversation to read it forwards, which is backwards.
  ///
  /// Finding the band is two-step, for the same reason `_jumpToReply` is.
  /// `ListView.builder` only builds near the viewport, so a band twenty rows up
  /// has no `BuildContext` and `ensureVisible` silently does nothing — which is
  /// exactly what the first version of this did, on every chat with more than a
  /// screen of backlog. So: walk up a viewport at a time until the band is
  /// built, then let `ensureVisible` land it exactly.
  ///
  /// Stepping rather than estimating from an average row height, because on the
  /// first frame `maxScrollExtent` only covers what has been laid out so far —
  /// an average taken then is an average of the wrong thing, and it
  /// underestimates by however much of the chat has not been built.
  void _anchorToUnreadOnce() {
    if (_hasAnchoredToUnread) return;
    _hasAnchoredToUnread = true;

    WidgetsBinding.instance.addPostFrameCallback((_) => _anchorToUnread());
  }

  Future<void> _anchorToUnread() async {
    if (!mounted || !_scroll.hasClients) return;

    final state = ref.read(conversationProvider(widget.chatId)).value;
    if (state == null || state.firstUnreadMessageId == null) return;

    // The band has to exist in the rows at all. It does not when the first
    // unread message is older than the window that was loaded.
    final rows = ConversationRows.build(
      state.messages,
      firstUnreadMessageId: state.firstUnreadMessageId,
    );
    if (ConversationRows.unreadRowFromNewest(rows) == null) return;

    for (var step = 0; step < _anchorSteps; step++) {
      if (!mounted || !_scroll.hasClients) return;

      final bandContext = _unreadBandKey.currentContext;
      // `mounted` on the band's own context, not this State's: the band is
      // rebuilt as the walk scrolls past it, so the element found on the
      // previous turn of the loop may already be gone.
      if (bandContext != null && bandContext.mounted) {
        await Scrollable.ensureVisible(
          bandContext,
          // 1.0 in a reversed list puts the band at the top of the viewport, so
          // the unread run reads downwards from it — which is the whole point.
          alignment: 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      final position = _scroll.position;
      final target = position.pixels + position.viewportDimension * 0.8;
      // Nothing further up has been loaded. Stepping again would land on the
      // same pixel and burn the remaining tries.
      if (position.pixels >= position.maxScrollExtent) return;

      _scroll.jumpTo(target.clamp(0.0, position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _markReadOnce() {
    if (_hasMarkedRead) return;
    _hasMarkedRead = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(conversationProvider(widget.chatId).notifier);
      notifier.setVisible(isVisible: true);
      notifier.markVisibleRead();
    });
  }

  /// Kicks off [_loadOlder] once if the first page came back too short to
  /// scroll. Everything after that is driven by the scroll listener.
  void _fillViewportOnce() {
    if (_hasCheckedViewport) return;
    _hasCheckedViewport = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final state = ref.read(conversationProvider(widget.chatId)).value;
      if (state == null || !state.hasMoreOlder) return;
      if (_scroll.position.maxScrollExtent <= 0) _loadOlder();
    });
  }

  Future<bool> _send(String text, List attachments) async {
    final sent = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .send(
          text: text,
          attachments: attachments.cast(),
          replyToMessageId: _replyTo?.messageId,
        );
    if (sent && mounted) {
      setState(() => _replyTo = null);
      _jumpToLatest();
    }
    return sent;
  }

  /// A failed bubble is tappable, and that is its only way out.
  ///
  /// Nothing else on a bubble responds to a plain tap, so the gesture is free
  /// — and a warning icon with no action behind it is the inert control the
  /// hard rules forbid.
  Future<void> _handleTap(ChatMessage message) async {
    if (message.sendState != MessageSendState.failed) return;
    HapticFeedback.lightImpact();

    final ok = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .resend(message.messageId);
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.chatSendFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Jumps to the message a reply is answering.
  ///
  /// The quoted block looks exactly like the tappable thing it is in every
  /// other chat app, and did nothing — the styled-but-inert control the hard
  /// rules forbid.
  ///
  /// Finding it is two-step on purpose. `ListView.builder` only builds near the
  /// viewport, so a target far up the scrollback has no `BuildContext` for
  /// `ensureVisible` to work with. So: estimate the offset from the average row
  /// height and jump roughly there, then let `ensureVisible` land it exactly on
  /// the next frame. The estimate only has to be close enough to get the row
  /// built.
  Future<void> _jumpToReply(ChatMessage message) async {
    final targetId = message.replyToMessageId;
    // A cross-chat reply points somewhere this screen cannot scroll to.
    if (targetId == null || message.replyToChatId != null) return;

    await _jumpToMessage(targetId, missing: AppStrings.chatReplyNotLoaded);
  }

  /// Scrolls to one message and flashes it.
  ///
  /// Two-step, then a walk. `ListView.builder` only builds near the viewport,
  /// so a target far up the scrollback has no `BuildContext` for
  /// `ensureVisible` to work with: estimate the offset from the average row
  /// height and jump roughly there, then — because that estimate is only as
  /// good as the part of the list already laid out — step the rest of the way
  /// until the target is built. T21-1 is the round that learned the estimate
  /// alone is not enough.
  Future<void> _jumpToMessage(int targetId, {String? missing}) async {
    final state = ref.read(conversationProvider(widget.chatId)).value;
    if (state == null) return;

    final index = state.messages.indexWhere((m) => m.messageId == targetId);
    if (index < 0) {
      // Older than what is loaded. Saying so beats a tap that does nothing.
      if (missing != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(missing),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _jumpTargetId = targetId);

    // Reversed list: index 0 is the newest, so the target's distance is
    // measured from the end.
    final rowsFromBottom = state.messages.length - 1 - index;
    if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
      final average = _scroll.position.maxScrollExtent / state.messages.length;
      _scroll.jumpTo(
        (average * rowsFromBottom).clamp(0.0, _scroll.position.maxScrollExtent),
      );
    }

    for (var step = 0; step < _anchorSteps; step++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scroll.hasClients) break;

      final target = _jumpKey.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
        break;
      }

      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) break;
      _scroll.jumpTo(
        (position.pixels + position.viewportDimension * 0.8)
            .clamp(0.0, position.maxScrollExtent),
      );
    }

    // A flash, not a state: it says "here", and a bubble that stayed tinted
    // would read as selected.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _jumpTargetId = null);
  }

  /// Jumps to the pinned message.
  ///
  /// The same two-step walk a reply uses, and for the same reason: a pin is
  /// usually the oldest thing in the chat, which is the furthest a
  /// `ListView.builder` will not have built.
  Future<void> _jumpToPinned() async {
    final pinned = ref.read(pinnedMessageProvider(widget.chatId)).value;
    if (pinned == null) return;
    await _jumpToMessage(pinned.messageId);
  }

  /// Closes the search field and goes to the result.
  ///
  /// A hit older than the loaded page cannot be scrolled to, so the field
  /// stays open and says so rather than closing onto a list that did not move.
  Future<void> _openSearchResult(ChatMessage message) async {
    final state = ref.read(conversationProvider(widget.chatId)).value;
    final loaded =
        state?.messages.any((m) => m.messageId == message.messageId) ?? false;

    if (!loaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.chatSearchResultNotLoaded),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ref.read(inChatSearchQueryProvider.notifier).close();
    await _jumpToMessage(message.messageId);
  }

  /// Opens whatever an `@name` refers to.
  ///
  /// A mention in a channel post is always a channel; in a conversation it is
  /// usually a person, and the app has somewhere to put a person now. Which one
  /// it is has to be asked — one networked lookup per tap, which is on-demand
  /// and bounded, the shape `docs/TDLIB.md` allows.
  Future<void> _openMention(String username) async {
    final resolved = await ref
        .read(chatsRepositoryProvider)
        .resolveUsername(username);
    if (!mounted) return;

    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.chatMentionUnknown(username)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // A person opens a conversation; anything else is a channel or a group and
    // belongs on the channel screen, which is what used to happen to both.
    if (resolved.isPrivate) {
      context.push(ChatsScreen.routeFor(resolved.chatId));
    } else {
      NavigationUtils.openChannel(context, resolved.chatId.toString());
    }
  }

  Future<void> _openActions(ChatMessage message) async {
    HapticFeedback.mediumImpact();
    await MessageActionsSheet.show(
      context,
      chatId: widget.chatId,
      message: message,
      onReply: () => setState(() => _replyTo = message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationProvider(widget.chatId));
    final summary = ref.watch(chatSummaryProvider(widget.chatId));
    final searchQuery = ref.watch(inChatSearchQueryProvider);

    return Scaffold(
      appBar: searchQuery == null
          ? _ConversationAppBar(
              summary: summary,
              typing: conversation.value?.typing,
              onSearch: () {
                ref.read(inChatSearchQueryProvider.notifier).open();
                _searchController.clear();
              },
            )
          : _ChatSearchAppBar(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(inChatSearchQueryProvider.notifier).setQuery(value),
              onClose: () =>
                  ref.read(inChatSearchQueryProvider.notifier).close(),
            ),
      body: Column(
        children: [
          // Above the list rather than over it: a pinned message is part of
          // the chat's furniture, and one that floated would sit on top of
          // whatever the reader had scrolled to.
          if (searchQuery == null)
            _PinnedBar(
              chatId: widget.chatId,
              onTap: _jumpToPinned,
            ),
          if (searchQuery != null)
            Expanded(
              child: _ChatSearchResults(
                chatId: widget.chatId,
                onTap: _openSearchResult,
              ),
            )
          else
          Expanded(
            child: conversation.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (error, _) => _ErrorState(
                onRetry: () => ref
                    .read(conversationProvider(widget.chatId).notifier)
                    .refresh(),
              ),
              data: (state) {
                if (state.messages.isEmpty) return const _EmptyState();
                _markReadOnce();
                if (state.firstUnreadMessageId != null) _anchorToUnreadOnce();
                _fillViewportOnce();
                return _MessageList(
                  state: state,
                  controller: _scroll,
                  unreadBandKey: _unreadBandKey,
                  onTap: _handleTap,
                  onLongPress: _openActions,
                  onReplyTap: _jumpToReply,
                  onMentionTap: _openMention,
                  onSenderTap: (userId) =>
                      context.push(UserProfileScreen.routeFor(userId)),
                  jumpKey: _jumpKey,
                  jumpTargetId: _jumpTargetId,
                  onReact: (message, emoji) => ref
                      .read(conversationProvider(widget.chatId).notifier)
                      .toggleReaction(message.messageId, emoji),
                );
              },
            ),
          ),
          MessageComposer(
            // TDLib holds the draft, so one typed on a laptop is here and one
            // typed here is there. Read once, when the composer is built.
            initialText: ref
                .read(chatsRepositoryProvider)
                .draftText(widget.chatId),
            onDraftChanged: (text) => ref
                .read(chatsRepositoryProvider)
                .saveDraft(widget.chatId, text),
            replyTo: _replyTo,
            onCancelReply: () => setState(() => _replyTo = null),
            onSend: _send,
            onChanged: (value) {
              final signal = ref.read(typingSignalProvider(widget.chatId));
              if (value.isEmpty) {
                signal.stop();
              } else {
                signal.onTyping();
              }
            },
          ),
        ],
      ),
      floatingActionButton: _showJumpButton
          ? FloatingActionButton.small(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              tooltip: AppStrings.chatScrollToBottom,
              onPressed: _jumpToLatest,
              child: const Icon(Icons.arrow_downward_rounded),
            )
          : null,
    );
  }
}


/// The header while a chat is being searched.
///
/// Replaces the header rather than sitting under it: searching a conversation
/// is a mode, and a screen showing both who you are talking to and a field
/// asking what you are looking for is two headers arguing.
class _ChatSearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _ChatSearchAppBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: AppStrings.chatSearchClose,
        onPressed: onClose,
      ),
      titleSpacing: 0,
      title: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: AppTypography.body(color: primary),
        decoration: InputDecoration(
          hintText: AppStrings.chatSearchHint,
          hintStyle: AppTypography.body(color: secondary),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}

/// Matches for what is being searched for.
class _ChatSearchResults extends ConsumerWidget {
  final int chatId;
  final ValueChanged<ChatMessage> onTap;

  const _ChatSearchResults({required this.chatId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final query = ref.watch(inChatSearchQueryProvider) ?? '';
    final results = ref.watch(inChatSearchResultsProvider(chatId));

    // Nothing typed yet is not "no results". A screen saying nothing matched
    // an empty query has answered a question nobody asked.
    if (query.trim().isEmpty) {
      return _SearchMessage(
        text: AppStrings.chatSearchPrompt,
        color: secondary,
      );
    }

    return results.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (_, _) =>
          _SearchMessage(text: AppStrings.chatSearchFailed, color: secondary),
      data: (messages) {
        if (messages.isEmpty) {
          return _SearchMessage(
            text: AppStrings.chatSearchNoResults(query),
            color: secondary,
          );
        }

        return ListView.separated(
          itemCount: messages.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, thickness: 0.5, color: borderColor),
          itemBuilder: (context, index) {
            final message = messages[index];
            return ListTile(
              onTap: () => onTap(message),
              title: Text(
                message.text ?? '',
                style: AppTypography.body(color: primary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                TimeUtils.fullDateTime(message.sentAt),
                style: AppTypography.timestamp(color: secondary),
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchMessage extends StatelessWidget {
  final String text;
  final Color color;

  const _SearchMessage({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        text,
        style: AppTypography.body(color: color),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// The pinned message, above the conversation.
///
/// Absent entirely when there is no pin — and while the one request that
/// answers that is in flight, because a bar that appears a second after the
/// chat does moves what somebody has already started reading.
class _PinnedBar extends ConsumerWidget {
  final int chatId;
  final VoidCallback onTap;

  const _PinnedBar({required this.chatId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(pinnedMessageProvider(chatId)).value;
    if (pinned == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // A short accent rule, which is how Telegram marks a pin and how
            // this app already marks a quoted reply.
            Container(width: 2, height: 30, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.chatPinnedMessage,
                    style: AppTypography.timestamp(color: AppColors.accent),
                  ),
                  Text(
                    pinned.text ?? AppStrings.chatPinnedNoText,
                    style: AppTypography.actionCount(color: primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.push_pin_outlined, size: 16, color: secondary),
          ],
        ),
      ),
    );
  }
}

/// The header: who this is, and what they are doing.
class _ConversationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final ChatSummary? summary;
  final ChatTyping? typing;

  /// Opens the search field. Null when there is nothing to search — a chat
  /// still loading — so the control is absent rather than inert.
  final VoidCallback? onSearch;

  const _ConversationAppBar({
    required this.summary,
    this.typing,
    this.onSearch,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    // The typing line replaces the presence line rather than sitting beside it:
    // both answer "where are they right now", and the live one is the answer.
    final subtitle = typing != null
        ? AppStrings.chatTyping(typing!.action, name: typing!.name)
        : _presenceLabel(summary);
    final isLive = typing != null || summary?.presence == ChatPresence.online;

    // Only a person has a profile to open. A group's header stays inert rather
    // than leading somewhere that would have to say "this is not a person".
    final userId =
        summary?.kind.isDirect == true || summary?.kind == ChatKind.bot
        ? summary?.chatId
        : null;

    return AppBar(
      titleSpacing: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      actions: [
        if (onSearch != null)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: AppStrings.chatSearchTooltip,
            onPressed: onSearch,
          ),
      ],
      title: _MaybeTappable(
        onTap: userId == null || summary?.kind == ChatKind.savedMessages
            ? null
            : () => context.push(UserProfileScreen.routeFor(userId)),
        child: Row(
          children: [
            if (summary != null)
              ChannelAvatar(
                title: summary!.title,
                avatarPath: summary!.avatarPath,
                avatarFileId: summary!.avatarFileId,
                avatarColorHex: summary!.avatarColorHex,
                radius: AppSpacing.avatarSizeSmall / 2,
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          summary?.title ?? '',
                          style: AppTypography.displayName(color: primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (summary?.isVerified ?? false) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.verified,
                          color: AppColors.verified,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      // Typing and online are both *live* facts — someone is
                      // there, right now — so they share the accent. "last seen
                      // within a week" is history and stays secondary.
                      style: AppTypography.timestamp(
                        color: isLive ? AppColors.accent : secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Telegram's hedged presence words, or nothing at all.
  ///
  /// Nothing is the right answer for a group, a bot, and a person whose
  /// last-seen is hidden without even a bucket — inventing "offline" for those
  /// would be a claim about somebody the server never made.
  static String? _presenceLabel(ChatSummary? summary) =>
      switch (summary?.presence) {
        ChatPresence.online => AppStrings.chatOnline,
        ChatPresence.offline => AppStrings.chatLastSeenOffline,
        ChatPresence.recently => AppStrings.chatLastSeenRecently,
        ChatPresence.lastWeek => AppStrings.chatLastSeenWeek,
        ChatPresence.lastMonth => AppStrings.chatLastSeenMonth,
        _ => null,
      };
}

/// Makes its child tappable, or leaves it exactly as it was.
///
/// A `GestureDetector` with a null `onTap` still joins the gesture arena and
/// still swallows a long press aimed at what is underneath it, so "no handler"
/// has to mean *no detector* rather than a detector with nothing in it.
class _MaybeTappable extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _MaybeTappable({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

/// The scrollback.
///
/// `reverse: true`, so the list is anchored to the newest message and a new
/// arrival extends it downwards without moving what is being read — the same
/// property the feed's arrival pill protects, achieved here by the layout
/// rather than by holding messages back.
class _MessageList extends StatelessWidget {
  final ConversationState state;
  final ScrollController controller;

  /// Attached to the unread band so the screen can scroll it into view.
  final GlobalKey unreadBandKey;
  final void Function(ChatMessage message) onTap;
  final void Function(ChatMessage message) onLongPress;
  final void Function(ChatMessage message) onReplyTap;
  final ValueChanged<String> onMentionTap;
  final ValueChanged<int> onSenderTap;

  /// Attached to [jumpTargetId]'s bubble while a reply jump is in flight.
  final GlobalKey jumpKey;
  final int? jumpTargetId;
  final void Function(ChatMessage message, String emoji) onReact;

  const _MessageList({
    required this.state,
    required this.controller,
    required this.unreadBandKey,
    required this.onTap,
    required this.onReplyTap,
    required this.onMentionTap,
    required this.onSenderTap,
    required this.jumpKey,
    required this.jumpTargetId,
    required this.onLongPress,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final rows = ConversationRows.build(
      state.messages,
      firstUnreadMessageId: state.firstUnreadMessageId,
    ).reversed.toList();

    return ListView.builder(
      controller: controller,
      reverse: true,
      // Dragging the conversation puts the keyboard away, which is what the
      // gesture means everywhere else — scrolling back through a chat with a
      // keyboard covering half of it is the commonest annoyance in a messaging
      // app, and it costs one line to not have.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: rows.length + (state.hasMoreOlder ? 1 : 0),
      itemBuilder: (context, index) {
        // Reversed, so the loading row for older messages is the *last* item.
        if (index >= rows.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
          );
        }

        final row = rows[index];
        return switch (row) {
          ConversationDateRow() => ChatDateSeparator(date: row.date),
          ConversationUnreadRow() => ChatUnreadBand(key: unreadBandKey),
          ConversationMessageRow() => MessageBubble(
            key: row.message.messageId == jumpTargetId ? jumpKey : null,
            message: row.message,
            isGroup: state.isGroup,
            isFirstInGroup: row.isFirstInGroup,
            isLastInGroup: row.isLastInGroup,
            isHighlighted: row.message.messageId == jumpTargetId,
            onTap: () => onTap(row.message),
            onLongPress: () => onLongPress(row.message),
            onReplyTap: () => onReplyTap(row.message),
            onMentionTap: onMentionTap,
            onSenderTap: row.message.senderId == null
                ? null
                : () => onSenderTap(row.message.senderId!),
            onReactionTap: (emoji) => onReact(row.message, emoji),
          ),
        };
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
            Icon(Icons.chat_bubble_outline_rounded, size: 40, color: secondary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.chatEmptyTitle,
              style: AppTypography.subheading(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.chatEmptyBody,
              style: AppTypography.body(color: secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

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
            Text(
              AppStrings.chatHistoryFailed,
              style: AppTypography.body(color: secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onRetry,
              child: const Text(AppStrings.chatRetry),
            ),
          ],
        ),
      ),
    );
  }
}
