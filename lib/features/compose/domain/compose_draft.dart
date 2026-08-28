import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';

/// How long a post may be, which is two numbers and not one.
///
/// A post with no media is a *message*; the moment a photo joins it, the
/// writing becomes a *caption*, and Telegram caps captions far shorter. That is
/// the trap this class exists to make visible: a 2000-character draft that was
/// fine a second ago is rejected the instant a picture joins it, with a server
/// error that does not say why.
///
/// Both numbers also depend on the account. Telegram Premium raises the message
/// limit to 8192 and the caption limit to 4096 — four times the free caption
/// allowance — so a hardcoded pair would tell a paying subscriber they have a
/// quarter of the room they actually have. That is why the real values come
/// from TDLib (`ComposeRepository.lengthLimits`) and the constants here are only
/// the fallback for before it answers.
///
/// Source for the numbers: <https://limits.tginfo.me/en>, cross-checked against
/// the option names TDLib's own `inputMessageText` and `inputMessagePhoto`
/// documentation points at.
@immutable
class ComposeLengthLimits {
  /// `message_text_length_max`.
  final int text;

  /// `message_caption_length_max`.
  final int caption;

  const ComposeLengthLimits({required this.text, required this.caption});

  /// What a free account gets, and what the counter assumes until TDLib says
  /// otherwise. Chosen as the fallback because it is the *smaller* pair: it can
  /// only ever under-promise, never invite a writer past a limit they'd be
  /// bounced off.
  static const free = ComposeLengthLimits(text: 4096, caption: 1024);

  /// What Telegram Premium gets. Nothing branches on this — the live value is
  /// read from TDLib, which already knows which account it is signed in as.
  /// It is here to name what the fallback would be wrong by.
  static const premium = ComposeLengthLimits(text: 8192, caption: 4096);

  /// The one that applies, given whether anything is attached.
  int forDraft({required bool hasMedia}) => hasMedia ? caption : text;

  @override
  bool operator ==(Object other) =>
      other is ComposeLengthLimits &&
      other.text == text &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(text, caption);

  @override
  String toString() => 'ComposeLengthLimits(text: $text, caption: $caption)';
}

/// Why Telegram would refuse a picked photo.
///
/// Named rather than boolean because the three cases need three different
/// things said to the writer, and Telegram's own error for all of them is the
/// same unhelpful `PHOTO_INVALID_DIMENSIONS`.
enum ComposePhotoRejection {
  /// Over the byte ceiling `InputMessagePhoto` documents.
  tooLarge,

  /// Width plus height over the ceiling — a picture too big to compress.
  tooManyPixels,

  /// A panorama past the aspect ratio Telegram accepts.
  tooWide,
}

/// Telegram's limits on the shape of a post, other than its length.
///
/// The dimension rules come from TDLib's own `inputMessagePhoto` documentation
/// rather than from the limits page, because they are enforced by the API call
/// itself: *"The photo must be at most 10 MB in size. The photo's width and
/// height must not exceed 10000 in total. Width and height ratio must be at
/// most 20."*
abstract class ComposeLimits {
  /// `SendMessageAlbum` sends 2–10 messages grouped together. Telegram's cap,
  /// not a choice.
  static const int maxAttachments = 10;

  /// Fewer than this and it is a plain message, not an album.
  static const int minAlbumAttachments = 2;

  /// Telegram rejects a photo larger than this outright.
  static const int maxPhotoBytes = 10 * 1024 * 1024;

  /// Ceiling on width *plus* height, not on either alone.
  static const int maxPhotoDimensionTotal = 10000;

  /// Longest edge over shortest. A panorama past this is refused.
  static const int maxPhotoAspectRatio = 20;

  /// The longest edge a picked photo is scaled down to before sending.
  ///
  /// Telegram's own two compression tiers are 1280px (SD) and 2560px (HD); this
  /// is the HD one, so a gramX post looks like a post from the official app
  /// rather than a size nobody else uses. It also keeps the total comfortably
  /// under [maxPhotoDimensionTotal] on its own.
  static const int photoLongestEdge = 2560;

  /// Why Telegram would refuse [attachment], or null if it would take it.
  ///
  /// Answered here, before the upload, because Telegram answers it *after* —
  /// so without this the writer spends a 10 MB upload to be told no in terms
  /// that do not say which rule they broke.
  ///
  /// A file whose dimensions the probe could not read is let through: this
  /// cannot judge what it cannot measure, and refusing on a failed measurement
  /// would block a photo Telegram would have accepted.
  static ComposePhotoRejection? photoRejection(ComposeAttachment attachment) {
    if (!attachment.isPhoto) return null;

    if (attachment.sizeBytes > maxPhotoBytes) {
      return ComposePhotoRejection.tooLarge;
    }
    if (attachment.hasUnknownSize) return null;

    if (attachment.width + attachment.height > maxPhotoDimensionTotal) {
      return ComposePhotoRejection.tooManyPixels;
    }

    final longest =
        math.max(attachment.width, attachment.height).toDouble();
    final shortest = math.min(attachment.width, attachment.height).toDouble();
    if (longest / shortest > maxPhotoAspectRatio) {
      return ComposePhotoRejection.tooWide;
    }

    return null;
  }
}

