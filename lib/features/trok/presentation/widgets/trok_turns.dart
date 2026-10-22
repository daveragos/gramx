import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/core/text/text_direction.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/trok/data/trok_source_previews.dart';
import 'package:gramx/features/trok/data/trok_citations.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_picture.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_style.dart';

/// The reader's question, on the right, under the post it is about.
class TrokQuestionView extends StatelessWidget {
  final TrokQuestion question;

  const TrokQuestionView({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = question.post;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TrokStyle.gutter * 3,
        TrokStyle.gutter,
        TrokStyle.gutter,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (post != null) ...[
            _PostQuote(post: post),
            const SizedBox(height: AppSpacing.xs + 2),
          ],
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md - 2,
            ),
            decoration: BoxDecoration(
              color: TrokStyle.fill(theme),
              borderRadius: BorderRadius.circular(TrokStyle.bubbleRadius),
            ),
            child: SelectableText(
              question.text,
              textDirection: firstStrongDirection(question.text),
              style: AppTypography.bodyLarge(
                color: theme.colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

/// A post a question is about, quoted small. Opens the post.
class _PostQuote extends ConsumerWidget {
  final Post post;

  const _PostQuote({required this.post});

  static const double _pictureSize = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final secondary = TrokStyle.secondary(theme);
    final snippet = (post.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final picture = trokPictureOf(ref, post);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/post/${post.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md - 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(color: TrokStyle.border(theme)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChannelAvatar(
                          title: post.channelTitle,
                          avatarPath: post.channelAvatarUrl,
                          avatarFileId: post.channelAvatarFileId,
                          avatarColorHex: post.channelAvatarColor,
                          radius: 9,
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text(
                            post.channelTitle,
                            style: AppTypography.actionCount(
                              color: theme.colorScheme.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${AppStrings.inlineSeparator}'
                          '${TimeUtils.relativeTime(post.publishedAt)}',
                          style: AppTypography.actionCount(color: secondary),
                        ),
                      ],
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        snippet,
                        textDirection: firstStrongDirection(snippet),
                        style: AppTypography.actionCount(
                          color: theme.colorScheme.onSurface,
                        ).copyWith(height: 1.35),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (picture != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  child: SizedBox.square(
                    dimension: _pictureSize,
                    child: TrokPictureView(picture: picture, markSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Trok's reply: the steps while it thinks, then the text as it arrives, the
/// posts it drew on, and what can be done with it.
class TrokAnswerView extends ConsumerWidget {
  final TrokAnswer answer;

  /// Only the last answer can be regenerated.
  final bool isLast;

  const TrokAnswerView({super.key, required this.answer, required this.isLast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasText = answer.text.isNotEmpty;
    final cited = TrokCitations.number(
      answer.text,
      answer.entities,
      answer.sources,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TrokStyle.gutter,
        AppSpacing.md,
        TrokStyle.gutter,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasText && answer.state.isActive)
            _ThinkingLine(label: answer.steps.lastOrNull)
          else if (answer.steps.isNotEmpty)
            _ThoughtSummary(answer: answer),
          if (hasText)
            Semantics(
              liveRegion: answer.state == TrokAnswerState.streaming,
              child: TextEntityRenderer(
                text: cited.text,
                entities: cited.entities,
                fullWidth: true,
                style: AppTypography.bodyLarge(
                  color: theme.colorScheme.onSurface,
                ).copyWith(fontWeight: FontWeight.w400, height: 1.45),
              ),
            ),
          if (answer.state == TrokAnswerState.streaming)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: _StreamingDot(),
            ),
          if (answer.sources.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _SourceStrip(sources: answer.sources),
          ],
          if (answer.state == TrokAnswerState.failed)
            _Failed(
              message: answer.failure?.message ?? AppStrings.trokFailed,
              onRetry: isLast && (answer.failure?.canRetry ?? true)
                  ? () => _regenerate(ref)
                  : null,
            )
          else if (!answer.state.isActive)
            _AnswerActions(
              answer: answer,
              onRegenerate: isLast ? () => _regenerate(ref) : null,
            ),
        ],
      ),
    );
  }

  void _regenerate(WidgetRef ref) {
    HapticFeedback.lightImpact();
    ref.read(trokControllerProvider.notifier).regenerate();
  }
}

/// What Trok is doing before any text: its eye looking around, and the step.
class _ThinkingLine extends StatelessWidget {
  final String? label;

  const _ThinkingLine({required this.label});

  @override
  Widget build(BuildContext context) {
    final secondary = TrokStyle.secondary(Theme.of(context));

    return Semantics(
      liveRegion: true,
      label: AppStrings.a11yTrokThinking,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            const TrokMark(size: 26, motion: TrokMarkMotion.thinking),
            const SizedBox(width: AppSpacing.sm + 2),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _Shimmer(
                  key: ValueKey(label),
                  child: Text(
                    label ?? AppStrings.trokThinking,
                    style: AppTypography.body(color: secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A light passing over its child, for text that is still in progress.
class _Shimmer extends StatefulWidget {
  final Widget child;

  const _Shimmer({super.key, required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlight = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _sweep,
      child: widget.child,
      builder: (context, child) {
        final t = _sweep.value * 3 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.transparent,
              highlight.withValues(alpha: 0.85),
              Colors.transparent,
            ],
            stops: [
              (t - 0.3).clamp(0.0, 1.0),
              t.clamp(0.0, 1.0),
              (t + 0.3).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// "Thought for 3 seconds", which opens to the steps Trok took.
class _ThoughtSummary extends StatefulWidget {
  final TrokAnswer answer;

  const _ThoughtSummary({required this.answer});

  @override
  State<_ThoughtSummary> createState() => _ThoughtSummaryState();
}

class _ThoughtSummaryState extends State<_ThoughtSummary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final secondary = TrokStyle.secondary(Theme.of(context));
    final seconds = widget.answer.thoughtFor?.inSeconds ?? 0;
    final style = AppTypography.actionCount(color: secondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TrokMark(size: 18, color: secondary),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    AppStrings.trokThoughtFor(seconds),
                    style: style.copyWith(fontWeight: FontWeight.w600),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      top: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final step in widget.answer.steps)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxs + 1,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: secondary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: Text(step, style: style)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pulses at the end of an answer that is still arriving.
class _StreamingDot extends StatefulWidget {
  const _StreamingDot();

  @override
  State<_StreamingDot> createState() => _StreamingDotState();
}

class _StreamingDotState extends State<_StreamingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.a11yTrokAnswering,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// The posts and pages an answer drew on, side by side, each a peek of
/// what it shows.
class _SourceStrip extends ConsumerWidget {
  final List<TrokSource> sources;

  const _SourceStrip({required this.sources});

  static const double _height = 200;

  /// For a strip with no pictures, which would leave space under the words.
  static const double _compactHeight = 116;
  static const double _width = 232;

  static bool _hasPicture(WidgetRef ref, TrokSource source) => switch (source) {
    TrokPostSource() => _PostSourceCard.pictureOf(ref, source) != null,
    TrokWebSource(:final url) =>
      ref.watch(trokLinkPreviewProvider(url)).value?.imageFileId != null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = TrokStyle.secondary(Theme.of(context));
    final compact = !sources.any((s) => _hasPicture(ref, s));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article_outlined, size: 15, color: secondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppStrings.trokSourceCount(sources.length),
              style: AppTypography.actionCount(
                color: secondary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: compact ? _compactHeight : _height,
          // Bleeds to the screen edges, so cards scroll off them.
          child: OverflowBox(
            maxWidth: MediaQuery.sizeOf(context).width,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-TrokStyle.gutter, 0),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: TrokStyle.gutter,
                ),
                itemCount: sources.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: _width,
                  child: switch (sources[index]) {
                    final TrokPostSource post => _PostSourceCard(
                      source: post,
                      number: index + 1,
                      compact: compact,
                    ),
                    final TrokWebSource web => _WebSourceCard(
                      source: web,
                      number: index + 1,
                      compact: compact,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A post: its picture, channel and text, as the post shows them.
class _PostSourceCard extends ConsumerWidget {
  final TrokPostSource source;

  /// Its number, as the answer's citations of it show.
  final int number;
  final bool compact;

  const _PostSourceCard({
    required this.source,
    required this.number,
    required this.compact,
  });

  void _open(BuildContext context, WidgetRef ref) {
    final postId = source.postId;
    if (postId != null) {
      context.push('/post/$postId');
      return;
    }
    // A post only Trok found opens as its t.me link would.
    final link = Uri.tryParse(source.link ?? '');
    if (link != null) ref.read(pendingDeepLinkProvider.notifier).offer(link);
  }

  /// The post itself, for one Trok sent without its picture: a post only
  /// Trok found, or one History rebuilt.
  static Post? _lookUp(WidgetRef ref, TrokPostSource source) {
    final id =
        source.postId ??
        switch (source.link) {
          final link? => ref.watch(trokLinkedPostIdProvider(link)).value,
          null => null,
        };
    return id == null ? null : ref.watch(postDetailProvider(id)).value;
  }

  /// [source]'s picture, looked up when Trok sent none.
  static TrokSourcePicture? pictureOf(WidgetRef ref, TrokPostSource source) {
    if (source.picture case final picture?) return picture;
    final post = _lookUp(ref, source);
    return post == null ? null : TrokSourcePicture.of(post);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = TrokStyle.secondary(Theme.of(context));
    final post = source.picture == null ? _lookUp(ref, source) : null;
    final picture =
        source.picture ?? (post == null ? null : TrokSourcePicture.of(post));
    final title = switch (post?.channelTitle) {
      final title? when title.isNotEmpty => title,
      _ => source.channelTitle,
    };
    final text = source.snippet.isNotEmpty
        ? source.snippet
        : (post?.text ?? '').trim();
    final publishedAt = source.publishedAt ?? post?.publishedAt;

    return _SourceFrame(
      onTap: () => _open(context, ref),
      number: number,
      compact: compact,
      picture: picture,
      leading: ChannelAvatar(
        title: title,
        avatarPath: post?.channelAvatarUrl ?? source.avatarPath,
        avatarFileId: post?.channelAvatarFileId ?? source.avatarFileId,
        avatarColorHex: post?.channelAvatarColor ?? source.avatarColorHex,
        radius: 10,
      ),
      title: title,
      trailing: publishedAt == null
          ? null
          : Text(
              TimeUtils.relativeTime(publishedAt),
              style: AppTypography.actionCount(color: secondary),
            ),
      // A picture says enough on its own.
      body: text.isNotEmpty || picture != null
          ? text.replaceAll(RegExp(r'\s+'), ' ')
          : AppStrings.trokSourceMediaOnly,
    );
  }
}

/// A web page Trok read: its picture, site and title, as Telegram previews
/// the link.
class _WebSourceCard extends ConsumerWidget {
  final TrokWebSource source;
  final int number;
  final bool compact;

  const _WebSourceCard({
    required this.source,
    required this.number,
    required this.compact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = TrokStyle.secondary(Theme.of(context));
    final preview = ref.watch(trokLinkPreviewProvider(source.url)).value;
    final pictureId = preview?.imageFileId;
    final picture = pictureId == null
        ? null
        : TrokSourcePicture(fileId: pictureId);
    final description = preview?.description.trim() ?? '';

    return _SourceFrame(
      onTap: () {
        final uri = Uri.tryParse(source.url);
        if (uri != null) unawaited(openExternalUrl(uri));
      },
      number: number,
      compact: compact,
      picture: picture,
      leading: Icon(Icons.public_rounded, size: 20, color: secondary),
      title: source.site,
      body: source.title,
      // Room for the page's own words when it has no picture.
      more: picture == null && description.isNotEmpty ? description : null,
    );
  }
}

/// A source card's shape: a picture across the top when it has one, who or
/// where under it, then a few lines. Without a picture the lines take its
/// place.
class _SourceFrame extends StatelessWidget {
  final VoidCallback onTap;

  /// Shown before the title, matching the answer's citations.
  final int number;

  /// In a strip with no pictures, which holds three lines of words.
  final bool compact;
  final TrokSourcePicture? picture;
  final Widget leading;
  final String title;
  final Widget? trailing;
  final String body;

  /// Lighter lines under [body].
  final String? more;

  const _SourceFrame({
    required this.onTap,
    required this.number,
    required this.compact,
    required this.leading,
    required this.title,
    required this.body,
    this.picture,
    this.trailing,
    this.more,
  });

  static const double _pictureHeight = 112;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picture = this.picture;
    final more = this.more;
    final style = AppTypography.actionCount(
      color: theme.colorScheme.onSurface,
    ).copyWith(height: 1.35);

    return Material(
      color: TrokStyle.fill(theme),
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (picture != null)
              SizedBox(
                height: _pictureHeight,
                child: TrokPictureView(picture: picture),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SourceNumber(number: number),
                        const SizedBox(width: AppSpacing.xs + 2),
                        leading,
                        const SizedBox(width: AppSpacing.xs + 2),
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.actionCount(
                              color: theme.colorScheme.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trailing case final trailing?) ...[
                          const SizedBox(width: AppSpacing.xs),
                          trailing,
                        ],
                      ],
                    ),
                    if (body.isNotEmpty || more != null) ...[
                      const SizedBox(height: AppSpacing.xs + 2),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: body),
                              if (more != null)
                                TextSpan(
                                  text: '\n$more',
                                  style: style.copyWith(
                                    color: TrokStyle.secondary(theme),
                                  ),
                                ),
                            ],
                          ),
                          textDirection: firstStrongDirection(body),
                          style: style,
                          maxLines: picture != null
                              ? 2
                              : compact
                              ? 3
                              : 8,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

/// A source card's number, in a small circle.
class _SourceNumber extends StatelessWidget {
  final int number;

  const _SourceNumber({required this.number});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TrokStyle.border(theme),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$number',
        style: AppTypography.actionCount(
          color: theme.colorScheme.onSurface,
        ).copyWith(fontSize: 11, fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }
}

/// Copy and regenerate under a finished answer.
class _AnswerActions extends StatelessWidget {
  final TrokAnswer answer;
  final VoidCallback? onRegenerate;

  const _AnswerActions({required this.answer, required this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    final secondary = TrokStyle.secondary(Theme.of(context));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          if (answer.text.isNotEmpty)
            _ActionIcon(
              icon: Icons.copy_rounded,
              tooltip: AppStrings.trokCopy,
              color: secondary,
              onTap: () {
                Clipboard.setData(ClipboardData(text: answer.text));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.trokCopied),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          if (onRegenerate != null)
            _ActionIcon(
              icon: Icons.refresh_rounded,
              tooltip: AppStrings.trokRegenerate,
              color: secondary,
              onTap: onRegenerate!,
            ),
          if (answer.state == TrokAnswerState.stopped) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppStrings.trokStopped,
              style: AppTypography.actionCount(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      // Lines the first icon up with the answer's text.
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      style: IconButton.styleFrom(alignment: Alignment.centerLeft),
      icon: Icon(icon, size: 18, color: color),
      onPressed: onTap,
    );
  }
}

class _Failed extends StatelessWidget {
  /// Trok's own words for what went wrong, when it said.
  final String message;
  final VoidCallback? onRetry;

  const _Failed({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body(color: AppColors.error),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text(AppStrings.trokRetry),
            ),
        ],
      ),
    );
  }
}

/// Questions to ask next, under the last finished answer.
class TrokFollowUpList extends ConsumerWidget {
  final List<String> followUps;

  const TrokFollowUpList({super.key, required this.followUps});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final secondary = TrokStyle.secondary(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TrokStyle.gutter,
        AppSpacing.xs,
        TrokStyle.gutter,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final followUp in followUps)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(trokControllerProvider.notifier).ask(followUp);
                  },
                  child: Ink(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.pillRadius,
                      ),
                      border: Border.all(color: TrokStyle.border(theme)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 16,
                          color: secondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            followUp,
                            textDirection: firstStrongDirection(followUp),
                            style: AppTypography.body(
                              color: theme.colorScheme.onSurface,
                            ).copyWith(fontWeight: FontWeight.w400),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
