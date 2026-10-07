import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

/// Whether [emoji] is a reaction that can be sent. The paid and custom emoji
/// keys stand in for reactions that aren't emoji, and sending them as emoji
/// was refused.
bool isSendableReaction(String emoji) =>
    emoji != TdlibMappers.paidReactionEmoji &&
    emoji != TdlibMappers.customReactionEmoji;

/// Reacts to posts and comments, from every reaction control.
///
/// It reacts from what is shown, shows the change at once in every view,
/// and puts back what was shown if Telegram refuses. A refused reaction used
/// to stay on screen as if it had worked.
class ReactionController extends Notifier<void> {
  @override
  void build() {}

  /// Reacts to [post] with [emoji], or takes the user's reaction back.
  /// Returns false if it couldn't, after restoring what was shown.
  Future<bool> react(Post post, String emoji) async {
    if (!isSendableReaction(emoji)) return false;

    final overrides = ref.read(optimisticPostUpdatesProvider.notifier);
    final feed = ref.read(feedPostsProvider.notifier);
    final shown = applyPostOverrides(
      post,
      ref.read(optimisticPostUpdatesProvider),
    );

    overrides.toggleReaction(post.id, emoji, shown);
    feed.toggleReactionOptimistic(post.id, emoji);

    final sent = await ref
        .read(syncServiceProvider)
        .togglePostReaction(
          chatId: post.chatId,
          messageId: post.messageId,
          reactionEmoji: emoji,
          isCurrentlyLiked: shown.chosenReactions.contains(emoji),
        );
    if (!sent) {
      overrides.setReactions(post.id, shown.reactions, shown.chosenReactions);
      feed.setReactions(post.id, shown.reactions, shown.chosenReactions);
    }
    return sent;
  }
}

final reactionControllerProvider = NotifierProvider<ReactionController, void>(
  ReactionController.new,
);
