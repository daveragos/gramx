import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/audio/fragmented_mp4.dart';
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
/// TDLib has one download offset per file, so the newest request for a file
/// steers it and any older one stops: a player only asks again for a file it
/// is already reading when it seeks or jumps to an index at the end.
///
/// MP4 audio in fragments with no index up front is served with one inserted
/// after its header, so the player can tell its length and seek; see
/// [FragmentedMp4]. Offsets in requests are then into the file as served.
///
/// Bound to loopback, and every URL carries a per-launch random token so other
/// apps on the device can't fetch media by file id.
class TdlibFileServer {
  final TdlibService _tdlib;

  /// How long a request waits for the prefix to advance before giving up.
  /// Long, because ending the response early makes the player fail hard.
  static const Duration stallTimeout = Duration(seconds: 30);

  /// How often a waiting request looks at the file again. Progress updates
  /// are throttled, so the one that reaches its offset may never arrive.
  static const Duration recheckInterval = Duration(milliseconds: 500);

  /// Largest slice handed to the player in one write.
  static const int chunkSize = 512 * 1024;

  /// Most of a file read to index its fragments: an `mfra` of 65,535
  /// entries is under 2 MB.
  static const int maxIndexRead = 4 * 1024 * 1024;

  HttpServer? _server;
  late final String _token = _makeToken();

  /// The request reading each file. See the class comment.
  final Map<int, _Reader> _readers = {};

  /// Each file's MIME type, sent as its Content-Type. AVPlayer goes by it,
  /// so an MP3 labelled as MP4 won't play on iOS.
  final Map<int, String> _mimeTypes = {};

  /// How each file is served, worked out once; see [_layoutFor].
  final Map<int, Future<_Layout?>> _layouts = {};

  TdlibFileServer(this._tdlib);

  /// The URL a player should open for [fileId], starting the server if needed.
  /// [mimeType] is Telegram's for the file; without one it is served as MP4.
  Future<Uri> urlFor(int fileId, {String? mimeType}) async {
    if (mimeType != null && mimeType.isNotEmpty) _mimeTypes[fileId] = mimeType;
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

    try {
      await _serve(request, fileId);
    } catch (e) {
      debugPrint('[FileServer] file $fileId failed: $e');
      // Headers are usually sent by now, so just close. The player treats a
      // truncated body as a stall and retries the range.
      try {
        await response.close();
      } catch (_) {}
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

    final layout = await _layoutFor(fileId, totalSize);
    final servedSize = totalSize + (layout?.index.length ?? 0);

    final range = parseRange(
      request.headers.value(HttpHeaders.rangeHeader),
      totalSize: servedSize,
    );
    final start = range.start;
    final end = range.end ?? servedSize - 1;
    final length = end - start + 1;

    response.statusCode = range.isPartial
        ? HttpStatus.partialContent
        : HttpStatus.ok;
    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, _mimeTypes[fileId] ?? 'video/mp4')
      ..set(HttpHeaders.contentLengthHeader, '$length');
    if (range.isPartial) {
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$servedSize',
      );
    }

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    final reader = _Reader();
    _readers.remove(fileId)?.supersede();
    _readers[fileId] = reader;

    // Point TDLib at the requested bytes, and only those, so a seek or a jump
    // to an index at the end doesn't wait behind the rest of the file.
    final fileStart = layout?.fileOffset(start) ?? start;
    final fileEnd = layout?.fileOffset(end) ?? end;
    await _startDownload(
      fileId,
      offset: fileStart,
      length: fileEnd - fileStart + 1,
    );

