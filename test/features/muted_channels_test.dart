import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/channels/presentation/channels_list_screen.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

Channel channel({
  required String id,
  required int chatId,
  String title = 'Channel',
  String? username,
}) =>
    Channel(id: id, chatId: chatId, title: title, username: username);

void main() {
  // The mute set persists to a JSON file. There is no platform channel here,
  // so the write fails and is swallowed — initialising the binding keeps that
  // failure to one quiet line instead of a wall of framework advice.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mutedChannelsListProvider', () {
    // Muting hid a channel from the feed and from nothing else, so there was
    // no way back short of remembering the channel and opening its profile.
    test('lists the channels currently muted', () async {
      final channels = [
        channel(id: '-100111', chatId: -100111, title: 'Kept'),
        channel(id: '-100222', chatId: -100222, title: 'Muted', username: 'm'),
      ];
      final container = ProviderContainer(overrides: [
        channelsProvider.overrideWith((ref) async => channels),
      ]);
      addTearDown(container.dispose);

      container.listen(channelsProvider, (_, _) {});
      await container.read(channelsProvider.future);

      expect(container.read(mutedChannelsListProvider), isEmpty);

      container
          .read(mutedChannelsProvider.notifier)
          .toggleMute('-100222', chatId: -100222, username: 'm');

      expect(
        container.read(mutedChannelsListProvider).map((c) => c.title),
        ['Muted'],
      );
    });

    test('unmuting takes the channel back out of the list', () async {
      final channels = [
        channel(id: '-100222', chatId: -100222, title: 'Muted'),
      ];
      final container = ProviderContainer(overrides: [
        channelsProvider.overrideWith((ref) async => channels),
      ]);
      addTearDown(container.dispose);

      container.listen(channelsProvider, (_, _) {});
      await container.read(channelsProvider.future);

      final muted = container.read(mutedChannelsProvider.notifier);
      muted.toggleMute('-100222', chatId: -100222);
      expect(container.read(mutedChannelsListProvider), hasLength(1));

      muted.toggleMute('-100222', chatId: -100222);
      expect(container.read(mutedChannelsListProvider), isEmpty);
    });

    // The mute set holds every id a channel answers to — chat id, prefixed id,
    // username — so a channel muted from one screen must read as muted on the
    // other.
    test('recognises a channel muted under any of its ids', () async {
      final channels = [
        channel(
            id: '-100222', chatId: -100222, title: 'Muted', username: 'somech'),
      ];
      final container = ProviderContainer(overrides: [
        channelsProvider.overrideWith((ref) async => channels),
      ]);
      addTearDown(container.dispose);

      container.listen(channelsProvider, (_, _) {});
      await container.read(channelsProvider.future);

      container.read(mutedChannelsProvider.notifier).toggleMute('somech');

      expect(container.read(mutedChannelsListProvider), hasLength(1));
    });
  });
}
