import 'dart:convert';
import 'dart:ui';

import 'package:gramx/features/stats/domain/stat_graph.dart';

/// Reads Telegram's chart JSON (`statisticalGraphData.json_data`, an
/// undocumented format) into a [StatGraph]:
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
/// Only `columns` is required; a missing x axis is fatal.
abstract class StatGraphParser {
  /// Parses `statisticalGraphData.jsonData`, or returns null if it cannot.
  /// Null means the chart shows as unavailable, not as empty.
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

    // The x column is the one typed `x`, or keyed `x` when `types` is absent.
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

    // Columns should all be the same length, but cut to the shortest so a
    // longer y column cannot throw or plot a point with no date.
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

  /// Parses `#4BC7C1`, `#4BC` and `rgb(75,199,193)` colours. Anything else
  /// returns null, and the chart palette is used.
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

  /// A missing or non-numeric sample (Telegram sends `null`) counts as zero.
  static double _asDouble(Object? raw) => raw is num ? raw.toDouble() : 0;
}
