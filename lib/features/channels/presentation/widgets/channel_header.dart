import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/text/plain_text_links.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';
import 'package:gramx/app/widgets/pill_button.dart';

/// The measurements of a channel profile's top, laid out as on X: a cover
/// running up under the status bar, a bar that stays over it, and the avatar
/// overlapping the cover's lower edge with the actions beside it.
class ChannelProfileGeometry {
  /// The status bar's height.
  final double topInset;

  const ChannelProfileGeometry(this.topInset);

  /// The bar's height below the status bar.
  static const double barHeight = 48;

  /// The cover's height below the status bar.
  static const double coverBodyHeight = 104;

  static const double avatarRadius = 40;
  static const double avatarBorder = 4;

  /// How much of the avatar lies over the cover.
  static const double avatarOverlap = 34;

  /// The smallest the avatar gets as it scrolls under the bar.
  static const double avatarMinScale = 0.6;

  /// The bar, from the top of the screen. The page scrolls below it.
  double get barExtent => topInset + barHeight;

  /// The cover, from the top of the screen.
  double get coverExtent => topInset + coverBodyHeight;

  /// The part of the cover below the bar, which scrolls with the page.
  double get coverBelowBar => coverExtent - barExtent;

  static double get avatarDiameter => 2 * (avatarRadius + avatarBorder);

  /// The row under the cover holding the avatar's overhang and the actions.
  static double get bandHeight => avatarDiameter - avatarOverlap + 8;

  /// The height of [ChannelCover], in the page.
  double get coverBlockHeight => coverBelowBar + bandHeight;

  /// How far collapsed the bar is at [offset]: 0 at rest, 1 once the cover
  /// has gone under it.
  double collapse(double offset) =>
      coverBelowBar <= 0 ? 1 : (offset / coverBelowBar).clamp(0.0, 1.0);

  /// How far the bar's title has come in at [offset]. It follows the name
  /// as that scrolls under the bar.
  double titleReveal(double offset) =>
      ((offset - coverBlockHeight - 4) / 28).clamp(0.0, 1.0);
}

/// The scroll offset of [controller], or 0 before it is attached.
double _offsetOf(ScrollController controller) =>
    controller.hasClients ? controller.offset : 0;

/// The top of the page: the cover (painted up under the bar), the avatar on
/// its lower edge, and the bell, share and join buttons beside the avatar.
class ChannelCover extends StatelessWidget {
  final Channel channel;
  final ChannelProfileGeometry geometry;

  /// The page's scroll, which shrinks the avatar and stretches the cover
  /// when pulled past the top.
  final ScrollController scroll;

  final bool isMuted;
  final String muteTooltip;
  final VoidCallback onMutePressed;

  /// Copies the channel's link. Null for a channel without a public one.
  final VoidCallback? onSharePressed;

  final bool isActionBusy;
  final VoidCallback onJoinPressed;

