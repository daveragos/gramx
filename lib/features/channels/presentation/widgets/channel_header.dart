import 'dart:io';

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

/// name, handle, subscriber count, description, and the join control.
///
/// Telegram has no separate cover image — a channel owns exactly one photo —
/// so the banner is that photo, shown as it is. It used to be blurred, on the
/// theory that a small square blown up to a wide band would look wrong; in
/// practice the blur threw away the only picture the channel has and left a
/// coloured smear, which is the empty band the profile screen already lost to
/// once in T8-42. A bottom-weighted scrim is what keeps the controls over it
/// legible now, and it costs the image nothing.
class ChannelHeader extends ConsumerWidget {
  final Channel channel;
  final bool isActionBusy;
  final VoidCallback onJoinPressed;

  static const double bannerHeight = 132;

  static const double _avatarRadius = 38;

  const ChannelHeader({
    super.key,
    required this.channel,
    required this.isActionBusy,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _Banner(channel: channel, isDark: isDark),
            // The avatar straddles the banner's lower edge, which is the shape
            // that makes the block read as a profile rather than as a card.
            Positioned(
              left: AppSpacing.postPadding,
              bottom: -_avatarRadius,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: ChannelAvatar(
                  title: channel.title,
                  avatarPath: channel.avatarUrl,
                  avatarFileId: channel.avatarFileId,
                  avatarColorHex: channel.avatarColor,
                  radius: _avatarRadius,
                ),
              ),
            ),
          ],
        ),

        // The join button sits on the row below the banner, opposite the
        // avatar's overhang at every text scale.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.postPadding,
            AppSpacing.sm,
            AppSpacing.postPadding,
            0,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: _JoinButton(
              isJoined: channel.isJoined,
              isBusy: isActionBusy,
              onPressed: onJoinPressed,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.postPadding,
            AppSpacing.sm,
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
                      ).copyWith(fontSize: 21, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (channel.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      color: AppColors.verified,
                      size: 19,
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
                // A bio is where a channel puts its site, its discussion group
                // and its owner, and TDLib hands it over as a bare string with
                // no entities — so all of that rendered as grey prose. The
                // links are re-derived rather than left flat; see
                // linkifyPlainText for what is and is not matched.
                TextEntityRenderer(
                  text: channel.description!,
                  entities: linkifyPlainText(channel.description!),
                  style: AppTypography.body(color: primary),
                  onHashtagTap: (tag) => openHashtagSearch(context, ref, tag),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 15, color: secondary),
                  const SizedBox(width: 5),
                  Text(
                    AppStrings.subscriberCountShort(
                      TimeUtils.formatCount(channel.subscriberCount),
                    ),
                    style: AppTypography.body(color: secondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The cover band: the channel's own photo, or a flat tint.
class _Banner extends ConsumerWidget {
  final Channel channel;
  final bool isDark;

  const _Banner({required this.channel, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = _tintFor(channel.avatarColor, isDark);

    final path = resolveMediaPath(
      ref,
      fileId: channel.avatarFileId,
      rawPath: channel.avatarUrl,
    );

    final exists = path != null && path.isNotEmpty
        ? ref.watch(fileExistsProvider(path)).value ?? false
        : false;

    return SizedBox(
      height: ChannelHeader.bannerHeight,
      width: double.infinity,
      child: exists
          ? Semantics(
              label: AppStrings.channelBannerLabel,
              image: true,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: fallback),
                    ),
                    // Not a flat wash over the whole picture: a gradient that
                    // is strongest at the top, where the back button sits, and
                    // clear by the middle. The photo stays the photo; only the
                    // band under the control is darkened enough to carry it
                    // over a bright image.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66000000), Color(0x00000000)],
                          stops: [0, 0.6],
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                  ],
                ),
              ),
            )
          : ColoredBox(color: fallback),
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

class _JoinButton extends StatelessWidget {
  final bool isJoined;
  final bool isBusy;
  final VoidCallback onPressed;

  const _JoinButton({
    required this.isJoined,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isJoined ? Colors.transparent : AppColors.accent,
        foregroundColor: isJoined ? primary : Colors.white,
        elevation: 0,
        side: isJoined
            ? BorderSide(color: secondary.withValues(alpha: 0.5))
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: 9,
        ),
      ),
      onPressed: isBusy ? null : onPressed,
      child: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              isJoined
                  ? AppStrings.channelJoinedAction
                  : AppStrings.channelJoinAction,
              style: AppTypography.button(),
            ),
    );
  }
}
