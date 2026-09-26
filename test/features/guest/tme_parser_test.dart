import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/guest/data/tme_page_parser.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';

/// The parser reads markup nobody promised to keep stable, so the way a
/// Telegram redesign is supposed to surface is a failing test against a saved
/// page — not an empty feed on somebody's phone.
///
/// `test/support/tme_samples/durov.html` is a real capture. The hand-written
/// snippets below cover the shapes that capture happens not to contain, and
/// the two selector traps that are easy to reintroduce.
void main() {
  late String durovHtml;

  setUpAll(() {
    durovHtml = File('test/support/tme_samples/durov.html').readAsStringSync();
  });

  group('against a real captured page', () {
    late GuestChannelPage page;

    setUp(() {
      final parsed = TmePageParser.parse(durovHtml, 'durov');
      expect(parsed, isNotNull, reason: 'the capture is a valid preview page');
      page = parsed!;
    });

    test('reads the channel header', () {
      expect(page.channel.username, 'durov');
      expect(page.channel.title, isNotEmpty);
      expect(page.channel.avatarUrl, startsWith('https://'));
      expect(page.channel.subscribers, isNotNull);
    });

    test('reads a full page of posts', () {
      expect(page.posts, hasLength(greaterThan(10)));
      for (final post in page.posts) {
        expect(post.seq, greaterThan(0));
        expect(post.id, contains('/'));
        expect(post.publishedAt.year, greaterThan(2012));
      }
    });

    test('the cursor is the oldest post on the page', () {
      final lowest = page.posts
          .map((p) => p.seq)
          .reduce((a, b) => a < b ? a : b);
      expect(page.olderCursor, lowest);
    });

    test('posts carry their text', () {
      expect(page.posts.where((p) => p.text.isNotEmpty), isNotEmpty);
    });

    test('posts carry view counts', () {
      expect(page.posts.where((p) => p.views != null), isNotEmpty);
    });

    // The whole reason reactions are worth parsing here: the preview page has
    // them, so a guest sees the same chips a signed-in reader does.
    test(
      'reactions come through, counts expanded from Telegram\'s shorthand',
      () {
        final withReactions = page.posts
            .where((p) => p.reactions.isNotEmpty)
            .toList();
        expect(withReactions, isNotEmpty);

        for (final reaction in withReactions.expand((p) => p.reactions)) {
          expect(reaction.count, greaterThan(0));
          expect(reaction.emoji, isNotEmpty);
        }
        // "55.2K" on the page is 55200 here — Post.reactions is a number, and
        // TimeUtils.formatCount re-abbreviates it in the app's own style.
        expect(
          withReactions.expand((p) => p.reactions).map((r) => r.count),
          contains(greaterThan(1000)),
        );
      },
    );

    test('paid reactions are recognised and drawn as the star', () {
      final paid = page.posts
          .expand((p) => p.reactions)
          .where((r) => r.isPaid)
          .toList();
      expect(
        paid,
        isNotEmpty,
        reason: 'the capture contains a tgme_reaction_paid chip',
      );
      expect(paid.first.emoji, TmePageParser.paidReactionEmoji);
    });

    // Telegram embeds only the id and draws the glyph in JS, so there is no
    // character in the HTML to show. Dropping the reaction would be worse.
    test('custom emoji reactions keep their count under a placeholder', () {
      final custom = page.posts
          .expand((p) => p.reactions)
          .where((r) => r.customEmojiId != null)
          .toList();
      expect(custom, isNotEmpty);
      expect(custom.first.emoji, TmePageParser.customReactionEmoji);
      expect(custom.first.count, greaterThan(0));
    });

    test('media URLs are absolute https, never relative or data:', () {
      for (final media in page.posts.expand((p) => p.media)) {
        expect(media.url, startsWith('https://'));
      }
    });
  });

  group('not a channel preview', () {
    // A 404, a private-channel redirect or a login wall has no channel header.
    // Returning an empty page instead of null would look like a channel that
    // has posted nothing, which is a much worse answer than "couldn't read it".
    test('returns null rather than an empty channel', () {
      expect(
        TmePageParser.parse('<html><body>Nope</body></html>', 'x'),
        isNull,
      );
      expect(TmePageParser.parse('', 'x'), isNull);
    });
  });

  group('the nested-text trap', () {
    // t.me/s/ nests the class: an outer wrapper holds an inner element with the
    // same class and the actual text. Taking the first match picks the wrapper.
    test('takes the innermost body, not the wrapper', () {
      final page = _pageWith('''
        <div class="tgme_widget_message" data-post="c/5">
          <div class="tgme_widget_message_date"><time datetime="2026-08-24T07:32:00+00:00"></time></div>
          <div class="tgme_widget_message_text js-message_text">
            <div class="tgme_widget_message_text">Good morning</div>
          </div>
        </div>
      ''');
      expect(page.posts.single.text, 'Good morning');
    });

    // The reply preview wears the same class, so a post replying to another
    // would otherwise render the quoted text as its own body.
    test('ignores the reply preview', () {
      final page = _pageWith('''
        <div class="tgme_widget_message" data-post="c/6">
          <div class="tgme_widget_message_date"><time datetime="2026-08-24T07:32:00+00:00"></time></div>
          <a class="tgme_widget_message_reply">
            <div class="tgme_widget_message_text js-message_reply_text">quoted words</div>
          </a>
          <div class="tgme_widget_message_text">my own words</div>
        </div>
      ''');
      expect(page.posts.single.text, 'my own words');
    });

    test('line breaks survive', () {
      final page = _pageWith('''
        <div class="tgme_widget_message" data-post="c/7">
          <div class="tgme_widget_message_date"><time datetime="2026-08-24T07:32:00+00:00"></time></div>
          <div class="tgme_widget_message_text">one<br/>two</div>
        </div>
      ''');
      expect(page.posts.single.text, 'one\ntwo');
    });
  });

  group('shapes the capture does not contain', () {
    test('a document keeps its name and href', () {
      final page = _pageWith('''
        <div class="tgme_widget_message" data-post="c/8">
          <div class="tgme_widget_message_date"><time datetime="2026-08-24T07:32:00+00:00"></time></div>
          <a class="tgme_widget_message_document_wrap" href="https://cdn.telegram.org/file.pdf">
            <div class="tgme_widget_message_document_title">report.pdf</div>
          </a>
        </div>
      ''');
      final media = page.posts.single.media.single;
      expect(media.kind, GuestMediaKind.document);
      expect(media.fileName, 'report.pdf');
    });

    test('a forward keeps the source name and username', () {
      final page = _pageWith('''
        <div class="tgme_widget_message" data-post="c/9">
          <div class="tgme_widget_message_date"><time datetime="2026-08-24T07:32:00+00:00"></time></div>
          <div class="tgme_widget_message_forwarded_from">
            <a class="tgme_widget_message_forwarded_from_name" href="https://t.me/somechannel/42">Some Channel</a>
          </div>
        </div>
      ''');
      final forward = page.posts.single.forwardedFrom!;
      expect(forward.name, 'Some Channel');
      expect(forward.username, 'somechannel');
    });

    test('a photo URL comes out of the inline background-image', () {
      final page = _pageWith('''
        <div class="tgme_widget_message" data-post="c/10">
          <div class="tgme_widget_message_date"><time datetime="2026-08-24T07:32:00+00:00"></time></div>
          <a class="tgme_widget_message_photo_wrap"
             style="width:100px;background-image:url('https://cdn.telegram.org/pic.jpg')"></a>
        </div>
      ''');
      expect(
        page.posts.single.media.single.url,
        'https://cdn.telegram.org/pic.jpg',
      );
    });

    // The page is untrusted network input. A relative path, a data: blob or a
    // javascript: href must never reach an image loader or a launcher.
    test('non-https media is dropped, not passed through', () {
      final page = _pageWith('''
        <div class="tgme_widget_message" data-post="c/11">
          <div class="tgme_widget_message_date"><time datetime="2026-08-24T07:32:00+00:00"></time></div>
          <a class="tgme_widget_message_photo_wrap"
             style="background-image:url('javascript:alert(1)')"></a>
          <a class="tgme_widget_message_photo_wrap"
             style="background-image:url('/relative.jpg')"></a>
          <a class="tgme_widget_message_photo_wrap"
             style="background-image:url('data:image/png;base64,AAAA')"></a>
        </div>
      ''');
      expect(page.posts.single.media, isEmpty);
    });

    test('a post with no parsable date is dropped rather than dated now', () {
      final page = _pageWith('''
        <div class="tgme_widget_message" data-post="c/12">
          <div class="tgme_widget_message_text">no time element</div>
        </div>
      ''');
      expect(page.posts, isEmpty);
    });

    test('centred service notices are skipped', () {
      final page = _pageWith('''
        <div class="tgme_widget_message_centered">Channel created</div>
      ''');
      expect(page.posts, isEmpty);
    });
  });

  // Reported against https://t.me/github/11123. The preview page draws its own
  // "Please open Telegram to view this post" placeholder for content its web
  // widget cannot render, and the post then carries no text and no media — so
  // it parsed as an empty post and reached the feed as a card with a header, a
  // timestamp and nothing between them.
  group('a post the preview page will not draw', () {
    test('is flagged rather than parsed as an empty post', () {
      final page = _pageWith('''
        <div class="tgme_widget_message text_not_supported_wrap js-widget_message"
             data-post="github/11123">
          <div class="message_media_not_supported_wrap">
            <div class="message_media_not_supported">
              <div class="message_media_not_supported_label">
                Please open Telegram to view this post
              </div>
            </div>
          </div>
          <div class="tgme_widget_message_date">
            <time datetime="2026-08-27T13:32:00+00:00"></time>
          </div>
        </div>
      ''');

      expect(page.posts, hasLength(1));
      expect(page.posts.single.seq, 11123);
      expect(page.posts.single.isUnsupported, isTrue);
      expect(page.posts.single.text, isEmpty);
      expect(page.posts.single.media, isEmpty);
    });

    // The trap. Telegram puts the same markup inside every video wrap as a
    // browser fallback, so matching on the class alone flags every post on the
    // saved capture — all twenty of them.
    test('a video\'s own browser fallback is not the placeholder', () {
      final page = _pageWith('''
        <div class="tgme_widget_message text_not_supported_wrap js-widget_message"
             data-post="c/7">
          <div class="tgme_widget_message_video_wrap">
            <video src="https://cdn4.telesco.pe/file/clip.mp4"></video>
          </div>
          <div class="message_media_not_supported_wrap">
            <div class="message_media_not_supported">
              <div class="message_media_not_supported_label">
                This media is not supported in your browser
              </div>
            </div>
          </div>
          <div class="tgme_widget_message_date">
            <time datetime="2026-08-27T13:32:00+00:00"></time>
          </div>
        </div>
      ''');

      expect(page.posts.single.media, hasLength(1));
      expect(page.posts.single.isUnsupported, isFalse);
    });

    test('an ordinary post is not flagged', () {
      final parsed = TmePageParser.parse(durovHtml, 'durov');

      expect(
        parsed!.posts.where((p) => p.isUnsupported),
        isEmpty,
        reason: 'the capture holds no placeholder posts',
      );
    });
  });
}

/// A minimal but valid preview page around [messageHtml].
GuestChannelPage _pageWith(String messageHtml) {
  final parsed = TmePageParser.parse('''
    <html><body>
      <div class="tgme_channel_info_header_title"><span>Test Channel</span></div>
      <div class="tgme_channel_info_header_username"><a href="https://t.me/c">@c</a></div>
      <div class="tgme_widget_message_wrap">$messageHtml</div>
    </body></html>
  ''', 'c');

  expect(parsed, isNotNull);
  return parsed!;
}
