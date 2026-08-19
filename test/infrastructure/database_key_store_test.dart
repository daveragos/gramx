import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/database_key_store.dart';

void main() {
  group('DatabaseKeyStore.generate', () {
    test('produces a 256-bit key', () {
      final key = DatabaseKeyStore.generate();
      expect(base64Url.decode(key), hasLength(DatabaseKeyStore.keyLengthBytes));
    });

    test('produces a different key every time', () {
      final keys = List.generate(50, (_) => DatabaseKeyStore.generate());
      expect(keys.toSet(), hasLength(50));
    });

    test('is base64url, so it survives being stored as a string', () {
      final key = DatabaseKeyStore.generate();
      expect(() => base64Url.decode(key), returnsNormally);
      expect(key, isNot(contains('\n')));
    });

    test('is never empty — an empty key is what left the database plaintext',
        () {
      expect(DatabaseKeyStore.generate(), isNotEmpty);
    });
  });

  group('storage key', () {
    // Changing this would orphan every existing encrypted database, with no way
    // to recover it short of a wipe.
    test('is pinned', () {
      expect(DatabaseKeyStore.storageKey, 'tdlib_db_encryption_key');
    });
  });
}
