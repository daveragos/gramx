import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';

import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// A change to a conversation, distilled from the raw TDLib update stream.
///
/// A reader with a chat open is watching something two-sided and live, so the
/// set of updates that matter is much wider than the feed's: messages arrive,
/// get edited, get deleted, fail to send, and the other side reads them and
/// starts typing. Each of those is a distinct event here rather than a flag on
/// one, so [ConversationState] can fold them with an exhaustive switch and a
/// new one cannot be forgotten silently.
sealed class ChatEvent {
  const ChatEvent();

  /// The chat this event belongs to. Every conversation screen filters on it,
  /// so it is on the base class rather than repeated at each call site.
  int get chatId;
}

/// A message landed in a chat.
class ChatMessageArrived extends ChatEvent {
  final td.Message message;
  const ChatMessageArrived(this.message);

  @override
  int get chatId => message.chatId;
}

/// Messages were removed. TDLib deletes from the local cache and from the
/// server through the same update, distinguished by [isPermanent] — only a
/// permanent one means "this is gone for everybody".
class ChatMessagesDeleted extends ChatEvent {
  @override
  final int chatId;
  final List<int> messageIds;
  final bool isPermanent;
  const ChatMessagesDeleted(this.chatId, this.messageIds, this.isPermanent);
}

/// Telegram accepted a message this account sent, and gave it its real id.
///
/// The id changes: a queued message carries a temporary one, and every id-keyed
/// thing about the bubble — the reply target, the reaction, the delete — has to
/// move with it. Dropping [oldMessageId] leaves the optimistic bubble on screen
/// next to the real one.
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

/// A message's content changed — an edit, or media finishing its upload.
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

/// The other side read up to this message id. The only source for the read
/// tick — TDLib sends no per-message "was read" flag.
class ChatOutboxRead extends ChatEvent {
  @override
  final int chatId;
  final int lastReadOutboxMessageId;
  const ChatOutboxRead(this.chatId, this.lastReadOutboxMessageId);
}

/// Reaction counts as TDLib now sees them.
///
/// An empty map is meaningful and different from absent: it is how the last
/// reaction being taken back arrives.
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

/// Somebody in the chat started or stopped doing something — typing, recording
/// a voice note, sending a photo. [action] is null when they stopped.
class ChatActionChanged extends ChatEvent {
  @override
  final int chatId;
  final int? userId;

  /// A short phrase for what they are doing, already in the reader's words —
  /// "typing", "recording audio". Null means they stopped.
  final String? action;
  const ChatActionChanged(this.chatId, this.userId, this.action);
}

/// Turns raw TDLib updates into [ChatEvent]s.
///
/// Pure and top-level, so the whole translation is testable without a client, a
/// database or a subscription — the seam the testing rules in `docs/CONVENTIONS.md` ask
/// for. Returns null for every update a conversation does not care about, which
/// is the vast majority of them.
abstract class ChatEvents {
  static ChatEvent? map(td.TdObject update) {
    switch (update) {
      case td.UpdateNewMessage():
        return ChatMessageArrived(update.message);

      case td.UpdateDeleteMessages():
        // `fromCache` means TDLib dropped it locally to save room — the message
        // still exists for everybody, including this reader on their phone.
        // Folding it in as a deletion is how a scrollback develops holes.
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
        // Reactions reach a user client through this field and nowhere else —
        // `updateMessageReactions` is documented bots-only. See docs/TDLIB.md.
        if (info == null) {
          return ChatReactionsChanged(
            update.chatId,
            update.messageId,
            const {},
            const {},
          );
        }
        // Through TdlibMappers rather than a loop here: it is the one place
        // that flattens emoji, custom-emoji and paid reactions together, and
        // the last time two copies of this existed they disagreed and dropped
        // two of the three kinds. See docs/TDLIB.md.
        final mapped = TdlibMappers.mapReactions(info.reactions);
        return ChatReactionsChanged(
          update.chatId,
          update.messageId,
          mapped.counts,
          mapped.chosen,
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

  /// What somebody is doing, in the words the header shows.
  ///
  /// Null for `ChatActionCancel`, which is TDLib's way of saying they stopped —
  /// and for the actions that have no honest short phrase.
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
