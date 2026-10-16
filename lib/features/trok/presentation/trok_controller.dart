import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/trok/data/trok_client.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';

/// The most feed posts sent with one question.
const int trokFeedLimit = 120;

/// The posts Trok may read: the "All" feed as the reader sees it, with muted
/// channels left out, unread first.
final trokFeedProvider = Provider<List<Post>>((ref) {
  final posts = ref.watch(filteredFeedPostsProvider('All')).value ?? const [];
  final unread = posts.where((p) => !p.isRead);
  final read = posts.where((p) => p.isRead);
  return [...unread, ...read].take(trokFeedLimit).toList();
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

  const TrokState({
    this.conversations = const [],
    this.activeId,
    this.think = false,
    this.draftPost,
  });

  TrokConversation? get active =>
      conversations.where((c) => c.id == activeId).firstOrNull;

  bool get isAnswering => active?.isAnswering ?? false;

  TrokState copyWith({
    List<TrokConversation>? conversations,
    String? Function()? activeId,
    bool? think,
    Post? Function()? draftPost,
  }) => TrokState(
    conversations: conversations ?? this.conversations,
    activeId: activeId == null ? this.activeId : activeId(),
    think: think ?? this.think,
    draftPost: draftPost == null ? this.draftPost : draftPost(),
  );
}

/// Trok's conversations, kept for as long as the app runs. Once Argus answers,
/// they live in its chat on Telegram and come back from TDLib.
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
    if (text.isEmpty) return;
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
        post: post ?? _subject(conversation),
        action: action,
        feed: ref.read(trokFeedProvider),
        history: conversation.turns,
        think: state.think,
      ),
    );
  }

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
    if (question is! TrokQuestion || conversation.lastAnswer == null) return;
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
        post: question.post,
        action: question.action,
        feed: ref.read(trokFeedProvider),
        history: earlier,
        think: state.think,
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
  }

  void delete(String id) {
    if (id == state.activeId) _stopAnswering();
    state = state.copyWith(
      conversations: state.conversations.where((c) => c.id != id).toList(),
      activeId: id == state.activeId ? () => null : null,
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
          (event) => _updateAnswer(
            conversationId,
            answerId,
            (a) => a.apply(event, DateTime.now()),
          ),
          onError: (Object error, StackTrace stack) {
            debugPrint('[Trok] answer failed: $error');
            _answering = null;
            _updateAnswer(
              conversationId,
              answerId,
              (a) => a.copyWith(state: TrokAnswerState.failed),
            );
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
  ) {
    final conversation = state.conversations
        .where((c) => c.id == conversationId)
        .firstOrNull;
    if (conversation == null) return;
    final turns = [
      for (final t in conversation.turns)
        if (t is TrokAnswer && t.id == answerId) update(t) else t,
    ];
    _put(conversation.copyWith(turns: turns), keepOrder: true);
  }

  /// Stores [conversation], first in the list unless [keepOrder], and makes
  /// it the active one.
  void _put(
    TrokConversation conversation, {
    bool keepOrder = false,
    Post? draftPost,
  }) {
    final others = state.conversations.where((c) => c.id != conversation.id);
    final List<TrokConversation> conversations;
    if (keepOrder) {
      conversations = [
        for (final c in state.conversations)
          c.id == conversation.id ? conversation : c,
      ];
    } else {
      conversations = [conversation, ...others];
    }
    state = state.copyWith(
      conversations: conversations,
      activeId: keepOrder ? null : () => conversation.id,
      draftPost: keepOrder ? null : () => draftPost,
    );
  }
}

final trokControllerProvider = NotifierProvider<TrokController, TrokState>(
  TrokController.new,
);
