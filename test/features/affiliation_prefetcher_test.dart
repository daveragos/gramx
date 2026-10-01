import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/chats/data/affiliation_prefetcher.dart';

import '../support/td_fixtures.dart';

void main() {
  // Only people whose channel is not yet known are worth a request.
  group('AffiliationPrefetcher.userToAskAbout', () {
    final ada = TdFixtures.user(id: 7, firstName: 'Ada');
    final bot = TdFixtures.user(id: 8, firstName: 'Bot', isBot: true);

    test('a person the cache has not met fully is asked about', () {
      final userId = AffiliationPrefetcher.userToAskAbout(
        TdFixtures.privateChat(id: 7),
        users: {7: ada},
        known: const {},
      );
      expect(userId, 7);
    });

    test('a person already known is not asked about again', () {
      final userId = AffiliationPrefetcher.userToAskAbout(
        TdFixtures.privateChat(id: 7),
        users: {7: ada},
        known: {7: TdFixtures.userFullInfo(personalChatId: -100)},
      );
      expect(userId, isNull);
    });

    test('a bot has no channel to run', () {
      final userId = AffiliationPrefetcher.userToAskAbout(
        TdFixtures.privateChat(id: 8),
        users: {8: bot},
        known: const {},
      );
      expect(userId, isNull);
    });

    test('the reader is not asked about themselves', () {
      final userId = AffiliationPrefetcher.userToAskAbout(
        TdFixtures.privateChat(id: 7),
        users: {7: ada},
        known: const {},
        selfUserId: 7,
      );
      expect(userId, isNull);
    });

    test('a group is nobody in particular', () {
      final userId = AffiliationPrefetcher.userToAskAbout(
        TdFixtures.chat(id: -100500, isChannel: false),
        users: {7: ada},
        known: const {},
      );
      expect(userId, isNull);
    });
  });
}
