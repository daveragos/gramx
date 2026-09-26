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
    // The log exists so somebody can be asked to send it, which means what
    // goes into it has to be safe to send. Each of these covers something the
    // app is known to put in an error message.
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
      final record = _record('Something broke', at: DateTime(2026, 8, 30, 9, 5));
      final decoded = ErrorLogFormatter.decodeHeader(
        ErrorLogFormatter.encode(record),
      );

      expect(decoded, isNotNull);
      expect(decoded!.message, 'Something broke');
      expect(decoded.source, ErrorSource.widget);
      expect(decoded.at.toUtc(), record.at.toUtc());
    });

    // Stack lines are indented under their header, so reading the file back
    // has to skip them rather than mistake each one for another error.
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
      expect(
        trimmed.split('\n').length,
        ErrorLogFormatter.stackFrames,
      );
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

    // A widget that throws in `build` throws on every frame. Fifty copies of
    // one fault is a log that has thrown away everything leading up to it.
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
      final state = const ErrorLogState().add(_record('old')).add(_record('new'));

      expect(state.newestFirst.first.message, 'new');
    });
  });

  group('ErrorHandlers', () {
    setUp(ErrorHandlers.reset);
    tearDown(ErrorHandlers.reset);

    // The errors most worth having are thrown while starting up, before there
    // is a log to write them to. They are held until one appears.
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

    // A crash loop during startup would otherwise push out the first error,
    // which is the one that says what actually happened.
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

  // Most of what reaches the log is thrown while the widget tree is being
  // built — a failed assertion in a build method — and Riverpod refuses a
  // provider change mid-build. The record was dropped, so exactly the errors
  // worth keeping were never kept.
  testWidgets('an error recorded while building is kept', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Listened to, so the provider is alive and the change can be seen.
    container.listen(errorLogProvider, (_, _) {});

    // The refusal surfaced only as a line on the console, after the state had
    // changed and before the record reached the file — so the screen showed
    // it once and it was gone on the next launch.
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
    // Restored inside the test: the framework checks it is back before
    // tear-down runs.
    debugPrint = original;

    expect(
      container.read(errorLogProvider).records.single.message,
      contains('thrown while building'),
    );
    expect(printed.where((line) => line.contains('failed to record')), isEmpty);
  });
}
