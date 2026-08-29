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

/// The "Unread messages" band, above the first message the reader has not seen.
///
/// Drawn once and only once, and its position is fixed for the visit: it marks
/// where reading *started*, not where it has got to. Recomputing it as messages
/// are acknowledged would slide it down the screen under the reader, which is
/// the opposite of what a bookmark is for.
class ConversationUnreadRow extends ConversationRow {
  const ConversationUnreadRow();
}

/// A message, with what the renderer needs to know about its neighbours.
///
/// Grouping is decided here rather than in the widget because it is a rule
/// about the list, and a widget can only see itself. Getting it wrong is what
/// makes a run of five messages from one person draw five avatars and five
/// names down the side.
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
///
/// Pure, and worth a test on its own: the day boundary and the grouping window
/// are two rules that are invisible when right and glaring when wrong.
abstract class ConversationRows {
  /// How far apart two messages from the same sender can be and still be drawn
  /// reply an hour later reads as part of the previous thought.
  static const Duration groupWindow = Duration(minutes: 5);

  /// Builds the rows, oldest first.
  ///
  /// [messages] is expected in the order `ConversationState` keeps them —
  /// ascending by message id, which for a chat is chronological.
  ///
  /// [firstUnreadMessageId] puts the unread band above that message. Null, or
  /// an id not in [messages], simply means no band — which is the honest answer
  /// for a chat opened with nothing waiting in it.
  static List<ConversationRow> build(
    List<ChatMessage> messages, {
    int? firstUnreadMessageId,
  }) {
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

      // Below the date band, above the message: the band says "from here on is
      // new", and a date header belongs to the day rather than to the split.
      if (!unreadBandDrawn && message.messageId == firstUnreadMessageId) {
        rows.add(const ConversationUnreadRow());
        unreadBandDrawn = true;
      }

      final previous = i == 0 ? null : messages[i - 1];
      final next = i == messages.length - 1 ? null : messages[i + 1];

      rows.add(
        ConversationMessageRow(
          message,
          // A message that opens a day always opens a run, whoever sent the last
          // one yesterday.
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

  /// Midnight of the day a timestamp falls on, in local time — which is the
  /// only sensible frame for "was this today", however the server stored it.
  static DateTime dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// Whether [later] continues [earlier]'s run.
  ///
  /// Same side of the conversation, same sender, close enough in time, and
  /// neither of them a service notice — a "you were added to the group" line
  /// between two messages breaks the run, because it is not part of it.
  static bool _sameRun(ChatMessage earlier, ChatMessage later) {
    if (earlier.isService || later.isService) return false;
    if (earlier.isOutgoing != later.isOutgoing) return false;
    if (earlier.senderId != later.senderId) return false;
    return later.sentAt.difference(earlier.sentAt).abs() <= groupWindow;
  }
}
