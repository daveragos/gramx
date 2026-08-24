import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/guest/data/guest_channel_store.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// Where a guest builds their reading list.
///
/// Adding resolves the channel before it is stored, so a typo or a private
/// channel fails here with a reason rather than becoming a permanently empty
/// row in the feed.
class GuestChannelsScreen extends ConsumerStatefulWidget {
  const GuestChannelsScreen({super.key});

  @override
  ConsumerState<GuestChannelsScreen> createState() =>
      _GuestChannelsScreenState();
}

class _GuestChannelsScreenState extends ConsumerState<GuestChannelsScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isAdding = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _isAdding) return;

    setState(() {
      _isAdding = true;
      _error = null;
    });

    final failure = await ref.read(guestChannelsProvider.notifier).add(input);

    if (!mounted) return;
    setState(() {
      _isAdding = false;
      _error = failure;
    });

    if (failure == null) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _remove(GuestChannel channel) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(guestChannelsProvider.notifier).remove(channel.username);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(AppStrings.guestRemoved(channel.username))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final channelsAsync = ref.watch(guestChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.guestChannelsTitle,
          style: AppTypography.heading(color: theme.colorScheme.onSurface),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.guestEmptyBody,
                  style: AppTypography.body(color: secondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _controller,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    labelText: AppStrings.guestAddLabel,
                    hintText: AppStrings.guestAddHint,
                    prefixText: '@',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    onPressed: _isAdding ? null : _add,
                    child: _isAdding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            AppStrings.guestAddAction,
                            style: AppTypography.button(),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: channelsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (err, _) => Center(
                child: Text(
                  err.toString(),
                  style: AppTypography.body(color: secondary),
                ),
              ),
              data: (channels) {
                if (channels.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Text(
                        AppStrings.guestEmptyTitle,
                        style: AppTypography.body(color: secondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return ListTile(
                      leading: ChannelAvatar(
                        title: channel.title,
                        avatarPath: channel.avatarUrl,
                        radius: AppSpacing.avatarSize / 2,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              channel.title,
                              style: AppTypography.displayName(
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (channel.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 15,
                              color: AppColors.verified,
                              semanticLabel: AppStrings.a11yVerified,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        channel.subscribers == null
                            ? '@${channel.username}'
                            : '@${channel.username} · ${channel.subscribers}',
                        style: AppTypography.username(color: secondary),
                      ),
                      trailing: IconButton(
                        tooltip: AppStrings.guestRemoveAction,
                        icon: Icon(Icons.close_rounded, color: secondary),
                        onPressed: () => _remove(channel),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
