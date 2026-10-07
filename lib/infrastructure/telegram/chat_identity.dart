import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';

/// What a post shows of a chat other than its own, such as the channel a
/// repost or a quote came from: its name, picture, handle and badge.
typedef ChatIdentity = ({
  String? title,
  String? avatarPath,
  int? avatarFileId,
  String? username,
  bool isVerified,
});

/// [ChatIdentity] for a chat id, from TDLib's copy of the chat. TDLib sends a
/// chat before any message that names it, so this asks the server nothing.
/// The name a message was mapped with can be missing, as when the chat
/// arrived after it.
final chatIdentityProvider = Provider.family<ChatIdentity, int>((ref, chatId) {
  final cache = ref.read(chatCacheProvider);
  final chat = cache.chat(chatId);
  final photo = chat?.photo?.small;
  final supergroupId = TelegramIds.supergroupId(chatId);
  final supergroup = supergroupId == null
      ? null
      : cache.supergroup(supergroupId);
  return (
    title: chat?.title,
    avatarPath: photo != null && photo.local.path.isNotEmpty
        ? photo.local.path
        : null,
    avatarFileId: photo?.id,
    username: supergroup?.usernames?.activeUsernames.firstOrNull,
    isVerified: supergroup?.isVerified ?? false,
  );
});