  const ChannelCover({
    super.key,
    required this.channel,
    required this.geometry,
    required this.scroll,
    required this.isMuted,
    required this.muteTooltip,
    required this.onMutePressed,
    required this.onSharePressed,
    required this.isActionBusy,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = geometry;

    return SizedBox(
      height: g.coverBlockHeight,
      child: ListenableBuilder(
        listenable: scroll,
        builder: (context, actions) {
          final offset = _offsetOf(scroll);
          // Pulled down past the top, the cover grows to keep the screen's
          // top edge covered.
          final pull = math.max(0.0, -offset);
          final scale = lerpDouble(
            1,
            ChannelProfileGeometry.avatarMinScale,
            g.collapse(offset),
          )!;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -g.barExtent - pull,
                left: 0,
                right: 0,
                height: g.coverExtent + pull,
                child: ChannelCoverImage(channel: channel),
              ),
              Positioned(
                left: AppSpacing.postPadding,
                top: g.coverBelowBar - ChannelProfileGeometry.avatarOverlap,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.all(
                      ChannelProfileGeometry.avatarBorder,
                    ),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: ChannelAvatar(
                      title: channel.title,
                      avatarPath: channel.avatarUrl,
                      avatarFileId: channel.avatarFileId,
                      avatarColorHex: channel.avatarColor,
                      radius: ChannelProfileGeometry.avatarRadius,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.postPadding,
                top: g.coverBelowBar + AppSpacing.md,
                child: actions!,
              ),
            ],
          );
        },
        // The actions don't move with the scroll, so they're built once.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OutlinedCircleButton(
              icon: isMuted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_none_rounded,
              color: isMuted ? AppColors.error : null,
              tooltip: muteTooltip,
              onPressed: onMutePressed,
            ),
            if (onSharePressed != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _OutlinedCircleButton(
                icon: Icons.ios_share,
                tooltip: AppStrings.a11yCopyChannelLink,
                onPressed: onSharePressed!,
              ),
            ],
            const SizedBox(width: AppSpacing.sm),
            PillButton(
              label: channel.isJoined
                  ? AppStrings.channelJoinedAction
                  : AppStrings.channelJoinAction,
              // Filled until joined, then outlined.
              style: channel.isJoined ? PillStyle.outlined : PillStyle.filled,
              isBusy: isActionBusy,
              onPressed: onJoinPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar over the page: back and analytics on round buttons, as on X.
/// Clear over the cover at first; once the cover has gone under it, it shows
/// the cover blurred, and the channel's name as the name scrolls away.
class ChannelProfileBar extends StatelessWidget {
  final Channel channel;
  final ChannelProfileGeometry geometry;
  final ScrollController scroll;

  /// Opens the channel's statistics. Null where Telegram has none.
  final VoidCallback? onAnalyticsPressed;

  const ChannelProfileBar({
    super.key,
    required this.channel,
    required this.geometry,
    required this.scroll,
    this.onAnalyticsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final g = geometry;

    final buttons = Row(
      children: [
        const SizedBox(width: AppSpacing.postPadding),
        _ScrimCircleButton(
          icon: Icons.arrow_back,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _BarTitle(channel: channel, scroll: scroll, g: g),
        ),
        if (onAnalyticsPressed != null) ...[
          const SizedBox(width: AppSpacing.lg),
          _ScrimCircleButton(
            icon: Icons.bar_chart_rounded,
            tooltip: AppStrings.a11yChannelAnalytics,
            onPressed: onAnalyticsPressed!,
          ),
        ],
        const SizedBox(width: AppSpacing.postPadding),
      ],
    );

    return SizedBox(
      height: g.barExtent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListenableBuilder(
            listenable: scroll,
            builder: (context, cover) {
              final collapse = g.collapse(_offsetOf(scroll));
              if (collapse == 0) return const SizedBox.shrink();
              return Opacity(opacity: collapse, child: cover);
            },
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // A blur fades out toward the bar's edges, which would let
                  // the page show through.
                  const ColoredBox(color: Colors.black),
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: ChannelCoverImage(
                      channel: channel,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                  const ColoredBox(color: Color(0x59000000)),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: g.topInset),
            child: buttons,
          ),
        ],
      ),
    );
  }
}

/// The channel's name and size, coming up into the bar as the name in the
/// page scrolls under it.
class _BarTitle extends StatelessWidget {
  final Channel channel;
  final ScrollController scroll;
  final ChannelProfileGeometry g;

  const _BarTitle({
    required this.channel,
    required this.scroll,
    required this.g,
  });

  @override
  Widget build(BuildContext context) {
    final title = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          channel.title,
          style: AppTypography.displayName(
            color: Colors.white,
          ).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          AppStrings.subscriberCountShort(
            TimeUtils.formatCount(channel.subscriberCount),
          ),
          style: AppTypography.timestamp(color: Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return ListenableBuilder(
      listenable: scroll,
      builder: (context, title) {
        final reveal = g.titleReveal(_offsetOf(scroll));
        if (reveal == 0) return const SizedBox.shrink();
        return Opacity(
          opacity: reveal,
          child: Transform.translate(
            offset: Offset(0, (1 - reveal) * 12),
            child: title,
          ),
        );
      },
      child: Align(alignment: AlignmentDirectional.centerStart, child: title),
    );
  }
}

/// The channel's name, handle, description and size, under the cover.
class ChannelIdentity extends ConsumerWidget {
  final Channel channel;

  /// How many similar channels Telegram has, once known.
  final int? similarCount;

  /// Opens the similar channels.
  final VoidCallback? onSimilarTap;

  const ChannelIdentity({
    super.key,
    required this.channel,
    this.similarCount,
    this.onSimilarTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.postPadding,
        AppSpacing.xs,
        AppSpacing.postPadding,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  channel.title,
                  style: AppTypography.heading(
                    color: primary,
                  ).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (channel.isVerified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified,
                  color: AppColors.verified,
                  size: 20,
                  semanticLabel: AppStrings.a11yVerified,
                ),
              ],
            ],
          ),
          if (channel.username != null) ...[
            const SizedBox(height: 1),
            Text(
              '@${channel.username}',
              style: AppTypography.username(color: secondary),
            ),
          ],
          if (channel.description != null &&
              channel.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            // TDLib sends the description without entities, so links are
            // found with linkifyPlainText.
            TextEntityRenderer(
              text: channel.description!,
              entities: linkifyPlainText(channel.description!),
              style: AppTypography.body(color: primary),
              onHashtagTap: (tag) => openHashtagSearch(context, ref, tag),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // Bold figures with plain labels, as X shows its follower counts.
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.xs,
            children: [
              _Figure(
                count: channel.subscriberCount,
                label: AppStrings.subscribersLabel(channel.subscriberCount),
                primary: primary,
                secondary: secondary,
              ),
              if (similarCount case final count? when count > 0)
                _Figure(
                  count: count,
                  label: AppStrings.similarChannelsLabel(count),
                  primary: primary,
                  secondary: secondary,
                  onTap: onSimilarTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A count with its label, tappable when it opens a list.
class _Figure extends StatelessWidget {
  final int count;
  final String label;
  final Color primary;
  final Color secondary;
  final VoidCallback? onTap;

  const _Figure({
    required this.count,
    required this.label,
    required this.primary,
    required this.secondary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: TimeUtils.formatCount(count),
            style: AppTypography.body(
              color: primary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: ' $label',
            style: AppTypography.body(color: secondary),
          ),
        ],
      ),
    );
    if (onTap == null) return text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: text,
    );
  }
}

/// The cover: the channel's own photo, or a flat band in its colour.
/// Telegram channels have no cover image, so the photo stands in, as it did.
class ChannelCoverImage extends ConsumerWidget {
  final Channel channel;

  /// Which part of the photo shows when the box crops it.
  final Alignment alignment;

  const ChannelCoverImage({
    super.key,
    required this.channel,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = _tintFor(channel.avatarColor, isDark);

    final path = resolveMediaPath(
      ref,
      fileId: channel.avatarFileId,
      rawPath: channel.avatarUrl,
    );

    final exists = path != null && path.isNotEmpty
        ? ref.watch(fileExistsProvider(path)).value ?? false
        : false;

    if (!exists) return ColoredBox(color: fallback);

    return Semantics(
      label: AppStrings.channelBannerLabel,
      image: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(path),
            fit: BoxFit.cover,
            alignment: alignment,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => ColoredBox(color: fallback),
          ),
          // Darkest at the top, behind the bar's buttons and the status bar.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000)],
                stops: [0, 0.6],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A flat band in the channel's own colour, for a channel with no photo.
  static Color _tintFor(String? hex, bool isDark) {
    final base = _parseHex(hex) ?? AppColors.accent;
    return Color.alphaBlend(
      base.withValues(alpha: isDark ? 0.32 : 0.22),
      isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
    );
  }

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(cleaned.length <= 6 ? 0xFF000000 | value : value);
  }
}

/// A round button over the cover, on a dark scrim so it reads on any photo.
class _ScrimCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ScrimCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// A round outlined button beside the avatar, like X's bell and share.
class _OutlinedCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// The icon's colour, or the text colour when null.
  final Color? color;

  const _OutlinedCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        shape: CircleBorder(
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(
              icon,
              color: color ?? theme.colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
