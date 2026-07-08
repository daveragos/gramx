import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final accounts = await _db.select(_db.accounts).get();
    if (accounts.isNotEmpty) {
      return accounts.first.id;
    }
    return _db.into(_db.accounts).insert(
      AccountsCompanion.insert(
        telegramUserId: 'active_user',
        displayName: const Value('Active User'),
      ),
    );
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
              final companion = TdlibMappers.mapChatToCompanion(chatObject, accountId);
              // Insert or update chat in local DB
              await _db.into(_db.channels).insertOnConflictUpdate(companion);
              debugPrint('[Sync] Subscribed channel added/updated: ${chatObject.title}');
            }
          }
        }
      }
    } catch (e, stack) {
      debugPrint('[Sync] Error syncing subscribed channels: $e\n$stack');
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
            for (final media in mediaCompanions) {
              // Delete old media for this post to avoid duplicates on rebuild
              await (_db.delete(_db.mediaItems)..where((m) => m.postId.equals(postDbId))).go();
              await _db.into(_db.mediaItems).insert(media);
            }
          }
        });
      }
    } catch (e, stack) {
      debugPrint('[Sync] Error syncing channel history for $chatId: $e\n$stack');
    }
  }

  /// Manually add a public channel by its username (Guest Mode).
  Future<void> addPublicChannelByUsername(String username) async {
    final accountId = await _getOrCreateActiveAccountId();
    debugPrint('[Sync] Resolving public chat username: @$username');

    try {
      // Clean username formatting
      final cleanUsername = username.replaceAll('@', '').trim();
      final searchRequest = td.SearchPublicChat(username: cleanUsername);
      final chatObject = await _tdlib.sendRequest(searchRequest);

      if (chatObject is td.Chat) {
        final type = chatObject.type;
        if (type is td.ChatTypeSupergroup && type.isChannel) {
          final companion = TdlibMappers.mapChatToCompanion(chatObject, accountId);
          final channelDbId = await _db.into(_db.channels).insertOnConflictUpdate(companion);
          debugPrint('[Sync] Manually added public channel: ${chatObject.title}');

          // Immediately sync history for this channel
          await syncChannelHistory(channelDbId, chatObject.id);
        } else {
          throw Exception('The username @$username is not a public broadcast channel.');
        }
      } else {
        throw Exception('Chat @$username not found.');
      }
    } catch (e) {
      debugPrint('[Sync] Error adding public channel: $e');
      rethrow;
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
      }
    }
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
