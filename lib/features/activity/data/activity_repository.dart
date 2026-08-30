import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/activity/domain/activity_item.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Which chats are worth asking about, and how many requests that costs.
///
/// **This is the whole budget argument for the Activity screen.** A list of
/// everything that has happened to you is the shape `docs/TDLIB.md` forbids —
/// a request per chat, over the whole chat list — unless something already
/// knows which chats have anything in them. Something does: TDLib pushes
/// `updateChatUnreadMentionCount` and `updateChatUnreadReactionCount` on the
/// update stream for free, and `ChatCache` folds both into [ChatSummary].
///
/// So the plan is: ask only chats whose count is non-zero, which for an
/// ordinary account is nought to three, and cap it anyway.
abstract class ActivityPlan {
  /// The most chats one refresh will ask about.
  ///
  /// A cap rather than a trust: an account that has been away for a month, or
  /// one in fifty busy groups, should cost the same as any other. Twelve chats
  /// is at most 24 requests, spread over the screen being opened by hand.
  static const int maxChats = 12;

  /// How many messages are read back per question.
  ///
  /// The screen shows the most recent few of anything; a hundred mentions in
  /// one group is a group to open, not a hundred rows to scroll.
  static const int perChatLimit = 10;

  /// What to ask, newest chat first.
  ///
  /// Sorted by the chat's own recency so the cap, when it bites, keeps the
  /// chats the reader is most likely to care about.
  static List<ActivityQuery> queriesFor(List<ChatSummary> chats) {
    final candidates = [
      for (final chat in chats)
        if (chat.unreadMentionCount > 0 || chat.unreadReactionCount > 0)
          ActivityQuery(
            chatId: chat.chatId,
            wantsMentions: chat.unreadMentionCount > 0,
            wantsReactions: chat.unreadReactionCount > 0,
          ),
    ];

    final byRecency = {for (final c in chats) c.chatId: c.lastMessageAt};
    candidates.sort((a, b) {
      final left = byRecency[a.chatId];
      final right = byRecency[b.chatId];
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });

    return candidates.take(maxChats).toList();
  }

  /// The number on the bell.
  ///
  /// Free — every term is already in the cache. Mentions and reactions are
  /// summed because the bell says "how many things happened", and the reader
  /// does not sort them by kind before deciding whether to look.
  static int badgeCount(List<ChatSummary> chats) {
    var total = 0;
    for (final chat in chats) {
      total += chat.unreadMentionCount + chat.unreadReactionCount;
    }
    return total;
  }
}

