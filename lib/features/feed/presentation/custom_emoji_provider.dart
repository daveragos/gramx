import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// What is needed to draw one custom (premium) emoji.
class CustomEmoji {
  final int fileId;
  final StickerFormat format;

  /// Local path, once TDLib has fetched the file.
  final String? path;

  const CustomEmoji({required this.fileId, required this.format, this.path});

  bool get isReady => path != null && path!.isNotEmpty;
}

/// Resolves custom emoji ids to drawable stickers. A message carries only the
/// id, so the artwork is fetched separately, in batches, once per session.
class CustomEmojiNotifier extends Notifier<Map<int, CustomEmoji>> {
  /// TDLib caps one `GetCustomEmojiStickers` call at 200 ids.
  static const int maxIdsPerRequest = 200;

  /// How long to gather ids before asking. Cards build in bursts as the feed
  /// scrolls, so a short wait turns many lookups into one.
  static const Duration batchWindow = Duration(milliseconds: 120);

  final Set<int> _pending = {};
  final Set<int> _requested = {};
  Timer? _batchTimer;
  StreamSubscription<td.UpdateFile>? _fileSub;

  @override
  Map<int, CustomEmoji> build() {
    // Swap the glyph in as soon as its file is on disk.
    _fileSub = ref.watch(tdlibServiceProvider).fileUpdates.listen(_onFileReady);

    ref.onDispose(() {
      _batchTimer?.cancel();
      _fileSub?.cancel();
    });

    return const {};
  }

  /// Asks for [ids] to be resolved. Safe to call on every build.
  void request(Iterable<int> ids) {
    var added = false;
    for (final id in ids) {
      if (id == 0) continue;
      if (_requested.contains(id) || state.containsKey(id)) continue;
      if (_pending.add(id)) added = true;
    }
    if (!added) return;

    _batchTimer?.cancel();
    _batchTimer = Timer(batchWindow, _flush);
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final batch = _pending.take(maxIdsPerRequest).toList();
    _pending.removeAll(batch);
    _requested.addAll(batch);

    try {
      final res = await ref
          .read(tdlibServiceProvider)
          .sendRequest(td.GetCustomEmojiStickers(customEmojiIds: batch));
      if (res is! td.Stickers) return;

      final sync = ref.read(syncServiceProvider);
      final resolved = <int, CustomEmoji>{};

      for (final sticker in res.stickers) {
        final fullType = sticker.fullType;
        if (fullType is! td.StickerFullTypeCustomEmoji) continue;

        final file = sticker.sticker;
        final path =
            file.local.isDownloadingCompleted && file.local.path.isNotEmpty
            ? file.local.path
            : null;

        resolved[fullType.customEmojiId] = CustomEmoji(
          fileId: file.id,
          format: StickerFormat.fromTdName(sticker.format.currentObjectId),
          path: path,
        );

        if (path == null) sync.downloadFileWithPriority(file.id, priority: 16);
      }

      if (resolved.isNotEmpty) state = {...state, ...resolved};
    } catch (e) {
      debugPrint('[CustomEmoji] Could not resolve batch: $e');
      // Allow a retry later.
      _requested.removeAll(batch);
    }

    if (_pending.isNotEmpty) unawaited(_flush());
  }

  void _onFileReady(td.UpdateFile update) {
    final file = update.file;
    if (!file.local.isDownloadingCompleted || file.local.path.isEmpty) return;

    var changed = false;
    final next = <int, CustomEmoji>{};
    for (final entry in state.entries) {
      if (entry.value.fileId == file.id && !entry.value.isReady) {
        next[entry.key] = CustomEmoji(
          fileId: entry.value.fileId,
          format: entry.value.format,
          path: file.local.path,
        );
        changed = true;
      } else {
        next[entry.key] = entry.value;
      }
    }
    if (changed) state = next;
  }
}

final customEmojiProvider =
    NotifierProvider<CustomEmojiNotifier, Map<int, CustomEmoji>>(
      CustomEmojiNotifier.new,
    );
