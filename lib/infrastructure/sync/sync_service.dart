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
      debugPrint('[Sync] DownloadFile request failed for fileId $fileId: $e');
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
    }
  }

  /// Syncs all subscribed broadcast channels from Telegram.
  Future<void> syncSubscribedChannels() async {
    final accountId = await _getOrCreateActiveAccountId();
    debugPrint('[Sync] Syncing subscribed channels...');

    try {
      // 1. Fetch main chat list from TDLib
      // In TDLib, GetChats is used.
      final getChatsFunction = td.GetChats(
        chatList: const td.ChatListMain(),
        limit: 100,
      );
      final chatsObject = await _tdlib.sendRequest(getChatsFunction);

      if (chatsObject is td.Chats) {
        for (final chatId in chatsObject.chatIds) {
          // 2. Fetch full chat info for each ID
          final getChatFunction = td.GetChat(chatId: chatId);
          final chatObject = await _tdlib.sendRequest(getChatFunction);

          if (chatObject is td.Chat) {
            // 3. Filter broadcast channels only
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
                debugPrint('[Sync] Error fetching supergroup info for ${chatObject.title}: $e');
              }

              final companion = TdlibMappers.mapChatToCompanion(
                chatObject,
                accountId,
                username: username,
                description: description,
                isVerified: isVerified,
                subscriberCount: subscriberCount,
              );
              // Insert or update chat in local DB
              await _db.into(_db.channels).insertOnConflictUpdate(companion);
              debugPrint('[Sync] Subscribed channel added/updated: ${chatObject.title}');

              // Trigger background download for the channel avatar
              if (chatObject.photo != null) {
                _downloadFile(chatObject.photo!.small.id);
              }
            }
          }
        }
      }
    } catch (e, stack) {
      debugPrint('[Sync] Error syncing subscribed channels: $e\n$stack');
    }
  }

  /// Syncs user's Telegram folders (chat filters) based on chatFolders list from update
  Future<void> _syncFoldersList(List<td.ChatFolderInfo> chatFolders, int accountId) async {
    try {
      // Clear existing folders and maps
      await _db.customStatement('DELETE FROM folder_channels');
      await _db.customStatement('DELETE FROM folders');

      for (final folderInfo in chatFolders) {
        // Fetch full folder filter details
        final getFilterFunc = td.GetChatFolder(chatFolderId: folderInfo.id);
        final filter = await _tdlib.sendRequest(getFilterFunc);

        if (filter is td.ChatFolder) {
          // Save folder definition
          final folderDbId = await _db.into(_db.folders).insertOnConflictUpdate(
            FoldersCompanion.insert(
              accountId: accountId,
              folderId: folderInfo.id,
              title: filter.title,
            ),
          );

          // Load and page chats inside this folder in TDLib
          final chatList = td.ChatListFolder(chatFolderId: folderInfo.id);
          try {
            await _tdlib.sendRequest(td.LoadChats(chatList: chatList, limit: 100));
          } catch (_) {}

          final chatsObj = await _tdlib.sendRequest(td.GetChats(chatList: chatList, limit: 100));
          if (chatsObj is td.Chats) {
            final allChannels = await _db.select(_db.channels).get();
            final folderChatIdsSet = chatsObj.chatIds.toSet();

            for (final channel in allChannels) {
              if (folderChatIdsSet.contains(channel.chatId)) {
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
            // Create post companion
            final postCompanion = TdlibMappers.mapMessageToCompanion(
              message,
              accountId,
              channelDbId,
            );
            // Upsert post
            final postDbId = await _db.into(_db.posts).insertOnConflictUpdate(postCompanion);

            // Extract and upsert media items
            final mediaCompanions = TdlibMappers.extractMediaCompanions(message, postDbId);
            // Delete old media for this post to avoid duplicates on rebuild
            await (_db.delete(_db.mediaItems)..where((m) => m.postId.equals(postDbId))).go();
            for (final media in mediaCompanions) {
              await _db.into(_db.mediaItems).insert(media);
            }

            // Trigger background downloads of media
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
    
    // Find the oldest message ID we have locally for this channel
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
            // Delete old media for this post to avoid duplicates on rebuild
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

    // Clean username formatting
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
        debugPrint('[Sync] Manually added public channel: ${chatObject.title}');

        // Trigger background download of avatar
        if (chatObject.photo != null) {
          _downloadFile(chatObject.photo!.small.id);
        }

        // Immediately sync history for this channel
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
      // Check if message belongs to a channel we sync
      final channel = await (_db.select(_db.channels)
            ..where((c) => c.chatId.equals(message.chatId)))
          .getSingleOrNull();

      if (channel != null) {
        debugPrint('[Sync] Received live new message for channel: ${channel.title}');
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

        // Trigger media downloads
        _downloadMessageMedia(message);
      }
    } else if (update is td.UpdateFile) {
      final file = update.file;
      if (file.local.isDownloadingCompleted && file.local.path.isNotEmpty) {
        debugPrint('[Sync] File download completed: ${file.remote.id} -> ${file.local.path}');
        await _updateFileLocalPath(file.remote.id, file.local.path);
      }
    } else if (update is td.UpdateChatReadInbox) {
      debugPrint('[Sync] Read cursor updated for chat ${update.chatId}: ${update.lastReadInboxMessageId}');
      await (_db.update(_db.channels)..where((c) => c.chatId.equals(update.chatId)))
          .write(ChannelsCompanion(
        lastReadInboxMessageId: Value(update.lastReadInboxMessageId),
      ));
    } else if (update is td.UpdateChatFolders) {
      debugPrint('[Sync] Received chat folders update: ${update.chatFolders.length} folders.');
      try {
        final accountId = await _getOrCreateActiveAccountId();
        await _syncFoldersList(update.chatFolders, accountId);
      } catch (e) {
        debugPrint('[Sync] Failed to sync folders on UpdateChatFolders: $e');
      }
    }
  }

  Future<void> _updateFileLocalPath(String remoteId, String localPath) async {
    // 1. Update Channels matching avatarUrl
    await (_db.update(_db.channels)..where((c) => c.avatarUrl.equals(remoteId)))
        .write(ChannelsCompanion(avatarUrl: Value(localPath)));

    // 2. Update MediaItems matching url or thumbnailUrl
    await (_db.update(_db.mediaItems)..where((m) => m.url.equals(remoteId)))
        .write(MediaItemsCompanion(localPath: Value(localPath)));

    await (_db.update(_db.mediaItems)..where((m) => m.thumbnailUrl.equals(remoteId)))
        .write(MediaItemsCompanion(thumbnailUrl: Value(localPath)));

    // 3. Update Accounts matching avatarPath
    await (_db.update(_db.accounts)..where((a) => a.avatarPath.equals(remoteId)))
        .write(AccountsCompanion(avatarPath: Value(localPath)));
  }
}

/// Riverpod provider for SyncService.
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final tdlib = ref.watch(tdlibServiceProvider);
  final service = SyncService(db, tdlib);

  // Start updates listener
  service.startListening();
  ref.onDispose(() => service.stopListening());

  return service;
});
