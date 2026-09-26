import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the key TDLib uses to encrypt its local database.
///
/// TDLib's database caches every message, channel and media path this app has
/// seen. It was previously created with an empty key, which leaves all of that
/// in plaintext on disk — a poor default for a Telegram client.
///
/// The key lives in the platform keystore (Keychain / EncryptedSharedPrefs),
/// not in the app's own files, so it is not readable alongside the data it
/// protects.
class DatabaseKeyStore {
  /// Bumping this would orphan every existing database, so treat it as fixed.
  static const String storageKey = 'tdlib_db_encryption_key';

  /// 256 bits, base64-encoded for storage.
  static const int keyLengthBytes = 32;

  final FlutterSecureStorage _storage;

  DatabaseKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  /// The stored key, or null if this install has never had one.
  ///
  /// Null means one of two things, and the caller cannot tell them apart:
  /// a fresh install, or an existing database created before encryption. Both
  /// are handled the same way — open with an empty key, then encrypt in place.
  Future<String?> read() async {
    try {
      return await _storage.read(key: storageKey);
    } catch (e) {
      debugPrint('[DbKey] Could not read key: $e');
      return null;
    }
  }

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
  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      keyLengthBytes,
      (_) => random.nextInt(256),
    );
    return base64UrlEncode(bytes);
  }
}

final databaseKeyStoreProvider = Provider<DatabaseKeyStore>(
  (ref) => DatabaseKeyStore(),
);
