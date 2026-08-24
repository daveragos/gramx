import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Serves a TDLib file over loopback HTTP so a video can start before it has
/// finished downloading.
///
/// **Why a server at all.** `video_player` takes a file path or a URL; it
/// cannot be handed a growing buffer. A local HTTP server that answers Range
/// requests is the seam between "TDLib has the first two megabytes" and "the
/// player wants bytes 0–65535", and it is how Telegram's own clients stream.
///
/// **Why not `ReadFilePart`.** That is the obvious call, and TDLib's own
/// documentation rules it out here: it is *"intended to be used only if the
/// application has no direct access to TDLib's file system, because it is
/// usually slower than a direct read from the file."* gramX runs TDLib
/// in-process with the file sitting at `file.local.path`, so every byte would
/// take a round trip through the TDLib request queue and a JSON envelope for
/// no reason. This reads the partial file directly and uses TDLib only to
/// steer *which* part is being fetched.
///
/// **How a partial read is made safe.** `LocalFile` reports `downloadOffset`
/// and `downloadedPrefixSize`: only `[downloadOffset, downloadOffset +
/// downloadedPrefixSize)` is real, and everything outside it may be garbage or
/// absent. So a request seeks TDLib with `DownloadFile(offset:)`, waits for the
/// prefix to cover the byte it wants, reads what is there, and waits again.
///
/// **Security.** Bound to loopback on an ephemeral port, and every URL carries
/// a per-launch random token. Without the token another app on the device
/// could walk file ids and pull the reader's media off a plain local port.
class TdlibFileServer {
  final TdlibService _tdlib;

  /// How long a request waits for the prefix to advance before giving up.
  ///
  /// Generous: a stalled connection is the common case and killing the
  /// response makes the player report a hard failure rather than buffering.
  static const Duration stallTimeout = Duration(seconds: 30);

  /// Largest slice handed to the player in one write.
  static const int chunkSize = 512 * 1024;

  HttpServer? _server;
  late final String _token = _makeToken();

  /// One in-flight range per file. TDLib has a single download offset per
  /// file, so two overlapping requests would fight over where it is pointing
  /// and each would see the other's bytes go missing.
  final Map<int, Future<void>> _inFlight = {};

  TdlibFileServer(this._tdlib);

  /// The URL a player should open for [fileId], starting the server if needed.
  Future<Uri> urlFor(int fileId) async {
    final server = await _ensureStarted();
    return Uri.parse('http://127.0.0.1:${server.port}/$_token/$fileId');
  }

