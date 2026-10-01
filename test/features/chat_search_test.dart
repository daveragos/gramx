import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/chats/presentation/chat_search_providers.dart';

void main() {
  late ProviderContainer container;

  /// Keeps the auto-dispose providers alive between reads, as the screen's
  /// watch does.
  void hold() {
    container.listen(inChatSearchQueryProvider, (_, _) {});
    container.listen(debouncedInChatSearchQueryProvider, (_, _) {});
  }

  setUp(() {
    container = ProviderContainer();
    hold();
  });
  tearDown(() => container.dispose());

  group('the in-chat search field', () {
    // Closed (null) shows the header; empty means the field is open.
    test('starts closed, which is not the same as empty', () {
      expect(container.read(inChatSearchQueryProvider), isNull);

      container.read(inChatSearchQueryProvider.notifier).open();
      expect(container.read(inChatSearchQueryProvider), '');
    });

    test('closing puts it away rather than clearing it', () {
      final notifier = container.read(inChatSearchQueryProvider.notifier);
      notifier.open();
      notifier.setQuery('receipts');
      expect(container.read(inChatSearchQueryProvider), 'receipts');

      notifier.close();
      expect(container.read(inChatSearchQueryProvider), isNull);
    });
  });

  group('the debounce', () {
    // Each settled query is a networked `SearchChatMessages`, so typing is
    // debounced.
    test('typing does not reach the settled query straight away', () {
      final notifier = container.read(inChatSearchQueryProvider.notifier)
        ..open();

      for (final chunk in ['r', 're', 'rec', 'rece']) {
        notifier.setQuery(chunk);
        expect(
          container.read(debouncedInChatSearchQueryProvider),
          '',
          reason: 'settled on "$chunk" before the pause',
        );
      }
    });

    test('it settles once typing pauses', () async {
      container.read(inChatSearchQueryProvider.notifier)
        ..open()
        ..setQuery('receipts');
      await Future<void>.delayed(chatSearchDebounce * 2);

      expect(container.read(debouncedInChatSearchQueryProvider), 'receipts');
    });

    // Clearing costs no request, so it skips the debounce.
    test('clearing takes effect immediately', () async {
      final notifier = container.read(inChatSearchQueryProvider.notifier)
        ..open()
        ..setQuery('receipts');
      await Future<void>.delayed(chatSearchDebounce * 2);

      notifier.setQuery('');
      expect(container.read(debouncedInChatSearchQueryProvider), '');
    });

    test('whitespace alone is not a query', () async {
      container.read(inChatSearchQueryProvider.notifier)
        ..open()
        ..setQuery('   ');
      await Future<void>.delayed(chatSearchDebounce * 2);

      expect(container.read(debouncedInChatSearchQueryProvider), '');
    });
  });
}
