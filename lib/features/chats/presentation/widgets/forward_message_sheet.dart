import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/chats/data/chat_list_builder.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';

/// Picks the destination chat for forwarding a message. Lists
/// `ChatCache.forwardTargets` (chats the account can write in), so opening it
/// sends no requests.
class ForwardMessageSheet extends ConsumerStatefulWidget {
  const ForwardMessageSheet({super.key});

  /// Returns the chosen chat id, or null if the sheet was dismissed.
  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.lg),
        ),
      ),
      builder: (_) => const ForwardMessageSheet(),
    );
  }

  @override
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final fill = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;

    // Filters locally, so typing sends no requests.
    final targets = ChatListBuilder.filter(
      ref
          .watch(chatsRepositoryProvider)
          .forwardTargets(selfUserId: ref.watch(selfUserIdProvider)),
      query: _query,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
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
                    AppStrings.forwardTitle,
                    style: AppTypography.heading(color: primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                style: AppTypography.body(color: primary),
                decoration: InputDecoration(
                  hintText: AppStrings.forwardSearchHint,
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
              child: targets.isEmpty
                  ? Center(
                      child: Text(
                        AppStrings.forwardNoChats,
                        style: AppTypography.body(color: secondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: targets.length,
                      itemBuilder: (context, index) =>
                          _TargetRow(target: targets[index], primary: primary),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  final ChatSummary target;
  final Color primary;

  const _TargetRow({required this.target, required this.primary});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ChannelAvatar(
        title: target.title,
        avatarPath: target.avatarPath,
        avatarFileId: target.avatarFileId,
        avatarColorHex: target.avatarColorHex,
        radius: AppSpacing.avatarSize / 2,
      ),
      title: Text(
        target.title,
        style: AppTypography.displayName(color: primary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(context).pop(target.chatId),
    );
  }
}
