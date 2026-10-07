import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/presentation/reaction_controller.dart';
import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

/// One open conversation: its messages, and everything that changes them.
///
/// The folding rules live in [ConversationState]; this class owns the
/// subscription, the timers and the repository calls. Opening costs an
/// `OpenChat` and a history fetch; later changes come on the update stream.
class ConversationNotifier extends AsyncNotifier<ConversationState> {
  /// Passed to the constructor, since Riverpod 3 gives a family's argument
  /// there and not to `build`.
  final int chatId;

  ConversationNotifier(this.chatId);

  StreamSubscription<td.TdObject>? _sub;
  Timer? _typingExpiry;

  /// Whether the conversation screen is in front of the user. Arrivals are only
  /// marked read while it is, since the notifier can outlive the screen.
  bool _isVisible = false;

  /// Called by the screen as it appears and disappears.
  void setVisible({required bool isVisible}) => _isVisible = isVisible;

  /// Whether TDLib accepted `OpenChat`. Until it does, an unforced read is
  /// silently ignored (see `ReadReceiptQueue`).
  bool _chatConfirmedOpen = false;

  @override
  Future<ConversationState> build() async {
    final repository = ref.watch(chatsRepositoryProvider);

    // Awaited because the answer decides how reads are sent.
    _chatConfirmedOpen = await repository.openChat(chatId);

    _listen();

    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _typingExpiry?.cancel();
      _typingExpiry = null;
      // Otherwise TDLib keeps streaming updates for chats that were left.
      repository.closeChat(chatId);
    });

    // An unread chat loads back to where reading stopped. With nothing unread,
    // the newest page is enough and costs one request.
    final readCursor = repository.lastReadInboxMessageId(chatId);
    final hasBacklog = repository.unreadCount(chatId) > 0 && readCursor != 0;

    final page = hasBacklog
        ? await repository.historyReaching(chatId, messageId: readCursor)
        : await repository.history(chatId);

    return ConversationState(
      chatId: chatId,
      isGroup: repository.isGroupChat(chatId),
      messages: page.messages,
      lastReadOutboxMessageId: repository.lastReadOutboxMessageId(chatId),
      hasMoreOlder: !page.reachedTop,
      firstUnreadMessageId: ConversationState.firstUnreadIn(
        page.messages,
        readCursor,
      ),
    );
  }

  void _listen() {
    _sub?.cancel();
    _sub = ref.read(chatUpdatesProvider).listen((update) {
      final event = ChatEvents.map(update);
      if (event == null || event.chatId != chatId) return;
      _fold(event);
    });
  }

  void _fold(ChatEvent event) {
    final current = state.value;
    if (current == null) return;

    final next = current.apply(
      event,
      users: ref.read(chatCacheProvider).usersById,
      chats: ref.read(chatCacheProvider).chatsById,
    );
    if (next == null) return;
    state = AsyncData(next);

    if (event is ChatActionChanged) _scheduleTypingExpiry(event.action != null);
    if (event is ChatMessageArrived &&
        !event.message.isOutgoing &&
        _isVisible) {
      // The user is looking at the chat, so a new arrival counts as read.
      unawaited(markRead([event.message.id]));
    }
  }

  /// Clears a typing indicator after [ConversationState.typingTimeout], since
  /// TDLib doesn't guarantee a `chatActionCancel`.
  void _scheduleTypingExpiry(bool isActive) {
    _typingExpiry?.cancel();
    _typingExpiry = null;
    if (!isActive) return;

    _typingExpiry = Timer(ConversationState.typingTimeout, () {
      final current = state.value;
      if (current?.typing == null) return;
      state = AsyncData(current!.copyWith(clearTyping: true));
    });
  }

  /// Loads the page above what is on screen. The scroll listener fires every
  /// frame near the top, so concurrent callers share the request in flight.
  Future<void> loadOlder() => _olderInFlight ??= _fetchOlder().whenComplete(
    () => _olderInFlight = null,
  );

  Future<void>? _olderInFlight;

  Future<void> _fetchOlder() async {
    final current = state.value;
    if (current == null || !current.hasMoreOlder) return;

    final cursor = current.oldestMessageId;
    if (cursor == null) return;

    final page = await ref
        .read(chatsRepositoryProvider)
        .history(chatId, fromMessageId: cursor);
    final latest = state.value;
    if (latest == null) return;
    state = AsyncData(
      latest.prepend(page.messages, reachedTop: page.reachedTop),
    );
  }

  /// How many pages [loadOlderUntil] spends looking for one message before
  /// [reveal] loads a window around it instead.
  static const int findPageLimit = 3;

  /// Pages back until [messageId] is loaded. Returns whether it is.
  Future<bool> loadOlderUntil(
    int messageId, {
    int maxPages = findPageLimit,
  }) async {
    bool isLoaded() =>
        state.value?.messages.any((m) => m.messageId == messageId) ?? false;

    for (var page = 0; page < maxPages && !isLoaded(); page++) {
      final current = state.value;
      if (current == null || !current.hasMoreOlder) break;
      // Newer than the oldest loaded and still missing means it is gone.
      final oldest = current.oldestMessageId;
      if (oldest != null && messageId > oldest) break;
      await loadOlder();
    }
    return isLoaded();
  }

  /// Loads [messageId] for a tap on a reply, the pinned bar or a search hit.
  /// Pages back up to [maxPagesBack] pages, then loads a window around it.
  /// Returns false only when Telegram no longer has the message.
  Future<bool> reveal(int messageId, {int maxPagesBack = findPageLimit}) async {
    if (await loadOlderUntil(messageId, maxPages: maxPagesBack)) return true;
    return loadAround(messageId);
  }

  /// Replaces the conversation with the history around [messageId]. Returns
  /// false, leaving the state alone, if the message wasn't in the answer.
  Future<bool> loadAround(int messageId) async {
    final window = await ref
        .read(chatsRepositoryProvider)
        .historyAround(chatId, messageId: messageId);
    if (!window.messages.any((m) => m.messageId == messageId)) return false;

    final current = state.value;
    if (current == null) return false;
    state = AsyncData(
      current.windowed(
        window.messages,
        reachedTop: window.reachedTop,
        reachedBottom: window.reachedBottom,
      ),
    );
    return true;
  }

  /// Loads the page below what is on screen, for a conversation opened in the
  /// middle. Shares the request in flight, like [loadOlder].
  Future<void> loadNewer() => _newerInFlight ??= _fetchNewer().whenComplete(
    () => _newerInFlight = null,
  );

  Future<void>? _newerInFlight;

  Future<void> _fetchNewer() async {
    final current = state.value;
    if (current == null || !current.hasMoreNewer) return;

    final cursor = current.newestMessageId;
    if (cursor == null) return;

    final page = await ref
        .read(chatsRepositoryProvider)
        .historyAfter(chatId, fromMessageId: cursor);
    final latest = state.value;
    if (latest == null || !latest.hasMoreNewer) return;
    state = AsyncData(
      latest.append(page.messages, reachedBottom: page.reachedBottom),
    );
  }

  /// Reloads the newest messages when a window in the middle is loaded. Used
  /// by jump-to-latest and before every send.
  Future<void> returnToLatest() async {
    final current = state.value;
    if (current == null || !current.hasMoreNewer) return;

    final page = await ref.read(chatsRepositoryProvider).history(chatId);
    final latest = state.value;
    if (latest == null) return;
    state = AsyncData(
      latest.copyWith(
        messages: page.messages,
        hasMoreOlder: !page.reachedTop,
        hasMoreNewer: false,
      ),
    );
  }

  /// Sends a message, showing an optimistic bubble in
  /// [MessageSendState.sending] until `updateMessageSendSucceeded` replaces it.
  /// If Telegram refuses it outright, the bubble is removed.
  Future<bool> send({
    required String text,
    List<ComposeAttachment> attachments = const [],
    int? replyToMessageId,
    MessageSchedule schedule = MessageSchedule.now,
  }) async {
    if (text.trim().isEmpty && attachments.isEmpty) return false;
    await returnToLatest();
    final current = state.value;
    if (current == null) return false;

    final repository = ref.read(chatsRepositoryProvider);
    unawaited(repository.setTyping(chatId, isTyping: false));
    unawaited(repository.saveDraft(chatId, ''));

    // No optimistic bubble for a scheduled message: it doesn't appear in the
    // chat until Telegram sends it.
    final placeholder = schedule.isImmediate
        ? _optimisticMessage(text: text, replyTo: replyToMessageId)
        : null;
    if (placeholder != null) {
      state = AsyncData(current.withOptimistic(placeholder));
    }

    final sent = await repository.send(
      chatId: chatId,
      text: text,
      attachments: attachments,
      replyToMessageId: replyToMessageId,
      schedule: schedule,
    );

    final latest = state.value;
    if (latest == null) return sent != null;

    if (sent == null) {
      // Never queued, so remove it instead of marking it failed.
      if (placeholder != null) {
        state = AsyncData(
          latest.copyWith(
            messages: [
              for (final message in latest.messages)
                if (message.messageId != placeholder.messageId) message,
            ],
          ),
        );
      }
      return false;
    }

    if (placeholder == null) return true;

    // Re-key the bubble to TDLib's temporary id now, before
    // `updateMessageSendSucceeded` brings the final one.
    state = AsyncData(
      latest.apply(
            ChatMessageSent(sent, placeholder.messageId),
            users: ref.read(chatCacheProvider).usersById,
            chats: ref.read(chatCacheProvider).chatsById,
          ) ??
          latest,
    );
    return true;
  }

  /// Sends a sticker or GIF from the account's collection. No optimistic
  /// bubble: Telegram returns the queued message in the same round trip.
  Future<bool> sendRemote(
    ComposeRemoteMedia media, {
    int? replyToMessageId,
  }) async {
    await returnToLatest();
    final repository = ref.read(chatsRepositoryProvider);
    unawaited(repository.setTyping(chatId, isTyping: false));
    return _absorb(
      await repository.send(
        chatId: chatId,
        text: '',
        remote: media,
        replyToMessageId: replyToMessageId,
      ),
    );
  }

  /// Sends a poll into this chat. Returns whether Telegram queued it. No
  /// optimistic bubble, since a placeholder would have to invent a poll.
  Future<bool> sendPoll(PollDraft draft, {int? replyToMessageId}) async {
    if (!draft.canSend) return false;

    final repository = ref.read(chatsRepositoryProvider);
    unawaited(repository.setTyping(chatId, isTyping: false));

    return _absorb(
      await repository.sendPoll(
        chatId: chatId,
        draft: draft,
        replyToMessageId: replyToMessageId,
      ),
    );
  }

  /// Votes in a poll, showing the vote straight away. The real counts arrive
  /// on `updateMessageContent`.
  Future<void> vote(int messageId, List<int> optionIds) async {
    final current = state.value;
    if (current == null) return;

    final optimistic = current.withOptimisticVote(messageId, optionIds);
    if (optimistic != null) state = AsyncData(optimistic);

    try {
      await ref
          .read(syncServiceProvider)
          .voteInPoll(
            chatId: chatId,
            messageId: messageId,
            optionIds: optionIds,
          );
    } catch (_) {
      // Put the message's poll back so it can be voted on again; it stayed
      // marked as voted.
      _restorePoll(current, messageId);
      rethrow;
    }
  }

  /// Puts the poll of [messageId] back as it was in [before].
  void _restorePoll(ConversationState before, int messageId) {
    final now = state.value;
    if (now == null) return;
    final old = before.messages.where((m) => m.messageId == messageId);
    final index = now.messages.indexWhere((m) => m.messageId == messageId);
    if (old.isEmpty || index < 0) return;
    final messages = [...now.messages];
    messages[index] = messages[index].copyWith(poll: old.first.poll);
    state = AsyncData(now.copyWith(messages: messages));
  }

  /// Sends this device's location. Returns whether Telegram queued it.
  Future<bool> sendLocation({
    required double latitude,
    required double longitude,
    double accuracy = 0,
    int? replyToMessageId,
  }) async {
    final sent = await ref
        .read(chatsRepositoryProvider)
        .sendLocation(
          chatId: chatId,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          replyToMessageId: replyToMessageId,
        );
    return _absorb(sent);
  }

  /// Shares one of this account's Telegram contacts.
  Future<bool> sendContact({required int userId, int? replyToMessageId}) async {
    final sent = await ref
        .read(chatsRepositoryProvider)
        .sendContact(
          chatId: chatId,
          userId: userId,
          replyToMessageId: replyToMessageId,
        );
    return _absorb(sent);
  }

  /// Folds a just-queued message into the conversation, for sends without an
  /// optimistic bubble, so it shows before `updateNewMessage` arrives.
  bool _absorb(td.Message? sent) {
    if (sent == null) return false;
    final latest = state.value;
    // Sent from the middle of the history: jump to the bottom, whose page
    // includes the new message.
    if (latest != null && latest.hasMoreNewer) {
      unawaited(returnToLatest());
      return true;
    }
    if (latest != null) {
      state = AsyncData(
        latest.apply(
              ChatMessageArrived(sent),
              users: ref.read(chatCacheProvider).usersById,
              chats: ref.read(chatCacheProvider).chatsById,
            ) ??
            latest,
      );
    }
    return true;
  }

  /// Opens self-destructing media, which starts its clock. Irreversible; see
  /// [ChatsRepository.openSecretMedia].
  Future<bool> openSecretMedia(int messageId) => ref
      .read(chatsRepositoryProvider)
      .openSecretMedia(chatId: chatId, messageId: messageId);

  /// A bubble for a message that has not left the device yet. Its negative id
  /// can't collide with TDLib's positive ids, and
  /// [ConversationState.compareOrder] sorts it to the bottom.
  ChatMessage _optimisticMessage({required String text, int? replyTo}) {
    final current = state.value;
    final replyTarget = replyTo == null
        ? null
        : current?.messages.cast<ChatMessage?>().firstWhere(
            (m) => m?.messageId == replyTo,
            orElse: () => null,
          );

    final id = _nextOptimisticId();
    return ChatMessage(
      id: '${chatId}_$id',
      chatId: chatId,
      messageId: id,
      isOutgoing: true,
      text: text.isEmpty ? null : text,
      sentAt: DateTime.now(),
      sendState: MessageSendState.sending,
      replyToMessageId: replyTo,
      replyToText: replyTarget == null
          ? null
          : ChatMessageMapper.replyPreviewOf(replyTarget),
      replyToAuthorName: replyTarget == null
          ? null
          : ChatMessageMapper.replyAuthorOf(replyTarget),
    );
  }

  /// One below the lowest optimistic id loaded, so pending messages keep the
  /// order they were sent in.
  int _nextOptimisticId() {
    final current = state.value;
    final lowest = current?.messages
        .map((m) => m.messageId)
        .where((id) => id < 0)
        .fold<int>(0, (a, b) => a < b ? a : b);
    return (lowest ?? 0) - 1;
  }

  /// Marks messages as read. Read state syncs to all the account's devices,
  /// so only call this for something the user saw, never from `build()`.
  Future<void> markRead(List<int> messageIds) async {
    if (messageIds.isEmpty) return;
    final error = await ref
        .read(chatsRepositoryProvider)
        .markRead(
          chatId: chatId,
          messageIds: messageIds,
          // TDLib ignores an unforced read in a chat it doesn't consider open.
          forceRead: !_chatConfirmedOpen,
        );
    if (error != null) debugPrint('[Conversation] read ack failed: $error');
  }

  /// Marks the unread backlog read. The screen calls it once, after the first
  /// page is shown: opening a chat counts as reading it.
  Future<void> markVisibleRead() async {
    final current = state.value;
    if (current == null || !_isVisible) return;
    final repository = ref.read(chatsRepositoryProvider);
    await markRead(
      current.unreadIncomingIds(repository.lastReadInboxMessageId(chatId)),
    );
  }

  /// Adds or removes one of this account's reactions, optimistically.
  /// Reacts to a message, or takes the reaction back. Shown at once, and put
  /// back if Telegram refuses: a refused reaction used to stay on screen.
  /// Returns false if it wasn't sent.
  Future<bool> toggleReaction(int messageId, String emoji) async {
    // Paid and custom emoji reactions can't be sent as emoji.
    if (!isSendableReaction(emoji)) return false;
    final current = state.value;
    if (current == null) return false;

    final index = current.messages.indexWhere((m) => m.messageId == messageId);
    if (index < 0) return false;

    final message = current.messages[index];
    final isChosen = message.chosenReactions.contains(emoji);

    final counts = <String, int>{...message.reactions};
    final chosen = <String>{...message.chosenReactions};
    if (isChosen) {
      chosen.remove(emoji);
      final next = (counts[emoji] ?? 1) - 1;
      if (next <= 0) {
        counts.remove(emoji);
      } else {
        counts[emoji] = next;
      }
    } else {
      chosen.add(emoji);
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    final messages = [...current.messages];
    messages[index] = message.copyWith(
      reactions: counts,
      chosenReactions: chosen,
    );
    state = AsyncData(current.copyWith(messages: messages));

    final sent = await ref
        .read(chatsRepositoryProvider)
        .toggleReaction(
          chatId: chatId,
          messageId: messageId,
          emoji: emoji,
          isChosen: isChosen,
        );
    if (!sent) _restoreReactions(message);
    return sent;
  }

  /// Puts [before]'s reactions back on its message, if it's still there.
  void _restoreReactions(ChatMessage before) {
    final current = state.value;
    if (current == null) return;
    final index = current.messages.indexWhere(
      (m) => m.messageId == before.messageId,
    );
    if (index < 0) return;
    final messages = [...current.messages];
    messages[index] = messages[index].copyWith(
      reactions: before.reactions,
      chosenReactions: before.chosenReactions,
    );
    state = AsyncData(current.copyWith(messages: messages));
  }

  /// Deletes messages. Irreversible, so the screen confirms before calling.
  Future<bool> delete(List<int> messageIds, {required bool revoke}) async {
    final ok = await ref
        .read(chatsRepositoryProvider)
        .deleteMessages(chatId: chatId, messageIds: messageIds, revoke: revoke);
    // Not optimistic, in case Telegram refuses. `updateDeleteMessages` removes
    // the bubbles.
    return ok;
  }

  /// Sends a failed message again. Telegram doesn't retry by itself.
  Future<bool> resend(int messageId) =>
      ref.read(chatsRepositoryProvider).resend(chatId, [messageId]);

  /// Edits a message's text, or a media message's caption.
  Future<bool> edit(int messageId, String text) async {
    final message = state.value?.messages
        .where((m) => m.messageId == messageId)
        .firstOrNull;
    final isCaption = message?.media.isNotEmpty ?? false;
    // A caption may be emptied; a text message may not.
    if (!isCaption && text.trim().isEmpty) return false;
    return ref
        .read(chatsRepositoryProvider)
        .editText(
          chatId: chatId,
          messageId: messageId,
          text: text,
          isCaption: isCaption,
        );
  }

  /// Reloads from scratch, for the error state's retry.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

/// Must stay `isAutoDispose: true` (Riverpod 3 families default to false).
/// A conversation that outlives its screen keeps marking arrivals read.
final conversationProvider =
    AsyncNotifierProvider.family<ConversationNotifier, ConversationState, int>(
      ConversationNotifier.new,
      isAutoDispose: true,
    );

/// Tells the other side this account is typing, at most once per [interval].
/// Telegram treats a chat action as valid for about six seconds.
class TypingSignal {
  /// The floor between two `SendChatAction` calls.
  static const Duration interval = Duration(seconds: 4);

  final ChatsRepository _repository;
  final int chatId;
  DateTime? _lastSent;

  TypingSignal(this._repository, this.chatId);

  /// Call on every change to the composer.
  void onTyping() {
    final now = DateTime.now();
    final last = _lastSent;
    if (last != null && now.difference(last) < interval) return;
    _lastSent = now;
    unawaited(_repository.setTyping(chatId, isTyping: true));
  }

  /// Call when the field empties or the screen closes.
  void stop() {
    if (_lastSent == null) return;
    _lastSent = null;
    unawaited(_repository.setTyping(chatId, isTyping: false));
  }
}

final typingSignalProvider = Provider.family<TypingSignal, int>((ref, chatId) {
  final signal = TypingSignal(ref.watch(chatsRepositoryProvider), chatId);
  ref.onDispose(signal.stop);
  return signal;
});

/// What this account may do with one message. Fetched only when watched, on
/// long-press.
final messageActionsProvider =
    FutureProvider.family<MessageActions, MessageRef>(
      (ref, target) => ref
          .watch(chatsRepositoryProvider)
          .messageActions(chatId: target.chatId, messageId: target.messageId),
    );

/// Addresses one message. A value type, so the family caches per message.
@immutable
class MessageRef {
  final int chatId;
  final int messageId;
  const MessageRef(this.chatId, this.messageId);

  @override
  bool operator ==(Object other) =>
      other is MessageRef &&
      other.chatId == chatId &&
      other.messageId == messageId;

  @override
  int get hashCode => Object.hash(chatId, messageId);
}

/// The emoji offered for one message in the reaction picker. Fetched only
/// when watched, like [messageActionsProvider].
final chatReactionsProvider = FutureProvider.family<List<String>, MessageRef>(
  (ref, target) => ref
      .watch(chatsRepositoryProvider)
      .messageReactions(chatId: target.chatId, messageId: target.messageId),
);
