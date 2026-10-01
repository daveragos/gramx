import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/compose/data/sticker_repository.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';

/// Where the stickers on screen come from: the account's favourites or
/// recents, or one installed set.
sealed class StickerSource {
  const StickerSource();
}

class FavouriteStickers extends StickerSource {
  const FavouriteStickers();

  @override
  bool operator ==(Object other) => other is FavouriteStickers;

  @override
  int get hashCode => 0x5741;
}

class RecentStickers extends StickerSource {
  const RecentStickers();

  @override
  bool operator ==(Object other) => other is RecentStickers;

  @override
  int get hashCode => 0x5742;
}

class InstalledSet extends StickerSource {
  final int setId;

  const InstalledSet(this.setId);

  @override
  bool operator ==(Object other) =>
      other is InstalledSet && other.setId == setId;

  @override
  int get hashCode => setId.hashCode;
}

/// The account's saved GIFs, fetched only once the GIF tab is opened.
final savedGifsProvider = FutureProvider<List<ComposeRemoteMedia>>((ref) {
  return ref.watch(stickerRepositoryProvider).savedGifs();
});

/// The installed sets, titles and icons only, in one request. See
/// [StickerRepository].
final installedStickerSetsProvider = FutureProvider<List<ComposeStickerSet>>((
  ref,
) {
  return ref.watch(stickerRepositoryProvider).installedSets();
});

/// The stickers for one source. As a family, each set's `GetStickerSet` is
/// sent only when that set is first shown, not once per installed set.
final stickersProvider =
    FutureProvider.family<List<ComposeRemoteMedia>, StickerSource>((
      ref,
      source,
    ) {
      final repository = ref.watch(stickerRepositoryProvider);
      return switch (source) {
        FavouriteStickers() => repository.favoriteStickers(),
        RecentStickers() => repository.recentStickers(),
        InstalledSet(setId: final id) => repository.stickerSet(id),
      };
    });