/// Builds the Activity list.
class ActivityRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  ActivityRepository(this._tdlib, this._chatCache);

  /// Everything that has happened, newest first.
  ///
  /// One `SearchChatMessages` per question in the plan, and the plan only ever
  /// names chats the update stream has already said have something in them.
  /// Driven by the screen being opened, never on a timer — see
  /// [ActivityPlan].
  Future<List<ActivityItem>> load(List<ChatSummary> chats) async {
    final items = <ActivityItem>[];

    for (final query in ActivityPlan.queriesFor(chats)) {
      if (query.wantsMentions) {
        items.addAll(
          await _search(
            query.chatId,
            const td.SearchMessagesFilterUnreadMention(),
          ),
        );
      }
      if (query.wantsReactions) {
        items.addAll(
          await _search(
            query.chatId,
            const td.SearchMessagesFilterUnreadReaction(),
          ),
        );
      }
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  Future<List<ActivityItem>> _search(
    int chatId,
    td.SearchMessagesFilter filter,
  ) async {
    try {
      final res = await _tdlib.sendRequest(
        td.SearchChatMessages(
          chatId: chatId,
          query: '',
          fromMessageId: 0,
          offset: 0,
          limit: ActivityPlan.perChatLimit,
          filter: filter,
          // The whole chat, not one thread and not a saved-messages topic —
          // both of those narrow the search to somewhere the reader did not
          // ask about.
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );
      if (res is! td.FoundChatMessages) return const [];

      final chat = _chatCache.chat(chatId);
      return [
        for (final message in res.messages)
          itemFor(
            message,
            chatTitle: chat?.title ?? '',
            isChannelPost: chat?.type is td.ChatTypeSupergroup &&
                (chat?.type as td.ChatTypeSupergroup?)?.isChannel == true,
            sender: _senderOf(message),
            isReaction: filter is td.SearchMessagesFilterUnreadReaction,
          ),
      ];
    } catch (e) {
      // One chat failing is one chat missing from the list, not an empty
      // screen. A flood wait here is exactly the case that must degrade.
      debugPrint('[Activity] search in $chatId failed: $e');
      return const [];
    }
  }

  /// Who sent a message, read only from what the cache already holds.
  ///
  /// Never a request: a lookup per row of a list is the fan-out
  /// `docs/TDLIB.md` forbids, and this is a list. A sender the cache does not
  /// know simply has no name, and the row says where it happened instead.
  ({String name, int? avatarFileId, int seed})? _senderOf(td.Message message) {
    final sender = message.senderId;
    if (sender is td.MessageSenderUser) {
      final user = _chatCache.user(sender.userId);
      if (user == null) return null;
      return (
        name: TdlibMappers.userDisplayName(user),
        avatarFileId: user.profilePhoto?.small.id,
        seed: sender.userId,
      );
    }
    if (sender is td.MessageSenderChat) {
      final chat = _chatCache.chat(sender.chatId);
      if (chat == null) return null;
      return (
        name: chat.title,
        avatarFileId: chat.photo?.small.id,
        seed: sender.chatId,
      );
    }
    return null;
  }

  /// One message as one row.
  ///
  /// Pure, and the part worth testing: which kind a message counts as, and
  /// what a row says when the message has no text of its own.
  @visibleForTesting
  static ActivityItem itemFor(
    td.Message message, {
    required String chatTitle,
    required bool isChannelPost,
    required bool isReaction,
    ({String name, int? avatarFileId, int seed})? sender,
  }) {
    // A reply to something you sent is a different event from a mention of
    // you, and Telegram carries both on the same message — the reply pointer
    // is what tells them apart, and it is the more specific of the two.
    final kind = isReaction
        ? ActivityKind.reaction
        : (message.replyTo != null ? ActivityKind.reply : ActivityKind.mention);

    return ActivityItem(
      kind: kind,
      chatId: message.chatId,
      messageId: message.id,
      chatTitle: chatTitle,
      isChannelPost: isChannelPost,
      senderName: sender?.name,
      senderAvatarFileId: sender?.avatarFileId,
      senderColorSeed: sender?.seed ?? message.chatId,
      preview: previewOf(message),
      emoji: isReaction ? newestReactionOn(message) : null,
      at: DateTime.fromMillisecondsSinceEpoch(message.date * 1000),
    );
  }

  /// One line of what the message says.
  ///
  /// A message with no text is not an empty row — a photo somebody tagged you
  /// under still happened. The content type stands in for the words.
  @visibleForTesting
  static String previewOf(td.Message message) {
    final content = message.content;
    final text = switch (content) {
      td.MessageText() => content.text.text,
      td.MessagePhoto() => content.caption.text,
      td.MessageVideo() => content.caption.text,
      td.MessageAnimation() => content.caption.text,
      td.MessageDocument() => content.caption.text,
      td.MessageAudio() => content.caption.text,
      td.MessageVoiceNote() => content.caption.text,
      _ => '',
    };

    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isNotEmpty) return trimmed;

    return switch (content) {
      td.MessagePhoto() => '📷',
      td.MessageVideo() => '🎬',
      td.MessageAnimation() => 'GIF',
      td.MessageDocument() => '📎',
      td.MessageAudio() => '🎵',
      td.MessageVoiceNote() => '🎤',
      td.MessageSticker() => content.sticker.emoji,
      td.MessagePoll() => content.poll.question.text,
      _ => '',
    };
  }

  /// The reaction to show, when a message carries several.
  ///
  /// Telegram lists *unread* reactions on the message itself, newest last —
  /// so the last of them is the one that just happened, which is the one the
  /// row is about.
  @visibleForTesting
  static String? newestReactionOn(td.Message message) {
    final unread = message.unreadReactions;
    if (unread.isEmpty) return null;
    final type = unread.last.type;
    return type is td.ReactionTypeEmoji ? type.emoji : null;
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});
