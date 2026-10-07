import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/channels_list_screen.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

Channel channel({
  required String id,
  required int chatId,
  String title = 'Channel',
  String? username,
}) => Channel(id: id, chatId: chatId, title: title, username: username);

void main() {
  // The mute set's file write fails without a platform channel; the binding
  // keeps that failure quiet.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mutedChannelsListProvider', () {
    // Gives a way to unmute without finding the channel's profile.
    test('lists the channels currently muted', () async {
      final channels = [
        channel(id: '-100111', chatId: -100111, title: 'Kept'),
        channel(id: '-100222', chatId: -100222, title: 'Muted', username: 'm'),
      ];
      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) async => channels),
          // Unmuting looks up the channel's usernames in the chat cache.
          chatCacheProvider.overrideWith((ref) => ChatCache(_SilentTdlib())),
        ],
      );
      addTearDown(container.dispose);

      container.listen(channelsProvider, (_, _) {});
      await container.read(channelsProvider.future);

      expect(container.read(mutedChannelsListProvider), isEmpty);

      container
          .read(mutedChannelsProvider.notifier)
          .toggleMute('-100222', chatId: -100222, username: 'm');

      expect(container.read(mutedChannelsListProvider).map((c) => c.title), [
        'Muted',
      ]);
    });

    test('unmuting takes the channel back out of the list', () async {
      final channels = [
        channel(id: '-100222', chatId: -100222, title: 'Muted'),
      ];
      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) async => channels),
          // Unmuting looks up the channel's usernames in the chat cache.
          chatCacheProvider.overrideWith((ref) => ChatCache(_SilentTdlib())),
        ],
      );
      addTearDown(container.dispose);

      container.listen(channelsProvider, (_, _) {});
      await container.read(channelsProvider.future);

      final muted = container.read(mutedChannelsProvider.notifier);
      muted.toggleMute('-100222', chatId: -100222);
      expect(container.read(mutedChannelsListProvider), hasLength(1));

      muted.toggleMute('-100222', chatId: -100222);
      expect(container.read(mutedChannelsListProvider), isEmpty);
    });

    // The mute set holds every id a channel answers to (chat id, prefixed id,
    // username).
    test('recognises a channel muted under any of its ids', () async {
      final channels = [
        channel(
          id: '-100222',
          chatId: -100222,
          title: 'Muted',
          username: 'somech',
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) async => channels),
          // Unmuting looks up the channel's usernames in the chat cache.
          chatCacheProvider.overrideWith((ref) => ChatCache(_SilentTdlib())),
        ],
      );
      addTearDown(container.dispose);

      container.listen(channelsProvider, (_, _) {});
      await container.read(channelsProvider.future);

      container.read(mutedChannelsProvider.notifier).toggleMute('somech');

      expect(container.read(mutedChannelsListProvider), hasLength(1));
    });
  });
}

/// A TDLib that sends no updates and answers nothing.
class _SilentTdlib implements TdlibService {
  @override
  Stream<td.TdObject> get updatesStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
