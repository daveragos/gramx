import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';

void main() {
  group('serverMessageId', () {
    // TDLib shifts server ids left by 20 bits. Sharing the raw value produced a
    // link with a message number in the billions, which Telegram cannot resolve.
    test('undoes TDLib\'s 20-bit shift', () {
      expect(TelegramIds.serverMessageId(1 << 20), 1);
      expect(TelegramIds.serverMessageId(42 << 20), 42);
      expect(TelegramIds.serverMessageId(123456 << 20), 123456);
    });

    test('ignores the low bits TDLib reserves', () {
      expect(TelegramIds.serverMessageId((42 << 20) + 7), 42);
    });
  });

  group('supergroupId', () {
    test('strips the -100 chat prefix', () {
      expect(TelegramIds.supergroupId(-1001234567890), 1234567890);
      expect(TelegramIds.supergroupId(-1001), 1);
    });

    test('passes a bare supergroup id through', () {
      expect(TelegramIds.supergroupId(1234567890), 1234567890);
    });

    test('returns null for chat ids that are not supergroups', () {
      expect(TelegramIds.supergroupId(-4567), isNull);
    });
  });

  group('postLink', () {
    test('prefers a public username link', () {
      expect(
        TelegramIds.postLink(
          chatId: -1001234567890,
          messageId: 42 << 20,
          username: 'durov',
        ),
        'https://t.me/durov/42',
      );
    });

    test('tolerates a username written with @', () {
      expect(
        TelegramIds.postLink(
          chatId: -1001234567890,
          messageId: 42 << 20,
          username: '@durov',
        ),
        'https://t.me/durov/42',
      );
    });

    test('falls back to the private c/ form without a username', () {
      expect(
        TelegramIds.postLink(chatId: -1001234567890, messageId: 42 << 20),
        'https://t.me/c/1234567890/42',
      );
    });

    // The exact bug this replaced: the -100 prefix was left on and the message
    // id was never shifted back, so every shared link was dead.
    test('never emits the raw chat id or the shifted message id', () {
      final link = TelegramIds.postLink(
        chatId: -1001234567890,
        messageId: 42 << 20,
      )!;

      expect(link, isNot(contains('-100')));
      expect(link, isNot(contains('44040192')));
    });

    test('treats a blank username as absent', () {
      expect(
        TelegramIds.postLink(
          chatId: -1001234567890,
          messageId: 42 << 20,
          username: '   ',
        ),
        'https://t.me/c/1234567890/42',
      );
    });

    test('returns null when no valid link exists', () {
      expect(
        TelegramIds.postLink(chatId: -4567, messageId: 42 << 20),
        isNull,
        reason: 'a basic group has no linkable form',
      );
      expect(
        TelegramIds.postLink(chatId: -1001234567890, messageId: 0),
        isNull,
        reason: 'message id 0 is not a real post',
      );
    });
  });
}
