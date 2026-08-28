import 'package:flutter/foundation.dart';

/// The two things a post can carry. Telegram has a dozen more, but a picker
/// that offers what this app can actually upload is the honest one.
enum ComposeMediaKind { photo, video }

/// A file picked off the device, measured and ready to hand to TDLib.
///
/// Dimensions are carried rather than looked up at send time because
/// `InputMessagePhoto` and `InputMessageVideo` both require them: a photo sent
/// with no size renders as a grey box in every client until the bytes arrive.
/// [ComposeMediaProbe] fills them in when the file is picked, which is the one
/// moment the app is allowed to be slow.
@immutable
class ComposeAttachment {
  /// Absolute path to the file on disk.
  final String path;

  final ComposeMediaKind kind;

  final int width;
  final int height;

  /// Video length in whole seconds. Always 0 for a photo.
  final int durationSeconds;

  /// Size on disk, checked against Telegram's 10 MB photo ceiling.
  final int sizeBytes;

  const ComposeAttachment({
    required this.path,
    required this.kind,
    required this.width,
    required this.height,
    this.durationSeconds = 0,
    this.sizeBytes = 0,
  });

  bool get isPhoto => kind == ComposeMediaKind.photo;
  bool get isVideo => kind == ComposeMediaKind.video;

  /// True when the probe could not read the file's dimensions.
  ///
  /// Not fatal — TDLib accepts zeros and the server works the size out — but
  /// it is why the tile falls back to a square rather than the real aspect.
  bool get hasUnknownSize => width <= 0 || height <= 0;

  @override
  bool operator ==(Object other) =>
      other is ComposeAttachment &&
      other.path == path &&
      other.kind == kind &&
      other.width == width &&
      other.height == height &&
      other.durationSeconds == durationSeconds &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode =>
      Object.hash(path, kind, width, height, durationSeconds, sizeBytes);

  @override
  String toString() => 'ComposeAttachment(${kind.name}, $path)';
}
