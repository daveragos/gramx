import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/chats/domain/message_schedule.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

/// One open conversation: its messages, and everything that changes them.
///
/// The division of labour is deliberate. All the *rules* — what an arriving
/// message does to the list, how a temporary id is swapped for a real one, when
/// a tick turns from sent to read — live in [ConversationState], which is pure
/// and tested. This class owns only the things a pure object cannot: the
/// subscription, the timers, and the calls to the repository.
///
/// **Request budget.** Opening a conversation is one `OpenChat` and one
/// `GetChatHistory`. Paging back is one more, on demand. Nothing here loops over
/// chats, and nothing here polls — every subsequent change arrives on the update
/// stream, which is free. See `docs/TDLIB.md`.
class ConversationNotifier extends AsyncNotifier<ConversationState> {
  /// The chat this conversation is of.
  ///
  /// Held on the notifier rather than read from a build argument: Riverpod 3
  /// hands a family's argument to the *constructor*, and `build` takes none.
  final int chatId;

  ConversationNotifier(this.chatId);

  StreamSubscription<td.TdObject>? _sub;
  Timer? _typingExpiry;
  bool _loadingOlder = false;

  /// Whether the screen showing this conversation is in front of the reader.
  ///
  /// The auto-dispose above is the real fix for reading messages in chats
  /// nobody opened; this is the second lock on the same door. A notifier can
  /// legitimately outlive its screen for a moment — a pending dispose, a route
  /// pushed on top — and "a message arrived" must never mean "the reader saw
  /// it" during that window. Defaults to false: nothing is acknowledged until a
  /// screen says it is showing.
  bool _isVisible = false;

  /// Called by the screen as it appears and disappears.
  void setVisible({required bool isVisible}) => _isVisible = isVisible;

  /// Whether TDLib has acknowledged `OpenChat` for this chat.
  ///
  /// Confirmed, not merely requested. A read acknowledgement sent with
  /// `forceRead: false` against a chat TDLib does not yet consider open is
  /// declined and still answers `Ok`, so nothing retries it — the same trap
  /// `ReadReceiptQueue` documents.
  bool _chatConfirmedOpen = false;

