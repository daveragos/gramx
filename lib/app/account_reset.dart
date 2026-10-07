import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:gramx/features/activity/presentation/activity_providers.dart';
import 'package:gramx/features/bookmarks/presentation/bookmark_providers.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/channel_tab_providers.dart';
import 'package:gramx/features/chats/presentation/chat_search_providers.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/chats/presentation/conversation_providers.dart';
import 'package:gramx/features/compose/presentation/sticker_providers.dart';
import 'package:gramx/features/feed/presentation/custom_emoji_provider.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/read_receipt_queue.dart';
import 'package:gramx/features/search/data/recent_searches.dart';
import 'package:gramx/features/search/presentation/search_filters_sheet.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/stats/presentation/stats_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_identity.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// Forgets what the app holds for the account signed in before, so the next
/// one starts clean. Its changes, reads and searches carried over, and
/// TDLib's file ids, which start again in a new session, could show the old
/// account's pictures.
///
/// The feed, channels and folders already rebuild on signing in.
void forgetPreviousAccount(Ref ref) {
  for (final provider in <ProviderOrFamily>[
    // Posts.
    optimisticPostUpdatesProvider,
    markPostAsReadProvider,
    readReceiptQueueProvider,
    activeFolderProvider,
    customEmojiProvider,
    bookmarksProvider,
    bookmarkFilterProvider,
    activityFeedProvider,
    activityBadgeProvider,

    // Channels.
    channelDetailProvider,
    channelPinnedPostProvider,
    initialChannelPostsProvider,
    olderChannelPostsProvider,
    similarChannelsProvider,
    similarChannelCountProvider,
    recommendedChannelsProvider,
    channelTabNotifierProvider,
    channelTabPostsProvider,
    channelStatsProvider,
    channelStatsExcerptsProvider,
    postStatsProvider,
    publicSharesProvider,
    canViewPostStatsProvider,
    statGraphsProvider,

    // Chats.
    chatListProvider,
    chatFilterProvider,
    chatSearchQueryProvider,
    conversationProvider,
    pinnedMessageProvider,
    messageActionsProvider,
    chatReactionsProvider,
    inChatSearchQueryProvider,
    chatIdentityProvider,
    savedGifsProvider,
    installedStickerSetsProvider,
    stickersProvider,

    // Search.
    searchQueryProvider,
    searchFiltersProvider,
    searchCategoryProvider,
    recentChatsProvider,

    // Files.
    fileDownloadProgressProvider,
    fileDownloadStatusProvider,
    fileDownloadProvider,
    fileExistsProvider,
  ]) {
    ref.invalidate(provider);
  }
}
