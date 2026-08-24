import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
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

/// How long typing must pause before a query is allowed to reach Telegram.
///
/// Without this, a ten-character query fired `SearchPublicChats` ten times,
/// each followed by per-result lookups — on the one path in the app the user
/// drives keystroke by keystroke. Nothing driven by a text field may reach
/// TDLib undebounced.
const Duration searchDebounce = Duration(milliseconds: 300);

/// The search query with the network debounce applied.
///
/// [searchQueryProvider] stays instant so filtering already-loaded posts feels
/// immediate; only the query that costs a request waits.
class DebouncedSearchQueryNotifier extends Notifier<String> {
  Timer? _timer;
  String _emitted = '';

  @override
  String build() {
    final query = ref.watch(searchQueryProvider).trim();

    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());

    // Clearing the field takes effect immediately — there is nothing to spend.
    if (query.isEmpty) {
      _emitted = '';
      return '';
    }
    if (query == _emitted) return _emitted;

    _timer = Timer(searchDebounce, () {
      _emitted = query;
      state = query;
    });

    // Keep showing the last settled query while the user is still typing.
    return _emitted;
  }
}

final debouncedSearchQueryProvider =
    NotifierProvider<DebouncedSearchQueryNotifier, String>(
        DebouncedSearchQueryNotifier.new);

class SearchFocusNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final searchFocusTriggerProvider =
    NotifierProvider<SearchFocusNotifier, int>(SearchFocusNotifier.new);

/// Posts matching the query, searched on Telegram's servers.
///
/// Runs off the debounced query, since each search is a request.
final searchedPostsProvider =
    FutureProvider<List<Post>>((ref) async {
  final query = ref.watch(debouncedSearchQueryProvider).trim();
  if (query.isEmpty) return const [];
  return ref.watch(feedRepositoryProvider).searchPosts(query);
});

/// Substring match over posts already loaded in the feed.
///
/// Instant, and shown while the server search is still in flight so results
/// don't blank out between keystrokes. Kept as a fallback rather than the whole
/// feature — it can only ever find what is already in memory.
List<Post> matchLoadedPosts(List<Post> posts, String query) {
  final needle = query.toLowerCase().trim();
  if (needle.isEmpty) return posts;

  return posts.where((post) {
    final textMatch = post.text?.toLowerCase().contains(needle) ?? false;
    final channelMatch = post.channelTitle.toLowerCase().contains(needle);
    final usernameMatch =
        post.channelUsername?.toLowerCase().contains(needle) ?? false;
    return textMatch || channelMatch || usernameMatch;
  }).toList();
}

/// Search results: server hits once they land, local matches until then.
///
/// A guest gets local matching only. `SearchMessages` is a TDLib request and
/// needs an account; `t.me/s/` offers no search of its own. So the guest search
/// filters what has been loaded, which is honest about its scope rather than
/// silently returning less than the reader expects.
final searchResultsProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim();

  if (!ref.watch(readerCapabilitiesProvider).canSearchServerSide) {
    final guestPosts = ref.watch(guestFeedProvider);
    if (query.isEmpty) return guestPosts;
    return guestPosts.whenData((posts) => matchLoadedPosts(posts, query));
  }

  final postsAsync = ref.watch(feedPostsProvider);

  if (query.isEmpty) return postsAsync;

  final local = postsAsync.whenData((posts) => matchLoadedPosts(posts, query));
  final remote = ref.watch(searchedPostsProvider);

  return remote.when(
    data: (results) {
      // Union: a loaded post the server didn't return is still a valid hit,
      // and vice versa.
      final localHits = local.value ?? const <Post>[];
      return AsyncValue.data(mergePostsNewestFirst(results, localHits));
    },
    loading: () => local.isLoading ? const AsyncValue.loading() : local,
    error: (_, _) => local,
  );
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

