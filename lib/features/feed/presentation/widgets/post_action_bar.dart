import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/app_glyphs.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/forward_sheet.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_control.dart';

class PostActionBar extends ConsumerWidget {
  final Post post;
  final Color secondaryColor;
  final VoidCallback onBookmarkTap;
  final ValueChanged<String> onSelectReaction;
  final VoidCallback onReplyTap;
  final VoidCallback onShareTap;

  /// An extra control at the end of the row, such as the media viewer's
  /// "open with".
  final Widget? trailing;

  /// Opens the post's statistics. Set only where Telegram reports they exist
  /// (see `StatsRepository.canViewPostStats`); otherwise the view count is a
  /// plain figure.
  final VoidCallback? onViewsTap;

  /// The post page's bar: larger icons spread across the page, and no view
  /// count, which the page shows by the time instead.
  final bool spread;

  /// The video player's bar: each action in a dark pill, as over a video.
  final bool pills;

  /// The icons' size, and the bar's height, which the icons sit in the
  /// middle of.
  static const double iconSize = 18.75;
  static const double height = 40;

  /// How far the actions' tap areas reach above and below the icons. The bar
  /// is this much taller than its row of icons on each side, so callers take
  /// it off the space around it.
  static const double touchSlop = (height - iconSize) / 2;

  /// The [spread] bar's icons and height.
  static const double spreadIconSize = 25.4;
  static const double spreadHeight = 56;

  /// Between the bookmark and share icons.
  static const double _endGap = 15;

  const PostActionBar({
    super.key,
    required this.post,
    required this.secondaryColor,
    required this.onBookmarkTap,
    required this.onSelectReaction,
    required this.onReplyTap,
    required this.onShareTap,
    this.trailing,
    this.onViewsTap,
    this.spread = false,
    this.pills = false,
  });

  Future<void> _forward(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await ForwardSheet.show(context, post);
    if (!sent) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.forwardSent(post.channelTitle)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A guest can't act on posts, so the counts stay and the actions prompt
    // them to sign in.
    final can = ref.watch(readerCapabilitiesProvider);

    if (pills) return _pillRow(context, can);

    final m = spread ? _Metrics.spread : _Metrics.feed;
    final cellPadding = EdgeInsets.symmetric(vertical: m.touchSlop);

    final bookmark = _IconAction(
      glyph: AppGlyphs.bookmark,
      filled: post.isBookmarked,
      color: post.isBookmarked ? AppColors.accent : secondaryColor,
      size: m.iconSize,
      semanticLabel: post.isBookmarked
          ? AppStrings.a11yBookmarkRemove
          : AppStrings.a11yBookmarkAdd,
      padding: spread
          ? EdgeInsetsDirectional.fromSTEB(0, m.touchSlop, 24, m.touchSlop)
          : EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              m.touchSlop,
              _endGap / 2,
              m.touchSlop,
            ),
      onTap: onBookmarkTap,
    );

