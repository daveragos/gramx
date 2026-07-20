import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/database/database.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

class SyncService {
  final AppDatabase _db;
  final TdlibService _tdlib;
  StreamSubscription? _updateSub;
  List<td.ChatFolderInfo>? _cachedFolders;

  final isSyncingNotifier = ValueNotifier<bool>(false);

  SyncService(this._db, this._tdlib);

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

  /// Get or create the local default account database record.
  Future<int> _getOrCreateActiveAccountId() async {
    final accounts = await (_db.select(_db.accounts)..where((a) => a.isActive.equals(true))).get();
    if (accounts.isNotEmpty) {
      return accounts.first.id;
    }
    throw StateError('No active authenticated account found.');
  }

  /// Queue background file download in TDLib.
  Future<void> _downloadFile(int fileId) async {
    if (fileId == 0) return;
    try {
      await _tdlib.sendRequest(td.DownloadFile(
        fileId: fileId,
        priority: 1,
        offset: 0,
        limit: 0,
        synchronous: false,
      ));
    } catch (e) {
      debugPrint('[Sync] DownloadFile failed for fileId $fileId: $e');
    }
  }

  /// Automatically download avatars and media for a message.
  void _downloadMessageMedia(td.Message message) {
    final content = message.content;
    if (content is td.MessagePhoto) {
      for (final size in content.photo.sizes) {
        _downloadFile(size.photo.id);
      }
    } else if (content is td.MessageVideo) {
      _downloadFile(content.video.video.id);
      if (content.video.thumbnail != null) {
        _downloadFile(content.video.thumbnail!.file.id);
      }
    } else if (content is td.MessageAnimation) {
      _downloadFile(content.animation.animation.id);
      if (content.animation.thumbnail != null) {
        _downloadFile(content.animation.thumbnail!.file.id);
      }
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
      } else if (previewType is td.LinkPreviewTypeApp) {
        for (final size in previewType.photo.sizes) {
          _downloadFile(size.photo.id);
        }
      } else if (previewType is td.LinkPreviewTypeVideo && previewType.video.thumbnail != null) {
        _downloadFile(previewType.video.thumbnail!.file.id);
      } else if (previewType is td.LinkPreviewTypeAnimation && previewType.animation.thumbnail != null) {
        _downloadFile(previewType.animation.thumbnail!.file.id);
      } else if (previewType is td.LinkPreviewTypeDocument && previewType.document.thumbnail != null) {
        _downloadFile(previewType.document.thumbnail!.file.id);
      }
    }
  }

  /// Syncs all subscribed broadcast channels from Telegram (with full pagination).
  Future<void> syncSubscribedChannels() async {
    isSyncingNotifier.value = true;
    try {
      final accountId = await _getOrCreateActiveAccountId();
      debugPrint('[Sync] Syncing subscribed channels...');

      // 1. Paginate LoadChats & GetChats to discover ALL user channels
      bool hasMore = true;
      int pageCount = 0;
      while (hasMore && pageCount < 10) {
        pageCount++;
        try {
          await _tdlib.sendRequest(const td.LoadChats(
            chatList: td.ChatListMain(),
            limit: 100,
          ));
        } catch (e) {
          debugPrint('[Sync] LoadChats note: $e');
        }

        final chatsObject = await _tdlib.sendRequest(const td.GetChats(
          chatList: td.ChatListMain(),
          limit: 100,
        ));

        if (chatsObject is td.Chats && chatsObject.chatIds.isNotEmpty) {
          for (final chatId in chatsObject.chatIds) {
            final chatObject = await _tdlib.sendRequest(td.GetChat(chatId: chatId));

            if (chatObject is td.Chat) {
              final type = chatObject.type;
              if (type is td.ChatTypeSupergroup && type.isChannel) {
                String? username;
                String? description;
                bool isVerified = false;
                int subscriberCount = 0;

                try {
                  final supergroupObj = await _tdlib.sendRequest(td.GetSupergroup(supergroupId: type.supergroupId));
                  if (supergroupObj is td.Supergroup) {
                    username = (supergroupObj.usernames?.activeUsernames != null && supergroupObj.usernames!.activeUsernames.isNotEmpty)
                        ? supergroupObj.usernames!.activeUsernames.first
                        : supergroupObj.usernames?.editableUsername;
                    isVerified = supergroupObj.isVerified;
                  }
                  final fullInfoObj = await _tdlib.sendRequest(td.GetSupergroupFullInfo(supergroupId: type.supergroupId));
                  if (fullInfoObj is td.SupergroupFullInfo) {
                    description = fullInfoObj.description;
                    subscriberCount = fullInfoObj.memberCount;
                  }
                } catch (e) {
                  debugPrint('[Sync] Error fetching supergroup info: $e');
                }

                final companion = TdlibMappers.mapChatToCompanion(
                  chatObject,
                  accountId,
                  username: username,
                  description: description,
                  isVerified: isVerified,
                  subscriberCount: subscriberCount,
                );
                await _db.into(_db.channels).insertOnConflictUpdate(companion);

                if (chatObject.photo != null) {
                  _downloadFile(chatObject.photo!.small.id);
                }
              }
            }
          }

          if (chatsObject.chatIds.length < 100) {
            hasMore = false;
          }
        } else {
          hasMore = false;
        }
      }

      // 2. Re-sync folder channel mappings now that all channels are in local DB
      if (_cachedFolders != null) {
        await _syncFoldersList(_cachedFolders!, accountId);
      }
    } catch (e, stack) {
      debugPrint('[Sync] Error syncing subscribed channels: $e\n$stack');
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Syncs user's Telegram folders (chat filters), filtering out Personal / non-channel folders
  Future<void> _syncFoldersList(List<td.ChatFolderInfo> chatFolders, int accountId) async {
    _cachedFolders = chatFolders;
    try {
      await _db.delete(_db.folderChannels).go();
      await _db.delete(_db.folders).go();

      for (final folderInfo in chatFolders) {
        final titleLower = folderInfo.title.toLowerCase().trim();
        // Skip personal/DM folders
        if (titleLower == 'personal' || titleLower == 'dms' || titleLower == 'direct messages') {
          continue;
        }

        final getFilterFunc = td.GetChatFolder(chatFolderId: folderInfo.id);
        final filter = await _tdlib.sendRequest(getFilterFunc);

        if (filter is td.ChatFolder) {
          final chatList = td.ChatListFolder(chatFolderId: folderInfo.id);
          try {
            await _tdlib.sendRequest(td.LoadChats(chatList: chatList, limit: 100));
          } catch (_) {}

          final chatsObj = await _tdlib.sendRequest(td.GetChats(chatList: chatList, limit: 100));
          if (chatsObj is td.Chats) {
            final allChannels = await _db.select(_db.channels).get();
            final folderChatIdsSet = chatsObj.chatIds.toSet();
            final matchingChannels = allChannels.where((ch) => folderChatIdsSet.contains(ch.chatId)).toList();

            // Only create folder if it contains broadcast channels
            if (matchingChannels.isNotEmpty) {
              final folderDbId = await _db.into(_db.folders).insertOnConflictUpdate(
                FoldersCompanion.insert(
                  accountId: accountId,
                  folderId: folderInfo.id,
                  title: filter.title,
                ),
              );

              for (final channel in matchingChannels) {
                await _db.into(_db.folderChannels).insertOnConflictUpdate(
                  FolderChannelsCompanion.insert(
                    folderDbId: folderDbId,
                    channelDbId: channel.id,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Sync] Error syncing folders list: $e');
    }
  }

  /// Syncs posts feed history for all locally tracked channels.
  Future<void> syncFeedHistory() async {
    debugPrint('[Sync] Syncing feed history...');
    try {
      final channels = await _db.select(_db.channels).get();
      for (final channel in channels) {
        await syncChannelHistory(channel.id, channel.chatId);
      }
    } catch (e) {
      debugPrint('[Sync] Error syncing feed history: $e');
    }
  }

  /// Sync history of a specific channel.
  Future<void> syncChannelHistory(int channelDbId, int chatId) async {
    final accountId = await _getOrCreateActiveAccountId();
    debugPrint('[Sync] Fetching history for channel $chatId (DbId: $channelDbId)');

    try {
      final getHistoryFunction = td.GetChatHistory(
        chatId: chatId,
        fromMessageId: 0,
        offset: 0,
        limit: 50,
        onlyLocal: false,
      );
      final messagesObject = await _tdlib.sendRequest(getHistoryFunction);

      if (messagesObject is td.Messages) {
        await _db.transaction(() async {
          for (final message in messagesObject.messages) {
            final postCompanion = TdlibMappers.mapMessageToCompanion(
              message,
              accountId,
              channelDbId,
            );
            final postDbId = await _db.into(_db.posts).insertOnConflictUpdate(postCompanion);

            final mediaCompanions = TdlibMappers.extractMediaCompanions(message, postDbId);
            await (_db.delete(_db.mediaItems)..where((m) => m.postId.equals(postDbId))).go();
            for (final media in mediaCompanions) {
              await _db.into(_db.mediaItems).insert(media);
            }

            _downloadMessageMedia(message);
          }
        });
      }
    } catch (e, stack) {
      debugPrint('[Sync] Error syncing channel history for $chatId: $e\n$stack');
    }
  }

  /// Load older channel history (pagination).
  Future<void> loadMoreChannelHistory(int channelDbId, int chatId) async {
    final accountId = await _getOrCreateActiveAccountId();
    
    final oldestPost = await (_db.select(_db.posts)
          ..where((p) => p.channelId.equals(channelDbId))
          ..orderBy([(p) => OrderingTerm.asc(p.publishedAt)])
          ..limit(1))
        .getSingleOrNull();

    final int fromMessageId = oldestPost != null ? oldestPost.messageId : 0;
    debugPrint('[Sync] Paginating history for channel $chatId starting from message $fromMessageId');

    try {
      final getHistoryFunction = td.GetChatHistory(
        chatId: chatId,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: 50,
        onlyLocal: false,
      );
      final messagesObject = await _tdlib.sendRequest(getHistoryFunction);

      if (messagesObject is td.Messages) {
        await _db.transaction(() async {
          for (final message in messagesObject.messages) {
            final postCompanion = TdlibMappers.mapMessageToCompanion(
              message,
              accountId,
              channelDbId,
            );
            final postDbId = await _db.into(_db.posts).insertOnConflictUpdate(postCompanion);

            final mediaCompanions = TdlibMappers.extractMediaCompanions(message, postDbId);
            await (_db.delete(_db.mediaItems)..where((m) => m.postId.equals(postDbId))).go();
            for (final media in mediaCompanions) {
              await _db.into(_db.mediaItems).insert(media);
            }

            _downloadMessageMedia(message);
          }
        });
      }
    } catch (e, stack) {
      debugPrint('[Sync] Error loading older channel history for $chatId: $e\n$stack');
    }
  }

  /// Manually add a public channel by its username.
  Future<void> addPublicChannelByUsername(String username) async {
    final accountId = await _getOrCreateActiveAccountId();
    debugPrint('[Sync] Resolving public chat username: @$username');

    final cleanUsername = username.replaceAll('@', '').trim();
    if (cleanUsername.isEmpty) {
      throw Exception('Username cannot be empty.');
    }
    final searchRequest = td.SearchPublicChat(username: cleanUsername);
    final chatObject = await _tdlib.sendRequest(searchRequest);

    if (chatObject is td.Chat) {
      final type = chatObject.type;
      if (type is td.ChatTypeSupergroup && type.isChannel) {
        String? usernameVal;
        String? description;
        bool isVerified = false;
        int subscriberCount = 0;

        try {
          final supergroupObj = await _tdlib.sendRequest(td.GetSupergroup(supergroupId: type.supergroupId));
          if (supergroupObj is td.Supergroup) {
            usernameVal = (supergroupObj.usernames?.activeUsernames != null && supergroupObj.usernames!.activeUsernames.isNotEmpty)
                ? supergroupObj.usernames!.activeUsernames.first
                : supergroupObj.usernames?.editableUsername;
            isVerified = supergroupObj.isVerified;
          }
          final fullInfoObj = await _tdlib.sendRequest(td.GetSupergroupFullInfo(supergroupId: type.supergroupId));
          if (fullInfoObj is td.SupergroupFullInfo) {
            description = fullInfoObj.description;
            subscriberCount = fullInfoObj.memberCount;
          }
        } catch (e) {
          debugPrint('[Sync] Error fetching supergroup info: $e');
        }

        final companion = TdlibMappers.mapChatToCompanion(
          chatObject,
          accountId,
          username: usernameVal ?? cleanUsername,
          description: description,
          isVerified: isVerified,
          subscriberCount: subscriberCount,
        );
        final channelDbId = await _db.into(_db.channels).insertOnConflictUpdate(companion);

        if (chatObject.photo != null) {
          _downloadFile(chatObject.photo!.small.id);
        }

        await syncChannelHistory(channelDbId, chatObject.id);
      } else {
        throw Exception('The username @$username is not a public broadcast channel.');
      }
    } else {
      throw Exception('Chat @$username not found.');
    }
  }

  /// Handles real-time updates from TDLib update streams.
  Future<void> _handleLiveUpdate(td.TdObject update) async {
    if (update is td.UpdateNewMessage) {
      final message = update.message;
      final channel = await (_db.select(_db.channels)
            ..where((c) => c.chatId.equals(message.chatId)))
          .getSingleOrNull();

      if (channel != null) {
        final accountId = await _getOrCreateActiveAccountId();
        await _db.transaction(() async {
          final postCompanion = TdlibMappers.mapMessageToCompanion(
            message,
            accountId,
            channel.id,
          );
          final postDbId = await _db.into(_db.posts).insertOnConflictUpdate(postCompanion);

          final mediaCompanions = TdlibMappers.extractMediaCompanions(message, postDbId);
          for (final media in mediaCompanions) {
            await _db.into(_db.mediaItems).insert(media);
          }
        });
        _downloadMessageMedia(message);
      }
    } else if (update is td.UpdateFile) {
      final file = update.file;
      if (file.local.isDownloadingCompleted && file.local.path.isNotEmpty) {
        await _updateFileLocalPath(file);
      }
    } else if (update is td.UpdateChatReadInbox) {
      await (_db.update(_db.channels)..where((c) => c.chatId.equals(update.chatId)))
          .write(ChannelsCompanion(
        lastReadInboxMessageId: Value(update.lastReadInboxMessageId),
      ));
    } else if (update is td.UpdateChatFolders) {
      try {
        final accountId = await _getOrCreateActiveAccountId();
        await _syncFoldersList(update.chatFolders, accountId);
      } catch (e) {
        debugPrint('[Sync] Failed to sync folders: $e');
      }
    } else if (update is td.UpdatePoll) {
      final poll = update.poll;
      try {
        final postsToUpdate = await (_db.select(_db.posts)
              ..where((p) => p.pollJson.like('%"id":"${poll.id}"%')))
            .get();
        for (final post in postsToUpdate) {
          final updatedPollJson = TdlibMappers.serializePoll(poll);
          await (_db.update(_db.posts)..where((p) => p.id.equals(post.id)))
              .write(PostsCompanion(pollJson: Value(updatedPollJson)));
        }
      } catch (e) {
        debugPrint('[Sync] Error handling UpdatePoll: $e');
      }
    }
  }

  /// Toggle post reaction (like) via TDLib and update local state
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
  Future<void> toggleBookmark(int postId, bool currentStatus) async {
    await (_db.update(_db.posts)..where((p) => p.id.equals(postId)))
        .write(PostsCompanion(isBookmarked: Value(!currentStatus)));
  }

  /// Set poll answers (vote) in TDLib and sync back.
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

  Future<void> _updateFileLocalPath(td.File file) async {
    if (!file.local.isDownloadingCompleted || file.local.path.isEmpty) return;

    final localPath = file.local.path;
    final fileIdStr = file.id.toString();
    final remoteId = file.remote.id;

    debugPrint('[Sync] Reconciling downloaded file ID $fileIdStr (Remote: $remoteId) -> $localPath');

    await (_db.update(_db.channels)
          ..where((c) => c.avatarUrl.equals(fileIdStr) | c.avatarUrl.equals(remoteId)))
        .write(ChannelsCompanion(avatarUrl: Value(localPath)));

    await (_db.update(_db.mediaItems)
          ..where((m) => m.url.equals(fileIdStr) | m.url.equals(remoteId) | m.localPath.equals(fileIdStr) | m.localPath.equals(remoteId)))
        .write(MediaItemsCompanion(localPath: Value(localPath)));

    await (_db.update(_db.mediaItems)
          ..where((m) => m.thumbnailUrl.equals(fileIdStr) | m.thumbnailUrl.equals(remoteId)))
        .write(MediaItemsCompanion(thumbnailUrl: Value(localPath)));

    await (_db.update(_db.accounts)
          ..where((a) => a.avatarPath.equals(fileIdStr) | a.avatarPath.equals(remoteId)))
        .write(AccountsCompanion(avatarPath: Value(localPath)));

    await (_db.update(_db.posts)
          ..where((p) => p.linkPreviewImageUrl.equals(fileIdStr) | p.linkPreviewImageUrl.equals(remoteId)))
        .write(PostsCompanion(linkPreviewImageUrl: Value(localPath)));
  }
}

/// Riverpod provider for SyncService.
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final tdlib = ref.watch(tdlibServiceProvider);
  final service = SyncService(db, tdlib);

  service.startListening();
  ref.onDispose(() => service.stopListening());

  return service;
});

final isSyncingProvider = Provider<ValueNotifier<bool>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.isSyncingNotifier;
});
