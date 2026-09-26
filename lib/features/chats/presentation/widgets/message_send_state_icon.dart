import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';

/// The tick under a message this account sent.
///
/// Shape alone carries the state — one tick, two ticks, a clock, a warning —
/// which is precisely the case a label is for, so every
/// one of them has one.
///
/// Read is the accent blue and sent is not, because the difference between "it
/// arrived" and "they read it" is the one thing anybody actually looks at here.
class MessageSendStateIcon extends StatelessWidget {
  final MessageSendState state;

  /// The bubble's meta colour, used for everything except read and failed —
  /// those two say something the bubble's own colour should not soften.
  final Color color;

  /// What "read" is drawn in. White on an outgoing bubble, whose fill is
  /// already the accent; the accent itself anywhere with no fill behind it,
  /// like a row of the chat list — where white would simply not be there.
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
