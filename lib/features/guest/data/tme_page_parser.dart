import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;

import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';

/// Reads a channel's public web preview, `https://t.me/s/<username>`.
///
/// The page is untrusted markup with no stable contract, so everything here is
/// defensive: a missing piece leaves a field empty, and a URL that is not
/// https is dropped rather than passed on.
abstract class TmePageParser {
  static const String paidReactionEmoji = '⭐';
  static const String customReactionEmoji = '🩶';

  /// The channel and posts on [html], or null when it is not a public channel
  /// preview. [username] is the name the page was requested for.
  static GuestChannelPage? parse(String html, String username) {
    final document = html_parser.parse(html);

    // Error pages, login walls and the plain t.me/<name> page all lack this.
    final titleElement = document.querySelector(
      '.tgme_channel_info_header_title',
    );
    if (titleElement == null) return null;

    final posts = [
      for (final message in document.querySelectorAll(
        '.tgme_widget_message[data-post]',
      ))
        ?_post(message),
    ];

    final shownUsername = _channelUsername(document, username, posts);
    final title = _plainText(titleElement);
    final channel = GuestChannelInfo(
      username: shownUsername,
      title: title.isEmpty ? shownUsername : title,
      description: _plainText(
        document.querySelector('.tgme_channel_info_description'),
      ),
      avatarUrl: _avatarUrl(document),
      subscribers: _subscribers(document),
      isVerified: _isVerified(document),
    );

    return GuestChannelPage(
      channel: channel,
      posts: posts,
      olderCursor: posts.isEmpty
          ? null
          : posts.map((p) => p.seq).reduce((a, b) => a < b ? a : b),
    );
  }

  /// A counter as the page abbreviates it ("1.2K", "12.6M", "12 345") as a
  /// number, or null when [text] is not one.
  static int? parseCount(String text) {
    // `\s` also covers the no-break spaces some locales group digits with.
    final compact = text.replaceAll(RegExp(r'\s'), '');
    final match = RegExp(r'^(\d+(?:[.,]\d+)*)([KkMmBb]?)$').firstMatch(compact);
    if (match == null) return null;

    final digits = match.group(1)!;
    final suffix = match.group(2)!.toUpperCase();
    // Without a suffix any separator groups thousands; with one it is the
    // decimal point of a shortened figure.
    if (suffix.isEmpty) {
      return int.tryParse(digits.replaceAll(RegExp('[.,]'), ''));
    }
    final value = double.tryParse(digits.replaceAll(',', '.'));
    if (value == null) return null;
    final scale = switch (suffix) {
      'K' => 1e3,
      'M' => 1e6,
      _ => 1e9,
    };
    return (value * scale).round();
  }

  // ── Channel header ─────────────────────────────────────────────────────────

  /// The handle the header shows, in the spelling the posts use.
  ///
  /// The header echoes the requested name in whatever case it was typed,
  /// while each post reference carries the channel's own spelling.
  static String _channelUsername(
    html.Document document,
    String requested,
    List<GuestPost> posts,
  ) {
    final shown = _stripAt(
      _plainText(document.querySelector('.tgme_channel_info_header_username')),
    );
    final name = TelegramLinks.isUsername(shown) ? shown : requested;

    for (final post in posts) {
      final fromPost = post.id.substring(0, post.id.lastIndexOf('/'));
      if (fromPost.toLowerCase() == name.toLowerCase()) return fromPost;
    }
    return name;
  }

  static String? _avatarUrl(html.Document document) {
    final image =
        document.querySelector('.tgme_channel_info_header img') ??
        document.querySelector('.tgme_page_photo_image img');
    return _https(image?.attributes['src']) ??
        _https(
          document
              .querySelector('meta[property="og:image"]')
              ?.attributes['content'],
        );
  }

