import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/guest/data/guest_channel_store.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/data/tme_preview_client.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';

/// Undoing a removal, searching added channels, and paging back through a
/// guest channel.
void main() {
  GuestChannel channel(String username) => GuestChannel(
    username: username,
    title: 'Channel $username',
    addedAt: DateTime.utc(2026, 1, 1),
  );

  /// `Override` is not part of Riverpod's public export, so containers are
  /// built inline rather than through a helper that would have to name it.
  ProviderContainer keep(ProviderContainer container) {
    addTearDown(container.dispose);
    return container;
  }

  // Adding fetched the channel, then saved the list from before the fetch,
  // so a channel removed meanwhile came back.
  test('a channel removed while another is added stays removed', () async {
    final tme = GatedTme();
    final container = keep(
      ProviderContainer(
        overrides: [
          guestChannelStoreProvider.overrideWithValue(
            MemoryStore([channel('alpha'), channel('bravo')]),
          ),
          tmePreviewClientProvider.overrideWithValue(tme),
        ],
      ),
    );
    final notifier = container.read(guestChannelsProvider.notifier);
    await container.read(guestChannelsProvider.future);

    final adding = notifier.add('charlie');
    await notifier.remove('alpha');
    tme.gate.complete();
    await adding;

    expect(
      container.read(guestChannelsProvider).value!.map((c) => c.username),
      ['charlie', 'bravo'],
    );
  });

  group('undo', () {
    test('puts a removed channel back where it was', () async {
      final container = keep(
        ProviderContainer(
          overrides: [
            guestChannelStoreProvider.overrideWithValue(
              MemoryStore([
                channel('alpha'),
                channel('bravo'),
                channel('delta'),
              ]),
            ),
          ],
        ),
      );
      final notifier = container.read(guestChannelsProvider.notifier);
      await container.read(guestChannelsProvider.future);

      final removed = container.read(guestChannelsProvider).value![1];
      await notifier.remove(removed.username);
      expect(
        container.read(guestChannelsProvider).value!.map((c) => c.username),
        ['alpha', 'delta'],
      );

      await notifier.restore(removed, 1);

      expect(
        container.read(guestChannelsProvider).value!.map((c) => c.username),
        ['alpha', 'bravo', 'delta'],
        reason: 'undo restores the order, not just the row',
      );
    });

    // Undo after re-adding the same channel must not duplicate the row.
    test(
      'does not add a second copy of a channel that is already back',
      () async {
        final container = keep(
          ProviderContainer(
            overrides: [
              guestChannelStoreProvider.overrideWithValue(
                MemoryStore([channel('alpha')]),
              ),
            ],
          ),
        );
        final notifier = container.read(guestChannelsProvider.notifier);
        await container.read(guestChannelsProvider.future);

        await notifier.restore(channel('alpha'), 0);

        expect(container.read(guestChannelsProvider).value!.length, 1);
      },
    );

    test('restores at the end when the list has since shrunk', () async {
      final container = keep(
        ProviderContainer(
          overrides: [
            guestChannelStoreProvider.overrideWithValue(
              MemoryStore([channel('alpha')]),
            ),
          ],
        ),
      );
      final notifier = container.read(guestChannelsProvider.notifier);
      await container.read(guestChannelsProvider.future);

      await notifier.restore(channel('bravo'), 9);

      expect(
        container.read(guestChannelsProvider).value!.map((c) => c.username),
        ['alpha', 'bravo'],
      );
    });
  });

  group('search', () {
    // A guest can't search Telegram's servers, but can search their own list.
    test('matches the channels a guest has added', () async {
      final container = keep(
        ProviderContainer(
          overrides: [
            guestChannelStoreProvider.overrideWithValue(
              MemoryStore([channel('alpha'), channel('bravo')]),
            ),
            readerCapabilitiesProvider.overrideWithValue(
              ReaderCapabilities.guest,
            ),
            debouncedSearchQueryProvider.overrideWith(() => FixedQuery('alp')),
          ],
        ),
      );

      final results = await container.read(searchChannelsProvider.future);

      expect(results.map((c) => c.username), ['alpha']);
      expect(
        results.single.chatId,
        GuestPostMapper.syntheticChatId('alpha'),
        reason: 'the row has to open the same channel screen the feed does',
      );
    });

    test('matches on the title as well as the handle', () async {
      final container = keep(
        ProviderContainer(
          overrides: [
            guestChannelStoreProvider.overrideWithValue(
              MemoryStore([channel('alpha'), channel('bravo')]),
            ),
            readerCapabilitiesProvider.overrideWithValue(
              ReaderCapabilities.guest,
            ),
            debouncedSearchQueryProvider.overrideWith(
              () => FixedQuery('Channel'),
            ),
          ],
        ),
      );

      final results = await container.read(searchChannelsProvider.future);

      expect(results.length, 2);
    });
  });

  group('paging a guest channel', () {
    Post guestPost(String username, int seq) {
      final chatId = GuestPostMapper.syntheticChatId(username);
      return Post(
        id: '${chatId}_$seq',
        chatId: chatId,
        channelId: '$chatId',
        messageId: seq,
        channelTitle: 'Channel $username',
        channelUsername: username,
        publishedAt: DateTime.utc(2026, 8, 25),
      );
    }

    // A guest channel pages through t.me, not the TDLib repository.
    test('asks t.me for the page below the oldest post on screen', () async {
      final tme = ScriptedTme();
      final chatId = GuestPostMapper.syntheticChatId('alpha');
      final container = keep(
        ProviderContainer(
          overrides: [
            guestChannelStoreProvider.overrideWithValue(
              MemoryStore([channel('alpha')]),
            ),
            tmePreviewClientProvider.overrideWithValue(tme),
            initialChannelPostsProvider.overrideWith(
              (ref, id) async => [
                guestPost('alpha', 30),
                guestPost('alpha', 29),
              ],
            ),
          ],
        ),
      );

      // loadMore reads the initial page synchronously, so it has to have
      // resolved before there is an oldest post to page from.
      await container.read(initialChannelPostsProvider('$chatId').future);

      final added = await container
          .read(olderChannelPostsProvider.notifier)
          .loadMore('$chatId');

      expect(tme.requested, ['alpha|29']);
      expect(added, isTrue);
      expect(
        container
            .read(olderChannelPostsProvider)['$chatId']!
            .map((p) => p.messageId),
        [28],
      );
    });

    // Both the id range and a username are required, so a real chat whose id
    // falls in the range is not sent to the web preview.
    test('a post with no username still goes to TDLib', () async {
      final tme = ScriptedTme();
      final repo = RecordingRepository();
      final container = keep(
        ProviderContainer(
          overrides: [
            guestChannelStoreProvider.overrideWithValue(MemoryStore(const [])),
            tmePreviewClientProvider.overrideWithValue(tme),
            feedRepositoryProvider.overrideWithValue(repo),
            initialChannelPostsProvider.overrideWith(
              (ref, id) async => [
                Post(
                  id: '-100500_10',
                  chatId: -100500,
                  channelId: '-100500',
                  messageId: 10,
                  channelTitle: 'Channel',
                  publishedAt: DateTime.utc(2026, 8, 25),
                ),
              ],
            ),
          ],
        ),
      );

      await container.read(initialChannelPostsProvider('-100500').future);
      await container
          .read(olderChannelPostsProvider.notifier)
          .loadMore('-100500');

      expect(tme.requested, isEmpty);
      expect(repo.requestedFrom, [10]);
    });
  });
}

