import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/activity/domain/activity_item.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Which chats Activity searches: only those with unread mentions or
/// reactions (counts TDLib pushes for free), up to a cap.
abstract class ActivityPlan {
  /// The most chats one refresh searches (at most 24 requests).
  static const int maxChats = 12;

  /// The fewest messages each search asks for.
  static const int perChatLimit = 10;

  /// How many to ask a chat for: all [unread], so the list can show every
  /// one before they are cleared, up to what one search returns.
  static int limitFor(int unread) => unread.clamp(perChatLimit, 100);

  /// What to search, newest chat first so the cap keeps recent chats.
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

  /// The number on the bell: unread mentions plus reactions, from the cache.
  static int badgeCount(List<ChatSummary> chats) {
    var total = 0;
    for (final chat in chats) {
      total += chat.unreadMentionCount + chat.unreadReactionCount;
    }
    return total;
  }
}

/// One Activity load: the items, and the chats whose unread mentions or
/// reactions it listed in full. Only those may be cleared; a chat with more
/// than one search returns, or whose search failed, keeps its count.
@immutable
class ActivityLoad {
  final List<ActivityItem> items;
  final Set<int> mentionsListed;
  final Set<int> reactionsListed;

  const ActivityLoad({
    required this.items,
    this.mentionsListed = const {},
    this.reactionsListed = const {},
  });
}

/// Builds the Activity list.
class ActivityRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  ActivityRepository(this._tdlib, this._chatCache);

  /// Unread mentions, replies and reactions, newest first. One
  /// `SearchChatMessages` per [ActivityPlan] query, run when the screen opens.
  Future<ActivityLoad> load(List<ChatSummary> chats) async {
    final items = <ActivityItem>[];
    final mentionsListed = <int>{};
    final reactionsListed = <int>{};
    final byId = {for (final chat in chats) chat.chatId: chat};

    for (final query in ActivityPlan.queriesFor(chats)) {
      final chat = byId[query.chatId]!;
      if (query.wantsMentions) {
        final found = await _search(
          query.chatId,
          const td.SearchMessagesFilterUnreadMention(),
          limit: ActivityPlan.limitFor(chat.unreadMentionCount),
        );
        if (found != null) {
          items.addAll(found);
          if (found.length >= chat.unreadMentionCount) {
            mentionsListed.add(query.chatId);
          }
        }
      }
      if (query.wantsReactions) {
        final found = await _search(
          query.chatId,
          const td.SearchMessagesFilterUnreadReaction(),
          limit: ActivityPlan.limitFor(chat.unreadReactionCount),
        );
        if (found != null) {
          items.addAll(found);
          if (found.length >= chat.unreadReactionCount) {
            reactionsListed.add(query.chatId);
          }
        }
      }
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return ActivityLoad(
      items: items,
      mentionsListed: mentionsListed,
      reactionsListed: reactionsListed,
    );
  }

  /// Clears the unread mention and reaction counts of the chats [loaded]
  /// listed in full, since Telegram otherwise clears them only when the
  /// message is viewed in its chat. It cleared every chat it searched, which
  /// lost mentions past the first ten, or from a search that failed. Each
  /// chat's read position is left alone.
  Future<void> markSeen(ActivityLoad loaded) async {
    for (final chatId in loaded.mentionsListed) {
      await _acknowledge(td.ReadAllChatMentions(chatId: chatId));
    }
    for (final chatId in loaded.reactionsListed) {
      await _acknowledge(td.ReadAllChatReactions(chatId: chatId));
    }
  }

  Future<void> _acknowledge(td.TdFunction request) async {
    try {
      await _tdlib.sendRequest(request);
    } catch (e) {
      // The chat just keeps its count on the bell.
      debugPrint('[Activity] $request failed: $e');
    }
  }

  /// One chat's unread mentions or reactions, or null if the search failed.
  Future<List<ActivityItem>?> _search(
    int chatId,
    td.SearchMessagesFilter filter, {
    required int limit,
  }) async {
    try {
      final res = await _tdlib.sendRequest(
        td.SearchChatMessages(
          chatId: chatId,
          query: '',
          fromMessageId: 0,
          offset: 0,
          limit: limit,
          filter: filter,
          // The whole chat, not one thread or saved-messages topic.
          messageThreadId: 0,
          savedMessagesTopicId: 0,
        ),
      );
      if (res is! td.FoundChatMessages) return null;

      final chat = _chatCache.chat(chatId);
      return [
        for (final message in res.messages)
          itemFor(
            message,
            chatTitle: chat?.title ?? '',
            isChannelPost:
                chat?.type is td.ChatTypeSupergroup &&
                (chat?.type as td.ChatTypeSupergroup?)?.isChannel == true,
            sender: _senderOf(message),
            isReaction: filter is td.SearchMessagesFilterUnreadReaction,
          ),
      ];
    } catch (e) {
      // A failed chat (say, a flood wait) is left out of the list, and keeps
      // its count.
      debugPrint('[Activity] search in $chatId failed: $e');
      return null;
    }
  }

  /// Who sent a message, from the cache only, to avoid a request per row. An
  /// unknown sender returns null and the row names the chat instead.
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
  @visibleForTesting
  static ActivityItem itemFor(
    td.Message message, {
    required String chatTitle,
    required bool isChannelPost,
    required bool isReaction,
    ({String name, int? avatarFileId, int seed})? sender,
  }) {
    // Telegram counts a reply to the user as an unread mention too; the reply
    // pointer tells the two apart.
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

  /// One line of the message's text, or its content type when it has none.
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

  /// The newest unread reaction on [message]. Telegram lists them newest last.
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
