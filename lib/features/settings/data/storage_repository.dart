import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// How much space cached media is using, and how much a clear freed.
class StorageUsage {
  final int fileCount;
  final int totalBytes;

  const StorageUsage({required this.fileCount, required this.totalBytes});

  static const empty = StorageUsage(fileCount: 0, totalBytes: 0);

  bool get isEmpty => totalBytes <= 0;

  /// Human-readable size, e.g. `1.4 GB`. Binary units, matching what phone
  /// storage screens report.
  String get formattedSize => formatBytes(totalBytes);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final rounded = unit == 0 || value >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$rounded ${units[unit]}';
  }
}

/// Reads and clears TDLib's media cache.
///
/// The settings screen previously showed "Storage cache cleared." and deleted
/// nothing — `OptimizeStorage` was never called.
class StorageRepository {
  final TdlibService _tdlib;

  StorageRepository(this._tdlib);

  /// Current cache usage. Counts only downloaded media, not the message
  /// database, which is what a user means by "cache".
  Future<StorageUsage> usage() async {
    try {
      final res = await _tdlib.sendRequest(const td.GetStorageStatisticsFast());
      if (res is td.StorageStatisticsFast) {
        return StorageUsage(
          fileCount: res.fileCount,
          totalBytes: res.filesSize,
        );
      }
    } catch (e) {
      debugPrint('[Storage] Could not read usage: $e');
    }
    return StorageUsage.empty;
  }

  /// Deletes cached media and reports how much was actually freed.
  ///
  /// `size: 0` asks TDLib to bring the cache down to nothing. Passing -1 for
  /// the other limits leaves TDLib's own defaults in place.
  Future<StorageUsage> clear() async {
    final before = await usage();
    try {
      await _tdlib.sendRequest(
        const td.OptimizeStorage(
          size: 0,
          ttl: 0,
          count: 0,
          immunityDelay: 0,
          fileTypes: [],
          chatIds: [],
          excludeChatIds: [],
          returnDeletedFileStatistics: false,
          chatLimit: 0,
        ),
      );
    } catch (e) {
      debugPrint('[Storage] Clear failed: $e');
      return StorageUsage.empty;
    }

    final after = await usage();
    final freed = before.totalBytes - after.totalBytes;
    return StorageUsage(
      fileCount: before.fileCount - after.fileCount,
      totalBytes: freed > 0 ? freed : 0,
    );
  }
}

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => StorageRepository(ref.watch(tdlibServiceProvider)),
);

/// Cache usage for the settings row. Re-read after a clear.
final storageUsageProvider = FutureProvider<StorageUsage>(
  (ref) => ref.watch(storageRepositoryProvider).usage(),
);
