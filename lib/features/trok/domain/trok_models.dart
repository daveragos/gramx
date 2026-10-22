import 'package:flutter/foundation.dart';

import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/core/text/text_clamp.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
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

/// Something an answer drew on, drawn under it.
@immutable
sealed class TrokSource {
  const TrokSource();

  factory TrokSource.fromPost(Post post) = TrokPostSource.fromPost;
}

/// A channel post. Opens the post.
class TrokPostSource extends TrokSource {
  /// The post as gramX holds it. Null for a public post only Trok found.
  final String? postId;

  /// Its t.me link, which opens it when there is no [postId].
  final String? link;
  final String channelTitle;
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;

  /// The post's text, untrimmed for length; the card clamps it.
  final String snippet;
  final DateTime? publishedAt;

  /// The picture the card shows of the post. Null when it has none, or
  /// gramX doesn't hold the post; the card then looks it up.
  final TrokSourcePicture? picture;

  const TrokPostSource({
    required this.channelTitle,
    required this.snippet,
    this.postId,
    this.link,
    this.publishedAt,
    this.avatarPath,
    this.avatarFileId,
    this.avatarColorHex,
    this.picture,
  });

  factory TrokPostSource.fromPost(Post post) => TrokPostSource(
    postId: post.id,
    // As Trok's citations of it read, so they can be matched to it.
    link: TelegramIds.postLink(
      chatId: post.chatId,
      messageId: post.messageId,
      username: post.channelUsername,
    ),
    channelTitle: post.channelTitle,
    avatarPath: post.channelAvatarUrl,
    avatarFileId: post.channelAvatarFileId,
    avatarColorHex: post.channelAvatarColor,
    snippet: (post.text ?? '').trim(),
    publishedAt: post.publishedAt,
    picture: TrokSourcePicture.of(post),
  );
}

/// A small picture of a source, for its card.
@immutable
class TrokSourcePicture {
  /// TDLib's id for the picture.
  final int fileId;

  /// TDLib's tiny blurred preview, shown until the picture arrives.
  final String? minithumbnail;

  /// Whether it is a video's cover, which the card marks.
  final bool isVideo;

  const TrokSourcePicture({
    required this.fileId,
    this.minithumbnail,
    this.isVideo = false,
  });

  /// [post]'s first photo, or the cover of its first video, GIF or file,
  /// or else its link's picture. Null when it has none.
  static TrokSourcePicture? of(Post post) {
    for (final media in post.media) {
      if (media.type == MediaType.audio || media.type == MediaType.voice) {
        continue;
      }
      // Only a photo is its own picture; a video's file is the video.
      final fileId = media.type == MediaType.photo
          ? media.thumbnailFileId ?? media.fileId
          : media.thumbnailFileId;
      if (fileId == null || fileId <= 0) continue;
      return TrokSourcePicture(
        fileId: fileId,
        minithumbnail: media.minithumbnail,
        isVideo: media.type == MediaType.video,
      );
    }
    final linkPicture = post.linkPreviewFileId;
    if (linkPicture != null && linkPicture > 0) {
      return TrokSourcePicture(fileId: linkPicture);
    }
    return null;
  }
}

/// A web page Trok read, as fact-checks do. Opens in the browser.
class TrokWebSource extends TrokSource {
  final String url;
  final String title;

  /// The site's name, such as "reuters.com".
  final String site;

  const TrokWebSource({
    required this.url,
    required this.title,
    required this.site,
  });
}

/// Why Trok couldn't answer, in words the reader is shown as they are.
@immutable
class TrokFailure implements Exception {
  /// Trok's code for it, such as `rate_limited`.
  final String code;
  final String message;

  /// How long until asking again may work, when Trok says.
  final Duration? retryAfter;

  const TrokFailure(this.code, this.message, {this.retryAfter});

  /// Whether asking the same again could get an answer.
  bool get canRetry => !const {
    'bad_request',
    'blocked',
    'rate_limited',
    'refused',
    'too_large',
  }.contains(code);

  /// The reader may not use Trok at all.
  bool get isBlocked => code == 'blocked';

  @override
  String toString() => 'TrokFailure($code: $message)';
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

  /// Trok's id for this answer, once it has one. Regenerating replaces it.
  final String? remoteId;

