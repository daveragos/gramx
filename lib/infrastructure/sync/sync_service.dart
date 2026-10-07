import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

sealed class LivePostUpdate {}

class LiveReactionsUpdate extends LivePostUpdate {
  final String postId;
  final Map<String, int> reactions;
  final Set<String> chosenReactions;
  LiveReactionsUpdate(this.postId, this.reactions, this.chosenReactions);
}

/// A message that just arrived in a followed chat.
class LiveNewMessage extends LivePostUpdate {
  final td.Message message;
  LiveNewMessage(this.message);
}

class LiveInteractionUpdate extends LivePostUpdate {
  final String postId;
  final int? viewCount;
  final int? forwardCount;

  /// Current reaction counts, or null if the update carried none. An empty
  /// map means the post has no reactions left.
  final Map<String, int>? reactions;
  final Set<String>? chosenReactions;

  LiveInteractionUpdate(
    this.postId, {
    this.viewCount,
    this.forwardCount,
    this.reactions,
    this.chosenReactions,
  });
}

/// Turns a TDLib update carrying counters into a feed event, or null.
/// `updateMessageReactions` is bots-only, so a user client learns about
/// reactions only from `updateMessageInteractionInfo.interactionInfo`.
LivePostUpdate? mapCounterUpdate(td.TdObject update) {
  if (update is td.UpdateMessageInteractionInfo) {
    final info = update.interactionInfo;
    if (info == null) return null;

    final mapped = TdlibMappers.mapReactions(info.reactions);
    return LiveInteractionUpdate(
      '${update.chatId}_${update.messageId}',
      viewCount: info.viewCount,
      forwardCount: info.forwardCount,
      reactions: mapped.counts,
      chosenReactions: mapped.chosen,
    );
  }

  if (update is td.UpdateMessageReactions) {
    // Bots-only, so not expected here, but cheap to handle.
    final mapped = TdlibMappers.mapReactionList(update.reactions);
    return LiveReactionsUpdate(
      '${update.chatId}_${update.messageId}',
      mapped.counts,
      mapped.chosen,
    );
  }

  return null;
}

class SyncService {
  final AppDatabase _db;
  final TdlibService _tdlib;
  StreamSubscription? _updateSub;
  final _liveUpdateController = StreamController<LivePostUpdate>.broadcast();

  Stream<LivePostUpdate> get livePostUpdates => _liveUpdateController.stream;

  final Completer<void> _authReady = Completer<void>();

  /// Whether photos may be prefetched as messages arrive. A function so a
  /// settings change applies without rebuilding the service.
  final bool Function() _autoDownloadImages;

  SyncService(this._db, this._tdlib, {bool Function()? autoDownloadImages})
    : _autoDownloadImages = autoDownloadImages ?? (() => true);

  /// Must be called by the auth controller when authentication is complete.
  void markAuthReady() {
    if (!_authReady.isCompleted) {
      _authReady.complete();
    }
  }

  Future<void> waitForAuth() => _authReady.future;

  void startListening() {
    _updateSub?.cancel();
    _updateSub = _tdlib.updatesStream.listen((update) {
      _handleLiveUpdate(update);
    });
  }

  void stopListening() {
    _updateSub?.cancel();
    _updateSub = null;
  }

  /// Queues a background file download in TDLib.
  Future<void> _downloadFile(int fileId, {int priority = 1}) async {
    if (fileId == 0) return;
    try {
      await _tdlib.sendRequest(
        td.DownloadFile(
          fileId: fileId,
          priority: priority,
          offset: 0,
          limit: 0,
          synchronous: false,
        ),
      );
    } catch (e) {
      debugPrint('[Sync] DownloadFile failed for fileId $fileId: $e');
    }
  }

  /// Downloads a file. Use priority 32 for visible media and 1 for
  /// background prefetch.
  Future<void> downloadFileWithPriority(int fileId, {int priority = 32}) async {
    await _downloadFile(fileId, priority: priority);
  }

  Future<void> downloadChatAvatar(td.Chat chat) async {
    if (chat.photo != null) {
      await _downloadFile(chat.photo!.small.id);
    }
  }

