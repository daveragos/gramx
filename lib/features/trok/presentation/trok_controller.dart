import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/trok/data/trok_client.dart';
import 'package:gramx/features/trok/data/trok_wire.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

/// The most feed posts sent with one question.
const int trokFeedLimit = TrokWire.feedLimit;

/// The posts Trok may read: the "All" feed as the reader sees it, with muted
/// channels left out, unread first.
final trokFeedProvider = Provider<List<Post>>((ref) {
  final posts = ref.watch(filteredFeedPostsProvider('All')).value ?? const [];
  final unread = posts.where((p) => !p.isRead);
  final read = posts.where((p) => p.isRead);
  return [...unread, ...read].take(trokFeedLimit).toList();
});

/// A channel's public username by chat id. TDLib keeps it on the supergroup,
/// not on each post, and Trok counts a post with one as public: it gets a
/// t.me link, and a shared answer others can reuse.
final trokChannelUsernameProvider = Provider<String? Function(int chatId)>((
  ref,
) {
  final cache = ref.watch(chatCacheProvider);
  return (chatId) {
    final chat = cache.chat(chatId);
    if (chat == null) return null;
    return cache
        .supergroupForChat(chat)
        ?.usernames
        ?.activeUsernames
        .firstOrNull;
  };
});

@immutable
class TrokState {
  /// Newest first.
  final List<TrokConversation> conversations;

  /// The conversation on screen; null for a new, empty one.
  final String? activeId;

  /// Whether the next question asks Trok to take longer.
  final bool think;

  /// A post the next question will be about, shown in the composer.
  final Post? draftPost;

  /// Why the reader may not use Trok, once Trok has said so. Trok is no
  /// longer offered.
  final TrokFailure? blocked;

  const TrokState({
    this.conversations = const [],
    this.activeId,
    this.think = false,
    this.draftPost,
    this.blocked,
  });

  TrokConversation? get active =>
      conversations.where((c) => c.id == activeId).firstOrNull;

  bool get isAnswering => active?.isAnswering ?? false;

  TrokState copyWith({
    List<TrokConversation>? conversations,
    String? Function()? activeId,
    bool? think,
    Post? Function()? draftPost,
    TrokFailure? blocked,
  }) => TrokState(
    conversations: conversations ?? this.conversations,
    activeId: activeId == null ? this.activeId : activeId(),
    think: think ?? this.think,
    draftPost: draftPost == null ? this.draftPost : draftPost(),
    blocked: blocked ?? this.blocked,
  );
}

/// How many questions the reader has left today, and which features are on.
/// Fetched again after each answer.
final trokAllowanceProvider = FutureProvider<TrokAllowance>(
  (ref) => ref.watch(trokClientProvider).allowance(),
);

/// Trok's conversations. Trok's server keeps them, so History lists the same
/// chats on every phone; this holds the ones opened since the app started.
class TrokController extends Notifier<TrokState> {
  StreamSubscription<TrokEvent>? _answering;
  int _lastId = 0;

  @override
  TrokState build() {
    ref.onDispose(() => _answering?.cancel());
    return const TrokState();
  }

  String _nextId() => 't${++_lastId}';

  /// Asks [prompt] in the conversation on screen, starting one if there is
  /// none. The draft post, if any, goes with it.
  void ask(String prompt, {TrokPostAction? action}) {
    final text = prompt.trim();
    if (text.isEmpty || !(state.active?.isLoaded ?? true)) return;
    _stopAnswering();

    final post = state.draftPost;
    final now = DateTime.now();
    final conversation =
        state.active ??
        TrokConversation(
          id: _nextId(),
          title: post == null
              ? text
              : '$text${AppStrings.inlineSeparator}${post.channelTitle}',
          updatedAt: now,
        );
    final question = TrokQuestion(
      id: _nextId(),
      text: text,
      post: post,
      action: action,
    );
    final answer = TrokAnswer(id: _nextId(), startedAt: now);

    _put(
      conversation.copyWith(
        turns: [...conversation.turns, question, answer],
        updatedAt: now,
      ),
      draftPost: null,
    );
    _answer(
      conversation.id,
      answer.id,
      TrokRequest(
        prompt: text,
        // A follow-up is still about the post the conversation is about.
        post: _public(post ?? _subject(conversation)),
        action: action,
        feed: _feed(),
        history: conversation.turns,
        think: state.think,
        conversationId: conversation.remoteId,
      ),
    );
  }

