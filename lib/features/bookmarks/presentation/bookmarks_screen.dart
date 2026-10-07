import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/app_sheet.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/features/bookmarks/presentation/bookmark_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/guest/presentation/widgets/guest_bookmarks_placeholder.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  /// Restore and, once there are any, removal of restored bookmarks.
  Future<void> _showMore(
    BuildContext context,
    WidgetRef ref, {
    required int restoredCount,
  }) {
    return showAppSheet<void>(
      context,
      children: [
        AppSheetRow<void>(
          icon: Icons.restore_rounded,
          label: AppStrings.bookmarksRestore,
          onTap: () => _restore(context, ref),
        ),
        if (restoredCount > 0)
          AppSheetRow<void>(
            icon: Icons.bookmark_remove_outlined,
            label: AppStrings.bookmarksRemoveRestored,
            isDestructive: true,
            onTap: () => _removeRestored(context, ref, restoredCount),
          ),
      ],
    );
  }

  /// Finds what Saved Messages could restore, and adds it only if the user
  /// says so. It used to add every channel post there at a tap, the user's
  /// own saves included.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(feedRepositoryProvider);

    messenger.showSnackBar(
      const SnackBar(
        content: Text(AppStrings.bookmarksLooking),
        behavior: SnackBarBehavior.floating,
      ),
    );
    final found = await repo.findRestorableBookmarks();
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;

    if (found.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.bookmarksNothingToRestore),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final add = await showAppDialog<bool>(
      context,
      title: AppStrings.bookmarksRestoreTitle(found.length),
      body: AppStrings.bookmarksRestoreBody,
      actions: [
        AppDialogAction(
          label: AppStrings.bookmarksRestoreAction(found.length),
          value: true,
          isPrimary: true,
        ),
        const AppDialogAction.cancel(AppStrings.bookmarksRestoreCancel),
      ],
    );
    if (add != true) return;

    final added = await repo.addRestoredBookmarks(found);
    ref.invalidate(bookmarksProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.bookmarksRestored(added)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _removeRestored(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final remove = await showAppDialog<bool>(
      context,
      title: AppStrings.bookmarksRemoveRestoredTitle(count),
      body: AppStrings.bookmarksRemoveRestoredBody,
      actions: const [
        AppDialogAction(
          label: AppStrings.bookmarksRemoveRestoredAction,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
        AppDialogAction.cancel(AppStrings.bookmarksRemoveRestoredKeep),
      ],
    );
    if (remove != true) return;

    final removed = await ref
        .read(feedRepositoryProvider)
        .removeRestoredBookmarks();
    ref.read(bookmarkFilterProvider.notifier).set(BookmarkFilter.all);
    ref.invalidate(bookmarksProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.bookmarksRemovedRestored(removed)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bookmarks belong to an account; a guest sees a placeholder.
    if (!ref.watch(readerCapabilitiesProvider).canBookmark) {
      return const GuestBookmarksPlaceholder();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final postsAsync = ref.watch(bookmarkedPostsProvider);
    final restoredIds =
        ref.watch(bookmarksProvider).value?.restoredIds ?? const <String>{};
    final posts = postsAsync.value ?? const [];
    final restoredCount = posts.where((p) => restoredIds.contains(p.id)).length;
    final filter = restoredCount == 0
        ? BookmarkFilter.all
        : ref.watch(bookmarkFilterProvider);

    return ChromeScaffold(
      header: ChromeHeaderRow(
        title: AppStrings.bookmarksTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: AppStrings.bookmarksMore,
            onPressed: () =>
                _showMore(context, ref, restoredCount: restoredCount),
          ),
        ],
      ),
      // The filters only once there are restored bookmarks to tell apart.
      headerBottomHeight: restoredCount > 0 ? _FilterChips.height : 0,
      headerBottom: restoredCount > 0 ? _FilterChips(selected: filter) : null,
      body: (context, topPadding, bottomPadding) => postsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Text(AppStrings.bookmarksError(err)),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return _Empty(
              topPadding: topPadding,
              primary: primaryColor,
              secondary: secondaryColor,
            );
          }

          final shown = filterBookmarks(posts, restoredIds, filter);
          return RefreshIndicator(
            color: AppColors.accent,
            edgeOffset: topPadding,
            onRefresh: () => ref.refresh(bookmarksProvider.future),
            child: shown.isEmpty
                ? ListView(
                    padding: EdgeInsets.only(top: topPadding + AppSpacing.xxl),
                    children: [
                      Text(
                        AppStrings.bookmarksFilterEmpty,
                        textAlign: TextAlign.center,
                        style: AppTypography.body(color: secondaryColor),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      top: topPadding,
                      bottom: bottomPadding,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final post = shown[index];
                      return PostCard(
                        post: post,
                        onTap: () {
                          ref.read(markPostAsReadProvider(post.id));
                          context.push('/post/${post.id}');
                        },
                        onChannelTap: () => NavigationUtils.openChannel(
                          context,
                          post.channelId,
                        ),
                        onBookmarkTap: () => ref
                            .read(bookmarkControllerProvider.notifier)
                            .toggle(post),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

/// All, bookmarked here, or from Saved Messages.
class _FilterChips extends ConsumerWidget {
  static const double height = 48;

  final BookmarkFilter selected;

  const _FilterChips({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(String label, BookmarkFilter filter) => ChoiceChip(
      label: Text(label),
      selected: selected == filter,
      onSelected: (_) => ref.read(bookmarkFilterProvider.notifier).set(filter),
    );

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      children: [
        chip(AppStrings.bookmarksFilterAll, BookmarkFilter.all),
        const SizedBox(width: AppSpacing.sm),
        chip(AppStrings.bookmarksFilterHere, BookmarkFilter.here),
        const SizedBox(width: AppSpacing.sm),
        chip(AppStrings.bookmarksFilterRestored, BookmarkFilter.restored),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final double topPadding;
  final Color primary;
  final Color secondary;

  const _Empty({
    required this.topPadding,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.bookmark_outline,
                color: AppColors.accent,
                size: 80,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.bookmarksEmptyTitle,
                style: AppTypography.heading(
                  color: primary,
                ).copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.bookmarksEmptyBody,
                style: AppTypography.body(color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
