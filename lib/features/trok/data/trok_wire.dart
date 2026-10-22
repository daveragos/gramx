import 'dart:convert';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/trok/data/trok_markdown.dart';
import 'package:gramx/features/trok/data/trok_pictures.dart';
import 'package:gramx/features/trok/data/trok_post_files.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';

/// The posts sent in one conversation, by the short ref Trok cites each by
/// (`p1`, `p2`). Trok keeps the feed sent with a conversation's first
/// question, so a ref stays the same post for the whole conversation.
class TrokRefs {
  final _posts = <String, Post>{};
  final _refs = <String, String>{};

  /// Links for refs known only from History, for posts gramX didn't send
  /// from this phone.
  final _links = <String, String>{};
  int _next;

  TrokRefs() : _next = 1;

  /// For a conversation started elsewhere or before the app restarted. Trok
  /// may hold up to 121 refs from its first question that History doesn't
  /// list, so new ones start after them.
  TrokRefs.rebuilt() : _next = TrokWire.feedLimit + 2;

  String refFor(Post post) {
    final held = _refs[post.id];
    if (held != null) return held;
    final ref = 'p${_next++}';
    _refs[post.id] = ref;
    _posts[ref] = post;
    return ref;
  }

  /// Notes what History says about [ref].
  void remember(String ref, {Post? post, String? link}) {
    if (post != null && !_posts.containsKey(ref)) {
      _posts[ref] = post;
      _refs[post.id] ??= ref;
    }
    if (link != null) _links[ref] = link;
    final number = int.tryParse(ref.startsWith('p') ? ref.substring(1) : '');
    if (number != null && number >= _next) _next = number + 1;
  }

  Post? post(String ref) => _posts[ref];

  /// Where a citation of [ref] opens: the post's t.me link, which the app
  /// opens at the post.
  String? link(String ref) {
    final post = _posts[ref];
    if (post == null) return _links[ref];
    return TelegramIds.postLink(
      chatId: post.chatId,
      messageId: post.messageId,
      username: post.channelUsername,
    );
  }

  /// The post held for a t.me [link], if any.
  Post? postAt(String link) {
    final uri = Uri.tryParse(link);
    final parsed = uri == null ? null : TelegramLinks.parse(uri);
    for (final post in _posts.values) {
      final number = TelegramIds.serverMessageId(post.messageId);
      final matches = switch (parsed) {
        TelegramPostLink(:final username, :final serverMessageId) =>
          serverMessageId == number &&
              username.toLowerCase() ==
                  (post.channelUsername ?? '').toLowerCase(),
        TelegramPrivatePostLink(:final supergroupId, :final serverMessageId) =>
          serverMessageId == number &&
              supergroupId == TelegramIds.supergroupId(post.chatId),
        _ => false,
      };
      if (matches) return post;
    }
    return null;
  }

  /// Turns a citation into the address it opens: `ref:p2` to the post's
  /// link, and t.me and web links as they are.
  String? resolve(String target) {
    if (target.startsWith('ref:')) return link(target.substring(4));
    return TrokMarkdown.webOnly(target);
  }
}

/// The JSON Trok's server reads and writes.
abstract final class TrokWire {
  /// The most feed posts one question may carry.
  static const feedLimit = 120;

  /// The longest question Trok takes, in characters.
  static const questionLimit = 4000;

  /// Post text past this is cut, as Trok would cut it.
  static const postTextLimit = 4096;

