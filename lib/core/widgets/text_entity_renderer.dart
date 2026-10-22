import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/core/text/text_clamp.dart';
import 'package:gramx/core/text/text_direction.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/mention_navigation.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/feed/presentation/widgets/custom_emoji_span.dart';

class TextEntityRenderer extends StatelessWidget {
  final String text;
  final List<TextEntity> entities;
  final TextStyle? style;

  /// Clamp the rendered text to this many lines. Null renders in full.
  final int? maxLines;

  /// Colour for links, mentions and hashtags. Defaults to the accent; an
  /// outgoing bubble, which is accent-coloured, passes its foreground colour.
  final Color? linkColor;

  /// Called when an `@name` is tapped. Without it [openMention] asks
  /// Telegram who the name belongs to and opens that.
  final ValueChanged<String>? onMentionTap;

  /// Called when a hashtag is tapped. Null renders hashtags as plain text.
  final ValueChanged<String>? onHashtagTap;

  /// Called with the second a timestamp such as "1:23" points at, to play the
  /// media from there. Null renders timestamps as plain text.
  final ValueChanged<int>? onMediaTimestampTap;

  /// Whether a long press selects text. Off in chat bubbles, where a long
  /// press opens the message actions.
  final bool selectable;

  /// Takes the parent's whole width, so a short line of right-to-left text
  /// starts at the right edge rather than shrinking to its own width at the
  /// left. Only under a parent of bounded width, such as a post card.
  final bool fullWidth;