  Future<HttpServer> _ensureStarted() async {
    final existing = _server;
    if (existing != null) return existing;

    // Loopback only. Binding to anything else would put the reader's media on
    // the local network.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (Object e) {
      debugPrint('[FileServer] listen error: $e');
    });
    debugPrint('[FileServer] listening on 127.0.0.1:${server.port}');
    return server;
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;

    final fileId = _fileIdOf(request.uri);
    if (fileId == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    // Serialise per file: see _inFlight.
    final previous = _inFlight[fileId];
    final completer = Completer<void>();
    _inFlight[fileId] = completer.future;
    try {
      if (previous != null) await previous;
      await _serve(request, fileId);
    } catch (e) {
      debugPrint('[FileServer] file $fileId failed: $e');
      // The headers are usually already out by the time anything fails, so
      // there is nothing to say but "stop" — the player treats a truncated
      // body as a stall and retries the range.
      try {
        await response.close();
      } catch (_) {}
    } finally {
      completer.complete();
      if (identical(_inFlight[fileId], completer.future)) {
        _inFlight.remove(fileId);
      }
    }
  }

  Future<void> _serve(HttpRequest request, int fileId) async {
    final response = request.response;

    final initial = await _getFile(fileId);
    if (initial == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final totalSize = initial.size > 0 ? initial.size : initial.expectedSize;
    if (totalSize <= 0) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final range = parseRange(request.headers.value(HttpHeaders.rangeHeader),
        totalSize: totalSize);
    final start = range.start;
    final end = range.end ?? totalSize - 1;
    final length = end - start + 1;

    response.statusCode =
        range.isPartial ? HttpStatus.partialContent : HttpStatus.ok;
    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, 'video/mp4')
      ..set(HttpHeaders.contentLengthHeader, '$length');
    if (range.isPartial) {
      response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalSize');
    }

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    // Point TDLib at the byte the player actually asked for. Without this a
    // seek past the downloaded prefix would wait for the whole file.
    await _startDownload(fileId, offset: start);

    var position = start;
    RandomAccessFile? handle;
    try {
      while (position <= end) {
        final file = await _awaitBytesAt(fileId, position);
        if (file == null) break;

        final available = _availableAt(file, position);
        if (available <= 0) break;

        handle ??= await File(file.local.path).open();

        final want = [chunkSize, available, end - position + 1]
            .reduce((a, b) => a < b ? a : b);
        await handle.setPosition(position);
        final bytes = await handle.read(want);
        if (bytes.isEmpty) break;

        response.add(bytes);
        await response.flush();
        position += bytes.length;
      }
    } finally {
      await handle?.close();
      await response.close();
    }
  }

  /// Waits until [offset] is inside the downloaded prefix, or the file is done.
  ///
  /// Returns null on timeout or if the download died — the caller ends the
  /// response, which the player reads as a stall and retries.
  Future<td.File?> _awaitBytesAt(int fileId, int offset) async {
    final now = await _getFile(fileId);
    if (now != null && _availableAt(now, offset) > 0) return now;

    // The timeout has to be on the stream, not checked inside the loop: the
    // loop body only runs when an update arrives, so a connection that goes
    // away entirely would leave this awaiting a stream that has gone quiet —
    // and the response never closes, which the player shows as a frozen frame
    // rather than a stall it could retry.
    try {
      return await _tdlib.fileUpdates
          .where((u) => u.file.id == fileId)
          .map((u) => u.file)
          .where((f) => _availableAt(f, offset) > 0)
          .timeout(stallTimeout)
          .first;
    } on TimeoutException {
      debugPrint('[FileServer] file $fileId stalled at $offset');
      return null;
    } catch (e) {
      debugPrint('[FileServer] file $fileId wait failed: $e');
      return null;
    }
  }

  /// Bytes readable from [offset], given what TDLib says it holds.
  ///
  /// Only `[downloadOffset, downloadOffset + downloadedPrefixSize)` is real
  /// while a download is in flight; a completed file is real throughout.
  static int _availableAt(td.File file, int offset) {
    final local = file.local;
    if (local.path.isEmpty) return 0;

    if (local.isDownloadingCompleted) {
      final total = file.size > 0 ? file.size : file.expectedSize;
      return total - offset;
    }

    final from = local.downloadOffset;
    final until = from + local.downloadedPrefixSize;
    if (offset < from || offset >= until) return 0;
    return until - offset;
  }

  Future<td.File?> _getFile(int fileId) async {
    try {
      final result = await _tdlib.sendRequest(td.GetFile(fileId: fileId));
      return result is td.File ? result : null;
    } catch (e) {
      debugPrint('[FileServer] GetFile $fileId: $e');
      return null;
    }
  }

  Future<void> _startDownload(int fileId, {required int offset}) async {
    try {
      await _tdlib.sendRequest(td.DownloadFile(
        fileId: fileId,
        priority: 32,
        offset: offset,
        limit: 0,
        synchronous: false,
      ));
    } catch (e) {
      debugPrint('[FileServer] DownloadFile $fileId @$offset: $e');
    }
  }

  /// `/<token>/<fileId>`, or null if the token is wrong or the path is not one
  /// of ours. The token is the only thing standing between this port and any
  /// other app on the device.
  int? _fileIdOf(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length != 2) return null;
    if (segments[0] != _token) return null;
    return int.tryParse(segments[1]);
  }

  static String _makeToken() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

/// A parsed HTTP Range header.
@immutable
class ByteRange {
  final int start;

  /// Inclusive end, or null for "to the end of the file".
  final int? end;
  final bool isPartial;

  const ByteRange({required this.start, this.end, required this.isPartial});
}

/// Parses `Range: bytes=<start>-<end>`.
///
/// Pure and public so the awkward forms are testable without a socket: no
/// header at all, an open-ended range, and the suffix form (`bytes=-500`,
/// meaning the *last* 500 bytes) which ExoPlayer does use and which is easy to
/// read backwards.
ByteRange parseRange(String? header, {required int totalSize}) {
  if (header == null || !header.startsWith('bytes=')) {
    return ByteRange(start: 0, end: totalSize - 1, isPartial: false);
  }

  final spec = header.substring('bytes='.length).split(',').first.trim();
  final dash = spec.indexOf('-');
  if (dash < 0) {
    return ByteRange(start: 0, end: totalSize - 1, isPartial: false);
  }

  final rawStart = spec.substring(0, dash).trim();
  final rawEnd = spec.substring(dash + 1).trim();

  if (rawStart.isEmpty) {
    // Suffix form: the last N bytes.
    final suffix = int.tryParse(rawEnd);
    if (suffix == null || suffix <= 0) {
      return ByteRange(start: 0, end: totalSize - 1, isPartial: false);
    }
    final start = (totalSize - suffix).clamp(0, totalSize - 1);
    return ByteRange(start: start, end: totalSize - 1, isPartial: true);
  }

  final start = int.tryParse(rawStart);
  if (start == null || start >= totalSize) {
    return ByteRange(start: 0, end: totalSize - 1, isPartial: false);
  }

  final parsedEnd = rawEnd.isEmpty ? null : int.tryParse(rawEnd);
  final end = parsedEnd == null ? totalSize - 1 : parsedEnd.clamp(start, totalSize - 1);

  return ByteRange(start: start, end: end, isPartial: true);
}

final tdlibFileServerProvider = Provider<TdlibFileServer>((ref) {
  final server = TdlibFileServer(ref.watch(tdlibServiceProvider));
  ref.onDispose(server.close);
  return server;
});
