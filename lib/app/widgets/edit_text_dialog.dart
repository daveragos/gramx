import 'package:flutter/material.dart';

import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/text/composed_text.dart';
import 'package:gramx/core/widgets/formatting_controller.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

/// Dialog for editing a message, comment or post, formatting included. Owns
/// its controller so it stays alive through the exit animation.
class EditTextDialog extends StatefulWidget {
  final String initialText;

  /// The formatting on [initialText].
  final List<TextEntity> initialEntities;
  final String title;

  /// Whether empty text may be saved. A caption may be emptied; Telegram
  /// rejects an empty text message.
  final bool allowsEmpty;

  const EditTextDialog({
    super.key,
    required this.initialText,
    this.initialEntities = const [],
    this.title = AppStrings.chatEditTitle,
    this.allowsEmpty = false,
  });

  /// Shows the dialog. Resolves to the new text and its formatting, or null
  /// if neither changed.
  static Future<ComposedText?> show(
    BuildContext context, {
    required String initialText,
    List<TextEntity> initialEntities = const [],
    String title = AppStrings.chatEditTitle,
    bool allowsEmpty = false,
  }) async {
    final updated = await showDialog<ComposedText>(
      context: context,
      builder: (_) => EditTextDialog(
        initialText: initialText,
        initialEntities: initialEntities,
        title: title,
        allowsEmpty: allowsEmpty,
      ),
    );
    if (updated == null ||
        updated == ComposedText.editable(initialText, initialEntities)) {
      return null;
    }
    return updated;
  }

  @override
  State<EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<EditTextDialog> {
  late final FormattingController _controller = FormattingController()
    ..composed = ComposedText.editable(
      widget.initialText,
      widget.initialEntities,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => widget.allowsEmpty || _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AppDialog<ComposedText>(
      title: widget.title,
      content: TextField(
        controller: _controller,
        contextMenuBuilder: _controller.contextMenuBuilder,
        autofocus: true,
        maxLines: 6,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        // Updates the save button's enabled state.
        onChanged: (_) => setState(() {}),
      ),
      // The text lives in this State, so the save button is built here.
      actions: const [AppDialogAction.cancel(AppStrings.chatCancel)],
      primary: PillButton(
        label: AppStrings.chatSave,
        expand: true,
        onPressed: _canSave
            ? () => Navigator.of(context).pop(_controller.composed.trimmed())
            : null,
      ),
    );
  }
}
