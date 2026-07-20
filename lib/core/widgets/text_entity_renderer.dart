import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

class TextEntityRenderer extends StatelessWidget {
  final String text;
  final List<TextEntity> entities;
  final TextStyle? style;

  const TextEntityRenderer({
    super.key,
    required this.text,
    required this.entities,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = style ?? AppTypography.body(color: theme.colorScheme.onSurface);

    if (entities.isEmpty) {
      return SelectableText(
        text,
        style: defaultStyle,
      );
    }

    // Sort entities by offset ascending.
    final sortedEntities = List<TextEntity>.from(entities)
      ..sort((a, b) => a.offset.compareTo(b.offset));

    final List<InlineSpan> spans = [];
    int currentIndex = 0;

    for (final entity in sortedEntities) {
      // Prevent index out of bounds
      if (entity.offset < currentIndex || entity.offset > text.length) {
        continue;
      }

      // Add preceding plain text
      if (entity.offset > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, entity.offset),
          style: defaultStyle,
        ));
      }

      final entityEnd = entity.offset + entity.length;
      final safeEnd = entityEnd > text.length ? text.length : entityEnd;
      final entityText = text.substring(entity.offset, safeEnd);

      // Apply entity-specific styling
      spans.add(_buildEntitySpan(context, entity, entityText, defaultStyle));

      currentIndex = safeEnd;
    }

    // Add remaining plain text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: defaultStyle,
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  InlineSpan _buildEntitySpan(
    BuildContext context,
    TextEntity entity,
    String entityText,
    TextStyle baseStyle,
  ) {
    final accentStyle = baseStyle.copyWith(
      color: AppColors.accent,
      fontWeight: FontWeight.w500,
    );

    switch (entity.type) {
      case TextEntityType.bold:
        return TextSpan(
          text: entityText,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        );
      case TextEntityType.italic:
        return TextSpan(
          text: entityText,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        );
      case TextEntityType.underline:
        return TextSpan(
          text: entityText,
          style: baseStyle.copyWith(decoration: TextDecoration.underline),
        );
      case TextEntityType.strikethrough:
        return TextSpan(
          text: entityText,
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        );
      case TextEntityType.code:
        return TextSpan(
          text: entityText,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.grey[200],
          ),
        );
      case TextEntityType.codeBlock:
        return TextSpan(
          text: '\n$entityText\n',
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            height: 1.5,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.grey[100],
          ),
        );
      case TextEntityType.url:
      case TextEntityType.textUrl:
        final tapUrl = entity.url ?? entityText;
        return TextSpan(
          text: entityText,
          style: accentStyle.copyWith(decoration: TextDecoration.none),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkTap(context, tapUrl),
        );
      case TextEntityType.mention:
        return TextSpan(
          text: entityText,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleMentionTap(context, entityText),
        );
      case TextEntityType.hashtag:
        return TextSpan(
          text: entityText,
          style: accentStyle,
        );
      case TextEntityType.spoiler:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SpoilerWidget(
            text: entityText,
            style: baseStyle,
          ),
        );
      case TextEntityType.customEmoji:
        // We'll render custom emojis as inline widget span using fallback text,
        // but with a tiny star icon indicating a premium emoji.
        return TextSpan(
          children: [
            TextSpan(text: entityText, style: baseStyle),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.star, size: 10, color: Colors.amber),
            ),
          ],
        );
      case TextEntityType.unknown:
        return TextSpan(
          text: entityText,
          style: baseStyle,
        );
    }
  }

  void _handleLinkTap(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied to clipboard: $url'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleMentionTap(BuildContext context, String mention) {
    final username = mention.replaceFirst('@', '').trim();
    if (username.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening user/channel mention: @$username'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class SpoilerWidget extends StatefulWidget {
  final String text;
  final TextStyle style;

  const SpoilerWidget({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<SpoilerWidget> createState() => _SpoilerWidgetState();
}

class _SpoilerWidgetState extends State<SpoilerWidget> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return GestureDetector(
      onTap: () {
        setState(() {
          _revealed = !_revealed;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: _revealed ? Colors.transparent : coverColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.text,
          style: widget.style.copyWith(
            color: _revealed ? widget.style.color : Colors.transparent,
            backgroundColor: _revealed ? Colors.transparent : coverColor,
          ),
        ),
      ),
    );
  }
}
