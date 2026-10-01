import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/infrastructure/telegram/file_update_throttle.dart';

/// TDLib emits `UpdateFile` continuously while bytes arrive. The throttle must
/// thin that flood without swallowing a terminal event.
void main() {
  final start = DateTime(2026, 8, 30, 12);

  group('FileUpdateThrottle', () {
    test('lets the first update for a file through', () {
      final throttle = FileUpdateThrottle();

      expect(throttle.allow(fileId: 1, isCompleted: false, now: start), isTrue);
    });

    test('holds the next one back until the interval has passed', () {
      final throttle = FileUpdateThrottle(
        interval: const Duration(milliseconds: 200),
      );

      throttle.allow(fileId: 1, isCompleted: false, now: start);

      expect(
        throttle.allow(
          fileId: 1,
          isCompleted: false,
          now: start.add(const Duration(milliseconds: 199)),
        ),
        isFalse,
      );
      expect(
        throttle.allow(
          fileId: 1,
          isCompleted: false,
          now: start.add(const Duration(milliseconds: 200)),
        ),
        isTrue,
      );
    });

    test('times each file separately', () {
      final throttle = FileUpdateThrottle();

      expect(throttle.allow(fileId: 1, isCompleted: false, now: start), isTrue);
      // A second file is not held back by the first one's turn.
      expect(throttle.allow(fileId: 2, isCompleted: false, now: start), isTrue);
    });

    // A dropped completion would leave a progress ring spinning forever.
    test('a completed download always passes, however recent the last one', () {
      final throttle = FileUpdateThrottle();

      throttle.allow(fileId: 1, isCompleted: false, now: start);

      expect(throttle.allow(fileId: 1, isCompleted: true, now: start), isTrue);
    });

    test('and completing forgets the file, so a re-download starts clean', () {
      final throttle = FileUpdateThrottle();

      throttle.allow(fileId: 1, isCompleted: false, now: start);
      throttle.allow(fileId: 1, isCompleted: true, now: start);

      expect(throttle.trackedCount, 0);
      expect(throttle.allow(fileId: 1, isCompleted: false, now: start), isTrue);
    });

    test('a burst of progress for one file collapses to one update', () {
      final throttle = FileUpdateThrottle(
        interval: const Duration(milliseconds: 200),
      );

      var allowed = 0;
      for (var ms = 0; ms < 200; ms += 10) {
        if (throttle.allow(
          fileId: 1,
          isCompleted: false,
          now: start.add(Duration(milliseconds: ms)),
        )) {
          allowed++;
        }
      }

      expect(allowed, 1);
    });

    test('tracking is bounded, so an abandoned download cannot leak', () {
      final throttle = FileUpdateThrottle(trackingLimit: 4);

      for (var id = 0; id < 10; id++) {
        throttle.allow(fileId: id, isCompleted: false, now: start);
      }

      expect(throttle.trackedCount, lessThanOrEqualTo(4));
    });
  });
}
