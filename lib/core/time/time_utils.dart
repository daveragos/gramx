import 'package:intl/intl.dart';

abstract class TimeUtils {
  /// A short relative timestamp: 'now', '2m', '2h', 'Jun 15' or 'Jun 15, 2024'.
  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.isNegative) return 'now';
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';

    if (dateTime.year == now.year) {
      return DateFormat('MMM d').format(dateTime);
    }
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  /// Full date and time, for the post detail view.
  static String fullDateTime(DateTime dateTime) {
    return DateFormat('h:mm a · MMM d, yyyy').format(dateTime);
  }

  /// A media length as `m:ss`, or `h:mm:ss` once it passes an hour.
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final paddedSecs = secs.toString().padLeft(2, '0');
    if (hours == 0) return '$mins:$paddedSecs';
    return '$hours:${mins.toString().padLeft(2, '0')}:$paddedSecs';
  }

  /// A deadline as a time today, a weekday this week, or a date beyond that.
  /// Used for "muted until ...".
  static String untilWhen(DateTime deadline, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final difference = deadline.difference(reference);

    if (difference.isNegative) return 'now';
    if (difference.inHours < 12 ||
        (deadline.year == reference.year &&
            deadline.month == reference.month &&
            deadline.day == reference.day)) {
      return DateFormat('HH:mm').format(deadline);
    }
    if (difference.inDays < 7) return DateFormat('EEEE HH:mm').format(deadline);
    return DateFormat('MMM d').format(deadline);
  }

  /// A calendar date: `Jun 7`, or `Jun 7, 2024` outside this year.
  static String shortDate(DateTime dateTime, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (dateTime.year == reference.year) {
      return DateFormat('MMM d').format(dateTime);
    }
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  /// One label on a chart's x axis, formatted by the axis [span]. Telegram
  /// sends every statistics axis as timestamps, even an hour-of-day one.
  static String axisLabel(DateTime dateTime, Duration span, {DateTime? now}) {
    if (span.inHours <= 48) return DateFormat('HH:mm').format(dateTime);
    if (span.inDays > 365) return DateFormat('MMM yyyy').format(dateTime);
    return shortDate(dateTime, now: now);
  }

  /// Formats a count: 1000 -> '1K', 1000000 -> '1M'
  static String formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 10000) {
      final k = count / 1000;
      return k == k.truncateToDouble()
          ? '${k.toInt()}K'
          : '${k.toStringAsFixed(1)}K';
    }
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(0)}K';
    if (count < 10000000) {
      final m = count / 1000000;
      return m == m.truncateToDouble()
          ? '${m.toInt()}M'
          : '${m.toStringAsFixed(1)}M';
    }
    return '${(count / 1000000).toStringAsFixed(0)}M';
  }
}
