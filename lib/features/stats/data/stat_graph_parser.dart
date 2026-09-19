import 'dart:convert';
import 'dart:ui';

import 'package:gramx/features/stats/domain/stat_graph.dart';

/// Reads Telegram's chart JSON into a [StatGraph].
///
/// **Pure, and tested against saved payloads** — the same decision as
/// `TmePageParser`, for the same reason. `statisticalGraphData.json_data` is a
/// format of Telegram's own that nobody promised to keep stable, and it
/// arrives as a *string* inside the TDLib reply rather than as typed fields,
/// so nothing in `handy_tdlib` checks its shape. A change to it has to surface
/// as a failing test here, not as an empty box on somebody's screen.
///
/// The shape:
///
/// ```json
/// {
///   "columns": [["x", 1719792000000, …], ["y0", 12, 19, …]],
///   "types":   {"x": "x", "y0": "line"},
///   "names":   {"y0": "Members"},
///   "colors":  {"y0": "#4BC7C1"},
///   "percentage": false,
///   "stacked": false
/// }
/// ```
///
/// Every field except `columns` is optional in practice, and each missing one
/// costs exactly what it describes: a series keeps its key as its name, or
/// takes the chart's default colour. Only a missing or unreadable x axis is
/// fatal, because there is nothing to plot the numbers against.
abstract class StatGraphParser {
  /// Parses `statisticalGraphData.jsonData`, or returns null if it cannot.
  ///
  /// Null means "draw the unavailable state", never an empty chart: a chart
  /// frame with no line in it reads as a channel with no activity, which is a
  /// different and much worse claim than "this did not load".
  static StatGraph? parse(String jsonData) {
    if (jsonData.trim().isEmpty) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(jsonData);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final columns = decoded['columns'];
    if (columns is! List || columns.isEmpty) return null;

    final types = _stringMap(decoded['types']);
    final names = _stringMap(decoded['names']);
    final colors = _stringMap(decoded['colors']);

    // The x column is the one *typed* `x`. Falling back to the key `x` covers
    // a payload that omits `types` entirely, which is legal and happens.
    List<Object?>? xColumn;
    final yColumns = <List<Object?>>[];

    for (final column in columns) {
      if (column is! List || column.isEmpty) continue;
      final key = column.first;
      if (key is! String) continue;

      final isX = types[key] == 'x' || (types[key] == null && key == 'x');
      if (isX && xColumn == null) {
        xColumn = column;
      } else if (!isX) {
        yColumns.add(column);
      }
    }

    if (xColumn == null || yColumns.isEmpty) return null;

    // Telegram sends every column the same length. "In practice" is not a
    // guarantee, and a y column one entry longer than the x axis would either
    // throw or draw a point at an invented date, so everything is cut to the
    // shortest column present.
    var length = xColumn.length - 1;
    for (final column in yColumns) {
      final candidate = column.length - 1;
      if (candidate < length) length = candidate;
    }
    if (length <= 0) return null;

    final timestamps = <int>[];
    for (var i = 1; i <= length; i++) {
      final raw = xColumn[i];
      if (raw is! num) return null;
      timestamps.add(raw.toInt());
    }

    final lines = <StatGraphLine>[];
    for (final column in yColumns) {
      final key = column.first as String;
      final values = <double>[
        for (var i = 1; i <= length; i++) _asDouble(column[i]),
      ];
      lines.add(
        StatGraphLine(
          key: key,
          name: names[key] ?? key,
          color: parseColor(colors[key]),
          shape: StatGraphShape.parse(types[key]),
          values: values,
        ),
      );
    }

    return StatGraph(
      timestamps: timestamps,
      lines: lines,
      isPercentage: decoded['percentage'] == true,
      isStacked: decoded['stacked'] == true,
    );
  }

  /// Telegram's colour strings: `#4BC7C1`, the three-digit `#4BC`, and the
  /// `rgb(75,199,193)` form its older charts use.
  ///
  /// Anything else answers null and the chart falls back to its own palette,
  /// which is better than a black line on a black theme.
  static Color? parseColor(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('#')) {
      var hex = value.substring(1);
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      if (hex.length != 6) return null;
      final parsed = int.tryParse(hex, radix: 16);
      return parsed == null ? null : Color(0xFF000000 | parsed);
    }

    final rgb = RegExp(
      r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (rgb == null) return null;

    final channels = [
      for (var i = 1; i <= 3; i++) int.parse(rgb.group(i)!).clamp(0, 255),
    ];
    return Color.fromARGB(255, channels[0], channels[1], channels[2]);
  }

  static Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  /// A missing or non-numeric sample is zero rather than a gap.
  ///
  /// Telegram uses `null` for "no data that day", and on a count graph no data
  /// and none of it are the same thing to a reader.
  static double _asDouble(Object? raw) => raw is num ? raw.toDouble() : 0;
}