  const TextEntityRenderer({
    super.key,
    required this.text,
    required this.entities,
    this.onHashtagTap,
    this.onMediaTimestampTap,
    this.style,
    this.maxLines,
    this.linkColor,
    this.onMentionTap,
    this.selectable = true,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    // Persian or Arabic starts from the right, as in Telegram, and a line in
    // the other direction keeps its punctuation at its own end.
    final direction = directionOf(context, text);
    final body = _text(context, direction);
    return fullWidth && direction == TextDirection.rtl
        ? SizedBox(width: double.infinity, child: body)
        : body;
  }

  Widget _text(BuildContext context, TextDirection direction) {
    final theme = Theme.of(context);
    final defaultStyle =
        style ?? AppTypography.body(color: theme.colorScheme.onSurface);
    final marks = directionIsolates(text, direction);

    if (entities.isEmpty && marks.isEmpty) {
      if (maxLines != null) {
        return Text(
          text,
          style: defaultStyle,
          textDirection: direction,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      }
      return selectable
          ? SelectableText(text, style: defaultStyle, textDirection: direction)
          : Text(text, style: defaultStyle, textDirection: direction);
    }

    final sortedEntities = List<TextEntity>.from(entities)
      ..sort((a, b) => a.offset.compareTo(b.offset));

    final List<InlineSpan> spans = [];
    int currentIndex = 0;

    for (final entity in sortedEntities) {
      // Skip entities that overlap the previous one or fall outside the text.
      if (entity.offset < currentIndex || entity.offset > text.length) {
        continue;
      }

      if (entity.offset > currentIndex) {
        spans.add(
          TextSpan(
            text: withMarks(text, currentIndex, entity.offset, marks),
            style: defaultStyle,
          ),
        );
      }

      final entityEnd = entity.offset + entity.length;
      final safeEnd = entityEnd > text.length ? text.length : entityEnd;
      final entityText = text.substring(entity.offset, safeEnd);

      // A widget has no text to carry a mark, so one starting its line gets
      // the mark just before it.
      final String display;
      if (_drawnAsWidget.contains(entity.type)) {
        final mark = marks[entity.offset];
        if (mark != null) spans.add(TextSpan(text: mark, style: defaultStyle));
        display = entityText;
      } else {
        display = withMarks(text, entity.offset, safeEnd, marks);
      }

      spans.add(
        _buildEntitySpan(context, entity, entityText, display, defaultStyle),
      );

      currentIndex = safeEnd;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: withMarks(text, currentIndex, text.length, marks),
          style: defaultStyle,
        ),
      );
    }

    // Clamped text uses Text, not SelectableText: a selectable field with a
    // line limit scrolls internally and clips instead of ellipsizing.
    if (maxLines != null) {
      return Text.rich(
        TextSpan(children: spans),
        textDirection: direction,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return selectable
        ? SelectableText.rich(
            TextSpan(children: spans),
            textDirection: direction,
          )
        : Text.rich(TextSpan(children: spans), textDirection: direction);
  }

  /// The direction [text] is laid out in: that of its first letter, or the
  /// app's when it has none.
  static TextDirection directionOf(BuildContext context, String text) =>
      firstStrongDirection(text) ?? Directionality.of(context);

  /// Entities drawn as widgets inside the text rather than as styled text.
  static const _drawnAsWidget = {
    TextEntityType.code,
    TextEntityType.codeBlock,
    TextEntityType.blockQuote,
    TextEntityType.expandableBlockQuote,
    TextEntityType.spoiler,
    TextEntityType.customEmoji,
  };

  /// The span for [entity]. [entityText] is what it covers, for links and
  /// the like; [display] is the same with any direction marks inside it.
  InlineSpan _buildEntitySpan(
    BuildContext context,
    TextEntity entity,
    String entityText,
    String display,
    TextStyle baseStyle,
  ) {
    final accentStyle = baseStyle.copyWith(
      color: linkColor ?? AppColors.accent,
      fontWeight: FontWeight.w500,
      // Set in both directions so no inherited underline leaks in. A caller's
      // link colour can match the body text, so the underline marks links.
      decoration: linkColor == null
          ? TextDecoration.none
          : TextDecoration.underline,
      decorationColor: linkColor,
    );

    switch (entity.type) {
      case TextEntityType.bold:
        return TextSpan(
          text: display,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        );
      case TextEntityType.italic:
        return TextSpan(
          text: display,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        );
      case TextEntityType.underline:
        return TextSpan(
          text: display,
          style: baseStyle.copyWith(decoration: TextDecoration.underline),
        );
      case TextEntityType.strikethrough:
        return TextSpan(
          text: display,
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        );
      case TextEntityType.code:
        // TextSpan backgrounds hug the glyphs, so inline code is a chip.
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InlineCodeChip(text: entityText, style: baseStyle),
        );
      case TextEntityType.codeBlock:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: CodeBlock(
            text: entityText,
            language: entity.language,
            style: baseStyle,
          ),
        );
      case TextEntityType.blockQuote:
      case TextEntityType.expandableBlockQuote:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: QuoteBlock(text: entityText, style: baseStyle),
        );
      case TextEntityType.url:
      case TextEntityType.textUrl:
        final tapUrl = entity.url ?? entityText;
        return TextSpan(
          text: display,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkTap(context, tapUrl),
        );
      case TextEntityType.mention:
        return TextSpan(
          text: display,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleMentionTap(context, entityText),
        );
      case TextEntityType.mentionName:
        final userId = entity.userId;
        if (userId == null) {
          return TextSpan(text: display, style: accentStyle);
        }
        return TextSpan(
          text: display,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => openUserProfile(context, userId),
        );
      case TextEntityType.emailAddress:
        return TextSpan(
          text: display,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkTap(context, 'mailto:$entityText'),
        );
      case TextEntityType.phoneNumber:
        return TextSpan(
          text: display,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkTap(
              context,
              'tel:${entityText.replaceAll(' ', '')}',
            ),
        );
      case TextEntityType.mediaTimestamp:
        final seconds = entity.mediaTimestamp;
        final onTap = onMediaTimestampTap;
        if (seconds == null || onTap == null) {
          return TextSpan(text: display, style: baseStyle);
        }
        return TextSpan(
          text: display,
          style: accentStyle,
          recognizer: TapGestureRecognizer()..onTap = () => onTap(seconds),
        );
      case TextEntityType.cashtag:
      case TextEntityType.botCommand:
      case TextEntityType.bankCardNumber:
        // Nothing acts on these, so they are not styled as links.
        return TextSpan(text: display, style: baseStyle);
      case TextEntityType.hashtag:
        if (onHashtagTap == null) {
          return TextSpan(text: display, style: baseStyle);
        }
        return TextSpan(
          text: display,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => onHashtagTap!(entityText),
        );
      case TextEntityType.spoiler:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SpoilerWidget(text: entityText, style: baseStyle),
        );
      case TextEntityType.customEmoji:
        final emojiId = int.tryParse(entity.customEmojiId ?? '');
        if (emojiId == null) {
          return TextSpan(text: display, style: baseStyle);
        }
        // The custom emoji once it resolves, the plain character until then.
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: CustomEmojiGlyph(
            customEmojiId: emojiId,
            fallbackText: entityText,
            size: (baseStyle.fontSize ?? 15) * 1.25,
          ),
        );
      case TextEntityType.unknown:
        return TextSpan(text: display, style: baseStyle);
    }
  }

  Future<void> _handleLinkTap(BuildContext context, String rawUrl) async {
    try {
      final uri = normalizeUrl(rawUrl);

      // Telegram links open in the app, as a link from outside would: the
      // shell resolves who or what it names, and a link to a message opens
      // at that message. A guest can't resolve, so it opens the channel.
      final link = TelegramLinks.parse(uri);
      if (link != null) {
        final container = ProviderScope.containerOf(context, listen: false);
        if (!container.read(isGuestModeProvider)) {
          container.read(pendingDeepLinkProvider.notifier).offer(uri);
          return;
        }
        // The name from the parsed link: reading the path's first segment
        // opened channels called "s", "joinchat" and "+hash". Invite and
        // private links open in Telegram.
        final username = switch (link) {
          TelegramChannelLink(:final username) => username,
          TelegramPostLink(:final username) => username,
          _ => null,
        };
        if (username != null) {
          NavigationUtils.openChannel(context, username);
          return;
        }
      }

      await openExternalUrl(uri);
    } catch (e) {
      debugPrint('[TextEntityRenderer] Could not launch URL $rawUrl: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.linkCouldNotOpen(rawUrl)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleMentionTap(BuildContext context, String mention) async {
    final username = mention.replaceFirst('@', '').trim();
    if (username.isEmpty) return;

    final handler = onMentionTap;
    if (handler != null) {
      handler(username);
      return;
    }
    await openMention(context, username);
  }
}

/// Telegram's spoiler: text under a cover until tapped. The cover shows an eye
/// (and a word, when it fits) so it doesn't look like an image that failed.
class SpoilerWidget extends StatefulWidget {
  final String text;
  final TextStyle style;

  const SpoilerWidget({super.key, required this.text, required this.style});

  @override
  State<SpoilerWidget> createState() => _SpoilerWidgetState();
}

class _SpoilerWidgetState extends State<SpoilerWidget> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverColor = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    final hintColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    // Only a cover spanning most of a line has room for the word.
    final showsWord = widget.text.length > 24;

    return Semantics(
      button: true,
      label: _revealed ? widget.text : AppStrings.spoilerTapToReveal,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => setState(() => _revealed = !_revealed),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _revealed ? Colors.transparent : coverColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                widget.text,
                textDirection: firstStrongDirection(widget.text),
                style: widget.style.copyWith(
                  color: _revealed ? widget.style.color : Colors.transparent,
                ),
              ),
              if (!_revealed)
                Positioned.fill(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 14,
                          color: hintColor,
                        ),
                        if (showsWord) ...[
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.spoilerLabel,
                            style: widget.style.copyWith(
                              color: hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monospaced text inside a sentence, as a padded chip.
class InlineCodeChip extends StatelessWidget {
  final String text;
  final TextStyle style;

  const InlineCodeChip({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: style.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Courier'],
          fontSize: (style.fontSize ?? 15) * 0.92,
        ),
      ),
    );
  }
}

/// A fenced code block: full width, copyable, scrolling sideways.
class CodeBlock extends StatelessWidget {
  final String text;
  final String? language;
  final TextStyle style;

  const CodeBlock({
    super.key,
    required this.text,
    required this.style,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final codeStyle = style.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier'],
      fontSize: (style.fontSize ?? 15) * 0.92,
      height: 1.4,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  language?.isNotEmpty == true
                      ? language!
                      : AppStrings.codeBlockLabel,
                  style: AppTypography.actionCount(color: secondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                tooltip: AppStrings.codeBlockCopy,
                icon: Icon(Icons.copy_rounded, color: secondary),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: text));
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.codeBlockCopied),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Text(text, style: codeStyle),
          ),
        ],
      ),
    );
  }
}

