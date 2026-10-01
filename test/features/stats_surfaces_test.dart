import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/stats/domain/channel_stats.dart';
import 'package:gramx/features/stats/domain/stat_graph.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_chart.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_figure_tile.dart';
import 'package:gramx/features/stats/presentation/widgets/stat_section.dart';

Post _post() => Post(
  id: '-100123_4194304',
  chatId: -100123,
  channelId: '-100123',
  messageId: 4194304,
  channelTitle: 'gramX',
  publishedAt: DateTime(2026, 9, 3),
  viewCount: 420,
);

StatGraph _graph({List<double> values = const [1, 2, 3]}) => StatGraph(
  timestamps: [
    for (var i = 0; i < values.length; i++) 1719792000000 + i * 86400000,
  ],
  lines: [
    StatGraphLine(
      key: 'y0',
      name: 'Views',
      shape: StatGraphShape.line,
      values: values,
    ),
  ],
);

void main() {
  Widget host(Widget child) => ProviderScope(
    overrides: [
      readerCapabilitiesProvider.overrideWithValue(ReaderCapabilities.signedIn),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  Widget actionBar({VoidCallback? onViewsTap}) => PostActionBar(
    post: _post(),
    secondaryColor: const Color(0xFF71767B),
    onBookmarkTap: () {},
    onSelectReaction: (_) {},
    onReplyTap: () {},
    onShareTap: () {},
    onViewsTap: onViewsTap,
  );

  // The view count is a control only where there are analytics behind it.
  group('the view count', () {
    testWidgets('is a plain figure where there are no analytics', (
      tester,
    ) async {
      await tester.pumpWidget(host(actionBar()));

      final views = find.ancestor(
        of: find.byIcon(Icons.bar_chart),
        matching: find.byType(PostStat),
      );
      expect(views, findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.bar_chart),
          matching: find.byType(PostActionButton),
        ),
        findsNothing,
      );
    });

    testWidgets('is a button where they open', (tester) async {
      var opened = 0;
      await tester.pumpWidget(host(actionBar(onViewsTap: () => opened++)));

      await tester.tap(find.byIcon(Icons.bar_chart));
      expect(opened, 1);
    });

    testWidgets('says what it opens, for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(actionBar(onViewsTap: () {})));

      expect(
        find.bySemanticsLabel(AppStrings.a11yPostAnalytics),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('StatFigureTile', () {
    testWidgets('draws the arrow only for a change worth reporting', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const StatFigureTile(
            label: 'Followers',
            figure: StatFigure(value: 1200, growthPercentage: 33),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('1.2K'), findsOneWidget);
    });

    testWidgets('points down for a fall', (tester) async {
      await tester.pumpWidget(
        host(
          const StatFigureTile(
            label: 'Views per post',
            figure: StatFigure(value: 800, growthPercentage: -20),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });

    // Telegram reports zero growth for both "unchanged" and "no prior period".
    testWidgets('draws no arrow at all for zero', (tester) async {
      await tester.pumpWidget(
        host(
          const StatFigureTile(
            label: 'Followers',
            figure: StatFigure(value: 1200, growthPercentage: 0),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets('a percentage figure reads as one', (tester) async {
      await tester.pumpWidget(
        host(
          const StatFigureTile(
            label: 'Notifications enabled',
            figure: StatFigure(value: 42.5, isPercentage: true),
          ),
        ),
      );

      expect(find.text('42.5%'), findsOneWidget);
    });

    test('a whole percentage loses its trailing zero', () {
      expect(
        StatFigureTile.format(const StatFigure(value: 43, isPercentage: true)),
        '43%',
      );
    });
  });

  group('StatSection', () {
    testWidgets('draws the chart when the data is there', (tester) async {
      await tester.pumpWidget(
        host(
          StatSection(
            chatId: -100123,
            title: AppStrings.statsGraphGrowth,
            source: StatGraphReady(_graph()),
            slug: 'growth',
          ),
        ),
      );

      expect(find.text(AppStrings.statsGraphGrowth), findsOneWidget);
      expect(find.byType(StatChart), findsOneWidget);
    });

    // An empty chart frame would read as a channel with no activity.
    testWidgets(
      'says a chart is unavailable rather than drawing an empty one',
      (tester) async {
        await tester.pumpWidget(
          host(
            const StatSection(
              chatId: -100123,
              title: AppStrings.statsGraphGrowth,
              source: StatGraphMissing('NOT_ENOUGH_DATA'),
              slug: 'growth',
            ),
          ),
        );

        expect(find.text(AppStrings.statsGraphUnavailable), findsOneWidget);
        expect(find.byType(StatChart), findsNothing);
      },
    );

    testWidgets('never shows Telegram\'s own error text to the reader', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const StatSection(
            chatId: -100123,
            title: AppStrings.statsGraphGrowth,
            source: StatGraphMissing('NOT_ENOUGH_DATA'),
            slug: 'growth',
          ),
        ),
      );

      expect(find.textContaining('NOT_ENOUGH_DATA'), findsNothing);
    });
  });

  // stat_chart_geometry_test covers the arithmetic; this checks that the
  // shapes it produces can be rasterised.
  group('StatChart paints', () {
    for (final entry in {
      'a single sample': [5.0],
      'a flat series': [7.0, 7.0, 7.0],
      'nothing but zeroes': [0.0, 0.0],
      'a long series': List.filled(90, 3.0),
    }.entries) {
      testWidgets(entry.key, (tester) async {
        await tester.pumpWidget(
          host(
            StatChart(
              graph: _graph(values: entry.value),
              semanticLabel: AppStrings.statsGraphGrowth,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
