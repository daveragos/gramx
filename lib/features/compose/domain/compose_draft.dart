import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';

/// The maximum post length: one limit for text and a shorter one for a
/// caption. Both vary by account, so the real values come from
/// `ComposeRepository.lengthLimits`.
@immutable
class ComposeLengthLimits {
  /// `message_text_length_max`.
  final int text;

  /// `message_caption_length_max`.
  final int caption;

  const ComposeLengthLimits({required this.text, required this.caption});

  /// A free account's limits, used as the fallback since they are smaller.
  static const free = ComposeLengthLimits(text: 4096, caption: 1024);

  /// A Premium account's limits, for reference.
  static const premium = ComposeLengthLimits(text: 8192, caption: 4096);

  /// The limit that applies, given whether anything is attached.
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

/// Why Telegram would refuse a picked photo. Telegram reports all three as
/// `PHOTO_INVALID_DIMENSIONS`, so each gets its own message here.
enum ComposePhotoRejection {
  /// Over the size limit `InputMessagePhoto` documents.
  tooLarge,

  /// Width plus height over the limit.
  tooManyPixels,

  /// An aspect ratio wider than Telegram accepts.
  tooWide,
}

/// Telegram's limits on a post other than its length. The photo rules are
/// from TDLib's `inputMessagePhoto` documentation.
abstract class ComposeLimits {
  /// The most messages `SendMessageAlbum` can group.
  static const int maxAttachments = 10;

  /// Fewer than this and it is a plain message, not an album.
  static const int minAlbumAttachments = 2;

  /// Telegram rejects a photo larger than this.
  static const int maxPhotoBytes = 10 * 1024 * 1024;

  /// Limit on width plus height.
  static const int maxPhotoDimensionTotal = 10000;

  /// Limit on longest edge over shortest.
  static const int maxPhotoAspectRatio = 20;

  /// The longest edge a picked photo is scaled down to, matching Telegram's
  /// HD size. It also keeps photos under [maxPhotoDimensionTotal].
  static const int photoLongestEdge = 2560;

  /// Why Telegram would refuse [attachment], or null. Checked before upload;
  /// photos with unknown dimensions pass.
  static ComposePhotoRejection? photoRejection(ComposeAttachment attachment) {
    if (!attachment.isPhoto) return null;

    if (attachment.sizeBytes > maxPhotoBytes) {
      return ComposePhotoRejection.tooLarge;
    }
    if (attachment.hasUnknownSize) return null;

    if (attachment.width + attachment.height > maxPhotoDimensionTotal) {
      return ComposePhotoRejection.tooManyPixels;
    }

    final longest = math.max(attachment.width, attachment.height).toDouble();
    final shortest = math.min(attachment.width, attachment.height).toDouble();
    if (longest / shortest > maxPhotoAspectRatio) {
      return ComposePhotoRejection.tooWide;
    }

    return null;
  }
}

/// The compose screen's state and the rules for whether it may be sent.
@immutable
class ComposeDraft {
  /// The destination. Null while targets load or when there is none.
  final ComposeTarget? target;

  final String text;

  final List<ComposeAttachment> attachments;

  /// A sticker or GIF from the account's collection. Exclusive with
  /// [attachments], since Telegram can't put one in an album.
  final ComposeRemoteMedia? remote;

  /// True while a send is in flight.
  final bool isSending;

  /// The account's length limits, free-tier until TDLib answers.
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
  }) => ComposeDraft(
    target: target ?? this.target,
    text: text ?? this.text,
    attachments: attachments ?? this.attachments,
    remote: remote,
    isSending: isSending ?? this.isSending,
    limits: limits ?? this.limits,
  );

  /// Sets or clears the sticker or GIF, dropping any attachments.
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

  bool get hasAttachments => attachments.isNotEmpty;

  /// Whether the text is a caption rather than a message body, which decides
  /// the character limit. A GIF takes a caption; a sticker doesn't.
  bool get isCaptioned => hasAttachments || (remote?.takesCaption ?? false);

  String get trimmedText => text.trim();

  /// The applicable length limit; see [isCaptioned].
  int get characterLimit => limits.forDraft(hasMedia: isCaptioned);

  /// Characters left, negative when over the limit. Counted in UTF-16 code
  /// units, as Telegram counts them.
  int get remaining => characterLimit - text.length;

  bool get isOverLimit => remaining < 0;

  bool get isEmpty => trimmedText.isEmpty && !hasAttachments && remote == null;

  /// Whether another file may be attached (never with a sticker or GIF).
  bool get canAttachMore =>
      remote == null && attachments.length < ComposeLimits.maxAttachments;

  /// A sticker is chosen alongside text. `inputMessageSticker` has no caption,
  /// so posting is blocked rather than dropping the text.
  bool get stickerBlocksText =>
      remote?.isSticker == true && trimmedText.isNotEmpty;

  /// Whether the Post button is enabled.
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
