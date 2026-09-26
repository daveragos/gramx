import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/chats/presentation/chat_search_providers.dart';

void main() {
  late ProviderContainer container;

  /// Both providers are auto-dispose, so a test that only reads them lets them
  /// be collected between statements — which is a disposed-notifier error, not
  /// a debounce failure. The screen holds them by watching; this stands in.
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
    // Closed and empty are different states: closed means the header is a
    // header again, empty means the field is open and waiting. A screen that
    // could not tell them apart would either never show the field or never
    // put it away.
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
    // Searching a chat is a networked SearchChatMessages. A ten-character
    // query undebounced is ten of them, on the one path a person drives
    // keystroke by keystroke.
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

    // Clearing the field has nothing to spend, so it takes effect at once —
    // otherwise the results linger for 300 ms over an empty field.
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
