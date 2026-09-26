import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';

import '../support/td_fixtures.dart';

ComposeAttachment photo({
  SelfDestruct selfDestruct = SelfDestruct.none,
  bool hasSpoiler = false,
}) => ComposeAttachment(
  path: '/tmp/a.jpg',
  kind: ComposeMediaKind.photo,
  width: 100,
  height: 100,
  selfDestruct: selfDestruct,
  hasSpoiler: hasSpoiler,
);

void main() {
  group('SelfDestruct', () {
    test('none carries no timer at all', () {
      expect(SelfDestruct.none.isEnabled, isFalse);
      expect(SelfDestruct.none.seconds, 0);
      expect(SelfDestruct.none.isViewOnce, isFalse);
    });

    test('a zero-second timer is no timer, not a zero-length one', () {
      expect(SelfDestruct.after(0), SelfDestruct.none);
    });

    test('a timer past Telegram\'s ceiling is clamped rather than refused', () {
      expect(
        SelfDestruct.after(SelfDestruct.maxSeconds + 30).seconds,
        SelfDestruct.maxSeconds,
      );
    });
  });

  group('ComposeAttachment', () {
    test('a spoiler and a timer cannot be set on the same file', () {
      final withTimer = photo(
        hasSpoiler: true,
      ).copyWith(selfDestruct: SelfDestruct.viewOnce);

      expect(withTimer.hasSpoiler, isFalse);
      expect(withTimer.canSpoiler, isFalse);
    });

    test('turning the timer off lets a spoiler be set again', () {
      final back = photo(
        selfDestruct: SelfDestruct.viewOnce,
      ).copyWith(selfDestruct: SelfDestruct.none).copyWith(hasSpoiler: true);

      expect(back.hasSpoiler, isTrue);
    });
  });

  group('what reaches TDLib', () {
    test('ordinary media carries a null self-destruct type', () {
      final content =
          ComposeMessages.build(text: '', attachments: [photo()]).single
              as td.InputMessagePhoto;

      expect(content.selfDestructType, isNull);
      expect(content.hasSpoiler, isFalse);
    });

    test('view once becomes the "immediately" type', () {
      final content =
          ComposeMessages.build(
                text: '',
                attachments: [photo(selfDestruct: SelfDestruct.viewOnce)],
              ).single
              as td.InputMessagePhoto;

      expect(
        content.selfDestructType,
        isA<td.MessageSelfDestructTypeImmediately>(),
      );
    });

    test('a timer becomes the timer type, in seconds', () {
      final content =
          ComposeMessages.build(
                text: '',
                attachments: [
                  ComposeAttachment(
                    path: '/tmp/a.mp4',
                    kind: ComposeMediaKind.video,
                    width: 100,
                    height: 100,
                    selfDestruct: SelfDestruct.after(10),
                  ),
                ],
              ).single
              as td.InputMessageVideo;

      expect(
        (content.selfDestructType as td.MessageSelfDestructTypeTimer)
            .selfDestructTime,
        10,
      );
    });

    test('a spoiler reaches Telegram as one', () {
      final content =
          ComposeMessages.build(
                text: '',
                attachments: [photo(hasSpoiler: true)],
              ).single
              as td.InputMessagePhoto;

      expect(content.hasSpoiler, isTrue);
    });
  });

  group('receiving disappearing media', () {
    test('an unopened view-once photo maps as secret and view-once', () {
      final message = ChatMessageMapper.map(
        TdFixtures.secretPhotoMessage(id: 4, chatId: 9),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.isSecretMedia, isTrue);
      expect(message.isViewOnce, isTrue);
      expect(message.selfDestructSeconds, 0);
      expect(message.selfDestructs, isTrue);
    });

    test('a timed photo carries its seconds', () {
      final message = ChatMessageMapper.map(
        TdFixtures.secretPhotoMessage(
          id: 4,
          chatId: 9,
          viewOnce: false,
          seconds: 15,
        ),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.isViewOnce, isFalse);
      expect(message.selfDestructSeconds, 15);
    });

    test('an ordinary photo is not secret', () {
      final message = ChatMessageMapper.map(
        TdFixtures.photoMessage(id: 4, chatId: 9, fileIds: const [7]),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.isSecretMedia, isFalse);
      expect(message.selfDestructs, isFalse);
    });

    // The expiry arrives as a content update, and the bubble has to stop
    // drawing a cover for media that is now gone. Before, the fold only read
    // the caption and the media off the new content and left the secret flag
    // where it was, so the cover stayed and offered a tap that opened nothing.
    test('expiry clears the secret flag through a content update', () {
      final message = ChatMessageMapper.map(
        TdFixtures.secretPhotoMessage(id: 4, chatId: 9),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      final state = ConversationState(chatId: 9, messages: [message]).apply(
        ChatMessageContentChanged(9, 4, const td.MessageExpiredPhoto()),
        users: const {},
      );

      expect(state, isNotNull);
      expect(state!.messages.single.isSecretMedia, isFalse);
      expect(state.messages.single.media, isEmpty);
      // And it says what happened rather than going blank.
      expect(state.messages.single.text, isNotNull);
    });
  });
}
