import 'package:flutter/foundation.dart';

/// One server-sent event.
@immutable
class SseEvent {
  /// The `event:` name; `message` when the server named none.
  final String event;
  final String data;

  const SseEvent(this.event, this.data);
}

/// Turns the lines of a `text/event-stream` into events, as the HTML
/// standard describes: `event:` and `data:` fields, ended by a blank line.
/// Lines starting with `:` are comments, which servers send to keep the
/// connection open.
class SseDecoder {
  String _event = '';
  final _data = <String>[];

  /// The event [line] completes, if any. [line] has no line ending.
  SseEvent? add(String line) {
    if (line.isEmpty) {
      if (_data.isEmpty) {
        _event = '';
        return null;
      }
      final event = SseEvent(
        _event.isEmpty ? 'message' : _event,
        _data.join('\n'),
      );
      _event = '';
      _data.clear();
      return event;
    }
    if (line.startsWith(':')) return null;

    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        _data.add(value);
    }
    return null;
  }
}
