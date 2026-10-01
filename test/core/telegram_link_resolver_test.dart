import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/core/navigation/telegram_link_resolver.dart';

/// `GetInternalLinkType` is TDLib's offline link parser, so it costs no
/// requests and works in guest mode.
///
/// The resolver has three outcomes: TDLib couldn't say, a supported link, or
/// a Telegram link with no screen here. The last must not fall through to the
/// local parser, which reads any leftover path as a username.
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

    /// `getMessageLinkInfo` is not offline, so message links are parsed locally.
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

    /// TDLib returns an invite as a URL; [TelegramInviteLink] holds a hash.
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
    /// Each of these has a first path segment the local parser would read as a
    /// channel name.
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

    /// A username Telegram accepts but this app's rule does not.
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
    /// This TDLib version has no type for `tg://search`, but the local parser
    /// handles it.
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

  /// The gate on the link stream. It must let through shapes only TDLib knows.
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

    /// It asks whether a link is Telegram's, not where it goes.
    test('is weaker than parse, deliberately', () {
      final reserved = uri('https://t.me/addstickers/pack');
      expect(TelegramLinks.parse(reserved), isNull);
      expect(TelegramLinks.couldBeTelegram(reserved), isTrue);
    });
  });
}
