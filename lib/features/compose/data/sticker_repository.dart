import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// One row in the sticker picker's set strip.
@immutable
class ComposeStickerSet {
  final int id;
  final String title;

  /// File id of the set's thumbnail, or of its first cover when it has none.
  final int? iconFileId;

  const ComposeStickerSet({
    required this.id,
    required this.title,
    this.iconFileId,
  });

  @override
  bool operator ==(Object other) =>
      other is ComposeStickerSet &&
      other.id == id &&
      other.title == title &&
      other.iconFileId == iconFileId;

  @override
  int get hashCode => Object.hash(id, title, iconFileId);
}

/// The account's sticker and GIF collections.
///
/// `GetInstalledStickerSets` returns only set info, and each set's stickers
/// need a separate `GetStickerSet`. A set is fetched only when the user opens
/// it, to avoid one request per installed set.
class StickerRepository {
  final TdlibService _tdlib;

  StickerRepository(this._tdlib);

  /// The account's saved GIFs. TDLib keeps this list locally and updates it
  /// through `updateSavedAnimations`.
  Future<List<ComposeRemoteMedia>> savedGifs() async {
    try {
      final res = await _tdlib.sendRequest(const td.GetSavedAnimations());
      if (res is! td.Animations) return const [];
      return res.animations.map(animationToMedia).toList();
    } catch (e) {
      debugPrint('[Stickers] GetSavedAnimations failed: $e');
      return const [];
    }
  }

  /// The account's favourite stickers.
  Future<List<ComposeRemoteMedia>> favoriteStickers() =>
      _stickers(const td.GetFavoriteStickers(), 'GetFavoriteStickers');

  /// Recently sent stickers. `isAttached: true` would return stickers
  /// attached to photos instead.
  Future<List<ComposeRemoteMedia>> recentStickers() => _stickers(
    const td.GetRecentStickers(isAttached: false),
    'GetRecentStickers',
  );

  /// The installed sets, titles and icons only. See the class comment.
  Future<List<ComposeStickerSet>> installedSets() async {
    try {
      final res = await _tdlib.sendRequest(
        const td.GetInstalledStickerSets(stickerType: td.StickerTypeRegular()),
      );
      if (res is! td.StickerSets) return const [];

      return [
        for (final set in res.sets)
          ComposeStickerSet(
            id: set.id,
            title: set.title,
            iconFileId:
                set.thumbnail?.file.id ??
                (set.covers.isNotEmpty ? set.covers.first.sticker.id : null),
          ),
      ];
    } catch (e) {
      debugPrint('[Stickers] GetInstalledStickerSets failed: $e');
      return const [];
    }
  }

  /// The stickers in one set, fetched when the set is opened.
  Future<List<ComposeRemoteMedia>> stickerSet(int setId) async {
    try {
      final res = await _tdlib.sendRequest(td.GetStickerSet(setId: setId));
      if (res is! td.StickerSet) return const [];
      return res.stickers.map(stickerToMedia).toList();
    } catch (e) {
      debugPrint('[Stickers] GetStickerSet($setId) failed: $e');
      return const [];
    }
  }

  Future<List<ComposeRemoteMedia>> _stickers(
    td.TdFunction request,
    String label,
  ) async {
    try {
      final res = await _tdlib.sendRequest(request);
      if (res is! td.Stickers) return const [];
      return res.stickers.map(stickerToMedia).toList();
    } catch (e) {
      debugPrint('[Stickers] $label failed: $e');
      return const [];
    }
  }

  /// Maps a TDLib sticker to [ComposeRemoteMedia].
  static ComposeRemoteMedia stickerToMedia(td.Sticker sticker) =>
      ComposeRemoteMedia(
        fileId: sticker.sticker.id,
        kind: ComposeRemoteKind.sticker,
        width: sticker.width,
        height: sticker.height,
        emoji: sticker.emoji,
        thumbnailFileId: sticker.thumbnail?.file.id,
      );

  static ComposeRemoteMedia animationToMedia(td.Animation animation) =>
      ComposeRemoteMedia(
        fileId: animation.animation.id,
        kind: ComposeRemoteKind.animation,
        width: animation.width,
        height: animation.height,
        durationSeconds: animation.duration,
        thumbnailFileId: animation.thumbnail?.file.id,
      );
}

final stickerRepositoryProvider = Provider<StickerRepository>((ref) {
  return StickerRepository(ref.watch(tdlibServiceProvider));
});
