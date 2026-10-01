import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where an error came from.
enum ErrorSource {
  /// A widget threw while building, laying out or painting.
  widget('widget'),

  /// An unhandled exception on the platform's own thread.
  platform('platform'),

  /// An uncaught error in the app's zone.
  zone('zone'),

  /// An error the app handled but still logs.
  reported('reported');

  const ErrorSource(this.tag);

  final String tag;

  static ErrorSource fromTag(String tag) => ErrorSource.values.firstWhere(
    (s) => s.tag == tag,
    orElse: () => reported,
  );
}

@immutable
class ErrorRecord {
  final DateTime at;
  final ErrorSource source;
  final String message;

  /// The first few frames, or null if there were none.
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

/// Encodes and decodes records, redacting personal data so the log is safe to
/// share.
abstract class ErrorLogFormatter {
  static const int stackFrames = 12;

  /// A phone number, in any of the shapes the sign-in screen produces.
  static final RegExp _phone = RegExp(r'\+?\d[\d\s\-()]{7,}\d');

  /// An absolute path, which can contain the sandbox id or a user name.
  static final RegExp _path = RegExp(r'(/[\w.\-]+){2,}');

  /// A bot token or API hash: any long hex string.
  static final RegExp _secret = RegExp(r'\b[0-9a-fA-F]{24,}\b');

  /// Redacts secrets, phone numbers and paths.
  static String redact(String text) => text
      .replaceAll(_secret, '<redacted>')
      .replaceAll(_phone, '<phone>')
      .replaceAll(_path, '<path>');

  /// Keeps the top [stackFrames] lines of a stack trace.
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

  /// One record as a tab-separated header line with the stack indented below.
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

  /// Parses a header line written by [encode], or returns null for a stack
  /// line.
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

/// The records held in memory, oldest first, capped. [ErrorLog] handles I/O.
@immutable
class ErrorLogState {
  static const int capacity = 50;

  final List<ErrorRecord> records;

  const ErrorLogState({this.records = const []});

  /// Adds a record, dropping the oldest past [capacity]. A repeat of the last
  /// message is ignored, since a throwing `build` repeats every frame.
  ErrorLogState add(ErrorRecord record) {
    if (records.isNotEmpty && records.last.message == record.message) {
      return this;
    }
    final next = [...records, record];
    if (next.length <= capacity) return ErrorLogState(records: next);
    return ErrorLogState(records: next.sublist(next.length - capacity));
  }

  bool get isEmpty => records.isEmpty;

  List<ErrorRecord> get newestFirst => records.reversed.toList();
}

/// The app's error log, persisted to a local file so it survives restarts.
/// Nothing is sent off the device.
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

  /// Records one failure. Never throws, since error handlers call it.
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

      // Riverpod does not allow changing a provider during build, so errors
      // thrown mid-frame are stored after it.
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

  /// Whether a frame's build, layout or paint is running.
  static bool get _isBuilding {
    try {
      return SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks;
    } catch (_) {
      return false;
    }
  }

  /// Appends one record, queued behind any write in progress.
  Future<void> _append(ErrorRecord record) async {
    _writing = (_writing ?? Future<void>.value()).then((_) async {
      final file = await _resolveFile();
      if (file == null) return;
      try {
        // Rewrite once the cap is reached so the file matches the state.
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

  Future<void> clear() async {
    state = const ErrorLogState();
    final file = await _resolveFile();
    try {
      if (file != null && file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('[ErrorLog] could not delete the log: $e');
    }
  }

  /// The whole log as one block of text.
  String asText() => state.records.map(ErrorLogFormatter.encode).join('\n\n');
}

final errorLogProvider = NotifierProvider<ErrorLog, ErrorLogState>(
  ErrorLog.new,
);
