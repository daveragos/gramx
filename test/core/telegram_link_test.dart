import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/core/navigation/telegram_link.dart';

TelegramLink? parse(String url) => TelegramLinks.parse(Uri.parse(url));

void main() {
  group('a channel link', () {
    test('is a bare username', () {
      expect(
        parse('https://t.me/ragoose_dumps'),
        TelegramChannelLink('ragoose_dumps'),
      );
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

    // `t.me/s/name` is the web preview page for the same channel.
    test('a preview link names the same channel', () {
      expect(
        parse('https://t.me/s/ragoose_dumps'),
        TelegramChannelLink('ragoose_dumps'),
      );
    });

    test('a trailing slash changes nothing', () {
      expect(
        parse('https://t.me/ragoose_dumps/'),
        TelegramChannelLink('ragoose_dumps'),
      );
    });
  });

  group('a post link', () {
    test('carries the number in the link', () {
      expect(
        parse('https://t.me/ragoose_dumps/11123'),
        TelegramPostLink('ragoose_dumps', 11123),
      );
    });

    // Links carry server ids; TDLib message ids are shifted left by 20 bits.
    test('the number is shifted into a TDLib message id', () {
      final link = parse('https://t.me/ragoose_dumps/42') as TelegramPostLink;
      expect(link.tdlibMessageId, 42 << 20);
    });

    // A forum link carries the topic first; gramX has no topics.
    test('a forum link opens the post and ignores the topic', () {
      expect(
        parse('https://t.me/ragoose_dumps/7/11123'),
        TelegramPostLink('ragoose_dumps', 11123),
      );
    });
  });

  group('a private post link', () {
    test('addresses the channel by its supergroup id', () {
      final link =
          parse('https://t.me/c/1234567890/42') as TelegramPrivatePostLink;

      expect(link.supergroupId, 1234567890);
      expect(link.serverMessageId, 42);
    });

    // TDLib chat ids for supergroups are the id with a -100 prefix.
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

    test('a private channel with no message is a channel, not nothing', () {
      expect(
        parse('https://t.me/c/1234567890'),
        const TelegramPrivateChannelLink(1234567890),
      );
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

    // `t.me/+15551234567` is a contact link, not an invite hash.
    test('a phone number is not an invite', () {
      expect(parse('https://t.me/+15551234567'), isNull);
    });
  });

  group('the tg:// scheme', () {
    test('resolve names a channel, or a post in it', () {
      expect(
        parse('tg://resolve?domain=ragoose_dumps'),
        TelegramChannelLink('ragoose_dumps'),
      );
      expect(
        parse('tg://resolve?domain=ragoose_dumps&post=42'),
        TelegramPostLink('ragoose_dumps', 42),
      );
    });

    test('privatepost carries both numbers', () {
      expect(
        parse('tg://privatepost?channel=123&post=42'),
        TelegramPrivatePostLink(123, 42),
      );
    });

    test('join carries the invite', () {
      expect(parse('tg://join?invite=AbCdEf'), TelegramInviteLink('AbCdEf'));
    });
  });

  group('links this app does not open', () {
    // Reserved words gramX doesn't handle; unparsed links go to Telegram.
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

    test('a resolved person opens their profile, and a group its chat', () {
      expect(
        DeepLinkRoutes.routeFor(
          TelegramChannelLink('ada'),
          chatId: 4242,
          kind: ResolvedChatKind.person,
        ),
        '/user/4242',
      );
      expect(
        DeepLinkRoutes.routeFor(
          TelegramChannelLink('flutter_ethiopia'),
          chatId: -100888,
          kind: ResolvedChatKind.group,
        ),
        '/chat/-100888',
      );
    });

    // It opened the group's chat at the bottom, not at the message.
    test('a link to a message in a group opens the group at it', () {
      expect(
        DeepLinkRoutes.routeFor(
          TelegramPostLink('flutter_ethiopia', 3),
          chatId: -100888,
          kind: ResolvedChatKind.group,
        ),
        '/chat/-100888?message=${3 << 20}',
      );
    });

    test('a private link to a message in a group does the same', () {
      expect(
        DeepLinkRoutes.routeFor(
          TelegramPrivatePostLink(888, 3),
          kind: ResolvedChatKind.group,
        ),
        '/chat/-100888?message=${3 << 20}',
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

    // Both are handed to Telegram.
    test('an invite, and an unresolved name, have no route here', () {
      expect(DeepLinkRoutes.routeFor(TelegramInviteLink('x')), isNull);
      expect(DeepLinkRoutes.routeFor(TelegramChannelLink('durov')), isNull);
      expect(DeepLinkRoutes.routeFor(TelegramPostLink('durov', 1)), isNull);
    });
  });

  // Links the app writes, such as from "Copy link", must parse back.
  group('round trip with the links this app writes', () {
    test('a public post link parses back to the same post', () {
      final link =
          parse('https://t.me/ragoose_dumps/11123') as TelegramPostLink;
      expect(link.username, 'ragoose_dumps');
      expect(link.serverMessageId, 11123);
    });

    test('a private post link parses back to the same chat', () {
      final link =
          parse('https://t.me/c/1234567890/11123') as TelegramPrivatePostLink;
      expect(link.chatId, -1001234567890);
    });
  });

  /// go_router can normalise `tg://resolve` to `tg:/resolve`, moving the
  /// action from the authority into the path.
  group('a tg: action is found wherever the form puts it', () {
    void expectsChannel(String raw, String username) {
      final link = TelegramLinks.parse(Uri.parse(raw));
      expect(link, isA<TelegramChannelLink>(), reason: raw);
      expect((link as TelegramChannelLink).username, username, reason: raw);
    }

    test('in the authority, as Android hands it over', () {
      expectsChannel('tg://resolve?domain=Meseretegeez', 'Meseretegeez');
    });

    test('in the path, as a normaliser leaves it', () {
      expectsChannel('tg:/resolve?domain=Meseretegeez', 'Meseretegeez');
    });

    test('with no slash at all', () {
      expectsChannel('tg:resolve?domain=Meseretegeez', 'Meseretegeez');
    });

    test('and a trailing slash is not part of the action', () {
      expectsChannel('tg://resolve/?domain=Meseretegeez', 'Meseretegeez');
    });

    test('a post keeps its id through the same forms', () {
      for (final raw in [
        'tg://resolve?domain=Meseretegeez&post=42',
        'tg:/resolve?domain=Meseretegeez&post=42',
      ]) {
        final link = TelegramLinks.parse(Uri.parse(raw));
        expect(link, isA<TelegramPostLink>(), reason: raw);
        expect((link as TelegramPostLink).username, 'Meseretegeez');
        expect(link.serverMessageId, 42);
      }
    });

    test('and so does a private post', () {
      final link = TelegramLinks.parse(
        Uri.parse('tg:/privatepost?channel=123&post=9'),
      );
      expect(link, isA<TelegramPrivatePostLink>());
    });

    test('an action this app does not know is still nothing', () {
      expect(TelegramLinks.parse(Uri.parse('tg:/settings')), isNull);
      expect(TelegramLinks.parse(Uri.parse('tg://settings')), isNull);
    });
  });

  /// A link that reaches the router as a location is handed to the link
  /// handler instead of failing to route.
  group('deepLinkFromStrayLocation', () {
    test('claims a link this app can open', () {
      final uri = Uri.parse('tg:/resolve?domain=Meseretegeez');
      expect(deepLinkFromStrayLocation(uri), uri);
    });

    test('claims a t.me location too', () {
      final uri = Uri.parse('https://t.me/Meseretegeez/12');
      expect(deepLinkFromStrayLocation(uri), uri);
    });

    // A bad in-app route is a routing bug, not a link.
    test('leaves an ordinary bad route alone', () {
      expect(deepLinkFromStrayLocation(Uri.parse('/nope')), isNull);
      expect(deepLinkFromStrayLocation(Uri.parse('/post/')), isNull);
    });
  });

  /// Further link shapes Telegram emits.
  group('shapes gramX used to hand back to Telegram', () {
    test('a private channel with no post opens the channel', () {
      final link = TelegramLinks.parse(Uri.parse('https://t.me/c/1234567890'));
      expect(link, isA<TelegramPrivateChannelLink>());
      expect((link as TelegramPrivateChannelLink).chatId, -1001234567890);
      expect(DeepLinkRoutes.routeFor(link), '/channel/-1001234567890');
    });

    test('and a trailing slash does not change that', () {
      expect(
        TelegramLinks.parse(Uri.parse('https://t.me/c/1234567890/')),
        isA<TelegramPrivateChannelLink>(),
      );
    });

    test('a post in one still opens the post', () {
      expect(
        TelegramLinks.parse(Uri.parse('https://t.me/c/1234567890/42')),
        isA<TelegramPrivatePostLink>(),
      );
    });

    test('a handle may carry its sigil', () {
      for (final raw in [
        'https://t.me/@durov_test',
        'tg://resolve?domain=@durov_test',
      ]) {
        final link = TelegramLinks.parse(Uri.parse(raw));
        expect(link, isA<TelegramChannelLink>(), reason: raw);
        expect((link as TelegramChannelLink).username, 'durov_test');
      }
    });

    test('www is an alias on every Telegram host, not just t.me', () {
      for (final host in ['www.t.me', 'www.telegram.me', 'www.telegram.dog']) {
        expect(
          TelegramLinks.parse(Uri.parse('https://$host/durov_test')),
          isA<TelegramChannelLink>(),
          reason: host,
        );
      }
    });

    test('a host that merely ends in a Telegram domain is still not one', () {
      expect(
        TelegramLinks.parse(Uri.parse('https://evil-t.me/durov_test')),
        isNull,
      );
      expect(
        TelegramLinks.parse(Uri.parse('https://t.me.evil.com/durov_test')),
        isNull,
      );
    });
  });

  group('hashtag search links', () {
    test('a tg://search opens the search field on the tag', () {
      final link = TelegramLinks.parse(
        Uri.parse('tg://search?query=%23flutter'),
      );
      expect(link, isA<TelegramHashtagLink>());
      expect((link as TelegramHashtagLink).tag, '#flutter');
    });

    test('the older q spelling is the same parameter', () {
      final link = TelegramLinks.parse(Uri.parse('tg://search?q=flutter'));
      expect((link as TelegramHashtagLink).tag, '#flutter');
    });

    test('a bare tag gets its sigil back', () {
      expect(TelegramLinks.normaliseHashtag('flutter'), '#flutter');
      expect(TelegramLinks.normaliseHashtag('#flutter'), '#flutter');
      expect(TelegramLinks.normaliseHashtag('  #flutter  '), '#flutter');
    });

    // A phrase is a text search, not a hashtag.
    test('a phrase is not a hashtag', () {
      expect(TelegramLinks.normaliseHashtag('two words'), isNull);
      expect(TelegramLinks.normaliseHashtag('#'), isNull);
      expect(TelegramLinks.normaliseHashtag(''), isNull);
      expect(TelegramLinks.parse(Uri.parse('tg://search')), isNull);
    });

    // A query and a tab switch, handled by the shell.
    test('it is deliberately not a route', () {
      expect(
        DeepLinkRoutes.routeFor(const TelegramHashtagLink('#flutter')),
        isNull,
      );
    });
  });
}
