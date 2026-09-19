import 'package:intl/intl.dart';

abstract class TimeUtils {
  /// Under 1min: 'now', under 1hr: '2m', under 24hr: '2h',
  /// same year: 'Jun 15', other year: 'Jun 15, 2024'
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

  /// Returns full date/time for post detail view
  static String fullDateTime(DateTime dateTime) {
    return DateFormat('h:mm a · MMM d, yyyy').format(dateTime);
  }

  /// A media length as `m:ss`, or `h:mm:ss` once it passes an hour.
  ///
  /// Lived privately in the audio player until the channel media grid needed
  /// the same thing on its video tiles.
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final paddedSecs = secs.toString().padLeft(2, '0');
    if (hours == 0) return '$mins:$paddedSecs';
    return '$hours:${mins.toString().padLeft(2, '0')}:$paddedSecs';
  }

  /// A deadline, said the way a person would: a time today, a weekday this
  /// week, a date beyond that. Used for "muted until …".
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

  /// A calendar date, said the short way: `Jun 7`, and `Jun 7, 2024` once it
  /// is not this year.
  ///
  /// Unlike [relativeTime] this never collapses into `2h` — a statistics
  /// period and a chart axis are about *when*, and "now" is not a position on
  /// an axis.
  static String shortDate(DateTime dateTime, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (dateTime.year == reference.year) {
      return DateFormat('MMM d').format(dateTime);
    }
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  /// One label on a chart's x axis.
  ///
  /// The unit is chosen from how much time the whole axis covers, because the
  /// graph itself never says: Telegram sends every statistics axis as
  /// millisecond timestamps, including the one that means "hour of the day".
  /// Labelling that one `Jun 7` twenty-four times is the failure this avoids.
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
