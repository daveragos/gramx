import 'dart:async';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/trok/data/trok_client.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';

/// Answers without Argus, so Trok's screens can be used before it is
/// connected. It only quotes and groups the reader's own posts, and every
/// answer says that it is a preview.
class PreviewTrokClient implements TrokClient {
  /// The wait between streamed words.
  final Duration pace;

  /// The wait after each step before answering.
  final Duration stepPace;

  const PreviewTrokClient({
    this.pace = const Duration(milliseconds: 24),
    this.stepPace = const Duration(milliseconds: 650),
  });

  @override
  Stream<TrokEvent> ask(TrokRequest request) async* {
    final plan = _plan(request);

    for (final step in plan.steps) {
      yield TrokStep(step);
      await Future<void>.delayed(request.think ? stepPace * 1.6 : stepPace);
    }

    // Word by word, the way a bot's edits arrive.
    final text = plan.text;
    var end = 0;
    while (end < text.length) {
      end = _nextWordEnd(text, end);
      yield TrokText(text.substring(0, end), plan.entities);
      await Future<void>.delayed(pace);
    }

    if (plan.sources.isNotEmpty) {
      yield TrokSources([for (final p in plan.sources) TrokSource.fromPost(p)]);
    }
    if (plan.followUps.isNotEmpty) yield TrokFollowUps(plan.followUps);
  }

  _Plan _plan(TrokRequest request) {
    final post = request.post;
    final plan = post == null
        ? switch (request.prompt) {
            AppStrings.trokStarterCatchUpPrompt => _catchUp(request.feed),
            AppStrings.trokStarterTodayPrompt => _today(request.feed),
            _ => _search(request.prompt, request.feed),
          }
        : switch (request.action) {
            TrokPostAction.summarize => _summarize(post),
            TrokPostAction.translate => _translate(post),
            TrokPostAction.factCheck => _factCheck(post, request.feed),
            // A typed question about a post is explained like one.
            TrokPostAction.explain || null => _explain(post),
          };
    return plan.thinking(request.think);
  }

  _Plan _explain(Post post) {
    final w = _Writer()
      ..bold('What it says')
      ..line()
      ..write(_opening(post, sentences: 2, max: 280))
      ..line(2)
      ..bold('Where it’s from')
      ..line()
      ..write(
        '• ${post.channelTitle}'
        '${AppStrings.inlineSeparator}'
        '${TimeUtils.relativeTime(post.publishedAt)}',
      );
    if (post.viewCount > 0) {
      w
        ..line()
        ..write('• ${TimeUtils.formatCount(post.viewCount)} views');
    }
    if (post.replyCount > 0) {
      w
        ..line()
        ..write('• ${TimeUtils.formatCount(post.replyCount)} comments');
    }
    w
      ..line(2)
      ..italic(_previewNote);
    return _Plan(
      steps: [
        'Reading the post',
        'Looking at what ${post.channelTitle} posted around it',
      ],
      writer: w,
      sources: [post],
      followUps: const [
        'Why does this matter?',
        'What happened before this?',
        'Which other channels cover it?',
      ],
    );
  }

  _Plan _summarize(Post post) => _Plan(
    steps: const ['Reading the post'],
    writer: _Writer()
      ..bold('In short')
      ..line()
      ..write(_opening(post, sentences: 1, max: 200))
      ..line(2)
      ..italic(_previewNote),
    followUps: const ['Explain it simply', 'Is this true?'],
  );

  _Plan _translate(Post post) => _Plan(
    steps: const ['Reading the post', 'Translating'],
    writer: _Writer()
      ..bold('Translation')
      ..line()
      ..italic('Trok will translate posts once Argus is connected.'),
    followUps: const ['Summarize it', 'Explain this post'],
  );