    var position = start;
    RandomAccessFile? handle;
    try {
      while (position <= end && !reader.isSuperseded) {
        // The inserted index comes from memory.
        if (layout != null && layout.holds(position)) {
          final from = position - layout.insertAt;
          final until = min(layout.index.length, end - layout.insertAt + 1);
          response.add(layout.index.sublist(from, until));
          await response.flush();
          position += until - from;
          continue;
        }

        final offset = layout?.fileOffset(position) ?? position;
        final file = await _awaitBytesAt(fileId, offset, reader);
        if (file == null) break;

        final available = _availableAt(file, offset);
        if (available <= 0) break;

        handle ??= await File(file.local.path).open();

        final want = [
          chunkSize,
          available,
          end - position + 1,
          // Up to where the index goes in, if that is still ahead.
          if (layout != null && position < layout.insertAt)
            layout.insertAt - position,
        ].reduce(min);
        await handle.setPosition(offset);
        final bytes = await handle.read(want);
        if (bytes.isEmpty) break;

        response.add(bytes);
        await response.flush();
        position += bytes.length;
      }
    } finally {
      if (identical(_readers[fileId], reader)) _readers.remove(fileId);
      await handle?.close();
      await response.close();
    }
  }

  /// How [fileId] is served: with an index inserted when it is MP4 audio in
  /// fragments without one, otherwise as it is (null). Worked out once per
  /// file, from the few boxes that tell.
  Future<_Layout?> _layoutFor(int fileId, int size) {
    final mime = _mimeTypes[fileId] ?? '';
    final mp4Audio =
        mime.startsWith('audio/') &&
        (mime.contains('mp4') || mime.contains('m4a'));
    if (!mp4Audio) return Future.value(null);
    return _layouts.putIfAbsent(fileId, () => _indexFragments(fileId, size));
  }

  /// Builds the index for a fragmented MP4 from its trailing `mfra`, fetching
  /// the boxes it reads first if TDLib hasn't. Null for any other layout, or
  /// when something doesn't add up, so the file is served as it is.
  Future<_Layout?> _indexFragments(int fileId, int size) async {
    try {
      // Past ftyp and the like to moov.
      var at = 0;
      ({String type, int size})? box;
      while (true) {
        box = await _boxAt(fileId, at, size);
        if (box == null) return null;
        if (box.type == 'moov') break;
        if (!const {'ftyp', 'styp', 'free', 'skip'}.contains(box.type)) {
          return null;
        }
        at += box.size;
      }
      final moovAt = at;
      final moovEnd = moovAt + box.size;

      // Fragments straight after, with no index of their own.
      final next = await _boxAt(fileId, moovEnd, size);
      if (next == null || next.type != 'moof') return null;

      final tail = await _readRange(fileId, size - 16, 16);
      final mfraSize = tail == null ? null : FragmentedMp4.mfraSize(tail);
      if (mfraSize == null || mfraSize > maxIndexRead || mfraSize > size) {
        return null;
      }
      final mfraAt = size - mfraSize;
      final mfra = await _readRange(fileId, mfraAt, mfraSize);
      final table = mfra == null ? null : FragmentedMp4.tfra(mfra);
      if (table == null) return null;
      final fragments = table.fragments;
      if (fragments.length > 0xFFFF || fragments.first.offset < moovEnd) {
        return null;
      }

      final moov = await _readRange(
        fileId,
        moovAt,
        min(box.size, maxIndexRead),
      );
      final timescale = moov == null ? null : FragmentedMp4.timescale(moov);
      if (timescale == null || timescale == 0) return null;

      // The mfra gives start times, so the last fragment's length comes from
      // its own samples.
      final last = fragments.last;
      final lastBox = await _boxAt(fileId, last.offset, size);
      if (lastBox == null || lastBox.type != 'moof') return null;
      final lastMoof = await _readRange(
        fileId,
        last.offset,
        min(lastBox.size, maxIndexRead),
      );
      final lastDuration = lastMoof == null
          ? null
          : FragmentedMp4.fragmentDuration(lastMoof);
      if (lastDuration == null) return null;

      final entries = <({int size, int duration})>[];
      for (var i = 0; i < fragments.length; i++) {
        final isLast = i == fragments.length - 1;
        final entry = (
          size:
              (isLast ? mfraAt : fragments[i + 1].offset) - fragments[i].offset,
          duration: isLast
              ? lastDuration
              : fragments[i + 1].time - fragments[i].time,
        );
        if (entry.size <= 0 || entry.duration < 0) return null;
        entries.add(entry);
      }

      return _Layout(
        insertAt: moovEnd,
        index: FragmentedMp4.sidx(
          trackId: table.trackId,
          timescale: timescale,
          earliestTime: fragments.first.time,
          firstOffset: fragments.first.offset - moovEnd,
          fragments: entries,
        ),
      );
    } catch (e) {
      debugPrint('[FileServer] file $fileId has no usable fragment index: $e');
      return null;
    }
  }

  /// The header of the box at [at], fetching it first if needed.
  Future<({String type, int size})?> _boxAt(
    int fileId,
    int at,
    int size,
  ) async {
    if (at + 8 > size) return null;
    final bytes = await _readRange(fileId, at, min(16, size - at));
    return bytes == null
        ? null
        : FragmentedMp4.boxHeader(bytes, remaining: size - at);
  }

  /// [length] bytes of the file from [offset], once TDLib has them. Null if
  /// they don't arrive.
  Future<Uint8List?> _readRange(int fileId, int offset, int length) async {
    final reader = _Reader();
    await _startDownload(fileId, offset: offset, length: length);
    final out = BytesBuilder(copy: false);
    var position = offset;
    RandomAccessFile? handle;
    try {
      while (position < offset + length) {
        final file = await _awaitBytesAt(fileId, position, reader);
        if (file == null) return null;
        handle ??= await File(file.local.path).open();
        final want = min(
          _availableAt(file, position),
          offset + length - position,
        );
        await handle.setPosition(position);
        final bytes = await handle.read(want);
        if (bytes.isEmpty) return null;
        out.add(bytes);
        position += bytes.length;
      }
      return out.takeBytes();
    } finally {
      await handle?.close();
    }
  }

  /// Waits until [offset] is inside the downloaded prefix, or the file is done.
  /// Returns null on timeout, on failure, or once [reader] is superseded.
  ///
  /// Wakes on the file's updates, on a supersede, and every [recheckInterval]
  /// regardless, so a dropped update costs half a second rather than the
  /// whole stall timeout.
  Future<td.File?> _awaitBytesAt(int fileId, int offset, _Reader reader) async {
    var wake = Completer<void>();
    void pulse() {
      if (!wake.isCompleted) wake.complete();
    }

    final updates = _tdlib.fileUpdates
        .where((u) => u.file.id == fileId)
        .listen((_) => pulse());
    final ticker = Timer.periodic(recheckInterval, (_) => pulse());
    reader.onSupersede = pulse;
    final deadline = DateTime.now().add(stallTimeout);

    try {
      while (!reader.isSuperseded) {
        // Armed before the read, so an update that lands during it still
        // wakes the next wait.
        wake = Completer<void>();
        final file = await _getFile(fileId);
        if (file == null) return null;
        if (_availableAt(file, offset) > 0) return file;
        if (DateTime.now().isAfter(deadline)) {
          debugPrint('[FileServer] file $fileId stalled at $offset');
          return null;
        }
        await wake.future;
      }
      return null;
    } finally {
      reader.onSupersede = null;
      ticker.cancel();
      await updates.cancel();
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

  Future<void> _startDownload(
    int fileId, {
    required int offset,
    required int length,
  }) async {
    try {
      await _tdlib.sendRequest(
        td.DownloadFile(
          fileId: fileId,
          priority: 32,
          offset: offset,
          limit: length,
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

/// A fragmented MP4 served with [index] inserted at [insertAt].
class _Layout {
  final int insertAt;
  final Uint8List index;

  const _Layout({required this.insertAt, required this.index});

  /// Whether the served byte [position] is part of the index.
  bool holds(int position) =>
      position >= insertAt && position < insertAt + index.length;

  /// The offset in the file behind the served byte [position]. Bytes of the
  /// index stand for where it goes in.
  int fileOffset(int position) {
    if (position < insertAt) return position;
    if (holds(position)) return insertAt;
    return position - index.length;
  }
}

/// One response reading a file, until a newer request for the file
/// supersedes it.
class _Reader {
  bool isSuperseded = false;

  /// Wakes the reader if it is waiting for bytes.
  void Function()? onSupersede;

  void supersede() {
    isSuperseded = true;
    onSupersede?.call();
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
