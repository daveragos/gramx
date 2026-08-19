import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';


sealed class LivePostUpdate {}

class LiveReactionsUpdate extends LivePostUpdate {
  final String postId;
  final Map<String, int> reactions;
  final Set<String> chosenReactions;
  LiveReactionsUpdate(this.postId, this.reactions, this.chosenReactions);
}

/// A message that just arrived in a chat we follow.
///
/// Previously `UpdateNewMessage` only triggered a media download and the
/// message itself was dropped, so a feed left open never gained a post.
class LiveNewMessage extends LivePostUpdate {
  final td.Message message;
  LiveNewMessage(this.message);
}

class LiveInteractionUpdate extends LivePostUpdate {
  final String postId;
  final int? viewCount;
  final int? forwardCount;
  LiveInteractionUpdate(this.postId, {this.viewCount, this.forwardCount});
}

class SyncService {
  final AppDatabase _db;
  final TdlibService _tdlib;
  StreamSubscription? _updateSub;
  final _liveUpdateController = StreamController<LivePostUpdate>.broadcast();

  Stream<LivePostUpdate> get livePostUpdates => _liveUpdateController.stream;
  
  final Completer<void> _authReady = Completer<void>();

  SyncService(this._db, this._tdlib);

  /// Must be called by the auth controller when authentication is complete.
  void markAuthReady() {
    if (!_authReady.isCompleted) {
      _authReady.complete();
    }
  }

  /// Wait for authentication to be ready.
  Future<void> waitForAuth() => _authReady.future;

  /// Start listening to real-time Telegram updates.
  void startListening() {
    _updateSub?.cancel();
    _updateSub = _tdlib.updatesStream.listen((update) {
      _handleLiveUpdate(update);
    });
  }

  /// Stop listening to updates.
  void stopListening() {
    _updateSub?.cancel();
    _updateSub = null;
  }

  /// Trigger initial sync by loading chats.
  Future<void> triggerInitialSync() async {
    await waitForAuth();
    try {
      await _tdlib.sendRequest(const td.LoadChats(
        chatList: td.ChatListMain(),
        limit: 100,
      ));
    } catch (e) {
      debugPrint('[Sync] LoadChats note: $e');
    }
  }

  /// Queue background file download in TDLib.
  Future<void> _downloadFile(int fileId, {int priority = 1}) async {
    if (fileId == 0) return;
    try {
      await _tdlib.sendRequest(td.DownloadFile(
        fileId: fileId,
        priority: priority,
        offset: 0,
        limit: 0,
        synchronous: false,
      ));
    } catch (e) {
      debugPrint('[Sync] DownloadFile failed for fileId $fileId: $e');
    }
  }

  /// Download a file with viewport-aware priority.
  /// Use priority 32 for visible/viewport media, 1 for background prefetch.
  Future<void> downloadFileWithPriority(int fileId, {int priority = 32}) async {
    await _downloadFile(fileId, priority: priority);
  }

  /// Download small chat photo if available.
  Future<void> downloadChatAvatar(td.Chat chat) async {
    if (chat.photo != null) {
      await _downloadFile(chat.photo!.small.id);
    }
  }

  /// Download photo thumbnails for message previews (heavy media/files are downloaded on-demand).
  void _downloadMessageMedia(td.Message message) {
    final content = message.content;
    if (content is td.MessagePhoto) {
      for (final size in content.photo.sizes) {
        _downloadFile(size.photo.id);
      }
    } else if (content is td.MessageVideo && content.video.thumbnail != null) {
      _downloadFile(content.video.thumbnail!.file.id);
    } else if (content is td.MessageAnimation && content.animation.thumbnail != null) {
      _downloadFile(content.animation.thumbnail!.file.id);
    } else if (content is td.MessageText && content.linkPreview != null) {
      final lp = content.linkPreview!;
      final previewType = lp.type;
      if (previewType is td.LinkPreviewTypePhoto) {
        for (final size in previewType.photo.sizes) {
          _downloadFile(size.photo.id);
        }
      } else if (previewType is td.LinkPreviewTypeArticle && previewType.photo != null) {
        for (final size in previewType.photo!.sizes) {
          _downloadFile(size.photo.id);
        }
      }
    }
  }

