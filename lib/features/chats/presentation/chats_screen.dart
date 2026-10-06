import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/widgets/drawer_avatar_button.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
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

/// The messages tab: every conversation this account is in. Rows come from the
/// chat cache, so showing and scrolling the list costs no TDLib requests.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  /// The route for a conversation. Root-level, so it covers the bottom bar.
  static String routeFor(int chatId) => '/chat/$chatId';

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  /// Height the search row reserves inside the header: a 48 dense field plus
  /// 8 padding above and below. The scaffold needs it up front to know how far
  /// the chrome travels.
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
    // Guests can't message. The tab stays because ShellTab owns the tab order.
    if (!ref.watch(readerCapabilitiesProvider).canMessage) {
      return const GuestMessagesPlaceholder();
    }

    ref.listen<int>(chatsScrollToTopProvider, (_, _) => _scrollToTop());

    final chats = ref.watch(visibleChatsProvider);
    final isFiltered =
        ref.watch(chatFilterProvider) != ChatFilter.all ||
        ref.watch(chatSearchQueryProvider).isNotEmpty;

    return ChromeScaffold(
      header: ChromeHeaderRow(
        title: AppStrings.messagesTitle,
        centerTitle: true,
        leading: const DrawerAvatarButton(),
        actions: [ChatFilterMenu(onAction: _handleMenu)],
      ),
      // Part of the header so it scrolls away with the rest of the chrome.
      headerBottomHeight: _searchFieldHeight,
      headerBottom: _SearchField(controller: _search),
      floatingActionButton: Padding(
        // The bottom bar overlays the content, so lift the button above it.
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
                // Fetch the person's channel as the row comes into view.
                // AffiliationPrefetcher dedupes, spaces and caps the requests.
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

/// Filters the loaded chats. No request, so no debounce.
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
  /// Whether a filter or a search is why the list is empty, which needs
  /// different wording from having no conversations at all.
  final bool isFiltered;

  /// Offered only when there are no conversations at all.
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
