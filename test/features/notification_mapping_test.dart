import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/activity/domain/app_notification.dart';
import 'package:gramx/features/settings/data/app_settings.dart';

import '../support/td_fixtures.dart';

td.Notification _notification(td.NotificationType type, {bool silent = false}) =>
    td.Notification(
      id: 7,
      date: 1700000000,
      isSilent: silent,
      type: type,
    );

void main() {
  group('NotificationMapper', () {
    test('a new message becomes a notification titled by its chat', () {
      final mapped = NotificationMapper.map(
        _notification(
          td.NotificationTypeNewMessage(
            message: TdFixtures.chatMessage(
              id: 1,
              chatId: -100500,
              senderUserId: 9,
              text: 'are you around?',
            ),
            showPreview: true,
          ),
        ),
        groupId: 3,
        chatId: -100500,
        chatTitle: 'Flutter Devs',
      );

      expect(mapped, isNotNull);
      // The chat, not the sender: in a group the chat is what the reader
      // recognises, and the sender is named in the body instead.
      expect(mapped!.title, 'Flutter Devs');
      expect(mapped.body, 'are you around?');
      expect(mapped.route, '/chat/-100500');
      // TDLib's own id, so a removal it announces cancels exactly the one it
      // means.
      expect(mapped.id, 7);
    });

    // Every notification used to open a chat screen, so a channel's new post
    // opened the channel as a conversation with a composer under it.
    test('a channel post opens the post, not a chat', () {
      final mapped = NotificationMapper.map(
        _notification(
          td.NotificationTypeNewMessage(
            message: TdFixtures.chatMessage(
              id: 5 << 20,
              chatId: -100700,
              senderUserId: 9,
            ),
            showPreview: true,
          ),
        ),
        groupId: 4,
        chatId: -100700,
        chatTitle: 'News',
        isChannelPost: true,
      );

      expect(mapped!.route, '/post/-100700_${5 << 20}');
    });

    // Your own message arriving on this device is not news. Telegram sends the
    // group anyway so every client can keep its counts in step.
    test('an outgoing message is not a notification', () {
      final mapped = NotificationMapper.map(
        _notification(
          td.NotificationTypeNewMessage(
            message: TdFixtures.chatMessage(
              id: 1,
              chatId: -100500,
              senderUserId: 1,
              isOutgoing: true,
            ),
            showPreview: true,
          ),
        ),
        groupId: 3,
        chatId: -100500,
        chatTitle: 'Flutter Devs',
      );

      expect(mapped, isNull);
    });

    // A tap that goes nowhere is worse than no notification, and gramX cannot
    // open a call or a secret chat.
    test('a call is not something gramX can open, so it is not shown', () {
      final mapped = NotificationMapper.map(
        _notification(const td.NotificationTypeNewCall(callId: 1)),
        groupId: 3,
        chatId: -100500,
        chatTitle: 'Ada',
      );

      expect(mapped, isNull);
    });

    test('silence is carried through', () {
      final mapped = NotificationMapper.map(
        _notification(
          td.NotificationTypeNewMessage(
            message: TdFixtures.chatMessage(
              id: 1,
              chatId: -1,
              senderUserId: 9,
            ),
            showPreview: true,
          ),
          silent: true,
        ),
        groupId: 3,
        chatId: -1,
        chatTitle: 'Quiet group',
      );

      expect(mapped!.isSilent, isTrue);
    });
  });

  group('NotificationMapper.bodyOfMessage', () {
    test('text is its own words, on one line', () {
      expect(
        NotificationMapper.bodyOfMessage(
          TdFixtures.chatMessage(
            id: 1,
            chatId: -1,
            senderUserId: 2,
            text: 'first\n\nsecond',
          ),
        ),
        'first second',
      );
    });

    test('a photo with no caption still says what arrived', () {
      final body = NotificationMapper.bodyOfMessage(
        TdFixtures.photoMessage(id: 1, chatId: -1, fileIds: [9]),
      );

      expect(body, isNotEmpty);
      expect(body.toLowerCase(), contains('photo'));
    });

    test('a caption beats the content type', () {
      expect(
        NotificationMapper.bodyOfMessage(
          TdFixtures.photoMessage(
            id: 1,
            chatId: -1,
            fileIds: [9],
            caption: 'the view from here',
          ),
        ),
        'the view from here',
      );
    });
  });

  group('NotificationMapper.bodyOfPush', () {
    test('push text comes through as itself', () {
      expect(
        NotificationMapper.bodyOfPush(
          const td.PushMessageContentText(text: 'hello', isPinned: false),
        ),
        'hello',
      );
    });

    // The reader turned previews off in Telegram. Filling the gap in would
    // undo a setting they chose on another device.
    test('a hidden push stays hidden', () {
      final body = NotificationMapper.bodyOfPush(
        const td.PushMessageContentHidden(isPinned: false),
      );

      expect(body, 'New message');
    });

    test('a captioned photo push prefers the caption', () {
      expect(
        NotificationMapper.bodyOfPush(
          const td.PushMessageContentPhoto(
            photo: null,
            caption: 'look',
            isSecret: false,
            isPinned: false,
          ),
        ),
        'look',
      );
    });
  });

  // Turning notifications on is also what asks the OS for permission, and a
  // permission dialog nobody asked for is the one every reader declines —
  // after which the app has to send them to their system settings to undo it.
  group('the setting', () {
    test('defaults off', () {
      expect(const AppSettings().notificationsEnabled, isFalse);
    });

    test('survives a round trip', () {
      final settings = const AppSettings().copyWith(
        notificationsEnabled: true,
      );

      expect(
        AppSettings.fromJson(settings.toJson()).notificationsEnabled,
        isTrue,
      );
    });

    // A settings file written by an older build has no such key.
    test('an older settings file reads as off, not as a crash', () {
      expect(
        AppSettings.fromJson(const {'guestMode': false}).notificationsEnabled,
        isFalse,
      );
    });
  });
}