    // Four equal cells with their icons at the start, then the rest at the
    // end, a little over the last cell.
    final counted = Padding(
      padding: EdgeInsetsDirectional.only(end: m.trailingRoom),
      child: Row(
        children: [
          Expanded(
            child: can.canComment
                ? PostActionButton(
                    glyph: AppGlyphs.reply,
                    count: spread ? 0 : post.replyCount,
                    color: secondaryColor,
                    activeColor: AppColors.reply,
                    iconSize: m.iconSize,
                    touchSlop: m.touchSlop,
                    semanticLabel: AppStrings.a11yReplyWithCount(
                      post.replyCount,
                    ),
                    onTap: onReplyTap,
                  )
                : PostStat(
                    glyph: AppGlyphs.reply,
                    count: spread ? 0 : post.replyCount,
                    color: secondaryColor,
                    iconSize: m.iconSize,
                    touchSlop: m.touchSlop,
                    semanticLabel: AppStrings.a11yReplyWithCount(
                      post.replyCount,
                    ),
                  ),
          ),
          Expanded(
            child: can.canForward
                ? PostActionButton(
                    glyph: AppGlyphs.repost,
                    count: post.forwardCount,
                    color: secondaryColor,
                    activeColor: AppColors.repost,
                    iconSize: m.iconSize,
                    touchSlop: m.touchSlop,
                    semanticLabel: AppStrings.a11yForward,
                    onTap: () => _forward(context),
                  )
                : PostStat(
                    glyph: AppGlyphs.repost,
                    count: post.forwardCount,
                    color: secondaryColor,
                    iconSize: m.iconSize,
                    touchSlop: m.touchSlop,
                    semanticLabel: AppStrings.a11yForward,
                  ),
          ),
          // Tap toggles the user's reaction, long press picks another. Guests
          // see the counts without being able to react.
          Expanded(
            child: can.canReact
                ? ReactionControl(
                    post: post,
                    color: secondaryColor,
                    onSelectReaction: onSelectReaction,
                    iconSize: m.iconSize,
                    hitPadding: cellPadding,
                  )
                : PostStat(
                    glyph: AppGlyphs.like,
                    count: post.reactions.values.fold(0, (a, b) => a + b),
                    color: secondaryColor,
                    iconSize: m.iconSize,
                    touchSlop: m.touchSlop,
                    semanticLabel: AppStrings.a11yReactionsReadOnly,
                  ),
          ),
          Expanded(
            child: spread
                ? (can.canBookmark
                      ? Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: bookmark,
                        )
                      : const SizedBox.shrink())
                // View count: a button only where statistics can be opened.
                : onViewsTap != null
                ? PostActionButton(
                    glyph: AppGlyphs.views,
                    count: post.viewCount,
                    color: secondaryColor,
                    activeColor: AppColors.accent,
                    iconSize: m.iconSize,
                    touchSlop: m.touchSlop,
                    semanticLabel: AppStrings.a11yPostAnalytics,
                    onTap: onViewsTap,
                  )
                : PostStat(
                    glyph: AppGlyphs.views,
                    count: post.viewCount,
                    color: secondaryColor,
                    iconSize: m.iconSize,
                    touchSlop: m.touchSlop,
                    semanticLabel: AppStrings.a11yViews,
                  ),
          ),
        ],
      ),
    );

    final ends = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!spread && can.canBookmark) bookmark,
        _IconAction(
          glyph: AppGlyphs.share,
          color: secondaryColor,
          size: m.iconSize,
          semanticLabel: AppStrings.a11yCopyLink,
          // Flush with the column's edge, like the reply icon at the start.
          padding: EdgeInsetsDirectional.fromSTEB(
            spread ? AppSpacing.lg : _endGap / 2,
            m.touchSlop,
            trailing == null ? 0 : AppSpacing.sm,
            m.touchSlop,
          ),
          onTap: onShareTap,
        ),
      ],
    );

    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              counted,
              // Over the last cell's spare end, so its taps go to these.
              PositionedDirectional(top: 0, bottom: 0, end: 0, child: ends),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

extension on PostActionBar {
  /// Reply, repost and like in wide pills, then bookmark and share in round
  /// ones, across the width.
  Widget _pillRow(BuildContext context, ReaderCapabilities can) {
    const iconSize = 20.0;
    const gap = 8.4;

    Widget counted(Widget child) => Expanded(child: _Pill(child: child));

    return Row(
      children: [
        counted(
          PostActionButton(
            glyph: AppGlyphs.reply,
            count: post.replyCount,
            color: secondaryColor,
            activeColor: AppColors.reply,
            iconSize: iconSize,
            touchSlop: 0,
            centered: true,
            semanticLabel: AppStrings.a11yReplyWithCount(post.replyCount),
            onTap: can.canComment ? onReplyTap : null,
          ),
        ),
        const SizedBox(width: gap),
        counted(
          PostActionButton(
            glyph: AppGlyphs.repost,
            count: post.forwardCount,
            color: secondaryColor,
            activeColor: AppColors.repost,
            iconSize: iconSize,
            touchSlop: 0,
            centered: true,
            semanticLabel: AppStrings.a11yForward,
            onTap: can.canForward ? () => _forward(context) : null,
          ),
        ),
        const SizedBox(width: gap),
        counted(
          can.canReact
              ? Center(
                  child: ReactionControl(
                    post: post,
                    color: secondaryColor,
                    onSelectReaction: onSelectReaction,
                    iconSize: iconSize,
                  ),
                )
              : PostStat(
                  glyph: AppGlyphs.like,
                  count: post.reactions.values.fold(0, (a, b) => a + b),
                  color: secondaryColor,
                  iconSize: iconSize,
                  touchSlop: 0,
                  centered: true,
                  semanticLabel: AppStrings.a11yReactionsReadOnly,
                ),
        ),
        if (can.canBookmark) ...[
          const SizedBox(width: gap),
          _Pill(
            width: _Pill.height,
            child: _IconAction(
              glyph: AppGlyphs.bookmark,
              filled: post.isBookmarked,
              color: post.isBookmarked ? AppColors.accent : secondaryColor,
              size: iconSize,
              semanticLabel: post.isBookmarked
                  ? AppStrings.a11yBookmarkRemove
                  : AppStrings.a11yBookmarkAdd,
              padding: EdgeInsets.zero,
              onTap: onBookmarkTap,
            ),
          ),
        ],
        const SizedBox(width: gap),
        _Pill(
          width: _Pill.height,
          child: _IconAction(
            glyph: AppGlyphs.share,
            color: secondaryColor,
            size: iconSize,
            semanticLabel: AppStrings.a11yCopyLink,
            padding: EdgeInsets.zero,
            onTap: onShareTap,
          ),
        ),
      ],
    );
  }
}