  _Plan _factCheck(Post post, List<Post> feed) {
    final words = _keywords(post.text ?? '');
    final related = _ranked(
      feed.where((p) => p.id != post.id && p.channelId != post.channelId),
      words,
      minShared: 2,
    ).take(3).toList();

    final w = _Writer()
      ..bold('Not checked yet')
      ..line()
      ..write(
        'Once Argus is connected, Trok will compare this post with what other '
        'channels report and say where they agree.',
      );
    if (related.isNotEmpty) {
      w
        ..line(2)
        ..bold('Also in your feed')
        ..line();
      _bullets(w, related);
    }
    return _Plan(
      steps: const [
        'Reading the post',
        'Looking for other channels covering it',
        'Comparing what they say',
      ],
      writer: w,
      sources: related,
      followUps: const ['Who first reported this?', 'Explain this post'],
    );
  }

  _Plan _catchUp(List<Post> feed) {
    final unread = feed.where((p) => !p.isRead).toList();
    if (unread.isEmpty) {
      return _Plan(
        steps: const ['Checking your channels'],
        writer: _Writer()
          ..write("You're all caught up. Nothing in your channels is unread."),
        followUps: const ["What are today's big stories?"],
      );
    }

    // Busiest channels first, each with its newest post.
    final byChannel = <String, List<Post>>{};
    for (final p in unread) {
      (byChannel[p.channelId] ??= []).add(p);
    }
    final groups = byChannel.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final top = groups.take(5).toList();

    final w = _Writer()..bold('Here’s what you missed');
    final newest = <Post>[];
    for (final group in top) {
      group.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final latest = group.firstWhere(
        (p) => (p.text ?? '').trim().isNotEmpty,
        orElse: () => group.first,
      );
      newest.add(latest);
      // One paragraph each: Telegram text has no hanging indent.
      w
        ..line(2)
        ..write('• ')
        ..bold(latest.channelTitle)
        ..write(' (${group.length} new): ${_opening(latest, max: 110)}');
    }
    w
      ..line(2)
      ..italic(
        'Preview: these are your posts as they are. With Argus connected, '
        'Trok will summarize them.',
      );

    return _Plan(
      steps: [
        'Reading ${unread.length} unread posts',
        'Grouping them by channel',
      ],
      writer: w,
      sources: newest,
      followUps: [
        'Tell me more about ${top.first.first.channelTitle}',
        'What’s the most important one?',
        'Anything I should act on?',
      ],
    );
  }

  _Plan _today(List<Post> feed) {
    final now = DateTime.now();
    final today =
        feed
            .where(
              (p) =>
                  p.publishedAt.year == now.year &&
                  p.publishedAt.month == now.month &&
                  p.publishedAt.day == now.day,
            )
            .toList()
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    final top = today.take(4).toList();

    final w = _Writer();
    if (top.isEmpty) {
      w.write('Nothing has been posted in your channels today yet.');
    } else {
      w
        ..bold('Today in your feed')
        ..line();
      _bullets(w, top);
      w
        ..line(2)
        ..italic(
          'Preview: ranked by views. With Argus connected, Trok will tell '
          'you what each story is about.',
        );
    }
    return _Plan(
      steps: const ['Looking at today’s posts', 'Ranking them by views'],
      writer: w,
      sources: top,
      followUps: top.isEmpty
          ? const ['What did I miss in my channels?']
          : const ['Explain the first one', 'What did I miss in my channels?'],
    );
  }

  _Plan _search(String prompt, List<Post> feed) {
    final words = _keywords(prompt);
    final found = _ranked(feed, words, minShared: 1).take(4).toList();

    final w = _Writer();
    if (found.isEmpty) {
      w.write('Nothing in your channels mentions that yet.');
    } else {
      w
        ..bold('What your channels say')
        ..line();
      _bullets(w, found);
    }
    w
      ..line(2)
      ..italic(_previewNote);

    return _Plan(
      steps: [
        'Searching your channels',
        if (found.isNotEmpty)
          found.length == 1
              ? 'Reading 1 post'
              : 'Reading ${found.length} posts',
      ],
      writer: w,
      sources: found,
      followUps: found.isEmpty
          ? const ['What did I miss in my channels?']
          : const ['Tell me more', 'Which channels cover this best?'],
    );
  }

  static const _previewNote =
      'Preview: Trok will write real answers once Argus is connected.';

