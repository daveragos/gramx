import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// A picture from a post, as the JPEG Telegram keeps of it.
class TrokPicture {
  final Uint8List jpeg;
  final int width;
  final int height;

  /// Whether this is the picture of a link's preview rather than one the
  /// channel posted.
  final bool isLinkPreview;

  const TrokPicture(
    this.jpeg, {
    required this.width,
    required this.height,
    this.isLinkPreview = false,
  });
}

/// The pictures in a post, for Trok to look at along with its text. A post
/// that is only a photo is otherwise nothing but its channel to Trok.
abstract interface class TrokPictures {
  /// [post]'s photos and the covers of its videos and GIFs in order, or the
  /// picture of its link's preview. Empty when it has none.
  Future<List<TrokPicture>> of(Post post);
}

/// Picks each picture from the sizes Telegram already keeps, so nothing is
/// scaled or encoded on the phone.
class TdlibTrokPictures implements TrokPictures {
  /// The most pictures sent with one post.
  static const limit = 4;

  /// The largest picture sent, in bytes. Telegram's 800-pixel size of a
  /// photo is usually well under it.
  static const maxBytes = 150 * 1024;

  /// The most all of a post's pictures come to, leaving room in the request
  /// for the feed.
  static const totalBytes = 450 * 1024;

  /// Telegram's larger sizes add bytes and nothing Trok needs.
  static const maxSide = 1280;

  /// Text in a picture smaller than this is hard to make out.
  static const _readableSide = 640;

  /// An album is at most ten messages, sent one after another.
  static const _albumSize = 10;

  /// How long to wait for a picture to download before sending a smaller
  /// one already on the phone instead. Trok waits on it to answer.
  static const _downloadWait = Duration(seconds: 4);

  /// How long to wait for a picture with nothing smaller to fall back on,
  /// short of the question's own wait for its pictures.
  static const _lastWait = Duration(seconds: 6);

  final TdlibService _tdlib;

  TdlibTrokPictures(this._tdlib);

  @override
  Future<List<TrokPicture>> of(Post post) async {
    if (post.media.isEmpty && post.linkPreviewUrl == null) return const [];
    final files = [
      for (final message in await postMessages(_tdlib, post))
        if (_sourcesOf(message.content) case final sources
            when sources.isNotEmpty)
          sources,
    ].take(limit);
    final pictures = <TrokPicture>[];
    var bytes = 0;
    for (final picture in (await Future.wait(files.map(_picture))).nonNulls) {
      if (bytes + picture.jpeg.length > totalBytes) break;
      bytes += picture.jpeg.length;
      pictures.add(picture);
    }
    return pictures;
  }

