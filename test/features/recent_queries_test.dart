import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/search/data/recent_searches.dart';

/// Holds the saved searches back until told to load them.
class _SlowStore implements RecentQueryStore {
  final loaded = Completer<List<String>>();
  List<String> saved = const [];

  @override
  Future<List<String>> load() => loaded.future;

  @override
  Future<void> save(List<String> queries) async => saved = queries;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  late _SlowStore store;
  late ProviderContainer c;

  setUp(() {
    store = _SlowStore();
    c = ProviderContainer(
      overrides: [recentQueryStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
  });

  test('restores the saved searches after any made meanwhile', () async {
    c.read(recentQueriesProvider.notifier).add('nasa');
    store.loaded.complete(['spacex', 'NASA']);
    await pumpEventQueue();

    expect(c.read(recentQueriesProvider), ['nasa', 'spacex']);
  });

  // Signing out cleared them while they were still loading, and the old
  // account's searches came back.
  test('a clear while loading keeps them cleared', () async {
    c.read(recentQueriesProvider);
    await c.read(recentQueriesProvider.notifier).clear();
    store.loaded.complete(['spacex']);
    await pumpEventQueue();

    expect(c.read(recentQueriesProvider), isEmpty);
    expect(store.saved, isEmpty);
  });
}
