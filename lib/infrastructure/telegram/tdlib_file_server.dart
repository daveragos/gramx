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
/// `video_player` needs a path or URL, so a local server answering Range
/// requests bridges it to a partially downloaded file. The file is read
/// directly from disk (TDLib documents `ReadFilePart` as slower than that) and
/// TDLib is only used to steer which part downloads next. Only
/// `[downloadOffset, downloadOffset + downloadedPrefixSize)` is valid while a
/// download is running.
///
/// Bound to loopback, and every URL carries a per-launch random token so other
/// apps on the device can't fetch media by file id.
class TdlibFileServer {
  final TdlibService _tdlib;

  /// How long a request waits for the prefix to advance before giving up.
  /// Long, because ending the response early makes the player fail hard.
  static const Duration stallTimeout = Duration(seconds: 30);

  /// Largest slice handed to the player in one write.
  static const int chunkSize = 512 * 1024;

  HttpServer? _server;
  late final String _token = _makeToken();

  /// One in-flight range per file, since TDLib has a single download offset
  /// per file and overlapping requests would fight over it.
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

    // Loopback only, so media is never exposed on the local network.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(
      _handle,
      onError: (Object e) {
        debugPrint('[FileServer] listen error: $e');
      },
    );
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
      // Headers are usually sent by now, so just close. The player treats a
      // truncated body as a stall and retries the range.
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

    final range = parseRange(
      request.headers.value(HttpHeaders.rangeHeader),
      totalSize: totalSize,
    );
    final start = range.start;
    final end = range.end ?? totalSize - 1;
    final length = end - start + 1;

    response.statusCode = range.isPartial
        ? HttpStatus.partialContent
        : HttpStatus.ok;
    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, 'video/mp4')
      ..set(HttpHeaders.contentLengthHeader, '$length');
    if (range.isPartial) {
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$totalSize',
      );
    }

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    // Point TDLib at the requested byte so a seek past the downloaded prefix
    // doesn't wait for the whole file.
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

        final want = [
          chunkSize,
          available,
          end - position + 1,
        ].reduce((a, b) => a < b ? a : b);
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
  /// Returns null on timeout or failure.
  Future<td.File?> _awaitBytesAt(int fileId, int offset) async {
    final now = await _getFile(fileId);
    if (now != null && _availableAt(now, offset) > 0) return now;

    // The timeout is on the stream so it fires even when no updates arrive at
    // all; otherwise the response never closes and the player freezes.
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
      await _tdlib.sendRequest(
        td.DownloadFile(
          fileId: fileId,
          priority: 32,
          offset: offset,
          limit: 0,
          synchronous: false,
        ),
      );
    } catch (e) {
      debugPrint('[FileServer] DownloadFile $fileId @$offset: $e');
    }
  }

  /// Parses `/<token>/<fileId>`, or returns null if the token or path is wrong.
  int? _fileIdOf(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length != 2) return null;
    if (segments[0] != _token) return null;
    return int.tryParse(segments[1]);
  }

  static String _makeToken() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
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

/// Parses `Range: bytes=<start>-<end>`, including open-ended ranges and the
/// suffix form (`bytes=-500` means the last 500 bytes), which ExoPlayer sends.
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
  final end = parsedEnd == null
      ? totalSize - 1
      : parsedEnd.clamp(start, totalSize - 1);

  return ByteRange(start: start, end: end, isPartial: true);
}

final tdlibFileServerProvider = Provider<TdlibFileServer>((ref) {
  final server = TdlibFileServer(ref.watch(tdlibServiceProvider));
  ref.onDispose(server.close);
  return server;
});
