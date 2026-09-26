import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/core/navigation/telegram_link_resolver.dart';

/// `GetInternalLinkType` is Telegram's own parser, shipped inside
/// TDLib, documented offline and callable before authorization — so it is off
/// the request budget and works in guest mode.
///
/// The whole design turns on there being **three** answers rather than two.
/// "TDLib could not say" and "TDLib says this is a Telegram link gramX has no
/// screen for" collapse into the same null if you let them, and they must not:
/// the local parser's last rule is "anything left is a username", so a link
/// shape Telegram adds next year would be read as a channel that does not
/// exist and the reader sent to a 404 instead of to Telegram.
void main() {
  Uri uri(String raw) => Uri.parse(raw);

  group('a link gramX can open', () {
    test('a public chat becomes a channel link', () {
      final verdict = TelegramLinkResolver.verdictFor(
        td.InternalLinkTypePublicChat(
          chatUsername: 'ragoose_dumps',
          draftText: '',
          openProfile: false,
        ),
        uri('https://t.me/ragoose_dumps'),
      );

      expect(verdict, isA<LinkHandled>());
      expect(
        (verdict as LinkHandled).link,
        const TelegramChannelLink('ragoose_dumps'),
      );
    });

    /// TDLib names the kind but hands back only a URL for `getMessageLinkInfo`
    /// — which is *not* documented offline. Calling it would put a networked
    /// request on the budget for every tapped post link, so the address is
    /// read out of the same URL locally, for nothing.
    test('a message link is addressed locally, not by a second request', () {
      final verdict = TelegramLinkResolver.verdictFor(
        td.InternalLinkTypeMessage(url: 'https://t.me/ragoose_dumps/42'),
        uri('https://t.me/ragoose_dumps/42'),
      );

      expect(verdict, isA<LinkHandled>());
      expect(
        (verdict as LinkHandled).link,
        const TelegramPostLink('ragoose_dumps', 42),
      );
    });

    test('a private post link too', () {
      final verdict = TelegramLinkResolver.verdictFor(
        td.InternalLinkTypeMessage(url: 'https://t.me/c/1234567890/42'),
        uri('https://t.me/c/1234567890/42'),
      );

      expect(
        (verdict as LinkHandled).link,
        const TelegramPrivatePostLink(1234567890, 42),
      );
    });

    /// TDLib answers with its own canonical spelling of an invite, which is a
    /// URL where [TelegramInviteLink] holds a hash.
    test('an invite is unwrapped back to its hash', () {
      final verdict = TelegramLinkResolver.verdictFor(
        td.InternalLinkTypeChatInvite(inviteLink: 'https://t.me/+AbCdEfGh'),
        uri('https://t.me/+AbCdEfGh'),
      );

      expect(
        (verdict as LinkHandled).link,
        const TelegramInviteLink('AbCdEfGh'),
      );
    });
  });

  group('a link only Telegram can open', () {
    /// The case the three-state exists for. Each of these has a first path
    /// segment the local parser would happily read as a channel name.
    test('is never guessed at by the local parser', () {
      final types = <td.InternalLinkType>[
        td.InternalLinkTypeBotStart(
          botUsername: 'somebot',
          startParameter: 'x',
          autostart: false,
        ),
        td.InternalLinkTypeStory(storySenderUsername: 'someone', storyId: 7),
        td.InternalLinkTypeStickerSet(
          stickerSetName: 'somepack',
          expectCustomEmoji: false,
        ),
        const td.InternalLinkTypePremiumFeatures(referrer: ''),
        const td.InternalLinkTypeChatFolderSettings(),
      ];

      for (final type in types) {
        expect(
          TelegramLinkResolver.verdictFor(type, uri('https://t.me/somebot')),
          isA<LinkForTelegram>(),
          reason: type.runtimeType.toString(),
        );
      }
    });

    /// A public chat whose username Telegram accepts and this app's rule does
    /// not. Better handed over than opened on a name the channel screen cannot
    /// look up.
    test('a username this app would refuse goes to Telegram', () {
      expect(
        TelegramLinkResolver.verdictFor(
          td.InternalLinkTypePublicChat(
            chatUsername: 'ab',
            draftText: '',
            openProfile: false,
          ),
          uri('https://t.me/ab'),
        ),
        isA<LinkForTelegram>(),
      );
    });

    test('a message link with no address in it is handed over', () {
      expect(
        TelegramLinkResolver.verdictFor(
          td.InternalLinkTypeMessage(url: 'https://example.com/nope'),
          uri('https://example.com/nope'),
        ),
        isA<LinkForTelegram>(),
      );
    });
  });

  group('a link TDLib has no opinion on', () {
    /// Not the same as unsupported. This TDLib version has no type for
    /// `tg://search`, and the local parser opens it — so the fallback has to
    /// run rather than the link being handed away.
    test('falls through to the local parser', () {
      expect(
        TelegramLinkResolver.verdictFor(
          const td.InternalLinkTypeUnknownDeepLink(link: 'tg://search?q=x'),
          uri('tg://search?query=%23flutter'),
        ),
        isA<LinkUnknown>(),
      );
    });
  });

  /// The gate on the link stream. It used to be a full parse, which quietly
  /// made the local regex the last word on every incoming link: a shape only
  /// TDLib knows was dropped on arrival and never reached the resolver.
  group('couldBeTelegram', () {
    test('lets through anything Telegram serves', () {
      for (final raw in [
        'tg://resolve?domain=x',
        'tg://some_future_thing?x=1',
        'https://t.me/whatever/1/2/3',
        'https://www.telegram.me/x',
        'http://telegram.dog/x',
      ]) {
        expect(TelegramLinks.couldBeTelegram(uri(raw)), isTrue, reason: raw);
      }
    });

    test('and nothing else', () {
      for (final raw in [
        'https://example.com/t.me',
        'https://t.me.evil.com/x',
        'https://evil-t.me/x',
        'mailto:a@b.com',
      ]) {
        expect(TelegramLinks.couldBeTelegram(uri(raw)), isFalse, reason: raw);
      }
    });

    /// Weaker than parse on purpose: it answers "ours to think about?", not
    /// "where does it go?". A reserved word is Telegram's, and only the
    /// resolver gets to decide it has no screen here.
    test('is weaker than parse, deliberately', () {
      final reserved = uri('https://t.me/addstickers/pack');
      expect(TelegramLinks.parse(reserved), isNull);
      expect(TelegramLinks.couldBeTelegram(reserved), isTrue);
    });
  });
}