/// Everything the compose screen is holding, and the rules for whether it may
/// be sent.
///
/// Pure and immutable, so "can this be posted" is answered by a test rather
/// than by tapping the button — which is the only way to find out otherwise,
/// and a bad way to find out about the caption limit above.
@immutable
class ComposeDraft {
  /// Where it is going. Null while the target list is still loading, or when
  /// this account can post nowhere at all.
  final ComposeTarget? target;

  final String text;

  final List<ComposeAttachment> attachments;

  /// A sticker or GIF from the account's own collection.
  ///
  /// Mutually exclusive with [attachments], and not by preference — Telegram
  /// cannot group a sticker or an animation into an album, so a post is either
  /// a set of uploaded files or exactly one of these.
  final ComposeRemoteMedia? remote;

  /// True while a send is in flight, so the Post button can refuse a second tap.
  final bool isSending;

  /// This account's real length limits. Defaults to the free tier, which is
  /// what the counter shows until TDLib answers with the account's own numbers.
  final ComposeLengthLimits limits;

  const ComposeDraft({
    this.target,
    this.text = '',
    this.attachments = const [],
    this.remote,
    this.isSending = false,
    this.limits = ComposeLengthLimits.free,
  });

  ComposeDraft copyWith({
    ComposeTarget? target,
    String? text,
    List<ComposeAttachment>? attachments,
    bool? isSending,
    ComposeLengthLimits? limits,
  }) =>
      ComposeDraft(
        target: target ?? this.target,
        text: text ?? this.text,
        attachments: attachments ?? this.attachments,
        remote: remote,
        isSending: isSending ?? this.isSending,
        limits: limits ?? this.limits,
      );

  /// Replaces the whole media selection with a sticker or GIF, or clears it.
  ///
  /// Its own method rather than a `copyWith` field because the two kinds of
  /// media are exclusive: setting one must drop the other, and a caller that
  /// has to remember that will eventually forget.
  ComposeDraft withRemote(ComposeRemoteMedia? next) => ComposeDraft(
        target: target,
        text: text,
        attachments: const [],
        remote: next,
        isSending: isSending,
        limits: limits,
      );

  /// Replaces the uploaded files, dropping any sticker or GIF.
  ComposeDraft withAttachments(List<ComposeAttachment> next) => ComposeDraft(
        target: target,
        text: text,
        attachments: next,
        remote: null,
        isSending: isSending,
        limits: limits,
      );

  /// Files picked off the device and waiting to upload.
  bool get hasAttachments => attachments.isNotEmpty;

  /// Whether the writing is a *caption* rather than a message body — which is
  /// what decides the character limit. A GIF takes one; a sticker takes none.
  bool get isCaptioned => hasAttachments || (remote?.takesCaption ?? false);

  /// The trimmed text actually sent. Trailing newlines from a keyboard's return
  /// key should not be the difference between an empty post and a valid one.
  String get trimmedText => text.trim();

  /// How long this draft is allowed to be. Changes with [isCaptioned] — see
  /// [ComposeLengthLimits].
  int get characterLimit => limits.forDraft(hasMedia: isCaptioned);

  /// Characters left. Negative once the draft is too long, which is what the
  /// counter turns red on.
  ///
  /// `String.length` is UTF-16 code units, which is exactly how Telegram counts
  /// a message — the same unit its entity offsets are expressed in. Counting
  /// grapheme clusters here would tell the writer they have room the server
  /// does not agree they have.
  int get remaining => characterLimit - text.length;

  bool get isOverLimit => remaining < 0;

  bool get isEmpty => trimmedText.isEmpty && !hasAttachments && remote == null;

  /// Whether one more file may be attached.
  ///
  /// Never, while a sticker or GIF is chosen: Telegram cannot group one into an
  /// album, so there is no post that holds both.
  bool get canAttachMore =>
      remote == null && attachments.length < ComposeLimits.maxAttachments;

  /// A sticker was chosen and there is writing that cannot go with it.
  ///
  /// `inputMessageSticker` has no caption field, so the text has nowhere to go.
  /// Sending anyway would mean silently dropping what somebody wrote, so this
  /// blocks the post instead and the screen says which two things disagree.
  bool get stickerBlocksText =>
      remote?.isSticker == true && trimmedText.isNotEmpty;

  /// The one question the Post button asks.
  ///
  /// Every way to be un-postable is visible on screen before the tap: no
  /// destination, nothing written, too long, a sticker with words on it, or a
  /// send already going.
  bool get canPost =>
      target != null &&
      !isEmpty &&
      !isOverLimit &&
      !isSending &&
      !stickerBlocksText;

  @override
  bool operator ==(Object other) =>
      other is ComposeDraft &&
      other.target == target &&
      other.text == text &&
      other.isSending == isSending &&
      other.limits == limits &&
      other.remote == remote &&
      listEquals(other.attachments, attachments);

  @override
  int get hashCode => Object.hash(
        target,
        text,
        isSending,
        limits,
        remote,
        Object.hashAll(attachments),
      );
}
