import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;

/// One notification, as the operating system will draw it.
@immutable
class AppNotification {
  /// TDLib's id, reused as the OS notification id so removals can cancel it.
  final int id;

  /// The TDLib notification group, one per chat.
  final int groupId;

  final int chatId;
  final int messageId;

  /// The notification title, usually the chat's name.
  final String title;

  /// The message, reduced to one line.
  final String body;

  /// Telegram's flag for a notification without sound.
  final bool isSilent;

  /// Whether this is a channel post rather than a chat message.
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

  /// What a tap opens: the post for a channel, the chat otherwise.
  String get route =>
      isChannelPost ? '/post/${chatId}_$messageId' : '/chat/$chatId';

  @override
  bool operator ==(Object other) => other is AppNotification && other.id == id;

  @override
  int get hashCode => id;
}

/// Turns TDLib's notification objects into ones the OS can draw. TDLib has
/// already applied mute settings, so this does no filtering of its own.
abstract class NotificationMapper {
  /// A notification, or null when there is nothing to draw. Outgoing messages
  /// give null; Telegram sends them only to keep counts in sync.
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
      // Calls and new secret chats can't be opened in the app.
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
      // The chat's name; in a group the sender is named in the body.
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

  /// One line for a message that only arrived as a push. With previews off,
  /// Telegram sends [td.PushMessageContentHidden] and no text.
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
    td.PushMessageContentHidden() => 'New message',
    _ => 'New message',
  };

  static String _oneLine(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ');
}