  @override
  Future<ConversationState> build() async {
    final repository = ref.watch(chatsRepositoryProvider);

    // Telling TDLib the chat is open is what makes read acknowledgements and
    // interaction info work at all, and it is awaited rather than dispatched
    // because the answer decides how reads are sent.
    _chatConfirmedOpen = await repository.openChat(chatId);

    _listen();

    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _typingExpiry?.cancel();
      _typingExpiry = null;
      // Telegram expects roughly one chat open at a time. Leaving them open is
      // how a reader ends up with interaction info streaming for a dozen chats
      // they have walked away from.
      repository.closeChat(chatId);
    });

    // An unread chat opens where reading stopped, not at the bottom. A group
    // left for a day is a hundred messages the reader has not seen, and landing
    // them on the newest one means scrolling *up* through a conversation to
    // read it forwards — which is backwards.
    //
    // Only when there is something to come back to: with nothing unread the
    // newest page is the right answer and costs one request instead of a
    // window plus a jump.
    final readCursor = repository.lastReadInboxMessageId(chatId);
    final hasBacklog = repository.unreadCount(chatId) > 0 && readCursor != 0;

    final page = hasBacklog
        ? await repository.historyAround(chatId, messageId: readCursor)
        : await repository.history(chatId);

    return ConversationState(
      chatId: chatId,
      isGroup: repository.isGroupChat(chatId),
      messages: page.messages,
      lastReadOutboxMessageId: repository.lastReadOutboxMessageId(chatId),
      hasMoreOlder: !page.reachedTop,
      // Captured here and never recomputed — see the field's own note.
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
    );
    if (next == null) return;
    state = AsyncData(next);

    if (event is ChatActionChanged) _scheduleTypingExpiry(event.action != null);
    if (event is ChatMessageArrived &&
        !event.message.isOutgoing &&
        _isVisible) {
      // Something arrived while the reader is looking at the chat. That is the
      // one case where marking read on arrival is honest rather than a guess
      // about the viewport — they are here, with it open, watching it land.
      // Off screen it is a guess, and the wrong one.
      unawaited(markRead([event.message.id]));
    }
  }

  /// Clears a typing indicator that nobody cancelled.
  ///
  /// TDLib does not promise a `chatActionCancel` — somebody who types a word
  /// and closes their app never sends one — so an indicator waiting for it
  /// stays up forever.
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

  /// Loads the page above what is on screen.
  ///
  /// Guarded against re-entry: a fast scroll fires the "near the top" callback
  /// on consecutive frames, and without the guard that is one request per
  /// frame — the per-keystroke mistake in a different costume.
  Future<void> loadOlder() async {
    final current = state.value;
    if (current == null || !current.hasMoreOlder || _loadingOlder) return;

    final cursor = current.oldestMessageId;
    if (cursor == null) return;

    _loadingOlder = true;
    try {
      final page = await ref
          .read(chatsRepositoryProvider)
          .history(chatId, fromMessageId: cursor);
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.prepend(page.messages, reachedTop: page.reachedTop),
      );
    } finally {
      _loadingOlder = false;
    }
  }

  /// Sends a message, showing it before Telegram has answered.
  ///
  /// Optimistic first, network second — the rule in `docs/UI.md`. The bubble
  /// appears under the sender's thumb carrying [MessageSendState.sending], and
  /// `updateMessageSendSucceeded` swaps in the real one with its real id. If
  /// Telegram refuses it outright the optimistic bubble is dropped, because a
  /// message that was never queued has no send state to fail from.
  Future<bool> send({
    required String text,
    List<ComposeAttachment> attachments = const [],
    int? replyToMessageId,
    MessageSchedule schedule = MessageSchedule.now,
  }) async {
    final current = state.value;
    if (current == null) return false;
    if (text.trim().isEmpty && attachments.isEmpty) return false;

    final repository = ref.read(chatsRepositoryProvider);
    // Typing stops the moment the message goes, or the other side is left
    // watching an ellipsis for the message they can already see.
    unawaited(repository.setTyping(chatId, isTyping: false));
    unawaited(repository.saveDraft(chatId, ''));

    // No optimistic bubble for a scheduled message. It is not going into this
    // conversation — Telegram holds the queue apart until it sends — so a
    // bubble here would be a message the reader can see and the recipient
    // cannot, sitting at the bottom of the chat until a refresh removed it.
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
      // Never queued. Removing it is more honest than a failed bubble, which
      // would imply Telegram has it and could not deliver it.
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

    // A scheduled message has nothing on screen to reconcile: it was never
    // drawn, and it will arrive as an ordinary new message whenever it goes.
    if (placeholder == null) return true;

    // TDLib gave the queued message its own temporary id. Swapping now means
    // the bubble is keyed correctly before `updateMessageSendSucceeded` lands
    // with the final one.
    state = AsyncData(
      latest.apply(
            ChatMessageSent(sent, placeholder.messageId),
            users: ref.read(chatCacheProvider).usersById,
          ) ??
          latest,
    );
    return true;
  }

  /// Sends a poll into this chat. Returns whether Telegram queued it.
  ///
  /// No optimistic bubble, unlike [send]. A poll placeholder would have to
  /// invent vote counts and a poll id, and the real message lands on
  /// `updateNewMessage` within the same beat — an empty poll that flickers into
  /// a real one is worse than a poll that simply appears.
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

  /// Answers a poll in this chat, optimistically.
  ///
  /// The same two-step every other write here uses: show it, then send it. The
  /// authoritative counts arrive on `updateMessageContent` and replace what the
  /// optimism guessed, so nothing here has to be undone if the guess was off.
  Future<void> vote(int messageId, List<int> optionIds) async {
    final current = state.value;
    if (current == null) return;

    final optimistic = current.withOptimisticVote(messageId, optionIds);
    if (optimistic != null) state = AsyncData(optimistic);

    await ref
        .read(syncServiceProvider)
        .voteInPoll(
          chatId: chatId,
          messageId: messageId,
          optionIds: optionIds,
        );
  }

  /// Sends where this device is. Returns whether Telegram queued it.
  ///
  /// No optimistic bubble, for the same reason [sendPoll] has none: a
  /// placeholder would have to invent a map preview, and the real message lands
  /// on `updateNewMessage` within the same beat.
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
  Future<bool> sendContact({
    required int userId,
    int? replyToMessageId,
  }) async {
    final sent = await ref
        .read(chatsRepositoryProvider)
        .sendContact(
          chatId: chatId,
          userId: userId,
          replyToMessageId: replyToMessageId,
        );
    return _absorb(sent);
  }

  /// Folds a just-queued message into the conversation.
  ///
  /// The shared tail of every send that has no optimistic bubble: the message
  /// TDLib answers with is real, and putting it in now means the bubble is on
  /// screen before `updateNewMessage` arrives with the same one.
  bool _absorb(td.Message? sent) {
    if (sent == null) return false;
    final latest = state.value;
    if (latest != null) {
      state = AsyncData(
        latest.apply(
              ChatMessageArrived(sent),
              users: ref.read(chatCacheProvider).usersById,
            ) ??
            latest,
      );
    }
    return true;
  }

  /// Opens self-destructing media, which starts its clock.
  ///
  /// Irreversible, and never called on the reader's behalf — see
  /// [ChatsRepository.openSecretMedia]. The screen confirms first and this only
  /// carries out the answer.
  Future<bool> openSecretMedia(int messageId) => ref
      .read(chatsRepositoryProvider)
      .openSecretMedia(chatId: chatId, messageId: messageId);

  /// A bubble for a message that has not left the device yet.
  ///
  /// The id is a large negative number so it can never collide with a TDLib
  /// message id (which are positive and shifted left by 20) and always sorts to
  /// the bottom of the list, where a message being sent belongs. It is replaced
  /// the moment TDLib answers.
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
      replyToText: replyTarget?.text,
      replyToAuthorName: replyTarget?.senderName,
    );
  }

  /// Ascending within a session, so two messages sent in the same second keep
  /// the order they were typed in.
  int _nextOptimisticId() {
    final current = state.value;
    final lowest = current?.messages
        .map((m) => m.messageId)
        .where((id) => id < 0)
        .fold<int>(0, (a, b) => a < b ? a : b);
    return (lowest ?? 0) - 1;
  }

  /// Acknowledges messages as read.
  ///
  /// Read state is pushed to every client this account owns, so this is only
  /// ever called from something the reader actually did — opening the chat,
  /// or watching a message arrive into it. Never from `build()`.
  Future<void> markRead(List<int> messageIds) async {
    if (messageIds.isEmpty) return;
    final error = await ref
        .read(chatsRepositoryProvider)
        .markRead(
          chatId: chatId,
          messageIds: messageIds,
          // Unconfirmed means force: for a chat TDLib does not consider open
          // an unforced ack is silently declined, and the reader really did
          // read it.
          forceRead: !_chatConfirmedOpen,
        );
    if (error != null) debugPrint('[Conversation] read ack failed: $error');
  }

  /// Acknowledges the backlog the reader arrived into.
  ///
  /// Called by the screen once, after the first page is on screen — not from
  /// `build()`, and not per visible bubble. Opening a conversation *is* reading
  /// it, which is the one place this app's dwell rules do not apply: the feed
  /// is a list somebody scrolls past, a chat is a thing somebody opened.
  Future<void> markVisibleRead() async {
    final current = state.value;
    if (current == null || !_isVisible) return;
    final repository = ref.read(chatsRepositoryProvider);
    await markRead(
      current.unreadIncomingIds(repository.lastReadInboxMessageId(chatId)),
    );
  }

  /// Adds or removes one of this account's reactions, optimistically.
  Future<void> toggleReaction(int messageId, String emoji) async {
    final current = state.value;
    if (current == null) return;

    final index = current.messages.indexWhere((m) => m.messageId == messageId);
    if (index < 0) return;

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

    await ref
        .read(chatsRepositoryProvider)
        .toggleReaction(
          chatId: chatId,
          messageId: messageId,
          emoji: emoji,
          isChosen: isChosen,
        );
  }

  /// Deletes messages. Irreversible, so the screen confirms before calling.
  Future<bool> delete(List<int> messageIds, {required bool revoke}) async {
    final ok = await ref
        .read(chatsRepositoryProvider)
        .deleteMessages(chatId: chatId, messageIds: messageIds, revoke: revoke);
    // Not applied optimistically. A delete Telegram refuses would take the
    // message off screen and leave it in the chat on every other device, which
    // is worse than a beat of delay — `updateDeleteMessages` removes it.
    return ok;
  }

  /// Sends a refused message again.
  ///
  /// Telegram does not retry by itself, so without this a failed message sits
  /// in the chat with a warning on it and nothing the reader can do about it —
  /// a dead end in the one place the app writes on their behalf. TDLib keeps
  /// the content, so this needs the id and nothing else.
  Future<bool> resend(int messageId) =>
      ref.read(chatsRepositoryProvider).resend(chatId, [messageId]);

  /// Rewrites a message this account sent.
  Future<bool> edit(int messageId, String text) async {
    if (text.trim().isEmpty) return false;
    return ref
        .read(chatsRepositoryProvider)
        .editText(chatId: chatId, messageId: messageId, text: text);
  }

  /// Reloads from scratch, for the error state's retry.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

