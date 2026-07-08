import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

class ChannelProfileScreen extends ConsumerWidget {
  final String channelId;

  const ChannelProfileScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelAsync = ref.watch(channelDetailProvider(channelId));
    final channelPostsAsync = ref.watch(channelPostsProvider(channelId));
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    return Scaffold(
      body: channelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (channel) {
          if (channel == null) return const Center(child: Text('Channel not found'));

          final bannerColor = channel.avatarColor != null
              ? _parseColor(channel.avatarColor!)
              : AppColors.accent;

          return CustomScrollView(
            slivers: [
              // Banner
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: bannerColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(color: bannerColor),
                ),
              ),
              // Profile header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.postPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar overlapping banner
                      Transform.translate(
                        offset: const Offset(0, -32),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 4,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: bannerColor,
                            child: Text(
                              channel.title[0].toUpperCase(),
                              style: AppTypography.heading(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(channel.title, style: AppTypography.heading(color: primaryColor)),
                                if (channel.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: AppColors.verified, size: 22),
                                ],
                              ],
                            ),
                            if (channel.username != null)
                              Text('@${channel.username}', style: AppTypography.username(color: secondaryColor)),
                            const SizedBox(height: AppSpacing.sm),
                            if (channel.description != null)
                              Text(channel.description!, style: AppTypography.body(color: primaryColor)),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${TimeUtils.formatCount(channel.subscriberCount)} subscribers',
                              style: AppTypography.body(color: secondaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider()),
              // Channel posts
              channelPostsAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                ),
                error: (err, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $err')),
                ),
                data: (posts) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => PostCard(
                      post: posts[index],
                      onTap: () => context.push('/post/${posts[index].id}'),
                    ),
                    childCount: posts.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