  /// [post] with its channel's username, when the channel has one.
  Post? _public(Post? post) {
    if (post == null || (post.channelUsername ?? '').isNotEmpty) return post;
    final username = ref.read(trokChannelUsernameProvider)(post.chatId);
    return username == null ? post : post.copyWith(channelUsername: username);
  }

  List<Post> _feed() => [
    for (final post in ref.read(trokFeedProvider)) _public(post)!,
  ];

  /// The post [conversation] is about: the latest one a question carried.
  static Post? _subject(TrokConversation conversation) => conversation.turns
      .whereType<TrokQuestion>()
      .map((q) => q.post)
      .lastWhere((p) => p != null, orElse: () => null);

  /// Starts a new conversation about [post] and asks [action] of it.
  void askAboutPost(Post post, TrokPostAction action) {
    startNew(draftPost: post);
    ask(promptFor(action), action: action);
  }

  /// The question [action] asks, as the reader sees it in the chat.
  static String promptFor(TrokPostAction action) => switch (action) {
    TrokPostAction.explain => AppStrings.trokPostExplain,
    TrokPostAction.summarize => AppStrings.trokPostSummarizePrompt,
    TrokPostAction.translate => AppStrings.trokPostTranslatePrompt,
    TrokPostAction.factCheck => AppStrings.trokPostFactCheck,
  };

  /// Stops the answer being written; what arrived stays.
  void stop() {
    if (_answering == null) return;
    _stopAnswering();
  }

  /// Replaces the last answer with a new one to the same question.
  void regenerate() {
    final conversation = state.active;
    if (conversation == null || conversation.turns.length < 2) return;
    final question = conversation.turns[conversation.turns.length - 2];
    final replaced = conversation.lastAnswer;
    if (question is! TrokQuestion || replaced == null) return;
    _stopAnswering();

    final now = DateTime.now();
    final answer = TrokAnswer(id: _nextId(), startedAt: now);
    final earlier = conversation.turns.sublist(
      0,
      conversation.turns.length - 2,
    );
    _put(
      conversation.copyWith(
        turns: [...earlier, question, answer],
        updatedAt: now,
      ),
      draftPost: state.draftPost,
    );
    _answer(
      conversation.id,
      answer.id,
      TrokRequest(
        prompt: question.text,
        post: _public(question.post ?? _subject(conversation)),
        action: question.action,
        feed: _feed(),
        history: earlier,
        think: state.think,
        conversationId: conversation.remoteId,
        replaceAnswerId: replaced.remoteId,
      ),
    );
  }

  /// Leaves the conversation on screen for an empty one.
  void startNew({Post? draftPost}) {
    _stopAnswering();
    state = state.copyWith(activeId: () => null, draftPost: () => draftPost);
  }

  void open(String id) {
    if (id == state.activeId) return;
    _stopAnswering();
    state = state.copyWith(activeId: () => id, draftPost: () => null);
    final conversation = state.active;
    if (conversation != null && !conversation.isLoaded) {
      unawaited(_load(conversation));
    }
  }

  /// Fetches the messages of a conversation History listed.
  Future<void> _load(TrokConversation listed) async {
    final remoteId = listed.remoteId;
    if (remoteId == null) return;
    try {
      final loaded = await ref.read(trokClientProvider).conversation(remoteId);
      _updateConversation(listed.id, (c) => c.isLoaded ? c : loaded);
    } on Object catch (e) {
      debugPrint('[Trok] could not open a conversation: $e');
      // Back to a new chat; opening it from History tries again.
      if (state.activeId == listed.id) {
        state = state.copyWith(activeId: () => null);
      }
    }
  }

