import 'package:flutter/foundation.dart';

/// One page of a public channel's web preview: the channel and its posts.
@immutable
class GuestChannelPage {
  final GuestChannelInfo channel;

  /// The posts on the page, oldest first, as the page lists them.
  final List<GuestPost> posts;

  /// The lowest post number on the page, to pass back as `before=` for the
  /// page of older posts. Null when the page has no posts.
  final int? olderCursor;

  const GuestChannelPage({
    required this.channel,
    required this.posts,
    this.olderCursor,
  });
}

/// The channel header of a preview page.
@immutable
class GuestChannelInfo {
  final String username;
  final String title;
  final String description;

  /// An https URL, or null when the page shows no picture.
  final String? avatarUrl;

  /// The subscriber count exactly as the page prints it, such as "1.2M".
  final String? subscribers;
  final bool isVerified;

  const GuestChannelInfo({
    required this.username,
    required this.title,
    this.description = '',
    this.avatarUrl,
    this.subscribers,
    this.isVerified = false,
  });
}

/// A single channel post as the preview page shows it.
@immutable
class GuestPost {
  /// The page's own reference for the post, `<channel>/<number>`.
  final String id;

  /// The post number within its channel.
  final int seq;
  final DateTime publishedAt;

  /// Plain text with line breaks kept. Empty for a post without text.
  final String text;
  final List<GuestMedia> media;
  final GuestLinkPreview? linkPreview;
  final GuestForward? forwardedFrom;

  /// The view counter exactly as the page prints it, such as "12.3K".
  final String? views;
  final List<GuestReaction> reactions;

  /// True when the page shows its "open Telegram to view this post" notice
  /// in place of content it cannot draw.
  final bool isUnsupported;

  const GuestPost({
    required this.id,
    required this.seq,
    required this.publishedAt,
    this.text = '',
    this.media = const [],
    this.linkPreview,
    this.forwardedFrom,
    this.views,
    this.reactions = const [],
    this.isUnsupported = false,
  });
}

enum GuestMediaKind { photo, video, roundVideo, voice, document, sticker }

/// A piece of media attached to a post. Every URL here is https.
@immutable
class GuestMedia {
  final GuestMediaKind kind;

  /// The file itself where the page links it, otherwise the post's own link.
  final String url;

  /// Width divided by height, when the page gives a size.
  final double? aspectRatio;
  final int? durationSec;
  final String? thumbnailUrl;
  final String? fileName;

  const GuestMedia({
    required this.kind,
    required this.url,
    this.aspectRatio,
    this.durationSec,
    this.thumbnailUrl,
    this.fileName,
  });
}

/// The preview card the page draws under a post for the link it contains.
@immutable
class GuestLinkPreview {
  final String url;
  final String? siteName;
  final String? title;
  final String? description;
  final String? imageUrl;

  const GuestLinkPreview({
    required this.url,
    this.siteName,
    this.title,
    this.description,
    this.imageUrl,
  });
}

/// Where a forwarded post came from.
@immutable
class GuestForward {
  final String name;

  /// Set when the source is a public channel the page links to.
  final String? username;

  const GuestForward({required this.name, this.username});
}

/// One reaction chip under a post.
@immutable
class GuestReaction {
  final String emoji;
  final int count;

  /// Set for a custom emoji, whose artwork the page does not include.
  final String? customEmojiId;

  /// True for the paid (Telegram Stars) reaction.
  final bool isPaid;

  const GuestReaction({
    required this.emoji,
    required this.count,
    this.customEmojiId,
    this.isPaid = false,
  });
}