/// Local and global public channels matching the search query.
///
/// Watches the debounced query — this provider spends requests.
final searchChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final query = ref.watch(debouncedSearchQueryProvider).trim();
  if (query.isEmpty) return [];
  // Public-channel discovery is a TDLib request. A guest adds channels by
  // typing a username on their own screen instead.
  if (!ref.watch(readerCapabilitiesProvider).canSearchServerSide) return [];

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

    return ChromeScaffold(
      header: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Container(
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
                    hintText: AppStrings.searchHint,
                    hintStyle: AppTypography.body(color: secondaryColor),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_isSearching)
                Semantics(
                  button: true,
                  label: AppStrings.searchClear,
                  child: GestureDetector(
                    onTap: _clearSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm),
                      child:
                          Icon(Icons.close, color: secondaryColor, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: (context, topPadding, bottomPadding) => _isSearching
          ? _SearchResults(
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              topPadding: topPadding,
              bottomPadding: bottomPadding,
            )
          : _ExploreView(
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              topPadding: topPadding,
              bottomPadding: bottomPadding,
            ),
    );
  }
}

/// Shows search results (channels + posts) when user is typing.
class _SearchResults extends ConsumerWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final double topPadding;
  final double bottomPadding;

  const _SearchResults({
    required this.primaryColor,
    required this.secondaryColor,
    required this.topPadding,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(searchCategoryProvider);
    final channelsAsync = ref.watch(searchChannelsProvider);
    final postsAsync = ref.watch(searchResultsProvider);

    final showChannels = category == SearchCategory.all ||
        category == SearchCategory.channels;
    final showPosts =
        category == SearchCategory.all || category == SearchCategory.posts;

    return CustomScrollView(
      slivers: [
        // The filter chips scroll with the results rather than sitting in a
        // fixed strip: the header slides away, and a row pinned to where it
        // used to be would strand itself mid-screen.
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: topPadding + AppSpacing.xs,
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                _buildCategoryChip(
                    ref, AppStrings.searchFilterAll, SearchCategory.all, category),
                const SizedBox(width: 8),
                _buildCategoryChip(ref, AppStrings.searchFilterChannels,
                    SearchCategory.channels, category),
                const SizedBox(width: 8),
                _buildCategoryChip(ref, AppStrings.searchFilterPosts,
                    SearchCategory.posts, category),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
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
              child: Center(child: Text(AppStrings.searchError(err))),
            ),
            data: (channels) {
              if (channels.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        AppStrings.searchChannelsHeading(channels.length),
                        style:
                            AppTypography.subheading(color: secondaryColor),
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
              child: Center(child: Text(AppStrings.searchError(err))),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: secondaryColor),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          AppStrings.searchNoResults,
                          style: AppTypography.subheading(
                              color: secondaryColor),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => PostCard(post: posts[index]),
                  childCount: posts.length,
                ),
              );
            },
          ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
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

/// Default explore view when not searching — recent posts from the feed.
class _ExploreView extends ConsumerWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final double topPadding;
  final double bottomPadding;

  const _ExploreView({
    required this.primaryColor,
    required this.secondaryColor,
    required this.topPadding,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(feedPostsProvider);

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (err, _) => Center(child: Text(AppStrings.searchError(err))),
      data: (posts) {
        if (posts.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_outlined, color: secondaryColor, size: 64),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.searchExploreTitle,
                    style: AppTypography.heading(color: primaryColor),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.searchExploreBody,
                    style: AppTypography.body(color: secondaryColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: topPadding + AppSpacing.lg,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  AppStrings.searchRecentHeading,
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
            SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
          ],
        );
      },
    );
  }
}

/// Opens the search tab with [hashtag] already entered.
///
/// Lives here so the tag lands in the same provider the search screen reads,
/// and so `core/`'s text renderer needs no knowledge of search.
void openHashtagSearch(BuildContext context, WidgetRef ref, String hashtag) {
  ref.read(searchQueryProvider.notifier).setQuery(hashtag);
  ref.read(searchCategoryProvider.notifier).setCategory(SearchCategory.posts);
  StatefulNavigationShell.of(context).goBranch(ShellTab.search.index);
}
