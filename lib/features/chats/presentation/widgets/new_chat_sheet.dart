import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';

/// Picks a chat to write to. Uses `SearchChats`, which TDLib runs offline over
/// already loaded chats, so typing sends no requests.
class NewChatSheet extends ConsumerStatefulWidget {
  const NewChatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.lg),
        ),
      ),
      builder: (_) => const NewChatSheet(),
    );
  }

  @override
  ConsumerState<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<NewChatSheet> {
  /// Debounce that coalesces a burst of keystrokes into one rebuild.
  static const Duration _settle = Duration(milliseconds: 200);

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<ChatSummary> _results = const [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Opens on the unfiltered list.
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_settle, () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final results = await ref
        .read(chatsRepositoryProvider)
        .searchChats(query, selfUserId: ref.read(selfUserIdProvider));
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final fill = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: secondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    AppStrings.messagesNewChat,
                    style: AppTypography.heading(color: primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                style: AppTypography.body(color: primary),
                decoration: InputDecoration(
                  hintText: AppStrings.messagesNewChatHint,
                  hintStyle: AppTypography.body(color: secondary),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: secondary,
                    size: 22,
                  ),
                  filled: true,
                  fillColor: fill,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: _isSearching
                          ? const CircularProgressIndicator(
                              color: AppColors.accent,
                            )
                          : Text(
                              AppStrings.messagesNoSearchResults,
                              style: AppTypography.body(color: secondary),
                            ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final chat = _results[index];
                        return ListTile(
                          leading: ChannelAvatar(
                            title: chat.title,
                            avatarPath: chat.avatarPath,
                            avatarFileId: chat.avatarFileId,
                            avatarColorHex: chat.avatarColorHex,
                            radius: AppSpacing.avatarSize / 2,
                          ),
                          title: Text(
                            chat.title,
                            style: AppTypography.displayName(color: primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: chat.username == null
                              ? null
                              : Text(
                                  '@${chat.username}',
                                  style: AppTypography.username(
                                    color: secondary,
                                  ),
                                ),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push(ChatsScreen.routeFor(chat.chatId));
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