/// A dark, rounded holder for one action over a video.
class _Pill extends StatelessWidget {
  static const double height = 38;

  final Widget child;
  final double? width;

  const _Pill({required this.child, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xB30F1419),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// The sizes of one of the bar's two forms.
class _Metrics {
  final double iconSize;
  final double height;

  /// Kept free at the end of the four cells, which the end actions overlap
  /// a little.
  final double trailingRoom;

  const _Metrics({
    required this.iconSize,
    required this.height,
    required this.trailingRoom,
  });

  double get touchSlop => (height - iconSize) / 2;

  static const feed = _Metrics(
    iconSize: PostActionBar.iconSize,
    height: PostActionBar.height,
    trailingRoom: 46,
  );

  static const spread = _Metrics(
    iconSize: PostActionBar.spreadIconSize,
    height: PostActionBar.spreadHeight,
    trailingRoom: 18.7,
  );
}

/// Bookmark and share: an icon with no count, in a tap area larger than it.
class _IconAction extends StatelessWidget {
  final AppGlyphs glyph;
  final bool filled;
  final Color color;
  final double size;
  final String semanticLabel;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;

  const _IconAction({
    required this.glyph,
    this.filled = false,
    required this.color,
    required this.size,
    required this.semanticLabel,
    required this.padding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: padding,
          child: Glyph(glyph, color: color, filled: filled, size: size),
        ),
      ),
    );
  }
}

/// An action's icon and count, at the start of a cell that is all tap area.
class _CellContent extends StatelessWidget {
  final AppGlyphs glyph;
  final int count;
  final Color color;
  final double iconSize;
  final double touchSlop;
  final bool centered;

  const _CellContent({
    required this.glyph,
    required this.iconSize,
    required this.touchSlop,
    this.centered = false,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The cell reaches the bar's top and bottom.
      padding: EdgeInsets.symmetric(vertical: touchSlop),
      child: Align(
        alignment: centered
            ? AlignmentDirectional.center
            : AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Glyph(glyph, color: color, size: iconSize),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  TimeUtils.formatCount(count),
                  style: AppTypography.actionBarCount(color: color),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A read-only figure in the action bar, with no touch feedback.
class PostStat extends StatelessWidget {
  final AppGlyphs glyph;
  final int count;
  final Color color;
  final double iconSize;
  final double touchSlop;
  final bool centered;
  final String semanticLabel;

  const PostStat({
    super.key,
    required this.glyph,
    required this.count,
    required this.color,
    this.iconSize = PostActionBar.iconSize,
    this.touchSlop = PostActionBar.touchSlop,
    this.centered = false,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.a11yCountedAction(count, semanticLabel),
      excludeSemantics: true,
      child: _CellContent(
        glyph: glyph,
        count: count,
        color: color,
        iconSize: iconSize,
        touchSlop: touchSlop,
        centered: centered,
      ),
    );
  }
}

class PostActionButton extends StatelessWidget {
  final AppGlyphs glyph;
  final int count;
  final Color color;
  final double iconSize;
  final double touchSlop;
  final bool centered;
  final Color activeColor;
  final VoidCallback? onTap;

  /// Screen reader label for the icon-only control.
  final String? semanticLabel;

  const PostActionButton({
    super.key,
    required this.glyph,
    required this.count,
    required this.color,
    this.iconSize = PostActionBar.iconSize,
    this.touchSlop = PostActionBar.touchSlop,
    this.centered = false,
    required this.activeColor,
    this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);
    if (semanticLabel == null) return button;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: button,
    );
  }

  Widget _buildButton(BuildContext context) {
    return GestureDetector(
      // The whole cell answers, not just the icon.
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap!();
        }
      },
      child: _CellContent(
        glyph: glyph,
        count: count,
        color: color,
        iconSize: iconSize,
        touchSlop: touchSlop,
        centered: centered,
      ),
    );
  }
}
