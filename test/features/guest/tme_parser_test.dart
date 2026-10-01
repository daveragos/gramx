import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/guest/data/tme_page_parser.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';

/// The t.me markup can change without notice, so a redesign should fail these
/// tests rather than empty someone's feed. `ragoose_dumps.html` is a real
/// capture of the author's channel; the snippets below cover shapes it doesn't
/// contain.
void main() {
  late String captureHtml;

  setUpAll(() {
    captureHtml = File(
      'test/support/tme_samples/ragoose_dumps.html',
    ).readAsStringSync();
  });

  group('against a real captured page', () {
    late GuestChannelPage page;

    setUp(() {
      final parsed = TmePageParser.parse(captureHtml, 'ragoose_dumps');
      expect(parsed, isNotNull, reason: 'the capture is a valid preview page');
      page = parsed!;
    });

    test('reads the channel header', () {
      expect(page.channel.username, 'ragoose_dumps');
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

    test('reactions come through with their emoji and counts', () {
      final reactions = page.posts.expand((p) => p.reactions).toList();
      expect(reactions, isNotEmpty);
      for (final reaction in reactions) {
        expect(reaction.count, greaterThan(0));
        expect(reaction.emoji, isNotEmpty);
      }
    });

    test('media of several kinds', () {
      final kinds = page.posts.expand((p) => p.media).map((m) => m.kind);
      expect(
        kinds.toSet(),
        containsAll([
          GuestMediaKind.photo,
          GuestMediaKind.video,
          GuestMediaKind.document,
        ]),
      );
    });

    test('forwards name the channel they came from', () {
      final forwards = page.posts
          .map((p) => p.forwardedFrom)
          .whereType<GuestForward>()
          .toList();
      expect(forwards, isNotEmpty);
      expect(forwards.every((f) => f.name.isNotEmpty), isTrue);
      expect(forwards.where((f) => f.username != null), isNotEmpty);
    });

    test('link previews come through', () {
      expect(page.posts.where((p) => p.linkPreview != null), isNotEmpty);
    });

    test('media URLs are absolute https, never relative or data:', () {
      for (final media in page.posts.expand((p) => p.media)) {
        expect(media.url, startsWith('https://'));
      }
    });
  });

  group('reactions', () {
    List<GuestReaction> reactionsOf(String chips) => _pageWith('''
      <div class="tgme_widget_message" data-post="c/20">
        <div class="tgme_widget_message_date"><time datetime="2026-08-24T07:32:00+00:00"></time></div>
        <div class="tgme_widget_message_text">reacted to</div>
        <div class="tgme_widget_message_reactions js-message_reactions">$chips</div>
      </div>
    ''').posts.single.reactions;

    test('expands shorthand counts', () {
      final reactions = reactionsOf(
        '<span class="tgme_reaction"><i class="emoji"><b>🔥</b></i>55.2K</span>',
      );
      expect(reactions.single.emoji, '🔥');
      expect(reactions.single.count, 55200);
    });

    test('paid reactions are recognised and drawn as the star', () {
      final reactions = reactionsOf(
        '<span class="tgme_reaction tgme_reaction_paid">'
        '<i class="icon icon-telegram-stars"></i>7.03K</span>',
      );
      expect(reactions.single.isPaid, isTrue);
      expect(reactions.single.emoji, TmePageParser.paidReactionEmoji);
      expect(reactions.single.count, 7030);
    });

    // The page has only the emoji id (the glyph is drawn by script), so a
    // placeholder stands in.
    test('custom emoji reactions keep their count under a placeholder', () {
      final reactions = reactionsOf(
        '<span class="tgme_reaction">'
        '<tg-emoji emoji-id="5465587407350942612"></tg-emoji>826</span>',
      );
      expect(reactions.single.customEmojiId, '5465587407350942612');
      expect(reactions.single.emoji, TmePageParser.customReactionEmoji);
      expect(reactions.single.count, 826);
    });
  });

  group('not a channel preview', () {
    // A 404, a private-channel redirect or a login wall has no channel header,
    // and must not read as a channel with no posts.
    test('returns null rather than an empty channel', () {
      expect(
        TmePageParser.parse('<html><body>Nope</body></html>', 'x'),
        isNull,
      );
      expect(TmePageParser.parse('', 'x'), isNull);
    });
  });

  group('the nested-text trap', () {
    // The text class is nested: the outer element wraps an inner one with the
    // same class, which holds the text.
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

    // The quoted reply above a post uses the same class.
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

    // Untrusted input: only https URLs may reach an image loader or launcher.
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

  // For content the web preview can't render (e.g. https://t.me/github/11123)
  // the page shows a "Please open Telegram" notice and no text or media.
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

    // Every video wrap carries the same notice as a hidden browser fallback,
    // so its presence alone must not flag a post.
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
      final parsed = TmePageParser.parse(captureHtml, 'ragoose_dumps');

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
