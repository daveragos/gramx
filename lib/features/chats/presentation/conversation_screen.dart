import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/features/chats/data/conversation_rows.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/domain/message_place.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/chats/presentation/chat_search_providers.dart';
import 'package:gramx/features/chats/presentation/conversation_providers.dart';
import 'package:gramx/features/chats/presentation/widgets/auto_delete_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/block_user.dart';
import 'package:gramx/features/chats/presentation/widgets/remove_chat.dart';
import 'package:gramx/features/chats/presentation/scheduled_messages_screen.dart';
import 'package:gramx/features/chats/presentation/video_note_recorder_screen.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_date_separator.dart';
import 'package:gramx/features/chats/presentation/widgets/contact_picker_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/forward_message_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/message_actions_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/message_bubble.dart';
import 'package:gramx/features/chats/presentation/widgets/message_composer.dart';
import 'package:gramx/features/chats/presentation/widgets/schedule_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/secret_media_bubble.dart';
import 'package:gramx/features/compose/data/location_service.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/app_sheet.dart';

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

  /// The messages the reader has ticked, in the order they ticked them.
  ///
  /// Null — not empty — when selection mode is off. An empty *set* is a real
  /// state the reader can reach by unticking the last one, and it has to look
  /// different from never having started: one keeps the selection bar up, the
  /// other puts the header back.
  Set<int>? _selected;

  /// What Telegram says may be done to each selected message, kept as it is
  /// ticked.
  ///
  /// One `getMessageProperties` per tick — user-driven and bounded, which is
  /// the on-demand shape `docs/TDLIB.md` allows, and the same request the
  /// long-press menu already makes for one message. Unticking costs nothing:
  /// the answer is still here, and the bar recomputes from what is left.
  final Map<int, MessageActions> _selectionRights = {};

  bool _showJumpButton = false;
  bool _hasMarkedRead = false;

  /// Where each built row is, so one can be held still while others change.
  final _RowRegistry _rows = _RowRegistry();

  /// The list itself, which rows are measured against.
  final GlobalKey _listKey = GlobalKey();

  /// A row, and how far below the top of the list it sat, taken just before
  /// the conversation changed. See [_holdPosition].
  ({Key key, double top})? _heldRow;

  /// Above zero while the screen is scrolling the list on purpose — landing on
  /// the unread band, or walking to a reply. Holding a row still then would
  /// fight the walk.
  int _walking = 0;

  /// Held from the start, because the composer saves its draft from its own
  /// `dispose()` — after this screen has been deactivated, when `ref` can no
  /// longer be read. Reading it there threw, and the draft somebody walked
  /// away from was never saved.
  late final ChatsRepository _repository;
  bool _hasAnchoredToUnread = false;
  bool _hasCheckedViewport = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(chatsRepositoryProvider);
    _scroll.addListener(_onScroll);
    // Called as the conversation changes, before the list is rebuilt — so the
    // layout being measured is still the one the reader is looking at.
    ref.listenManual(
      conversationProvider(widget.chatId),
      (previous, _) => _holdPosition(
        wasWindowed: previous?.value?.hasMoreNewer ?? false,
      ),
    );
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
    // Opened in the middle — after a jump to a search hit — the bottom edge
    // is a page boundary too, and scrolling towards it pages down.
    if (position.pixels < _loadOlderThreshold) {
      final state = ref.read(conversationProvider(widget.chatId)).value;
      if (state?.hasMoreNewer ?? false) {
        ref.read(conversationProvider(widget.chatId).notifier).loadNewer();
      }
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

  /// Goes to the newest message.
  ///
  /// From a window loaded around a search hit, "the newest message" is not on
  /// screen or anywhere near it, so the tail is loaded first and the scroll
  /// lands once it is there.
  Future<void> _jumpToLatest() async {
    final state = ref.read(conversationProvider(widget.chatId)).value;
    if (state?.hasMoreNewer ?? false) {
      _walking++;
      try {
        await ref
            .read(conversationProvider(widget.chatId).notifier)
            .returnToLatest();
        if (!mounted) return;
        await WidgetsBinding.instance.endOfFrame;
      } finally {
        _walking--;
      }
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
      return;
    }
    if (!_scroll.hasClients) return;
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
  /// Bounded so a chat whose band is not in the loaded window cannot spin, and
  /// sized for what opening can load: up to
  /// [ChatsRepository.backlogMaxMessages] between the band and the bottom,
  /// plus the pages a jump may add. Each step is one viewport and one frame,
  /// and the walk ends the moment the target is built.
  static const int _anchorSteps = 40;

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
    _walking++;
    try {
      await _walkToUnread();
    } finally {
      _walking--;
    }
  }

  Future<void> _walkToUnread() async {
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

  /// Keeps what the reader is looking at where it is while the conversation
  /// changes around it.
  ///
  /// The list is `reverse: true`, so it is laid out from the bottom up, and a
  /// row that grows pushes everything *above* it up the screen. Reactions,
  /// edits and votes all land on bubbles after they are drawn — TDLib
  /// refreshes an open chat's messages as soon as it is opened — so the unread
  /// band the screen had just scrolled to was shoved off the top, and anybody
  /// reading back through history had it slide away under them.
  ///
  /// So: before the change, note the topmost visible row and how far down the
  /// list it sits; after the frame that applies the change, put it back. Only
  /// away from the bottom. At the bottom the list is *meant* to move — a new
  /// message pushing the conversation up is how the reader sees it arrive.
  ///
  /// [wasWindowed] says the conversation was showing a stretch of history that
  /// stopped short of the newest message. Then the bottom edge is a page
  /// boundary, not the bottom of the chat, and a page landing below is a
  /// change to hold still through — the same as one landing above — rather
  /// than a new message to let the list move for.
  void _holdPosition({bool wasWindowed = false}) {
    if (_heldRow != null || _walking > 0 || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!wasWindowed && position.pixels <= _atBottomSlack) return;
    // The reader's own finger, or a fling, is moving it. Nothing here should
    // fight that.
    if (position.isScrollingNotifier.value) return;

    final held = _rows.topmostVisible(_listKey);
    if (held == null) return;
    _heldRow = held;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  void _restorePosition() {
    final held = _heldRow;
    _heldRow = null;
    if (held == null || !mounted || !_scroll.hasClients) return;

    final top = _rows.topOf(held.key, _listKey);
    if (top == null) return;
    // Reversed: more pixels is further back, which moves the content down.
    final drift = held.top - top;
    if (drift.abs() < 0.5) return;

    final position = _scroll.position;
    _scroll.jumpTo(
      (position.pixels + drift).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
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

  Future<bool> _send(
    String text,
    List<ComposeAttachment> attachments,
    MessageSchedule schedule,
  ) async {
    final sent = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .send(
          text: text,
          attachments: attachments,
          replyToMessageId: _replyTo?.messageId,
          schedule: schedule,
        );
    if (sent && mounted) {
      setState(() => _replyTo = null);
      // A scheduled message is not in the conversation — Telegram holds it
      // apart until it goes — so there is nothing at the bottom to scroll to,
      // and saying where it went is the only feedback there can be.
      if (schedule.isImmediate) {
        _jumpToLatest();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.scheduleQueued),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    return sent;
  }

  /// Asks when a message should go, and refuses a time Telegram would.
  Future<MessageSchedule?> _pickSchedule() async {
    final schedule = await ScheduleSheet.show(
      context,
      // "When they come online" needs a *they*. There is no such moment for a
      // group, so the row is absent rather than present and meaningless.
      allowsWhenOnline: ref
          .read(chatsRepositoryProvider)
          .isPrivateChat(widget.chatId),
    );
    if (schedule == null || !mounted) return null;

    if (!schedule.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.scheduleInvalid),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
    return schedule;
  }

  /// Opens a location or venue in whatever maps app the device has.
  ///
  /// A `geo:` URI, which every platform routes to its own maps app — gramX
  /// draws no map of its own and has no tile provider to draw one from, so the
  /// honest thing is to hand the place to something that does.
  Future<void> _openPlace(MessagePlace place) async {
    final opened = await openExternalUrl(Uri.parse(place.geoUri));
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.placeOpenFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Records a round video message and hands it back to the composer.
  Future<ComposeAttachment?> _recordVideoNote() =>
      VideoNoteRecorderScreen.show(context);

  /// Asks the device where it is and sends that.
  ///
  /// The permission is requested inside [LocationService], at this moment and
  /// nowhere else. Both failures say something the reader can act on — one is
  /// fixable in Settings, the other is not fixable at all — so they are told
  /// apart rather than collapsed into "couldn't send".
  Future<bool> _sendLocation() async {
    final result = await const LocationService().current();
    if (!mounted) return false;

    final location = result.location;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failure == LocationFailure.noPermission
                ? AppStrings.locationNoPermission
                : AppStrings.locationUnavailable,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // True, so the composer does not add a second message on top of the one
      // just shown. The reader has been told why; saying it twice is noise.
      return true;
    }

    final sent = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .sendLocation(
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          replyToMessageId: _replyTo?.messageId,
        );
    if (sent && mounted) {
      setState(() => _replyTo = null);
      _jumpToLatest();
    }
    return sent;
  }

  Future<bool> _sendContact() async {
    final userId = await ContactPickerSheet.show(context);
    // Backing out of the picker is not a failure, and must not draw one.
    if (userId == null || !mounted) return true;

    final sent = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .sendContact(
          userId: userId,
          replyToMessageId: _replyTo?.messageId,
        );
    if (sent && mounted) {
      setState(() => _replyTo = null);
      _jumpToLatest();
    }
    return sent;
  }

  /// Sends a sticker or a GIF the composer picked.
  Future<bool> _sendRemote(ComposeRemoteMedia media) async {
    final sent = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .sendRemote(media, replyToMessageId: _replyTo?.messageId);
    if (sent && mounted) {
      setState(() => _replyTo = null);
      _jumpToLatest();
    }
    return sent;
  }

  Future<bool> _sendPoll(PollDraft draft) async {
    final sent = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .sendPoll(draft, replyToMessageId: _replyTo?.messageId);
    if (sent && mounted) {
      setState(() => _replyTo = null);
      _jumpToLatest();
    }
    return sent;
  }

  /// Opens media that disappears once opened.
  ///
  /// The confirmation is not ceremony. Opening is irreversible: Telegram tells
  /// the sender it was seen, the clock starts, and for view-once media the
  /// content is gone the moment the viewer closes it. Somebody who taps a
  /// bubble by accident should not lose the thing they were sent, so the tap
  /// asks, and the answer is what reaches TDLib.
  Future<void> _openSecretMedia(ChatMessage message) async {
    if (message.isOutgoing || !message.isSecretMedia) return;

    final confirmed = await showAppDialog<bool>(
      context,
      title: AppStrings.secretMediaTapToView,
      body: message.isViewOnce
          ? AppStrings.secretMediaOnceWarning
          : AppStrings.secretMediaTimerWarning(message.selfDestructSeconds),
      actions: const [
        AppDialogAction(
          label: AppStrings.secretMediaTapToView,
          value: true,
          isPrimary: true,
        ),
        AppDialogAction.cancel(AppStrings.chatCancel),
      ],
    );
    if (confirmed != true || !mounted) return;

    final opened = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .openSecretMedia(message.messageId);
    if (!mounted) return;

    if (!opened || message.media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.secretMediaOpenFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await SecretMediaViewer.show(
      context,
      item: message.media.first,
      seconds: message.selfDestructSeconds,
    );
  }

  /// A failed bubble is tappable, and that is its only way out.
  ///
  /// Nothing else on a bubble responds to a plain tap, so the gesture is free
  /// — and a warning icon with no action behind it is the inert control the
  /// hard rules forbid.
  Future<void> _handleTap(ChatMessage message) async {
    // While selecting, a tap is a tick. Every other meaning a tap has in a
    // conversation is suspended for as long as the bar is up, which is what
    // makes selection mode a mode rather than a second gesture to remember.
    if (_isSelecting) {
      await _toggleSelected(message);
      return;
    }
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

    await _jumpToMessage(targetId);
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
  ///
  /// A target older than what is loaded is paged back to when it is close and
  /// loaded as a window around itself when it is not — see
  /// [ConversationNotifier.reveal]. Only a message Telegram no longer has ends
  /// in a message rather than a jump, and it always ends in one of the two:
  /// the pinned bar used to do nothing at all for a pin older than the first
  /// page, and a search hit from last year answered "scroll up to reach it".
  Future<void> _jumpToMessage(int targetId) async {
    _walking++;
    try {
      await _walkToMessage(targetId);
    } finally {
      _walking--;
    }
  }

  Future<void> _walkToMessage(int targetId) async {
    final found = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .reveal(targetId);
    if (!mounted) return;

    final state = ref.read(conversationProvider(widget.chatId)).value;
    if (state == null) return;

    final index = state.messages.indexWhere((m) => m.messageId == targetId);
    if (!found || index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.chatMessageTooFarBack),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // The page that brought it in has to be laid out before the walk below
    // can measure anything.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

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
  /// A hit is nearly always far back — that is what search is for — so this
  /// pages at most once before loading the window around it. A hit Telegram
  /// no longer has keeps the field open and says so, rather than closing onto
  /// a list that did not move.
  Future<void> _openSearchResult(ChatMessage message) async {
    final found = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .reveal(message.messageId, maxPagesBack: 1);
    if (!mounted) return;

    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.chatMessageTooFarBack),
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

    // A person or a group opens a conversation; only a channel belongs on the
    // channel screen, which used to be where groups went too.
    switch (resolved.kind) {
      case ResolvedChatKind.person:
      case ResolvedChatKind.group:
        context.push(ChatsScreen.routeFor(resolved.chatId));
      case ResolvedChatKind.channel:
        NavigationUtils.openChannel(context, resolved.chatId.toString());
    }
  }

  // ── Selecting several messages ────────────────────────────────────────────

  /// Telegram's own cap on a bulk delete or forward.
  static const int _maxSelected = 100;

  bool get _isSelecting => _selected != null;

  /// Whether every ticked message may be taken back from everybody.
  ///
  /// An `AND` across the selection, from the answers Telegram already gave for
  /// each one — so "Delete for everyone" is offered exactly when it would work
  /// for all of them, rather than for some and failing on the rest.
  bool get _canRevokeSelection {
    final selected = _selected;
    if (selected == null || selected.isEmpty) return false;
    return selected.every(
      (id) => _selectionRights[id]?.canDeleteForAll ?? false,
    );
  }

  bool get _canForwardSelection {
    final selected = _selected;
    if (selected == null || selected.isEmpty) return false;
    return selected.every((id) => _selectionRights[id]?.canForward ?? false);
  }

  /// Enters selection mode with [message] already ticked.
  void _startSelecting(ChatMessage message) {
    setState(() => _selected = <int>{});
    _toggleSelected(message);
  }

  void _stopSelecting() {
    setState(() => _selected = null);
    _selectionRights.clear();
  }

  Future<void> _toggleSelected(ChatMessage message) async {
    final selected = _selected;
    if (selected == null) return;

    if (selected.contains(message.messageId)) {
      setState(() => selected.remove(message.messageId));
      return;
    }

    if (selected.length >= _maxSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.chatSelectLimit(_maxSelected)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => selected.add(message.messageId));

    // Asked once per message and remembered, so re-ticking one costs nothing.
    if (_selectionRights.containsKey(message.messageId)) return;
    final rights = await ref
        .read(chatsRepositoryProvider)
        .messageActions(chatId: widget.chatId, messageId: message.messageId);
    if (!mounted) return;
    setState(() => _selectionRights[message.messageId] = rights);
  }

  Future<void> _forwardSelection() async {
    final ids = _selected?.toList();
    if (ids == null || ids.isEmpty) return;

    final toChatId = await ForwardMessageSheet.show(context);
    if (toChatId == null || !mounted) return;

    // Oldest first, so they land in the order they were written rather than
    // the order they happened to be tapped in.
    ids.sort();
    final ok = await ref
        .read(chatsRepositoryProvider)
        .forward(
          fromChatId: widget.chatId,
          messageIds: ids,
          toChatId: toChatId,
        );
    if (!mounted) return;

    _stopSelecting();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppStrings.chatForwardedCount(ids.length)
              : AppStrings.chatForwardFailedPlain,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteSelection() async {
    final ids = _selected?.toList();
    if (ids == null || ids.isEmpty) return;

    final revoke = await showAppDialog<bool>(
      context,
      title: AppStrings.chatDeleteCountTitle(ids.length),
      body: AppStrings.chatDeleteBody,
      actions: [
        // Only when it would work for every one of them — see
        // [_canRevokeSelection].
        if (_canRevokeSelection)
          const AppDialogAction(
            label: AppStrings.chatActionDeleteForEveryone,
            value: true,
            isPrimary: true,
            isDestructive: true,
          ),
        AppDialogAction(
          label: AppStrings.chatActionDeleteForMe,
          value: false,
          isPrimary: !_canRevokeSelection,
          isDestructive: true,
        ),
        const AppDialogAction.cancel(AppStrings.chatCancel),
      ],
    );
    if (revoke == null || !mounted) return;

    final ok = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .delete(ids, revoke: revoke);
    if (!mounted) return;

    _stopSelecting();
    if (ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.chatDeleteFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Ends an end-to-end chat, asking first.
  ///
  /// Irreversible and two-sided — Telegram deletes the messages from both
  /// devices — so it confirms, and the confirmation says which of those two
  /// things is about to happen.
  Future<void> _closeSecretChat() async {
    final confirmed = await showAppDialog<bool>(
      context,
      title: AppStrings.secretChatCloseTitle,
      body: AppStrings.secretChatCloseBody,
      actions: const [
        AppDialogAction(
          label: AppStrings.secretChatCloseConfirm,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
        AppDialogAction.cancel(AppStrings.chatCancel),
      ],
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(chatsRepositoryProvider)
        .closeSecretChat(widget.chatId);
    if (!mounted) return;

    if (ok) {
      // The chat is gone. Staying on a screen for one would leave the reader
      // looking at a conversation that no longer exists on either device.
      Navigator.of(context).maybePop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.secretChatCloseFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Sets how long messages live in this chat.
  ///
  /// Chat-wide and two-sided, which is why it sits in the header's overflow
  /// rather than on the composer: it is a property of the conversation, not of
  /// the message being written.
  Future<void> _setAutoDelete() async {
    final repository = ref.read(chatsRepositoryProvider);
    final seconds = await AutoDeleteSheet.show(
      context,
      current: repository.autoDeleteTime(widget.chatId),
    );
    if (seconds == null || !mounted) return;

    final ok = await repository.setAutoDeleteTime(widget.chatId, seconds);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? AppStrings.autoDeleteSet(seconds) : AppStrings.autoDeleteFailed,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// The person behind a one-to-one chat, who can be blocked from it. Null for
  /// a group, and for Saved Messages. A private chat's id is its user's id.
  static int? _blockableUserId(ChatSummary? summary) =>
      summary != null &&
          (summary.kind == ChatKind.direct || summary.kind == ChatKind.bot) &&
          !summary.isSecret
      ? summary.chatId
      : null;

  /// Leaves this group or deletes this chat, then leaves the screen — there is
  /// no conversation left to be looking at.
  Future<void> _removeChat(ChatSummary summary) async {
    final ok = await confirmAndRemoveChat(
      context,
      _repository,
      chatId: widget.chatId,
      title: summary.title,
    );
    if (ok && mounted) Navigator.of(context).maybePop();
  }

  Future<void> _openActions(ChatMessage message) async {
    // A long press while selecting would open a menu about one message on top
    // of a bar about several. It ticks instead, which is the same thing a tap
    // does and the only sensible reading of the gesture in this mode.
    if (_isSelecting) {
      await _toggleSelected(message);
      return;
    }

    HapticFeedback.mediumImpact();
    final choice = await MessageActionsSheet.show(
      context,
      chatId: widget.chatId,
      message: message,
    );
    if (choice == null || !mounted) return;

    switch (choice.action) {
      case MessageAction.reply:
        setState(() => _replyTo = message);
      case MessageAction.select:
        _startSelecting(message);
      case MessageAction.forward ||
          MessageAction.edit ||
          MessageAction.pin ||
          MessageAction.delete:
        await runMessageAction(
          choice,
          context,
          ref,
          chatId: widget.chatId,
          message: message,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationProvider(widget.chatId));
    final summary = ref.watch(chatSummaryProvider(widget.chatId));
    final searchQuery = ref.watch(inChatSearchQueryProvider);

    return Scaffold(
      appBar: _isSelecting
          ? _SelectionAppBar(
              count: _selected!.length,
              canForward: _canForwardSelection,
              onClose: _stopSelecting,
              onForward: _forwardSelection,
              onDelete: _deleteSelection,
            )
          : searchQuery == null
          ? _ConversationAppBar(
              summary: summary,
              typing: conversation.value?.typing,
              onSearch: () {
                ref.read(inChatSearchQueryProvider.notifier).open();
                _searchController.clear();
              },
              onAutoDelete:
                  ref.read(chatsRepositoryProvider).canSetAutoDelete(
                    widget.chatId,
                  )
                  ? _setAutoDelete
                  : null,
              // Only when there is something on it. TDLib keeps
              // `hasScheduledMessages` current, so this costs nothing to ask
              // and there is no way into an empty screen.
              onScheduled:
                  ref.read(chatsRepositoryProvider).hasScheduledMessages(
                    widget.chatId,
                  )
                  ? () => ScheduledMessagesScreen.show(context, widget.chatId)
                  : null,
              onCloseSecretChat:
                  ref.read(chatsRepositoryProvider).isSecretChat(widget.chatId)
                  ? _closeSecretChat
                  : null,
              // Saved Messages has nobody to leave or block.
              onRemove:
                  summary == null || summary.kind == ChatKind.savedMessages
                  ? null
                  : () => _removeChat(summary),
              isGroup: summary?.kind == ChatKind.group,
              isBlocked: () =>
                  _blockableUserId(summary) != null &&
                  _repository.isBlocked(_blockableUserId(summary)!),
              onToggleBlock: _blockableUserId(summary) == null
                  ? null
                  : () => toggleBlock(
                      context,
                      _repository,
                      userId: _blockableUserId(summary)!,
                      name: summary!.title,
                    ),
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
          // Somebody the reader does not know started this chat. Telegram's
          // own clients put the choice right here, above what they said, and
          // without it the only way to block a stranger was to find their
          // profile first.
          if (searchQuery == null &&
              summary != null &&
              summary.isRequest &&
              _blockableUserId(summary) != null)
            _RequestBar(
              onBlock: () => toggleBlock(
                context,
                _repository,
                userId: _blockableUserId(summary)!,
                name: summary.title,
              ),
              onDismiss: () => _repository.dismissRequest(widget.chatId),
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
                // The jump button floats over the list rather than over the
                // whole screen. As the Scaffold's floating button it sat on
                // the composer's right edge — on top of the send and
                // microphone buttons.
                return Stack(
                  children: [
                    _MessageList(
                      listKey: _listKey,
                      registry: _rows,
                      state: state,
                      controller: _scroll,
                      unreadBandKey: _unreadBandKey,
                      onTap: _handleTap,
                      onLongPress: _openActions,
                      selected: _selected,
                      onReplyTap: _jumpToReply,
                      onMentionTap: _openMention,
                      onSenderTap: (userId) =>
                          context.push(UserProfileScreen.routeFor(userId)),
                      jumpKey: _jumpKey,
                      jumpTargetId: _jumpTargetId,
                      onReact: (message, emoji) => ref
                          .read(conversationProvider(widget.chatId).notifier)
                          .toggleReaction(message.messageId, emoji),
                      onVote: (message, optionIds) => ref
                          .read(conversationProvider(widget.chatId).notifier)
                          .vote(message.messageId, optionIds),
                      onOpenSecretMedia: _openSecretMedia,
                      onOpenPlace: _openPlace,
                    ),
                    if (_showJumpButton || state.hasMoreNewer)
                      Positioned(
                        right: AppSpacing.lg,
                        bottom: AppSpacing.lg,
                        child: FloatingActionButton.small(
                          heroTag: null,
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          tooltip: AppStrings.chatScrollToBottom,
                          onPressed: _jumpToLatest,
                          child: const Icon(Icons.arrow_downward_rounded),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // A secret chat that has not finished its key exchange takes nothing.
          // Telegram refuses the send outright, so the composer goes and a line
          // says what is being waited for — a composer that swallowed messages
          // until the other person happened to open Telegram is the worst
          // possible reading of "sent".
          if (ref.read(chatsRepositoryProvider).isSecretChatPending(
            widget.chatId,
          ))
            const _SecretChatPendingNotice()
          else
          MessageComposer(
            // TDLib holds the draft, so one typed on a laptop is here and one
            // typed here is there. Read once, when the composer is built.
            initialText: ref
                .read(chatsRepositoryProvider)
                .draftText(widget.chatId),
            onDraftChanged: (text) =>
                _repository.saveDraft(widget.chatId, text),
            replyTo: _replyTo,
            onCancelReply: () => setState(() => _replyTo = null),
            onSend: _send,
            // Both are the chat's own answer, read from the cache rather than
            // guessed: Telegram takes a poll only where polls are permitted and
            // disappearing media only in a one-to-one chat, and a control that
            // is offered and then refused is worse than one that is not there.
            onSendPoll: ref.read(chatsRepositoryProvider).canSendPollsIn(widget.chatId)
                ? _sendPoll
                : null,
            allowsSelfDestruct: ref
                .read(chatsRepositoryProvider)
                .isPrivateChat(widget.chatId),
            // Telegram permissions media by kind, so each control asks its own
            // question. A group that allows photos and forbids voice messages
            // is a common setting, and a microphone that fails when held is
            // exactly the inert control the hard rules forbid.
            allowsVoiceNotes: ref
                .read(chatsRepositoryProvider)
                .canSendIn(widget.chatId, ChatSendRight.voiceNotes),
            allowsVideoNotes: ref
                .read(chatsRepositoryProvider)
                .canSendIn(widget.chatId, ChatSendRight.videoNotes),
            allowsDocuments: ref
                .read(chatsRepositoryProvider)
                .canSendIn(widget.chatId, ChatSendRight.documents),
            onRecordVideoNote: _recordVideoNote,
            onSendLocation: _sendLocation,
            onSendContact: _sendContact,
            // Stickers and GIFs are one permission in Telegram's model, and
            // a group can withhold it; the button goes rather than failing.
            onSendRemote: ref
                .read(chatsRepositoryProvider)
                .canSendIn(widget.chatId, ChatSendRight.stickers)
                ? _sendRemote
                : null,
            onPickSchedule: _pickSchedule,
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
    );
  }
}


/// What sits where the composer would, in a secret chat that is not ready yet.
class _SecretChatPendingNotice extends StatelessWidget {
  const _SecretChatPendingNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.lock_clock_rounded, size: 18, color: secondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  AppStrings.secretChatPending,
                  style: AppTypography.timestamp(color: secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The header while several messages are ticked.
///
/// Replaces the header rather than sitting under it, the same way the search
/// bar does and for the same reason: selecting is a mode, and a screen showing
/// both who you are talking to and how many of their messages you have ticked
/// is two headers arguing.
class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int count;

  /// Whether Telegram would forward every one of them. False hides the button
  /// rather than disabling it — a greyed control with no explanation is the
  /// same dead end as one that fails.
  final bool canForward;

  final VoidCallback onClose;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  const _SelectionAppBar({
    required this.count,
    required this.canForward,
    required this.onClose,
    required this.onForward,
    required this.onDelete,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: AppStrings.chatSelectCancel,
        onPressed: onClose,
      ),
      titleSpacing: 0,
      title: Text(
        AppStrings.chatSelectedCount(count),
        style: AppTypography.displayName(color: theme.colorScheme.onSurface),
      ),
      actions: [
        // Both are absent at zero rather than greyed: unticking the last
        // message leaves the bar up so the mode is still obvious, and there is
        // nothing for either button to act on.
        if (count > 0 && canForward)
          IconButton(
            icon: const Icon(Icons.forward_rounded),
            tooltip: AppStrings.chatActionForward,
            onPressed: onForward,
          ),
        if (count > 0)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: theme.colorScheme.error,
            tooltip: AppStrings.chatActionDelete,
            onPressed: onDelete,
          ),
      ],
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

/// The choice offered above a chat started by a stranger.
class _RequestBar extends StatelessWidget {
  final VoidCallback onBlock;
  final VoidCallback onDismiss;

  const _RequestBar({required this.onBlock, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.requestBarText,
                style: AppTypography.timestamp(color: secondary),
              ),
            ),
            TextButton(
              onPressed: onBlock,
              child: Text(
                AppStrings.userBlock,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              child: const Text(AppStrings.requestBarDismiss),
            ),
          ],
        ),
      ),
    );
  }
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

  /// Opens the auto-delete timer. Null in a chat where Telegram does not offer
  /// one, so the overflow menu is absent rather than carrying a dead row.
  final VoidCallback? onAutoDelete;

  /// Opens the queue of messages waiting to be sent. Null when there is none.
  final VoidCallback? onScheduled;

  /// Ends an end-to-end chat. Null in every chat that is not one.
  final VoidCallback? onCloseSecretChat;

  /// Leaves the group or deletes the chat. Null where there is neither.
  final VoidCallback? onRemove;

  /// Which of the two [onRemove] is, for its label.
  final bool isGroup;

  /// Blocks or unblocks the person. Null in a group.
  final VoidCallback? onToggleBlock;

  /// Asked when the menu opens rather than when the header was built: a block
  /// lands on the chat record, which does not rebuild this screen, and a label
  /// read at build time went on saying "Block" after the block.
  final ValueGetter<bool> isBlocked;

  const _ConversationAppBar({
    required this.summary,
    this.typing,
    this.onSearch,
    this.onAutoDelete,
    this.onScheduled,
    this.onCloseSecretChat,
    this.onRemove,
    this.isGroup = false,
    this.onToggleBlock,
    this.isBlocked = _never,
  });

  static bool _never() => false;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  /// The "…" sheet. Rows only for what this chat can do — see the fields
  /// above for why each one may be null.
  ///
  /// The sheet closes before any row's callback runs, and the callbacks are
  /// the screen's own, so what they open afterwards is opened on a context
  /// that is still there.
  Future<void> _showMore(BuildContext context) {
    return showAppSheet<void>(
      context,
      haptic: false,
      children: [
        if (onScheduled != null)
          AppSheetRow<void>(
            icon: Icons.schedule_rounded,
            label: AppStrings.scheduleMenu,
            onTap: onScheduled,
          ),
        if (onAutoDelete != null)
          AppSheetRow<void>(
            icon: Icons.auto_delete_outlined,
            label: AppStrings.autoDeleteMenu,
            onTap: onAutoDelete,
          ),
        if (onToggleBlock != null)
          AppSheetRow<void>(
            icon: Icons.block_rounded,
            label: isBlocked() ? AppStrings.userUnblock : AppStrings.userBlock,
            onTap: onToggleBlock,
          ),
        if (onCloseSecretChat != null)
          AppSheetRow<void>(
            icon: Icons.lock_open_rounded,
            label: AppStrings.secretChatClose,
            isDestructive: true,
            onTap: onCloseSecretChat,
          ),
        if (onRemove != null)
          AppSheetRow<void>(
            icon: isGroup
                ? Icons.logout_rounded
                : Icons.delete_outline_rounded,
            label: isGroup
                ? AppStrings.messagesLeaveGroup
                : AppStrings.messagesDeleteChat,
            isDestructive: true,
            onTap: onRemove,
          ),
      ],
    );
  }

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
        if (onAutoDelete != null ||
            onScheduled != null ||
            onCloseSecretChat != null ||
            onRemove != null ||
            onToggleBlock != null)
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: AppStrings.chatMoreTooltip,
            onPressed: () => _showMore(context),
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
                      // The lock leads, before the name. It is the only visible
                      // difference between this chat and the ordinary one with
                      // the same person, and the header is where somebody
                      // checks which one they are typing into.
                      if (summary?.isSecret == true) ...[
                        Tooltip(
                          message: AppStrings.secretChatLockLabel,
                          child: Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: AppColors.verified,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
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
  final GlobalKey listKey;

  /// Every built row registers here, so the screen can measure them.
  final _RowRegistry registry;
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
  final Future<void> Function(ChatMessage message, List<int> optionIds) onVote;
  final void Function(ChatMessage message) onOpenSecretMedia;
  final void Function(MessagePlace place) onOpenPlace;

  /// The ticked message ids, or null when selection mode is off.
  final Set<int>? selected;

  const _MessageList({
    required this.listKey,
    required this.registry,
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
    required this.onVote,
    required this.onOpenSecretMedia,
    required this.onOpenPlace,
    required this.selected,
  });

  /// A key that follows a row wherever it moves in the list.
  ///
  /// The list is reversed, so every arrival is inserted at index 0 and shifts
  /// every other row up by one. Unkeyed, Flutter matched rows by *position*:
  /// the element that held a playing voice message was handed the next
  /// message along, and the player carried on under the wrong bubble. A key
  /// per row, and [ListView.builder]'s `findChildIndexCallback`, keep each
  /// bubble's state with its own message.
  static Key _keyFor(ConversationRow row) => switch (row) {
    ConversationDateRow() => ValueKey<String>(
      'date-${row.date.millisecondsSinceEpoch}',
    ),
    ConversationUnreadRow() => const ValueKey<String>('unread'),
    ConversationMessageRow() => ValueKey<String>(
      'message-${row.message.messageId}',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final rows = ConversationRows.build(
      state.messages,
      firstUnreadMessageId: state.firstUnreadMessageId,
    ).reversed.toList();
    final indexByKey = {
      for (var i = 0; i < rows.length; i++) _keyFor(rows[i]): i,
    };

    // Reversed, so index 0 is the bottom. A conversation opened in the middle
    // has a page waiting below as well as above, and says so with a spinner
    // at each end.
    final newerRows = state.hasMoreNewer ? 1 : 0;

    return ListView.builder(
      key: listKey,
      controller: controller,
      reverse: true,
      // Dragging the conversation puts the keyboard away, which is what the
      // gesture means everywhere else — scrolling back through a chat with a
      // keyboard covering half of it is the commonest annoyance in a messaging
      // app, and it costs one line to not have.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: rows.length + newerRows + (state.hasMoreOlder ? 1 : 0),
      findChildIndexCallback: (key) {
        final index = indexByKey[key];
        return index == null ? null : index + newerRows;
      },
      itemBuilder: (context, index) {
        if (newerRows == 1 && index == 0) {
          return const _LoadingRow(key: ValueKey<String>('loading-newer'));
        }
        final rowIndex = index - newerRows;
        // Reversed, so the loading row for older messages is the *last* item.
        if (rowIndex >= rows.length) {
          return const _LoadingRow(key: ValueKey<String>('loading-older'));
        }

        final row = rows[rowIndex];
        return _TrackedRow(
          key: _keyFor(row),
          registry: registry,
          child: _buildRow(row),
        );
      },
    );
  }

  Widget _buildRow(ConversationRow row) => switch (row) {
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
      onVote: (optionIds) => onVote(row.message, optionIds),
      onOpenSecretMedia: () => onOpenSecretMedia(row.message),
      onOpenPlace: row.message.place == null
          ? null
          : () => onOpenPlace(row.message.place!),
      onOpenContact: onSenderTap,
      isSelecting: selected != null,
      isSelected: selected?.contains(row.message.messageId) ?? false,
    ),
  };
}

/// The spinner at either end of the list while a page is on its way.
class _LoadingRow extends StatelessWidget {
  const _LoadingRow({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
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

/// Where each built row is on screen, by its key.
///
/// `ListView.builder` only builds rows near the viewport, and a row has no
/// position until it is built — so rather than a `GlobalKey` per message, each
/// built row registers its own context here and takes it back out when it is
/// dropped. What is registered is only ever what is on or near the screen.
class _RowRegistry {
  final Map<Key, BuildContext> _contexts = {};

  void add(Key key, BuildContext context) => _contexts[key] = context;

  void remove(Key key, BuildContext context) {
    if (identical(_contexts[key], context)) _contexts.remove(key);
  }

  /// How far below the top of [listKey]'s list the row [key] sits, or null
  /// when it is not built or not laid out.
  double? topOf(Key key, GlobalKey listKey) {
    final list = _box(listKey.currentContext);
    final row = _box(_contexts[key]);
    if (list == null || row == null) return null;
    return row.localToGlobal(Offset.zero).dy - list.localToGlobal(Offset.zero).dy;
  }

  /// The highest row that is at least partly on screen.
  ({Key key, double top})? topmostVisible(GlobalKey listKey) {
    final list = _box(listKey.currentContext);
    if (list == null) return null;
    final listTop = list.localToGlobal(Offset.zero).dy;

    ({Key key, double top})? best;
    for (final MapEntry(:key, value: context) in _contexts.entries) {
      final row = _box(context);
      if (row == null) continue;
      final top = row.localToGlobal(Offset.zero).dy - listTop;
      final bottom = top + row.size.height;
      // Off the top, or off the bottom, of the list.
      if (bottom <= 0 || top >= list.size.height) continue;
      if (best == null || top < best.top) best = (key: key, top: top);
    }
    return best;
  }

  static RenderBox? _box(BuildContext? context) {
    if (context == null || !context.mounted) return null;
    final box = context.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }
}

/// One row of the list, registered in a [_RowRegistry] for as long as it is
/// built. Its key is the row's key, which is also what the list uses to follow
/// the row when it moves — see `_MessageList._keyFor`.
class _TrackedRow extends StatefulWidget {
  final _RowRegistry registry;
  final Widget child;

  const _TrackedRow({
    required Key super.key,
    required this.registry,
    required this.child,
  });

  @override
  State<_TrackedRow> createState() => _TrackedRowState();
}

class _TrackedRowState extends State<_TrackedRow> {
  @override
  void initState() {
    super.initState();
    widget.registry.add(widget.key!, context);
  }

  @override
  void dispose() {
    widget.registry.remove(widget.key!, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
