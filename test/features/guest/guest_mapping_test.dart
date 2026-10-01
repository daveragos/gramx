import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/guest/data/guest_media_cache.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/guest/data/tme_preview_client.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';

GuestChannelInfo _channel({String username = 'ashangulit'}) => GuestChannelInfo(
  username: username,
  title: 'Ashangulit',
  avatarUrl: 'https://cdn.telegram.org/avatar.jpg',
  subscribers: '104',
  isVerified: true,
);

GuestPost _post({
  int seq = 42,
  String text = 'Good morning',
  List<GuestMedia> media = const [],
  List<GuestReaction> reactions = const [],
  String? views,
}) => GuestPost(
  id: 'ashangulit/$seq',
  seq: seq,
  publishedAt: DateTime.utc(2026, 8, 24, 7, 32),
  text: text,
  media: media,
  reactions: reactions,
  views: views,
);

void main() {
  group('GuestPostMapper', () {
    test('maps a post onto the app\'s own model', () {
      final post = GuestPostMapper.mapPost(_post(views: '48'), _channel());

      expect(post.channelTitle, 'Ashangulit');
      expect(post.channelUsername, 'ashangulit');
      expect(post.isChannelVerified, isTrue);
      expect(post.text, 'Good morning');
      expect(post.viewCount, 48);
      expect(post.messageId, 42);
    });

    // The router, the bookmark key and the optimistic override map are all
    // keyed on this exact shape.
    test('the post id keeps the "<chatId>_<messageId>" shape', () {
      final post = GuestPostMapper.mapPost(_post(), _channel());
      expect(post.id, '${post.chatId}_${post.messageId}');
      expect(post.id.split('_'), hasLength(2));
    });

    group('the synthetic chat id', () {
      // Stable across runs (unlike hashCode), so bookmarks keep their ids.
      test('is the same every time for the same channel', () {
        expect(
          GuestPostMapper.syntheticChatId('durov'),
          GuestPostMapper.syntheticChatId('durov'),
        );
      });

      // Telegram usernames are case-insensitive.
      test('ignores case', () {
        expect(
          GuestPostMapper.syntheticChatId('Durov'),
          GuestPostMapper.syntheticChatId('durov'),
        );
      });

      test('differs between channels', () {
        expect(
          GuestPostMapper.syntheticChatId('durov'),
          isNot(GuestPostMapper.syntheticChatId('telegram')),
        );
      });

      // Real supergroup ids (-100 followed by the id) are far below this range,
      // so a guest id is never mistaken for one.
      test('can never be read as a real Telegram chat id', () {
        for (final name in ['durov', 'telegram', 'a', 'zzzzzzzzzzzz']) {
          final id = GuestPostMapper.syntheticChatId(name);
          expect(id, lessThan(0));
          expect(id, greaterThan(-1000000000000));
          expect(GuestPostMapper.isSynthetic(id), isTrue);
        }
        expect(GuestPostMapper.isSynthetic(-1001234567890), isFalse);
      });
    });

    test('reactions carry through as counts the card can draw', () {
      final post = GuestPostMapper.mapPost(
        _post(
          reactions: const [
            GuestReaction(emoji: '⭐', count: 1, isPaid: true),
            GuestReaction(emoji: '❤️', count: 5),
          ],
        ),
        _channel(),
      );

      expect(post.reactions, {'⭐': 1, '❤️': 5});
      expect(post.chosenReactions, isEmpty);
    });

    // Without an account there is no read state, so no unread dot.
    test('guest posts are never unread', () {
      expect(GuestPostMapper.mapPost(_post(), _channel()).isRead, isTrue);
    });

    test('media keeps its https URL for the cache to resolve', () {
      final post = GuestPostMapper.mapPost(
        _post(
          media: const [
            GuestMedia(
              kind: GuestMediaKind.photo,
              url: 'https://cdn.telegram.org/pic.jpg',
            ),
          ],
        ),
        _channel(),
      );

      expect(post.media.single.type, MediaType.photo);
      expect(post.media.single.url, 'https://cdn.telegram.org/pic.jpg');
    });

    test('a round video maps to a video', () {
      final post = GuestPostMapper.mapPost(
        _post(
          media: const [
            GuestMedia(
              kind: GuestMediaKind.roundVideo,
              url: 'https://cdn.telegram.org/round.mp4',
              durationSec: 12,
            ),
          ],
        ),
        _channel(),
      );

      expect(post.media.single.type, MediaType.video);
      expect(post.media.single.duration, 12);
    });

    test('view counts expand from Telegram\'s shorthand', () {
      int views(String raw) =>
          GuestPostMapper.mapPost(_post(views: raw), _channel()).viewCount;

      expect(views('48'), 48);
      expect(views('1.5K'), 1500);
      expect(views('12.6M'), 12600000);
      expect(views('12 345'), 12345);
    });

    test('mapping a page gives every post the same chat id', () {
      final posts = GuestPostMapper.mapPage(
        GuestChannelPage(
          channel: _channel(),
          posts: [_post(seq: 1), _post(seq: 2)],
        ),
      );

      expect(posts.map((p) => p.chatId).toSet(), hasLength(1));
      expect(posts.map((p) => p.messageId), [1, 2]);
    });
  });

  group('TmePreviewClient.parseUsername', () {
    test('accepts the forms a person actually types', () {
      for (final input in [
        'durov',
        '@durov',
        ' durov ',
        't.me/durov',
        'https://t.me/durov',
        'https://t.me/s/durov',
        'https://t.me/durov/1234',
      ]) {
        expect(
          TmePreviewClient.parseUsername(input),
          'durov',
          reason: 'input: $input',
        );
      }
    });

    // A typo fails here with a reason instead of adding an empty channel.
    test('rejects what is not a channel username', () {
      for (final input in [
        '',
        '   ',
        'ab',
        'has spaces',
        'https://example.com/durov',
        'has-a-hyphen',
        'way_too_long_${'x' * 40}',
      ]) {
        expect(
          TmePreviewClient.parseUsername(input),
          isNull,
          reason: 'input: $input',
        );
      }
    });
  });

  group('GuestMediaCache', () {
    // URLs from fetched markup must not point the image loader at any host.
    test('only Telegram\'s own hosts are fetched', () {
      expect(
        GuestMediaCache.isAllowed('https://cdn4.telegram-cdn.org/f.jpg'),
        isTrue,
      );
      expect(GuestMediaCache.isAllowed('https://t.me/i/pic.jpg'), isTrue);
      expect(
        GuestMediaCache.isAllowed('https://telesco.pe/file/x.jpg'),
        isTrue,
      );

      expect(
        GuestMediaCache.isAllowed('https://evil.example.com/x.jpg'),
        isFalse,
      );
      // A suffix match must not be fooled by a lookalike domain.
      expect(GuestMediaCache.isAllowed('https://nott.me/x.jpg'), isFalse);
      expect(GuestMediaCache.isAllowed('https://t.me.evil.com/x.jpg'), isFalse);
      expect(GuestMediaCache.isAllowed('http://t.me/x.jpg'), isFalse);
      expect(GuestMediaCache.isAllowed('data:image/png;base64,AAAA'), isFalse);
      expect(GuestMediaCache.isAllowed('javascript:alert(1)'), isFalse);
    });

    test('a URL always names the same file', () {
      const url = 'https://cdn4.telegram-cdn.org/file/abc?size=large';
      expect(
        GuestMediaCache.fileNameFor(url),
        GuestMediaCache.fileNameFor(url),
      );
      expect(
        GuestMediaCache.fileNameFor(url),
        isNot(GuestMediaCache.fileNameFor('${url}2')),
      );
    });

    test('the filename keeps a plain extension and rejects anything else', () {
      expect(
        GuestMediaCache.fileNameFor('https://t.me/a/b.JPG'),
        endsWith('.jpg'),
      );
      expect(
        GuestMediaCache.fileNameFor('https://t.me/a/b'),
        isNot(contains('.')),
      );
      expect(
        GuestMediaCache.fileNameFor('https://t.me/a/b.verylongsuffix'),
        isNot(contains('.')),
      );
    });
  });

  group('ReaderCapabilities', () {
    // One capabilities object instead of `if (isGuest)` checks at each call
    // site, so no control is left that does nothing for a guest.
    test('a guest can do nothing that needs an account', () {
      const guest = ReaderCapabilities.guest;
      expect(guest.canReact, isFalse);
      expect(guest.canMarkRead, isFalse);
      expect(guest.canComment, isFalse);
      expect(guest.canBookmark, isFalse);
      expect(guest.canJoin, isFalse);
      expect(guest.canForward, isFalse);
      expect(guest.canSearchServerSide, isFalse);
      expect(guest.isGuest, isTrue);
    });

    test('signing in turns everything on', () {
      const signedIn = ReaderCapabilities.signedIn;
      expect(signedIn.canReact, isTrue);
      expect(signedIn.canMarkRead, isTrue);
      expect(signedIn.canComment, isTrue);
      expect(signedIn.canBookmark, isTrue);
      expect(signedIn.canJoin, isTrue);
      expect(signedIn.canForward, isTrue);
      expect(signedIn.canSearchServerSide, isTrue);
      expect(signedIn.isGuest, isFalse);
    });
  });

  // Posts the preview page can't draw (e.g. https://t.me/github/11123) say so
  // and offer to open Telegram.
  group('a post the preview page would not draw', () {
    Post mapped() => GuestPostMapper.mapPost(
      GuestPost(
        id: 'github/11123',
        seq: 11123,
        publishedAt: DateTime.utc(2026, 8, 27, 13, 32),
        isUnsupported: true,
      ),
      _channel(username: 'github'),
    );

    test('carries the same marker the TDLib mapper sets', () {
      expect(mapped().unsupportedKind, isNotNull);
    });

    test('says what happened instead of arriving blank', () {
      expect(mapped().text, AppStrings.postUnsupported);
    });

    test('an ordinary guest post carries no marker', () {
      final post = GuestPostMapper.mapPost(_post(), _channel());
      expect(post.unsupportedKind, isNull);
    });
  });

  // A guest post's id is already the server id, so the link must not shift it
  // the way TelegramIds.postLink shifts TDLib ids.
  group('GuestPostMapper.postLink', () {
    test('builds the public t.me link without shifting the id', () {
      final post = GuestPostMapper.mapPost(
        _post(seq: 11123),
        _channel(username: 'github'),
      );

      expect(GuestPostMapper.postLink(post), 'https://t.me/github/11123');
    });

    test('is null when there is no handle to build it from', () {
      final post = GuestPostMapper.mapPost(
        _post(),
        _channel(),
      ).copyWith(channelUsername: null);

      expect(GuestPostMapper.postLink(post), isNull);
    });
  });
}
