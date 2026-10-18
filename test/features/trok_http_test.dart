import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/trok/data/http_trok_client.dart';
import 'package:gramx/features/trok/data/sse_decoder.dart';
import 'package:gramx/features/trok/data/trok_credentials.dart';
import 'package:gramx/features/trok/data/trok_markdown.dart';
import 'package:gramx/features/trok/data/trok_wire.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';

const _channelId = -1001234567890;

Post post(
  int number, {
  String text = 'A post.',
  String? username = 'durov',
  bool read = false,
}) => Post(
  id: '${_channelId}_${number << 20}',
  chatId: _channelId,
  channelId: '$_channelId',
  messageId: number << 20,
  channelTitle: 'Durov',
  channelUsername: username,
  text: text,
  isRead: read,
  publishedAt: DateTime.utc(2026, 10, 16, 21, 58),
);

class _Credentials implements TrokCredentials {
  var fetched = 0;
  var invalidated = 0;
  String? _held;

  @override
  Future<String> initData() async =>
      _held ??= 'query_id=AAH&user=%7B%22id%22%3A1%7D&hash=h${++fetched}';

  @override
  void invalidate() {
    invalidated++;
    _held = null;
  }
}

String sse(List<(String, Object?)> events) => [
  for (final (name, data) in events)
    'event: $name\ndata: ${jsonEncode(data)}\n\n',
].join();

/// The events of a whole answer, as Trok sends them.
List<(String, Object?)> answer({
  String text = '**Partly true.** See [the post](ref:p1).',
}) => [
  (
    'conversation',
    {'conversation_id': 'c_1', 'answer_id': 'a_1', 'title': 'Is this true?'},
  ),
  ('step', {'text': 'Reading the post'}),
  ('step', {'text': 'Searching the web'}),
  ('delta', {'text': '**Partly'}),
  ('delta', {'text': ' true.** See'}),
  (
    'sources',
    {
      'items': [
        {'type': 'post', 'ref': 'p1'},
        {
          'type': 'web',
          'url': 'https://example.com/report',
          'title': 'Shipping delays',
          'site': 'example.com',
        },
      ],
    },
  ),
  (
    'follow_ups',
    {
      'items': ['Who first reported this?'],
    },
  ),
  ('done', {'answer_id': 'a_1', 'text': text, 'finish': 'complete'}),
];

http.StreamedResponse streamed(String body, [int status = 200]) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': 'text/event-stream'},
    );

