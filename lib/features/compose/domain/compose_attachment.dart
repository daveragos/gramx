import 'package:flutter/foundation.dart';

/// The kinds of file this app can upload.
///
/// Each one answers three questions Telegram asks differently of each, and the
/// answers are here rather than at the call sites because getting one wrong is
/// silent: a caption that vanishes, or an album Telegram refuses with an error
/// that names no file.
enum ComposeMediaKind {
  photo,
  video,

  /// Any other file, sent as-is.
  document,

  /// A voice message: a waveform somebody holds a button to record.
  voiceNote,

  /// A round video message.
  videoNote;

  /// Whether `sendMessageAlbum` may group this with others *of the same
  /// family*.
  ///
  /// TDLib's rule, quoted: only audio, document, photo and video may be
  /// grouped, and documents may only be grouped with documents. A voice note
  /// or a round video note is always its own message.
  bool get canGroup => this == photo || this == video || this == document;

  /// Which pile this may be grouped with. Null for anything ungroupable.
  ///
  /// Photos and videos share one album; documents have their own. Mixing the
  /// two is refused by Telegram, so the composer sends them as separate
  /// messages instead.
  int? get albumFamily => switch (this) {
    ComposeMediaKind.photo || ComposeMediaKind.video => 0,
    ComposeMediaKind.document => 1,
    _ => null,
  };

  /// Whether Telegram lets this carry a caption at all.
  ///
  /// `inputMessageVideoNote` has no caption field — words typed beside one
  /// would be dropped without a word, which is the failure
  /// [ComposeDraft.stickerBlocksText] already guards for stickers.
  bool get takesCaption => this != ComposeMediaKind.videoNote;

  /// Whether a self-destruct timer may be set on this.
  ///
  /// Every media kind but a plain document: TDLib puts `selfDestructType` on
  /// photo, video, video note and voice note, and on nothing else.
  bool get canSelfDestruct => this != ComposeMediaKind.document;
}

/// How long a piece of media survives after the person it was sent to opens it.
///
/// Telegram's "view once" and its timer are the same TDLib field with two
/// shapes — [MessageSelfDestructType] is either "immediately" or a number of
/// seconds — so they are one type here rather than a bool and an int that can
/// disagree. [SelfDestruct.none] is the ordinary case and carries no timer at
/// all, which is what keeps `selfDestructType: null` on every message that is
/// not meant to disappear.
///
/// **Private chats only.** Telegram rejects a self-destructing message anywhere
/// else, so the control that sets this is not offered in a group or a channel
/// rather than being offered and failing on send.
@immutable
class SelfDestruct {
  /// Telegram's ceiling for a timed self-destruct, in seconds. A timer past it
  /// is refused outright.
  static const int maxSeconds = 60;

  /// Ordinary media. Stays where it is sent.
  static const SelfDestruct none = SelfDestruct._(
    seconds: 0,
    isViewOnce: false,
  );

  /// Gone the moment the viewer closes it, however long they looked.
  static const SelfDestruct viewOnce = SelfDestruct._(
    seconds: 0,
    isViewOnce: true,
  );

  /// The timer lengths the picker offers, in seconds. Telegram's own set.
  static const List<int> timerChoices = [5, 10, 30, 60];

  /// Seconds the viewer gets once they open it. Zero when this is [none] or
  /// [viewOnce].
  final int seconds;

  /// True for "view once": no countdown, gone on close.
  ///
  /// Named with the `is` prefix so it does not collide with the [viewOnce]
  /// constant beside it — the value and the predicate are different things.
  final bool isViewOnce;

  const SelfDestruct._({required this.seconds, required this.isViewOnce});

  /// A countdown of [seconds]. Clamped to Telegram's range, because a value
  /// outside it is refused with an error that does not say which field it meant.
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

  /// The name the file arrives under. Documents only — every other kind is
  /// named by Telegram from its type.
  final String? fileName;

  /// The document's MIME type, when the picker could work one out.
  final String? mimeType;

  /// The bars drawn under a voice message, one byte per sample.
  ///
  /// Telegram's own clients draw this and never re-read the audio for it, so a
  /// voice note sent with an empty waveform is a flat grey bar in every client
  /// that receives it. Empty for every other kind.
  final List<int> waveform;

  /// Whether this one disappears after it is opened. [SelfDestruct.none] for
  /// everything sent to a group, a channel, or Saved Messages — Telegram only
  /// takes a self-destructing message in a private chat.
  final SelfDestruct selfDestruct;

  /// Whether the media arrives blurred behind a tap-to-reveal cover.
  ///
  /// Nothing to do with [selfDestruct]: a spoiler still lives in the chat
  /// forever, it just is not the first thing somebody's eye lands on. Telegram
  /// refuses both flags on the same message, which [canSpoiler] enforces.
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

  /// Whether this one is drawn as a picture in the composer's strip. A document
  /// has no frame to show, so it gets a row with its name instead.
  bool get hasPreviewFrame => isPhoto || isVideo || isVideoNote;

  /// Whether a spoiler cover may be put over this.
  ///
  /// Media that destroys itself is already hidden behind a tap, and Telegram
  /// rejects the pair. The composer hides the toggle rather than offering one
  /// that would take the message down with it.
  bool get canSpoiler => !selfDestruct.isEnabled && (isPhoto || isVideo);

  /// True when the probe could not read the file's dimensions.
  ///
  /// Not fatal — TDLib accepts zeros and the server works the size out — but
  /// it is why the tile falls back to a square rather than the real aspect.
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
      // A timer wins over a spoiler rather than the two being sent together,
      // which Telegram refuses. Setting one clears the other here, at the one
      // place both are known, instead of at every control that sets either.
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
