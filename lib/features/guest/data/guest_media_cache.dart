import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads guest-mode media to disk, so everything downstream keeps loading
/// images from a file.
///
/// Guest content comes from Telegram's CDN over https, while every image widget
/// in this app renders from a local path — `cached_network_image` was removed
/// in T8-29 precisely so the app could say it fetches from Telegram and nobody
/// else. Caching to disk keeps that true and leaves the widgets untouched: the
/// only new thing is where the file came from, and it still came from Telegram.
///
/// Only `https` hosts under Telegram's own domains are fetched. The URLs come
/// out of a page parsed from the network, and an image loader pointed at an
/// arbitrary host by remote markup is exactly the leak T8-29 closed.
class GuestMediaCache {
  final http.Client _http;

  /// Hosts guest media may be fetched from.
  ///
  /// Telegram serves preview media from its own CDN and from t.me itself. Any
  /// other host in the markup is not ours to fetch, whatever the page says.
  static const Set<String> allowedHostSuffixes = {
    't.me',
    'telegram.org',
    'telegram-cdn.org',
    'cdn-telegram.org',
    'telesco.pe',
  };

  /// Files larger than this are left alone. A preview thumbnail is tens of
  /// kilobytes; anything at this size is a video the grid has no business
  /// pulling down to show a tile.
  static const int maxBytes = 8 * 1024 * 1024;

  static const Duration timeout = Duration(seconds: 20);

  /// In-flight downloads, so ten tiles sharing one URL make one request.
  final Map<String, Future<String?>> _inFlight = {};

  GuestMediaCache({http.Client? client}) : _http = client ?? http.Client();

  /// Whether this URL is one we will fetch at all.
  static bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    return allowedHostSuffixes.any(
      (suffix) => uri.host == suffix || uri.host.endsWith('.$suffix'),
    );
  }

  /// The local path for [url], downloading it once if it isn't there yet.
  ///
  /// Returns null when the URL is not fetchable or the download failed — the
  /// caller falls back to a placeholder, which is what it already does while a
  /// TDLib file is still downloading.
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

  /// Named by a hash of the URL: the URLs carry query strings and are far too
  /// long to be filenames, and the hash makes the name stable across launches.
  Future<String> _pathOnDisk(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/guest_media/${fileNameFor(url)}';
  }

  /// A stable filename for a URL.
  ///
  /// FNV-1a over the bytes, twice with different offsets, rather than a real
  /// digest: `package:crypto` is only a transitive dependency here and adding
  /// it to name a cache file would be a poor trade. Not a security boundary —
  /// a collision costs one wrong thumbnail, and the wide output makes that
  /// vanishingly unlikely across the few hundred files a reader accumulates.
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
    // Only a short, plain extension — the path is remote input, and a "."
    // followed by anything is not a file suffix.
    return RegExp(r'^\.[A-Za-z0-9]{1,5}$').hasMatch(extension)
        ? extension.toLowerCase()
        : '';
  }

  /// Deletes everything cached. Called when guest mode is turned off, because
  /// leaving a browsing history on disk after the reader has left it is not
  /// something they asked for.
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

/// The local path for one guest media URL, once it has been fetched.
///
/// Mirrors `fileDownloadProvider`'s shape so the widgets can treat a guest URL
/// and a TDLib file id the same way — see `resolveMediaPath`.
final guestMediaPathProvider = FutureProvider.family<String?, String>((
  ref,
  url,
) async {
  return ref.watch(guestMediaCacheProvider).pathFor(url);
});