http.StreamedResponse json(Object? body, int status) => http.StreamedResponse(
  Stream.value(body == null ? <int>[] : utf8.encode(jsonEncode(body))),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('HttpTrokClient.ask', () {
    late _Credentials credentials;
    late List<http.BaseRequest> requests;
    late List<Map<String, dynamic>> bodies;

    HttpTrokClient clientWith(
      List<FutureOr<http.StreamedResponse> Function()> responses, {
      Duration silence = const Duration(seconds: 5),
    }) {
      var i = 0;
      return HttpTrokClient(
        credentials: credentials,
        base: 'https://trok.test/v1',
        deviceLanguage: () => 'en',
        silence: silence,
        reconnectDelay: Duration.zero,
        client: MockClient.streaming((request, body) async {
          requests.add(request);
          final text = await body.bytesToString();
          if (text.isNotEmpty) {
            bodies.add(jsonDecode(text) as Map<String, dynamic>);
          }
          return responses[i++]();
        }),
      );
    }

    setUp(() {
      credentials = _Credentials();
      requests = [];
      bodies = [];
    });

    final subject = post(42, text: 'Laptops are at the US office.');
    final factCheck = TrokRequest(
      prompt: AppStrings.trokPostFactCheck,
      post: subject,
      action: TrokPostAction.factCheck,
      feed: [subject, post(43), post(44, read: true)],
    );

    test('streams an answer and ends with the cleaned text', () async {
      final client = clientWith([() => streamed(sse(answer()))]);
      final events = await client.ask(factCheck).toList();

      final started = events.whereType<TrokStarted>().single;
      expect(started.conversationId, 'c_1');
      expect(started.answerId, 'a_1');
      expect(events.whereType<TrokStep>().map((s) => s.label), [
        'Reading the post',
        'Searching the web',
      ]);

      final texts = events.whereType<TrokText>().toList();
      expect(texts.first.text, 'Partly');
      expect(texts.first.entities.single.type, TextEntityType.bold);
      final last = texts.last;
      expect(last.text, 'Partly true. See the post.');
      final link = last.entities.firstWhere(
        (e) => e.type == TextEntityType.textUrl,
      );
      expect(link.url, 'https://t.me/durov/42');
      expect(
        last.text.substring(link.offset, link.offset + link.length),
        'the post',
      );

      final sources = events.whereType<TrokSources>().single.sources;
      expect((sources[0] as TrokPostSource).postId, subject.id);
      expect((sources[1] as TrokWebSource).site, 'example.com');
      expect(events.whereType<TrokFollowUps>().single.followUps, [
        'Who first reported this?',
      ]);
    });

    test('sends the post, the feed and the sign-in as agreed', () async {
      final client = clientWith([() => streamed(sse(answer()))]);
      await client.ask(factCheck).drain<void>();

      final request = requests.single;
      expect(request.url.toString(), 'https://trok.test/v1/ask');
      expect(request.headers['Authorization'], startsWith('tma query_id='));
      expect(request.headers['Accept'], 'text/event-stream');
      final body = bodies.single;
      expect(request.headers['Idempotency-Key'], body['question_id']);
      expect(body['question_id'], matches(RegExp(r'^[A-Za-z0-9_-]{1,80}$')));
      expect(body['conversation_id'], isNull);
      expect(body['action'], 'fact_check');
      expect(body['language'], 'en');
      expect(body['translate_to'], isNull);

      final sent = body['post'] as Map<String, dynamic>;
      expect(sent['ref'], 'p1');
      expect(sent['message_id'], 42);
      expect(sent['link'], 'https://t.me/durov/42');
      expect(sent['channel'], {
        'title': 'Durov',
        'username': 'durov',
        'verified': false,
      });
      expect(sent['date'], '2026-10-16T21:58:00.000Z');
      expect(sent['unread'], isTrue);

      // The post asked about isn't sent twice.
      final feed = (body['feed'] as List).cast<Map<String, dynamic>>();
      expect(feed.map((p) => p['ref']), ['p2', 'p3']);
      expect(feed.last['unread'], isFalse);
    });

    test('a follow-up names the conversation and sends no feed', () async {
      final client = clientWith([
        () => streamed(sse(answer())),
        () => streamed(sse(answer(text: 'More.'))),
      ]);
      await client.ask(factCheck).drain<void>();
      await client
          .ask(
            TrokRequest(
              prompt: 'Why?',
              post: subject,
              feed: factCheck.feed,
              conversationId: 'c_1',
            ),
          )
          .drain<void>();

      final body = bodies.last;
      expect(body['conversation_id'], 'c_1');
      expect(body['action'], 'ask');
      expect((body['post'] as Map)['ref'], 'p1');
      expect(body['feed'], isEmpty);
      expect(body['question_id'], isNot(bodies.first['question_id']));
    });

    test('starters are sent as their actions', () async {
      final client = clientWith([
        () => streamed(sse(answer())),
        () => streamed(sse(answer())),
      ]);
      await client
          .ask(const TrokRequest(prompt: AppStrings.trokStarterCatchUpPrompt))
          .drain<void>();
      await client
          .ask(const TrokRequest(prompt: AppStrings.trokStarterTodayPrompt))
          .drain<void>();
      expect(bodies.map((b) => b['action']), ['catch_up', 'today']);
    });

    test('expired sign-in is fetched again, once', () async {
      final client = clientWith([
        () => json({
          'error': {
            'code': 'auth_expired',
            'message': 'Old',
            'retry_after': null,
          },
        }, 401),
        () => streamed(sse(answer())),
      ]);
      final events = await client.ask(factCheck).toList();
      expect(events.whereType<TrokText>(), isNotEmpty);
      expect(credentials.invalidated, 1);
      expect(requests[0].headers['Authorization'], endsWith('hash=h1'));
      expect(requests[1].headers['Authorization'], endsWith('hash=h2'));
      // A retry is the same question.
      expect(bodies[0]['question_id'], bodies[1]['question_id']);
    });

    test('an empty 404 means Trok is switched off', () async {
      final client = clientWith([() => json(null, 404)]);
      await expectLater(
        client.ask(factCheck),
        emitsError(
          isA<TrokFailure>()
              .having((f) => f.code, 'code', 'off')
              .having((f) => f.message, 'message', AppStrings.trokUnavailable),
        ),
      );
    });

    test('the daily limit fails with Trok\'s own words', () async {
      final client = clientWith([
        () => json({
          'error': {
            'code': 'rate_limited',
            'message': 'Trok is back at midnight.',
            'retry_after': 7200,
          },
        }, 429),
      ]);
      await expectLater(
        client.ask(factCheck),
        emitsError(
          isA<TrokFailure>()
              .having((f) => f.message, 'message', 'Trok is back at midnight.')
              .having((f) => f.retryAfter, 'retryAfter', Duration(hours: 2))
              .having((f) => f.canRetry, 'canRetry', isFalse),
        ),
      );
    });

    test('an error event after text keeps the text and fails', () async {
      final client = clientWith([
        () => streamed(
          sse([
            answer().first,
            ('delta', {'text': 'Half'}),
            (
              'error',
              {
                'code': 'unavailable',
                'message': 'Trok is busy.',
                'retry_after': 10,
              },
            ),
          ]),
        ),
      ]);
      final events = <TrokEvent>[];
      final failed = Completer<Object>();
      client
          .ask(factCheck)
          .listen(events.add, onError: (Object e) => failed.complete(e));
      final error = await failed.future as TrokFailure;
      expect(events.whereType<TrokText>().last.text, 'Half');
      expect(error.message, 'Trok is busy.');
      expect(error.canRetry, isTrue);
    });

    test('a dropped connection rejoins the same answer', () async {
      final events = answer();
      final client = clientWith([
        // Cut off after the steps and the first delta.
        () => streamed(sse(events.sublist(0, 4))),
        () => streamed(sse(events)),
      ]);
      final got = await client.ask(factCheck).toList();

      expect(bodies[0]['question_id'], bodies[1]['question_id']);
      expect(got.whereType<TrokStarted>(), hasLength(1));
      expect(got.whereType<TrokStep>(), hasLength(2));
      expect(got.whereType<TrokText>().last.text, 'Partly true. See the post.');
    });

    test('silence counts as a dropped connection', () async {
      final quiet = StreamController<List<int>>();
      addTearDown(quiet.close);
      final client = clientWith([
        () {
          quiet.add(utf8.encode(sse([answer().first])));
          return http.StreamedResponse(quiet.stream, 200);
        },
        () => streamed(sse(answer())),
      ], silence: const Duration(milliseconds: 50));
      final got = await client.ask(factCheck).toList();
      expect(requests, hasLength(2));
      expect(got.whereType<TrokText>().last.text, 'Partly true. See the post.');
    });

    test('too large a body is sent again with half the feed', () async {
      final client = clientWith([
        () => json({
          'error': {'code': 'too_large', 'message': 'Too big.'},
        }, 413),
        () => streamed(sse(answer())),
      ]);
      await client.ask(factCheck).drain<void>();
      expect((bodies[0]['feed'] as List), hasLength(2));
      expect((bodies[1]['feed'] as List), hasLength(1));
    });

    test('a conversation Trok no longer has starts again', () async {
      final client = clientWith([
        () => json({
          'error': {'code': 'not_found', 'message': 'Unknown.'},
        }, 404),
        () => streamed(sse(answer())),
      ]);
      await client
          .ask(
            TrokRequest(
              prompt: 'Why?',
              post: subject,
              feed: factCheck.feed,
              conversationId: 'c_gone',
            ),
          )
          .drain<void>();
      expect(bodies[0]['conversation_id'], 'c_gone');
      expect(bodies[1]['conversation_id'], isNull);
      expect(bodies[1]['feed'], isNotEmpty);
    });

    test('stopping closes the connection', () async {
      var closed = false;
      final body = StreamController<List<int>>(onCancel: () => closed = true);
      final client = clientWith([
        () {
          body.add(utf8.encode(sse([answer().first])));
          return http.StreamedResponse(body.stream, 200);
        },
      ]);
      final started = Completer<void>();
      final subscription = client.ask(factCheck).listen((e) {
        if (e is TrokStarted) started.complete();
      });
      await started.future;
      await subscription.cancel();
      await pumpEventQueue();
      expect(closed, isTrue);
    });

    test('translating chooses the language the post is not in', () async {
      final client = clientWith([
        for (var i = 0; i < 4; i++) () => streamed(sse(answer())),
      ]);
      for (final text in [
        'ዝናብ ነገ ይጠበቃል።',
        'Rain is expected in the north of the country tomorrow.',
        'سقوط سهام هوش مصنوعی آمریکایی',
        'Roobni boru ni eegama.',
      ]) {
        await client
            .ask(
              TrokRequest(
                prompt: AppStrings.trokPostTranslatePrompt,
                post: post(7, text: text),
                action: TrokPostAction.translate,
              ),
            )
            .drain<void>();
      }
      expect(bodies.map((b) => b['translate_to']), ['en', 'am', 'en', 'en']);
    });
  });

  group('HttpTrokClient history', () {
    HttpTrokClient clientReturning(Object? body, [int status = 200]) =>
        HttpTrokClient(
          credentials: _Credentials(),
          base: 'https://trok.test/v1',
          client: MockClient.streaming(
            (request, _) async => json(body, status),
          ),
        );

    test('a conversation comes back with its messages', () async {
      final client = clientReturning({
        'id': 'c_1',
        'title': 'Is this true? · Durov',
        'updated_at': '2026-10-17T00:24:42+00:00',
        'post': {...TrokWire.post(post(42), 'p1')},
        'messages': [
          {
            'role': 'user',
            'id': 'q_1',
            'text': 'Is this true?',
            'action': 'fact_check',
            'created_at': '2026-10-17T00:24:30+00:00',
          },
          {
            'role': 'trok',
            'id': 'a_1',
            'text': '**False.** See [this](ref:p9).',
            'steps': ['Reading the post'],
            'thought_ms': 1800,
            'sources': [
              {
                'type': 'post',
                'ref': 'p9',
                'link': 'https://t.me/other/77',
                'title': 'Other',
                'snippet': 'Not delayed.',
                'date': '2026-10-16T18:40:00Z',
              },
            ],
            'follow_ups': ['Why?'],
            'finish': 'stopped',
            'created_at': '2026-10-17T00:24:42+00:00',
          },
        ],
      });
      final conversation = await client.conversation('c_1');

      expect(conversation.remoteId, 'c_1');
      expect(conversation.isLoaded, isTrue);
      final question = conversation.turns[0] as TrokQuestion;
      expect(question.action, TrokPostAction.factCheck);
      expect(question.post!.id, post(42).id);

      final answer = conversation.turns[1] as TrokAnswer;
      expect(answer.remoteId, 'a_1');
      expect(answer.state, TrokAnswerState.stopped);
      expect(answer.text, 'False. See this.');
      expect(
        answer.entities.firstWhere((e) => e.type == TextEntityType.textUrl).url,
        'https://t.me/other/77',
      );
      expect(answer.thoughtFor, const Duration(milliseconds: 1800));
      final source = answer.sources.single as TrokPostSource;
      expect(source.postId, isNull);
      expect(source.link, 'https://t.me/other/77');
      expect(source.channelTitle, 'Other');
    });

    test('the list holds summaries to fetch later', () async {
      final client = clientReturning({
        'items': [
          {
            'id': 'c_2',
            'title': 'Catch me up',
            'updated_at': '2026-10-17T00:24:42+00:00',
          },
        ],
        'next_cursor': null,
      });
      final listed = await client.conversations();
      expect(listed.single.remoteId, 'c_2');
      expect(listed.single.isLoaded, isFalse);
    });

    test('the allowance says what is left and what is on', () async {
      final client = clientReturning({
        'user_id': 1,
        'plan': 'free',
        'limits': {
          'questions_per_day': 30,
          'used_today': 27,
          'resets_at': '2026-10-18T00:00:00+00:00',
        },
        'features': {'think': false, 'translate': true, 'web_search': true},
      });
      final allowance = await client.allowance();
      expect(allowance.questionsLeft, 3);
      expect(allowance.think, isFalse);
      expect(allowance.translate, isTrue);
    });

    test('a blocked reader gets Trok\'s message', () async {
      final client = clientReturning({
        'error': {'code': 'blocked', 'message': 'Not for this account.'},
      }, 403);
      await expectLater(
        client.allowance(),
        throwsA(isA<TrokFailure>().having((f) => f.isBlocked, 'blocked', true)),
      );
    });
  });

  group('TrokMarkdown', () {
    (String, List<TextEntity>) format(String md, {bool partial = false}) =>
        TrokMarkdown.format(md, partial: partial);

    String marked((String, List<TextEntity>) formatted, TextEntityType type) {
      final (text, entities) = formatted;
      final e = entities.firstWhere((e) => e.type == type);
      return text.substring(e.offset, e.offset + e.length);
    }

    test('bold, italic and code', () {
      final f = format('A **big** and *small* `x = 1` day.');
      expect(f.$1, 'A big and small x = 1 day.');
      expect(marked(f, TextEntityType.bold), 'big');
      expect(marked(f, TextEntityType.italic), 'small');
      expect(marked(f, TextEntityType.code), 'x = 1');
    });

    test('headings become bold lines and bullets dots', () {
      final f = format('## Today\n\n- One\n- Two\n\n1. First');
      expect(f.$1, 'Today\n\n• One\n• Two\n\n1. First');
      expect(marked(f, TextEntityType.bold), 'Today');
    });

    test('a link inside bold text is a link, not both', () {
      final f = format('**See [Reuters](https://r.example/a) now**');
      expect(f.$1, 'See Reuters now');
      final types = f.$2.map((e) => e.type).toList();
      expect(types, [
        TextEntityType.bold,
        TextEntityType.textUrl,
        TextEntityType.bold,
      ]);
      for (var i = 1; i < f.$2.length; i++) {
        expect(
          f.$2[i].offset,
          greaterThanOrEqualTo(f.$2[i - 1].offset + f.$2[i - 1].length),
        );
      }
    });

    test('a link Trok can\'t open stays as words', () {
      final f = format('Per [p7](ref:p7) and [x](javascript:alert(1)).');
      expect(f.$1, 'Per p7 and x.');
      expect(f.$2, isEmpty);
    });

    test('fenced code keeps its language', () {
      final (text, entities) = format('Run:\n```dart\nprint(1);\n```\nDone.');
      expect(text, 'Run:\nprint(1);\nDone.');
      expect(entities.single.type, TextEntityType.codeBlock);
      expect(entities.single.language, 'dart');
    });

    test('snake_case is not italic', () {
      expect(format('use snake_case_names here').$2, isEmpty);
    });

    test('bare links are links, without the full stop after them', () {
      final f = format('Read https://example.com/a.');
      expect(marked(f, TextEntityType.url), 'https://example.com/a');
    });

    test('while arriving, open marks apply to the rest', () {
      final bold = format('It is **partly tr', partial: true);
      expect(bold.$1, 'It is partly tr');
      expect(marked(bold, TextEntityType.bold), 'partly tr');

      expect(format('Two **', partial: true).$1, 'Two ');
      expect(format('See [the po', partial: true).$1, 'See the po');
      expect(
        format('See [the post](https://t.me/du', partial: true).$1,
        'See the post',
      );
    });

    test('when finished, an open mark shows as typed', () {
      expect(format('5 * 3 = 15').$1, '5 * 3 = 15');
      expect(format('A **lone mark').$1, 'A **lone mark');
    });

    test('entities stay inside the text with emoji around', () {
      final (text, entities) = format('🔥 **Hot** take 🔥');
      expect(text, '🔥 Hot take 🔥');
      final e = entities.single;
      expect(text.substring(e.offset, e.offset + e.length), 'Hot');
    });
  });

  group('SseDecoder', () {
    test('reads events and ignores pings', () {
      final decoder = SseDecoder();
      final events = [
        for (final line in [
          ': ping',
          'event: step',
          'data: {"text":"Reading"}',
          '',
          '',
          'data: one',
          'data: two',
          '',
        ])
          ?decoder.add(line),
      ];
      expect(events.map((e) => e.event), ['step', 'message']);
      expect(events.first.data, '{"text":"Reading"}');
      expect(events.last.data, 'one\ntwo');
    });
  });

  group('TdlibTrokCredentials.initDataFromUrl', () {
    test('takes tgWebAppData from the fragment, decoded once', () {
      const initData =
          'query_id=AAH&user=%7B%22id%22%3A1%7D&auth_date=1792188000'
          '&signature=abc&hash=9f86';
      final url =
          'https://trok.example/app#tgWebAppData='
          '${Uri.encodeComponent(initData)}&tgWebAppVersion=8.0';
      expect(TdlibTrokCredentials.initDataFromUrl(url), initData);
    });

    test('is null without it', () {
      expect(
        TdlibTrokCredentials.initDataFromUrl('https://trok.example/app'),
        isNull,
      );
    });
  });

  group('TrokWire.post', () {
    test('a private channel\'s post has no link', () {
      expect(TrokWire.post(post(5, username: null), 'p1')['link'], isNull);
    });

    test('long text is cut and its entities with it', () {
      final long = post(5, text: 'a' * 5000).copyWith(
        entities: const [
          TextEntity(offset: 4090, length: 20, type: TextEntityType.bold),
          TextEntity(offset: 4500, length: 5, type: TextEntityType.italic),
        ],
      );
      final sent = TrokWire.post(long, 'p1');
      expect(sent['text'], hasLength(4096));
      expect(sent['entities'], [
        {'type': 'bold', 'offset': 4090, 'length': 6},
      ]);
    });
  });
}
