import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/tdlib_file_server.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:http/http.dart' as http;

/// Range parsing and the loopback server's contract.
///
/// Both halves are easy to get subtly wrong in ways that only show up as a
/// video that will not scrub: an off-by-one in `Content-Range` makes a player
/// re-request the same byte forever, and the suffix form (`bytes=-500`, the
/// *last* 500 bytes) reads naturally as "from 500" if you are not looking.
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

    // The one that reads backwards: this is the last 500 bytes, not "from 500".
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

    // Only the first range of a multi-range request is served, which is what
    // the single Content-Range header can honestly describe.
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

    // The token is the only thing between this port and any other app on the
    // device — without it, a neighbour could walk file ids and pull the
    // reader's media off a plain local socket.
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
}

/// The server only reaches TDLib once a request gets past the token check, and
/// none of the tests above get that far.
class _UnusedTdlib implements TdlibService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the server should not have reached TDLib');
}
