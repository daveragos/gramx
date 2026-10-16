import 'package:flutter/foundation.dart';

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

/// What a reader can ask Trok to do with one post. Each is sent as an
/// ordinary question, so it reads in the chat like one the reader typed.
enum TrokPostAction { explain, summarize, translate, factCheck }

/// Where an answer is in its life.
enum TrokAnswerState {
  /// Working before any text: the steps it takes are shown.
  thinking,

  /// Text is arriving.
  streaming,
  done,

  /// The reader stopped it; what arrived stays.
  stopped,
  failed;

  bool get isActive => this == thinking || this == streaming;
}

/// A post an answer drew on. Drawn under the answer; opens the post.
@immutable
class TrokSource {
  final String postId;
  final String channelTitle;
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;

  /// The post's text, untrimmed for length; the card clamps it.
  final String snippet;
  final DateTime publishedAt;

  const TrokSource({
    required this.postId,
    required this.channelTitle,
    required this.snippet,
    required this.publishedAt,
    this.avatarPath,
    this.avatarFileId,
    this.avatarColorHex,
  });

  factory TrokSource.fromPost(Post post) => TrokSource(
    postId: post.id,
    channelTitle: post.channelTitle,
    avatarPath: post.channelAvatarUrl,
    avatarFileId: post.channelAvatarFileId,
    avatarColorHex: post.channelAvatarColor,
    snippet: (post.text ?? '').trim(),
    publishedAt: post.publishedAt,
  );
}

/// One message in a conversation with Trok.
@immutable
sealed class TrokTurn {
  final String id;

  const TrokTurn(this.id);
}

/// What the reader asked, and the post it is about, if any.
class TrokQuestion extends TrokTurn {
  final String text;
  final Post? post;
  final TrokPostAction? action;

  const TrokQuestion({
    required String id,
    required this.text,
    this.post,
    this.action,
  }) : super(id);
}

/// Trok's reply. Text arrives as Telegram formatted text, so a bot's reply
/// renders as it would in a chat.
class TrokAnswer extends TrokTurn {
  final TrokAnswerState state;
  final String text;
  final List<TextEntity> entities;

  /// What Trok did before answering, such as reading posts, in order.
  final List<String> steps;
  final List<TrokSource> sources;

  /// Questions the reader might ask next.
  final List<String> followUps;
  final DateTime startedAt;

  /// From the question to the first text. Null until text arrives.
  final Duration? thoughtFor;

  const TrokAnswer({
    required String id,
    required this.startedAt,
    this.state = TrokAnswerState.thinking,
    this.text = '',
    this.entities = const [],
    this.steps = const [],
    this.sources = const [],
    this.followUps = const [],
    this.thoughtFor,
  }) : super(id);

  TrokAnswer copyWith({
    TrokAnswerState? state,
    String? text,
    List<TextEntity>? entities,
    List<String>? steps,
    List<TrokSource>? sources,
    List<String>? followUps,
    Duration? thoughtFor,
  }) => TrokAnswer(
    id: id,
    startedAt: startedAt,
    state: state ?? this.state,
    text: text ?? this.text,
    entities: entities ?? this.entities,
    steps: steps ?? this.steps,
    sources: sources ?? this.sources,
    followUps: followUps ?? this.followUps,
    thoughtFor: thoughtFor ?? this.thoughtFor,
  );

  /// This answer with [event] applied, at [now].
  TrokAnswer apply(TrokEvent event, DateTime now) => switch (event) {
    TrokStep(:final label) => copyWith(steps: [...steps, label]),
    TrokText(:final text, :final entities) => copyWith(
      state: TrokAnswerState.streaming,
      text: text,
      entities: entities,
      thoughtFor: thoughtFor ?? now.difference(startedAt),
    ),
    TrokSources(:final sources) => copyWith(sources: sources),
    TrokFollowUps(:final followUps) => copyWith(followUps: followUps),
  };
}

@immutable
class TrokConversation {
  final String id;

  /// From the first question; shown in History.
  final String title;
  final List<TrokTurn> turns;
  final DateTime updatedAt;

  const TrokConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.turns = const [],
  });

  TrokAnswer? get lastAnswer => switch (turns.lastOrNull) {
    final TrokAnswer answer => answer,
    _ => null,
  };

  bool get isAnswering => lastAnswer?.state.isActive ?? false;

  TrokConversation copyWith({List<TrokTurn>? turns, DateTime? updatedAt}) =>
      TrokConversation(
        id: id,
        title: title,
        turns: turns ?? this.turns,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Everything sent with one question.
@immutable
class TrokRequest {
  final String prompt;

  /// The post the question is about.
  final Post? post;
  final TrokPostAction? action;

  /// Posts from the reader's feed Trok may read, unread first.
  final List<Post> feed;

  /// The conversation so far, before this question.
  final List<TrokTurn> history;

  /// Whether the reader asked Trok to take longer over it.
  final bool think;

  const TrokRequest({
    required this.prompt,
    this.post,
    this.action,
    this.feed = const [],
    this.history = const [],
    this.think = false,
  });
}

/// What Trok sends back while answering. The stream ends when the answer is
/// complete and fails if it can't answer.
@immutable
sealed class TrokEvent {
  const TrokEvent();
}

/// A step taken before answering, such as "Reading 24 posts".
class TrokStep extends TrokEvent {
  final String label;

  const TrokStep(this.label);
}

/// The whole answer so far, replacing the last. Telegram bots stream by
/// editing their message, and each edit carries the full text.
class TrokText extends TrokEvent {
  final String text;
  final List<TextEntity> entities;

  const TrokText(this.text, [this.entities = const []]);
}

class TrokSources extends TrokEvent {
  final List<TrokSource> sources;

  const TrokSources(this.sources);
}

class TrokFollowUps extends TrokEvent {
  final List<String> followUps;

  const TrokFollowUps(this.followUps);
}
