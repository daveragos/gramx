import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/database_key_store.dart';

void main() {
  group('DatabaseKeyStore.generate', () {
    test('produces a 256-bit key', () {
      final key = DatabaseKeyStore.generate();
      expect(base64.decode(key), hasLength(DatabaseKeyStore.keyLengthBytes));
    });

    test('produces a different key every time', () {
      final keys = List.generate(50, (_) => DatabaseKeyStore.generate());
      expect(keys.toSet(), hasLength(50));
    });

    test('is base64 in the alphabet TDLib decodes bytes with', () {
      // TDLib rejects `-` and `_`, and URL-safe base64 has one in most keys.
      for (var i = 0; i < 200; i++) {
        final key = DatabaseKeyStore.generate();
        expect(key, matches(RegExp(r'^[A-Za-z0-9+/]+=*$')));
      }
    });

    test(
      'is never empty — an empty key is what left the database plaintext',
      () {
        expect(DatabaseKeyStore.generate(), isNotEmpty);
      },
    );
  });

  group('storage key', () {
    // Changing this would orphan every existing encrypted database.
    test('is pinned', () {
      expect(DatabaseKeyStore.storageKey, 'tdlib_db_encryption_key');
    });
  });
}
