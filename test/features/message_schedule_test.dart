import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/domain/message_schedule.dart';

void main() {
  group('MessageSchedule', () {
    // The load-bearing one. TDLib reads the *presence* of a scheduling state as
    // "this message is scheduled", so an immediate send has to omit the field
    // — a zero date here queues the message for 1970.
    test('sending now carries no scheduling state at all', () {
      expect(MessageSchedule.now.isImmediate, isTrue);
      expect(MessageSchedule.now.toTdlib(), isNull);
    });

    test('a date becomes a Unix timestamp in seconds', () {
      final moment = DateTime.fromMillisecondsSinceEpoch(1893456000000);
      final state =
          MessageSchedule.at(moment).toTdlib()
              as td.MessageSchedulingStateSendAtDate;

      expect(state.sendDate, 1893456000);
    });

    test('when they come online is its own state, with no date', () {
      expect(
        MessageSchedule.whenOnline.toTdlib(),
        isA<td.MessageSchedulingStateSendWhenOnline>(),
      );
      expect(MessageSchedule.whenOnline.sendAt, isNull);
      expect(MessageSchedule.whenOnline.isImmediate, isFalse);
    });

    test('a time in the past is refused before Telegram sees it', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      expect(MessageSchedule.at(past).isValid, isFalse);
    });

    test('a time seconds away is refused — Telegram wants a minute', () {
      final soon = DateTime.now().add(const Duration(seconds: 10));
      expect(MessageSchedule.at(soon).isValid, isFalse);
    });

    test('a time past a year out is refused', () {
      final far = DateTime.now().add(const Duration(days: 400));
      expect(MessageSchedule.at(far).isValid, isFalse);
    });

    test('an hour from now is fine', () {
      final soon = DateTime.now().add(const Duration(hours: 1));
      expect(MessageSchedule.at(soon).isValid, isTrue);
    });

    // Neither dateless state can be out of range, so neither must be refused by
    // a check written for dates.
    test('the two dateless states are always valid', () {
      expect(MessageSchedule.now.isValid, isTrue);
      expect(MessageSchedule.whenOnline.isValid, isTrue);
    });
  });
}
