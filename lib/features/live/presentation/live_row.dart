import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/live/presentation/live_providers.dart';
import 'package:gramx/features/live/presentation/live_screen.dart';

/// The row of live chats at the top of Home: ringed avatars with a LIVE
/// badge, scrolling sideways. Nothing is drawn while nothing is live.
class LiveRow extends StatelessWidget {
  final List<LiveChat> lives;

  static const double avatarSize = 64;
  static const double ringWidth = 2.5;
  static const double ringGap = 2.5;
  static const double tileWidth = 80;
  static const double nameSize = 13;
  static const double nameLineHeight = 1.25;

  const LiveRow({super.key, required this.lives});

  @override
  Widget build(BuildContext context) {
    if (lives.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // Grows with the text size, so the name is never clipped.
    final nameHeight =
        MediaQuery.textScalerOf(context).scale(nameSize) * nameLineHeight;
    const ringed = avatarSize + 2 * (ringWidth + ringGap);

    return Semantics(
      container: true,
      label: AppStrings.liveRowLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 10 + ringed + 6 + 4 + nameHeight + 10,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: lives.length,
              itemBuilder: (context, index) => _LiveTile(live: lives[index]),
            ),
          ),
          Divider(color: theme.dividerTheme.color, height: 0.5, thickness: 0.5),
        ],
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  final LiveChat live;

  const _LiveTile({required this.live});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ringed =
        LiveRow.avatarSize + 2 * (LiveRow.ringWidth + LiveRow.ringGap);

    return Semantics(
      button: true,
      label: AppStrings.liveTileLabel(live.title),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(LiveScreen.routeFor(live.chatId)),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: LiveRow.tileWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                SizedBox(
                  width: ringed,
                  height: ringed + 6,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: ringed,
                        height: ringed,
                        padding: const EdgeInsets.all(LiveRow.ringGap),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.error,
                            width: LiveRow.ringWidth,
                          ),
                        ),
                        child: ChannelAvatar(
                          title: live.title,
                          avatarPath: live.avatarPath,
                          avatarFileId: live.avatarFileId,
                          avatarColorHex: live.avatarColorHex,
                          radius: LiveRow.avatarSize / 2,
                        ),
                      ),
                      const Positioned(bottom: 0, child: LiveBadge()),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    live.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: LiveRow.nameSize,
                      height: LiveRow.nameLineHeight,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The red LIVE badge, on an avatar or beside a live's title.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
      ),
      child: Text(
        AppStrings.liveBadge,
        style: GoogleFonts.inter(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }
}