  /// Handles real-time updates from TDLib update streams.
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
        
        await (_db.update(_db.accounts)
              ..where((a) => a.avatarPath.equals(fileIdStr) | a.avatarPath.equals(remoteId)))
            .write(AccountsCompanion(avatarPath: Value(localPath)));
      }
    } else if (update is td.UpdateMessageReactions) {
      final chatId = update.chatId;
      final messageId = update.messageId;
      final compositeId = '${chatId}_$messageId';

      final reactionsMap = <String, int>{};
      final chosenSet = <String>{};

      for (final r in update.reactions) {
        final emoji = r.type is td.ReactionTypeEmoji ? (r.type as td.ReactionTypeEmoji).emoji : '';
        if (emoji.isNotEmpty) {
          reactionsMap[emoji] = r.totalCount;
          if (r.isChosen) {
            chosenSet.add(emoji);
          }
        }
      }

      _liveUpdateController.add(LiveReactionsUpdate(compositeId, reactionsMap, chosenSet));
    } else if (update is td.UpdateMessageInteractionInfo) {
      final chatId = update.chatId;
      final messageId = update.messageId;
      final compositeId = '${chatId}_$messageId';
      final info = update.interactionInfo;

      if (info != null) {
        _liveUpdateController.add(LiveInteractionUpdate(
          compositeId,
          viewCount: info.viewCount,
          forwardCount: info.forwardCount,
        ));
      }
    }
  }

  /// Toggle post reaction (like) via TDLib
  Future<void> togglePostReaction({
    required int chatId,
    required int messageId,
    required String reactionEmoji,
    required bool isCurrentlyLiked,
  }) async {
    try {
      if (isCurrentlyLiked) {
        await _tdlib.sendRequest(td.RemoveMessageReaction(
          chatId: chatId,
          messageId: messageId,
          reactionType: td.ReactionTypeEmoji(emoji: reactionEmoji),
        ));
      } else {
        await _tdlib.sendRequest(td.AddMessageReaction(
          chatId: chatId,
          messageId: messageId,
          reactionType: td.ReactionTypeEmoji(emoji: reactionEmoji),
          isBig: false,
          updateRecentReactions: true,
        ));
      }
    } catch (e) {
      debugPrint('[Sync] Failed to toggle post reaction: $e');
    }
  }

  /// Toggle bookmark status in local database
  Future<void> toggleBookmark(int chatId, int messageId) async {
    final existing = await (_db.select(_db.bookmarkEntries)
          ..where((b) => b.chatId.equals(chatId) & b.messageId.equals(messageId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.delete(_db.bookmarkEntries)
            ..where((b) => b.chatId.equals(chatId) & b.messageId.equals(messageId)))
          .go();
    } else {
      final accounts = await (_db.select(_db.accounts)..where((a) => a.isActive.equals(true))).get();
      final accountId = accounts.isNotEmpty ? accounts.first.id : 1;
      
      await _db.into(_db.bookmarkEntries).insert(BookmarkEntriesCompanion.insert(
        accountId: accountId,
        chatId: chatId,
        messageId: messageId,
      ));
    }
  }

  /// Set poll answers (vote) in TDLib.
  Future<void> voteInPoll({
    required int chatId,
    required int messageId,
    required List<int> optionIds,
  }) async {
    try {
      await _tdlib.sendRequest(td.SetPollAnswer(
        chatId: chatId,
        messageId: messageId,
        optionIds: optionIds,
      ));
    } catch (e) {
      debugPrint('[Sync] Failed to vote in poll: $e');
      rethrow;
    }
  }
}

/// Riverpod provider for SyncService.
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final tdlib = ref.watch(tdlibServiceProvider);
  return SyncService(db, tdlib);
});