/// A settled query, standing in for the debounce timer.
class FixedQuery extends DebouncedSearchQueryNotifier {
  FixedQuery(this.query);

  final String query;

  @override
  String build() => query;
}

/// Answers one page of history for `alpha`, and records what it was asked.
class ScriptedTme extends TmePreviewClient {
  final List<String> requested = [];

  @override
  Future<TmeFetchResult> fetchPage(
    String username, {
    int? before,
    String? etag,
    String? lastModified,
  }) async {
    requested.add(before == null ? username : '$username|$before');
    return TmeFetchSuccess(
      GuestChannelPage(
        channel: GuestChannelInfo(username: username, title: username),
        posts: [
          GuestPost(
            id: '$username/28',
            seq: 28,
            publishedAt: DateTime.utc(2026, 8, 24),
          ),
        ],
        olderCursor: 28,
      ),
    );
  }
}

/// Answers once [gate] opens.
class GatedTme extends ScriptedTme {
  final gate = Completer<void>();

  @override
  Future<TmeFetchResult> fetchPage(
    String username, {
    int? before,
    String? etag,
    String? lastModified,
  }) async {
    await gate.future;
    return super.fetchPage(username, before: before);
  }
}

class RecordingRepository implements FeedRepository {
  final List<int> requestedFrom = [];

  @override
  Future<List<Post>> fetchChannelPosts(
    int chatId, {
    int fromMessageId = 0,
    int limit = 50,
  }) async {
    requestedFrom.add(fromMessageId);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// The channel list, without a file behind it.
class MemoryStore extends GuestChannelStore {
  MemoryStore(this._channels);

  List<GuestChannel> _channels;

  @override
  Future<List<GuestChannel>> load() async => _channels;

  @override
  Future<void> save(List<GuestChannel> channels) async => _channels = channels;

  @override
  Future<void> clear() async => _channels = [];
}
