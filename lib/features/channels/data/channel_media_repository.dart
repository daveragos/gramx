import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/channels/domain/channel_tab.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// One page of a channel tab, plus where the next one starts.
class ChannelTabPage {
  final List<Post> posts;

  /// The next `fromMessageId`; zero means the tab has ended.
  final int nextFromMessageId;

  const ChannelTabPage({required this.posts, required this.nextFromMessageId});

  static const empty = ChannelTabPage(posts: [], nextFromMessageId: 0);

  bool get isExhausted => nextFromMessageId == 0;
}

/// Backs the Media, Files, Links and Voice tabs. Each page is a networked
/// search, so fetch only when a tab is selected, never in a loop.
class ChannelMediaRepository {
  final TdlibService _tdlib;
  final FeedRepository _feed;

  /// Messages asked for per page. TDLib can return fewer, so pagination
  /// follows `nextFromMessageId` rather than counting rows.
  static const int pageSize = 50;

  ChannelMediaRepository(this._tdlib, this._feed);

  /// The TDLib filter a tab searches with. [ChannelTab.posts] has none, since
  /// it is the plain history from `channelPostsProvider`.
  static td.SearchMessagesFilter? filterFor(ChannelTab tab) => switch (tab) {
    ChannelTab.posts => null,
    ChannelTab.media => const td.SearchMessagesFilterPhotoAndVideo(),
    ChannelTab.files => const td.SearchMessagesFilterDocument(),
    ChannelTab.links => const td.SearchMessagesFilterUrl(),
    // Voice notes and round videos together, the way Telegram groups them.
    ChannelTab.voice => const td.SearchMessagesFilterVoiceAndVideoNote(),
  };

  /// One page of a tab. [fromMessageId] is 0 for the first page, then whatever
  /// the previous page reported.
  Future<ChannelTabPage> fetchTabPage(
    int chatId,
    ChannelTab tab, {
    int fromMessageId = 0,
  }) async {
    final filter = filterFor(tab);
    if (filter == null) return ChannelTabPage.empty;

    try {
      final res = await _tdlib.sendRequest(
        td.SearchChatMessages(
          chatId: chatId,
          query: '',
          fromMessageId: fromMessageId,
          offset: 0,
          limit: pageSize,
          filter: filter,
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );

      if (res is! td.FoundChatMessages) return ChannelTabPage.empty;

      final posts = await _feed.mapChannelMessages(chatId, res.messages);
      return ChannelTabPage(
        posts: posts,
        nextFromMessageId: res.nextFromMessageId,
      );
    } catch (e) {
      debugPrint('[ChannelMedia] ${tab.name} page failed: $e');
      rethrow;
    }
  }

  /// The channel's newest pinned message, or null if it has none. TDLib
  /// answers 400 when nothing is pinned.
  Future<Post?> fetchPinnedPost(int chatId) async {
    try {
      final res = await _tdlib.sendRequest(
        td.GetChatPinnedMessage(chatId: chatId),
      );
      if (res is! td.Message) return null;

      final posts = await _feed.mapChannelMessages(chatId, [res]);
      return posts.isEmpty ? null : posts.first;
    } catch (e) {
      debugPrint('[ChannelMedia] no pinned message for $chatId: $e');
      return null;
    }
  }
}

final channelMediaRepositoryProvider = Provider<ChannelMediaRepository>((ref) {
  return ChannelMediaRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(feedRepositoryProvider),
  );
});