  /// Lists the conversations Trok keeps alongside the ones open here.
  Future<void> refreshHistory() async {
    final List<TrokConversation> listed;
    try {
      listed = await ref.read(trokClientProvider).conversations();
    } on Object catch (e) {
      debugPrint('[Trok] could not list conversations: $e');
      return;
    }
    final held = {for (final c in state.conversations) ?c.remoteId: c};
    final listedIds = {for (final c in listed) c.remoteId};
    final conversations = [
      for (final c in listed)
        held[c.remoteId]?.copyWith(title: c.title.isEmpty ? null : c.title) ??
            c,
      // Ones Trok hasn't listed: not answered yet, or past the first page.
      for (final c in state.conversations)
        if (!listedIds.contains(c.remoteId)) c,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(conversations: conversations);
  }

  /// Deletes a conversation here and on Trok's server.
  void delete(String id) {
    final remoteId = state.conversations
        .where((c) => c.id == id)
        .firstOrNull
        ?.remoteId;
    if (id == state.activeId) _stopAnswering();
    state = state.copyWith(
      conversations: state.conversations.where((c) => c.id != id).toList(),
      activeId: id == state.activeId ? () => null : null,
    );
    if (remoteId == null) return;
    unawaited(
      ref
          .read(trokClientProvider)
          .deleteConversation(remoteId)
          .catchError(
            (Object e) => debugPrint('[Trok] could not delete it: $e'),
          ),
    );
  }

  void setThink(bool think) => state = state.copyWith(think: think);

  void setDraftPost(Post? post) =>
      state = state.copyWith(draftPost: () => post);

  void _answer(String conversationId, String answerId, TrokRequest request) {
    _answering = ref
        .read(trokClientProvider)
        .ask(request)
        .listen(
          (event) {
            if (event is TrokStarted) {
              _updateConversation(
                conversationId,
                (c) => c.copyWith(
                  remoteId: event.conversationId,
                  title: event.title.isEmpty ? null : event.title,
                ),
              );
            }
            _updateAnswer(
              conversationId,
              answerId,
              (a) => a.apply(event, DateTime.now()),
            );
          },
          onError: (Object error, StackTrace stack) {
            debugPrint('[Trok] answer failed: $error');
            _answering = null;
            final failure = error is TrokFailure ? error : null;
            if (failure != null && failure.isBlocked) {
              state = state.copyWith(blocked: failure);
            }
            _updateAnswer(
              conversationId,
              answerId,
              (a) =>
                  a.copyWith(state: TrokAnswerState.failed, failure: failure),
            );
            ref.invalidate(trokAllowanceProvider);
          },
          onDone: () {
            _answering = null;
            _updateAnswer(
              conversationId,
              answerId,
              (a) => a.state.isActive
                  ? a.copyWith(state: TrokAnswerState.done)
                  : a,
            );
            ref.invalidate(trokAllowanceProvider);
          },
          cancelOnError: true,
        );
  }

  /// Cancels the answer in progress and marks it stopped.
  void _stopAnswering() {
    final subscription = _answering;
    if (subscription == null) return;
    _answering = null;
    unawaited(subscription.cancel());
    for (final c in state.conversations) {
      final answer = c.lastAnswer;
      if (answer != null && answer.state.isActive) {
        _updateAnswer(
          c.id,
          answer.id,
          (a) => a.copyWith(state: TrokAnswerState.stopped),
        );
      }
    }
  }

  void _updateAnswer(
    String conversationId,
    String answerId,
    TrokAnswer Function(TrokAnswer) update,
  ) => _updateConversation(
    conversationId,
    (c) => c.copyWith(
      turns: [
        for (final t in c.turns)
          if (t is TrokAnswer && t.id == answerId) update(t) else t,
      ],
    ),
  );

  /// Replaces the conversation [id] with [update] of it, in its place.
  void _updateConversation(
    String id,
    TrokConversation Function(TrokConversation) update,
  ) {
    final conversation = state.conversations
        .where((c) => c.id == id)
        .firstOrNull;
    if (conversation == null) return;
    state = state.copyWith(
      conversations: [
        for (final c in state.conversations)
          c.id == id ? update(conversation) : c,
      ],
    );
  }

  /// Stores [conversation] first in the list and makes it the active one.
  void _put(TrokConversation conversation, {Post? draftPost}) {
    state = state.copyWith(
      conversations: [
        conversation,
        ...state.conversations.where((c) => c.id != conversation.id),
      ],
      activeId: () => conversation.id,
      draftPost: () => draftPost,
    );
  }
}

final trokControllerProvider = NotifierProvider<TrokController, TrokState>(
  TrokController.new,
);
