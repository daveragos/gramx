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

  /// File id of the set's thumbnail, or of its first cover when it has none —
  /// some sets ship no thumbnail and would otherwise draw as a blank square.
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

/// The account's own sticker and GIF collections.
///
/// **Every call here is bounded and user-driven, and one of them would be a
/// fan-out if it were not deferred.** `GetInstalledStickerSets` returns set
/// *info* — a title, a thumbnail and up to five covers — not the stickers. The
/// stickers of a set arrive only from `GetStickerSet`, one request per set, so
/// loading every installed set up front is a request per set for content
/// nobody asked to see. That is the same shape as the channel-profile tabs, and
/// it gets the same rule: **a set is fetched only when the reader opens it**,
/// and cached after.
class StickerRepository {
  final TdlibService _tdlib;

  StickerRepository(this._tdlib);

  /// The account's saved GIFs.
  ///
  /// One request. TDLib keeps this list locally and refreshes it through
  /// `updateSavedAnimations`, so it is cheap and stays current.
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

  /// Stickers the account has starred. One request.
  Future<List<ComposeRemoteMedia>> favoriteStickers() =>
      _stickers(const td.GetFavoriteStickers(), 'GetFavoriteStickers');

  /// Stickers the account has sent lately. One request.
  ///
  /// `isAttached: false` is the meaningful half — true would return stickers
  /// stuck onto photos, which is a different feature entirely.
  Future<List<ComposeRemoteMedia>> recentStickers() => _stickers(
        const td.GetRecentStickers(isAttached: false),
        'GetRecentStickers',
      );

  /// The sets the account has installed — titles and icons only.
  ///
  /// One request for the whole strip. Deliberately does **not** touch the
  /// stickers inside them; see the class comment.
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
            iconFileId: set.thumbnail?.file.id ??
                (set.covers.isNotEmpty ? set.covers.first.sticker.id : null),
          ),
      ];
    } catch (e) {
      debugPrint('[Stickers] GetInstalledStickerSets failed: $e');
      return const [];
    }
  }

  /// The stickers in one set. **One request, and only when a set is opened.**
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

  /// Flattens TDLib's sticker into what the composer carries.
  ///
  /// Pure, so the mapping is testable without a client.
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
