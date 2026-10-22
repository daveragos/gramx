import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/text/composed_text.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

/// A text field's controller that keeps the formatting a writer applies and
/// draws it as they type, as Telegram's composers do. Pass
/// [contextMenuBuilder] to the field for the "Format" menu.
class FormattingController extends TextEditingController {
  FormattingController({super.text});

  List<TextEntity> _entities = const [];

  /// Whether the selection menu shows the marks rather than the usual items.
  bool _showsFormats = false;

  /// The text and its formatting.
  ComposedText get composed => ComposedText(text, _entities);

  /// Puts [value] in the field with the caret at its end.
  set composed(ComposedText value) {
    _entities = value.entities;
    super.value = TextEditingValue(
      text: value.text,
      selection: TextSelection.collapsed(offset: value.text.length),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.selection != selection) _showsFormats = false;
    if (newValue.text != text) {
      final caret = newValue.selection;
      _entities = composed
          .edited(
            newValue.text,
            cursor: caret.isValid && caret.isCollapsed
                ? caret.baseOffset
                : null,
          )
          .entities;
    }
    super.value = newValue;
  }

  /// Whether all of [range] carries [format].
  bool isApplied(TextFormat format, TextRange range) =>
      composed.has(format.type, range.start, range.end);

  /// Puts [format] on [range], or takes it off if all of it has it already.
  /// A new link needs [url].
  void toggle(TextFormat format, TextRange range, {String? url}) {
    if (!range.isValid || range.isCollapsed) return;
    final current = composed;
    final next = isApplied(format, range)
        ? current.withoutFormat(format.type, range.start, range.end)
        : current.withFormat(format.type, range.start, range.end, url: url);
    _entities = next.entities;
    notifyListeners();
  }

