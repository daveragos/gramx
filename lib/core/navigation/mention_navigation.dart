import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// Opens whoever `@username` is, as Telegram resolves it: a person or bot's
/// profile, a channel's profile, or a group's chat. An `@name` in a post or
/// description can be any of them, and was always opened as a channel.
///
/// A guest has no account to ask with, and only public channels to show, so
/// the name opens as one.
Future<void> openMention(BuildContext context, String username) async {
  final handle = username.replaceFirst('@', '').trim();
  if (handle.isEmpty) return;

  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(isGuestModeProvider)) {
    NavigationUtils.openChannel(context, handle);
    return;
  }

  final resolved = await container
      .read(chatsRepositoryProvider)
      .resolveUsername(handle);
  if (!context.mounted) return;

  if (resolved == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.chatMentionUnknown(handle)),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  if (resolved.kind == ResolvedChatKind.channel) {
    // Not again if it's the channel already showing.
    NavigationUtils.openChannel(context, resolved.chatId.toString());
    return;
  }
  context.push(mentionRouteFor(resolved.kind, resolved.chatId));
}

/// Opens a person's profile from a mention that names them by id, as bots
/// write mentions. TDLib sends the user before any message mentioning them.
void openUserProfile(BuildContext context, int userId) =>
    context.push(UserProfileScreen.routeFor(userId));

/// Where an `@name` of [kind] opens: a person or bot's profile, a channel's
/// profile, or a group's chat.
String mentionRouteFor(ResolvedChatKind kind, int chatId) => switch (kind) {
  // A private chat's id is its user's id.
  ResolvedChatKind.person => UserProfileScreen.routeFor(chatId),
  ResolvedChatKind.channel => '/channel/$chatId',
  ResolvedChatKind.group => ChatsScreen.routeFor(chatId),
};
