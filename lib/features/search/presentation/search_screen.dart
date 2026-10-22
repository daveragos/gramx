import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';
import 'package:gramx/features/bookmarks/presentation/bookmark_providers.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/app_glyphs.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/features/search/presentation/search_filters_sheet.dart';
import 'package:gramx/features/search/presentation/recent_searches_view.dart';
import 'package:gramx/features/search/data/recent_searches.dart';

/// The search query as typed.
class SearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchNotifier, String>(
  SearchNotifier.new,
);

/// How long typing must pause before a query reaches Telegram. Each search
/// is a request plus per-result lookups, so text input is always debounced.
const Duration searchDebounce = Duration(milliseconds: 300);

/// The search query with the network debounce applied. [searchQueryProvider]
/// stays instant for filtering posts that are already loaded.
class DebouncedSearchQueryNotifier extends Notifier<String> {
  Timer? _timer;
  String _emitted = '';

  @override
  String build() {
    final query = ref.watch(searchQueryProvider).trim();

    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());

    // Clearing the field takes effect immediately, since it costs nothing.
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
      DebouncedSearchQueryNotifier.new,
    );

class SearchFocusNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final searchFocusTriggerProvider = NotifierProvider<SearchFocusNotifier, int>(
  SearchFocusNotifier.new,
);

/// Posts matching the debounced query, searched on Telegram's servers.
final searchedPostsProvider = FutureProvider<List<Post>>((ref) async {
  final query = ref.watch(debouncedSearchQueryProvider).trim();
  if (query.isEmpty) return const [];
  final filters = ref.watch(searchFiltersProvider);
  final folderId = filters.folderId;
  // Telegram can't search a folder; see FeedRepository.searchPosts.
  final inChats = folderId == null
      ? null
      : await ref
            .read(folderRepositoryProvider)
            .getFolderChannelChatIds(folderId);
  return ref
      .watch(feedRepositoryProvider)
      .searchPosts(query, filters: filters, inChats: inChats);
});

/// Substring match over posts already loaded in the feed. Shown while the
/// server search is in flight so results don't blank out between keystrokes.
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
/// Guests get local matching only, since `SearchMessages` needs an account.
///
/// Shown with this session's changes, so a post bookmarked or reacted to
/// elsewhere looks the same here.
final searchResultsProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final overrides = ref.watch(optimisticPostUpdatesProvider);
  return ref
      .watch(_searchResultsProvider)
      .whenData(
        (posts) => [for (final p in posts) applyPostOverrides(p, overrides)],
      );
});

