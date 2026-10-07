import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/domain/poll.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

const poll = Poll(
  id: '1',
  question: 'Launch?',
  options: [
    PollOption(text: 'Yes', voterCount: 3),
    PollOption(text: 'No', voterCount: 1),
  ],
  totalVoterCount: 4,
  isAnonymous: true,
  isClosed: false,
  isQuiz: false,
);

Post post() => Post(
  id: '-100_5',
  chatId: -100,
  channelId: '-100',
  messageId: 5,
  channelTitle: 'Nasa',
  publishedAt: DateTime(2026, 10, 7),
  poll: poll,
);

class _EmptyFeed extends FeedNotifier {
  @override
  Future<List<Post>> build() async => const [];
}

void main() {
  test('a vote counts the voter and the option', () {
    final voted = pollWithVote(poll, [1]);

    expect(voted.totalVoterCount, 5);
    expect(voted.chosenOptionIds, [1]);
    expect(voted.options[1].voterCount, 2);
    expect(voted.options[1].isChosen, isTrue);
    expect(voted.options[1].votePercentage, 40);
    expect(voted.options[0].votePercentage, 60);
  });

  // Telegram sends a poll's results as the message's new content, and they
  // were never read, so a vote never showed the real counts.
  test('new poll content is a live poll update', () {
    final update = mapCounterUpdate(
      td.UpdateMessageContent(
        chatId: -100,
        messageId: 5,
        newContent: td.MessagePoll(
          poll: td.Poll(
            id: 1,
            question: td.FormattedText(text: 'Launch?', entities: []),
            options: [
              td.PollOption(
                text: td.FormattedText(text: 'Yes', entities: []),
                voterCount: 3,
                votePercentage: 60,
                isChosen: false,
                isBeingChosen: false,
              ),
              td.PollOption(
                text: td.FormattedText(text: 'No', entities: []),
                voterCount: 2,
                votePercentage: 40,
                isChosen: true,
                isBeingChosen: false,
              ),
            ],
            totalVoterCount: 5,
            recentVoterIds: [],
            isAnonymous: true,
            type: td.PollTypeRegular(allowMultipleAnswers: false),
            openPeriod: 0,
            closeDate: 0,
            isClosed: false,
          ),
        ),
      ),
    );

    expect(update, isA<LivePollUpdate>());
    final live = update! as LivePollUpdate;
    expect(live.postId, '-100_5');
    expect(live.poll.totalVoterCount, 5);
    expect(live.poll.chosenOptionIds, [1]);
  });

  group('a vote in other views', () {
    late ProviderContainer c;
    setUp(() {
      c = ProviderContainer(
        overrides: [feedPostsProvider.overrideWith(_EmptyFeed.new)],
      );
      addTearDown(c.dispose);
    });

    Poll? shown() =>
        applyPostOverrides(post(), c.read(optimisticPostUpdatesProvider)).poll;

    test('shows the vote made in the feed', () {
      c
          .read(optimisticPostUpdatesProvider.notifier)
          .setPoll('-100_5', pollWithVote(poll, [0]));

      expect(shown()!.chosenOptionIds, [0]);
    });

    test('takes the real results once they come', () async {
      c
          .read(optimisticPostUpdatesProvider.notifier)
          .setPoll('-100_5', pollWithVote(poll, [0]));
      final real = pollWithVote(poll, [0]).copyWith(totalVoterCount: 9);

      await c.read(feedPostsProvider.future);
      c.read(feedPostsProvider.notifier).updatePollLive('-100_5', real);

      expect(shown()!.totalVoterCount, 9);
    });

    test('leaves polls not voted on here to their own data', () async {
      await c.read(feedPostsProvider.future);
      c.read(feedPostsProvider.notifier).updatePollLive('-100_5', poll);

      expect(c.read(optimisticPostUpdatesProvider), isEmpty);
    });
  });
}
