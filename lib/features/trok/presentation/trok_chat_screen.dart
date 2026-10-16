import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/trok_conversation_view.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_header_actions.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';

/// Trok over the current tab, opened from a post, so back returns to the
/// place in the feed. The conversation is the one the Trok tab shows.
class TrokChatScreen extends ConsumerWidget {
  /// Root-level, so it covers the tab bar.
  static const route = '/trok-chat';

  /// Opens the keyboard at once, for a question the reader will type.
  final bool focusComposer;

  const TrokChatScreen({super.key, this.focusComposer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answering = ref.watch(
      trokControllerProvider.select((s) => s.isAnswering),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TrokWordmark(
          motion: answering ? TrokMarkMotion.thinking : TrokMarkMotion.still,
        ),
        actions: const [TrokHeaderActions()],
      ),
      body: SafeArea(
        top: false,
        child: TrokConversationView(autofocus: focusComposer),
      ),
    );
  }
}
