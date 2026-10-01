import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// Opens Saved Messages, resolving (and on a fresh account creating) the chat
/// first. Shows a snackbar if the chat can't be resolved.
Future<void> openSavedMessages(BuildContext context, WidgetRef ref) async {
  final chatId = await ref
      .read(chatsRepositoryProvider)
      .savedMessagesChatId(ref.read(selfUserIdProvider));

  if (!context.mounted) return;

  if (chatId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.savedMessagesUnavailable),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  context.push(ChatsScreen.routeFor(chatId));
}

/// Whether Saved Messages is available. False for a guest, who has no account.
bool canOpenSavedMessages(WidgetRef ref) =>
    ref.watch(readerCapabilitiesProvider).canMessage;
