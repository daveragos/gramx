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
