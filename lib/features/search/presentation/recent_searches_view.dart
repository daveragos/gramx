import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/search/data/recent_searches.dart';

/// What the search page shows while the field is focused and empty, as on
/// X: the chats opened from search in a row, then the text searched.
class RecentSearchesView extends ConsumerWidget {
  /// Runs a recent search.
  final ValueChanged<String> onSearch;

  /// Puts a recent search in the field to edit, without running it.
  final ValueChanged<String> onFill;

  final double topPadding;
  final double bottomPadding;

  const RecentSearchesView({
    super.key,
    required this.onSearch,
    required this.onFill,
    required this.topPadding,
    required this.bottomPadding,
  });

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final clear = await showAppDialog<bool>(
      context,
      title: AppStrings.searchRecentClearConfirm,
      actions: const [
        AppDialogAction(
          label: AppStrings.searchRecentClearAction,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
        AppDialogAction.cancel(AppStrings.searchRecentKeep),
      ],
    );
    if (clear == true) await clearRecentSearches(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final chats = ref.watch(recentChatsProvider).value ?? const [];
    final queries = ref.watch(recentQueriesProvider);

    if (chats.isEmpty && queries.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          topPadding + AppSpacing.xxl,
          AppSpacing.xl,
          bottomPadding,
        ),
        child: Text(
          AppStrings.searchEmptyPrompt,
          textAlign: TextAlign.center,
          style: AppTypography.body(color: secondary),
        ),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.searchRecentTitle,
                  style: AppTypography.heading(color: primary),
                ),
              ),
              IconButton(
                tooltip: AppStrings.searchRecentClear,
                onPressed: () => _confirmClear(context, ref),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  minimumSize: const Size.square(32),
                  fixedSize: const Size.square(32),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(Icons.close_rounded, size: 18, color: primary),
              ),
            ],
          ),
        ),
        if (chats.isNotEmpty)
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: chats.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => _RecentChatTile(
                chat: chats[index],
                primary: primary,
                secondary: secondary,
              ),
            ),
          ),
        for (final query in queries)
          _RecentQueryRow(
            query: query,
            color: primary,
            onTap: () => onSearch(query),
            onFill: () => onFill(query),
          ),
      ],
    );
  }
}

/// A chat opened from search: its picture, name and handle.
class _RecentChatTile extends ConsumerWidget {
  final RecentChat chat;
  final Color primary;
  final Color secondary;

  const _RecentChatTile({
    required this.chat,
    required this.primary,
    required this.secondary,
  });

  void _open(BuildContext context, WidgetRef ref) {
    rememberSearch(ref, chatId: chat.chatId);
    switch (chat.kind) {
      case ResolvedChatKind.channel:
        NavigationUtils.openChannel(context, '${chat.chatId}');
      case ResolvedChatKind.person:
        context.push(UserProfileScreen.routeFor(chat.userId ?? chat.chatId));
      case ResolvedChatKind.group:
        context.push(ChatsScreen.routeFor(chat.chatId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = chat.username;
    return SizedBox(
      width: 84,
      child: Semantics(
        button: true,
        label: chat.title,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          onTap: () => _open(context, ref),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xs),
              ChannelAvatar(
                title: chat.title,
                avatarPath: chat.avatarPath,
                avatarFileId: chat.avatarFileId,
                radius: 32,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                chat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.timestamp(
                  color: primary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (username != null)
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.timestamp(color: secondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A search that was run: tapping it runs it again; the arrow puts it in
/// the field to change first.
class _RecentQueryRow extends StatelessWidget {
  final String query;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onFill;

  const _RecentQueryRow({
    required this.query,
    required this.color,
    required this.onTap,
    required this.onFill,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLarge(color: color),
              ),
            ),
            IconButton(
              tooltip: AppStrings.a11ySearchRecentFill(query),
              onPressed: onFill,
              icon: const Icon(
                Icons.north_west_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
