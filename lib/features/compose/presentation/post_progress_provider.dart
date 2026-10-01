import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

enum PostSendStatus { uploading, sent, failed }

/// One post on its way out, as shown in the bar over the timeline.
@immutable
class PostSendProgress {
  final PostSendStatus status;

  /// Upload progress, 0 to 1, or null when there is nothing to measure (an
  /// indeterminate bar).
  final double? fraction;

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

/// Upload progress across tracked files. A file reports either
/// `expectedSize` or `size`, so both are read.
@immutable
class UploadTally {
  final Map<int, int> uploaded;

  final Map<int, int> total;

  const UploadTally({this.uploaded = const {}, this.total = const {}});

  /// Folds one file update in, ignoring files this post doesn't own.
  UploadTally apply(td.File file, Set<int> watched) {
    if (!watched.contains(file.id)) return this;

    final size = file.size > 0 ? file.size : file.expectedSize;
    return UploadTally(
      uploaded: {...uploaded, file.id: file.remote.uploadedSize},
      total: {...total, if (size > 0) file.id: size},
    );
  }

  /// The fraction to draw, summed by bytes across files, or null while
  /// nothing has a size yet.
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

/// The post going out and its progress, or null. TDLib accepts a send
/// before its files upload, so this tracks the real upload and send.
class PostSendTracker extends Notifier<PostSendProgress?> {
  /// How long the finished bar stays up. Failures stay longer.
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

  /// Starts watching a post TDLib has accepted, replacing any earlier one.
  void track(ComposeSendResult result, {required String targetLabel}) {
    if (!result.accepted) return;
    _stop();

    _watchedFiles = result.fileIds.toSet();
    _pendingMessages = result.messageIds.toSet();
    _tally = const UploadTally();

    state = PostSendProgress(
      status: PostSendStatus.uploading,
      targetLabel: targetLabel,
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
    // Held short of full until the send is confirmed, so a full bar doesn't
    // sit there looking stuck.
    state = current.copyWith(fraction: fraction.clamp(0.0, 0.98));
  }

  void _onUpdate(td.TdObject object) {
    final current = state;
    if (current == null || current.status != PostSendStatus.uploading) return;

    switch (object) {
      case td.UpdateMessageSendSucceeded():
        _pendingMessages = {..._pendingMessages}..remove(object.oldMessageId);
        // An album is several messages, so wait for the last one.
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

  /// Removes the bar, also used to dismiss a failure.
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
