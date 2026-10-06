import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the key TDLib uses to encrypt its local database. Stored in the
/// platform keystore rather than the app's files, so it is not readable
/// alongside the data it protects.
class DatabaseKeyStore {
  /// Changing this would orphan every existing database.
  static const String storageKey = 'tdlib_db_encryption_key';

  /// 256 bits, base64-encoded for storage.
  static const int keyLengthBytes = 32;

  final FlutterSecureStorage _storage;

  DatabaseKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  /// The stored key, or null for a fresh install or a database created before
  /// encryption. Both open with an empty key and are then encrypted in place.
  ///
  /// Throws when the keystore can't be read, which is not the same as having
  /// no key: opening an encrypted database with an empty key would make it
  /// look lost, and a lost database is cleared.
  Future<String?> read() => _storage.read(key: storageKey);

  Future<void> write(String key) async {
    try {
      await _storage.write(key: storageKey, value: key);
    } catch (e) {
      debugPrint('[DbKey] Could not persist key: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (e) {
      debugPrint('[DbKey] Could not clear key: $e');
    }
  }

  /// A fresh random key, from the platform's cryptographic RNG.
  ///
  /// Standard base64, which is how TDLib's JSON carries bytes. It rejects the
  /// URL-safe alphabet's `-` and `_`.
  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      keyLengthBytes,
      (_) => random.nextInt(256),
    );
    return base64Encode(bytes);
  }
}

final databaseKeyStoreProvider = Provider<DatabaseKeyStore>(
  (ref) => DatabaseKeyStore(),
);