  /// Why it failed, when Trok said.
  final TrokFailure? failure;

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
    this.remoteId,
    this.failure,
  }) : super(id);

  TrokAnswer copyWith({
    TrokAnswerState? state,
    String? text,
    List<TextEntity>? entities,
    List<String>? steps,
    List<TrokSource>? sources,
    List<String>? followUps,
    Duration? thoughtFor,
    String? remoteId,
    TrokFailure? failure,
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
    remoteId: remoteId ?? this.remoteId,
    failure: failure ?? this.failure,
  );

  /// This answer with [event] applied, at [now].
  TrokAnswer apply(TrokEvent event, DateTime now) => switch (event) {
    TrokStarted(:final answerId) => copyWith(remoteId: answerId),
    TrokStep(:final label, replacesLast: true) when steps.isNotEmpty =>
      copyWith(steps: [...steps.sublist(0, steps.length - 1), label]),
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

  /// Shown in History; see [titleFor].
  final String title;
  final List<TrokTurn> turns;
  final DateTime updatedAt;

  /// Trok's id for it, once Trok has answered in it. Follow-ups go there.
  final String? remoteId;

  /// False for one listed in History whose messages haven't been fetched.
  final bool isLoaded;

  const TrokConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.turns = const [],
    this.remoteId,
    this.isLoaded = true,
  });

  /// The longest title, in characters, before it is cut at a word.
  static const int titleLength = 60;

  /// What History calls a conversation: the opening line of the post it is
  /// about, else the [question]. Trok names each one after its first question
  /// and channel, so chats about posts all read "Summarize this post · …".
  static String titleFor({required String question, Post? post}) {
    if (post == null) return question;
    final opening = (post.text ?? '').trim().split('\n').first.trim();
    if (opening.isEmpty) return post.channelTitle;
    if (opening.length <= titleLength) return opening;
    final end = collapsedLength(opening, maxLines: 1, maxChars: titleLength);
    return '${opening.substring(0, end).trimRight()}…';
  }

  TrokAnswer? get lastAnswer => switch (turns.lastOrNull) {
    final TrokAnswer answer => answer,
    _ => null,
  };

  bool get isAnswering => lastAnswer?.state.isActive ?? false;

  TrokConversation copyWith({
    String? title,
    List<TrokTurn>? turns,
    DateTime? updatedAt,
    String? remoteId,
    bool? isLoaded,
  }) => TrokConversation(
    id: id,
    title: title ?? this.title,
    turns: turns ?? this.turns,
    updatedAt: updatedAt ?? this.updatedAt,
    remoteId: remoteId ?? this.remoteId,
    isLoaded: isLoaded ?? this.isLoaded,
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

  /// Trok's id for the conversation; null starts one.
  final String? conversationId;

  /// Trok's id for the answer this one replaces, when regenerating.
  final String? replaceAnswerId;

  const TrokRequest({
    required this.prompt,
    this.post,
    this.action,
    this.feed = const [],
    this.history = const [],
    this.think = false,
    this.conversationId,
    this.replaceAnswerId,
  });
}

/// What the reader may do with Trok today.
@immutable
class TrokAllowance {
  final int questionsPerDay;
  final int usedToday;
  final DateTime? resetsAt;
  final bool think;
  final bool translate;

  const TrokAllowance({
    required this.questionsPerDay,
    required this.usedToday,
    this.resetsAt,
    this.think = true,
    this.translate = true,
  });

  int get questionsLeft =>
      (questionsPerDay - usedToday).clamp(0, questionsPerDay);
}

/// What Trok sends back while answering. The stream ends when the answer is
/// complete and fails, with a [TrokFailure] when Trok says why, if it can't
/// answer.
@immutable
sealed class TrokEvent {
  const TrokEvent();
}

/// Trok has the question: its ids for the conversation and the answer, and
/// the conversation's title.
class TrokStarted extends TrokEvent {
  final String conversationId;
  final String answerId;
  final String title;

  const TrokStarted({
    required this.conversationId,
    required this.answerId,
    required this.title,
  });
}

/// A step taken before answering, such as "Reading 24 posts".
class TrokStep extends TrokEvent {
  final String label;

  /// Updates the last step in place, as progress does, rather than adding
  /// another.
  final bool replacesLast;

  const TrokStep(this.label, {this.replacesLast = false});
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
