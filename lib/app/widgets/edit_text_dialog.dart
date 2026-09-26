import 'package:flutter/material.dart';

import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The box a message's words are rewritten in.
///
/// One dialog for every place a reader can edit something they wrote — a
/// message in a conversation, a comment under a post, a post in a channel they
/// run. Each of those used to be its own answer or, mostly, no answer at all;
/// this is the one shape, and the caller only decides what to do with the text.
///
/// Owns its own controller. The controller used to be disposed the moment
/// `showDialog` returned — while the dialog was still animating out and its
/// field still reading from it, which threw on every save.
class EditTextDialog extends StatefulWidget {
  final String initialText;
  final String title;

  /// Whether an empty answer may be saved. A caption may be emptied; a text
  /// message may not, since Telegram has no such thing as a message with
  /// nothing in it. The button greys out rather than sending a save that
  /// Telegram would refuse.
  final bool allowsEmpty;

  const EditTextDialog({
    super.key,
    required this.initialText,
    this.title = AppStrings.chatEditTitle,
    this.allowsEmpty = false,
  });

  /// Shows the dialog. Resolves to the new text, or null if it was cancelled
  /// or the text was left as it was — a save that changes nothing is not an
  /// edit, and sending one costs a request for Telegram to say so.
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

  bool get _canSave =>
      widget.allowsEmpty || _controller.text.trim().isNotEmpty;

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
        // Rebuilds the save button's enabled state; the field itself stays
        // uncontrolled, so this costs one setState per keystroke.
        onChanged: (_) => setState(() {}),
      ),
      // The dialog pops with a value it is *given*; the text lives in this
      // State, so the primary action is wired here rather than declared.
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