  /// A post as Trok reads it, with [pictures] of it when sent.
  static Map<String, Object?> post(
    Post post,
    String ref, {
    List<TrokPicture> pictures = const [],
    List<TrokSentFile> files = const [],
  }) {
    final text = _cut(post.text ?? '', postTextLimit);
    return {
      'ref': ref,
      'chat_id': post.chatId,
      'message_id': TelegramIds.serverMessageId(post.messageId),
      'link': publicLink(post),
      'channel': {
        'title': post.channelTitle,
        'username': _username(post.channelUsername),
        'verified': post.isChannelVerified,
      },
      'date': post.publishedAt.toUtc().toIso8601String(),
      'text': text,
      'entities': [
        for (final e in post.entities)
          if (_entityTypes[e.type] case final type?)
            if (e.offset >= 0 && e.length > 0 && e.offset < text.length)
              {
                'type': type,
                'offset': e.offset,
                'length': e.offset + e.length > text.length
                    ? text.length - e.offset
                    : e.length,
                if (e.type == TextEntityType.textUrl && e.url != null)
                  'url': e.url,
              },
      ],
      'media': [
        for (final m in post.media)
          {
            'type': _mediaTypes[m.type],
            if (_named.contains(m.type)) 'file_name': ?_string(m.fileName),
            if (m.duration > 0) 'duration': m.duration,
          },
        if (post.poll != null) {'type': 'poll'},
      ],
      if (post.poll case final poll?) 'poll': _poll(poll),
      if (_string(post.linkPreviewUrl) case final url?)
        'link_preview': {
          'url': url,
          'title': _string(post.linkPreviewTitle),
          'description': _string(post.linkPreviewDescription),
        },
      if (_string(post.replyToText) case final text?)
        'reply_to': {
          'text': text,
          'quote': post.replyToIsQuote,
          'author': _string(post.replyToAuthorTitle),
        },
      if (pictures.isNotEmpty)
        'images': [
          for (final picture in pictures)
            {
              'mime_type': 'image/jpeg',
              'width': picture.width,
              'height': picture.height,
              if (picture.isLinkPreview) 'link_preview': true,
              'data': base64Encode(picture.jpeg),
            },
        ],
      if (files.isNotEmpty)
        'files': [
          for (final file in files)
            {'file_id': file.fileId, 'type': file.type.wire},
        ],
      'views': post.viewCount,
      'comments': post.replyCount,
      'forwards': post.forwardCount,
      'reactions': post.reactions,
      'forwarded_from': post.forwardedFromTitle == null
          ? null
          : {
              'title': post.forwardedFromTitle,
              'username': _username(post.forwardedFromUsername),
              'message_id': switch (post.forwardedFromMessageId) {
                final id? => TelegramIds.serverMessageId(id),
                null => null,
              },
            },
      'unread': !post.isRead,
    };
  }

  /// A poll as anyone can see it, without the reader's own vote. Telegram
  /// gives each option's votes only once the poll is closed or the reader
  /// has voted, so they are left out before that.
  static Map<String, Object?> _poll(Poll poll) {
    final counted = poll.isClosed || poll.chosenOptionIds.isNotEmpty;
    return {
      'question': poll.question,
      'options': [
        for (final option in poll.options)
          {'text': option.text, if (counted) 'voters': option.voterCount},
      ],
      'total_voters': poll.totalVoterCount,
      'quiz': poll.isQuiz,
      'multiple_answers': poll.allowsMultipleAnswers,
      'closed': poll.isClosed,
    };
  }

  /// `https://t.me/<username>/<number>` for a public channel's post, which
  /// Trok counts as public. Null for a private channel's.
  static String? publicLink(Post post) {
    final username = _username(post.channelUsername);
    final number = TelegramIds.serverMessageId(post.messageId);
    if (username == null || number <= 0) return null;
    return 'https://t.me/$username/$number';
  }

  /// The kind of question [request] is.
  static String action(TrokRequest request) => switch (request.action) {
    TrokPostAction.explain => 'explain',
    TrokPostAction.summarize => 'summarize',
    TrokPostAction.translate => 'translate',
    TrokPostAction.factCheck => 'fact_check',
    null => switch (request.prompt) {
      AppStrings.trokStarterCatchUpPrompt => 'catch_up',
      AppStrings.trokStarterTodayPrompt => 'today',
      _ => 'ask',
    },
  };

