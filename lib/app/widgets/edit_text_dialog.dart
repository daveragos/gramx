import 'package:flutter/material.dart';

import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// Dialog for editing a message, comment or post. Owns its controller so it
/// stays alive through the exit animation.
class EditTextDialog extends StatefulWidget {
  final String initialText;
  final String title;

  /// Whether empty text may be saved. A caption may be emptied; Telegram
  /// rejects an empty text message.
  final bool allowsEmpty;

  const EditTextDialog({
    super.key,
    required this.initialText,
    this.title = AppStrings.chatEditTitle,
    this.allowsEmpty = false,
  });

  /// Shows the dialog. Resolves to the new text, or null if unchanged.
  static Future<String?> show(
    BuildContext context, {
    required String initialText,
    String title = AppStrings.chatEditTitle,
    bool allowsEmpty = false,
  }) async {
    final updated = await showDialog<String>(
      context: context,
      builder: (_) => EditTextDialog(
        initialText: initialText,
        title: title,
        allowsEmpty: allowsEmpty,
      ),
    );
    if (updated == null || updated == initialText) return null;
    return updated;
  }

  @override
  State<EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<EditTextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => widget.allowsEmpty || _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AppDialog<String>(
      title: widget.title,
      content: TextField(
        controller: _controller,
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
            ? () => Navigator.of(context).pop(_controller.text.trim())
            : null,
      ),
    );
  }
}
