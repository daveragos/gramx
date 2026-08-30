import 'package:flutter/foundation.dart';

/// What kind of thing happened.
///
/// Telegram has all three facts and keeps them in three different places; these
/// are the names it knows them by.
enum ActivityKind {
  /// Somebody wrote your `@name`.
  mention,

  /// Somebody replied to a message you sent.
  reply,

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

  /// True when opening this should go to the post screen rather than to a
  /// conversation — a mention inside a channel's discussion thread is a post,
  /// and a mention in a group is a chat.
  final bool isChannelPost;

  /// Who did it. Null when Telegram will not say — an anonymous admin, or a
  /// reaction Telegram reports without a sender.
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

  /// Stable identity, so the same event arriving twice is one row.
  ///
  /// Keyed on the kind as well as the message: one message can be both a
  /// mention of you and a reply to you, and those are two things that
  /// happened, not one.
  String get id => '${kind.name}_${chatId}_$messageId';

  @override
  bool operator ==(Object other) => other is ActivityItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One chat's worth of questions to ask.
///
/// A chat with neither count is not asked about at all, which is the whole
/// point: the counts arrive free on the update stream, so the request is only
/// ever spent where there is known to be something to find.
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
