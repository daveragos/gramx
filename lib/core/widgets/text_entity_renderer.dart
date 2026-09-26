import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/core/text/text_clamp.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/feed/presentation/widgets/custom_emoji_span.dart';

class TextEntityRenderer extends StatelessWidget {
  final String text;
  final List<TextEntity> entities;
  final TextStyle? style;

  /// Clamp the rendered text to this many lines. Null renders in full.
  final int? maxLines;

  /// Colour for links, mentions, hashtags — anything this renderer styles as
  /// tappable.
  ///
  /// except one: an outgoing message bubble, which *is* that blue. A mention
  /// rendered in accent on accent is invisible, so the bubble passes its own
  /// foreground colour instead.
  final Color? linkColor;

  /// Called when an `@name` is tapped, instead of this widget deciding.
  ///
  /// The default assumes a mention is a *channel* and pushes the channel screen
  /// — which is right in a feed, where every mention is one, and wrong in a
  /// conversation, where most are people. Resolving which reaches Telegram, and
  /// `core/` must not; so the caller that can, does.
  final ValueChanged<String>? onMentionTap;

  /// Called when a hashtag is tapped.
  ///
  /// Supplied by the caller rather than handled here: `core/` must not reach
  /// into a feature's providers. Null leaves hashtags styled as plain text, so
  /// they never look tappable when they aren't.
  final ValueChanged<String>? onHashtagTap;

  /// Whether a long press selects text. On by default, and off in a chat
  /// bubble: there the long press is the way into the message's actions —
  /// reply, edit, forward, delete — and a selectable field swallowed it, so
  /// holding the words of a message opened the system's Copy/Share bar and
  /// nothing of this app's. The bubble's own menu has "Copy text".
  final bool selectable;

  const TextEntityRenderer({
    super.key,
    required this.text,
    required this.entities,
    this.onHashtagTap,
    this.style,
    this.maxLines,
    this.linkColor,
    this.onMentionTap,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle =
        style ?? AppTypography.body(color: theme.colorScheme.onSurface);

    if (entities.isEmpty) {
      if (maxLines != null) {
        return Text(
          text,
          style: defaultStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      }
      return selectable
          ? SelectableText(text, style: defaultStyle)
          : Text(text, style: defaultStyle);
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
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, entity.offset),
            style: defaultStyle,
          ),
        );
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
      spans.add(
        TextSpan(text: text.substring(currentIndex), style: defaultStyle),
      );
    }

    // Clamped text is drawn with Text, not SelectableText. A selectable field
    // with a line limit keeps the rest of the post inside its own scroll view,
    // so a collapsed post could be scrolled through without ever expanding it —
    // and it clips rather than ellipsizing. Text does neither.
    if (maxLines != null) {
      return Text.rich(
        TextSpan(children: spans),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return selectable
        ? SelectableText.rich(TextSpan(children: spans))
        : Text.rich(TextSpan(children: spans));
  }

  InlineSpan _buildEntitySpan(
    BuildContext context,
    TextEntity entity,
    String entityText,
    TextStyle baseStyle,
  ) {
    final accentStyle = baseStyle.copyWith(
      color: linkColor ?? AppColors.accent,
      fontWeight: FontWeight.w500,
      // Set explicitly in both directions, so no inherited underline leaks in.
      //
      // On a coloured bubble the link and the body text are the same colour, so
      // weight alone would have to carry "this is tappable" — and weight alone
      // is not enough. The underline is what keeps it legible there, and it is
      // drawn only when a caller has overridden the colour for that reason.
      decoration: linkColor == null
          ? TextDecoration.none
          : TextDecoration.underline,
      decorationColor: linkColor,
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
        // A background on a TextSpan paints tight against the glyphs with no
        // padding and no corners, which is why inline code read as unstyled
        // text with a grey smear behind it. A real chip is the fix.
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
          text: entityText,
          style: accentStyle,
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
      case TextEntityType.mentionName:
        // Telegram gives a user id rather than a username here, and this app
        // has no user profile screen — so it is coloured, not tappable.
        return TextSpan(text: entityText, style: accentStyle);
      case TextEntityType.emailAddress:
        return TextSpan(
          text: entityText,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkTap(context, 'mailto:$entityText'),
        );
      case TextEntityType.phoneNumber:
        return TextSpan(
          text: entityText,
          style: accentStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkTap(
              context,
              'tel:${entityText.replaceAll(' ', '')}',
            ),
        );
      case TextEntityType.cashtag:
      case TextEntityType.botCommand:
      case TextEntityType.bankCardNumber:
      case TextEntityType.mediaTimestamp:
        // Real marks Telegram applies, but nothing in this app acts on them.
        // Styled plainly rather than dressed up as links that go nowhere.
        return TextSpan(text: entityText, style: baseStyle);
      case TextEntityType.hashtag:
        // Only render as a link when something will actually happen.
        if (onHashtagTap == null) {
          return TextSpan(text: entityText, style: baseStyle);
        }
        return TextSpan(
          text: entityText,
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
          return TextSpan(text: entityText, style: baseStyle);
        }
        // Draws the real artwork once it resolves, and the plain character
        // until then. The old version appended a gold star to every one, which
        // made a post full of premium emoji unreadable.
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: CustomEmojiGlyph(
            customEmojiId: emojiId,
            fallbackText: entityText,
            size: (baseStyle.fontSize ?? 15) * 1.25,
          ),
        );
      case TextEntityType.unknown:
        return TextSpan(text: entityText, style: baseStyle);
    }
  }

  Future<void> _handleLinkTap(BuildContext context, String rawUrl) async {
    try {
      final uri = normalizeUrl(rawUrl);

      // In-app handling for Telegram t.me links
      if (uri.host == 't.me' ||
          uri.host == 'telegram.me' ||
          uri.host == 'www.t.me') {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          if (segments.length == 1) {
            final target = segments.first;
            if (!target.startsWith('c')) {
              NavigationUtils.openChannel(context, target);
              return;
            }
          } else if (segments.length == 2) {
            final first = segments[0];
            final second = segments[1];
            if (first == 'c') {
              NavigationUtils.openChannel(context, second);
              return;
            } else {
              NavigationUtils.openChannel(context, first);
              return;
            }
          }
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
    // No handler: assume a channel, which is what a mention is in a feed.
    NavigationUtils.openChannel(context, username);
  }
}

/// Hidden text, until it is tapped.
///
/// Telegram's spoiler: the words are there, covered. The cover used to be a
/// flat grey bar with nothing on it, which on a card read as a picture that
/// had failed to load — a channel that hides a line of metadata behind one
/// looked broken in every post. The cover now says what it is, with an eye
/// and, where there is room, a word, and it takes the surface colour the rest
/// of the card's boxes use rather than a grey from nowhere.
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
    // A word fits on a cover that spans most of a line; a short spoiler gets
    // the eye alone, which is still a sign that something is under it.
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

/// A fenced code block: full width, scrollable sideways, copyable.
///
/// Code does not wrap — wrapping it is what made pasted snippets unreadable —
/// so the block scrolls horizontally instead.
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

/// A quoted passage — Telegram's block quote, drawn the way it draws it.
///
/// Collapses when it is long, on the same rule the post body uses. Without
/// this a quoted wall of text was rendered whole: the post's own "Show more"
/// could not clamp it, because a quote is a widget inside the paragraph rather
/// than more lines of it, and `maxLines` does not reach inside a widget.
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
    // A recycled card showing a different post must not inherit this one's
    // expanded state.
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2, bottom: 2),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
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
  }
}
