import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

/// When a message should go out.
///
/// Three states, not a nullable `DateTime`. "Send it now" and "send it at a
/// date" are obvious; the third — *send it when they next come online* — has no
/// date at all, and squeezing it into a nullable date is what makes a scheduler
/// grow a boolean beside the date that the two halves then disagree about.
///
/// Pure and TDLib-shaped only at the edge: [toTdlib] is the one place that
/// knows the field is absent for an immediate send rather than zeroed, which is
/// the mistake that queues a message for 1970.
@immutable
class MessageSchedule {
  /// Telegram's own ceiling on how far ahead a message may be scheduled.
  static const Duration maxAhead = Duration(days: 365);

  /// The soonest a scheduled message may be set for.
  ///
  /// Telegram refuses a date in the past, and a picker that let somebody choose
  /// "one minute ago" would send them into a rejection with no explanation.
  static const Duration minAhead = Duration(minutes: 1);

  /// Send it as soon as Telegram takes it. The ordinary case.
  static const MessageSchedule now = MessageSchedule._(
    sendAt: null,
    isWhenOnline: false,
  );

  /// Send it the next time the other person is online.
  ///
  /// Private chats only — there is no "online" for a group — which is why the
  /// sheet that offers it asks the chat first.
  static const MessageSchedule whenOnline = MessageSchedule._(
    sendAt: null,
    isWhenOnline: true,
  );

  /// The moment it goes, or null for the two states that have no date.
  final DateTime? sendAt;

  /// Named with the `is` prefix so it does not collide with the [whenOnline]
  /// constant beside it — the value and the predicate are different things.
  final bool isWhenOnline;

  const MessageSchedule._({required this.sendAt, required this.isWhenOnline});

  /// A message scheduled for a moment. Rounded down to the second, because
  /// Telegram's field is a Unix timestamp and the milliseconds are noise.
  factory MessageSchedule.at(DateTime moment) =>
      MessageSchedule._(sendAt: moment, isWhenOnline: false);

  /// Whether this means "send it now".
  bool get isImmediate => sendAt == null && !isWhenOnline;

  /// Whether Telegram would accept this date — far enough ahead, not too far.
  ///
  /// Answers true for the two dateless states: neither can be out of range.
  bool get isValid {
    final moment = sendAt;
    if (moment == null) return true;
    final ahead = moment.difference(DateTime.now());
    return ahead >= minAhead && ahead <= maxAhead;
  }

  /// TDLib's form, or null for an immediate send.
  ///
  /// Null is load-bearing: TDLib reads the *presence* of a scheduling state as
  /// "this message is scheduled", so an immediate send must omit the field
  /// rather than carry a zero.
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
