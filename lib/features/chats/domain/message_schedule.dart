import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

/// When a message should go out: [now], at a date, or [whenOnline] (which has
/// no date).
@immutable
class MessageSchedule {
  /// Telegram's own ceiling on how far ahead a message may be scheduled.
  static const Duration maxAhead = Duration(days: 365);

  /// The soonest a scheduled message may be set for. Telegram refuses a date
  /// in the past.
  static const Duration minAhead = Duration(minutes: 1);

  /// Send it straight away.
  static const MessageSchedule now = MessageSchedule._(
    sendAt: null,
    isWhenOnline: false,
  );

  /// Send it the next time the other person is online. Private chats only.
  static const MessageSchedule whenOnline = MessageSchedule._(
    sendAt: null,
    isWhenOnline: true,
  );

  /// The moment it goes, or null for the two states that have no date.
  final DateTime? sendAt;

  /// Whether this is the [whenOnline] schedule.
  final bool isWhenOnline;

  const MessageSchedule._({required this.sendAt, required this.isWhenOnline});

  /// A message scheduled for [moment]. Telegram keeps it to whole seconds.
  factory MessageSchedule.at(DateTime moment) =>
      MessageSchedule._(sendAt: moment, isWhenOnline: false);

  /// Whether this means "send it now".
  bool get isImmediate => sendAt == null && !isWhenOnline;

  /// Whether Telegram would accept this date. Always true for the two
  /// dateless states.
  bool get isValid {
    final moment = sendAt;
    if (moment == null) return true;
    final ahead = moment.difference(DateTime.now());
    return ahead >= minAhead && ahead <= maxAhead;
  }

  /// TDLib's form, or null for an immediate send. TDLib treats any scheduling
  /// state as "scheduled", so an immediate send must omit it.
  td.MessageSchedulingState? toTdlib() {
    if (isWhenOnline) return const td.MessageSchedulingStateSendWhenOnline();
    final moment = sendAt;
    if (moment == null) return null;
    return td.MessageSchedulingStateSendAtDate(
      sendDate: moment.millisecondsSinceEpoch ~/ 1000,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MessageSchedule &&
      other.sendAt == sendAt &&
      other.isWhenOnline == isWhenOnline;

  @override
  int get hashCode => Object.hash(sendAt, isWhenOnline);

  @override
  String toString() => isWhenOnline
      ? 'MessageSchedule.whenOnline'
      : (sendAt == null ? 'MessageSchedule.now' : 'MessageSchedule($sendAt)');
}
