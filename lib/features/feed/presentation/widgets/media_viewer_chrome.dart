import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';

/// The frame around full-screen media: who posted it, what they said, and the
/// same actions the feed card offers.
///
/// Opening media used to drop the reader into a bare black screen with only a
/// identity and actions attached, so a photo can be liked or shared without
/// backing out first — this mirrors that.
class MediaViewerChrome extends ConsumerWidget {
  /// The post the media belongs to. Null for media opened without one, in
  /// which case only the close button is drawn.
  final Post? post;

  /// The media itself, filling the space between the bars.
  final Widget child;

  /// Extra controls pinned above the action bar — the video scrubber.
  final Widget? controls;

  /// Page indicator dots for an album.
  final Widget? pageIndicator;

  /// Whether the chrome is currently shown. Tapping the media toggles it, so
  /// the picture can be looked at without furniture over it.
  final bool showChrome;

  const MediaViewerChrome({
    super.key,
    required this.child,
    this.post,
    this.controls,
    this.pageIndicator,
    this.showChrome = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPost = post;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: child),

          // Positioned has to stay a direct child of Stack — wrapping it in
          // the fade throws "Incorrect use of ParentDataWidget" at runtime.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Fade(
              visible: showChrome,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back,
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (currentPost != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Fade(
                visible: showChrome,
                child: _BottomSheetChrome(
                  post: currentPost,
                  controls: controls,
                  pageIndicator: pageIndicator,
                ),
              ),
            )
          else if (pageIndicator != null || controls != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Fade(
                visible: showChrome,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?pageIndicator,
                      ?controls,
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Author, caption, page dots, controls and actions, over a gradient.
///
/// The gradient exists so white controls stay legible over a light photo —
/// without it the whole row disappears against a bright image.
class _BottomSheetChrome extends ConsumerWidget {
  final Post post;
  final Widget? controls;
  final Widget? pageIndicator;

  const _BottomSheetChrome({
    required this.post,
    this.controls,
    this.pageIndicator,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black87, Colors.black],
          stops: [0, 0.35, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.postPadding,
            AppSpacing.xl,
            AppSpacing.postPadding,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pageIndicator != null) ...[
                pageIndicator!,
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  ChannelAvatar(
                    title: post.channelTitle,
                    avatarPath: post.channelAvatarUrl,
                    avatarFileId: post.channelAvatarFileId,
                    avatarColorHex: post.channelAvatarColor,
                    radius: AppSpacing.avatarSizeSmall / 2,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.channelTitle,
                                style: AppTypography.displayName(
                                    color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (post.isChannelVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: AppColors.verified, size: 14),
                            ],
                          ],
                        ),
                        if (post.channelUsername != null)
                          Text(
                            '@${post.channelUsername}',
                            style: AppTypography.username(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (post.text != null && post.text!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  post.text!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(color: Colors.white),
                ),
              ],
              if (controls != null) ...[
                const SizedBox(height: AppSpacing.sm),
                controls!,
              ],
              const SizedBox(height: AppSpacing.md),
              PostActionBar(
                post: post,
                secondaryColor: Colors.white70,
                onBookmarkTap: () =>
                    ref.read(bookmarkToggleProvider(post.id)),
                onSelectReaction: (emoji) {
                  ref
                      .read(optimisticPostUpdatesProvider.notifier)
                      .toggleReaction(post.id, emoji, post);
                  ref
                      .read(feedPostsProvider.notifier)
                      .toggleReactionOptimistic(post.id, emoji);
                  ref.read(syncServiceProvider).togglePostReaction(
                        chatId: post.chatId,
                        messageId: post.messageId,
                        reactionEmoji: emoji,
                        isCurrentlyLiked: post.chosenReactions.contains(emoji),
                      );
                },
                // Replying and sharing belong to the post, not the viewer;
                // closing first keeps the reader where those make sense.
                onReplyTap: () => Navigator.of(context).pop(),
                onShareTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _Fade({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(ignoring: !visible, child: child),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class MediaPageDots extends StatelessWidget {
  final int count;
  final int index;

  const MediaPageDots({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? Colors.white : Colors.white38,
            ),
          ),
      ],
    );
  }
}
