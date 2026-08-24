import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class FileDownloadProgressState {
  final int fileId;
  final int downloadedSize;
  final int totalSize;
  final bool isCompleted;
  final String? localPath;

  const FileDownloadProgressState({
    required this.fileId,
    this.downloadedSize = 0,
    this.totalSize = 0,
    this.isCompleted = false,
    this.localPath,
  });

  double get progress {
    if (isCompleted) return 1.0;
    if (totalSize > 0 && downloadedSize > 0) {
      return (downloadedSize / totalSize).clamp(0.01, 1.0);
    }
    return 0.0;
  }
}

/// Reactive stream provider tracking real-time TDLib download progress for a fileId.
final fileDownloadProgressProvider =
    StreamProvider.family<FileDownloadProgressState, int>((ref, fileId) async* {
  if (fileId == 0) {
    yield const FileDownloadProgressState(fileId: 0);
    return;
  }

  final tdlib = ref.watch(tdlibServiceProvider);

  // 1. Query initial file state
  try {
    final result = await tdlib.sendRequest(td.GetFile(fileId: fileId));
    if (result is td.File) {
      final isDone = result.local.isDownloadingCompleted && result.local.path.isNotEmpty;
      final total = result.expectedSize > 0 ? result.expectedSize : result.size;

      yield FileDownloadProgressState(
        fileId: fileId,
        downloadedSize: result.local.downloadedSize,
        totalSize: total,
        isCompleted: isDone,
        localPath: isDone ? result.local.path : null,
      );

      if (isDone) return;

      if (!result.local.isDownloadingActive) {
        await tdlib.sendRequest(td.DownloadFile(
          fileId: fileId,
          priority: 32,
          offset: 0,
          limit: 0,
          synchronous: false,
        ));
      }
    }
  } catch (_) {
    try {
      await tdlib.sendRequest(td.DownloadFile(
        fileId: fileId,
        priority: 32,
        offset: 0,
        limit: 0,
        synchronous: false,
      ));
    } catch (_) {}
  }

  // 2. Stream real-time progress updates from TDLib update stream
  await for (final update in tdlib.fileUpdates) {
    if (update.file.id == fileId) {
      final file = update.file;
      final isDone = file.local.isDownloadingCompleted && file.local.path.isNotEmpty;
      final total = file.expectedSize > 0 ? file.expectedSize : file.size;

      yield FileDownloadProgressState(
        fileId: fileId,
        downloadedSize: file.local.downloadedSize,
        totalSize: total,
        isCompleted: isDone,
        localPath: isDone ? file.local.path : null,
      );

      if (isDone) return;
    }
  }
});

/// Reactive stream of TDLib download progress for a fileId that never starts
/// or resumes a download itself — unlike [fileDownloadProgressProvider], which
/// issues a `DownloadFile` the moment it's watched. Use this for media that
/// must stay on-demand (audio, documents): the tap handler calls
/// `downloadFileWithPriority` explicitly, and this stream just reflects the
/// `UpdateFile` events that download produces.
final fileDownloadStatusProvider =
    StreamProvider.family<FileDownloadProgressState, int>((ref, fileId) async* {
  if (fileId == 0) {
    yield const FileDownloadProgressState(fileId: 0);
    return;
  }

  final tdlib = ref.watch(tdlibServiceProvider);

  try {
    final result = await tdlib.sendRequest(td.GetFile(fileId: fileId));
    if (result is td.File) {
      final isDone = result.local.isDownloadingCompleted && result.local.path.isNotEmpty;
      final total = result.expectedSize > 0 ? result.expectedSize : result.size;

      yield FileDownloadProgressState(
        fileId: fileId,
        downloadedSize: result.local.downloadedSize,
        totalSize: total,
        isCompleted: isDone,
        localPath: isDone ? result.local.path : null,
      );

      if (isDone) return;
    }
  } catch (_) {}

  await for (final update in tdlib.fileUpdates) {
    if (update.file.id == fileId) {
      final file = update.file;
      final isDone = file.local.isDownloadingCompleted && file.local.path.isNotEmpty;
      final total = file.expectedSize > 0 ? file.expectedSize : file.size;

      yield FileDownloadProgressState(
        fileId: fileId,
        downloadedSize: file.local.downloadedSize,
        totalSize: total,
        isCompleted: isDone,
        localPath: isDone ? file.local.path : null,
      );

      if (isDone) return;
    }
  }
});

/// Reactive provider that tracks a TDLib file download by its fileId and returns the completed local path.
final fileDownloadProvider =
    StreamProvider.family<String?, int>((ref, fileId) async* {
  final stateAsync = ref.watch(fileDownloadProgressProvider(fileId));
  yield stateAsync.value?.localPath;
});

/// Async file existence check that doesn't block the UI thread.
/// Use this instead of File.existsSync() in build methods.
final fileExistsProvider =
    FutureProvider.family<bool, String>((ref, path) async {
  if (path.isEmpty) return false;
  return File(path).exists();
});
