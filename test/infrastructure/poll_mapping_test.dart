import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/message_content_support.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:handy_tdlib/api.dart' as td;

import '../support/td_fixtures.dart';

Map<String, dynamic> pollContent({
  required bool isClosed,
  bool isQuiz = false,
}) => {
  '@type': 'messagePoll',
  'poll': {
    '@type': 'poll',
    'id': '55',
    'question': {
      '@type': 'formattedText',
      'text': 'Which one?',
      'entities': [],
    },
    'options': [
      {
        '@type': 'pollOption',
        'text': {'@type': 'formattedText', 'text': 'A', 'entities': []},
        'voter_count': 3,
        'vote_percentage': 75,
        'is_chosen': true,
        'is_being_chosen': false,
      },
      {
        '@type': 'pollOption',
        'text': {'@type': 'formattedText', 'text': 'B', 'entities': []},
        'voter_count': 1,
        'vote_percentage': 25,
        'is_chosen': false,
        'is_being_chosen': false,
      },
    ],
    'total_voter_count': 4,
    'recent_voter_ids': [
      {'@type': 'messageSenderUser', 'user_id': 9},
    ],
    'is_anonymous': false,
    'type': isQuiz
        ? {
            '@type': 'pollTypeQuiz',
            'correct_option_id': 0,
            'explanation': {
              '@type': 'formattedText',
              'text': 'because',
              'entities': [],
            },
          }
        : {'@type': 'pollTypeRegular', 'allow_multiple_answers': false},
    'open_period': 60,
    'close_date': 1700000060,
    'is_closed': isClosed,
  },
};

td.Message pollMessage({required bool isClosed, bool isQuiz = false}) {
  final json = TdFixtures.textMessageJson(id: 100, chatId: -1001);
  json['content'] = pollContent(isClosed: isClosed, isQuiz: isQuiz);
  return td.Message.fromJson(json);
}

void main() {
  group('polls', () {
    // Polls of every shape map to a poll; an unsupported card means TDLib sent
    // `messageUnsupported`.
    test('a closed poll is a poll, not unsupported content', () {
      final post = TdlibMappers.mapMessageToPost(
        pollMessage(isClosed: true),
        TdFixtures.chat(id: -1001),
      );

      expect(post.poll, isNotNull);
      expect(post.poll!.isClosed, isTrue);
      expect(post.unsupportedKind, isNull);
      expect(post.text, 'Which one?');
    });

    test('a closed quiz keeps its correct answer', () {
      final post = TdlibMappers.mapMessageToPost(
        pollMessage(isClosed: true, isQuiz: true),
        TdFixtures.chat(id: -1001),
      );

      expect(post.poll!.isQuiz, isTrue);
      expect(post.poll!.correctOptionId, 0);
      expect(post.poll!.options.first.isCorrect, isTrue);
    });

    test('votes already cast survive the mapping', () {
      final post = TdlibMappers.mapMessageToPost(
        pollMessage(isClosed: false),
        TdFixtures.chat(id: -1001),
      );

      expect(post.poll!.chosenOptionIds, [0]);
      expect(post.poll!.totalVoterCount, 4);
    });

    test('a poll message is rendered content, so it never gets a label', () {
      final content = pollMessage(isClosed: true).content;
      expect(MessageContentSupport.isRendered(content), isTrue);
      expect(MessageContentSupport.isUnsupported(content), isFalse);
      expect(MessageContentSupport.describe(content), isNull);
    });
  });

  group('content this build cannot draw', () {
    test('is flagged so the card can offer Telegram instead', () {
      final json = TdFixtures.textMessageJson(id: 101, chatId: -1001);
      json['content'] = {'@type': 'messageUnsupported'};

      final post = TdlibMappers.mapMessageToPost(
        td.Message.fromJson(json),
        TdFixtures.chat(id: -1001),
      );

      expect(post.unsupportedKind, 'messageUnsupported');
      expect(post.text, MessageContentSupport.unsupportedLabel);
    });

    // A location is known content, so it gets a label, not the Telegram link.
    test('named-but-undrawn content is labelled, not flagged', () {
      final json = TdFixtures.textMessageJson(id: 102, chatId: -1001);
      json['content'] = {
        '@type': 'messageLocation',
        'location': {
          '@type': 'location',
          'latitude': 1.0,
          'longitude': 2.0,
          'horizontal_accuracy': 0.0,
        },
        'live_period': 0,
        'expires_in': 0,
        'heading': 0,
        'proximity_alert_radius': 0,
      };

      final post = TdlibMappers.mapMessageToPost(
        td.Message.fromJson(json),
        TdFixtures.chat(id: -1001),
      );

      expect(post.unsupportedKind, isNull);
      expect(post.text, '📍 Location');
    });
  });
}
