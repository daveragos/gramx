import 'package:gramx/features/chats/domain/chat_message.dart';

/// One row of a rendered conversation: either a message, or the date band
/// above the first message of a day.
sealed class ConversationRow {
  const ConversationRow();
}

/// The centred "Today" / "Fri, May 01" band between two days.
class ConversationDateRow extends ConversationRow {
  final DateTime date;
  const ConversationDateRow(this.date);
}

/// The "Unread messages" band above the first unseen message. Its position is
/// fixed for the visit, so it doesn't move as messages are marked read.
class ConversationUnreadRow extends ConversationRow {
  const ConversationUnreadRow();
}

/// A message, with what the renderer needs to know about its neighbours.
/// Grouping is decided here because a widget can only see itself.
class ConversationMessageRow extends ConversationRow {
  final ChatMessage message;

  /// First of a run from the same sender. Carries the name and the top corner.
  final bool isFirstInGroup;

  /// Last of a run. Carries the avatar, the timestamp and the bubble's tail.
  final bool isLastInGroup;

  const ConversationMessageRow(
    this.message, {
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });
}

/// Turns a flat message list into the rows a conversation draws.
abstract class ConversationRows {
  /// How far apart two messages from the same sender can be and still be drawn
  /// as one run.
  static const Duration groupWindow = Duration(minutes: 5);

  /// The unread band's index counted from the newest row, or null. The
  /// reversed list builds lazily, so the screen finds the band by index.
  static int? unreadRowFromNewest(List<ConversationRow> rows) {
    final index = rows.indexWhere((row) => row is ConversationUnreadRow);
    if (index < 0) return null;
    return rows.length - 1 - index;
  }

  /// Builds the rows, oldest first, from messages in ascending id order.
  /// [firstUnreadMessageId] puts the unread band above that message.
  static List<ConversationRow> build(
    List<ChatMessage> all, {
    int? firstUnreadMessageId,
  }) {
    // Service messages with no text are dropped, along with the date band of a
    // day that had only those. See `ChatMessageMapper.serviceText`.
    final messages = [
      for (final message in all)
        if (!message.isService || (message.text?.isNotEmpty ?? false)) message,
    ];
    final rows = <ConversationRow>[];
    DateTime? currentDay;
    var unreadBandDrawn = false;

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final day = dayOf(message.sentAt);

      if (currentDay == null || day != currentDay) {
        rows.add(ConversationDateRow(day));
        currentDay = day;
      }

      // The unread band goes below the date band, directly above the message.
      if (!unreadBandDrawn && message.messageId == firstUnreadMessageId) {
        rows.add(const ConversationUnreadRow());
        unreadBandDrawn = true;
      }

      final previous = i == 0 ? null : messages[i - 1];
      final next = i == messages.length - 1 ? null : messages[i + 1];

      rows.add(
        ConversationMessageRow(
          message,
          // A new day always starts a new run.
          isFirstInGroup:
              previous == null ||
              dayOf(previous.sentAt) != day ||
              !_sameRun(previous, message),
          isLastInGroup:
              next == null ||
              dayOf(next.sentAt) != day ||
              !_sameRun(message, next),
        ),
      );
    }

    return rows;
  }

  /// Local midnight of the day [time] falls on.
  static DateTime dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// Whether [later] continues [earlier]'s run: same side, same sender, within
  /// [groupWindow], and neither a service notice.
  static bool _sameRun(ChatMessage earlier, ChatMessage later) {
    if (earlier.isService || later.isService) return false;
    if (earlier.isOutgoing != later.isOutgoing) return false;
    if (earlier.senderId != later.senderId) return false;
    return later.sentAt.difference(earlier.sentAt).abs() <= groupWindow;
  }
}
