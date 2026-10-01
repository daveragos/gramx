import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';

/// The send-state icon on an outgoing message: clock, one tick, two ticks or
/// a warning, each with a semantic label.
class MessageSendStateIcon extends StatelessWidget {
  final MessageSendState state;

  /// The colour for every state except read and failed.
  final Color color;

  /// The colour for read: white on an outgoing bubble, the accent where there
  /// is no bubble fill (such as the chat list).
  final Color readColor;

  const MessageSendStateIcon({
    super.key,
    required this.state,
    required this.color,
    this.readColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, tint, label) = switch (state) {
      MessageSendState.sending => (
        Icons.schedule_rounded,
        color,
        AppStrings.chatStateSending,
      ),
      MessageSendState.sent => (
        Icons.check_rounded,
        color,
        AppStrings.chatStateSent,
      ),
      MessageSendState.read => (
        Icons.done_all_rounded,
        readColor,
        AppStrings.chatStateRead,
      ),
      MessageSendState.failed => (
        Icons.error_outline_rounded,
        Theme.of(context).colorScheme.error,
        AppStrings.chatStateFailed,
      ),
    };

    return Semantics(
      label: label,
      child: Icon(icon, size: 14, color: tint),
    );
  }
}
