import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Reactive provider that tracks a TDLib file download by its fileId.
/// Emits the local file path once the download completes.
/// Automatically triggers high-priority TDLib download when requested.
final fileDownloadProvider =
    StreamProvider.family<String?, int>((ref, fileId) async* {
  if (fileId == 0) {
    yield null;
    return;
  }

  final tdlib = ref.watch(tdlibServiceProvider);

  // 1. Check current file state immediately via TDLib
  try {
    final result = await tdlib.sendRequest(td.GetFile(fileId: fileId));
    if (result is td.File) {
      if (result.local.isDownloadingCompleted &&
          result.local.path.isNotEmpty) {
        yield result.local.path;
        return;
      }
    }
  } catch (_) {
    // File state query failed, proceed to request download
  }

  // 2. Yield null initially (file downloading)
  yield null;

  // 3. Trigger viewport-aware download via SyncService
  final syncService = ref.watch(syncServiceProvider);
  syncService.downloadFileWithPriority(fileId, priority: 32);

  // 4. Listen for completed UpdateFile event for this specific fileId
  await for (final update in tdlib.fileUpdates) {
    if (update.file.id == fileId &&
        update.file.local.isDownloadingCompleted &&
        update.file.local.path.isNotEmpty) {
      yield update.file.local.path;
      return; // Download complete, cancel stream subscription
    }
  }
});

/// Async file existence check that doesn't block the UI thread.
/// Use this instead of File.existsSync() in build methods.
final fileExistsProvider =
    FutureProvider.family<bool, String>((ref, path) async {
  if (path.isEmpty) return false;
  return File(path).exists();
});
