import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/trok/data/trok_pictures.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// What a post's file is, as Trok's server names it.
enum TrokFileType {
  video('video'),
  gif('gif'),
  roundVideo('round_video'),
  voice('voice');

  final String wire;

  const TrokFileType(this.wire);
}

/// A post's file once Trok's server holds it, as `post.files` names it.
typedef TrokSentFile = ({String fileId, TrokFileType type});

/// A post's own video or voice note, short enough for Trok to watch or hear.
class TrokPostFile {
  /// TDLib's id for the file.
  final int fileId;
  final TrokFileType type;
  final String mimeType;
  final String name;

  const TrokPostFile({
    required this.fileId,
    required this.type,
    required this.mimeType,
    required this.name,
  });
}

/// A post's videos and voice notes, for Trok to watch and hear. Pictures go
/// as `images` instead; see [TrokPictures].
abstract interface class TrokPostFiles {
  /// [post]'s own videos, GIFs, round videos and voice notes that Trok
  /// takes, in order. Empty when it has none.
  Future<List<TrokPostFile>> of(Post post);

  /// [file] on the phone, downloaded first if need be. Null when it can't
  /// be had, or turns out too big.
  Future<File?> local(TrokPostFile file);
}

/// Finds a post's files with TDLib and downloads them through it.
class TdlibTrokPostFiles implements TrokPostFiles {
  /// The most files sent with one post.
  static const limit = 2;

  /// The largest file Trok takes.
  static const maxBytes = 20 * 1000 * 1000;

  /// Longer videos go as their cover, in `images`.
  static const maxVideoSeconds = 60;

  static const maxVoiceSeconds = 5 * 60;

  /// The types Trok reads, with the extension a file of each gets when it
  /// has no name of its own.
  static const _extensions = {
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'video/webm': 'webm',
    'audio/ogg': 'ogg',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
  };

  /// How long a download may take before the question goes without it.
  static const _downloadWait = Duration(seconds: 60);

  final TdlibService _tdlib;

  TdlibTrokPostFiles(this._tdlib);

  @override
  Future<List<TrokPostFile>> of(Post post) async {
    const kinds = {MediaType.video, MediaType.gif, MediaType.voice};
    if (!post.media.any((m) => kinds.contains(m.type))) return const [];
    final messages = await TdlibTrokPictures.postMessages(_tdlib, post);
    return [
      for (final message in messages) ?fileOf(message.content),
    ].take(limit).toList();
  }

  /// The file Trok would take from [content], if any.
  @visibleForTesting
  static TrokPostFile? fileOf(td.MessageContent content) {
    final (file, type, mimeType, seconds, name) = switch (content) {
      td.MessageVideo(:final video) => (
        video.video,
        TrokFileType.video,
        video.mimeType,
        video.duration,
        video.fileName,
      ),
      td.MessageAnimation(:final animation) => (
        animation.animation,
        TrokFileType.gif,
        animation.mimeType,
        animation.duration,
        animation.fileName,
      ),
      // Telegram records round videos as MP4 and gives no type.
      td.MessageVideoNote(:final videoNote) => (
        videoNote.video,
        TrokFileType.roundVideo,
        'video/mp4',
        videoNote.duration,
        '',
      ),
      td.MessageVoiceNote(:final voiceNote) => (
        voiceNote.voice,
        TrokFileType.voice,
        voiceNote.mimeType,
        voiceNote.duration,
        '',
      ),
      _ => (null, TrokFileType.video, '', 0, ''),
    };
    if (file == null) return null;
    final mime = mimeType.toLowerCase();
    final extension = _extensions[mime];
    if (extension == null) return null;
    final longest = type == TrokFileType.voice
        ? maxVoiceSeconds
        : maxVideoSeconds;
    if (seconds > longest) return null;
    final bytes = file.size > 0 ? file.size : file.expectedSize;
    if (bytes > maxBytes) return null;
    return TrokPostFile(
      fileId: file.id,
      type: type,
      mimeType: mime,
      name: name.trim().isEmpty ? '${type.wire}.$extension' : name.trim(),
    );
  }

  @override
  Future<File?> local(TrokPostFile file) async {
    try {
      // Returns at once when the file is already on the phone. The reader
      // is waiting, so it goes ahead of the feed's own downloads.
      final downloaded = await _tdlib.sendRequest(
        td.DownloadFile(
          fileId: file.fileId,
          priority: 32,
          offset: 0,
          limit: 0,
          synchronous: true,
        ),
        timeout: _downloadWait,
      );
      if (downloaded is! td.File || !downloaded.local.isDownloadingCompleted) {
        return null;
      }
      final local = File(downloaded.local.path);
      final size = await local.length();
      return size > 0 && size <= maxBytes ? local : null;
    } on Object catch (e) {
      debugPrint('[Trok] file ${file.fileId} failed: $e');
      return null;
    }
  }
}