  static void _bullets(_Writer w, List<Post> posts) {
    for (final (i, p) in posts.indexed) {
      if (i > 0) w.line(2);
      w
        ..write('• ')
        ..bold(p.channelTitle)
        ..write(': ${_opening(p, max: 110)}');
    }
  }
}

/// A preview answer: the steps before it, its text, and what goes under it.
class _Plan {
  final List<String> steps;
  final _Writer writer;
  final List<Post> sources;
  final List<String> followUps;

  const _Plan({
    required this.steps,
    required this.writer,
    this.sources = const [],
    this.followUps = const [],
  });

  String get text => writer.text;
  List<TextEntity> get entities => writer.entities;

  _Plan thinking(bool think) => think
      ? _Plan(
          steps: [...steps, 'Thinking it through'],
          writer: writer,
          sources: sources,
          followUps: followUps,
        )
      : this;
}

/// Builds formatted text with Telegram's entities, as a bot would send it.
class _Writer {
  final _buffer = StringBuffer();
  final entities = <TextEntity>[];

  String get text => _buffer.toString();

  void write(String s) => _buffer.write(s);

  void line([int count = 1]) => _buffer.write('\n' * count);

  void bold(String s) => _mark(s, TextEntityType.bold);

  void italic(String s) => _mark(s, TextEntityType.italic);

  void _mark(String s, TextEntityType type) {
    entities.add(
      TextEntity(offset: _buffer.length, length: s.length, type: type),
    );
    _buffer.write(s);
  }
}

/// The end of the next word after [from]: the following space or line break,
/// or the end of [text].
int _nextWordEnd(String text, int from) {
  var i = from + 1;
  while (i < text.length && text[i] != ' ' && text[i] != '\n') {
    i++;
  }
  return i;
}

/// A post's first [sentences] on one line, cut to [max] at a word.
String _opening(Post post, {int sentences = 1, int max = 140}) {
  final flat = (post.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return 'A post with no text, only media.';

  // Amharic ends sentences with ።
  final parts = flat.split(RegExp(r'(?<=[.!?።])\s+'));
  final lead = parts.take(sentences).join(' ');
  if (lead.length <= max) return lead;

  var cut = lead.lastIndexOf(' ', max);
  if (cut < max ~/ 2) cut = max;
  // Never between the halves of an emoji.
  final unit = lead.codeUnitAt(cut - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF) cut--;
  return '${lead.substring(0, cut).trimRight()}…';
}

const _stopWords = {
  'about',
  'after',
  'again',
  'also',
  'any',
  'because',
  'been',
  'before',
  'being',
  'channel',
  'channels',
  'could',
  'does',
  'explain',
  'feed',
  'from',
  'have',
  'here',
  'into',
  'just',
  'like',
  'more',
  'news',
  'only',
  'other',
  'over',
  'post',
  'posts',
  'really',
  'recommend',
  'should',
  'show',
  'simply',
  'some',
  'such',
  'tell',
  'than',
  'that',
  'their',
  'them',
  'then',
  'there',
  'these',
  'they',
  'this',
  'those',
  'very',
  'were',
  'what',
  'when',
  'where',
  'which',
  'while',
  'will',
  'with',
  'would',
  'your',
};

/// The words worth matching in [text], lowercased: four letters or more in
/// Latin script, three in others, where Ethiopic writes a syllable a letter.
Set<String> _keywords(String text) => {
  for (final m in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(text))
    if (m[0]!.length >= (_latin.hasMatch(m[0]!) ? 4 : 3) &&
        !_stopWords.contains(m[0]!.toLowerCase()))
      m[0]!.toLowerCase(),
};

final _latin = RegExp(r'^[A-Za-z0-9]+$');

/// [posts] sharing at least [minShared] of [words], most shared first.
List<Post> _ranked(
  Iterable<Post> posts,
  Set<String> words, {
  required int minShared,
}) {
  if (words.isEmpty) return const [];
  final scored = <(Post, int)>[];
  for (final p in posts) {
    final shared = _keywords(p.text ?? '').intersection(words).length;
    if (shared >= minShared) scored.add((p, shared));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (p, _) in scored) p];
}