/// Telegram's block quote. Collapses on the same rule as the post body, since
/// the post's `maxLines` does not reach inside a widget span.
class QuoteBlock extends StatefulWidget {
  final String text;
  final TextStyle style;

  const QuoteBlock({super.key, required this.text, required this.style});

  @override
  State<QuoteBlock> createState() => _QuoteBlockState();
}

class _QuoteBlockState extends State<QuoteBlock> {
  bool _expanded = false;

  @override
  void didUpdateWidget(QuoteBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled card showing a different post starts collapsed.
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final clampable = shouldClampText(
      widget.text,
      maxLines: kCollapsedQuoteLines,
    );
    final collapsed = clampable && !_expanded;
    final label = _expanded ? AppStrings.postShowLess : AppStrings.postShowMore;

    // A quote in Persian has its bar on the right.
    final direction = firstStrongDirection(widget.text);
    final quote = Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.sm,
        top: 2,
        bottom: 2,
      ),
      decoration: const BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.text,
            maxLines: collapsed ? kCollapsedQuoteLines : null,
            overflow: collapsed ? TextOverflow.ellipsis : null,
            style: widget.style.copyWith(fontStyle: FontStyle.italic),
          ),
          if (clampable)
            Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Text(
                    label,
                    style: AppTypography.actionCount(
                      color: secondary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return direction == null
        ? quote
        : Directionality(textDirection: direction, child: quote);
  }
}