  /// The subscriber counter's value. Telegram lists that counter first, which
  /// is the fallback if its label is ever worded differently.
  static String? _subscribers(html.Document document) {
    final counters = document.querySelectorAll('.tgme_channel_info_counter');
    if (counters.isEmpty) return null;

    bool countsSubscribers(html.Element counter) => _plainText(
      counter.querySelector('.counter_type'),
    ).toLowerCase().startsWith('subscriber');

    final counter = counters.firstWhere(
      countsSubscribers,
      orElse: () => counters.first,
    );
    final value = _plainText(counter.querySelector('.counter_value'));
    return value.isEmpty ? null : value;
  }

  static bool _isVerified(html.Document document) => const [
    '.tgme_channel_info_header .verified-icon',
    '.tgme_channel_info_header_labels .verified-icon',
  ].any((selector) => document.querySelector(selector) != null);

  // ── Posts ──────────────────────────────────────────────────────────────────

  /// Parts of a message that belong to something other than the post: the
  /// post it replies to, the preview of a link, and the fallback notice the
  /// page keeps hidden unless the browser cannot show the media.
  static const _notThePost = {
    'tgme_widget_message_reply',
    'tgme_widget_message_link_preview',
    'media_not_supported_cont',
  };

  static GuestPost? _post(html.Element message) {
    // "Channel created" and other service entries are not posts.
    if (message.classes.contains('service_message')) return null;

    final id = message.attributes['data-post']?.trim() ?? '';
    final slash = id.lastIndexOf('/');
    final seq = slash > 0 ? int.tryParse(id.substring(slash + 1)) : null;
    if (seq == null || seq <= 0) return null;

    final publishedAt = _publishedAt(message);
    if (publishedAt == null) return null;

    final media = _media(message, postLink: 'https://t.me/$id');
    final views = _plainText(_ownFirst(message, '.tgme_widget_message_views'));

    return GuestPost(
      id: id,
      seq: seq,
      publishedAt: publishedAt,
      text: _postText(message),
      media: media,
      linkPreview: _linkPreview(message),
      forwardedFrom: _forward(message),
      views: views.isEmpty ? null : views,
      reactions: _reactions(message),
      // Where media was found, a notice beside it is that media's browser
      // fallback rather than the page giving up on the whole post.
      isUnsupported: media.isEmpty && _showsPlaceholder(message),
    );
  }

  static DateTime? _publishedAt(html.Element message) {
    final time =
        message.querySelector('.tgme_widget_message_date time[datetime]') ??
        message.querySelector('time[datetime]');
    final value = time?.attributes['datetime'];
    return value == null ? null : DateTime.tryParse(value);
  }

  /// The post's own text.
  ///
  /// The text class is nested on some posts, a wrapper around an inner copy,
  /// so only the innermost match is read. Reply quotes wear the same class
  /// and are excluded.
  static String _postText(html.Element message) {
    final candidates = _own(message, '.tgme_widget_message_text');
    for (final candidate in candidates) {
      final wrapsAnother = candidates.any(
        (other) => !identical(other, candidate) && _contains(candidate, other),
      );
      if (!wrapsAnother) return _plainText(candidate);
    }
    return '';
  }

  static GuestForward? _forward(html.Element message) {
    final source = _ownFirst(
      message,
      '.tgme_widget_message_forwarded_from_name',
    );
    final name = _plainText(source);
    if (source == null || name.isEmpty) return null;

    final href = _https(source.attributes['href']);
    final link = href == null ? null : TelegramLinks.parse(Uri.parse(href));
    return GuestForward(
      name: name,
      username: switch (link) {
        TelegramChannelLink(:final username) => username,
        TelegramPostLink(:final username) => username,
        _ => null,
      },
    );
  }

  static GuestLinkPreview? _linkPreview(html.Element message) {
    final preview = _ownFirst(message, '.tgme_widget_message_link_preview');
    final url = _https(preview?.attributes['href']);
    if (preview == null || url == null) return null;

    String? textOf(String selector) {
      final text = _plainText(preview.querySelector(selector));
      return text.isEmpty ? null : text;
    }

    final image = [
      '.link_preview_image',
      '.link_preview_right_image',
      '.link_preview_video_thumb',
    ].map((s) => _backgroundUrl(preview.querySelector(s))).nonNulls;

    return GuestLinkPreview(
      url: url,
      siteName: textOf('.link_preview_site_name'),
      title: textOf('.link_preview_title'),
      description: textOf('.link_preview_description'),
      imageUrl: image.firstOrNull,
    );
  }

