import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/search/data/recent_searches.dart';
import 'package:gramx/features/search/domain/search_filters.dart';
import 'package:gramx/features/search/presentation/recent_searches_view.dart';
import 'package:gramx/features/search/presentation/search_filters_sheet.dart';

Post post({int? replyTo, String? forwardedFrom}) => Post(
  id: '-100_5',
  chatId: -100,
  channelId: '-100',
  messageId: 5,
  channelTitle: 'Nasa',
  publishedAt: DateTime(2026, 10, 7),
  replyToMessageId: replyTo,
  forwardedFromChatId: forwardedFrom,
);

/// Keeps recent searches in memory instead of a file.
class _MemoryStore extends RecentQueryStore {
  List<String> saved;

  _MemoryStore([this.saved = const []]);

  @override
  Future<List<String>> load() async => saved;

  @override
  Future<void> save(List<String> queries) async => saved = queries;
}

void main() {
  group('SearchFilters', () {
    test('starts with nothing set', () {
      expect(const SearchFilters().isDefault, isTrue);
      expect(const SearchFilters(excludeReplies: true).isDefault, isFalse);
    });

    test('reaches back by the chosen span', () {
      final now = DateTime.utc(2026, 10, 7, 12);
      expect(const SearchFilters().minDateFor(now), 0);
      expect(
        const SearchFilters(date: SearchDateRange.week).minDateFor(now),
        DateTime.utc(2026, 9, 30, 12).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('leaves out replies and reposts when asked', () {
      const both = SearchFilters(excludeReplies: true, excludeReposts: true);
      expect(both.keeps(post()), isTrue);
      expect(both.keeps(post(replyTo: 4)), isFalse);
      expect(both.keeps(post(forwardedFrom: '-200')), isFalse);
      expect(const SearchFilters().keeps(post(replyTo: 4)), isTrue);
    });

    test('a folder can be set and cleared', () {
      const filters = SearchFilters(date: SearchDateRange.day);
      expect(filters.withFolder(3).folderId, 3);
      expect(filters.withFolder(3).withFolder(null).folderId, isNull);
      expect(filters.withFolder(3).date, SearchDateRange.day);
    });

    test('each type is a filter Telegram applies', () {
      expect(FeedRepository.searchFilterFor(SearchMediaType.any), isNull);
      expect(
        FeedRepository.searchFilterFor(SearchMediaType.photos),
        isA<td.SearchMessagesFilterPhoto>(),
      );
      expect(
        FeedRepository.searchFilterFor(SearchMediaType.links),
        isA<td.SearchMessagesFilterUrl>(),
      );
      expect(
        FeedRepository.searchFilterFor(SearchMediaType.voice),
        isA<td.SearchMessagesFilterVoiceNote>(),
      );
    });
  });

  group('RecentQueries', () {
    ProviderContainer container(_MemoryStore store) {
      final c = ProviderContainer(
        overrides: [recentQueryStoreProvider.overrideWithValue(store)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('puts the newest first, once whatever its case', () async {
      final store = _MemoryStore();
      final c = container(store);
      c.read(recentQueriesProvider);
      await Future<void>.delayed(Duration.zero);

      final notifier = c.read(recentQueriesProvider.notifier);
      notifier.add('flutter');
      notifier.add('Messi');
      notifier.add('FLUTTER');

      expect(c.read(recentQueriesProvider), ['FLUTTER', 'Messi']);
      expect(store.saved, ['FLUTTER', 'Messi']);
    });

    test('keeps only the last few', () async {
      final c = container(_MemoryStore());
      c.read(recentQueriesProvider);
      await Future<void>.delayed(Duration.zero);

      for (var i = 0; i < 15; i++) {
        c.read(recentQueriesProvider.notifier).add('q$i');
      }

      final queries = c.read(recentQueriesProvider);
      expect(queries, hasLength(RecentQueries.limit));
      expect(queries.first, 'q14');
    });

    test('comes back from disk, and clears', () async {
      final store = _MemoryStore(['saved']);
      final c = container(store);
      c.read(recentQueriesProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(recentQueriesProvider), ['saved']);

      await c.read(recentQueriesProvider.notifier).clear();
      expect(c.read(recentQueriesProvider), isEmpty);
      expect(store.saved, isEmpty);
    });
  });

  group('the filters sheet', () {
    Future<ProviderContainer> open(WidgetTester tester) async {
      final c = ProviderContainer(
        overrides: [
          foldersProvider.overrideWith(
            (ref) => Stream.value([
              const td.ChatFolderInfo(
                id: 3,
                title: 'Tech',
                icon: td.ChatFolderIcon(name: 'Custom'),
                colorId: -1,
                isShareable: false,
                hasMyInviteLinks: false,
              ),
            ]),
          ),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showSearchFilters(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('applies its choices on Search', (tester) async {
      final c = await open(tester);

      await tester.tap(find.text(AppStrings.searchFilterDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.searchDateWeek));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.searchFilterFrom));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.searchFilterExcludeReplies));
      await tester.pumpAndSettle();

      // Nothing changes until Search.
      expect(c.read(searchFiltersProvider).isDefault, isTrue);

      await tester.tap(find.text(AppStrings.searchFiltersApply));
      await tester.pumpAndSettle();

      expect(
        c.read(searchFiltersProvider),
        const SearchFilters(
          folderId: 3,
          date: SearchDateRange.week,
          excludeReplies: true,
        ),
      );
    });

    testWidgets('closing drops the changes', (tester) async {
      final c = await open(tester);
      await tester.tap(find.text(AppStrings.searchFilterExcludeReposts));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(c.read(searchFiltersProvider).isDefault, isTrue);
    });

    testWidgets('Reset clears what was set before', (tester) async {
      final c = await open(tester);
      c
          .read(searchFiltersProvider.notifier)
          .set(const SearchFilters(type: SearchMediaType.photos));
      Navigator.of(
        tester.element(find.text(AppStrings.searchFiltersTitle)),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.searchTypePhotos), findsOneWidget);

      await tester.tap(find.text(AppStrings.searchFiltersReset));
      await tester.tap(find.text(AppStrings.searchFiltersApply));
      await tester.pumpAndSettle();

      expect(c.read(searchFiltersProvider).isDefault, isTrue);
    });
  });

  group('RecentSearchesView', () {
    Future<(List<String>, List<String>)> pump(WidgetTester tester) async {
      final searched = <String>[];
      final filled = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentQueryStoreProvider.overrideWithValue(
              _MemoryStore(['messi 4k sitting on a ball']),
            ),
            recentChatsProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RecentSearchesView(
                onSearch: searched.add,
                onFill: filled.add,
                topPadding: 0,
                bottomPadding: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (searched, filled);
    }

    testWidgets('runs a recent search, or puts it in the field', (
      tester,
    ) async {
      final (searched, filled) = await pump(tester);

      await tester.tap(find.byIcon(Icons.north_west_rounded));
      expect(filled, ['messi 4k sitting on a ball']);
      expect(searched, isEmpty);

      await tester.tap(find.text('messi 4k sitting on a ball'));
      expect(searched, ['messi 4k sitting on a ball']);
    });

    testWidgets('says what to try when there is nothing yet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentQueryStoreProvider.overrideWithValue(_MemoryStore()),
            recentChatsProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RecentSearchesView(
                onSearch: (_) {},
                onFill: (_) {},
                topPadding: 0,
                bottomPadding: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.searchEmptyPrompt), findsOneWidget);
      expect(find.text(AppStrings.searchRecentTitle), findsNothing);
    });
  });
}
