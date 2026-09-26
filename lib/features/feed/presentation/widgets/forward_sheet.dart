import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';

/// Picks a chat to forward a post into.
///
/// Destinations come from [ChatCache], which already holds every chat TDLib
/// volunteered — so opening this costs no requests.
class ForwardSheet extends ConsumerStatefulWidget {
  final Post post;

  const ForwardSheet({super.key, required this.post});

  /// Shows the sheet and reports whether a forward actually happened.
  static Future<bool> show(BuildContext context, Post post) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      // See mute_sheet.dart: the shell's bottom tab bar paints over each
      // branch's own Navigator, so this needs the root Navigator's Overlay
      // to actually sit above it instead of underneath.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ForwardSheet(post: post),
    );
    return sent ?? false;
  }

  @override
  ConsumerState<ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<ForwardSheet> {
  String _query = '';
  int? _sendingTo;

  Future<void> _forward(td.Chat chat) async {
    setState(() => _sendingTo = chat.id);
    final ok = await ref
        .read(feedRepositoryProvider)
        .forwardPost(post: widget.post, toChatId: chat.id);
    if (!mounted) return;

    if (!ok) {
      setState(() => _sendingTo = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.forwardFailed(chat.title))),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final needle = _query.trim().toLowerCase();
    final chats = ref
        .read(feedRepositoryProvider)
        .forwardTargets()
        .where((c) => needle.isEmpty || c.title.toLowerCase().contains(needle))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  AppStrings.forwardTitle,
                  style: AppTypography.heading(color: primary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.body(color: primary),
                  decoration: InputDecoration(
                    hintText: AppStrings.forwardSearchHint,
                    hintStyle: AppTypography.body(color: secondary),
                    prefixIcon: Icon(Icons.search, color: secondary, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: chats.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.forwardNoChats,
                          style: AppTypography.body(color: secondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final sending = _sendingTo == chat.id;

                          return ListTile(
                            leading: ChannelAvatar(
                              title: chat.title,
                              avatarPath: chat.photo?.small.local.path,
                              avatarFileId: chat.photo?.small.id,
                            ),
                            title: Text(
                              chat.title,
                              style: AppTypography.subheading(color: primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : null,
                            // One forward at a time, so a double tap can't send twice.
                            onTap: _sendingTo == null
                                ? () => _forward(chat)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
