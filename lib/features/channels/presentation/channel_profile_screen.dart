import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

class ChannelProfileScreen extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelProfileScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChannelProfileScreen> createState() => _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends ConsumerState<ChannelProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialHistory();
    });
  }

  Future<void> _fetchInitialHistory() async {
    try {
      final channel = ref.read(channelDetailProvider(widget.channelId)).value;
      if (channel != null) {
        await ref.read(loadMoreChannelHistoryProvider((chatId: channel.chatId, fromMessageId: 0)).future);
      }
    } catch (e) {
      debugPrint('[ChannelScreen] Error fetching initial history: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;

    try {
      final channel = ref.read(channelDetailProvider(widget.channelId)).value;
      if (channel != null) {
        await ref.read(
          loadMoreChannelHistoryProvider((
            chatId: channel.chatId,
            fromMessageId: 0,
          )).future,
        );
      }
    } catch (e) {
      debugPrint('[ChannelScreen] Error loading more history: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  Widget _buildHeaderAvatar(dynamic channel, Color bannerColor) {
    if (channel.avatarUrl != null && channel.avatarUrl!.isNotEmpty) {
      final file = File(channel.avatarUrl!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: 32,
          backgroundImage: FileImage(file),
        );
      }
    }
    return CircleAvatar(
      radius: 32,
      backgroundColor: bannerColor,
      child: Text(
        channel.title.isNotEmpty ? channel.title[0].toUpperCase() : '?',
        style: AppTypography.heading(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelAsync = ref.watch(channelDetailProvider(widget.channelId));
    final channelPostsAsync = ref.watch(channelPostsProvider(widget.channelId));
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    return Scaffold(
      body: channelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
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
                          child: _buildHeaderAvatar(channel, bannerColor),
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
                    (context, index) {
                      final post = posts[index];
                      return PostCard(
                        post: post,
                        onTap: () {
                          ref.read(markPostAsReadProvider(post.id));
                          context.push('/post/${post.id}');
                        },
                      );
                    },
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
}
