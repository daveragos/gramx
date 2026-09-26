import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

/// One notification, as the operating system will draw it.
@immutable
class AppNotification {
  /// TDLib's own id for it, reused as the OS notification id so a removal
  /// TDLib announces can cancel exactly the one it means.
  final int id;

  /// The group it belongs to — one chat, one group. Carried so a chat that
  /// goes quiet can have all of its notifications taken down together.
  final int groupId;

  final int chatId;
  final int messageId;

  /// Who is speaking, or where. This is the notification's title.
  final String title;

  /// What they said, already reduced to a line.
  final String body;

  /// Telegram's own "do not make a sound" flag for this one.
  final bool isSilent;

  /// Whether this is a post in a broadcast channel rather than a message in a
  /// conversation. The two open in different places.
  final bool isChannelPost;

  final DateTime at;

  const AppNotification({
    required this.id,
    required this.groupId,
    required this.chatId,
    required this.messageId,
    required this.title,
    required this.body,
    required this.at,
    this.isSilent = false,
    this.isChannelPost = false,
  });

  /// What tapping it opens: the post itself for a channel, where a chat
  /// screen would put a composer under somebody else's broadcast, and the
  /// conversation for everything else.
  String get route =>
      isChannelPost ? '/post/${chatId}_$messageId' : '/chat/$chatId';

  @override
  bool operator ==(Object other) => other is AppNotification && other.id == id;

  @override
  int get hashCode => id;
}

/// Turns TDLib's notification objects into ones the OS can draw.
///
/// Pure, and deliberately so: **what** is worth notifying about is TDLib's
/// decision, not this app's — it already applies the reader's per-chat mute
/// settings, their scope settings, and the notifications another device has
/// already dismissed. Second-guessing any of that here would produce an app
/// that buzzes for chats the reader silenced on their phone.
///
/// What is left is presentation, which is what this does.
abstract class NotificationMapper {
  /// A notification, or null when there is nothing worth drawing.
  ///
  /// Outgoing messages answer null: your own message arriving on this device
  /// is not news, and Telegram sends the notification group anyway so that
  /// every client can keep its counts in step.
  static AppNotification? map(
    td.Notification notification, {
    required int groupId,
    required int chatId,
    required String chatTitle,
    bool isChannelPost = false,
  }) {
    final type = notification.type;

    return switch (type) {
      td.NotificationTypeNewMessage() => _fromMessage(
        notification,
        type,
        groupId: groupId,
        chatId: chatId,
        chatTitle: chatTitle,
        isChannelPost: isChannelPost,
      ),
      td.NotificationTypeNewPushMessage() => _fromPush(
        notification,
        type,
        groupId: groupId,
        chatId: chatId,
        chatTitle: chatTitle,
        isChannelPost: isChannelPost,
      ),
      // A call and a new secret chat are both things gramX cannot open. A
      // notification whose tap goes nowhere is worse than no notification.
      _ => null,
    };
  }

  static AppNotification? _fromMessage(
    td.Notification notification,
    td.NotificationTypeNewMessage type, {
    required int groupId,
    required int chatId,
    required String chatTitle,
    bool isChannelPost = false,
  }) {
    final message = type.message;
    if (message.isOutgoing) return null;

    return AppNotification(
      id: notification.id,
      groupId: groupId,
      chatId: chatId,
      messageId: message.id,
      // The chat's name, not the sender's: in a group the chat is what the
      // reader recognises, and the sender is named in the body instead — which
      // is what every Telegram client does.
      title: chatTitle,
      body: bodyOfMessage(message),
      isSilent: notification.isSilent,
      at: DateTime.fromMillisecondsSinceEpoch(notification.date * 1000),
      isChannelPost: isChannelPost,
    );
  }

  static AppNotification? _fromPush(
    td.Notification notification,
    td.NotificationTypeNewPushMessage type, {
    required int groupId,
    required int chatId,
    required String chatTitle,
    bool isChannelPost = false,
  }) {
    if (type.isOutgoing) return null;

    final content = bodyOfPush(type.content);
    return AppNotification(
      id: notification.id,
      groupId: groupId,
      chatId: chatId,
      messageId: type.messageId,
      title: chatTitle.isEmpty ? type.senderName : chatTitle,
      body: type.senderName.isEmpty || type.senderName == chatTitle
          ? content
          : '${type.senderName}: $content',
      isSilent: notification.isSilent,
      at: DateTime.fromMillisecondsSinceEpoch(notification.date * 1000),
      isChannelPost: isChannelPost,
    );
  }

  /// One line for a message that arrived in full.
  @visibleForTesting
  static String bodyOfMessage(td.Message message) {
    final content = message.content;
    final text = switch (content) {
      td.MessageText() => content.text.text,
      td.MessagePhoto() => content.caption.text,
      td.MessageVideo() => content.caption.text,
      td.MessageAnimation() => content.caption.text,
      td.MessageDocument() => content.caption.text,
      td.MessageAudio() => content.caption.text,
      _ => '',
    };

    final trimmed = _oneLine(text);
    if (trimmed.isNotEmpty) return trimmed;

    return switch (content) {
      td.MessagePhoto() => '📷 Photo',
      td.MessageVideo() => '🎬 Video',
      td.MessageAnimation() => 'GIF',
      td.MessageDocument() => '📎 File',
      td.MessageAudio() => '🎵 Audio',
      td.MessageVoiceNote() => '🎤 Voice message',
      td.MessageSticker() => '${content.sticker.emoji} Sticker',
      td.MessagePoll() => '📊 ${_oneLine(content.poll.question.text)}',
      _ => 'New message',
    };
  }

  /// One line for a message that only arrived as a push.
  ///
  /// Telegram sends these without the message body when the reader has
  /// previews turned off, which is [td.PushMessageContentHidden] — and that is
  /// a setting to respect rather than a gap to fill in.
  @visibleForTesting
  static String bodyOfPush(td.PushMessageContent content) => switch (content) {
    td.PushMessageContentText() => _oneLine(content.text),
    td.PushMessageContentPhoto() when content.caption.isNotEmpty => _oneLine(
      content.caption,
    ),
    td.PushMessageContentPhoto() => '📷 Photo',
    td.PushMessageContentVideo() when content.caption.isNotEmpty => _oneLine(
      content.caption,
    ),
    td.PushMessageContentVideo() => '🎬 Video',
    td.PushMessageContentAnimation() => 'GIF',
    td.PushMessageContentDocument() => '📎 File',
    td.PushMessageContentAudio() => '🎵 Audio',
    td.PushMessageContentVoiceNote() => '🎤 Voice message',
    td.PushMessageContentVideoNote() => '📹 Video message',
    td.PushMessageContentSticker() => '${content.emoji} Sticker',
    td.PushMessageContentPoll() => '📊 ${_oneLine(content.question)}',
    td.PushMessageContentContact() => '👤 Contact',
    td.PushMessageContentLocation() => '📍 Location',
    // The reader turned previews off. Saying "New message" is the honest
    // rendering of a body Telegram deliberately did not send.
    td.PushMessageContentHidden() => 'New message',
    _ => 'New message',
  };

  static String _oneLine(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ');
}
