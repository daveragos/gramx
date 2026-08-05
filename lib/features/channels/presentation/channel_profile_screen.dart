import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

class ChannelProfileScreen extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelProfileScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChannelProfileScreen> createState() =>
      _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends ConsumerState<ChannelProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isMuted = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  void _openTelegramLink(String? username) async {
    if (username != null && username.isNotEmpty) {
      final uri = Uri.parse('https://t.me/$username');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelAsync = ref.watch(channelDetailProvider(widget.channelId));
    final channelPostsAsync = ref.watch(channelPostsProvider(widget.channelId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    return Scaffold(
      body: channelAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Scaffold(
          appBar: AppBar(title: const Text('Channel')),
          body: Center(child: Text('Error: $err')),
        ),
        data: (channel) {
          if (channel == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Channel Not Found')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'This channel is private or inaccessible.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final bannerColor = channel.avatarColor != null
              ? _parseColor(channel.avatarColor!)
              : AppColors.accent;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Banner & Navigation Header
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                backgroundColor: bannerColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    channel.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [bannerColor, bannerColor.withValues(alpha: 0.8)],
                      ),
                    ),
                  ),
                ),
              ),

              // Profile Details Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.postPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Overlapping Channel Avatar
                          Transform.translate(
                            offset: const Offset(0, -28),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 4,
                                ),
                              ),
                              child: ChannelAvatar(
                                title: channel.title,
                                avatarPath: channel.avatarUrl,
                                avatarFileId: channel.avatarFileId,
                                avatarColorHex: channel.avatarColor,
                                radius: 36,
                              ),
                            ),
                          ),

                          // Action Buttons
                          Row(
                            children: [
                              IconButton.outlined(
                                onPressed: () {
                                  setState(() => _isMuted = !_isMuted);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_isMuted
                                          ? 'Muted notifications'
                                          : 'Unmuted notifications'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  _isMuted
                                      ? Icons.notifications_off_outlined
                                      : Icons.notifications_outlined,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (channel.username != null)
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _openTelegramLink(channel.username),
                                  icon: const Icon(Icons.send_rounded, size: 16),
                                  label: const Text('Open'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Channel Title & Username
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              channel.title,
                              style: AppTypography.heading(color: primaryColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (channel.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: AppColors.verified,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      if (channel.username != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${channel.username}',
                          style: AppTypography.username(color: secondaryColor),
                        ),
                      ],

                      // Description
                      if (channel.description != null &&
                          channel.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          channel.description!,
                          style: AppTypography.body(color: primaryColor),
                        ),
                      ],

                      // Subscriber count
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.people_outline,
                              size: 16, color: secondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            '${TimeUtils.formatCount(channel.subscriberCount)} subscribers',
                            style: AppTypography.body(color: secondaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: Divider(height: 1)),

              // Channel Posts List
              channelPostsAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (err, _) => SliverFillRemaining(
                  child: Center(child: Text('Error loading posts: $err')),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: Text('No posts found in this channel.'),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final post = posts[index];
                      return PostCard(
                        post: post,
                        onTap: () {
                          ref.read(markPostAsReadProvider(post.id));
                          context.push('/post/${post.id}');
                        },
                      );
                    }, childCount: posts.length),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
