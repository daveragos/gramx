import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads guest-mode media to disk, so image widgets can keep rendering
/// from local files.
///
/// Only `https` URLs on Telegram's own domains are fetched, since the URLs
/// come from remote markup and the app talks only to Telegram.
class GuestMediaCache {
  final http.Client _http;

  /// Hosts guest media may be fetched from: Telegram's CDN and t.me.
  static const Set<String> allowedHostSuffixes = {
    't.me',
    'telegram.org',
    'telegram-cdn.org',
    'cdn-telegram.org',
    'telesco.pe',
  };

  /// Files larger than this are not cached.
  static const int maxBytes = 8 * 1024 * 1024;

  static const Duration timeout = Duration(seconds: 20);

  /// In-flight downloads, so tiles sharing a URL make one request.
  final Map<String, Future<String?>> _inFlight = {};

  GuestMediaCache({http.Client? client}) : _http = client ?? http.Client();

  /// Whether [url] may be fetched.
  static bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    return allowedHostSuffixes.any(
      (suffix) => uri.host == suffix || uri.host.endsWith('.$suffix'),
    );
  }

  /// The local path for [url], downloading it if needed. Null when the URL
  /// isn't allowed or the download failed.
  Future<String?> pathFor(String url) {
    if (!isAllowed(url)) return Future.value(null);
    return _inFlight.putIfAbsent(url, () => _download(url))
      ..whenComplete(() => _inFlight.remove(url));
  }

  Future<String?> _download(String url) async {
    try {
      final file = File(await _pathOnDisk(url));
      if (await file.exists() && await file.length() > 0) return file.path;

      final response = await _http.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length > maxBytes) return null;

      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('[Guest] media $url failed: $e');
      return null;
    }
  }

  /// Named by a stable hash of the URL, which is too long for a filename.
  Future<String> _pathOnDisk(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/guest_media/${fileNameFor(url)}';
  }

  /// A stable filename for a URL: FNV-1a run twice with different offsets.
  /// Not a security boundary; a collision costs one wrong thumbnail.
  @visibleForTesting
  static String fileNameFor(String url) {
    final bytes = utf8.encode(url);
    final low = _fnv1a(bytes, 0x811c9dc5);
    final high = _fnv1a(bytes.reversed.toList(), 0x01000193);
    final name =
        low.toRadixString(16).padLeft(8, '0') +
        high.toRadixString(16).padLeft(8, '0');
    return '$name${_extensionOf(url)}';
  }

  static int _fnv1a(List<int> bytes, int seed) {
    var hash = seed;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    final extension = path.substring(dot);
    // Only a short, plain extension, since the path is remote input.
    return RegExp(r'^\.[A-Za-z0-9]{1,5}$').hasMatch(extension)
        ? extension.toLowerCase()
        : '';
  }

  /// Deletes everything cached. Called when guest mode is turned off.
  Future<void> clear() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cache = Directory('${dir.path}/guest_media');
      if (await cache.exists()) await cache.delete(recursive: true);
    } catch (e) {
      debugPrint('[Guest] could not clear the media cache: $e');
    }
  }

  void close() => _http.close();
}

final guestMediaCacheProvider = Provider<GuestMediaCache>((ref) {
  final cache = GuestMediaCache();
  ref.onDispose(cache.close);
  return cache;
});

/// The local path for a guest media URL once fetched. Shaped like
/// `fileDownloadProvider` (see `resolveMediaPath`).
final guestMediaPathProvider = FutureProvider.family<String?, String>((
  ref,
  url,
) async {
  return ref.watch(guestMediaCacheProvider).pathFor(url);
});