  /// [post]'s message, or its album's messages in order.
  static Future<List<td.Message>> postMessages(
    TdlibService tdlib,
    Post post,
  ) async {
    final first = await tdlib.sendRequest(
      td.GetMessage(chatId: post.chatId, messageId: post.messageId),
    );
    if (first is! td.Message) return const [];
    final albumId = first.mediaAlbumId;
    if (albumId == 0) return [first];
    // A post is its album's first message; the rest come after it.
    final history = await tdlib.sendRequest(
      td.GetChatHistory(
        chatId: post.chatId,
        fromMessageId: post.messageId,
        offset: -_albumSize,
        limit: _albumSize + 1,
        onlyLocal: false,
      ),
    );
    final album = {
      first.id: first,
      if (history is td.Messages)
        for (final m in history.messages)
          if (m.mediaAlbumId == albumId) m.id: m,
    };
    return album.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  /// The files that could be sent for [content], best first, each with its
  /// size in pixels.
  static List<_Source> _sourcesOf(td.MessageContent content) {
    final (photo, isLinkPreview) = switch (content) {
      td.MessagePhoto(:final photo) => (photo, false),
      td.MessageText(:final linkPreview?) => (_photoOf(linkPreview.type), true),
      _ => (null, false),
    };
    if (photo != null) {
      _Source source(td.PhotoSize size) => (
        file: size.photo,
        width: size.width,
        height: size.height,
        isLinkPreview: isLinkPreview,
      );
      final readable = readableSize(photo.sizes);
      final held = heldSize(photo.sizes);
      return [
        if (readable != null) source(readable),
        if (held != null && held.photo.id != readable?.photo.id) source(held),
      ];
    }
    final thumbnail = switch (content) {
      td.MessageVideo(:final video) => video.thumbnail,
      td.MessageAnimation(:final animation) => animation.thumbnail,
      td.MessageDocument(:final document) => document.thumbnail,
      _ => null,
    };
    if (thumbnail == null || thumbnail.format is! td.ThumbnailFormatJpeg) {
      return const [];
    }
    return [
      (
        file: thumbnail.file,
        width: thumbnail.width,
        height: thumbnail.height,
        isLinkPreview: false,
      ),
    ];
  }

  /// The picture a link preview shows, for the kinds that have one.
  static td.Photo? _photoOf(td.LinkPreviewType type) => switch (type) {
    td.LinkPreviewTypeArticle(:final photo) => photo,
    td.LinkPreviewTypePhoto(:final photo) => photo,
    td.LinkPreviewTypeApp(:final photo) => photo,
    td.LinkPreviewTypeWebApp(:final photo) => photo,
    td.LinkPreviewTypeEmbeddedVideoPlayer(:final thumbnail) => thumbnail,
    td.LinkPreviewTypeEmbeddedAnimationPlayer(:final thumbnail) => thumbnail,
    td.LinkPreviewTypeEmbeddedAudioPlayer(:final thumbnail) => thumbnail,
    _ => null,
  };

  /// The size of a photo to send: the largest within [maxBytes] and
  /// [maxSide], or a smaller one already on the phone if it is big enough
  /// to read text in. TDLib lists sizes smallest first.
  @visibleForTesting
  static td.PhotoSize? readableSize(List<td.PhotoSize> sizes) {
    final fitting = [
      for (final size in sizes)
        if (_bytesOf(size.photo) <= maxBytes &&
            max(size.width, size.height) <= maxSide)
          size,
    ];
    for (final size in fitting.reversed) {
      if (max(size.width, size.height) < _readableSide) break;
      if (size.photo.local.isDownloadingCompleted) return size;
    }
    return fitting.lastOrNull;
  }

  /// The largest size of a photo within the limits that is already on the
  /// phone, such as the preview the feed showed, to send when the readable
  /// size is slow to arrive.
  @visibleForTesting
  static td.PhotoSize? heldSize(List<td.PhotoSize> sizes) => sizes
      .where(
        (size) =>
            size.photo.local.isDownloadingCompleted &&
            _bytesOf(size.photo) <= maxBytes &&
            max(size.width, size.height) <= maxSide,
      )
      .lastOrNull;

  static int _bytesOf(td.File file) =>
      file.size > 0 ? file.size : file.expectedSize;

  /// The first of [sources] that can be had: the best within
  /// [_downloadWait], or else one already on the phone.
  Future<TrokPicture?> _picture(List<_Source> sources) async {
    for (final (i, source) in sources.indexed) {
      try {
        // Returns at once when the file is already on the phone. The reader
        // is waiting, so it goes ahead of the feed's own downloads.
        final file = await _tdlib.sendRequest(
          td.DownloadFile(
            fileId: source.file.id,
            priority: 32,
            offset: 0,
            limit: 0,
            synchronous: true,
          ),
          timeout: i < sources.length - 1 ? _downloadWait : _lastWait,
        );
        if (file is! td.File || !file.local.isDownloadingCompleted) continue;
        final jpeg = await File(file.local.path).readAsBytes();
        if (jpeg.isEmpty || jpeg.length > maxBytes) continue;
        return TrokPicture(
          jpeg,
          width: source.width,
          height: source.height,
          isLinkPreview: source.isLinkPreview,
        );
      } on Object catch (e) {
        debugPrint('[Trok] picture ${source.file.id} failed: $e');
      }
    }
    return null;
  }
}

typedef _Source = ({td.File file, int width, int height, bool isLinkPreview});
