import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/stats/data/stats_mapper.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';

import '../support/td_fixtures.dart';

void main() {
  group('StatsMapper.mapChannel', () {
    test('reads the period as dates rather than as seconds', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          startDate: 1719792000,
          endDate: 1727654400,
        ),
      )!;

      expect(
        stats.periodStart,
        DateTime.fromMillisecondsSinceEpoch(1719792000 * 1000),
      );
      expect(
        stats.periodEnd,
        DateTime.fromMillisecondsSinceEpoch(1727654400 * 1000),
      );
    });

    test('carries the figures and the growth Telegram computed', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          memberCount: TdFixtures.statisticalValueJson(
            value: 1200,
            previousValue: 900,
            growthRatePercentage: 33.3,
          ),
        ),
      )!;

      final followers = stats.figures[ChannelStatFigure.followers]!;
      expect(followers.value, 1200);
      expect(followers.previousValue, 900);
      expect(followers.growthPercentage, 33.3);
      expect(followers.hasGrowth, isTrue);
      expect(followers.isRising, isTrue);
    });

    // The only figure Telegram sends as a bare number, with no period behind
    // it — an arrow on it would be an invention.
    test('the notifications figure is a percentage with no growth', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(enabledNotificationsPercentage: 42.5),
      )!;

      final notifications = stats.figures[ChannelStatFigure.notifications]!;
      expect(notifications.value, 42.5);
      expect(notifications.isPercentage, isTrue);
      expect(notifications.hasGrowth, isFalse);
    });

    test('an unresolved graph keeps its token instead of being dropped', () {
      final stats = StatsMapper.mapChannel(TdFixtures.channelStatistics())!;

      final growth = stats.graphs[ChannelStatGraph.growth];
      expect(growth, isA<StatGraphPending>());
      expect((growth as StatGraphPending).token, 'token');
    });

    test('a graph that arrived with the reply is parsed there and then', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          memberCountGraph: TdFixtures.graphDataJson(
            TdFixtures.chartJson(
              series: const {
                'y0': [10, 20],
              },
            ),
          ),
        ),
      )!;

      final growth = stats.graphs[ChannelStatGraph.growth];
      expect(growth, isA<StatGraphReady>());
      expect((growth as StatGraphReady).graph.lines.single.values, [10, 20]);
    });

    // Unreadable is not empty: an empty chart frame reads as a channel with no
    // activity, so it has to arrive as "unavailable" instead.
    test('an unreadable graph becomes missing, not an empty chart', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          memberCountGraph: TdFixtures.graphDataJson('not json'),
        ),
      )!;

      expect(stats.graphs[ChannelStatGraph.growth], isA<StatGraphMissing>());
    });

    test('an error graph carries its reason for the log', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          memberCountGraph: TdFixtures.graphErrorJson('NOT_ENOUGH_DATA'),
        ),
      )!;

      final growth = stats.graphs[ChannelStatGraph.growth] as StatGraphMissing;
      expect(growth.reason, 'NOT_ENOUGH_DATA');
    });

    // The supergroup variant describes senders and administrators, which is a
    // different screen for a different thing.
    test('refuses a supergroup\'s statistics', () {
      expect(StatsMapper.mapChannel(TdFixtures.supergroupStatistics()), isNull);
    });
  });

  group('StatsMapper.recentPosts', () {
    test('keeps the counts and the message id', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          recentInteractions: [
            TdFixtures.interactionJson(
              messageId: 4194304,
              viewCount: 420,
              forwardCount: 7,
              reactionCount: 15,
            ),
          ],
        ),
      )!;

      final post = stats.recentPosts.single;
      expect(post.messageId, 4194304);
      expect(post.viewCount, 420);
      expect(post.forwardCount, 7);
      expect(post.reactionCount, 15);
    });

    // gramX has no screen to open a story on, so a row for one would go
    // nowhere — the inert control the hard rules forbid, wearing a list's
    // clothes.
    test('drops stories', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          recentInteractions: [
            TdFixtures.interactionJson(messageId: 1, isStory: true),
            TdFixtures.interactionJson(messageId: 2),
          ],
        ),
      )!;

      expect(stats.recentPosts.map((p) => p.messageId), [2]);
    });

    test('orders newest first', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          recentInteractions: [
            TdFixtures.interactionJson(messageId: 10),
            TdFixtures.interactionJson(messageId: 30),
            TdFixtures.interactionJson(messageId: 20),
          ],
        ),
      )!;

      expect(stats.recentPosts.map((p) => p.messageId), [30, 20, 10]);
    });

    // Each row's words are one local read, and Telegram sends hundreds of
    // these. The cap is what keeps the Content tab from becoming a sweep.
    test('is capped, keeping the newest', () {
      final stats = StatsMapper.mapChannel(
        TdFixtures.channelStatistics(
          recentInteractions: [
            for (var i = 0; i < StatsMapper.recentPostLimit + 20; i++)
              TdFixtures.interactionJson(messageId: i + 1),
          ],
        ),
      )!;

      expect(stats.recentPosts.length, StatsMapper.recentPostLimit);
      expect(
        stats.recentPosts.first.messageId,
        StatsMapper.recentPostLimit + 20,
      );
    });
  });
}