  static List<GuestReaction> _reactions(html.Element message) {
    final reactions = <GuestReaction>[];
    for (final chip in _own(message, '.tgme_reaction')) {
      // The count is the chip's own text; the emoji sits in a child element.
      final count = parseCount(
        chip.nodes.whereType<html.Text>().map((t) => t.data).join(),
      );
      if (count == null || count <= 0) continue;

      if (chip.classes.contains('tgme_reaction_paid')) {
        reactions.add(
          GuestReaction(emoji: paidReactionEmoji, count: count, isPaid: true),
        );
        continue;
      }

      // A custom emoji is only an id; the page draws its artwork in script.
      final customId = chip
          .querySelector('tg-emoji[emoji-id]')
          ?.attributes['emoji-id'];
      if (customId != null && customId.isNotEmpty) {
        reactions.add(
          GuestReaction(
            emoji: customReactionEmoji,
            count: count,
            customEmojiId: customId,
          ),
        );
        continue;
      }

      final emoji = _plainText(chip.querySelector('.emoji'));
      if (emoji.isNotEmpty) {
        reactions.add(GuestReaction(emoji: emoji, count: count));
      }
    }
    return reactions;
  }

  /// Whether the page shows its notice for content it cannot draw.
  ///
  /// The same notice is also present, hidden, inside every video player and
  /// in a fallback block beside most media. Only one outside both is shown.
  static bool _showsPlaceholder(html.Element message) {
    for (final notice in message.querySelectorAll(
      '.message_media_not_supported_wrap',
    )) {
      final hidden = _hasAncestor(
        notice,
        message,
        (e) =>
            e.classes.contains('media_not_supported_cont') ||
            e.classes.contains('tgme_widget_message_video_player') ||
            e.classes.contains('tgme_widget_message_roundvideo_player'),
      );
      if (!hidden) return true;
    }
    return false;
  }

  // ── Media ──────────────────────────────────────────────────────────────────

  /// Every piece of media in the post, in page order.
  ///
  /// [postLink] stands in for the file of a video, voice message or document
  /// the page does not link directly (too large, or not served to the web).
  static List<GuestMedia> _media(
    html.Element message, {
    required String postLink,
  }) {
    final found = <GuestMedia>[];

    void visit(html.Element element) {
      if (element.classes.any(_notThePost.contains)) return;
      final kind = _mediaKindOf(element);
      if (kind == null) {
        element.children.forEach(visit);
        return;
      }
      // A recognised block is read whole and not descended into, so a
      // player and the video inside it count once.
      final media = _readMedia(kind, element, postLink);
      if (media != null) found.add(media);
    }

    message.children.forEach(visit);
    return found;
  }

  /// Which kind of media block [element] is, if any.
  static GuestMediaKind? _mediaKindOf(html.Element element) {
    final classes = element.classes;
    for (final MapEntry(key: className, value: kind) in _mediaBlocks.entries) {
      if (classes.contains(className)) return kind;
    }
    return null;
  }

  /// The class that marks each media block. Bare wrappers are listed beside
  /// their players because a page can carry either.
  static const _mediaBlocks = {
    'tgme_widget_message_photo_wrap': GuestMediaKind.photo,
    'tgme_widget_message_video_player': GuestMediaKind.video,
    'tgme_widget_message_video_wrap': GuestMediaKind.video,
    'tgme_widget_message_roundvideo_player': GuestMediaKind.roundVideo,
    'tgme_widget_message_roundvideo_wrap': GuestMediaKind.roundVideo,
    'tgme_widget_message_voice_player': GuestMediaKind.voice,
    'tgme_widget_message_voice': GuestMediaKind.voice,
    'tgme_widget_message_document_wrap': GuestMediaKind.document,
    'tgme_widget_message_sticker_wrap': GuestMediaKind.sticker,
    'tgme_widget_message_sticker': GuestMediaKind.sticker,
    'tgme_widget_message_tgsticker': GuestMediaKind.sticker,
    'tgme_widget_message_videosticker': GuestMediaKind.sticker,
  };

