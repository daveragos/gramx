import 'dart:convert';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/guest/data/tme_page_parser.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';

/// Turns posts read from a channel's web preview into the app's own [Post].
///
/// A guest channel has no Telegram chat id, so each one gets a synthetic id
/// from a range no real chat can occupy.
abstract class GuestPostMapper {
  static const int syntheticIdFloor = -999999999;

  /// The top of the synthetic range. User ids are positive and real channel
  /// ids sit below -10^12, so the whole range is free.
  static const int _syntheticIdCeiling = -1000;

  /// Marks a post the preview page would not draw, as TDLib's type name does
  /// for a signed-in reader.
  static const String _unsupportedKind = 'webPreviewPlaceholder';

  /// The base an aspect ratio is scaled against to give [MediaItem] a size.
  static const int _aspectBase = 1000;

  /// A stable id for [username], the same for any letter case.
  ///
  /// Hashed with FNV-1a rather than `hashCode`, which may differ between runs
  /// and would orphan every bookmark made against the old id.
  static int syntheticChatId(String username) {
    const span = _syntheticIdCeiling - syntheticIdFloor + 1;
    return _syntheticIdCeiling - _fnv1a(username.toLowerCase()) % span;
  }

  static bool isSynthetic(int chatId) =>
      chatId >= syntheticIdFloor && chatId <= _syntheticIdCeiling;

  static List<Post> mapPage(GuestChannelPage page) {
    final chatId = syntheticChatId(page.channel.username);
    return [
      for (final post in page.posts)
        mapPost(post, page.channel, chatId: chatId),
    ];
  }

  static Post mapPost(GuestPost post, GuestChannelInfo channel, {int? chatId}) {
    final id = chatId ?? syntheticChatId(channel.username);
    final preview = post.linkPreview;
    final forward = post.forwardedFrom;

    return Post(
      id: '${id}_${post.seq}',
      chatId: id,
      channelId: '$id',
      messageId: post.seq,
      channelTitle: channel.title,
      channelUsername: channel.username.isEmpty ? null : channel.username,
      channelAvatarUrl: channel.avatarUrl,
      isChannelVerified: channel.isVerified,
      text: _text(post),
      media: [
        for (final (index, media) in post.media.indexed)
          _mediaItem(media, '${post.id}#$index'),
      ],
      publishedAt: post.publishedAt,
      viewCount: TmePageParser.parseCount(post.views ?? '') ?? 0,
      reactions: _reactions(post.reactions),
      // Read state belongs to an account; a guest has none to be behind on.
      isRead: true,
      linkPreviewUrl: preview?.url,
      linkPreviewTitle: preview?.title ?? preview?.siteName,
      linkPreviewDescription: preview?.description,
      linkPreviewImageUrl: preview?.imageUrl,
      forwardedFromTitle: forward?.name,
      forwardedFromUsername: forward?.username,
      unsupportedKind: post.isUnsupported ? _unsupportedKind : null,
    );
  }

  /// The public link to a guest post, `https://t.me/<username>/<number>`.
  ///
  /// The message id of a guest post is already the number in the link, so
  /// unlike a TDLib id it needs no shifting.
  static String? postLink(Post post) {
    final username = post.channelUsername?.trim();
    if (username == null || username.isEmpty || post.messageId <= 0) {
      return null;
    }
    return 'https://t.me/$username/${post.messageId}';
  }

  static String? _text(GuestPost post) {
    if (post.text.isNotEmpty) return post.text;
    return post.isUnsupported ? AppStrings.postUnsupported : null;
  }

  /// Counts by emoji. Custom emoji share one placeholder, so theirs add up.
  static Map<String, int> _reactions(List<GuestReaction> reactions) {
    final counts = <String, int>{};
    for (final reaction in reactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + reaction.count;
    }
    return counts;
  }

  static MediaItem _mediaItem(GuestMedia media, String id) {
    final ratio =
        media.aspectRatio ??
        (media.kind == GuestMediaKind.roundVideo ? 1.0 : null);

    return MediaItem(
      id: id,
      type: switch (media.kind) {
        GuestMediaKind.photo => MediaType.photo,
        GuestMediaKind.video || GuestMediaKind.roundVideo => MediaType.video,
        GuestMediaKind.voice => MediaType.voice,
        GuestMediaKind.document => MediaType.document,
        GuestMediaKind.sticker => MediaType.sticker,
      },
      url: media.url,
      thumbnailUrl: media.thumbnailUrl,
      width: ratio == null ? 0 : (ratio * _aspectBase).round(),
      height: ratio == null ? 0 : _aspectBase,
      duration: media.durationSec ?? 0,
      fileName: media.fileName,
      stickerFormat: media.kind == GuestMediaKind.sticker
          ? _stickerFormat(media.url)
          : StickerFormat.unknown,
    );
  }

  static StickerFormat _stickerFormat(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.webp')) return StickerFormat.webp;
    if (path.endsWith('.tgs')) return StickerFormat.tgs;
    if (path.endsWith('.webm')) return StickerFormat.webm;
    return StickerFormat.unknown;
  }

  /// 32-bit FNV-1a over the UTF-8 bytes of [text].
  static int _fnv1a(String text) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(text)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
