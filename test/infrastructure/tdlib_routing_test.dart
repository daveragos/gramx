import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/tdlib_receiver.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

void main() {
  group('TdlibService.isRequestReply', () {
    test('a payload carrying @extra is a reply', () {
      expect(
        TdlibService.isRequestReply({'@type': 'ok', '@extra': '12345'}),
        isTrue,
      );
    });

    // The key's presence marks a reply, even when its value is null.
    test('a present-but-null @extra is still a reply', () {
      expect(
        TdlibService.isRequestReply({'@type': 'ok', '@extra': null}),
        isTrue,
      );
    });

    test('an update without @extra is not a reply', () {
      expect(
        TdlibService.isRequestReply({'@type': 'updateNewMessage'}),
        isFalse,
      );
    });

    test('an empty payload is not a reply', () {
      expect(TdlibService.isRequestReply({}), isFalse);
    });
  });

  group('TdlibReceiver contract', () {
    test('starts not running', () {
      final receiver = TdlibReceiver(onPayload: (_) {});
      expect(receiver.isRunning, isFalse);
    });

    test('stopping before starting is safe', () async {
      final receiver = TdlibReceiver(onPayload: (_) {});
      await receiver.stop();
      expect(receiver.isRunning, isFalse);
    });

    // bootstrap() awaits TDLib before the first frame, so this bounds startup.
    test('readiness timeout is short enough not to stall startup', () {
      expect(TdlibReceiver.readyTimeout.inSeconds, lessThanOrEqualTo(3));
    });

    test('receive timeout bounds shutdown latency', () {
      expect(TdlibReceiver.receiveTimeoutSeconds, greaterThan(0));
      expect(TdlibReceiver.receiveTimeoutSeconds, lessThanOrEqualTo(2.0));
    });
  });
}