  static GuestMedia? _readMedia(
    GuestMediaKind kind,
    html.Element element,
    String postLink,
  ) {
    // The block's own link, such as `t.me/<channel>/<n>?single` for one item
    // of an album, is more precise than the post's.
    final fallback = _https(element.attributes['href']) ?? postLink;

    switch (kind) {
      case GuestMediaKind.photo:
        final url =
            _backgroundUrl(element) ??
            _backgroundUrl(element.querySelector('.tgme_widget_message_photo'));
        if (url == null) return null;
        return GuestMedia(
          kind: kind,
          url: url,
          aspectRatio: _aspectRatio(element),
        );

      case GuestMediaKind.video:
        return GuestMedia(
          kind: kind,
          url: _https(_sourceOf(element, 'video')) ?? fallback,
          thumbnailUrl: _backgroundUrl(
            element.querySelector('.tgme_widget_message_video_thumb'),
          ),
          durationSec: _duration(
            element.querySelector('.message_video_duration'),
          ),
          aspectRatio: _aspectRatio(element),
        );

      case GuestMediaKind.roundVideo:
        return GuestMedia(
          kind: kind,
          url: _https(_sourceOf(element, 'video')) ?? fallback,
          thumbnailUrl: _backgroundUrl(
            element.querySelector('.tgme_widget_message_roundvideo_thumb'),
          ),
          durationSec: _duration(
            element.querySelector('.tgme_widget_message_roundvideo_duration'),
          ),
          aspectRatio: 1,
        );

      case GuestMediaKind.voice:
        return GuestMedia(
          kind: kind,
          url: _https(_sourceOf(element, 'audio')) ?? fallback,
          durationSec: _duration(
            element.querySelector('.tgme_widget_message_voice_duration'),
          ),
        );

      case GuestMediaKind.document:
        final name = _plainText(
          element.querySelector('.tgme_widget_message_document_title'),
        );
        return GuestMedia(
          kind: kind,
          url: fallback,
          fileName: name.isEmpty ? null : name,
        );

      case GuestMediaKind.sticker:
        final url = _stickerUrl(element);
        if (url == null) return null;
        return GuestMedia(
          kind: kind,
          url: url,
          aspectRatio: _aspectRatio(element),
        );
    }
  }

  /// A sticker's file. The visible image is a data: placeholder; the real
  /// file is a WebP in `data-webp`, a TGS in a `<source>`, or a WebM video.
  static String? _stickerUrl(html.Element element) {
    final withWebp = element.attributes.containsKey('data-webp')
        ? element
        : element.querySelector('[data-webp]');
    final candidates = [
      withWebp?.attributes['data-webp'],
      for (final source in element.querySelectorAll('source[srcset]'))
        source.attributes['srcset'],
      _sourceOf(element, 'video'),
      element.querySelector('img[src]')?.attributes['src'],
    ];
    return candidates.map(_https).nonNulls.firstOrNull ??
        _backgroundUrl(element);
  }

  /// The `src` of the first [tag] element at or under [element], or of a
  /// `<source>` inside it.
  static String? _sourceOf(html.Element element, String tag) {
    final media = element.localName == tag
        ? element
        : element.querySelector(tag);
    if (media == null) return null;
    return media.attributes['src'] ??
        media.querySelector('source[src]')?.attributes['src'];
  }