/// **`isAutoDispose` is set explicitly, and that is load-bearing.**
///
/// Riverpod 3's family constructors default to `isAutoDispose: false` — unlike
/// the codegen form, and unlike what this repo's docs used to claim. Left on
/// the default, a conversation opened once lived for the rest of the session
/// with its update subscription still attached, so **every** message arriving
/// in **every** chat the reader had ever opened was acknowledged as read on
/// arrival, with the chat nowhere on screen. Read state is written to every
/// client the account owns, so that quietly emptied their unread everywhere.
final conversationProvider =
    AsyncNotifierProvider.family<ConversationNotifier, ConversationState, int>(
      ConversationNotifier.new,
      isAutoDispose: true,
    );

/// Tells the other side that this account is typing — at Telegram's cadence,
/// not the keyboard's.
///
/// Telegram expects a chat action about every five seconds while typing
/// continues and treats one as valid for six. Sending per keystroke would be
/// exactly the per-keystroke traffic `docs/TDLIB.md` forbids, so this sends at
/// most one every [interval] however fast somebody types.
class TypingSignal {
  /// The floor between two `SendChatAction` calls.
  static const Duration interval = Duration(seconds: 4);

  final ChatsRepository _repository;
  final int chatId;
  DateTime? _lastSent;

  TypingSignal(this._repository, this.chatId);

  /// Call on every change to the composer. Sends at most one action per
  /// [interval]; the rest are dropped, which is the point.
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

/// What this account may do with one message, asked when it is long-pressed.
///
/// A family so it is lazy by construction: watching `MessageRef(chat, id)` is
/// what issues the lookup, so a page of forty bubbles cannot accidentally ask
/// forty times — the same shape that keeps the channel tabs honest.
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

/// The emoji offered for one message, for the reaction picker.
///
/// A family on the *message*, not the chat, and lazy by construction for the
/// same reason [messageActionsProvider] is: watching it is what issues the
/// lookup, so a page of bubbles cannot ask on everyone's behalf.
final chatReactionsProvider = FutureProvider.family<List<String>, MessageRef>(
  (ref, target) => ref
      .watch(chatsRepositoryProvider)
      .messageReactions(chatId: target.chatId, messageId: target.messageId),
);
