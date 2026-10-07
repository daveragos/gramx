import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/navigation/mention_navigation.dart';
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
import 'package:gramx/features/chats/presentation/widgets/premium_mark.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
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

/// One open conversation. Uses a plain `Scaffold` with a fixed `AppBar`
/// rather than `ChromeScaffold`, so the header never scrolls away.
class ConversationScreen extends ConsumerStatefulWidget {
  final int chatId;

  /// A message to open the chat at, as from a link to it.
  final int? initialMessageId;

  const ConversationScreen({
    super.key,
    required this.chatId,
    this.initialMessageId,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  /// How close to the loaded edge the scroll gets before the next page is
  /// requested.
  static const double _loadOlderThreshold = 400;

  /// How far off the bottom counts as "not at the bottom", which shows the
  /// jump-to-latest button.
  static const double _atBottomSlack = 200;

  final ScrollController _scroll = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  /// Attached to the unread band, so the first frame can bring it into view.
  final GlobalKey _unreadBandKey = GlobalKey();

  /// Attached to whichever message a reply is currently jumping to. There is
  /// only one target at a time, so one key is enough.
  final GlobalKey _jumpKey = GlobalKey();

  /// The message a tapped reply points at, flashed while it is found.
  int? _jumpTargetId;

  ChatMessage? _replyTo;

  /// The selected messages, in selection order. Null when selection mode is
  /// off; an empty set (after unticking the last one) keeps the selection bar.
  Set<int>? _selected;

  /// What may be done with each selected message, fetched once per tick with
  /// `getMessageProperties`.
  final Map<int, MessageActions> _selectionRights = {};

  bool _showJumpButton = false;
  bool _hasMarkedRead = false;

  /// Where each built row is, so one can be held still while others change.
  final _RowRegistry _rows = _RowRegistry();

  /// The list itself, which rows are measured against.
  final GlobalKey _listKey = GlobalKey();

  /// The rows on screen and their offsets from the top of the list, highest
  /// first, taken just before the conversation changed. See [_holdPosition].
  List<({Key key, double top})>? _heldRows;

  /// Above zero while the screen scrolls the list itself (to the unread band
  /// or a reply), so [_holdPosition] stays out of the way.
  int _walking = 0;

  /// Read in `initState` because the composer saves its draft from its own
  /// `dispose()`, when `ref` can no longer be used.
  late final ChatsRepository _repository;
  bool _hasAnchoredToUnread = false;
  bool _hasCheckedViewport = false;

  /// Whether the chat has gone to [ConversationScreen.initialMessageId].
  bool _openedAtInitial = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(chatsRepositoryProvider);
    _scroll.addListener(_onScroll);
    // Runs before the list rebuilds, so it measures the current layout.
    ref.listenManual(
      conversationProvider(widget.chatId),
      (previous, _) =>
          _holdPosition(wasWindowed: previous?.value?.hasMoreNewer ?? false),
    );
    // The notifier marks nothing read until the screen is showing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(conversationProvider(widget.chatId).notifier)
          .setVisible(isVisible: true);
    });
    // Opened from a link to one message: go to it once the chat has loaded.
    final initial = widget.initialMessageId;
    if (initial != null) {
      ref.listenManual(conversationProvider(widget.chatId), (_, next) {
        if (_openedAtInitial || next.value == null) return;
        _openedAtInitial = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _jumpToMessage(initial);
        });
      }, fireImmediately: true);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// The list is reversed: offset 0 is the newest message.
  void _onScroll() {
    if (!_scroll.hasClients) return;

    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels < _loadOlderThreshold) {
      _loadOlder();
    }
    // After a jump into the middle, the bottom edge is a page boundary too.
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

  /// Loads the page above, and keeps loading while the list is too short to
  /// scroll (TDLib can return very short pages).
  Future<void> _loadOlder() async {
    final notifier = ref.read(conversationProvider(widget.chatId).notifier);
    await notifier.loadOlder();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final state = ref.read(conversationProvider(widget.chatId)).value;
      if (state == null || !state.hasMoreOlder) return;
      if (_scroll.position.maxScrollExtent <= 0) _loadOlder();
    });
  }

  /// Goes to the newest message, loading it first if a window in the middle
  /// of the history is loaded.
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

  /// How many viewport steps the anchor takes looking for the unread band
  /// before giving up. Sized to cover [ChatsRepository.backlogMaxMessages].
  static const int _anchorSteps = 40;

  /// Brings the unread band to the top of the viewport, once. Steps up a
  /// viewport at a time until `ListView.builder` has built the band, then
  /// lets `ensureVisible` land it.
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

    // No band when the first unread message is older than what was loaded.
    final rows = ConversationRows.build(
      state.messages,
      firstUnreadMessageId: state.firstUnreadMessageId,
    );
    if (ConversationRows.unreadRowFromNewest(rows) == null) return;

    for (var step = 0; step < _anchorSteps; step++) {
      if (!mounted || !_scroll.hasClients) return;

      final bandContext = _unreadBandKey.currentContext;
      // Check the band's own context: it may have been rebuilt during the walk.
      if (bandContext != null && bandContext.mounted) {
        await Scrollable.ensureVisible(
          bandContext,
          // In a reversed list, 1.0 puts the band at the top of the viewport.
          alignment: 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      final position = _scroll.position;
      final target = position.pixels + position.viewportDimension * 0.8;
      // Already at the oldest loaded row.
      if (position.pixels >= position.maxScrollExtent) return;

      _scroll.jumpTo(target.clamp(0.0, position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// Keeps the topmost visible row in place while the conversation changes,
  /// since in a reversed list a growing row pushes everything above it up.
  /// Skipped at the bottom, where new messages should move the list, unless
  /// [wasWindowed] (the bottom edge was then only a page boundary).
  void _holdPosition({bool wasWindowed = false}) {
    if (_heldRows != null || _walking > 0 || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!wasWindowed && position.pixels <= _atBottomSlack) return;
    // Don't fight a drag or fling in progress.
    if (position.isScrollingNotifier.value) return;

    final held = _rows.visibleRows(_listKey);
    if (held.isEmpty) return;
    _heldRows = held;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  void _restorePosition() {
    final held = _heldRows;
    _heldRows = null;
    if (held == null || !mounted || !_scroll.hasClients) return;

    // The highest row still built. A tall arrival can push the top rows out
    // of the list's cache, and then a lower one measures the same shift.
    for (final row in held) {
      final top = _rows.topOf(row.key, _listKey);
      if (top == null) continue;
      // Reversed list: adding pixels moves the content down.
      final drift = row.top - top;
      if (drift.abs() < 0.5) return;

      final position = _scroll.position;
      _scroll.jumpTo(
        (position.pixels + drift).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      return;
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

  /// Calls [_loadOlder] once if the first page is too short to scroll.
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
      // A scheduled message doesn't appear in the chat, so confirm it instead.
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

  /// Asks when a message should go, and rejects a time Telegram would refuse.
  Future<MessageSchedule?> _pickSchedule() async {
    final schedule = await ScheduleSheet.show(
      context,
      // "When online" only makes sense in a private chat.
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

  /// Opens a location or venue in the device's maps app via a `geo:` URI.
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

  /// Gets the device's location and sends it. [LocationService] asks for the
  /// permission at this point.
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
      // True so the composer doesn't show a second error.
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
    // Backing out of the picker is not a failure.
    if (userId == null || !mounted) return true;

    final sent = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .sendContact(userId: userId, replyToMessageId: _replyTo?.messageId);
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

  /// Opens self-destructing media after a confirmation, since opening is
  /// irreversible and tells the sender.
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

  /// A plain tap on a bubble: toggles selection while selecting, and resends
  /// a failed message.
  Future<void> _handleTap(ChatMessage message) async {
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
  Future<void> _jumpToReply(ChatMessage message) async {
    final targetId = message.replyToMessageId;
    // A cross-chat reply points somewhere this screen can't scroll to.
    if (targetId == null || message.replyToChatId != null) return;

    await _jumpToMessage(targetId);
  }

  /// Loads, scrolls to and flashes one message. Jumps to an estimate from the
  /// average row height, steps until `ListView.builder` has built the target,
  /// then lets `ensureVisible` land it.
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
          content: Text(AppStrings.chatMessageUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Let the new page lay out before measuring.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    HapticFeedback.lightImpact();
    setState(() => _jumpTargetId = targetId);

    // Reversed list, so measure from the newest message.
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
        (position.pixels + position.viewportDimension * 0.8).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
    }

    // Brief, so the tint isn't mistaken for selection.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _jumpTargetId = null);
  }

  /// Jumps to the pinned message.
  Future<void> _jumpToPinned() async {
    final pinned = ref.read(pinnedMessageProvider(widget.chatId)).value;
    if (pinned == null) return;
    await _jumpToMessage(pinned.messageId);
  }

  /// Closes the search field and goes to the result. Pages back at most once
  /// before loading a window around it, since hits are usually far back.
  Future<void> _openSearchResult(ChatMessage message) async {
    final found = await ref
        .read(conversationProvider(widget.chatId).notifier)
        .reveal(message.messageId, maxPagesBack: 1);
    if (!mounted) return;

    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.chatMessageUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ref.read(inChatSearchQueryProvider.notifier).close();
    await _jumpToMessage(message.messageId);
  }

  /// Opens whoever an `@name` is: a person's profile, a channel or a group.
  Future<void> _openMention(String username) => openMention(context, username);

  // ── Selecting several messages ────────────────────────────────────────────

  /// Telegram's own cap on a bulk delete or forward.
  static const int _maxSelected = 100;

  bool get _isSelecting => _selected != null;

  /// Whether every selected message can be deleted for everyone.
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

    // Fetched once per message and kept.
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

    // Oldest first, not in tap order.
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

  /// Ends an end-to-end chat after confirming. Irreversible, and Telegram
  /// deletes the messages on both devices.
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

  /// Sets the chat's auto-delete timer, from the header's overflow menu.
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

  /// Leaves this group or deletes this chat, then closes the screen.
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
    // While selecting, a long press toggles selection like a tap.
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
                  ref
                      .read(chatsRepositoryProvider)
                      .canSetAutoDelete(widget.chatId)
                  ? _setAutoDelete
                  : null,
              // Only offered when there are scheduled messages.
              onScheduled:
                  ref
                      .read(chatsRepositoryProvider)
                      .hasScheduledMessages(widget.chatId)
                  ? () => ScheduledMessagesScreen.show(context, widget.chatId)
                  : null,
              onCloseSecretChat:
                  ref.read(chatsRepositoryProvider).isSecretChat(widget.chatId)
                  ? _closeSecretChat
                  : null,
              // Saved Messages can't be left or blocked.
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
          // Above the list, not overlaid, so it never covers a message.
          if (searchQuery == null)
            _PinnedBar(chatId: widget.chatId, onTap: _jumpToPinned),
          // A chat started by a non-contact: offer to block or dismiss.
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
                  // Over the list only, so the button can't cover the composer.
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
          // Telegram refuses sends until a secret chat's key exchange is done.
          if (ref
              .read(chatsRepositoryProvider)
              .isSecretChatPending(widget.chatId))
            const _SecretChatPendingNotice()
          else
            MessageComposer(
              // The draft is TDLib's, so it syncs across devices.
              initialText: ref
                  .read(chatsRepositoryProvider)
                  .draftText(widget.chatId),
              onDraftChanged: (text) =>
                  _repository.saveDraft(widget.chatId, text),
              replyTo: _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
              onSend: _send,
              // Controls Telegram would refuse in this chat are hidden.
              onSendPoll:
                  ref
                      .read(chatsRepositoryProvider)
                      .canSendPollsIn(widget.chatId)
                  ? _sendPoll
                  : null,
              allowsSelfDestruct: ref
                  .read(chatsRepositoryProvider)
                  .isPrivateChat(widget.chatId),
              // Telegram grants media rights per kind.
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
              // Stickers and GIFs share one permission.
              onSendRemote:
                  ref
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

/// Shown in place of the composer while a secret chat is pending.
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

/// Replaces the header while messages are selected.
class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int count;

  /// Whether every selected message can be forwarded. False hides the button.
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
        // Hidden, not greyed, when nothing is selected.
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

/// Replaces the header while the chat is being searched.
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

/// Results for the in-chat search.
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

    // An empty query shows a prompt, not "no results".
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

/// The pinned message, above the conversation. Hidden when there is no pin
/// and while the lookup is in flight.
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
          border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Accent rule, matching the quoted-reply style.
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

  /// Opens the search field. Null hides the control.
  final VoidCallback? onSearch;

  /// Opens the auto-delete timer. Null where Telegram doesn't allow one.
  final VoidCallback? onAutoDelete;

  /// Opens the scheduled messages. Null when there are none.
  final VoidCallback? onScheduled;

  /// Ends an end-to-end chat. Null for any other chat.
  final VoidCallback? onCloseSecretChat;

  /// Leaves the group or deletes the chat. Null where there is neither.
  final VoidCallback? onRemove;

  /// Whether [onRemove] leaves a group rather than deleting a chat.
  final bool isGroup;

  /// Blocks or unblocks the person. Null in a group.
  final VoidCallback? onToggleBlock;

  /// Read when the menu opens, since blocking doesn't rebuild this screen.
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

  /// The overflow sheet, with a row for each non-null action. The sheet closes
  /// before a row's callback runs.
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
            icon: isGroup ? Icons.logout_rounded : Icons.delete_outline_rounded,
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

    // Typing replaces the presence line.
    final subtitle = typing != null
        ? AppStrings.chatTyping(typing!.action, name: typing!.name)
        : _presenceLabel(summary);
    final isLive = typing != null || summary?.presence == ChatPresence.online;

    // Only people and bots have a profile to open.
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
                      // The lock tells a secret chat apart from the ordinary
                      // one with the same person.
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
                      if (summary case final person?
                          when PremiumMark.shows(
                            isPremium: person.isPremium,
                            isVerified: person.isVerified,
                            emojiStatusId: person.emojiStatusId,
                          )) ...[
                        const SizedBox(width: AppSpacing.xs),
                        PremiumMark(
                          emojiStatusId: person.emojiStatusId,
                          isVerified: person.isVerified,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      // Live states (typing, online) use the accent colour.
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

  /// The presence line, or null for groups, bots and hidden last-seen.
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

/// Makes its child tappable, or leaves it as is. A `GestureDetector` with a
/// null `onTap` still joins the gesture arena, so none is added in that case.
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

/// The scrollback, reversed so it stays anchored to the newest message.
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

  /// A stable key per row, so a bubble's state (such as a playing voice
  /// message) stays with its message when arrivals shift the indexes.
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

    // A spinner at the bottom too when opened in the middle.
    final newerRows = state.hasMoreNewer ? 1 : 0;

    return ListView.builder(
      key: listKey,
      controller: controller,
      reverse: true,
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
        // Reversed, so the loading row for older messages is the last item.
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

/// The contexts of the rows currently built, by key, so their positions can
/// be measured without a `GlobalKey` per message.
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
    return row.localToGlobal(Offset.zero).dy -
        list.localToGlobal(Offset.zero).dy;
  }

  /// The rows at least partly on screen, highest first.
  List<({Key key, double top})> visibleRows(GlobalKey listKey) {
    final list = _box(listKey.currentContext);
    if (list == null) return const [];
    final listTop = list.localToGlobal(Offset.zero).dy;

    final rows = <({Key key, double top})>[];
    for (final MapEntry(:key, value: context) in _contexts.entries) {
      final row = _box(context);
      if (row == null) continue;
      final top = row.localToGlobal(Offset.zero).dy - listTop;
      final bottom = top + row.size.height;
      if (bottom <= 0 || top >= list.size.height) continue;
      rows.add((key: key, top: top));
    }
    rows.sort((a, b) => a.top.compareTo(b.top));
    return rows;
  }

  static RenderBox? _box(BuildContext? context) {
    if (context == null || !context.mounted) return null;
    final box = context.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }
}

/// One row of the list, registered in a [_RowRegistry] while it is built.
/// Keyed by `_MessageList._keyFor`.
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
