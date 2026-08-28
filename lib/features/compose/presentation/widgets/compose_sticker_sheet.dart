import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/presentation/sticker_providers.dart';

/// Picks a sticker or a GIF out of the account's own Telegram collection.
///
/// Two tabs, because they are two collections and Telegram keeps them apart.
/// The sticker tab has a source strip along the bottom — favourites, recents,
/// then one icon per installed set — which is Telegram's own arrangement and,
/// more importantly, the thing that keeps this off the request budget: a set's
/// stickers are fetched when its icon is tapped, never before.
class ComposeStickerSheet extends ConsumerStatefulWidget {
  /// Which tab to open on.
  final ComposeRemoteKind initialKind;

  const ComposeStickerSheet({super.key, required this.initialKind});

  /// Shows the sheet. Resolves to the chosen sticker or GIF, or null.
  static Future<ComposeRemoteMedia?> show(
    BuildContext context, {
    required ComposeRemoteKind initialKind,
  }) {
    return showModalBottomSheet<ComposeRemoteMedia>(
      context: context,
      // See mute_sheet.dart: the shell's bottom tab bar paints over each
      // branch's own Navigator, so this needs the root Navigator's Overlay.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ComposeStickerSheet(initialKind: initialKind),
    );
  }

  @override
  ConsumerState<ComposeStickerSheet> createState() =>
      _ComposeStickerSheetState();
}

class _ComposeStickerSheetState extends ConsumerState<ComposeStickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// Which sticker source is on screen. Only this one is ever fetched.
  StickerSource _source = const FavouriteStickers();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex:
          widget.initialKind == ComposeRemoteKind.animation ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _pick(ComposeRemoteMedia media) => Navigator.of(context).pop(media);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              indicatorColor: AppColors.accent,
              labelColor: primary,
              unselectedLabelColor: secondary,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: AppStrings.composeStickersTab),
                Tab(text: AppStrings.composeGifsTab),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _StickerTab(
                    source: _source,
                    onSourceChanged: (s) => setState(() => _source = s),
                    onPick: _pick,
                    secondary: secondary,
                  ),
                  _RemoteGrid(
                    // Lazy: the GIF list is not fetched until this tab is
                    // built, which is what makes the tab choice free.
                    itemsAsync: ref.watch(savedGifsProvider),
                    emptyMessage: AppStrings.composeNoGifs,
                    onPick: _pick,
                    secondary: secondary,
                    crossAxisCount: 3,
                    aspectRatio: 1.4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sticker half: a grid over a strip of sources.
class _StickerTab extends ConsumerWidget {
  final StickerSource source;
  final ValueChanged<StickerSource> onSourceChanged;
  final ValueChanged<ComposeRemoteMedia> onPick;
  final Color secondary;

  const _StickerTab({
    required this.source,
    required this.onSourceChanged,
    required this.onPick,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: _RemoteGrid(
            itemsAsync: ref.watch(stickersProvider(source)),
            emptyMessage: AppStrings.composeNoStickers,
            onPick: onPick,
            secondary: secondary,
            crossAxisCount: 4,
            aspectRatio: 1,
          ),
        ),
        _SourceStrip(
          selected: source,
          onSelected: onSourceChanged,
          secondary: secondary,
        ),
      ],
    );
  }
}

/// Favourites, recents, then one icon per installed set.
class _SourceStrip extends ConsumerWidget {
  static const double height = 56;

  final StickerSource selected;
  final ValueChanged<StickerSource> onSelected;
  final Color secondary;

  const _SourceStrip({
    required this.selected,
    required this.onSelected,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    // Titles and icons only — one request, no stickers fetched.
    final sets = ref.watch(installedStickerSetsProvider).value ?? const [];

    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        children: [
          _SourceButton(
            icon: Icons.star_rounded,
            tooltip: AppStrings.composeStickersFavourites,
            isSelected: selected is FavouriteStickers,
            onTap: () => onSelected(const FavouriteStickers()),
            secondary: secondary,
          ),
          _SourceButton(
            icon: Icons.history_rounded,
            tooltip: AppStrings.composeStickersRecent,
            isSelected: selected is RecentStickers,
            onTap: () => onSelected(const RecentStickers()),
            secondary: secondary,
          ),
          for (final set in sets)
            _SourceButton(
              iconFileId: set.iconFileId,
              tooltip: set.title,
              isSelected: selected == InstalledSet(set.id),
              onTap: () => onSelected(InstalledSet(set.id)),
              secondary: secondary,
            ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData? icon;
  final int? iconFileId;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;
  final Color secondary;

  const _SourceButton({
    this.icon,
    this.iconFileId,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          width: 44,
          margin: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppColors.accent : secondary,
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _RemoteThumbnail(fileId: iconFileId),
                ),
        ),
      ),
    );
  }
}

/// A grid of stickers or GIFs, in whatever state the fetch is in.
class _RemoteGrid extends StatelessWidget {
  final AsyncValue<List<ComposeRemoteMedia>> itemsAsync;
  final String emptyMessage;
  final ValueChanged<ComposeRemoteMedia> onPick;
  final Color secondary;
  final int crossAxisCount;
  final double aspectRatio;

  const _RemoteGrid({
    required this.itemsAsync,
    required this.emptyMessage,
    required this.onPick,
    required this.secondary,
    required this.crossAxisCount,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      // The repository already logs and answers with an empty list, so an
      // error here is only ever a programming fault — say the same thing an
      // empty collection says rather than showing a stack trace.
      error: (_, _) => _Empty(message: emptyMessage, secondary: secondary),
      data: (items) {
        if (items.isEmpty) {
          return _Empty(message: emptyMessage, secondary: secondary);
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.sm),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspectRatio,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Semantics(
              button: true,
              label: item.isSticker
                  ? AppStrings.a11ySticker(item.emoji)
                  : AppStrings.mediaGif,
              child: InkWell(
                onTap: () => onPick(item),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: _RemoteThumbnail(
                  // The thumbnail, not the sticker itself: it is a fraction of
                  // the size, and it is always WEBP or JPEG — so a grid of them
                  // costs little and never hits the TGS and WebM formats that
                  // Flutter's image decoder cannot read. See StickerTile.
                  fileId: item.thumbnailFileId ?? item.fileId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// One thumbnail, fetched by file id.
class _RemoteThumbnail extends ConsumerWidget {
  final int? fileId;

  const _RemoteThumbnail({required this.fileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = fileId;
    if (id == null || id == 0) return const SizedBox.shrink();

    final path = resolveMediaPath(ref, fileId: id);
    if (path == null || path.isEmpty) return const SizedBox.shrink();

    return Image.file(
      File(path),
      fit: BoxFit.contain,
      // A format the decoder will not read draws nothing rather than an error
      // glyph — the sticker is still perfectly sendable.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  final Color secondary;

  const _Empty({required this.message, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          message,
          style: AppTypography.body(color: secondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
