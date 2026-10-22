import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/tdlib_file_server.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:http/http.dart' as http;

import '../support/fragmented_mp4_fixture.dart';

/// Range parsing and the loopback server's contract. Mistakes here show up as
/// a video that will not scrub.
void main() {
  group('parseRange', () {
    const total = 1000;

    test('no header is the whole file, and not a partial response', () {
      final range = parseRange(null, totalSize: total);
      expect(range.start, 0);
      expect(range.end, 999);
      expect(range.isPartial, isFalse);
    });

    test('a closed range is taken literally', () {
      final range = parseRange('bytes=100-199', totalSize: total);
      expect(range.start, 100);
      expect(range.end, 199);
      expect(range.isPartial, isTrue);
    });

    // What a player sends to start playback: everything from here on.
    test('an open-ended range runs to the last byte', () {
      final range = parseRange('bytes=500-', totalSize: total);
      expect(range.start, 500);
      expect(range.end, 999);
      expect(range.isPartial, isTrue);
    });

    // The last 500 bytes, not "from 500".
    test('a suffix range counts back from the end', () {
      final range = parseRange('bytes=-500', totalSize: total);
      expect(range.start, 500);
      expect(range.end, 999);
      expect(range.isPartial, isTrue);
    });

    test('a suffix longer than the file starts at zero', () {
      final range = parseRange('bytes=-5000', totalSize: total);
      expect(range.start, 0);
      expect(range.end, 999);
    });

    test('an end past the file is clamped, not trusted', () {
      final range = parseRange('bytes=900-99999', totalSize: total);
      expect(range.start, 900);
      expect(range.end, 999);
    });

    test('a start past the file falls back to the whole file', () {
      final range = parseRange('bytes=5000-', totalSize: total);
      expect(range.start, 0);
      expect(range.isPartial, isFalse);
    });

    // A single Content-Range header can only describe one range.
    test('a multi-range request serves the first range', () {
      final range = parseRange('bytes=0-99,200-299', totalSize: total);
      expect(range.start, 0);
      expect(range.end, 99);
    });

    test('nonsense falls back to the whole file rather than throwing', () {
      for (final header in [
        'bytes=',
        'bytes=abc-def',
        'items=0-10',
        'bytes=-',
        '',
      ]) {
        final range = parseRange(header, totalSize: total);
        expect(range.start, 0, reason: header);
        expect(range.end, 999, reason: header);
      }
    });
  });

  group('the loopback server', () {
    late TdlibFileServer server;

    setUp(() => server = TdlibFileServer(_UnusedTdlib()));
    tearDown(() => server.close());

    test('binds to loopback on an ephemeral port', () async {
      final url = await server.urlFor(1);
      expect(url.host, '127.0.0.1');
      expect(url.port, greaterThan(0));
    });

    // Without the token, any app on the device could read media off the port.
    test('the URL carries a per-launch token', () async {
      final url = await server.urlFor(42);
      expect(url.pathSegments, hasLength(2));
      expect(url.pathSegments.last, '42');
      expect(url.pathSegments.first, hasLength(32));
    });

    test('the same server reuses one port and one token', () async {
      final first = await server.urlFor(1);
      final second = await server.urlFor(2);
      expect(second.port, first.port);
      expect(second.pathSegments.first, first.pathSegments.first);
    });

    test('two servers do not share a token', () async {
      final other = TdlibFileServer(_UnusedTdlib());
      addTearDown(other.close);

      final mine = await server.urlFor(1);
      final theirs = await other.urlFor(1);
      expect(theirs.pathSegments.first, isNot(mine.pathSegments.first));
    });

    test('a request without the token is refused', () async {
      final url = await server.urlFor(7);
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${url.port}/wrongtoken/7'),
      );
      expect(response.statusCode, HttpStatus.notFound);
    });

    test('a path that is not <token>/<fileId> is refused', () async {
      final url = await server.urlFor(7);
      final token = url.pathSegments.first;

      for (final path in ['/$token', '/$token/notanumber', '/$token/7/extra']) {
        final response = await http.get(
          Uri.parse('http://127.0.0.1:${url.port}$path'),
        );
        expect(response.statusCode, HttpStatus.notFound, reason: path);
      }
    });
  });

  group('streaming a file that is still downloading', () {
    const size = 64 * 1024;
    final content = List<int>.generate(size, (i) => i * 7 % 256);

    late Directory dir;
    late _PartialFile tdlib;
    late TdlibFileServer server;
    late http.Client client;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('file_server_test');
      final file = File('${dir.path}/video.mp4');
      // All of it is on disk; the fake decides how much counts as downloaded.
      await file.writeAsBytes(content);
      tdlib = _PartialFile(file.path, size);
      server = TdlibFileServer(tdlib);
      client = http.Client();
    });

    tearDown(() async {
      client.close();
      await server.close();
      await tdlib.closeStreams();
      await dir.delete(recursive: true);
    });

    Future<http.StreamedResponse> get(String range) async {
      final url = await server.urlFor(_PartialFile.id);
      final request = http.Request('GET', url)..headers['range'] = range;
      return client.send(request);
    }

    /// Lets the next DownloadFile land, then hands out the file in steps.
    Future<void> trickle(int from) async {
      await tdlib.steeredTo(from);
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        tdlib.arrive((size - from) ~/ 4 + 1);
      }
    }

    test('serves bytes as they arrive, not after the whole file', () async {
      final response = get('bytes=0-');
      unawaited(trickle(0));

      final body = await (await response).stream.toBytes();
      expect(body, content);
    });

    // A seek past the prefix must not wait for everything before it.
    test('a range past the prefix moves the download there', () async {
      final response = get('bytes=40000-');
      unawaited(trickle(40000));

      final reply = await response;
      expect(reply.statusCode, HttpStatus.partialContent);
      expect(reply.headers['content-range'], 'bytes 40000-${size - 1}/$size');
      expect(await reply.stream.toBytes(), content.sublist(40000));
      expect(tdlib.requestedOffsets, contains(40000));
    });

    // AVPlayer goes by the Content-Type, so an MP3 sent as MP4 won't play.
    test('a file goes out as the MIME type it was opened with', () async {
      final url = await server.urlFor(_PartialFile.id, mimeType: 'audio/mpeg');
      final request = http.Request('GET', url)..headers['range'] = 'bytes=0-';
      final response = client.send(request);
      unawaited(trickle(0));

      final reply = await response;
      expect(reply.headers['content-type'], 'audio/mpeg');
      expect(await reply.stream.toBytes(), content);
    });

    test('a file opened without a MIME type goes out as MP4', () async {
      final response = get('bytes=0-');
      unawaited(trickle(0));

      final reply = await response;
      expect(reply.headers['content-type'], 'video/mp4');
      // Read to the end, so the trickle is done before teardown.
      expect(await reply.stream.toBytes(), content);
    });

    // The player seeks with a new request. Queued behind the old one, which
    // waits for bytes TDLib is no longer fetching, it would sit out the whole
    // stall timeout.
    test('a newer request takes over from one waiting for bytes', () async {
      final older = get('bytes=0-');
      await tdlib.steeredTo(0);
      final olderBody = older.then(
        (r) => r.stream.toBytes().then((b) => b.length),
        onError: (_) => -1,
      );

      final newer = get('bytes=32768-');
      unawaited(trickle(32768));

      final body = await (await newer).stream.toBytes().timeout(
        const Duration(seconds: 5),
      );
      expect(body, content.sublist(32768));
      expect(
        await olderBody.timeout(const Duration(seconds: 5)),
        lessThan(size),
      );
    });

    // Progress updates are throttled, so the one a request waits for can be
    // dropped. It must find the bytes anyway, not wait out the timeout.
    test('bytes that arrive without an update are still found', () async {
      final response = get('bytes=0-');
      await tdlib.steeredTo(0);
      // Once the server is waiting, so its first look finds nothing.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      tdlib.arrive(size, announce: false);

      final body = await (await response).stream.toBytes().timeout(
        const Duration(seconds: 5),
      );
      expect(body, content);
    });
  });

  // Long mixes come as MP4 fragments with only a trailing index, which
  // ExoPlayer ignores: no length, no seeking. The server slips the index
  // players read in after the header.
  group('MP4 audio in fragments', () {
    final fixture = FragmentedMp4Fixture();

    late Directory dir;
    late _PartialFile tdlib;
    late TdlibFileServer server;
    late http.Client client;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fragmented_mp4_test');
      final file = File('${dir.path}/mix.m4a');
      await file.writeAsBytes(fixture.bytes);
      tdlib = _PartialFile(file.path, fixture.bytes.length, complete: true);
      server = TdlibFileServer(tdlib);
      client = http.Client();
    });

    tearDown(() async {
      client.close();
      await server.close();
      await tdlib.closeStreams();
      await dir.delete(recursive: true);
    });

    Future<http.Response> get(String mimeType, {String? range}) async {
      final url = await server.urlFor(_PartialFile.id, mimeType: mimeType);
      return client.get(url, headers: {'range': ?range});
    }

    test('gets an index after its header', () async {
      final body = (await get('audio/mp4')).bodyBytes;
      final moovEnd = fixture.moovEnd;
      final index = ByteData.sublistView(body, moovEnd);
      final indexLength = index.getUint32(0);

      expect(String.fromCharCodes(body, moovEnd + 4, moovEnd + 8), 'sidx');
      expect(body.length, fixture.bytes.length + indexLength);
      expect(body.sublist(0, moovEnd), fixture.bytes.sublist(0, moovEnd));
      expect(
        body.sublist(moovEnd + indexLength),
        fixture.bytes.sublist(moovEnd),
      );
      expect(index.getUint16(38), fixture.fragments.length);
      for (var i = 0; i < fixture.fragments.length; i++) {
        expect(index.getUint32(40 + 12 * i), fixture.fragments[i].size);
        expect(index.getUint32(44 + 12 * i), fixture.fragments[i].duration);
      }
    });

    // The index points a seek at a fragment's offset as served; that must
    // land on the fragment in the file.
    test('a range past the index reads the file behind it', () async {
      final served = (await get('audio/mp4')).bodyBytes.length;
      final indexLength = served - fixture.bytes.length;
      final second = fixture.fragments[1].offset;

      final reply = await get(
        'audio/mp4',
        range: 'bytes=${second + indexLength}-',
      );

      expect(reply.statusCode, HttpStatus.partialContent);
      expect(
        reply.headers['content-range'],
        'bytes ${second + indexLength}-${served - 1}/$served',
      );
      expect(reply.bodyBytes, fixture.bytes.sublist(second));
    });

    test('a range across the index has the file on both sides', () async {
      final whole = (await get('audio/mp4')).bodyBytes;
      final from = fixture.moovEnd - 10;
      final to = whole.length - fixture.bytes.length + fixture.moovEnd + 9;

      final reply = await get('audio/mp4', range: 'bytes=$from-$to');

      expect(reply.bodyBytes, whole.sublist(from, to + 1));
    });

    test('an MP3 is served as it is', () async {
      expect((await get('audio/mpeg')).bodyBytes, fixture.bytes);
    });
  });
}

