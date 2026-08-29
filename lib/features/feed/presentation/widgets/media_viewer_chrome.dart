import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/open_with.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/expandable_text.dart';
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

  /// The downloaded file behind what is on screen, when there is one.
  ///
  /// Drives the "open with" control, which is absent rather than disabled while
  /// the file is still arriving — a share icon that says "not yet" is furniture.
  ///
  /// It sits in the action bar at the bottom, at the same weight as bookmark
  /// and share, rather than as a filled chip over the top-right corner of the
  /// picture. Handing a photo to another app is a thing you *can* do with it,
  /// not the thing you came here for, and a button that size on top of every
  /// image said otherwise. The only place it still rides in the top bar is a
  /// viewer opened without a post, which has no bottom bar to put it in.
  final String? localPath;

  const MediaViewerChrome({
    super.key,
    required this.child,
    this.post,
    this.controls,
    this.pageIndicator,
    this.showChrome = true,
    this.localPath,
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
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      // Only when there is no post, and therefore no action bar
                      // below to carry it. With a post it lives down there
                      // instead — see [localPath].
                      if (localPath != null && currentPost == null)
                        _OpenWithButton(
                          path: localPath!,
                          color: Colors.white70,
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
                  localPath: localPath,
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
                    children: [?pageIndicator, ?controls],
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
  /// Lines of caption shown before "Show more".
  static const int _captionLines = 3;

  final Post post;
  final Widget? controls;
  final Widget? pageIndicator;

  /// The file on screen, when it has finished arriving. See
  /// [MediaViewerChrome.localPath].
  final String? localPath;

  const _BottomSheetChrome({
    required this.post,
    this.controls,
    this.pageIndicator,
    this.localPath,
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
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (post.isChannelVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: AppColors.verified,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                        if (post.channelUsername != null)
                          Text(
                            '@${post.channelUsername}',
                            style: AppTypography.username(
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (post.text != null && post.text!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                // Collapsed to a few lines with its own toggle. A long caption
                // rendered in full pushed the picture off the top of the
                // screen, which is the opposite of what a viewer is for.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: ExpandableText(
                      text: post.text!,
                      entities: post.entities,
                      style: AppTypography.body(color: Colors.white),
                      maxLines: _captionLines,
                      linkColor: Colors.white,
                    ),
                  ),
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
                trailing: localPath == null
                    ? null
                    : _OpenWithButton(path: localPath!, color: Colors.white70),
                onBookmarkTap: () => ref.read(bookmarkToggleProvider(post.id)),
                onSelectReaction: (emoji) {
                  ref
                      .read(optimisticPostUpdatesProvider.notifier)
                      .toggleReaction(post.id, emoji, post);
                  ref
                      .read(feedPostsProvider.notifier)
                      .toggleReactionOptimistic(post.id, emoji);
                  ref
                      .read(syncServiceProvider)
                      .togglePostReaction(
                        chatId: post.chatId,
                        messageId: post.messageId,
                        reactionEmoji: emoji,
                        isCurrentlyLiked: post.chosenReactions.contains(emoji),
                      );
                },
                // Comments live on the post, so close the viewer and open
                // it — popping alone just dropped the reader back in the feed
                // with nothing to show for the tap.
                onReplyTap: () {
                  final router = GoRouter.of(context);
                  final atPost = router.state.uri.path == '/post/${post.id}';
                  Navigator.of(context).pop();
                  if (!atPost) router.push('/post/${post.id}?focusReply=true');
                },
                onShareTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets a downward (or upward) drag close the viewer, the way every gallery
/// does. The media follows the finger and fades, so a half-committed pull
/// shows what letting go would do.
class DragToDismiss extends StatefulWidget {
  final Widget child;

  /// Where the drag is allowed to start from. Zoomed images consume their own
  /// pans, so the viewer disables this while the image is scaled up.
  final bool enabled;

  const DragToDismiss({super.key, required this.child, this.enabled = true});

  @override
  State<DragToDismiss> createState() => _DragToDismissState();
}

class _DragToDismissState extends State<DragToDismiss> {
  /// How far the drag has to travel, or how fast it has to be thrown, before
  /// letting go dismisses rather than snapping back.
  static const double _dismissDistance = 120;
  static const double _dismissVelocity = 700;

  double _offset = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final height = MediaQuery.of(context).size.height;
    final progress = (_offset.abs() / height).clamp(0.0, 1.0);

    return GestureDetector(
      onVerticalDragStart: (_) => setState(() => _dragging = true),
      onVerticalDragUpdate: (details) =>
          setState(() => _offset += details.delta.dy),
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_offset.abs() > _dismissDistance ||
            velocity.abs() > _dismissVelocity) {
          Navigator.of(context).maybePop();
          return;
        }
        setState(() {
          _offset = 0;
          _dragging = false;
        });
      },
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _offset, 0),
        child: Opacity(opacity: 1 - progress * 0.8, child: widget.child),
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

/// Hands the file on screen to whatever app owns it.
///
/// A bare icon at the action bar's own weight — 18pt, the secondary colour, no
/// chip behind it — so it reads as one more thing in the row rather than as a
/// control pinned over the picture.
class _OpenWithButton extends StatelessWidget {
  final String path;
  final Color color;

  const _OpenWithButton({required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.openWith,
      child: Tooltip(
        message: AppStrings.openWith,
        child: GestureDetector(
          onTap: () => openWithSystemApp(context, path),
          child: Icon(Icons.open_in_new_rounded, color: color, size: 18),
        ),
      ),
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