  /// Width over height, from whichever hint the markup carries: an explicit
  /// `data-ratio`, a `padding-top` percentage box, or pixel sizes.
  static double? _aspectRatio(html.Element element) {
    final ratio = double.tryParse(element.attributes['data-ratio'] ?? '');
    if (ratio != null && ratio > 0) return ratio;

    for (final box in [element, ...element.querySelectorAll('[style]')]) {
      final padding = _styleNumber(box, 'padding-top', '%');
      if (padding != null && padding > 0) return 100 / padding;
    }

    final width = _styleNumber(element, 'width', 'px');
    final height = _styleNumber(element, 'height', 'px');
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return null;
  }

  /// "1:35" or "1:02:03" as seconds.
  static int? _duration(html.Element? element) {
    final text = _plainText(element);
    if (text.isEmpty) return null;
    var seconds = 0;
    for (final part in text.split(':')) {
      final value = int.tryParse(part.trim());
      if (value == null) return null;
      seconds = seconds * 60 + value;
    }
    return seconds;
  }

  // ── Markup helpers ─────────────────────────────────────────────────────────

  /// Elements under [message] matching [selector] that belong to the post
  /// itself, not to a quoted reply, a link preview or a hidden fallback.
  static List<html.Element> _own(html.Element message, String selector) => [
    for (final element in message.querySelectorAll(selector))
      if (!_hasAncestor(
        element.parent,
        message,
        (e) => e.classes.any(_notThePost.contains),
      ))
        element,
  ];

  static html.Element? _ownFirst(html.Element message, String selector) =>
      _own(message, selector).firstOrNull;

  /// Whether [start] or any ancestor below [stop] satisfies [test].
  static bool _hasAncestor(
    html.Element? start,
    html.Element stop,
    bool Function(html.Element) test,
  ) {
    for (var e = start; e != null && !identical(e, stop); e = e.parent) {
      if (test(e)) return true;
    }
    return false;
  }

  /// Whether [inner] sits somewhere inside [outer].
  static bool _contains(html.Element outer, html.Element inner) {
    for (var e = inner.parent; e != null; e = e.parent) {
      if (identical(e, outer)) return true;
    }
    return false;
  }

  /// The text a reader sees: whitespace collapsed as a browser would, and a
  /// line break for each `<br>`.
  static String _plainText(html.Element? root) {
    if (root == null) return '';
    final buffer = StringBuffer();

    void write(html.Node node) {
      if (node is html.Text) {
        buffer.write(node.data.replaceAll(_collapsibleSpace, ' '));
      } else if (node is html.Element) {
        if (node.localName == 'br') {
          buffer.write('\n');
        } else {
          node.nodes.forEach(write);
        }
      }
    }

    root.nodes.forEach(write);
    return buffer
        .toString()
        .replaceAll(RegExp(' {2,}'), ' ')
        .replaceAll(RegExp(' ?\n ?'), '\n')
        .trim();
  }

  /// Source whitespace a browser folds into one space. Deliberately not
  /// `\s`, which would also fold the non-breaking spaces the page uses.
  static final _collapsibleSpace = RegExp(r'[ \t\r\n\f]+');

  /// The https URL in an inline `background-image:url('…')`, if any.
  static String? _backgroundUrl(html.Element? element) {
    final style = element?.attributes['style'];
    if (style == null) return null;
    final match = RegExp(
      r'''background-image\s*:\s*url\(\s*(['"]?)(.*?)\1\s*\)''',
    ).firstMatch(style);
    return _https(match?.group(2));
  }

  /// The numeric value of [property] in [element]'s inline style, when it is
  /// given in [unit].
  static double? _styleNumber(
    html.Element element,
    String property,
    String unit,
  ) {
    final style = element.attributes['style'];
    if (style == null) return null;
    final match = RegExp(
      '(?:^|;)\\s*${RegExp.escape(property)}\\s*:\\s*([0-9.]+)${RegExp.escape(unit)}',
    ).firstMatch(style);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  /// [raw] when it is an absolute https URL. A protocol-relative URL is read
  /// against the page, which is itself served over https.
  static String? _https(String? raw) {
    var value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('//')) value = 'https:$value';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return value;
  }

  static String _stripAt(String value) =>
      value.startsWith('@') ? value.substring(1) : value;
}