  /// The language to translate [post] into. A reader who wants Amharic
  /// answers gets any post not already in Ethiopic script in Amharic, and
  /// one that is in English. A reader who wants Afaan Oromo gets any post
  /// in Afaan Oromo; Trok returns one already in it unchanged. Otherwise a
  /// reader of an English post gets their phone's language when Trok
  /// translates into it, or Amharic; any other post, Amharic included, is
  /// translated into English.
  static String translateTarget(
    Post post,
    String deviceLanguage, {
    String answerLanguage = 'en',
  }) {
    final text = post.text ?? '';
    if (answerLanguage == 'am') return _isMostlyEthiopic(text) ? 'en' : 'am';
    if (answerLanguage == 'om') return 'om';
    if (_isMostlyEthiopic(text) || !_looksEnglish(text)) return 'en';
    return const {'am', 'om', 'ti'}.contains(deviceLanguage)
        ? deviceLanguage
        : 'am';
  }

  /// Whether [text] is worth offering to translate for a reader who reads
  /// [answerLanguage]: enough words, in another language.
  static bool needsTranslation(String text, String answerLanguage) {
    final letters = _letter.allMatches(text).length;
    if (letters < _translatableLetters) return false;
    if (answerLanguage == 'am') return !_isMostlyEthiopic(text);
    // Another script is plainly neither English nor Afaan Oromo.
    if (_latinLetter.allMatches(text).length * 2 < letters) return true;
    // In Latin letters, a short post can't be told apart, and is taken for
    // the reader's language. A longer one is English by its commonest words.
    final words = _latinWord
        .allMatches(text)
        .map((m) => m[0]!.toLowerCase())
        .toList();
    if (words.length < _telltaleWords) return false;
    final common = words.where(_englishWords.contains).length;
    final english = common * 12 >= words.length;
    // Other Latin-script posts could be in Afaan Oromo itself.
    return answerLanguage == 'om' ? english : !english;
  }

  /// Fewer letters than this are a word or two, read at a glance.
  static const _translatableLetters = 12;

  /// Fewer Latin words than this don't say which language they are.
  static const _telltaleWords = 8;

  /// [markdown] formatted, with citations opening the posts they name.
  static TrokText text(String markdown, TrokRefs refs, {bool partial = false}) {
    final (text, entities) = TrokMarkdown.format(
      markdown,
      resolve: refs.resolve,
      partial: partial,
    );
    return TrokText(text, entities);
  }

  /// The `items` of a `sources` event, or of a message in History.
  static List<TrokSource> sources(Object? items, TrokRefs refs) {
    if (items is! List) return const [];
    final sources = <TrokSource>[];
    final seen = <String>{};
    for (final item in items.whereType<Map<String, dynamic>>()) {
      final source = _source(item, refs);
      if (source == null) continue;
      final key = switch (source) {
        TrokPostSource(:final postId, :final link) => postId ?? link ?? '',
        TrokWebSource(:final url) => url,
      };
      if (seen.add(key)) sources.add(source);
    }
    return sources;
  }

  static TrokSource? _source(Map<String, dynamic> item, TrokRefs refs) {
    switch (item['type']) {
      case 'web':
        final url = _string(item['url']);
        if (url == null || TrokMarkdown.webOnly(url) == null) return null;
        final site = _string(item['site']) ?? Uri.tryParse(url)?.host ?? url;
        return TrokWebSource(
          url: url,
          title: _string(item['title']) ?? site,
          site: site,
        );
      case 'post':
        final ref = _string(item['ref']);
        final link = _string(item['link']);
        if (ref != null && link != null) refs.remember(ref, link: link);
        final held =
            (ref == null ? null : refs.post(ref)) ??
            (link == null ? null : refs.postAt(link));
        if (held != null) return TrokSource.fromPost(held);
        if (link == null) return null;
        return TrokPostSource(
          link: link,
          channelTitle: _string(item['title']) ?? _channelOf(link),
          snippet: _string(item['snippet']) ?? '',
          publishedAt: _date(item['date']),
        );
    }
    return null;
  }

  /// The `items` of a `follow_ups` event.
  static List<String> followUps(Object? items) => [
    if (items is List)
      for (final item in items.whereType<String>())
        if (item.trim().isNotEmpty) item.trim(),
  ];

