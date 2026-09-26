import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

void main() {
  group('TdlibService.parseRetryAfter', () {
    test('reads TDLib FLOOD_WAIT_<n>', () {
      expect(TdlibService.parseRetryAfter('FLOOD_WAIT_30'), 30);
      expect(TdlibService.parseRetryAfter('FLOOD_WAIT_5'), 5);
      expect(TdlibService.parseRetryAfter('FLOOD_WAIT_600'), 600);
    });

    test('reads the HTTP-style "retry after <n>" form', () {
      expect(
        TdlibService.parseRetryAfter('Too Many Requests: retry after 12'),
        12,
      );
      expect(TdlibService.parseRetryAfter('retry after12'), 12);
    });

    test('is case insensitive', () {
      expect(TdlibService.parseRetryAfter('flood_wait_45'), 45);
      expect(TdlibService.parseRetryAfter('Retry After 7'), 7);
    });

    test('returns null when the message carries no delay', () {
      expect(TdlibService.parseRetryAfter('PHONE_NUMBER_INVALID'), isNull);
      expect(TdlibService.parseRetryAfter('Chat not found'), isNull);
      expect(TdlibService.parseRetryAfter(''), isNull);
    });
  });

  group('TdlibRequestException', () {
    test('recognises both rate-limit codes', () {
      expect(
        const TdlibRequestException(420, 'FLOOD_WAIT_30').isFloodWait,
        isTrue,
      );
      expect(
        const TdlibRequestException(429, 'retry after 30').isFloodWait,
        isTrue,
      );
    });

    test('does not mistake other failures for rate limits', () {
      expect(
        const TdlibRequestException(400, 'PHONE_NUMBER_INVALID').isFloodWait,
        isFalse,
      );
      expect(
        const TdlibRequestException(401, 'Unauthorized').isFloodWait,
        isFalse,
      );
      expect(
        const TdlibRequestException(404, 'Not found').isFloodWait,
        isFalse,
      );
    });

    test('exposes the retry delay', () {
      expect(
        const TdlibRequestException(420, 'FLOOD_WAIT_30').retryAfterSeconds,
        30,
      );
      expect(
        const TdlibRequestException(400, 'CHAT_INVALID').retryAfterSeconds,
        isNull,
      );
    });

    // Load-bearing: auth_providers.dart shows this string to the user verbatim.
    // A type prefix would surface "TdlibRequestException(400): ..." on sign-in.
    test('toString is the bare Telegram message, with no type prefix', () {
      expect(
        const TdlibRequestException(400, 'PHONE_NUMBER_INVALID').toString(),
        'PHONE_NUMBER_INVALID',
      );
      expect(
        const TdlibRequestException(
          400,
          'PHONE_CODE_INVALID',
        ).toString().replaceAll('Exception: ', ''),
        'PHONE_CODE_INVALID',
        reason: 'the auth screen strips this prefix; result must be unchanged',
      );
    });

    test('keeps the numeric code, which a bare Exception would have lost', () {
      const e = TdlibRequestException(420, 'FLOOD_WAIT_30');
      expect(e.code, 420);
    });
  });

  group('flood gate constants', () {
    test('inline wait ceiling is bounded so callers fail fast', () {
      expect(TdlibService.maxInlineFloodWait.inSeconds, lessThanOrEqualTo(60));
      expect(TdlibService.maxInlineFloodWait.inSeconds, greaterThan(0));
    });
  });
}
