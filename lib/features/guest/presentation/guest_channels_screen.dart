import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/guest/data/guest_channel_store.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// Where a guest manages their channel list. A channel is resolved before
/// it is stored, so a typo or private channel fails here with a reason.
class GuestChannelsScreen extends ConsumerStatefulWidget {
  /// True when shown as the Channels tab, with the sliding chrome and room
  /// for the bottom bar, rather than as a pushed route.
  final bool embedded;

  const GuestChannelsScreen({super.key, this.embedded = false});

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

    final notifier = ref.read(guestChannelsProvider.notifier);
    final failure = await notifier.add(input);

    if (!mounted) return;
    setState(() {
      _isAdding = false;
      _error = failure;
    });

    if (failure != null) return;

    _controller.clear();
    FocusScope.of(context).unfocus();

    // Confirm with the resolved title rather than the typed handle.
    final added = ref.read(guestChannelsProvider).value?.firstOrNull;
    if (added == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.guestAdded(added.title))));
  }

  /// Pastes a link or handle from the clipboard. `add` does the parsing.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;

    _controller.text = text;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _error = null);
  }

  void _open(GuestChannel channel) {
    context.push(
      '/channel/${GuestPostMapper.syntheticChatId(channel.username)}',
    );
  }

  Future<void> _remove(GuestChannel channel, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(guestChannelsProvider.notifier);
    await notifier.remove(channel.username);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.guestRemoved(channel.username)),
        // Undo restores the stored row in place, without a new request.
        action: SnackBarAction(
          label: AppStrings.guestUndo,
          onPressed: () => notifier.restore(channel, index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.embedded) {
      return ChromeScaffold(
        header: const ChromeHeaderRow(title: AppStrings.guestChannelsTitle),
        body: (context, topPadding, bottomPadding) =>
            _body(topPadding: topPadding, bottomPadding: bottomPadding),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.guestChannelsTitle,
          style: AppTypography.heading(color: theme.colorScheme.onSurface),
        ),
      ),
      body: _body(topPadding: 0, bottomPadding: 0),
    );
  }

  Widget _body({required double topPadding, required double bottomPadding}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final channelsAsync = ref.watch(guestChannelsProvider);

    return Column(
      children: [
        SizedBox(height: topPadding),
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
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: AppStrings.guestPasteTooltip,
                    icon: Icon(Icons.content_paste_rounded, color: secondary),
                    onPressed: _paste,
                  ),
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
                padding: EdgeInsets.only(bottom: bottomPadding),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  return ListTile(
                    onTap: () => _open(channel),
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
                      onPressed: () => _remove(channel, index),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
