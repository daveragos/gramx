import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    // Keep the debounced provider alive; an unlistened provider auto-disposes
    // and would never see the follow-up keystrokes.
    container.listen(debouncedSearchQueryProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  void type(String value) =>
      container.read(searchQueryProvider.notifier).setQuery(value);

  Future<void> settle() =>
      Future<void>.delayed(searchDebounce + const Duration(milliseconds: 80));

  group('debouncedSearchQueryProvider', () {
    test('holds the query back until typing pauses', () async {
      type('t');
      expect(container.read(debouncedSearchQueryProvider), '',
          reason: 'must not reach Telegram mid-keystroke');

      await settle();
      expect(container.read(debouncedSearchQueryProvider), 't');
    });

    // The regression this exists for: ten characters used to mean ten
    // SearchPublicChats calls plus per-result lookups.
    test('a burst of keystrokes settles on the final query only', () async {
      type('f');
      type('fl');
      type('flu');
      type('flut');
      type('flutter');

      expect(container.read(debouncedSearchQueryProvider), '');

      await settle();
      expect(container.read(debouncedSearchQueryProvider), 'flutter');
    });

    test('clearing the field takes effect immediately', () async {
      type('flutter');
      await settle();
      expect(container.read(debouncedSearchQueryProvider), 'flutter');

      type('');
      expect(container.read(debouncedSearchQueryProvider), '',
          reason: 'clearing costs nothing, so it should not wait');
    });

    test('keeps the last settled query visible while typing continues',
        () async {
      type('dart');
      await settle();
      expect(container.read(debouncedSearchQueryProvider), 'dart');

      type('dartlang');
      expect(container.read(debouncedSearchQueryProvider), 'dart',
          reason: 'results stay put rather than blanking mid-edit');

      await settle();
      expect(container.read(debouncedSearchQueryProvider), 'dartlang');
    });

    test('surrounding whitespace does not re-trigger a search', () async {
      type('news');
      await settle();
      expect(container.read(debouncedSearchQueryProvider), 'news');

      type('  news  ');
      await settle();
      expect(container.read(debouncedSearchQueryProvider), 'news');
    });
  });

  group('searchQueryProvider', () {
    test('stays instant so local filtering does not lag', () {
      type('abc');
      expect(container.read(searchQueryProvider), 'abc');
    });
  });
}
