import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/features/guest/presentation/guest_channels_screen.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/presentation/widgets/add_channel_dialog.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/widgets/mute_sheet.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

/// Which slice of the subscription list is on screen.
///
/// Muted channels are hidden from the feed, which used to make them
/// unreachable: nothing listed them, so a mute could only be undone by
/// remembering the channel and opening its profile. This is that list.
enum ChannelFilter { all, muted }

class ChannelFilterNotifier extends Notifier<ChannelFilter> {
  @override
  ChannelFilter build() => ChannelFilter.all;

  void set(ChannelFilter filter) {
    if (state != filter) state = filter;
  }
}

final channelFilterProvider =
    NotifierProvider<ChannelFilterNotifier, ChannelFilter>(
        ChannelFilterNotifier.new);

/// The channels currently muted, in subscription order.
///
/// Derived from the same notifier the mute button writes to, so the list and
/// the toggle can never disagree.
final mutedChannelsListProvider = Provider<List<Channel>>((ref) {
  final channels = ref.watch(channelsProvider).value ?? const <Channel>[];
  // Watched so the list rebuilds when a mute is toggled; the check itself goes
  // through the notifier, which knows about every id a channel answers to.
  ref.watch(mutedChannelsProvider);
  final muted = ref.read(mutedChannelsProvider.notifier);

  return channels
      .where((c) =>
          muted.isMuted(c.id, chatId: c.chatId, username: c.username))
      .toList();
});

class ChannelsListScreen extends ConsumerWidget {
  const ChannelsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A guest's channels are the public ones they typed in, not a subscription
    // list Telegram keeps for them. Different source, different screen.
    if (ref.watch(isGuestModeProvider)) {
      return const GuestChannelsScreen(embedded: true);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final channelsAsync = ref.watch(channelsProvider);
    final filter = ref.watch(channelFilterProvider);
    final mutedChannels = ref.watch(mutedChannelsListProvider);
    final showFilter =
        mutedChannels.isNotEmpty || filter == ChannelFilter.muted;

    return ChromeScaffold(
      header: ChromeHeaderRow(
        title: AppStrings.channelsTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppStrings.channelsAddPublic,
            onPressed: () => _showAddChannelDialog(context, ref),
          ),
        ],
      ),
      // The filter only exists once something is muted, so the header does not
      // reserve room for an empty strip.
      headerBottomHeight: showFilter ? _filterStripHeight : 0,
      headerBottom: showFilter
          ? _ChannelFilterStrip(
              filter: filter,
              mutedCount: mutedChannels.length,
              secondaryColor: secondaryColor,
            )
          : null,
      body: (context, topPadding, bottomPadding) => channelsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Text(AppStrings.channelsError(err)),
          ),
        ),
        data: (channels) {
          final visible =
              filter == ChannelFilter.muted ? mutedChannels : channels;

          if (visible.isEmpty) {
            return _EmptyState(
              topPadding: topPadding,
              filter: filter,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              onAdd: () => _showAddChannelDialog(context, ref),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            itemCount: visible.length,
            separatorBuilder: (context, index) => const Divider(height: 0.5),
            itemBuilder: (context, index) => _ChannelRow(
              channel: visible[index],
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          );
        },
      ),
    );
  }

  static const double _filterStripHeight = 48;

  void _showAddChannelDialog(BuildContext context, WidgetRef ref) {
    showAddChannelDialog(context);
  }
}

/// All / Muted. Only offered once something is actually muted — an empty
/// filter is a control that does nothing.
class _ChannelFilterStrip extends ConsumerWidget {
  final ChannelFilter filter;
  final int mutedCount;
  final Color secondaryColor;

  const _ChannelFilterStrip({
    required this.filter,
    required this.mutedCount,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(String label, ChannelFilter value) {
      final selected = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor: AppColors.accent.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: selected ? AppColors.accent : secondaryColor,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (_) =>
              ref.read(channelFilterProvider.notifier).set(value),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          chip(AppStrings.channelsFilterAll, ChannelFilter.all),
          chip(AppStrings.channelsFilterMuted(mutedCount), ChannelFilter.muted),
        ],
      ),
    );
  }
}