final _searchResultsProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim();

  if (!ref.watch(readerCapabilitiesProvider).canSearchServerSide) {
    final guestFeed = ref.watch(guestFeedProvider);
    if (query.isEmpty) return guestFeed.whenData((feed) => feed.posts);
    return guestFeed.whenData((feed) => matchLoadedPosts(feed.posts, query));
  }

  final postsAsync = ref.watch(feedPostsProvider);

  if (query.isEmpty) return postsAsync;

  final remote = ref.watch(searchedPostsProvider);
  // Loaded posts can't be checked against a folder or a type, so filtered
  // searches show Telegram's answer alone.
  if (!ref.watch(searchFiltersProvider).isDefault) return remote;

  final local = postsAsync.whenData((posts) => matchLoadedPosts(posts, query));

  return remote.when(
    data: (results) {
      // Union of local and server hits.
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
      SearchCategoryNotifier.new,
    );

/// Local and global public channels matching the debounced query.
final searchChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final query = ref.watch(debouncedSearchQueryProvider).trim();
  if (query.isEmpty) return [];
  // Channel discovery needs an account; guests search their own list.
  if (!ref.watch(readerCapabilitiesProvider).canSearchServerSide) {
    final needle = query.toLowerCase();
    final guestChannels = await ref.watch(guestChannelsProvider.future);
    return [
      for (final channel in guestChannels)
        if (channel.title.toLowerCase().contains(needle) ||
            channel.username.toLowerCase().contains(needle))
          guestChannelToChannel(channel),
    ];
  }

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
  final newPublic = publicChannels
      .where((c) => !existingIds.contains(c.id))
      .toList();

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

  // No autofocus, so the keyboard does not cover the Explore page. Tapping
  // the Search tab again focuses the field through searchFocusTriggerProvider.
  @override
  void initState() {
    super.initState();
    // The header changes with focus.
    _focusNode.addListener(_onFocusChanged);
    // A search started before this tab first opened, such as a #hashtag.
    final pending = ref.read(searchQueryProvider);
    if (pending.isNotEmpty) {
      _controller.text = pending;
      _isSearching = pending.trim().isNotEmpty;
      // After the frame: recording it changes a provider, which can't
      // happen while widgets build.
      if (_isSearching) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) rememberSearch(ref, query: pending);
        });
      }
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {
      if (_focusNode.hasFocus) _inSearchMode = true;
    });
  }

  /// Whether the page is in search mode, from focusing the field until
  /// Cancel, as on X. Focus alone won't do: the filters sheet takes it.
  bool _inSearchMode = false;

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
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

  /// Puts [query] in the field, with the cursor at its end.
  void _setText(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _onQueryChanged(query);
  }

  /// Runs [query], as from a recent search: the results, without the
  /// keyboard.
  void _runSearch(String query) {
    _setText(query);
    rememberSearch(ref, query: query);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
    setState(() {
      _isSearching = false;
      _inSearchMode = false;
    });
    _focusNode.unfocus();
  }

  /// Whether the account picture gives way to the filters and Cancel.
  bool get _isActive => _inSearchMode || _isSearching;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(searchFocusTriggerProvider, (previous, next) {
      if (next > 0) {
        _focusNode.requestFocus();
      }
    });
    // A search started elsewhere, such as a tapped #hashtag, shows in the
    // field.
    ref.listen<String>(searchQueryProvider, (_, query) {
      if (query == _controller.text) return;
      _setText(query);
      if (query.trim().isNotEmpty) rememberSearch(ref, query: query);
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    final account = ref.watch(activeAccountProvider).value;

    final canFilter = ref.watch(readerCapabilitiesProvider).canSearchServerSide;

    return ChromeScaffold(
      header: Row(
        children: [
          if (_isActive)
            // Leaves search, as Cancel did.
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: _clearSearch,
                icon: Icon(Icons.arrow_back, color: primaryColor),
              ),
            )
          else ...[
            const SizedBox(width: 16.75),
            Semantics(
              button: true,
              label: AppStrings.a11yOpenMenu,
              child: ChannelAvatar(
                title: account?.displayName ?? AppStrings.drawerAccountFallback,
                avatarPath: account?.avatarPath,
                radius: AppSpacing.avatarSizeSmall / 2,
                onTap: openAppDrawer,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          // Keyed: the avatar leaving on focus shifts the field, which
          // would otherwise be rebuilt and drop the keyboard's input.
          Expanded(
            key: const ValueKey('search-field'),
            child: _searchField(context),
          ),
          // Filters need Telegram's search, which a guest doesn't have. They
          // step aside while the recent searches show.
          if (canFilter && (_isSearching || !_isActive)) ...[
            if (!_isActive) const SizedBox(width: 8.3),
            _FiltersButton(color: _isActive ? secondaryColor : primaryColor),
          ] else
            const SizedBox(width: AppSpacing.lg),
          if (canFilter && (_isSearching || !_isActive))
            SizedBox(width: _isActive ? 4 : 8.4),
        ],
      ),
      body: (context, topPadding, bottomPadding) => _isSearching
          ? _SearchResults(
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              topPadding: topPadding,
              bottomPadding: bottomPadding,
            )
          : _isActive
          ? RecentSearchesView(
              onSearch: _runSearch,
              onFill: _setText,
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

  /// The search field: a pill with its words centred until it is focused,
  /// then a plain field after the back arrow.
  Widget _searchField(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isBlack = theme.scaffoldBackgroundColor == AppColors.darkBackground;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final fill = isBlack
        ? AppColors.darkSearchFill
        : (isDark ? AppColors.dimSurface : AppColors.lightSurfaceVariant);
    final idleColor = isBlack ? AppColors.darkSearchHint : secondaryColor;
    final primaryColor = theme.colorScheme.onSurface;
    final idle = !_isActive;

    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onQueryChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (query) => rememberSearch(ref, query: query),
      style: AppTypography.body(color: primaryColor),
      decoration: InputDecoration(
        // Idle, the pill draws its own words in the middle.
        hintText: idle ? null : AppStrings.searchHint,
        hintStyle: AppTypography.body(color: secondaryColor),
        // The pill is the field; the app theme's outline and fill would draw
        // a second box inside it.
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: idle ? fill : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              if (!idle) ...[
                const SizedBox(width: 16.2),
                Glyph(AppGlyphs.search, size: 24, color: secondaryColor),
                const SizedBox(width: 12.8),
              ] else
                const SizedBox(width: AppSpacing.lg),
              Expanded(child: field),
              if (_isSearching)
                Semantics(
                  button: true,
                  label: AppStrings.searchClear,
                  child: GestureDetector(
                    onTap: _clearSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Icon(Icons.close, color: secondaryColor, size: 18),
                    ),
                  ),
                ),
            ],
          ),
          if (idle)
            IgnorePointer(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Glyph(AppGlyphs.search, size: 24, color: idleColor),
                    const SizedBox(width: 8.7),
                    Text(
                      AppStrings.searchHint,
                      style: AppTypography.username(color: idleColor),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the filters, marked while any is set.
class _FiltersButton extends ConsumerWidget {
  final Color color;

  const _FiltersButton({required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = !ref.watch(searchFiltersProvider).isDefault;
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: active
            ? AppStrings.a11ySearchFiltersOn
            : AppStrings.a11ySearchFilters,
        onPressed: () => showSearchFilters(context),
        padding: EdgeInsets.zero,
        icon: Badge(
          isLabelVisible: active,
          backgroundColor: AppColors.accent,
          smallSize: 8,
          child: Icon(
            Icons.settings_outlined,
            size: 24,
            color: active ? AppColors.accent : color,
          ),
        ),
      ),
    );
  }
}

/// Channel and post results while the user is typing.
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

    final showChannels =
        category == SearchCategory.all || category == SearchCategory.channels;
    final showPosts =
        category == SearchCategory.all || category == SearchCategory.posts;

    return CustomScrollView(
      slivers: [
        // The chips scroll with the results, since the header slides away.
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
                  ref,
                  AppStrings.searchFilterAll,
                  SearchCategory.all,
                  category,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  ref,
                  AppStrings.searchFilterChannels,
                  SearchCategory.channels,
                  category,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  ref,
                  AppStrings.searchFilterPosts,
                  SearchCategory.posts,
                  category,
                ),
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
                        style: AppTypography.subheading(color: secondaryColor),
                      ),
                    ),
                    ...channels.map(
                      (channel) => ChannelResultTile(
                        channel: channel,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        onOpen: () => rememberSearch(
                          ref,
                          query: ref.read(searchQueryProvider),
                          chatId: channel.chatId,
                        ),
                      ),
                    ),
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
                        Icon(Icons.search_off, size: 48, color: secondaryColor),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          AppStrings.searchNoResults,
                          style: AppTypography.subheading(
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = posts[index];
                  return PostCard(
                    post: post,
                    onTap: () {
                      rememberSearch(ref, query: ref.read(searchQueryProvider));
                      context.push('/post/${post.id}');
                    },
                  );
                }, childCount: posts.length),
              );
            },
          ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
  }

  Widget _buildCategoryChip(
    WidgetRef ref,
    String label,
    SearchCategory cat,
    SearchCategory current,
  ) {
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

/// A channel in the search results or the suggestions to follow.
class ChannelResultTile extends StatelessWidget {
  final Channel channel;
  final Color primaryColor;
  final Color secondaryColor;

  /// Called as the channel opens, to record the search that found it.
  final VoidCallback? onOpen;

  const ChannelResultTile({
    super.key,
    required this.channel,
    required this.primaryColor,
    required this.secondaryColor,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onOpen?.call();
        NavigationUtils.openChannel(context, channel.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            ChannelAvatar(
              title: channel.title,
              avatarPath: channel.avatarUrl,
              avatarFileId: channel.avatarFileId,
              avatarColorHex: channel.avatarColor,
            ),
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
                  if (channel.username != null)
                    Text(
                      AppStrings.handle(channel.username!),
                      style: AppTypography.username(color: secondaryColor),
                    ),
                ],
              ),
            ),
            Text(
              AppStrings.subscriberCountShort(
                TimeUtils.formatCount(channel.subscriberCount),
              ),
              style: AppTypography.actionCount(color: secondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Channel suggestions from Telegram's recommendations, as a sliver that
/// scrolls with the posts. Hidden while loading or when there are none.
class _WhoToFollow extends ConsumerWidget {
  /// How many suggestions are shown.
  static const int maxShown = 5;

  final Color primaryColor;
  final Color secondaryColor;
  final double topPadding;

  const _WhoToFollow({
    required this.primaryColor,
    required this.secondaryColor,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommended =
        ref.watch(recommendedChannelsProvider).value ?? const <Channel>[];

    if (recommended.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox(height: topPadding));
    }

    final shown = recommended.take(maxShown).toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: topPadding + AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.searchWhoToFollow,
                  style: AppTypography.subheading(color: primaryColor),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  AppStrings.searchWhoToFollowBody,
                  style: AppTypography.actionCount(color: secondaryColor),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => ChannelResultTile(
              channel: shown[index],
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
            childCount: shown.length,
          ),
        ),
      ],
    );
  }
}

/// The explore view shown when not searching: recent posts from the feed.
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
            // One request per session; see `recommendedChannelsProvider`.
            _WhoToFollow(
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              topPadding: topPadding,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.lg,
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
              delegate: SliverChildBuilderDelegate((context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onTap: () {
                    ref.read(markPostAsReadProvider(post.id));
                    context.push('/post/${post.id}');
                  },
                  onChannelTap: () =>
                      NavigationUtils.openChannel(context, post.channelId),
                  onBookmarkTap: () => ref
                      .read(bookmarkControllerProvider.notifier)
                      .toggle(post),
                );
              }, childCount: posts.length),
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
          ],
        );
      },
    );
  }
}

/// Opens the search tab with [hashtag] already entered. Lives here so
/// `core/`'s text renderer needs no knowledge of search.
void openHashtagSearch(BuildContext context, WidgetRef ref, String hashtag) {
  ref.read(searchQueryProvider.notifier).setQuery(hashtag);
  ref.read(searchCategoryProvider.notifier).setCategory(SearchCategory.posts);
  // Inside a tab, switch tabs. Elsewhere (a post or channel page over the
  // tabs, or the shell itself for a link) there is no tab shell to ask, and
  // asking threw, so the Search tab is gone to by its route.
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(ShellTab.search.index);
  } else {
    GoRouter.of(context).go(ShellTab.search.path);
  }
}