/// One file mid-download. The bytes are on disk; [arrive] decides how much of
/// it, from the download offset on, TDLib reports as downloaded.
class _PartialFile implements TdlibService {
  static const id = 9;

  final String path;
  final int size;

  /// Whether TDLib has all of it already.
  final bool complete;

  int _offset = 0;
  int _prefix = 0;
  final List<int> requestedOffsets = [];
  final _updates = StreamController<td.UpdateFile>.broadcast();
  final _steered = StreamController<int>.broadcast();

  _PartialFile(this.path, this.size, {this.complete = false});

  td.File get _file => td.File(
    id: id,
    size: size,
    expectedSize: size,
    local: td.LocalFile(
      path: path,
      canBeDownloaded: true,
      canBeDeleted: true,
      isDownloadingActive: !complete,
      isDownloadingCompleted: complete,
      downloadOffset: _offset,
      downloadedPrefixSize: _prefix,
      downloadedSize: _prefix,
    ),
    remote: const td.RemoteFile(
      id: 'remote',
      uniqueId: 'unique',
      isUploadingActive: false,
      isUploadingCompleted: true,
      uploadedSize: 0,
    ),
  );

  /// Completes once the server has asked TDLib to download from [offset].
  Future<void> steeredTo(int offset) async {
    if (requestedOffsets.contains(offset)) return;
    await _steered.stream.firstWhere((o) => o == offset);
  }

  void arrive(int bytes, {bool announce = true}) {
    _prefix = min(_prefix + bytes, size - _offset);
    if (announce) _updates.add(td.UpdateFile(file: _file));
  }

  Future<void> closeStreams() async {
    await _updates.close();
    await _steered.close();
  }

  @override
  Stream<td.UpdateFile> get fileUpdates => _updates.stream;

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (function is td.GetFile) return _file;
    if (function is td.DownloadFile) {
      if (function.offset != _offset) {
        _offset = function.offset;
        _prefix = 0;
      }
      requestedOffsets.add(function.offset);
      _steered.add(function.offset);
      return _file;
    }
    throw UnimplementedError('$function');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Throws if reached; the tests above never get past the token check.
class _UnusedTdlib implements TdlibService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the server should not have reached TDLib');
}
