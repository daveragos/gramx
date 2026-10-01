import 'package:flutter/foundation.dart';

/// What kind of thing happened.
enum ActivityKind {
  /// Somebody wrote your `@name`.
  mention,

  /// Somebody replied to a message you sent.
  reply,

  /// Somebody reacted to a message you sent.
  reaction,
}

/// One thing that happened while you were away.
@immutable
class ActivityItem {
  final ActivityKind kind;

  /// Where it happened, and what to open.
  final int chatId;
  final int messageId;
  final String chatTitle;

  /// Whether this opens the post screen (a channel thread) rather than a chat.
  final bool isChannelPost;

  /// Who did it. Null when unknown, such as an anonymous admin.
  final String? senderName;
  final int? senderAvatarFileId;
  final int? senderColorSeed;

  /// The words themselves, already trimmed to a line.
  final String preview;

  /// The reaction, for a [ActivityKind.reaction]. Null otherwise.
  final String? emoji;

  final DateTime at;

  const ActivityItem({
    required this.kind,
    required this.chatId,
    required this.messageId,
    required this.chatTitle,
    required this.preview,
    required this.at,
    this.isChannelPost = false,
    this.senderName,
    this.senderAvatarFileId,
    this.senderColorSeed,
    this.emoji,
  });

  /// Stable identity, so the same event arriving twice is one row. Includes
  /// the kind, since one message can produce more than one event.
  String get id => '${kind.name}_${chatId}_$messageId';

  @override
  bool operator ==(Object other) => other is ActivityItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The searches to run in one chat, from its unread counts.
@immutable
class ActivityQuery {
  final int chatId;
  final bool wantsMentions;
  final bool wantsReactions;

  const ActivityQuery({
    required this.chatId,
    this.wantsMentions = false,
    this.wantsReactions = false,
  });

  /// How many requests this costs.
  int get requestCount => (wantsMentions ? 1 : 0) + (wantsReactions ? 1 : 0);

  @override
  bool operator ==(Object other) =>
      other is ActivityQuery &&
      other.chatId == chatId &&
      other.wantsMentions == wantsMentions &&
      other.wantsReactions == wantsReactions;

  @override
  int get hashCode => Object.hash(chatId, wantsMentions, wantsReactions);

  @override
  String toString() =>
      'ActivityQuery($chatId, mentions: $wantsMentions, '
      'reactions: $wantsReactions)';
}
