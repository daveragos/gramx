import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/text/plain_text_links.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_profile_screen.dart'
    show ChannelRetry;
import 'package:gramx/features/channels/presentation/channel_providers.dart';

/// The channels Telegram finds like one, listed the way X lists followers:
/// avatar, name, handle and description, with a join button on each.
class SimilarChannelsScreen extends ConsumerWidget {
  static const String route = '/channel/:channelId/similar';

  static String routeFor(int chatId) => '/channel/$chatId/similar';

  final int chatId;

  const SimilarChannelsScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final source = ref.watch(channelDetailProvider('$chatId')).value;
    final similar = ref.watch(similarChannelsProvider(chatId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.similarChannelsTitle,
              style: AppTypography.heading(color: theme.colorScheme.onSurface),
            ),
            if (source != null)
              Text(
                source.title,
                style: AppTypography.timestamp(color: secondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: similar.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (error, _) => ChannelRetry(
          message: AppStrings.similarChannelsFailed,
          detail: error.toString(),
          onRetry: () async => ref.invalidate(similarChannelsProvider(chatId)),
        ),
        data: (channels) => channels.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    AppStrings.similarChannelsEmpty,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(color: secondary),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: channels.length,
                itemBuilder: (context, index) => SimilarChannelRow(
                  channel: channels[index],
                  sourceChatId: chatId,
                ),
              ),
      ),
    );
  }
}

/// One channel: what X shows of an account in its follower lists.
class SimilarChannelRow extends ConsumerStatefulWidget {
  final Channel channel;

  /// The channel whose list this is, which Telegram is told was the source.
  final int sourceChatId;

  const SimilarChannelRow({
    super.key,
    required this.channel,
    required this.sourceChatId,
  });

  @override
  ConsumerState<SimilarChannelRow> createState() => _SimilarChannelRowState();
}

class _SimilarChannelRowState extends ConsumerState<SimilarChannelRow> {
  bool _joining = false;

  void _open() {
    final channel = widget.channel;
    ref
        .read(channelRepositoryProvider)
        .openedSimilarChannel(widget.sourceChatId, channel.chatId);
    NavigationUtils.openChannel(context, '${channel.chatId}');
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    final messenger = ScaffoldMessenger.of(context);
    final joined = await ref
        .read(channelMembershipProvider.notifier)
        .join(widget.channel.chatId);
    // A failed join used to say nothing.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          joined
              ? AppStrings.channelJoined(widget.channel.title)
              : AppStrings.channelsAddJoinFailed,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final channel = widget.channel;
    final description = channel.description?.trim();

    return InkWell(
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.postPadding,
          AppSpacing.md,
          AppSpacing.postPadding,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChannelAvatar(
              title: channel.title,
              avatarPath: channel.avatarUrl,
              avatarFileId: channel.avatarFileId,
              avatarColorHex: channel.avatarColor,
              radius: AppSpacing.avatarSize / 2,
            ),
            const SizedBox(width: AppSpacing.avatarGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    channel.title,
                                    style: AppTypography.displayName(
                                      color: primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (channel.isVerified) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(
                                    Icons.verified,
                                    color: AppColors.verified,
                                    size: 16,
                                    semanticLabel: AppStrings.a11yVerified,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              [
                                if (channel.username != null)
                                  '@${channel.username}',
                                if (channel.subscriberCount > 0)
                                  AppStrings.subscriberCountShort(
                                    TimeUtils.formatCount(
                                      channel.subscriberCount,
                                    ),
                                  ),
                              ].join(' · '),
                              style: AppTypography.username(color: secondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      PillButton(
                        label: channel.isJoined
                            ? AppStrings.channelJoinedAction
                            : AppStrings.channelJoinAction,
                        // Joined channels open; leaving is on their profile.
                        style: channel.isJoined
                            ? PillStyle.outlined
                            : PillStyle.filled,
                        compact: true,
                        isBusy: _joining,
                        onPressed: channel.isJoined ? _open : _join,
                      ),
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextEntityRenderer(
                      text: description,
                      entities: linkifyPlainText(description),
                      style: AppTypography.body(color: primary),
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
