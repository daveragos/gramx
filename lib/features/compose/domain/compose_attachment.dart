import 'package:flutter/foundation.dart';

/// The kinds of file this app can upload, with Telegram's per-kind rules for
/// albums, captions and self-destruct.
enum ComposeMediaKind {
  photo,
  video,

  /// Any other file, sent as-is.
  document,

  voiceNote,

  /// A round video message.
  videoNote;

  /// Whether `sendMessageAlbum` may group this with others of the same
  /// [albumFamily]. Voice and round video notes are always separate messages.
  bool get canGroup => this == photo || this == video || this == document;

  /// The album group this belongs to, or null. Photos and videos share one;
  /// documents have their own, and Telegram refuses mixing the two.
  int? get albumFamily => switch (this) {
    ComposeMediaKind.photo || ComposeMediaKind.video => 0,
    ComposeMediaKind.document => 1,
    _ => null,
  };

  /// Whether this can carry a caption (`inputMessageVideoNote` can't).
  bool get takesCaption => this != ComposeMediaKind.videoNote;

  /// Whether a self-destruct timer may be set (not on documents).
  bool get canSelfDestruct => this != ComposeMediaKind.document;
}

/// How long media survives after the recipient opens it: never ([none]), on
/// close ([viewOnce]), or after a timer. Mirrors TDLib's
/// `MessageSelfDestructType`. Telegram only allows this in private chats.
@immutable
class SelfDestruct {
  /// Telegram's maximum self-destruct timer, in seconds.
  static const int maxSeconds = 60;

  /// Ordinary media that doesn't self-destruct.
  static const SelfDestruct none = SelfDestruct._(
    seconds: 0,
    isViewOnce: false,
  );

  /// Deleted as soon as the recipient closes it.
  static const SelfDestruct viewOnce = SelfDestruct._(
    seconds: 0,
    isViewOnce: true,
  );

  /// The timer lengths the picker offers, in seconds.
  static const List<int> timerChoices = [5, 10, 30, 60];

  /// Seconds after opening before deletion. Zero for [none] and [viewOnce].
  final int seconds;

  /// True for view-once media, which has no countdown.
  final bool isViewOnce;

  const SelfDestruct._({required this.seconds, required this.isViewOnce});

  /// A countdown of [seconds], clamped to [maxSeconds].
  factory SelfDestruct.after(int seconds) {
    if (seconds <= 0) return none;
    return SelfDestruct._(
      seconds: seconds > maxSeconds ? maxSeconds : seconds,
      isViewOnce: false,
    );
  }

  /// Whether this media disappears at all.
  bool get isEnabled => isViewOnce || seconds > 0;

  @override
  bool operator ==(Object other) =>
      other is SelfDestruct &&
      other.seconds == seconds &&
      other.isViewOnce == isViewOnce;

  @override
  int get hashCode => Object.hash(seconds, isViewOnce);

  @override
  String toString() =>
      isViewOnce ? 'SelfDestruct.viewOnce' : 'SelfDestruct($seconds s)';
}

/// A picked file, measured and ready to send. Dimensions are read when the
/// file is picked, since `InputMessagePhoto` and `InputMessageVideo` need them.
@immutable
class ComposeAttachment {
  /// Absolute path to the file on disk.
  final String path;

  final ComposeMediaKind kind;

  final int width;
  final int height;

  /// Video length in whole seconds. Always 0 for a photo.
  final int durationSeconds;

  /// Size on disk, checked against Telegram's 10 MB photo limit.
  final int sizeBytes;

  /// The file name, for documents only.
  final String? fileName;

  /// The document's MIME type, when the picker could work one out.
  final String? mimeType;

  /// A voice message's waveform, one byte per sample. Recipients draw this
  /// rather than reading the audio. Empty for other kinds.
  final List<int> waveform;

  /// Self-destruct setting; always [SelfDestruct.none] outside private chats.
  final SelfDestruct selfDestruct;

  /// Whether the media arrives behind a tap-to-reveal cover. Telegram refuses
  /// this together with [selfDestruct]; see [canSpoiler].
  final bool hasSpoiler;

  const ComposeAttachment({
    required this.path,
    required this.kind,
    required this.width,
    required this.height,
    this.durationSeconds = 0,
    this.sizeBytes = 0,
    this.selfDestruct = SelfDestruct.none,
    this.hasSpoiler = false,
    this.fileName,
    this.mimeType,
    this.waveform = const [],
  });

  bool get isPhoto => kind == ComposeMediaKind.photo;
  bool get isVideo => kind == ComposeMediaKind.video;
  bool get isDocument => kind == ComposeMediaKind.document;
  bool get isVoiceNote => kind == ComposeMediaKind.voiceNote;
  bool get isVideoNote => kind == ComposeMediaKind.videoNote;

  /// Whether the composer shows a thumbnail. Documents show their name.
  bool get hasPreviewFrame => isPhoto || isVideo || isVideoNote;

  /// Whether a spoiler may be set (not on self-destructing media).
  bool get canSpoiler => !selfDestruct.isEnabled && (isPhoto || isVideo);

  /// True when the file's dimensions couldn't be read.
  bool get hasUnknownSize => width <= 0 || height <= 0;

  ComposeAttachment copyWith({SelfDestruct? selfDestruct, bool? hasSpoiler}) {
    final destruct = selfDestruct ?? this.selfDestruct;
    return ComposeAttachment(
      path: path,
      kind: kind,
      width: width,
      height: height,
      durationSeconds: durationSeconds,
      sizeBytes: sizeBytes,
      fileName: fileName,
      mimeType: mimeType,
      waveform: waveform,
      selfDestruct: destruct,
      // A timer clears the spoiler, since Telegram refuses both together.
      hasSpoiler: destruct.isEnabled ? false : (hasSpoiler ?? this.hasSpoiler),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ComposeAttachment &&
      other.path == path &&
      other.kind == kind &&
      other.width == width &&
      other.height == height &&
      other.durationSeconds == durationSeconds &&
      other.sizeBytes == sizeBytes &&
      other.fileName == fileName &&
      other.mimeType == mimeType &&
      listEquals(other.waveform, waveform) &&
      other.selfDestruct == selfDestruct &&
      other.hasSpoiler == hasSpoiler;

  @override
  int get hashCode => Object.hash(
    path,
    kind,
    width,
    height,
    durationSeconds,
    sizeBytes,
    fileName,
    mimeType,
    Object.hashAll(waveform),
    selfDestruct,
    hasSpoiler,
  );

  @override
  String toString() => 'ComposeAttachment(${kind.name}, $path)';
}
