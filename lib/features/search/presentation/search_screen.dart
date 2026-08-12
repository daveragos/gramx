import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';

/// Search state notifier for managing search query and results.
class SearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<SearchNotifier, String>(SearchNotifier.new);

class SearchFocusNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final searchFocusTriggerProvider =
    NotifierProvider<SearchFocusNotifier, int>(SearchFocusNotifier.new);

/// Filtered posts based on search query.
final searchResultsProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final postsAsync = ref.watch(feedPostsProvider);

  if (query.isEmpty) return postsAsync;

  return postsAsync.whenData((posts) {
    return posts.where((post) {
      final textMatch = post.text?.toLowerCase().contains(query) ?? false;
      final channelMatch = post.channelTitle.toLowerCase().contains(query);
      final usernameMatch =
          post.channelUsername?.toLowerCase().contains(query) ?? false;
      return textMatch || channelMatch || usernameMatch;
    }).toList();
  });
});

enum SearchCategory { all, channels, posts }

class SearchCategoryNotifier extends Notifier<SearchCategory> {
  @override
  SearchCategory build() => SearchCategory.all;

  void setCategory(SearchCategory cat) => state = cat;
}

final searchCategoryProvider =
    NotifierProvider<SearchCategoryNotifier, SearchCategory>(
        SearchCategoryNotifier.new);

/// Filtered local and global public channels based on search query.
final searchChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return [];

  final repo = ref.watch(channelRepositoryProvider);
  final localChannels = ref.watch(channelsProvider).value ?? [];
  final matchedLocal = localChannels.where((ch) {
    final titleMatch = ch.title.toLowerCase().contains(query.toLowerCase());
    final usernameMatch =
        ch.username?.toLowerCase().contains(query.toLowerCase()) ?? false;
    return titleMatch || usernameMatch;
  }).toList();

  final publicChannels = await repo.searchPublicChannels(query);
  final existingIds = matchedLocal.map((c) => c.id).toSet();
  final newPublic =
      publicChannels.where((c) => !existingIds.contains(c.id)).toList();

  return [...matchedLocal, ...newPublic];
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(searchQueryProvider.notifier).setQuery(value);
    setState(() {
      _isSearching = value.trim().isNotEmpty;
    });
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
    setState(() {
      _isSearching = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(searchFocusTriggerProvider, (previous, next) {
      if (next > 0) {
        _focusNode.requestFocus();
      }
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final primaryColor = theme.colorScheme.onSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focusNode.hasFocus ? AppColors.accent : borderColor,
              width: _focusNode.hasFocus ? 1.0 : 0.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.search, color: secondaryColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  style: AppTypography.body(color: primaryColor),
                  decoration: InputDecoration(
                    hintText: 'Search posts and channels',
                    hintStyle: AppTypography.body(color: secondaryColor),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_isSearching)
                GestureDetector(
                  onTap: _clearSearch,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Icon(Icons.close, color: secondaryColor, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _isSearching
          ? _SearchResults(primaryColor: primaryColor, secondaryColor: secondaryColor)
          : _ExploreView(primaryColor: primaryColor, secondaryColor: secondaryColor),
    );
  }
}

/// Shows search results (channels + posts) when user is typing.
class _SearchResults extends ConsumerWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const _SearchResults({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(searchCategoryProvider);
    final channelsAsync = ref.watch(searchChannelsProvider);
    final postsAsync = ref.watch(searchResultsProvider);

    final showChannels = category == SearchCategory.all || category == SearchCategory.channels;
    final showPosts = category == SearchCategory.all || category == SearchCategory.posts;

    return Column(
      children: [
        // Filter Chips Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(
            children: [
              _buildCategoryChip(ref, 'All', SearchCategory.all, category),
              const SizedBox(width: 8),
              _buildCategoryChip(ref, 'Channels', SearchCategory.channels, category),
              const SizedBox(width: 8),
              _buildCategoryChip(ref, 'Posts', SearchCategory.posts, category),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (showChannels)
                channelsAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    ),
                  ),
                  error: (err, _) => SliverToBoxAdapter(
                    child: Center(child: Text('Error: $err')),
                  ),
                  data: (channels) {
                    if (channels.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
                            ),
                            child: Text(
                              'Channels (${channels.length})',
                              style: AppTypography.subheading(color: secondaryColor),
                            ),
                          ),
                          ...channels.map((channel) => _ChannelResultTile(
                                channel: channel,
                                primaryColor: primaryColor,
                                secondaryColor: secondaryColor,
                              )),
                          const Divider(),
                        ],
                      ),
                    );
                  },
                ),
              if (showPosts)
                postsAsync.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $err')),
                  ),
                  data: (posts) {
                    if (posts.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 48, color: secondaryColor),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No posts found',
                                style: AppTypography.subheading(color: secondaryColor),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = posts[index];
                          return PostCard(post: post);
                        },
                        childCount: posts.length,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(
      WidgetRef ref, String label, SearchCategory cat, SearchCategory current) {
    final isSelected = cat == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accent : secondaryColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        ref.read(searchCategoryProvider.notifier).setCategory(cat);
      },
    );
  }
}

/// Channel search result tile.
class _ChannelResultTile extends StatelessWidget {
  final Channel channel;
  final Color primaryColor;
  final Color secondaryColor;

  const _ChannelResultTile({
    required this.channel,
    required this.primaryColor,
    required this.secondaryColor,
  });

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => NavigationUtils.openChannel(context, channel.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // Avatar
            () {
              if (channel.avatarUrl != null && channel.avatarUrl!.isNotEmpty) {
                final file = File(channel.avatarUrl!);
                if (file.existsSync()) {
                  return CircleAvatar(
                    radius: AppSpacing.avatarSize / 2,
                    backgroundImage: FileImage(file),
                  );
                }
              }
              return CircleAvatar(
                radius: AppSpacing.avatarSize / 2,
                backgroundColor: channel.avatarColor != null
                    ? _parseColor(channel.avatarColor!)
                    : AppColors.accent,
                child: Text(
                  channel.title.isNotEmpty
                      ? channel.title[0].toUpperCase()
                      : '?',
                  style: AppTypography.displayName(color: Colors.white),
                ),
              );
            }(),
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
                          style:
                              AppTypography.displayName(color: primaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            color: AppColors.verified, size: 18),
                      ],
                    ],
                  ),
                  if (channel.username != null)
                    Text(
                      '@${channel.username}',
                      style: AppTypography.username(color: secondaryColor),
                    ),
                ],
              ),
            ),
            Text(
              '${TimeUtils.formatCount(channel.subscriberCount)} subscribers',
              style: AppTypography.actionCount(color: secondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Default explore view when not searching — shows trending/recent posts.
class _ExploreView extends ConsumerWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const _ExploreView({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(feedPostsProvider);

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_outlined, color: secondaryColor, size: 64),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Explore',
                  style: AppTypography.heading(color: primaryColor),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Subscribe to channels to discover posts.',
                  style: AppTypography.body(color: secondaryColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
                ),
                child: Text(
                  'Recent from your channels',
                  style: AppTypography.subheading(color: secondaryColor),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = posts[index];
                  return PostCard(
                    post: post,
                    onTap: () {
                      ref.read(markPostAsReadProvider(post.id));
                      context.push('/post/${post.id}');
                    },
                    onChannelTap: () =>
                        NavigationUtils.openChannel(context, post.channelId),
                    onBookmarkTap: () {
                      ref.read(bookmarkToggleProvider(post.id));
                    },
                  );
                },
                childCount: posts.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
