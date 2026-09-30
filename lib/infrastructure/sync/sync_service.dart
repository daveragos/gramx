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

  /// Reaction counts as TDLib now sees them, or null if the update carried no
  /// interaction info to speak for them.
  ///
  /// An *empty* map is meaningful and different from null: it says the post has
  /// no reactions, which is how the last one being taken back arrives.
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

/// Turns a counter-bearing TDLib update into the event the feed folds in.
///
/// Pure and top-level so it can be tested without standing up a client, a
/// database and a subscription — the seam the tests
/// need. Returns null for updates that carry no
/// counters.
///
/// The reaction path is the whole reason this exists. `updateMessageReactions`
/// is documented **"for bots only"**, so on a user client it never fires — the
/// only place a reader is ever told about a reaction is
/// `updateMessageInteractionInfo.interactionInfo.reactions`, and that field
/// used to be read past and dropped. Everything downstream was already wired up
/// and waiting for it.
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
    // Bots-only, so unreachable for this app. Kept because handling it costs
    // nothing and a future TDLib could widen it.
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

  /// Whether photos may be prefetched as messages arrive.
  ///
  /// A getter rather than a value: the reader can flip the setting mid-session
  /// and this service outlives that — it owns the update subscription, so
  /// rebuilding it to pick up a preference would drop the stream.
  final bool Function() _autoDownloadImages;

  SyncService(this._db, this._tdlib, {bool Function()? autoDownloadImages})
    : _autoDownloadImages = autoDownloadImages ?? (() => true);

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

  /// Queue background file download in TDLib.
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
      // Off means off at the source: with auto-download disabled, a photo
      // costs nothing until it is tapped. The minithumbnail travels inside the
      // message itself, so the card still shows something.
      if (!_autoDownloadImages()) return;
      for (final size in content.photo.sizes) {
        _downloadFile(size.photo.id);
      }
    } else if (content is td.MessageVideo && content.video.thumbnail != null) {
      _downloadFile(content.video.thumbnail!.file.id);
    } else if (content is td.MessageVideoNote &&
        content.videoNote.thumbnail != null) {
      // Queued now that round video messages are drawn rather than labelled;
      // without this the tile has nothing to show until it is tapped.
      _downloadFile(content.videoNote.thumbnail!.file.id);
    } else if (content is td.MessageAnimation &&
        content.animation.thumbnail != null) {
      _downloadFile(content.animation.thumbnail!.file.id);
    } else if (content is td.MessageSticker) {
      // Stickers were never queued, so their file never landed and the tile
      // rendered its "can't show this" fallback forever. The sticker *is* the
      // message, so it downloads in full rather than as a thumbnail.
      _downloadFile(content.sticker.sticker.id);
      final thumbnail = content.sticker.thumbnail;
      if (thumbnail != null) _downloadFile(thumbnail.file.id);
    } else if (content is td.MessageText && content.linkPreview != null) {
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

  /// Toggle post reaction (like) via TDLib
  Future<void> togglePostReaction({
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
    } catch (e) {
      debugPrint('[Sync] Failed to toggle post reaction: $e');
    }
  }

  /// Toggle bookmark status in local database
  Future<void> toggleBookmark(int chatId, int messageId) async {
    final existing =
        await (_db.select(_db.bookmarkEntries)..where(
              (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.delete(_db.bookmarkEntries)..where(
            (b) => b.chatId.equals(chatId) & b.messageId.equals(messageId),
          ))
          .go();
    } else {
      final accounts = await (_db.select(
        _db.accounts,
      )..where((a) => a.isActive.equals(true))).get();
      final accountId = accounts.isNotEmpty ? accounts.first.id : 1;

      await _db
          .into(_db.bookmarkEntries)
          .insert(
            BookmarkEntriesCompanion.insert(
              accountId: accountId,
              chatId: chatId,
              messageId: messageId,
            ),
          );
    }
  }

  /// Set poll answers (vote) in TDLib.
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

/// Riverpod provider for SyncService.
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final tdlib = ref.watch(tdlibServiceProvider);
  return SyncService(
    db,
    tdlib,
    // Read, not watched: watching would rebuild the service on every toggle
    // and take its update subscription with it.
    autoDownloadImages: () =>
        ref.read(settingsProvider).autoDownloadImagesEnabled,
  );
});
