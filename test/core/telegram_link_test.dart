import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/core/navigation/telegram_link.dart';

TelegramLink? parse(String url) => TelegramLinks.parse(Uri.parse(url));

void main() {
  group('a channel link', () {
    test('is a bare username', () {
      expect(parse('https://t.me/ragoose_dumps'), TelegramChannelLink('ragoose_dumps'));
    });

    test('is the same on every host Telegram serves', () {
      for (final host in ['t.me', 'telegram.me', 'telegram.dog', 'www.t.me']) {
        expect(
          parse('https://$host/ragoose_dumps'),
          TelegramChannelLink('ragoose_dumps'),
          reason: host,
        );
      }
    });

    // `t.me/s/name` is the web preview page — the one guest mode reads. It
    // names the same channel, so it opens the same screen.
    test('a preview link names the same channel', () {
      expect(parse('https://t.me/s/ragoose_dumps'), TelegramChannelLink('ragoose_dumps'));
    });

    test('a trailing slash changes nothing', () {
      expect(parse('https://t.me/ragoose_dumps/'), TelegramChannelLink('ragoose_dumps'));
    });
  });

  group('a post link', () {
    test('carries the number in the link', () {
      expect(parse('https://t.me/ragoose_dumps/11123'),
          TelegramPostLink('ragoose_dumps', 11123));
    });

    // TDLib shifts a server id left by 20 bits so it can address parts of a
    // message. A link carries the unshifted number, so it has to be converted
    // before anything in this app can look it up.
    test('the number is shifted into a TDLib message id', () {
      final link = parse('https://t.me/ragoose_dumps/42') as TelegramPostLink;
      expect(link.tdlibMessageId, 42 << 20);
    });

    // A forum link carries the topic first. gramX has no topics (T13-12), and
    // the post still opens — which beats refusing the link.
    test('a forum link opens the post and ignores the topic', () {
      expect(parse('https://t.me/ragoose_dumps/7/11123'),
          TelegramPostLink('ragoose_dumps', 11123));
    });
  });

  group('a private post link', () {
    test('addresses the channel by its supergroup id', () {
      final link =
          parse('https://t.me/c/1234567890/42') as TelegramPrivatePostLink;

      expect(link.supergroupId, 1234567890);
      expect(link.serverMessageId, 42);
    });

    // TDLib puts a -100 in front of a supergroup id to make a chat id, and
    // every lookup in this app is by chat id.
    test('the chat id carries the -100 prefix', () {
      final link =
          parse('https://t.me/c/1234567890/42') as TelegramPrivatePostLink;

      expect(link.chatId, -1001234567890);
    });

    test('a topic id between the two is skipped', () {
      final link =
          parse('https://t.me/c/1234567890/7/42') as TelegramPrivatePostLink;

      expect(link.serverMessageId, 42);
    });

    test('a private channel with no message is not a post', () {
      expect(parse('https://t.me/c/1234567890'), isNull);
    });
  });

  group('an invite link', () {
    test('both shapes carry the hash', () {
      expect(parse('https://t.me/+AbCdEfGh'), TelegramInviteLink('AbCdEfGh'));
      expect(
        parse('https://t.me/joinchat/AbCdEfGh'),
        TelegramInviteLink('AbCdEfGh'),
      );
    });

    // `t.me/+15551234567` is a contact link — somebody to add, not a place to
    // go. Treating it as an invite would send a phone number to the server as
    // an invite hash.
    test('a phone number is not an invite', () {
      expect(parse('https://t.me/+15551234567'), isNull);
    });
  });

  group('the tg:// scheme', () {
    test('resolve names a channel, or a post in it', () {
      expect(parse('tg://resolve?domain=ragoose_dumps'),
          TelegramChannelLink('ragoose_dumps'));
      expect(parse('tg://resolve?domain=ragoose_dumps&post=42'),
          TelegramPostLink('ragoose_dumps', 42));
    });

    test('privatepost carries both numbers', () {
      expect(parse('tg://privatepost?channel=123&post=42'),
          TelegramPrivatePostLink(123, 42));
    });

    test('join carries the invite', () {
      expect(parse('tg://join?invite=AbCdEf'), TelegramInviteLink('AbCdEf'));
    });
  });

  group('links this app does not open', () {
    // Telegram reserves these words, and gramX implements none of them.
    // Reading one as a username would send somebody to a channel that does
    // not exist; unparsed means the link goes back to Telegram, which can.
    test('a reserved word is not a username', () {
      for (final word in ['addstickers', 'proxy', 'login', 'share', 'bg']) {
        expect(parse('https://t.me/$word/whatever'), isNull, reason: word);
      }
    });

    test('a number is not a channel called that number', () {
      expect(parse('https://t.me/1234'), isNull);
    });

    test('a username too short for Telegram is refused', () {
      expect(parse('https://t.me/ab'), isNull);
    });

    test('another site is not a Telegram link', () {
      expect(parse('https://example.com/ragoose_dumps'), isNull);
      expect(parse('https://tme.example.com/ragoose_dumps'), isNull);
    });

    test('a bare host names nothing', () {
      expect(parse('https://t.me'), isNull);
      expect(parse('https://t.me/'), isNull);
    });

    test('an unknown scheme is left alone', () {
      expect(parse('mailto:someone@example.com'), isNull);
      expect(parse('tg://unknownthing?x=1'), isNull);
    });
  });

  group('DeepLinkRoutes', () {
    test('a post link needs its username resolved first', () {
      expect(
        DeepLinkRoutes.usernameToResolve(TelegramPostLink('durov', 1)),
        'durov',
      );
      expect(
        DeepLinkRoutes.usernameToResolve(TelegramChannelLink('durov')),
        'durov',
      );
    });

    // A private post carries its own chat id, so it opens without a request.
    test('a private post needs nothing resolved', () {
      expect(
        DeepLinkRoutes.usernameToResolve(TelegramPrivatePostLink(1, 2)),
        isNull,
      );
    });

    test('a resolved channel opens the channel screen', () {
      expect(
        DeepLinkRoutes.routeFor(TelegramChannelLink('durov'), chatId: -100777),
        '/channel/-100777',
      );
    });

    test('a resolved post opens the post screen', () {
      expect(
        DeepLinkRoutes.routeFor(TelegramPostLink('durov', 3), chatId: -100777),
        '/post/-100777_${3 << 20}',
      );
    });

    test('a private post opens without a resolved id', () {
      expect(
        DeepLinkRoutes.routeFor(TelegramPrivatePostLink(777, 3)),
        '/post/-100777_${3 << 20}',
      );
    });

    // Nothing in gramX joins a private chat, and an unresolvable name has no
    // screen either. Both go back to Telegram rather than nowhere.
    test('an invite, and an unresolved name, have no route here', () {
      expect(DeepLinkRoutes.routeFor(TelegramInviteLink('x')), isNull);
      expect(DeepLinkRoutes.routeFor(TelegramChannelLink('durov')), isNull);
      expect(DeepLinkRoutes.routeFor(TelegramPostLink('durov', 1)), isNull);
    });
  });

  // A link the app renders has to be one the app can read back. Anything else
  // and "Copy link" produces something gramX itself would hand to Telegram.
  group('round trip with the links this app writes', () {
    test('a public post link parses back to the same post', () {
      final link = parse('https://t.me/ragoose_dumps/11123') as TelegramPostLink;
      expect(link.username, 'ragoose_dumps');
      expect(link.serverMessageId, 11123);
    });

    test('a private post link parses back to the same chat', () {
      final link =
          parse('https://t.me/c/1234567890/11123') as TelegramPrivatePostLink;
      expect(link.chatId, -1001234567890);
    });
  });
}
