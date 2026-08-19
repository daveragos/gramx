import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/presentation/feed_focus_tracker.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  late FeedFocusTracker tracker;
  setUp(() => tracker = FeedFocusTracker());

  group('read dwell', () {
    // The regression this replaces: PostCard marked posts read from build(),
    // so Flutter's build-ahead marked posts the user never saw — and pushed
    // that read state to every Telegram client they own.
    test('a post only counts as read after it has been on screen', () {
      tracker.onVisibilityChanged('a', 1.0, at(0));

      expect(tracker.takeNewlyRead(at(100)), isEmpty);
      expect(tracker.takeNewlyRead(at(499)), isEmpty);
      expect(tracker.takeNewlyRead(at(500)), ['a']);
    });

    test('a post flung past is never marked read', () {
      tracker.onVisibilityChanged('a', 1.0, at(0));
      tracker.onVisibilityChanged('a', 0.0, at(200));

      expect(tracker.takeNewlyRead(at(1000)), isEmpty);
    });

    test('dwell restarts when a post leaves and comes back', () {
      tracker.onVisibilityChanged('a', 1.0, at(0));
      tracker.onVisibilityChanged('a', 0.1, at(400));
      tracker.onVisibilityChanged('a', 1.0, at(500));

      expect(tracker.takeNewlyRead(at(900)), isEmpty,
          reason: 'only 400ms since it returned');
      expect(tracker.takeNewlyRead(at(1000)), ['a']);
    });

    test('a barely-visible sliver does not accumulate dwell', () {
      // The top card is usually clipped by the app bar.
      tracker.onVisibilityChanged('a', 0.2, at(0));
      expect(tracker.takeNewlyRead(at(5000)), isEmpty);
    });

    test('each post is reported exactly once', () {
      tracker.onVisibilityChanged('a', 1.0, at(0));

      expect(tracker.takeNewlyRead(at(600)), ['a']);
      expect(tracker.takeNewlyRead(at(700)), isEmpty);
      expect(tracker.takeNewlyRead(at(5000)), isEmpty);
    });

    test('several posts settle independently', () {
      tracker.onVisibilityChanged('a', 1.0, at(0));
      tracker.onVisibilityChanged('b', 0.9, at(300));

      expect(tracker.takeNewlyRead(at(550)), ['a']);
      expect(tracker.takeNewlyRead(at(850)), ['b']);
    });

    test('a post seeded as already read is never reported', () {
      tracker.markAlreadyRead('a');
      tracker.onVisibilityChanged('a', 1.0, at(0));

      expect(tracker.takeNewlyRead(at(5000)), isEmpty);
      expect(tracker.hasReported('a'), isTrue);
    });
  });

  group('chat focus', () {
    test('focus settles on the dominant post after the longer dwell', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));

      expect(tracker.settleFocus(at(599)), isFalse);
      expect(tracker.focusedPostId, isNull);

      expect(tracker.settleFocus(at(600)), isTrue);
      expect(tracker.focusedPostId, 'a');
    });

    // TDLib streams reaction and view counts only for open chats, and expects
    // roughly one open at a time — so the *most* visible card wins, not the
    // first one built, which on full-width cards is often a clipped neighbour.
    test('the most visible post wins, not the first reported', () {
      tracker.onVisibilityChanged('a', 0.55, at(0));
      tracker.onVisibilityChanged('b', 0.95, at(0));

      tracker.settleFocus(at(600));
      expect(tracker.focusedPostId, 'b');
    });

    test('focus does not change while the dominant post keeps changing', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));
      tracker.onVisibilityChanged('a', 0.1, at(200));
      tracker.onVisibilityChanged('b', 0.9, at(200));
      tracker.onVisibilityChanged('b', 0.1, at(400));
      tracker.onVisibilityChanged('c', 0.9, at(400));

      expect(tracker.settleFocus(at(700)), isFalse,
          reason: 'c has only dominated for 300ms');
      expect(tracker.focusedPostId, isNull);

      expect(tracker.settleFocus(at(1000)), isTrue);
      expect(tracker.focusedPostId, 'c');
    });

    test('settling twice on the same post reports no change', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));

      expect(tracker.settleFocus(at(600)), isTrue);
      expect(tracker.settleFocus(at(1200)), isFalse,
          reason: 'no chat swap needed when focus is unchanged');
    });

    test('nothing sufficiently visible means no focus', () {
      tracker.onVisibilityChanged('a', 0.3, at(0));
      expect(tracker.settleFocus(at(5000)), isFalse);
      expect(tracker.focusedPostId, isNull);
    });
  });

  group('releasing focus', () {
    // Navigating away leaves an open chat streaming updates for a screen the
    // user is no longer looking at, and TDLib expects ~one open chat at a time.
    test('focus is released once nothing is visible', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));
      tracker.settleFocus(at(600));
      expect(tracker.focusedPostId, 'a');

      tracker.onVisibilityChanged('a', 0.0, at(700));

      expect(tracker.releaseFocusIfNothingVisible(), isTrue);
      expect(tracker.focusedPostId, isNull);
    });

    test('focus is kept while something is still on screen', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));
      tracker.settleFocus(at(600));

      tracker.onVisibilityChanged('a', 0.6, at(700));

      expect(tracker.releaseFocusIfNothingVisible(), isFalse);
      expect(tracker.focusedPostId, 'a');
    });

    test('releasing twice is a no-op', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));
      tracker.settleFocus(at(600));
      tracker.onVisibilityChanged('a', 0.0, at(700));

      expect(tracker.releaseFocusIfNothingVisible(), isTrue);
      expect(tracker.releaseFocusIfNothingVisible(), isFalse);
    });
  });

  group('hasPendingWork', () {
    test('is false once everything has settled', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));
      tracker.takeNewlyRead(at(600));
      tracker.settleFocus(at(700));

      expect(tracker.hasPendingWork, isFalse,
          reason: 'the ticker should be allowed to stop');
    });

    test('is true while a post still owes a read ack', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));
      expect(tracker.hasPendingWork, isTrue);
    });

    // Regression: checking only for a non-null candidate stopped the ticker
    // before focus could be released, leaking an open chat.
    test('is true while focus still needs releasing', () {
      tracker.onVisibilityChanged('a', 0.9, at(0));
      tracker.takeNewlyRead(at(600));
      tracker.settleFocus(at(700));
      tracker.onVisibilityChanged('a', 0.0, at(800));

      expect(tracker.hasPendingWork, isTrue);
    });
  });

  group('lifecycle', () {
    test('disposing a card stops it accumulating dwell', () {
      tracker.onVisibilityChanged('a', 1.0, at(0));
      tracker.onDisposed('a');

      expect(tracker.takeNewlyRead(at(5000)), isEmpty);
      expect(tracker.trackedPostIds, isEmpty);
    });

    test('clear resets everything', () {
      tracker.onVisibilityChanged('a', 1.0, at(0));
      tracker.takeNewlyRead(at(600));
      tracker.settleFocus(at(700));

      tracker.clear();

      expect(tracker.focusedPostId, isNull);
      expect(tracker.hasReported('a'), isFalse);
      expect(tracker.trackedPostIds, isEmpty);
    });
  });
}
