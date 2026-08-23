import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

Post comment({
  String id = '-100500_8',
  Map<String, int> reactions = const {},
  Set<String> chosen = const {},
}) =>
    Post(
      id: id,
      chatId: -100500,
      channelId: '-100500',
      messageId: 8,
      channelTitle: 'Discussion',
      publishedAt: DateTime(2026, 8, 22),
      reactions: reactions,
      chosenReactions: chosen,
    );

void main() {
  group('postCommentsProvider', () {
    test('a reaction shows immediately, without refetching the thread',
        () async {
      var fetches = 0;
      final container = ProviderContainer(overrides: [
        postCommentsFetchProvider.overrideWith((ref, postId) async {
          fetches++;
          return [comment()];
        }),
      ]);
      addTearDown(container.dispose);

      // Keep it alive, the way the screen does.
      container.listen(postCommentsProvider('-100500_4'), (_, _) {});
      await container.read(postCommentsFetchProvider('-100500_4').future);
      expect(fetches, 1);

      container
          .read(optimisticPostUpdatesProvider.notifier)
          .toggleReaction('-100500_8', '🔥', comment());

      final updated = container.read(postCommentsProvider('-100500_4')).value!;
      expect(updated.single.chosenReactions, {'🔥'});
      expect(updated.single.reactions['🔥'], 1);

      // The bug: overrides were watched inside the future, so every tap
      // re-ran the TDLib request and dropped the screen back to a spinner.
      expect(fetches, 1,
          reason: 'reacting must not cost a request or a loading state');
    });

    test('the thread keeps its data while an override changes', () async {
      final container = ProviderContainer(overrides: [
        postCommentsFetchProvider.overrideWith((ref, postId) async {
          return [comment()];
        }),
      ]);
      addTearDown(container.dispose);

      container.listen(postCommentsProvider('-100500_4'), (_, _) {});
      await container.read(postCommentsFetchProvider('-100500_4').future);

      container
          .read(optimisticPostUpdatesProvider.notifier)
          .toggleReaction('-100500_8', '❤️', comment());

      expect(container.read(postCommentsProvider('-100500_4')).isLoading,
          isFalse);
    });
  });

  group('postDetailProvider', () {
    test('a reaction on the post does not refetch it either', () async {
      var fetches = 0;
      final container = ProviderContainer(overrides: [
        postDetailFetchProvider.overrideWith((ref, postId) async {
          fetches++;
          return comment(id: '-100500_4');
        }),
      ]);
      addTearDown(container.dispose);

      container.listen(postDetailProvider('-100500_4'), (_, _) {});
      await container.read(postDetailFetchProvider('-100500_4').future);

      container
          .read(optimisticPostUpdatesProvider.notifier)
          .toggleReaction('-100500_4', '👍', comment(id: '-100500_4'));

      expect(container.read(postDetailProvider('-100500_4')).value!
          .chosenReactions, {'👍'});
      expect(fetches, 1);
    });
  });
}