  /// A conversation as History lists it, before its messages are fetched.
  static TrokConversation summary(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return TrokConversation(
      id: id,
      remoteId: id,
      title: _string(json['title']) ?? '',
      updatedAt: _date(json['updated_at']) ?? DateTime.now(),
      isLoaded: false,
    );
  }

  /// A conversation with its messages, noting in [refs] the posts it cites.
  static TrokConversation conversation(
    Map<String, dynamic> json,
    TrokRefs refs,
  ) {
    final subject = postFrom(json['post']);
    final subjectRef = switch (json['post']) {
      {'ref': final String ref} => ref,
      _ => null,
    };
    if (subject != null && subjectRef != null) {
      refs.remember(subjectRef, post: subject);
    }

    final messages = (json['messages'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    // Sources first, so citations in earlier answers can open later ones.
    for (final m in messages) {
      sources(m['sources'], refs);
    }

    final turns = <TrokTurn>[];
    for (final m in messages) {
      final id = _string(m['id']) ?? 'm${turns.length}';
      final created = _date(m['created_at']) ?? DateTime.now();
      if (m['role'] == 'user') {
        turns.add(
          TrokQuestion(
            id: id,
            text: _string(m['text']) ?? '',
            // The first question quotes the post, as when it was asked.
            post: turns.isEmpty ? subject : null,
            action: _postAction(m['action']),
          ),
        );
      } else if (m['role'] == 'trok') {
        final text = TrokWire.text(_string(m['text']) ?? '', refs);
        final thoughtMs = m['thought_ms'];
        turns.add(
          TrokAnswer(
            id: id,
            remoteId: id,
            startedAt: created,
            state: switch (m['finish']) {
              'stopped' => TrokAnswerState.stopped,
              'error' => TrokAnswerState.failed,
              _ => TrokAnswerState.done,
            },
            text: text.text,
            entities: text.entities,
            steps: [
              if (m['steps'] is List)
                ...(m['steps'] as List).whereType<String>(),
            ],
            sources: sources(m['sources'], refs),
            followUps: followUps(m['follow_ups']),
            thoughtFor: thoughtMs is int
                ? Duration(milliseconds: thoughtMs)
                : null,
          ),
        );
      }
    }

    final id = json['id'] as String;
    return TrokConversation(
      id: id,
      remoteId: id,
      title: _string(json['title']) ?? '',
      updatedAt: _date(json['updated_at']) ?? DateTime.now(),
      turns: turns,
    );
  }

  /// A post Trok sent back, as much of it as History keeps.
  static Post? postFrom(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final chatId = json['chat_id'];
    final number = json['message_id'];
    if (chatId is! int || number is! int) return null;
    final channel = json['channel'] is Map<String, dynamic>
        ? json['channel'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final messageId = number << TelegramIds.messageIdShift;
    return Post(
      id: '${chatId}_$messageId',
      chatId: chatId,
      channelId: '$chatId',
      messageId: messageId,
      channelTitle: _string(channel['title']) ?? '',
      channelUsername: _string(channel['username']),
      isChannelVerified: channel['verified'] == true,
      text: _string(json['text']),
      publishedAt: _date(json['date']) ?? DateTime.now(),
      viewCount: _int(json['views']),
      replyCount: _int(json['comments']),
      forwardCount: _int(json['forwards']),
      isRead: json['unread'] != true,
    );
  }

  static TrokAllowance allowance(Map<String, dynamic> json) {
    final limits = json['limits'] is Map<String, dynamic>
        ? json['limits'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final features = json['features'] is Map<String, dynamic>
        ? json['features'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return TrokAllowance(
      questionsPerDay: _int(limits['questions_per_day']),
      usedToday: _int(limits['used_today']),
      resetsAt: _date(limits['resets_at']),
      think: features['think'] != false,
      translate: features['translate'] != false,
    );
  }

  /// The failure in an error body or `error` event, or null if [json] is
  /// neither.
  static TrokFailure? failure(Object? json) {
    final error = switch (json) {
      {'error': final Map<String, dynamic> error} => error,
      {'code': _} => json as Map<String, dynamic>,
      _ => null,
    };
    if (error == null) return null;
    final retryAfter = error['retry_after'];
    return TrokFailure(
      _string(error['code']) ?? 'unknown',
      _string(error['message']) ?? AppStrings.trokFailed,
      retryAfter: retryAfter is num
          ? Duration(seconds: retryAfter.round())
          : null,
    );
  }

  static TrokPostAction? _postAction(Object? action) => switch (action) {
    'explain' => TrokPostAction.explain,
    'summarize' => TrokPostAction.summarize,
    'translate' => TrokPostAction.translate,
    'fact_check' => TrokPostAction.factCheck,
    _ => null,
  };

  /// [text] cut to [limit] UTF-16 units, never between the halves of an
  /// emoji.
  static String _cut(String text, int limit) {
    if (text.length <= limit) return text;
    var end = limit;
    final unit = text.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) end--;
    return text.substring(0, end);
  }

  static String? _username(String? username) {
    final handle = username?.trim().replaceAll('@', '');
    return handle == null || handle.isEmpty ? null : handle;
  }

  /// The channel a t.me link names, for a post Trok found without a title.
  static String _channelOf(String link) =>
      Uri.tryParse(link)?.pathSegments.firstOrNull ?? link;

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  /// Latin letters with enough of English's commonest words among them.
  /// Afaan Oromo is written in Latin letters too, and has few of them.
  static bool _looksEnglish(String text) {
    final letters = _letter.allMatches(text).length;
    if (letters == 0) return false;
    if (_latinLetter.allMatches(text).length * 2 < letters) return false;
    final words = _latinWord
        .allMatches(text)
        .map((m) => m[0]!.toLowerCase())
        .toList();
    final common = words.where(_englishWords.contains).length;
    return common >= 2 && common * 12 >= words.length;
  }

  static final _latinLetter = RegExp('[A-Za-z]');
  static final _latinWord = RegExp(r"[A-Za-z']+");
  static const _englishWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'has',
    'have',
    'in',
    'is',
    'it',
    'not',
    'of',
    'on',
    'or',
    'that',
    'the',
    'this',
    'to',
    'was',
    'we',
    'will',
    'with',
    'you',
  };

  static bool _isMostlyEthiopic(String text) {
    final letters = _letter.allMatches(text).length;
    if (letters == 0) return false;
    return _ethiopic.allMatches(text).length * 2 >= letters;
  }

  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _ethiopic = RegExp(r'[ሀ-᎟ⶀ-⷟꬀-꬯]');

  static const _entityTypes = {
    TextEntityType.bold: 'bold',
    TextEntityType.italic: 'italic',
    TextEntityType.underline: 'underline',
    TextEntityType.strikethrough: 'strikethrough',
    TextEntityType.code: 'code',
    TextEntityType.codeBlock: 'pre',
    TextEntityType.blockQuote: 'blockquote',
    TextEntityType.expandableBlockQuote: 'expandable_blockquote',
    TextEntityType.url: 'url',
    TextEntityType.textUrl: 'text_url',
    TextEntityType.mention: 'mention',
    TextEntityType.mentionName: 'mention_name',
    TextEntityType.hashtag: 'hashtag',
    TextEntityType.cashtag: 'cashtag',
    TextEntityType.botCommand: 'bot_command',
    TextEntityType.emailAddress: 'email_address',
    TextEntityType.phoneNumber: 'phone_number',
    TextEntityType.bankCardNumber: 'bank_card_number',
    TextEntityType.mediaTimestamp: 'media_timestamp',
    TextEntityType.spoiler: 'spoiler',
    TextEntityType.customEmoji: 'custom_emoji',
  };

  /// Media sent with the name the reader sees on it.
  static const _named = {MediaType.document, MediaType.audio};

  static const _mediaTypes = {
    MediaType.photo: 'photo',
    MediaType.video: 'video',
    // An animation is a silent looping video.
    MediaType.gif: 'video',
    MediaType.document: 'document',
    MediaType.audio: 'audio',
    MediaType.voice: 'voice',
    MediaType.sticker: 'sticker',
  };
}
