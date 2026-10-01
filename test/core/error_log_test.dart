import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/diagnostics/error_handlers.dart';
import 'package:gramx/core/diagnostics/error_log.dart';

ErrorRecord _record(String message, {DateTime? at, String? stack}) =>
    ErrorRecord(
      at: at ?? DateTime(2026, 8, 30, 12),
      source: ErrorSource.widget,
      message: message,
      stack: stack,
    );

void main() {
  group('ErrorLogFormatter.redact', () {
    // The log may be shared, so personal data must be scrubbed from it.
    test('a phone number never reaches the log', () {
      final out = ErrorLogFormatter.redact(
        'PHONE_NUMBER_INVALID for +251 91 234 5678',
      );

      expect(out, contains('<phone>'));
      expect(out, isNot(contains('234')));
    });

    test('an absolute path is replaced', () {
      final out = ErrorLogFormatter.redact(
        'Failed to open /data/user/0/dev.ragoose.gramx/files/tdlib/db.sqlite',
      );

      expect(out, contains('<path>'));
      expect(out, isNot(contains('ragoose')));
    });

    test('anything long and hex-ish is treated as a key', () {
      final out = ErrorLogFormatter.redact(
        'auth failed with a1b2c3d4e5f60718293a4b5c6d7e8f90',
      );

      expect(out, contains('<redacted>'));
      expect(out, isNot(contains('a1b2c3d4')));
    });

    test('an ordinary message is left alone', () {
      const message = 'RenderFlex overflowed by 12 pixels on the right';
      expect(ErrorLogFormatter.redact(message), message);
    });
  });

  group('ErrorLogFormatter encode/decode', () {
    test('a header round-trips', () {
      final record = _record(
        'Something broke',
        at: DateTime(2026, 8, 30, 9, 5),
      );
      final decoded = ErrorLogFormatter.decodeHeader(
        ErrorLogFormatter.encode(record),
      );

      expect(decoded, isNotNull);
      expect(decoded!.message, 'Something broke');
      expect(decoded.source, ErrorSource.widget);
      expect(decoded.at.toUtc(), record.at.toUtc());
    });

    test('an indented stack line is not a record', () {
      final encoded = ErrorLogFormatter.encode(
        _record('boom', stack: '#0  main\n#1  runApp'),
      );
      final headers = encoded
          .split('\n')
          .map(ErrorLogFormatter.decodeHeader)
          .whereType<ErrorRecord>();

      expect(headers.length, 1);
    });

    test('a stack is trimmed to a readable number of frames', () {
      final long = StackTrace.fromString(
        List.generate(40, (i) => '#$i  frame$i').join('\n'),
      );

      final trimmed = ErrorLogFormatter.trimStack(long)!;
      expect(trimmed.split('\n').length, ErrorLogFormatter.stackFrames);
    });

    test('no stack stays no stack', () {
      expect(ErrorLogFormatter.trimStack(null), isNull);
    });

    test('a message with a newline stays one line', () {
      final encoded = ErrorLogFormatter.encode(_record('first\nsecond'));
      expect(encoded.split('\n').length, 1);
      expect(ErrorLogFormatter.decodeHeader(encoded)!.message, 'first second');
    });
  });

  group('ErrorLogState', () {
    test('keeps the newest once it is full', () {
      var state = const ErrorLogState();
      for (var i = 0; i < ErrorLogState.capacity + 10; i++) {
        state = state.add(_record('error $i'));
      }

      expect(state.records.length, ErrorLogState.capacity);
      expect(state.records.first.message, 'error 10');
      expect(state.records.last.message, 'error 59');
    });

    // A widget that throws in `build` throws on every frame.
    test('a repeat of the last message is not recorded twice', () {
      final state = const ErrorLogState()
          .add(_record('same'))
          .add(_record('same'))
          .add(_record('same'));

      expect(state.records.length, 1);
    });

    test('the same message after a different one is recorded again', () {
      final state = const ErrorLogState()
          .add(_record('a'))
          .add(_record('b'))
          .add(_record('a'));

      expect(state.records.map((r) => r.message), ['a', 'b', 'a']);
    });

    test('newestFirst is the reading order', () {
      final state = const ErrorLogState()
          .add(_record('old'))
          .add(_record('new'));

      expect(state.newestFirst.first.message, 'new');
    });
  });

  group('ErrorHandlers', () {
    setUp(ErrorHandlers.reset);
    tearDown(ErrorHandlers.reset);

    // Startup errors are held until a log is connected.
    test('errors before connect are handed over afterwards', () {
      ErrorHandlers.onZoneError(StateError('early'), StackTrace.empty);
      expect(ErrorHandlers.bufferedCount, 1);

      final seen = <String>[];
      ErrorHandlers.connect((e, _, _) => seen.add(e.toString()));

      expect(seen.single, contains('early'));
      expect(ErrorHandlers.bufferedCount, 0);
    });

    test('errors after connect go straight through', () {
      final seen = <ErrorSource>[];
      ErrorHandlers.connect((_, _, source) => seen.add(source));

      ErrorHandlers.onZoneError(StateError('late'), StackTrace.empty);

      expect(seen, [ErrorSource.zone]);
    });

    // A startup crash loop must not push out the first error.
    test('the hold is bounded', () {
      for (var i = 0; i < ErrorHandlers.bufferLimit + 25; i++) {
        ErrorHandlers.onZoneError(StateError('e$i'), StackTrace.empty);
      }

      expect(ErrorHandlers.bufferedCount, ErrorHandlers.bufferLimit);

      final seen = <String>[];
      ErrorHandlers.connect((e, _, _) => seen.add(e.toString()));
      expect(seen.first, contains('e0'));
    });
  });

  // Riverpod refuses a provider change mid-build, and most errors are thrown
  // during build.
  testWidgets('an error recorded while building is kept', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Keeps the provider alive.
    container.listen(errorLogProvider, (_, _) {});

    // Riverpod reports the refusal only through the console.
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            ref
                .read(errorLogProvider.notifier)
                .record(StateError('thrown while building'));
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    // The framework checks this is restored before tear-down.
    debugPrint = original;

    expect(
      container.read(errorLogProvider).records.single.message,
      contains('thrown while building'),
    );
    expect(printed.where((line) => line.contains('failed to record')), isEmpty);
  });
}