class _ChannelRow extends ConsumerWidget {
  final Channel channel;
  final Color primaryColor;
  final Color secondaryColor;

  const _ChannelRow({
    required this.channel,
    required this.primaryColor,
    required this.secondaryColor,
  });

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  Widget _buildAvatar() {
    final path = channel.avatarUrl;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(
        radius: AppSpacing.avatarSizeLarge / 2,
        backgroundImage: FileImage(File(path)),
      );
    }
    return CircleAvatar(
      radius: AppSpacing.avatarSizeLarge / 2,
      backgroundColor: channel.avatarColor != null
          ? _parseColor(channel.avatarColor!)
          : AppColors.accent,
      child: Text(
        channel.title.isNotEmpty ? channel.title[0].toUpperCase() : '?',
        style: AppTypography.heading(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mutedChannelsProvider);
    final mutes = ref.read(mutedChannelsProvider.notifier);
    final muted = mutes.isMuted(
      channel.id,
      chatId: channel.chatId,
      username: channel.username,
    );
    final mutedUntil = mutes.mutedUntil(
      channel.id,
      chatId: channel.chatId,
      username: channel.username,
    );

    return InkWell(
      onTap: () => NavigationUtils.openChannel(context, channel.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.postPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: AppSpacing.avatarGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.title,
                          style: AppTypography.displayName(color: primaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: AppColors.verified,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      if (channel.username != null)
                        Flexible(
                          child: Text(
                            '@${channel.username}',
                            style:
                                AppTypography.username(color: secondaryColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (channel.subscriberCount > 0) ...[
                        if (channel.username != null)
                          Text(AppStrings.inlineSeparator,
                              style: AppTypography.username(
                                  color: secondaryColor)),
                        Text(
                          AppStrings.subscriberCountShort(
                            TimeUtils.formatCount(channel.subscriberCount),
                          ),
                          style:
                              AppTypography.actionCount(color: secondaryColor),
                        ),
                      ],
                    ],
                  ),
                  // Muted state is otherwise carried only by the icon — and a
                  // timed mute has to say when it lifts, or the reader has no
                  // way to tell it apart from a permanent one. In the grey the
                  // row's other facts use: a mute is a preference the reader
                  // set, and the red it used to wear made it read as an error.
                  if (muted)
                    Text(
                      mutedUntil != null
                          ? AppStrings.channelsMutedUntil(
                              TimeUtils.untilWhen(mutedUntil))
                          : AppStrings.channelsMutedIndefinitely,
                      style: AppTypography.actionCount(color: secondaryColor),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: muted
                  ? AppStrings.channelsUnmuteAction
                  : AppStrings.channelsMuteAction,
              icon: Icon(
                muted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_none,
                color: secondaryColor,
              ),
              onPressed: () => MuteSheet.show(
                context,
                ref,
                channelId: channel.id,
                chatId: channel.chatId,
                username: channel.username,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final double topPadding;
  final ChannelFilter filter;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.topPadding,
    required this.filter,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isMutedFilter = filter == ChannelFilter.muted;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMutedFilter
                    ? Icons.notifications_none
                    : Icons.list_alt_outlined,
                color: AppColors.accent,
                size: 80,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isMutedFilter
                    ? AppStrings.channelsNoMutedTitle
                    : AppStrings.channelsEmptyTitle,
                style: AppTypography.heading(color: primaryColor)
                    .copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isMutedFilter
                    ? AppStrings.channelsNoMutedBody
                    : AppStrings.channelsEmptyBody,
                style: AppTypography.body(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
              if (!isMutedFilter) ...[
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: onAdd,
                  child: const Text(AppStrings.channelsAddPublic,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Adds a public channel — and actually joins it.
///
/// Resolving the username only taught TDLib the channel existed; the user was
/// never subscribed, so the channel never reached the feed and the button
/// looked broken.
