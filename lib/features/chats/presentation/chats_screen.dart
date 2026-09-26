import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/chats/data/affiliation_prefetcher.dart';
import 'package:gramx/features/chats/domain/chat_filter.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_actions_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_filter_menu.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_list_tile.dart';
import 'package:gramx/features/chats/presentation/widgets/chat_peek_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/new_chat_sheet.dart';
import 'package:gramx/features/chats/presentation/widgets/guest_messages_placeholder.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// The messages tab: every conversation this account is in.
///
/// Costs no TDLib requests to open or to scroll — the rows are read out of the
/// chat cache the update stream already fills. Only opening one costs anything.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  /// Where a conversation lives. Root-level, so it covers the shell the way the
  /// post and channel screens do rather than sitting under the bottom bar.
  static String routeFor(int chatId) => '/chat/$chatId';

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  /// Height the search row reserves inside the header.
  ///
  /// Measured, not guessed: the field's own dense content padding plus the
  /// prefix icon's minimum come to 48, and the padding around it adds 8 above
  /// and below. The scaffold needs the total up front — that number is how far
  /// the chrome has to travel — which is the same arrangement, and the same
  /// constraint, as the feed's folder strip.
  static const double _searchFieldHeight = 64;

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleMenu(ChatMenuAction action) async {
    switch (action) {
      case ChatMenuAction.settings:
        context.push('/settings');
      case ChatMenuAction.markAllRead:
        final marked = await ref.read(chatListProvider.notifier).markAllRead();
        if (!mounted || marked == 0) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.messagesAllReadDone),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // A guest has no account, so there is nobody for a message to be from.
    // The tab stays — ShellTab owns tab order and branch index — and says so.
    if (!ref.watch(readerCapabilitiesProvider).canMessage) {
      return const GuestMessagesPlaceholder();
    }

    // Re-tapping the tab you are already on means "take me back to the top".
    ref.listen<int>(chatsScrollToTopProvider, (_, _) => _scrollToTop());

    final chats = ref.watch(visibleChatsProvider);
    final isFiltered =
        ref.watch(chatFilterProvider) != ChatFilter.all ||
        ref.watch(chatSearchQueryProvider).isNotEmpty;

    return ChromeScaffold(
      header: ChromeHeaderRow(
        title: AppStrings.messagesTitle,
        centerTitle: true,
        leading: _AccountAvatar(),
        actions: [ChatFilterMenu(onAction: _handleMenu)],
      ),
      // The search field belongs to the header, not to the body. Sitting in
      // the body it was pinned below the space the header *used* to occupy, so
      // scrolling down took the title row, the bottom bar and the button away
      // and left the field floating under a band of nothing. As part of the
      // chrome it leaves with everything else — the feed's folder tabs are the
      // same arrangement for the same reason.
      headerBottomHeight: _searchFieldHeight,
      headerBottom: _SearchField(controller: _search),
      floatingActionButton: Padding(
        // Lifts the button clear of the bottom bar, which overlays the content
        // rather than sitting under it — so a FAB at the Scaffold's own
        // position is drawn *behind* the bar. `ComposeFab` has the same line
        // for the same reason.
        padding: const EdgeInsets.only(bottom: ShellChrome.bottomBarHeight),
        child: FloatingActionButton(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          tooltip: AppStrings.messagesNewChat,
          shape: const CircleBorder(),
          onPressed: () => NewChatSheet.show(context),
          child: const Icon(Icons.maps_ugc_outlined),
        ),
      ),
      body: (context, topPadding, bottomPadding) => chats.isEmpty
          ? Padding(
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              child: _EmptyState(
                isFiltered: isFiltered,
                onStart: isFiltered ? null : () => NewChatSheet.show(context),
              ),
            )
          : ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                // A row being built is a row about to be looked at, so the
                // channel this person runs is asked for now rather than when
                // their chat is opened. Deduped, spaced and capped — see
                // AffiliationPrefetcher for why this is not a fan-out.
                if (chat.kind == ChatKind.direct &&
                    chat.affiliatedChannelId == null) {
                  ref.read(affiliationPrefetcherProvider).request(chat.chatId);
                }
                return ChatListTile(
                  chat: chat,
                  onTap: () => context.push(ChatsScreen.routeFor(chat.chatId)),
                  onLongPress: () => ChatActionsSheet.show(context, chat),
                  onPeek: () => ChatPeekSheet.show(context, chat),
                  onAffiliatedChannelTap: chat.affiliatedChannelId == null
                      ? null
                      : () => NavigationUtils.openChannel(
                          context,
                          '${chat.affiliatedChannelId}',
                        ),
                );
              },
            ),
    );
  }
}

/// The account avatar, which opens the drawer — the same gesture and the same
/// place as on the feed.
class _AccountAvatar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider).value;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: ChannelAvatar(
        title: account?.displayName ?? AppStrings.drawerAccountFallback,
        avatarPath: account?.avatarPath,
        radius: AppSpacing.avatarSizeSmall / 2,
        onTap: openAppDrawer,
      ),
    );
  }
}

/// Filters what is loaded. Issues no request, so it needs no debounce — see
/// [ChatSearchQueryNotifier].
class _SearchField extends ConsumerWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final fill = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: controller,
        onChanged: ref.read(chatSearchQueryProvider.notifier).set,
        style: AppTypography.body(color: theme.colorScheme.onSurface),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: AppStrings.messagesSearchHint,
          hintStyle: AppTypography.body(color: secondary),
          prefixIcon: Icon(Icons.search_rounded, color: secondary, size: 22),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).modalBarrierDismissLabel,
                  icon: Icon(Icons.close_rounded, color: secondary, size: 18),
                  onPressed: () {
                    controller.clear();
                    ref.read(chatSearchQueryProvider.notifier).clear();
                  },
                ),
          filled: true,
          fillColor: fill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  /// Whether a filter or a search is why the list is empty. The two cases need
  /// different words: one is "you have no conversations", the other is "none of
  /// them match", and telling somebody the first when the second is true reads
  /// as the app having lost their messages.
  final bool isFiltered;

  /// Offered only in the genuinely-empty case. A "start a conversation" button
  /// under "nothing matches this filter" answers a question nobody asked.
  final VoidCallback? onStart;

  const _EmptyState({required this.isFiltered, this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered ? Icons.filter_list_off_rounded : Icons.forum_outlined,
              size: 44,
              color: secondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isFiltered
                  ? AppStrings.messagesEmptyFilteredTitle
                  : AppStrings.messagesEmptyTitle,
              style: AppTypography.subheading(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isFiltered
                  ? AppStrings.messagesEmptyFilteredBody
                  : AppStrings.messagesEmptyBody,
              style: AppTypography.body(color: secondary),
              textAlign: TextAlign.center,
            ),
            if (onStart != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.md,
                  ),
                ),
                onPressed: onStart,
                child: Text(
                  AppStrings.messagesStartOne,
                  style: AppTypography.button(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