  /// Prefetches thumbnails for message previews.
  void _downloadMessageMedia(td.Message message) {
    final content = message.content;
    if (content is td.MessagePhoto) {
      // With auto-download off, photos wait for a tap. Only the largest size
      // is shown, so the smaller ones aren't worth the data.
      if (!_autoDownloadImages() || content.photo.sizes.isEmpty) return;
      _downloadFile(content.photo.sizes.last.photo.id);
    } else if (content is td.MessageVideo && content.video.thumbnail != null) {
      _downloadFile(content.video.thumbnail!.file.id);
    } else if (content is td.MessageVideoNote &&
        content.videoNote.thumbnail != null) {
      _downloadFile(content.videoNote.thumbnail!.file.id);
    } else if (content is td.MessageAnimation &&
        content.animation.thumbnail != null) {
      _downloadFile(content.animation.thumbnail!.file.id);
    } else if (content is td.MessageSticker) {
      // The sticker is the message, so it downloads in full.
      _downloadFile(content.sticker.sticker.id);
      final thumbnail = content.sticker.thumbnail;
      if (thumbnail != null) _downloadFile(thumbnail.file.id);
    } else if (content is td.MessageText && content.linkPreview != null) {
      if (!_autoDownloadImages()) return;
      final lp = content.linkPreview!;
      final previewType = lp.type;
      if (previewType is td.LinkPreviewTypePhoto) {
        for (final size in previewType.photo.sizes) {
          _downloadFile(size.photo.id);
        }
      } else if (previewType is td.LinkPreviewTypeArticle &&
          previewType.photo != null) {
        for (final size in previewType.photo!.sizes) {
          _downloadFile(size.photo.id);
        }
      }
    }
  }

  Future<void> _handleLiveUpdate(td.TdObject update) async {
    if (!_authReady.isCompleted) return;

    if (update is td.UpdateNewMessage) {
      _downloadMessageMedia(update.message);
      _liveUpdateController.add(LiveNewMessage(update.message));
    } else if (update is td.UpdateFile) {
      final file = update.file;
      if (file.local.isDownloadingCompleted && file.local.path.isNotEmpty) {
        final localPath = file.local.path;
        final fileIdStr = file.id.toString();
        final remoteId = file.remote.id;

        await (_db.update(_db.accounts)..where(
              (a) =>
                  a.avatarPath.equals(fileIdStr) |
                  a.avatarPath.equals(remoteId),
            ))
            .write(AccountsCompanion(avatarPath: Value(localPath)));
      }
    } else {
      final counterUpdate = mapCounterUpdate(update);
      if (counterUpdate != null) _liveUpdateController.add(counterUpdate);
    }
  }

  /// Adds or removes a reaction on a post.
  /// Adds or removes a reaction. Returns false if Telegram refused it.
  Future<bool> togglePostReaction({
    required int chatId,
    required int messageId,
    required String reactionEmoji,
    required bool isCurrentlyLiked,
  }) async {
    try {
      if (isCurrentlyLiked) {
        await _tdlib.sendRequest(
          td.RemoveMessageReaction(
            chatId: chatId,
            messageId: messageId,
            reactionType: td.ReactionTypeEmoji(emoji: reactionEmoji),
          ),
        );
      } else {
        await _tdlib.sendRequest(
          td.AddMessageReaction(
            chatId: chatId,
            messageId: messageId,
            reactionType: td.ReactionTypeEmoji(emoji: reactionEmoji),
            isBig: false,
            updateRecentReactions: true,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('[Sync] Failed to toggle post reaction: $e');
      return false;
    }
  }

  /// Votes in a poll.
  Future<void> voteInPoll({
    required int chatId,
    required int messageId,
    required List<int> optionIds,
  }) async {
    try {
      await _tdlib.sendRequest(
        td.SetPollAnswer(
          chatId: chatId,
          messageId: messageId,
          optionIds: optionIds,
        ),
      );
    } catch (e) {
      debugPrint('[Sync] Failed to vote in poll: $e');
      rethrow;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final tdlib = ref.watch(tdlibServiceProvider);
  return SyncService(
    db,
    tdlib,
    // Read, not watched, so a toggle doesn't rebuild the service and drop
    // its update subscription.
    autoDownloadImages: () =>
        ref.read(settingsProvider).autoDownloadImagesEnabled,
  );
});