  /// Takes every mark off [range].
  void clearFormatting(TextRange range) {
    if (!range.isValid || range.isCollapsed) return;
    _entities = composed.plain(range.start, range.end).entities;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_entities.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final cuts = <int>{0, text.length};
    for (final entity in _entities) {
      cuts
        ..add(entity.offset.clamp(0, text.length))
        ..add((entity.offset + entity.length).clamp(0, text.length));
    }
    if (composing.isValid) cuts.addAll([composing.start, composing.end]);
    final sorted = cuts.toList()..sort();

    final spoiler = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.16);
    return TextSpan(
      style: style,
      children: [
        for (var i = 0; i < sorted.length - 1; i++)
          if (sorted[i] < sorted[i + 1])
            TextSpan(
              text: text.substring(sorted[i], sorted[i + 1]),
              style: _styleOf(
                sorted[i],
                sorted[i + 1],
                isComposing:
                    composing.isValid &&
                    sorted[i] >= composing.start &&
                    sorted[i + 1] <= composing.end,
                spoiler: spoiler,
              ),
            ),
      ],
    );
  }

  /// How [start, end) looks, from every mark covering it.
  TextStyle? _styleOf(
    int start,
    int end, {
    required bool isComposing,
    required Color spoiler,
  }) {
    var style = const TextStyle();
    final lines = <TextDecoration>[if (isComposing) TextDecoration.underline];
    for (final entity in _entities) {
      if (entity.offset > start || entity.offset + entity.length < end) {
        continue;
      }
      switch (entity.type) {
        case TextEntityType.bold:
          style = style.copyWith(fontWeight: FontWeight.bold);
        case TextEntityType.italic:
          style = style.copyWith(fontStyle: FontStyle.italic);
        case TextEntityType.underline:
          lines.add(TextDecoration.underline);
        case TextEntityType.strikethrough:
          lines.add(TextDecoration.lineThrough);
        case TextEntityType.code || TextEntityType.codeBlock:
          style = style.copyWith(
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Courier'],
          );
        case TextEntityType.spoiler:
          style = style.copyWith(backgroundColor: spoiler);
        case TextEntityType.textUrl || TextEntityType.mentionName:
          style = style.copyWith(color: AppColors.accent);
        default:
          break;
      }
    }
    if (lines.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(lines));
    }
    return style;
  }

  /// The field's selection menu: the usual items, and "Format" while text is
  /// selected, which shows the marks in their place.
  Widget contextMenuBuilder(BuildContext context, EditableTextState editable) {
    final selection = editable.textEditingValue.selection;
    final canFormat = selection.isValid && !selection.isCollapsed;

    final List<ContextMenuButtonItem> items;
    if (canFormat && _showsFormats) {
      items = [
        for (final format in TextFormat.values)
          ContextMenuButtonItem(
            label: _label(format, selection),
            onPressed: () => _pick(editable, format, selection),
          ),
        if (composed.hasAny(selection.start, selection.end))
          ContextMenuButtonItem(
            label: AppStrings.formatPlain,
            onPressed: () {
              _showsFormats = false;
              clearFormatting(selection);
              editable.hideToolbar(false);
            },
          ),
      ];
    } else {
      items = [...editable.contextMenuButtonItems];
      if (canFormat) {
        // After cut, copy and paste, ahead of what the system adds (Share,
        // Read aloud), which would push it into the overflow.
        final at = items.lastIndexWhere(
          (item) => const {
            ContextMenuButtonType.cut,
            ContextMenuButtonType.copy,
            ContextMenuButtonType.paste,
          }.contains(item.type),
        );
        items.insert(
          at + 1,
          ContextMenuButtonItem(
            label: AppStrings.formatMenu,
            onPressed: () {
              _showsFormats = true;
              editable
                ..hideToolbar(false)
                ..showToolbar();
            },
          ),
        );
      }
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editable.contextMenuAnchors,
      buttonItems: items,
    );
  }

  String _label(TextFormat format, TextRange range) => switch (format) {
    TextFormat.bold => AppStrings.formatBold,
    TextFormat.italic => AppStrings.formatItalic,
    TextFormat.underline => AppStrings.formatUnderline,
    TextFormat.strikethrough => AppStrings.formatStrikethrough,
    TextFormat.spoiler => AppStrings.formatSpoiler,
    TextFormat.code => AppStrings.formatCode,
    TextFormat.link =>
      isApplied(format, range)
          ? AppStrings.formatRemoveLink
          : AppStrings.formatLink,
  };

  Future<void> _pick(
    EditableTextState editable,
    TextFormat format,
    TextRange range,
  ) async {
    _showsFormats = false;
    editable.hideToolbar(false);
    if (format != TextFormat.link || isApplied(format, range)) {
      toggle(format, range);
      return;
    }
    final url = await LinkDialog.show(editable.context);
    // The text may have changed under the dialog.
    if (url == null || range.end > text.length) return;
    toggle(format, range, url: url);
  }
}

/// Asks for the address a link opens.
class LinkDialog extends StatefulWidget {
  const LinkDialog({super.key});

  /// The address, with "https://" added when it names no scheme. Null when
  /// dismissed.
  static Future<String?> show(BuildContext context) =>
      showDialog<String>(context: context, builder: (_) => const LinkDialog());

  /// [typed] as an address a link can open, or null if it can't be one.
  @visibleForTesting
  static String? addressOf(String typed) {
    final trimmed = typed.trim();
    if (trimmed.isEmpty || trimmed.contains(' ')) return null;
    final hasScheme = RegExp(
      r'^[a-z][a-z0-9+.-]*:',
      caseSensitive: false,
    ).hasMatch(trimmed);
    final address = hasScheme ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(address);
    if (uri == null) return null;
    final opens =
        uri.host.contains('.') ||
        const {'tg', 'mailto', 'tel'}.contains(uri.scheme);
    return opens ? address : null;
  }

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final address = LinkDialog.addressOf(_controller.text);
    return AppDialog<String>(
      title: AppStrings.formatLinkTitle,
      content: TextField(
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: AppStrings.formatLinkHint),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (address != null) Navigator.of(context).pop(address);
        },
      ),
      actions: const [AppDialogAction.cancel(AppStrings.chatCancel)],
      primary: PillButton(
        label: AppStrings.formatLinkAdd,
        expand: true,
        onPressed: address == null
            ? null
            : () => Navigator.of(context).pop(address),
      ),
    );
  }
}
