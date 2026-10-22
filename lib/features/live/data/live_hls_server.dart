import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:gramx/features/live/data/live_hls.dart';

/// Serves a [LiveHlsWindow] to the platform player over loopback HTTP, the
/// way the file server serves downloads.
class LiveHlsServer {
  final LiveHlsWindow window;

  HttpServer? _server;
  final String _token = _makeToken();

  LiveHlsServer(this.window);

  /// The playlist's URL, starting the server if needed.
  Future<Uri> start() async {
    var server = _server;
    if (server == null) {
      // Loopback only, so the stream is never exposed on the network.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      server.listen(
        _handle,
        onError: (Object e) => debugPrint('[LiveHls] listen error: $e'),
      );
    }
    return Uri.parse('http://127.0.0.1:${server.port}/$_token/live.m3u8');
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final segments = request.uri.pathSegments;
      if (segments.length != 2 || segments[0] != _token) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final name = segments[1];
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

      if (name == 'live.m3u8') {
        response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        response.write(
          window.playlist(
            initUri: (id) => 'init$id.mp4',
            segmentUri: (sequence) => '$sequence.m4s',
          ),
        );
        return;
      }

      final bytes = _bytesFor(name);
      if (bytes == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      response.headers.contentType = ContentType('video', 'mp4');
      response.contentLength = bytes.length;
      response.add(bytes);
    } catch (e) {
      debugPrint('[LiveHls] ${request.uri.path} failed: $e');
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  /// `init<id>.mp4` or `<sequence>.m4s`.
  Uint8List? _bytesFor(String name) {
    if (name.startsWith('init') && name.endsWith('.mp4')) {
      final id = int.tryParse(name.substring(4, name.length - 4));
      return id == null ? null : window.init(id);
    }
    if (name.endsWith('.m4s')) {
      final sequence = int.tryParse(name.substring(0, name.length - 4));
      return sequence == null ? null : window.segment(sequence);
    }
    return null;
  }

  static String _makeToken() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
