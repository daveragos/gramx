import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where an error came from.
///
/// Kept separate from the message because it is the part that says whether the
/// app noticed the fault itself or only found out afterwards.
enum ErrorSource {
  /// A widget threw while building, laying out or painting.
  widget('widget'),

  /// An unhandled exception on the platform's own thread.
  platform('platform'),

  /// Something in the app's zone threw with nobody to catch it.
  zone('zone'),

  /// The app caught it, handled it, and wants it remembered anyway.
  reported('reported');

  const ErrorSource(this.tag);

  final String tag;

  static ErrorSource fromTag(String tag) => ErrorSource.values.firstWhere(
    (s) => s.tag == tag,
    orElse: () => reported,
  );
}

/// One thing that went wrong.
@immutable
class ErrorRecord {
  final DateTime at;
  final ErrorSource source;
  final String message;

  /// The first few frames, or null when there were none worth keeping.
  final String? stack;

  const ErrorRecord({
    required this.at,
    required this.source,
    required this.message,
    this.stack,
  });

  @override
  bool operator ==(Object other) =>
      other is ErrorRecord &&
      other.at == at &&
      other.source == source &&
      other.message == message &&
      other.stack == stack;

  @override
  int get hashCode => Object.hash(at, source, message, stack);
}

/// Turns records into lines and back, and takes the reader out of them first.
///
/// The whole point of a log is that somebody can be asked to send it, so what
/// goes into it has to be safe to send. Nothing here is a guess about what
/// might be sensitive — each rule below covers something the app is known to
/// put in an error message.
abstract class ErrorLogFormatter {
  /// How many frames of a stack are worth keeping.
  ///
  /// Enough to name the call path, short enough that fifty records stay a file
  /// somebody can read rather than one they have to search.
  static const int stackFrames = 12;

  /// A phone number, in any of the shapes the sign-in screen produces.
  static final RegExp _phone = RegExp(r'\+?\d[\d\s\-()]{7,}\d');

  /// An absolute path. On a real device these carry the app's sandbox id, and
  /// on a desktop build they carry the account name of whoever is signed in.
  static final RegExp _path = RegExp(r'(/[\w.\-]+){2,}');

  /// A bot token or an api hash — anything long, opaque and hex-ish.
  static final RegExp _secret = RegExp(r'\b[0-9a-fA-F]{24,}\b');

  /// Strips what should not leave the device.
  static String redact(String text) => text
      .replaceAll(_secret, '<redacted>')
      .replaceAll(_phone, '<phone>')
      .replaceAll(_path, '<path>');

  /// Keeps the top of a stack trace and drops the rest.
  static String? trimStack(StackTrace? stack) {
    if (stack == null) return null;
    final lines = stack
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(stackFrames)
        .map(redact)
        .toList();
    return lines.isEmpty ? null : lines.join('\n');
  }

  /// One record as one block of text.
  ///
  /// Tab-separated header, then the stack indented under it — a shape `grep`
  /// can pick a single record out of, which is what somebody debugging from a
  /// pasted log actually does.
  static String encode(ErrorRecord record) {
    final buffer = StringBuffer()
      ..write(record.at.toUtc().toIso8601String())
      ..write('\t')
      ..write(record.source.tag)
      ..write('\t')
      ..write(record.message.replaceAll('\n', ' ').trim());

    final stack = record.stack;
    if (stack != null) {
      for (final line in stack.split('\n')) {
        buffer.write('\n    ${line.trim()}');
      }
    }
    return buffer.toString();
  }

  /// The inverse of [encode], for reading a log back off disk.
  ///
  /// Returns null for a line that is not a header, which is how the stack
  /// lines under a record are skipped.
  static ErrorRecord? decodeHeader(String line) {
    final parts = line.split('\t');
    if (parts.length < 3) return null;
    final at = DateTime.tryParse(parts[0]);
    if (at == null) return null;
    return ErrorRecord(
      at: at.toLocal(),
      source: ErrorSource.fromTag(parts[1]),
      message: parts.sublist(2).join('\t'),
    );
  }
}

/// The records the app is holding, oldest first, capped.
///
/// Pure: no file, no clock, no I/O. [ErrorLog] owns those.
@immutable
class ErrorLogState {
  /// How many records are kept.
  ///
  /// A crash log is only useful if somebody reads it, and the last few failures
  /// are the ones that explain the current one. Unbounded, this is a file that
  /// grows for the lifetime of the install and is never opened.
  static const int capacity = 50;

  final List<ErrorRecord> records;

  const ErrorLogState({this.records = const []});

