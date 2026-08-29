import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// Opens Saved Messages, resolving the chat first.
///
/// One function rather than a route, because the destination is not knowable
/// from a path: Saved Messages is a private chat with your own user id, which
/// is read from the account record, and on a fresh account the chat has to be
/// created before it can be pushed. A `/saved` route would have to do all of
/// that inside a builder, which is exactly the side-effect-in-`build` the hard
/// rules forbid.
///
/// Safe to call from anywhere with a `WidgetRef`. Reports failure rather than
/// pushing an empty screen.
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

/// Whether Saved Messages is reachable at all.
///
/// A guest has no account, so there is no chat with themselves to save into —
/// the entry is hidden rather than shown and refused.
bool canOpenSavedMessages(WidgetRef ref) =>
    ref.watch(readerCapabilitiesProvider).canMessage;
