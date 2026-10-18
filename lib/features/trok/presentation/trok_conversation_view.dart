import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_composer.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_empty_state.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_turns.dart';

/// The conversation on screen above the composer, or starters when there is
/// none. Shared by the Trok tab and Trok opened from a post.
class TrokConversationView extends ConsumerStatefulWidget {
  /// Space a header overlaid on the view covers.
  final double topPadding;

  /// Space kept under the composer, for the tab bar.
  final double bottomInset;

  /// Opens the keyboard at once, for a question the reader will type.
  final bool autofocus;

  const TrokConversationView({
    super.key,
    this.topPadding = 0,
    this.bottomInset = 0,
    this.autofocus = false,
  });

  @override
  ConsumerState<TrokConversationView> createState() =>
      _TrokConversationViewState();
}

class _TrokConversationViewState extends ConsumerState<TrokConversationView> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onStarter(TrokStarter starter) {
    if (starter.needsTopic) {
      _text.value = TextEditingValue(
        text: starter.prompt,
        selection: TextSelection.collapsed(offset: starter.prompt.length),
      );
      _focus.requestFocus();
      return;
    }
    ref.read(trokControllerProvider.notifier).ask(starter.prompt);
  }

  /// Back to the newest message, which a reversed list keeps at offset 0.
  void _toNewest() {
    if (!_scroll.hasClients || _scroll.offset == 0) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(
      trokControllerProvider.select((s) => s.active),
    );

    // A new question, or another conversation, starts at the newest message.
    ref.listen<(String?, int)>(
      trokControllerProvider.select(
        (s) => (s.activeId, s.active?.turns.length ?? 0),
      ),
      (previous, next) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _toNewest()),
    );

    final hasTurns = conversation != null && conversation.turns.isNotEmpty;
    final loading = conversation != null && !conversation.isLoaded;

    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: loading
                ? Padding(
                    key: const ValueKey('loading'),
                    padding: EdgeInsets.only(top: widget.topPadding),
                    child: const Center(
                      child: TrokMark(
                        size: 48,
                        motion: TrokMarkMotion.thinking,
                      ),
                    ),
                  )
                : hasTurns
                ? _Turns(
                    key: ValueKey(conversation.id),
                    conversation: conversation,
                    controller: _scroll,
                    topPadding: widget.topPadding,
                  )
                : Padding(
                    key: const ValueKey('empty'),
                    padding: EdgeInsets.only(top: widget.topPadding),
                    child: TrokEmptyState(onStarter: _onStarter),
                  ),
          ),
        ),
        TrokComposer(controller: _text, focusNode: _focus),
        SizedBox(height: widget.bottomInset),
      ],
    );
  }
}

/// The turns, newest at the bottom, with follow-ups under a finished answer.
class _Turns extends StatelessWidget {
  final TrokConversation conversation;
  final ScrollController controller;
  final double topPadding;

  const _Turns({
    super.key,
    required this.conversation,
    required this.controller,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final turns = conversation.turns;
    final last = conversation.lastAnswer;
    final followUps = last != null && last.state == TrokAnswerState.done
        ? last.followUps
        : const <String>[];
    final extra = followUps.isEmpty ? 0 : 1;

    // Reversed, so the list starts at the newest turn and stays there as an
    // answer grows.
    return ListView.builder(
      controller: controller,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        top: topPadding + AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      itemCount: turns.length + extra,
      itemBuilder: (context, index) {
        if (index < extra) return TrokFollowUpList(followUps: followUps);
        final turn = turns[turns.length - 1 - (index - extra)];
        return switch (turn) {
          final TrokQuestion q => TrokQuestionView(
            key: ValueKey(q.id),
            question: q,
          ),
          final TrokAnswer a => TrokAnswerView(
            key: ValueKey(a.id),
            answer: a,
            isLast: identical(a, last),
          ),
        };
      },
    );
  }
}
