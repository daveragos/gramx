import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/presentation/mute_registry.dart';

void main() {
  final now = DateTime(2026, 8, 23, 12, 0);

  group('MuteRegistry', () {
    test('a channel muted for an hour is muted now and free after', () {
      final registry = MuteRegistry();
      registry.mute(
        '-100111',
        chatId: -100111,
        until: MuteDuration.oneHour.expiryFrom(now),
      );

      expect(registry.isMuted('-100111', chatId: -100111, now: now), isTrue);
      expect(
        registry.isMuted(
          '-100111',
          chatId: -100111,
          now: now.add(const Duration(hours: 2)),
        ),
        isFalse,
      );
    });

    test('an indefinite mute never lifts on its own', () {
      final registry = MuteRegistry();
      registry.mute('-100111', chatId: -100111);

      expect(
        registry.isMuted(
          '-100111',
          chatId: -100111,
          now: now.add(const Duration(days: 400)),
        ),
        isTrue,
      );
      expect(
        registry.mutedUntil('-100111', chatId: -100111, now: now),
        isNull,
        reason: 'there is no deadline to show',
      );
    });

    // A channel is learned under different ids depending on where it came
    // from, so muting it in one place has to mute it in all of them.
    test('a mute set under any id is seen under the others', () {
      final registry = MuteRegistry();
      registry.mute('-100111', chatId: -100111, username: 'somech');

      expect(registry.isMuted('somech', now: now), isTrue);
      expect(
        registry.isMuted('100111', now: now),
        isTrue,
        reason: 'the unsigned chat id is one of the names it answers to',
      );
      expect(registry.isMuted('-100111', now: now), isTrue);
    });

    test('unmuting clears every id it was stored under', () {
      final registry = MuteRegistry();
      registry.mute('-100111', chatId: -100111, username: 'somech');
      registry.unmute('-100111', chatId: -100111, username: 'somech');

      expect(registry.isMuted('somech', now: now), isFalse);
      expect(registry.isEmpty, isTrue);
    });

    test('mutedUntil reports the deadline a timed mute lifts on', () {
      final registry = MuteRegistry();
      final until = MuteDuration.twoDays.expiryFrom(now);
      registry.mute('-100111', chatId: -100111, until: until);

      expect(registry.mutedUntil('-100111', chatId: -100111, now: now), until);
    });

    test('re-muting replaces the old deadline', () {
      final registry = MuteRegistry();
      registry.mute(
        '-100111',
        chatId: -100111,
        until: MuteDuration.oneHour.expiryFrom(now),
      );
      registry.mute(
        '-100111',
        chatId: -100111,
        until: MuteDuration.twoDays.expiryFrom(now),
      );

      expect(
        registry.isMuted(
          '-100111',
          chatId: -100111,
          now: now.add(const Duration(hours: 5)),
        ),
        isTrue,
      );
    });

    group('expiry', () {
      test('pruning drops what has run out and keeps what has not', () {
        final registry = MuteRegistry();
        registry.mute(
          '-100111',
          chatId: -100111,
          until: now.add(const Duration(minutes: 30)),
        );
        registry.mute('-100222', chatId: -100222);

        expect(
          registry.pruneExpired(now.add(const Duration(hours: 1))),
          isTrue,
        );
        expect(registry.isMuted('-100111', chatId: -100111, now: now), isFalse);
        expect(registry.isMuted('-100222', chatId: -100222, now: now), isTrue);
      });

      test('pruning nothing reports no change, so nothing is re-saved', () {
        final registry = MuteRegistry();
        registry.mute('-100111', chatId: -100111);
        expect(registry.pruneExpired(now), isFalse);
      });

      // So the notifier can wake exactly once instead of polling a clock.
      test('the next expiry is the soonest deadline still ahead', () {
        final registry = MuteRegistry();
        registry.mute('a', until: now.add(const Duration(hours: 8)));
        registry.mute('b', until: now.add(const Duration(hours: 1)));
        registry.mute('c');

        expect(registry.nextExpiry(now), now.add(const Duration(hours: 1)));
      });

      test('nothing timed means nothing to wake for', () {
        final registry = MuteRegistry();
        registry.mute('c');
        expect(registry.nextExpiry(now), isNull);
      });

      test('activeIds leaves out mutes that have run out', () {
        final registry = MuteRegistry();
        registry.mute('a', until: now.subtract(const Duration(minutes: 1)));
        registry.mute('b');

        expect(registry.activeIds(now), {'b'});
      });
    });

    group('persistence', () {
      test('survives a round trip, deadlines included', () {
        final registry = MuteRegistry();
        final until = now.add(const Duration(hours: 8));
        registry.mute('a', until: until);
        registry.mute('b');

        final restored = MuteRegistry.fromJson(registry.toJson());

        expect(restored.mutedUntil('a', now: now), until);
        expect(restored.isMuted('b', now: now), isTrue);
      });

      // A bare list of ids is the format without expiry, read as indefinite.
      test('reads the old list format as indefinite mutes', () {
        final restored = MuteRegistry.fromJson(['-100111', 'somech']);

        expect(restored.isMuted('-100111', now: now), isTrue);
        expect(restored.mutedUntil('-100111', now: now), isNull);
      });

      test('junk on disk costs the mutes, not the app', () {
        expect(MuteRegistry.fromJson('nonsense').isEmpty, isTrue);
        expect(MuteRegistry.fromJson(null).isEmpty, isTrue);
      });
    });
  });

  group('MuteDuration', () {
    test('forever has no expiry', () {
      expect(MuteDuration.forever.expiryFrom(now), isNull);
    });

    test('the timed ones are the durations Telegram offers', () {
      expect(
        MuteDuration.oneHour.expiryFrom(now),
        now.add(const Duration(hours: 1)),
      );
      expect(
        MuteDuration.eightHours.expiryFrom(now),
        now.add(const Duration(hours: 8)),
      );
      expect(
        MuteDuration.twoDays.expiryFrom(now),
        now.add(const Duration(days: 2)),
      );
    });
  });
}