  /// Adds a record, dropping the oldest once [capacity] is reached.
  ///
  /// Identical consecutive messages are counted rather than repeated: a widget
  /// that throws in `build` throws on every frame, and fifty copies of one
  /// fault is a log that has thrown away everything that led to it.
  ErrorLogState add(ErrorRecord record) {
    if (records.isNotEmpty && records.last.message == record.message) {
      return this;
    }
    final next = [...records, record];
    if (next.length <= capacity) return ErrorLogState(records: next);
    return ErrorLogState(records: next.sublist(next.length - capacity));
  }

  bool get isEmpty => records.isEmpty;

  /// Newest first, which is the order somebody looking for what just happened
  /// wants to read them in.
  List<ErrorRecord> get newestFirst => records.reversed.toList();
}

/// The app's error log: an [ErrorLogState] plus the file it survives in.
///
/// Everything the app knows about its own failures goes through here. Nothing
/// leaves the device — there is no reporting endpoint, and the privacy policy
/// says so. The file exists so a reader can be asked what happened after a
/// restart, which is exactly when they cannot tell you.
class ErrorLog extends Notifier<ErrorLogState> {
  static const String fileName = 'gramx-errors.log';

  File? _file;
  Future<void>? _writing;

  @override
  ErrorLogState build() {
    unawaited(_load());
    return const ErrorLogState();
  }

  Future<File?> _resolveFile() async {
    final existing = _file;
    if (existing != null) return existing;
    try {
      final dir = await getApplicationSupportDirectory();
      return _file = File('${dir.path}/$fileName');
    } catch (e) {
      // A log that cannot find a home is not worth failing the app over.
      debugPrint('[ErrorLog] no writable location: $e');
      return null;
    }
  }

  Future<void> _load() async {
    final file = await _resolveFile();
    if (file == null || !file.existsSync()) return;
    try {
      final records = <ErrorRecord>[];
      for (final line in await file.readAsLines()) {
        final record = ErrorLogFormatter.decodeHeader(line);
        if (record != null) records.add(record);
      }
      if (records.isEmpty) return;
      var next = const ErrorLogState();
      for (final record in records) {
        next = next.add(record);
      }
      state = next;
    } catch (e) {
      debugPrint('[ErrorLog] could not read the log: $e');
    }
  }

  /// Records one failure.
  ///
  /// Never throws: this runs from inside the error handlers, and an error log
  /// that can fail is a second crash on top of the first.
  void record(
    Object error, {
    StackTrace? stack,
    ErrorSource source = ErrorSource.reported,
  }) {
    try {
      final entry = ErrorRecord(
        at: DateTime.now(),
        source: source,
        message: ErrorLogFormatter.redact(error.toString()),
        stack: ErrorLogFormatter.trimStack(stack),
      );

      // An error thrown while the widget tree is being built — a failed
      // assertion in a build method, which is most of what reaches here — may
      // not change a provider there and then: Riverpod refuses, and the record
      // was lost, so the errors most worth keeping were never kept.
      // Those are stored once the frame is over.
      if (_isBuilding) {
        scheduleMicrotask(() => _store(entry));
      } else {
        _store(entry);
      }
    } catch (e) {
      debugPrint('[ErrorLog] failed to record an error: $e');
    }
  }

  void _store(ErrorRecord entry) {
    try {
      final next = state.add(entry);
      if (identical(next, state)) return;
      state = next;

      unawaited(_append(entry));
    } catch (e) {
      debugPrint('[ErrorLog] failed to record an error: $e');
    }
  }

  /// Whether a frame's build, layout or paint is running right now. False with
  /// no binding at all, which is a plain unit test.
  static bool get _isBuilding {
    try {
      return SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks;
    } catch (_) {
      return false;
    }
  }

  /// Appends one record, serialised behind whatever write is already running.
  Future<void> _append(ErrorRecord record) async {
    _writing = (_writing ?? Future<void>.value()).then((_) async {
      final file = await _resolveFile();
      if (file == null) return;
      try {
        // Rewrite rather than append once the cap is reached, so the file on
        // disk holds the same records as the state does.
        if (state.records.length >= ErrorLogState.capacity) {
          await file.writeAsString(
            '${state.records.map(ErrorLogFormatter.encode).join('\n')}\n',
          );
          return;
        }
        await file.writeAsString(
          '${ErrorLogFormatter.encode(record)}\n',
          mode: FileMode.append,
        );
      } catch (e) {
        debugPrint('[ErrorLog] could not write the log: $e');
      }
    });
    return _writing;
  }

  /// Empties the log, on disk as well as in memory.
  Future<void> clear() async {
    state = const ErrorLogState();
    final file = await _resolveFile();
    try {
      if (file != null && file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('[ErrorLog] could not delete the log: $e');
    }
  }

  /// The whole log as one block of text, for the copy button.
  String asText() => state.records.map(ErrorLogFormatter.encode).join('\n\n');
}

final errorLogProvider = NotifierProvider<ErrorLog, ErrorLogState>(
  ErrorLog.new,
);
