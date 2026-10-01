import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';

import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// A change to a conversation, taken from the TDLib update stream. Sealed so
/// [ConversationState] folds events with an exhaustive switch.
sealed class ChatEvent {
  const ChatEvent();

  /// The chat this event belongs to.
  int get chatId;
}

/// A message landed in a chat.
class ChatMessageArrived extends ChatEvent {
  final td.Message message;
  const ChatMessageArrived(this.message);

  @override
  int get chatId => message.chatId;
}

/// Messages were removed. Only an [isPermanent] deletion is gone for everyone.
class ChatMessagesDeleted extends ChatEvent {
  @override
  final int chatId;
  final List<int> messageIds;
  final bool isPermanent;
  const ChatMessagesDeleted(this.chatId, this.messageIds, this.isPermanent);
}

/// Telegram accepted a sent message and gave it its real id. Anything keyed by
/// [oldMessageId] (the temporary id) must move to the new one, or the pending
/// bubble stays next to the real one.
class ChatMessageSent extends ChatEvent {
  final td.Message message;
  final int oldMessageId;
  const ChatMessageSent(this.message, this.oldMessageId);

  @override
  int get chatId => message.chatId;
}

/// Telegram refused a message. It will not retry itself.
class ChatMessageFailed extends ChatEvent {
  final td.Message message;
  final int oldMessageId;
  final String error;
  const ChatMessageFailed(this.message, this.oldMessageId, this.error);

  @override
  int get chatId => message.chatId;
}

/// A message's content changed: an edit, or media finishing its upload.
class ChatMessageContentChanged extends ChatEvent {
  @override
  final int chatId;
  final int messageId;
  final td.MessageContent content;
  const ChatMessageContentChanged(this.chatId, this.messageId, this.content);
}

/// Telegram stamped a message as edited.
class ChatMessageEdited extends ChatEvent {
  @override
  final int chatId;
  final int messageId;
  final DateTime editedAt;
  const ChatMessageEdited(this.chatId, this.messageId, this.editedAt);
}

/// The other side read up to this message id. TDLib has no per-message read
/// flag, so this drives the read tick.
class ChatOutboxRead extends ChatEvent {
  @override
  final int chatId;
  final int lastReadOutboxMessageId;
  const ChatOutboxRead(this.chatId, this.lastReadOutboxMessageId);
}

/// Current reaction counts. An empty map means the last reaction was removed.
class ChatReactionsChanged extends ChatEvent {
  @override
  final int chatId;
  final int messageId;
  final Map<String, int> reactions;
  final Set<String> chosen;
  const ChatReactionsChanged(
    this.chatId,
    this.messageId,
    this.reactions,
    this.chosen,
  );
}

/// A message was pinned or unpinned (its body is unchanged).
class ChatMessagePinChanged extends ChatEvent {
  @override
  final int chatId;
  final int messageId;
  final bool isPinned;
  const ChatMessagePinChanged(this.chatId, this.messageId, this.isPinned);
}

/// Somebody started or stopped typing, recording or sending media.
class ChatActionChanged extends ChatEvent {
  @override
  final int chatId;
  final int? userId;

  /// A short phrase such as "typing". Null means they stopped.
  final String? action;
  const ChatActionChanged(this.chatId, this.userId, this.action);
}

/// Turns raw TDLib updates into [ChatEvent]s, or null for updates a
/// conversation ignores.
abstract class ChatEvents {
  static ChatEvent? map(td.TdObject update) {
    switch (update) {
      case td.UpdateNewMessage():
        return ChatMessageArrived(update.message);

      case td.UpdateDeleteMessages():
        // `fromCache` means TDLib only evicted it locally; the message still
        // exists, so treating it as deleted would leave gaps in the history.
        if (update.fromCache) return null;
        return ChatMessagesDeleted(
          update.chatId,
          update.messageIds,
          update.isPermanent,
        );

      case td.UpdateMessageSendSucceeded():
        return ChatMessageSent(update.message, update.oldMessageId);

      case td.UpdateMessageSendFailed():
        return ChatMessageFailed(
          update.message,
          update.oldMessageId,
          update.error.message,
        );

      case td.UpdateMessageContent():
        return ChatMessageContentChanged(
          update.chatId,
          update.messageId,
          update.newContent,
        );

      case td.UpdateMessageEdited():
        return ChatMessageEdited(
          update.chatId,
          update.messageId,
          DateTime.fromMillisecondsSinceEpoch(update.editDate * 1000),
        );

      case td.UpdateChatReadOutbox():
        return ChatOutboxRead(update.chatId, update.lastReadOutboxMessageId);

      case td.UpdateMessageInteractionInfo():
        final info = update.interactionInfo;
        // User clients get reactions only through this field;
        // `updateMessageReactions` is for bots.
        if (info == null) {
          return ChatReactionsChanged(
            update.chatId,
            update.messageId,
            const {},
            const {},
          );
        }
        // Shared mapping for emoji, custom-emoji and paid reactions.
        final mapped = TdlibMappers.mapReactions(info.reactions);
        return ChatReactionsChanged(
          update.chatId,
          update.messageId,
          mapped.counts,
          mapped.chosen,
        );

      case td.UpdateMessageIsPinned():
        return ChatMessagePinChanged(
          update.chatId,
          update.messageId,
          update.isPinned,
        );

      case td.UpdateChatAction():
        final sender = update.senderId;
        return ChatActionChanged(
          update.chatId,
          sender is td.MessageSenderUser ? sender.userId : null,
          describeAction(update.action),
        );

      default:
        return null;
    }
  }

  /// What somebody is doing, as the header shows it. Null for
  /// `ChatActionCancel` (they stopped) and for actions with no short phrase.
  static String? describeAction(td.ChatAction action) => switch (action) {
    td.ChatActionTyping() => AppStrings.chatActionTyping,
    td.ChatActionRecordingVideo() => AppStrings.chatActionRecordingVideo,
    td.ChatActionUploadingVideo() => AppStrings.chatActionSendingVideo,
    td.ChatActionRecordingVoiceNote() => AppStrings.chatActionRecordingAudio,
    td.ChatActionUploadingVoiceNote() => AppStrings.chatActionSendingAudio,
    td.ChatActionUploadingPhoto() => AppStrings.chatActionSendingPhoto,
    td.ChatActionUploadingDocument() => AppStrings.chatActionSendingFile,
    td.ChatActionRecordingVideoNote() =>
      AppStrings.chatActionRecordingVideoMessage,
    td.ChatActionUploadingVideoNote() =>
      AppStrings.chatActionSendingVideoMessage,
    td.ChatActionChoosingSticker() => AppStrings.chatActionChoosingSticker,
    td.ChatActionChoosingLocation() => AppStrings.chatActionChoosingLocation,
    td.ChatActionChoosingContact() => AppStrings.chatActionChoosingContact,
    td.ChatActionWatchingAnimations() => AppStrings.chatActionWatchingAnimation,
    td.ChatActionStartPlayingGame() => AppStrings.chatActionPlayingGame,
    td.ChatActionCancel() => null,
  };
}
