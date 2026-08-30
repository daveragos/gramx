import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Where a post has got to.
enum PostSendStatus { uploading, sent, failed }

/// One post on its way out, as the bar over the timeline shows it.
@immutable
class PostSendProgress {
  final PostSendStatus status;

  /// How much of the attached files has gone up, 0…1.
  ///
  /// Null means there is nothing to measure — a text post, or a sticker
  /// already on Telegram's servers. The bar runs indeterminate then, which is
  /// the honest drawing of "working, and I cannot tell you how far".
  final double? fraction;

  /// Where it is going, as the composer named it.
  final String targetLabel;

  const PostSendProgress({
    required this.status,
    required this.targetLabel,
    this.fraction,
  });

  PostSendProgress copyWith({PostSendStatus? status, double? fraction}) =>
      PostSendProgress(
        status: status ?? this.status,
        targetLabel: targetLabel,
        fraction: fraction ?? this.fraction,
      );

  @override
  bool operator ==(Object other) =>
      other is PostSendProgress &&
      other.status == status &&
      other.fraction == fraction &&
      other.targetLabel == targetLabel;

  @override
  int get hashCode => Object.hash(status, fraction, targetLabel);
}

/// How far the tracked files have got, as one number.
///
/// Pure, and separated out because it is the part with the arithmetic in it.
/// `expectedSize` is TDLib's estimate before it knows, and `size` is the truth
/// once it does — a file reports one or the other, so both are read.
@immutable
class UploadTally {
  /// Bytes uploaded per file id.
  final Map<int, int> uploaded;

  /// Total bytes per file id.
  final Map<int, int> total;

  const UploadTally({this.uploaded = const {}, this.total = const {}});

  /// Folds one file update in, ignoring files this post does not own.
  UploadTally apply(td.File file, Set<int> watched) {
    if (!watched.contains(file.id)) return this;

    final size = file.size > 0 ? file.size : file.expectedSize;
    return UploadTally(
      uploaded: {...uploaded, file.id: file.remote.uploadedSize},
      total: {...total, if (size > 0) file.id: size},
    );
  }

  /// The fraction to draw, or null while nothing has a size yet.
  ///
  /// Summed across files rather than averaged per file: three attachments of
  /// wildly different sizes should move the bar by what they actually cost,
  /// not a third each.
  double? get fraction {
    var done = 0;
    var expected = 0;
    for (final entry in total.entries) {
      expected += entry.value;
      done += (uploaded[entry.key] ?? 0).clamp(0, entry.value);
    }
    if (expected <= 0) return null;
    return (done / expected).clamp(0.0, 1.0);
  }
}

/// The post currently going out, and how far it has got.
///
/// gramX used to close the composer and say "Posted" the instant TDLib
/// *accepted* the send, which for a post with media is several seconds before
/// it is true.
///
/// Null when nothing is in flight, which is almost always.
class PostSendTracker extends Notifier<PostSendProgress?> {
  /// How long the finished bar stays up before clearing itself.
  ///
  /// Long enough to be seen, short enough that it is gone before it becomes
  /// furniture. A failure holds longer, because it asks for a decision.
  static const Duration sentLinger = Duration(milliseconds: 1600);
  static const Duration failedLinger = Duration(seconds: 5);

  StreamSubscription<td.UpdateFile>? _fileSub;
  StreamSubscription<td.TdObject>? _updateSub;
  Timer? _clearTimer;

  Set<int> _watchedFiles = const {};
  Set<int> _pendingMessages = const {};
  UploadTally _tally = const UploadTally();

  @override
  PostSendProgress? build() {
    ref.onDispose(_stop);
    return null;
  }

  /// Starts watching a post that TDLib has accepted.
  ///
  /// Called by the composer as it closes. A second post while one is in flight
  /// replaces the first: the bar shows one thing, and the newest send is the
  /// one the writer is waiting on.
  void track(ComposeSendResult result, {required String targetLabel}) {
    if (!result.accepted) return;
    _stop();

    _watchedFiles = result.fileIds.toSet();
    _pendingMessages = result.messageIds.toSet();
    _tally = const UploadTally();

    state = PostSendProgress(
      status: PostSendStatus.uploading,
      targetLabel: targetLabel,
      // A post with nothing to upload has no fraction to show, and never will.
      fraction: result.hasUpload ? 0 : null,
    );

    final tdlib = ref.read(tdlibServiceProvider);

    if (_watchedFiles.isNotEmpty) {
      _fileSub = tdlib.fileUpdates.listen(_onFile);
    }
    _updateSub = tdlib.updatesStream.listen(_onUpdate);
  }

  void _onFile(td.UpdateFile update) {
    final current = state;
    if (current == null || current.status != PostSendStatus.uploading) return;

    final next = _tally.apply(update.file, _watchedFiles);
    if (identical(next, _tally)) return;
    _tally = next;

    final fraction = next.fraction;
    if (fraction == null) return;
    // The last stretch belongs to the server, not to the wire: a file whose
    // bytes have all gone up is not a message that has been sent yet, and a
    // bar sitting full while nothing happens reads as stuck. Held just short
    // until the send is confirmed.
    state = current.copyWith(fraction: fraction.clamp(0.0, 0.98));
  }

  void _onUpdate(td.TdObject object) {
    final current = state;
    if (current == null || current.status != PostSendStatus.uploading) return;

    switch (object) {
      case td.UpdateMessageSendSucceeded():
        _pendingMessages = {..._pendingMessages}..remove(object.oldMessageId);
        // An album is several messages and is only done when the last of them
        // lands. Finishing on the first would flash "Posted" over an upload
        // still running.
        if (_pendingMessages.isNotEmpty) return;
        _finish(PostSendStatus.sent, sentLinger);

      case td.UpdateMessageSendFailed():
        if (!_pendingMessages.contains(object.oldMessageId)) return;
        _finish(PostSendStatus.failed, failedLinger);

      default:
        return;
    }
  }

  void _finish(PostSendStatus status, Duration linger) {
    state = PostSendProgress(
      status: status,
      targetLabel: state?.targetLabel ?? '',
      fraction: status == PostSendStatus.sent ? 1 : null,
    );
    _unsubscribe();
    _clearTimer = Timer(linger, clear);
  }

  /// Takes the bar away. Also the "dismiss" the failed state offers.
  void clear() {
    _stop();
    state = null;
  }

  void _unsubscribe() {
    _fileSub?.cancel();
    _fileSub = null;
    _updateSub?.cancel();
    _updateSub = null;
  }

  void _stop() {
    _unsubscribe();
    _clearTimer?.cancel();
    _clearTimer = null;
    _watchedFiles = const {};
    _pendingMessages = const {};
    _tally = const UploadTally();
  }
}

final postSendTrackerProvider =
    NotifierProvider<PostSendTracker, PostSendProgress?>(PostSendTracker.new);
