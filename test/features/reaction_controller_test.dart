import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/reaction_controller.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

Post post({
  Map<String, int> reactions = const {},
  Set<String> chosen = const {},
}) => Post(
  id: '-100_5',
  chatId: -100,
  channelId: '-100',
  messageId: 5,
  channelTitle: 'Nasa',
  publishedAt: DateTime(2026, 10, 7),
  reactions: reactions,
  chosenReactions: chosen,
);

/// Records reactions, and refuses them when told to.
class _Sync implements SyncService {
  final List<({String emoji, bool remove})> sent = [];
  bool refuse = false;

  @override
  Future<bool> togglePostReaction({
    required int chatId,
    required int messageId,
    required String reactionEmoji,
    required bool isCurrentlyLiked,
  }) async {
    sent.add((emoji: reactionEmoji, remove: isCurrentlyLiked));
    return !refuse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _EmptyFeed extends FeedNotifier {
  @override
  Future<List<Post>> build() async => const [];
}

void main() {
  late _Sync sync;
  late ProviderContainer c;

  setUp(() {
    sync = _Sync();
    c = ProviderContainer(
      overrides: [
        syncServiceProvider.overrideWithValue(sync),
        feedPostsProvider.overrideWith(_EmptyFeed.new),
      ],
    );
    addTearDown(c.dispose);
  });

  Post shown(Post p) =>
      applyPostOverrides(p, c.read(optimisticPostUpdatesProvider));

  test('a reaction shows at once and is sent', () async {
    final p = post();
    final sent = await c
        .read(reactionControllerProvider.notifier)
        .react(p, '👍');

    expect(sent, isTrue);
    expect(sync.sent.single, (emoji: '👍', remove: false));
    expect(shown(p).chosenReactions, {'👍'});
    expect(shown(p).reactions, {'👍': 1});
  });

  // A refused reaction stayed on screen as if it had worked.
  test('a refused reaction puts back what was shown', () async {
    sync.refuse = true;
    final p = post(reactions: {'🔥': 3}, chosen: {'🔥'});

    final sent = await c
        .read(reactionControllerProvider.notifier)
        .react(p, '🔥');

    expect(sent, isFalse);
    expect(shown(p).reactions, {'🔥': 3});
    expect(shown(p).chosenReactions, {'🔥'});
  });

  test('paid and custom emoji placeholders are never sent', () async {
    final p = post(reactions: {TdlibMappers.paidReactionEmoji: 2});

    final sent = await c
        .read(reactionControllerProvider.notifier)
        .react(p, TdlibMappers.paidReactionEmoji);

    expect(sent, isFalse);
    expect(sync.sent, isEmpty);
    expect(shown(p).reactions, {TdlibMappers.paidReactionEmoji: 2});
  });

  // The server's echo used to drop the reaction made here, so views other
  // than the feed snapped back to the snapshot from before the tap.
  test('a live update keeps a reaction made here current', () async {
    final p = post();
    await c.read(reactionControllerProvider.notifier).react(p, '👍');

    await c.read(feedPostsProvider.future);
    c
        .read(feedPostsProvider.notifier)
        .updateReactionsLive(p.id, {'👍': 4}, {'👍'});

    expect(shown(p).reactions, {'👍': 4});
    expect(shown(p).chosenReactions, {'👍'});
  });

  test('a live update leaves untouched posts to their own data', () async {
    await c.read(feedPostsProvider.future);
    c.read(feedPostsProvider.notifier).updateReactionsLive('-100_9', {
      '👍': 4,
    }, const {});

    expect(c.read(optimisticPostUpdatesProvider), isEmpty);
  });
}
