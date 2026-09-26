import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/channels/data/channel_media_repository.dart';
import 'package:gramx/features/channels/domain/channel_tab.dart';
import 'package:gramx/features/channels/presentation/channel_tab_providers.dart';
import 'package:gramx/features/channels/presentation/widgets/channel_file_list.dart';
import 'package:gramx/features/channels/presentation/widgets/channel_media_grid.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';

/// Answers tab pages from a script instead of Telegram, and counts the calls.
///
/// The count is the point of most of this file: four of the five tabs are a
/// networked `SearchChatMessages`, so "how many requests did opening a channel
/// spend" is a correctness question, not a performance one.
class _RecordingMediaRepository implements ChannelMediaRepository {
  final List<({int chatId, ChannelTab tab, int fromMessageId})> calls = [];

  /// Pages to answer with, in order. Falls back to an exhausted empty page.
  final List<ChannelTabPage> pages;

  /// Thrown by the next call, then cleared.
  Object? nextError;

  _RecordingMediaRepository({this.pages = const []});

  @override
  Future<ChannelTabPage> fetchTabPage(
    int chatId,
    ChannelTab tab, {
    int fromMessageId = 0,
  }) async {
    calls.add((chatId: chatId, tab: tab, fromMessageId: fromMessageId));
    final error = nextError;
    nextError = null;
    if (error != null) throw error;

    final index = calls.length - 1;
    return index < pages.length ? pages[index] : ChannelTabPage.empty;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

Post _post(int messageId, {List<MediaItem> media = const []}) => Post(
      id: '-1001_$messageId',
      chatId: -1001,
      channelId: '-1001',
      messageId: messageId,
      channelTitle: 'Ashangulit',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(messageId * 1000),
      media: media,
    );

MediaItem _media(String id, MediaType type) => MediaItem(id: id, type: type);

void main() {
  group('ChannelMediaRepository.filterFor', () {
    // Each tab is one TDLib filter, and getting the mapping wrong shows the
    // reader someone else's content under the wrong heading.
    test('maps every tab to the filter it means', () {
      expect(ChannelMediaRepository.filterFor(ChannelTab.media),
          isA<td.SearchMessagesFilterPhotoAndVideo>());
      expect(ChannelMediaRepository.filterFor(ChannelTab.files),
          isA<td.SearchMessagesFilterDocument>());
      expect(ChannelMediaRepository.filterFor(ChannelTab.links),
          isA<td.SearchMessagesFilterUrl>());
      expect(ChannelMediaRepository.filterFor(ChannelTab.voice),
          isA<td.SearchMessagesFilterVoiceAndVideoNote>());
    });

    // Posts is the channel's plain history, already served by
    // channelPostsProvider. Searching for it would spend a networked request
    // to get back what is loaded.
    test('the Posts tab has no filter, because it is not a search', () {
      expect(ChannelMediaRepository.filterFor(ChannelTab.posts), isNull);
      expect(ChannelTab.posts.isHistory, isTrue);
      for (final tab in ChannelTab.values.where((t) => t != ChannelTab.posts)) {
        expect(tab.isHistory, isFalse);
      }
    });
  });

  group('ChannelTabNotifier', () {
    late _RecordingMediaRepository repo;
    late ProviderContainer container;
    late ChannelTabNotifier notifier;

    ProviderContainer build({List<ChannelTabPage> pages = const []}) {
      repo = _RecordingMediaRepository(pages: pages);
      final c = ProviderContainer(overrides: [
        channelMediaRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      container = build();
      notifier = container.read(channelTabNotifierProvider.notifier);
    });

    const mediaKey = ChannelTabKey('-1001', ChannelTab.media);
    const filesKey = ChannelTabKey('-1001', ChannelTab.files);

    // The tabs are swipeable, which means `TabBarView` now builds the
    // *adjacent* tab's body while a swipe is in flight. That body reads its
    // tab's state — so reading must stay free, or swiping past a tab would
    // fetch it, and the budget rule above would be broken by a gesture rather
    // than by a tap.
    test('reading a tab\'s state is not what fetches it', () {
      container.read(channelTabPostsProvider(mediaKey));
      container.read(channelTabPostsProvider(filesKey));

      expect(repo.calls, isEmpty);
    });

    test('a swipe settling on one tab fetches only that one', () async {
      // What `_onTabChanged` does once `indexIsChanging` clears: exactly one
      // `ensureLoaded`, for the index that settled.
      await notifier.ensureLoaded(filesKey, -1001);

      expect(repo.calls.map((c) => c.tab), [ChannelTab.files]);
    });

    // The budget rule. Five tabs fetched on open would be four networked
    // searches per channel visited, for content nobody asked to see — the same
    // shape of mistake as the cold-start fan-out this app once had.
    test('a tab that has not been selected costs no request', () async {
      expect(repo.calls, isEmpty);
      expect(notifier.stateFor(mediaKey).hasFetched, isFalse);
    });

    test('selecting a tab fetches it exactly once', () async {
      await notifier.ensureLoaded(mediaKey, -1001);
      await notifier.ensureLoaded(mediaKey, -1001);
      await notifier.ensureLoaded(mediaKey, -1001);

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.tab, ChannelTab.media);
      expect(repo.calls.single.fromMessageId, 0);
    });

    test('selecting a second tab does not refetch the first', () async {
      await notifier.ensureLoaded(mediaKey, -1001);
      await notifier.ensureLoaded(filesKey, -1001);

      expect(repo.calls.map((c) => c.tab),
          [ChannelTab.media, ChannelTab.files]);
    });

    test('the Posts tab is never searched', () async {
      // ChannelTab.posts has no filter, so even if the screen asked, the
      // repository answers empty rather than spending a request. The screen
      // also guards on isHistory; this is the second line of defence.
      final page = await repo.fetchTabPage(-1001, ChannelTab.posts);
      expect(page.posts, isEmpty);
      expect(page.isExhausted, isTrue);
    });

    group('pagination', () {
      test('loadMore pages from the oldest message loaded', () async {
        container = build(pages: [
          ChannelTabPage(posts: [_post(30), _post(20)], nextFromMessageId: 20),
          ChannelTabPage(posts: [_post(10)], nextFromMessageId: 10),
        ]);
        notifier = container.read(channelTabNotifierProvider.notifier);

        await notifier.ensureLoaded(mediaKey, -1001);
        await notifier.loadMore(mediaKey, -1001);

        expect(repo.calls.map((c) => c.fromMessageId), [0, 20]);
        expect(notifier.stateFor(mediaKey).posts.map((p) => p.messageId),
            [30, 20, 10]);
      });

      // The guard exists because pagination hangs off a scroll listener, which
      // fires on every frame near the bottom of a list. Without it that is a
      // networked request per frame, aimed at an account with a rate limit.
      test('an exhausted tab stops asking', () async {
        container = build(pages: [
          ChannelTabPage(posts: [_post(30)], nextFromMessageId: 0),
        ]);
        notifier = container.read(channelTabNotifierProvider.notifier);

        await notifier.ensureLoaded(mediaKey, -1001);
        expect(notifier.stateFor(mediaKey).isExhausted, isTrue);

        await notifier.loadMore(mediaKey, -1001);
        await notifier.loadMore(mediaKey, -1001);
        expect(repo.calls, hasLength(1));
      });

      test('loadMore before the tab is loaded does nothing', () async {
        expect(await notifier.loadMore(mediaKey, -1001), isFalse);
        expect(repo.calls, isEmpty);
      });

      test('a page of only duplicates ends the tab', () async {
        container = build(pages: [
          ChannelTabPage(posts: [_post(30), _post(20)], nextFromMessageId: 20),
          ChannelTabPage(posts: [_post(20)], nextFromMessageId: 20),
        ]);
        notifier = container.read(channelTabNotifierProvider.notifier);

        await notifier.ensureLoaded(mediaKey, -1001);
        expect(await notifier.loadMore(mediaKey, -1001), isFalse);
        expect(notifier.stateFor(mediaKey).isExhausted, isTrue);
      });
    });

    test('a failure is held on the tab, not thrown at the screen', () async {
      repo.nextError = StateError('FLOOD_WAIT_20');
      await notifier.ensureLoaded(mediaKey, -1001);

      final state = notifier.stateFor(mediaKey);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
      expect(state.hasFetched, isTrue);
    });

    // Without this a refresh stacks a second copy of every tab under the first.
    test('reset drops one channel and leaves the others', () async {
      await notifier.ensureLoaded(mediaKey, -1001);
      await notifier.ensureLoaded(
          const ChannelTabKey('-1002', ChannelTab.media), -1002);

      notifier.reset('-1001');

      expect(notifier.stateFor(mediaKey).hasFetched, isFalse);
      expect(
        notifier
            .stateFor(const ChannelTabKey('-1002', ChannelTab.media))
            .hasFetched,
        isTrue,
      );
    });
  });

  group('ChannelTabKey', () {
    test('is keyed by channel and tab together', () {
      expect(const ChannelTabKey('a', ChannelTab.media),
          const ChannelTabKey('a', ChannelTab.media));
      expect(const ChannelTabKey('a', ChannelTab.media),
          isNot(const ChannelTabKey('a', ChannelTab.files)));
      expect(const ChannelTabKey('a', ChannelTab.media),
          isNot(const ChannelTabKey('b', ChannelTab.media)));
    });
  });

  group('tab layouts', () {
    test('media is a grid, files are rows, the rest are cards', () {
      expect(ChannelTab.media.layout, ChannelTabLayout.grid);
      expect(ChannelTab.files.layout, ChannelTabLayout.fileRows);
      expect(ChannelTab.posts.layout, ChannelTabLayout.cards);
      expect(ChannelTab.links.layout, ChannelTabLayout.cards);
      expect(ChannelTab.voice.layout, ChannelTabLayout.cards);
    });

    // An album is several pictures, so it is several tiles — collapsing it to
    // one would hide the rest of the album from the tab that exists to show it.
    test('the grid flattens albums into one tile each', () {
      final tiles = ChannelMediaGrid.tilesFor([
        _post(30, media: [
          _media('a', MediaType.photo),
          _media('b', MediaType.photo),
        ]),
        _post(20, media: [_media('c', MediaType.video)]),
      ]);

      expect(tiles, hasLength(3));
      expect(tiles.map((t) => t.item.id), ['a', 'b', 'c']);
      expect(tiles.first.post.messageId, 30);
    });

    test('the grid skips documents and audio', () {
      final tiles = ChannelMediaGrid.tilesFor([
        _post(30, media: [
          _media('doc', MediaType.document),
          _media('voice', MediaType.voice),
          _media('pic', MediaType.photo),
        ]),
      ]);

      expect(tiles.map((t) => t.item.id), ['pic']);
    });

    test('the file list takes documents and nothing else', () {
      final rows = ChannelFileList.rowsFor([
        _post(30, media: [
          _media('doc', MediaType.document),
          _media('pic', MediaType.photo),
        ]),
      ]);

      expect(rows.map((r) => r.item.id), ['doc']);
    });
  });
}
