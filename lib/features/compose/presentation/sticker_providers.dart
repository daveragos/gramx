import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/compose/data/sticker_repository.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';

/// Where the stickers on screen are coming from.
///
/// Favourites and recents are lists Telegram keeps for the account; everything
/// else is one installed set, named by its id.
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
  bool operator ==(Object other) => other is InstalledSet && other.setId == setId;

  @override
  int get hashCode => setId.hashCode;
}

/// The account's saved GIFs. One request, and only once the GIF tab is opened —
/// a `FutureProvider` does not run until something watches it.
final savedGifsProvider = FutureProvider<List<ComposeRemoteMedia>>((ref) {
  return ref.watch(stickerRepositoryProvider).savedGifs();
});

/// The installed sets, titles and icons only — one request for the whole strip.
/// Deliberately not the stickers inside them; see [StickerRepository].
final installedStickerSetsProvider =
    FutureProvider<List<ComposeStickerSet>>((ref) {
  return ref.watch(stickerRepositoryProvider).installedSets();
});

/// The stickers for one source.
///
/// **This is the provider that keeps the picker off the request budget.** A
/// family is lazy: `stickersProvider(InstalledSet(id))` issues its
/// `GetStickerSet` the first time something watches *that* id and never again
/// while it stays alive. So opening the picker costs the sources actually shown
/// — not one request per installed set, which is the fan-out shape the channel
/// tabs already had to be taught to avoid.
final stickersProvider =
    FutureProvider.family<List<ComposeRemoteMedia>, StickerSource>(
        (ref, source) {
  final repository = ref.watch(stickerRepositoryProvider);
  return switch (source) {
    FavouriteStickers() => repository.favoriteStickers(),
    RecentStickers() => repository.recentStickers(),
    InstalledSet(setId: final id) => repository.stickerSet(id),
  };
});
