import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/channels/data/channel_media_repository.dart';
import 'package:gramx/features/channels/domain/channel_tab.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

/// Identifies one tab of one channel.
@immutable
class ChannelTabKey {
  final String channelId;
  final ChannelTab tab;

  const ChannelTabKey(this.channelId, this.tab);

  @override
  bool operator ==(Object other) =>
      other is ChannelTabKey &&
      other.channelId == channelId &&
      other.tab == tab;

  @override
  int get hashCode => Object.hash(channelId, tab);

  @override
  String toString() => '$channelId/${tab.name}';
}

/// What one tab currently holds.
@immutable
class ChannelTabState {
  final List<Post> posts;
  final bool isLoading;

  /// Whether the tab has been fetched, so an empty tab isn't shown as loading.
  final bool hasFetched;

  /// True when TDLib reported no further page.
  final bool isExhausted;
  final Object? error;

  const ChannelTabState({
    this.posts = const [],
    this.isLoading = false,
    this.hasFetched = false,
    this.isExhausted = false,
    this.error,
  });

  /// Where the next page starts: zero on a fresh tab, otherwise the oldest
  /// loaded message, since TDLib pages a search backwards by message id.
  int get nextFromMessageId => posts.isEmpty
      ? 0
      : posts.map((p) => p.messageId).reduce((a, b) => a < b ? a : b);

  ChannelTabState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? hasFetched,
    bool? isExhausted,
    Object? error,
    bool clearError = false,
  }) {
    return ChannelTabState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      hasFetched: hasFetched ?? this.hasFetched,
      isExhausted: isExhausted ?? this.isExhausted,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Every channel tab's loaded pages. A tab is fetched only when selected, via
/// [ensureLoaded] from the tab controller. In-flight and exhausted flags stop
/// the scroll listener from requesting a page per frame.
class ChannelTabNotifier extends Notifier<Map<ChannelTabKey, ChannelTabState>> {
  @override
  Map<ChannelTabKey, ChannelTabState> build() => {};

  ChannelTabState stateFor(ChannelTabKey key) =>
      state[key] ?? const ChannelTabState();

  /// Loads the first page if the tab has never been fetched. Safe to call on
  /// every tab change.
  Future<void> ensureLoaded(ChannelTabKey key, int chatId) async {
    final current = stateFor(key);
    if (current.hasFetched || current.isLoading) return;
    await _fetch(key, chatId, fromMessageId: 0);
  }

  /// Loads the next page. Returns true if anything new arrived.
  Future<bool> loadMore(ChannelTabKey key, int chatId) async {
    final current = stateFor(key);
    if (current.isLoading || current.isExhausted || !current.hasFetched) {
      return false;
    }
    final before = current.posts.length;
    await _fetch(key, chatId, fromMessageId: current.nextFromMessageId);
    return stateFor(key).posts.length > before;
  }

  /// Drops a channel's loaded tabs, so a refresh doesn't duplicate them.
  void reset(String channelId) {
    final next = Map<ChannelTabKey, ChannelTabState>.from(state)
      ..removeWhere((key, _) => key.channelId == channelId);
    state = next;
  }

  Future<void> _fetch(
    ChannelTabKey key,
    int chatId, {
    required int fromMessageId,
  }) async {
    final before = stateFor(key);
    _put(key, before.copyWith(isLoading: true, clearError: true));

    try {
      final page = await ref
          .read(channelMediaRepositoryProvider)
          .fetchTabPage(chatId, key.tab, fromMessageId: fromMessageId);

      final known = before.posts.map((p) => p.id).toSet();
      final additions = page.posts.where((p) => !known.contains(p.id)).toList();

      _put(
        key,
        before.copyWith(
          posts: [...before.posts, ...additions],
          isLoading: false,
          hasFetched: true,
          // TDLib's end signal, or a later page that added only duplicates.
          isExhausted:
              page.isExhausted || (fromMessageId != 0 && additions.isEmpty),
        ),
      );
    } catch (e) {
      _put(key, before.copyWith(isLoading: false, hasFetched: true, error: e));
    }
  }

  void _put(ChannelTabKey key, ChannelTabState value) {
    state = {...state, key: value};
  }
}

final channelTabNotifierProvider =
    NotifierProvider<ChannelTabNotifier, Map<ChannelTabKey, ChannelTabState>>(
      ChannelTabNotifier.new,
    );

/// One tab's rows with optimistic reactions and bookmarks applied. Synchronous,
/// so a reaction tap doesn't re-run the search.
final channelTabPostsProvider = Provider.family<ChannelTabState, ChannelTabKey>(
  (ref, key) {
    final tabs = ref.watch(channelTabNotifierProvider);
    final base = tabs[key] ?? const ChannelTabState();
    if (base.posts.isEmpty) return base;

    final overrides = ref.watch(optimisticPostUpdatesProvider);
    final feedPosts = ref.watch(feedPostsProvider).value ?? [];
    final feedMap = {for (final p in feedPosts) p.id: p};

    return base.copyWith(
      posts: [
        for (final post in base.posts)
          applyPostOverrides(feedMap[post.id] ?? post, overrides),
      ],
    );
  },
);
