import 'package:flutter/gestures.dart';
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

/// The frame around full-screen media: the post's author, caption and the
/// same actions the feed card offers.
class MediaViewerChrome extends ConsumerWidget {
  /// The post the media belongs to. When null, only the close button shows.
  final Post? post;

  final Widget child;

  /// Extra controls pinned above the action bar, such as the video scrubber.
  final Widget? controls;

  /// Page indicator dots for an album.
  final Widget? pageIndicator;

  /// Whether the chrome is shown. Tapping the media toggles it.
  final bool showChrome;

  /// The downloaded file on screen. The "open with" button shows only once
  /// it is set.
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

          // Positioned must stay a direct child of the Stack.
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
                      // Only without a post; otherwise it is in the action bar.
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

/// Author, caption, page dots, controls and actions, over a gradient that
/// keeps white controls legible on light photos.
class _BottomSheetChrome extends ConsumerWidget {
  /// Lines of caption shown before "Show more".
  static const int _captionLines = 3;

  final Post post;
  final Widget? controls;
  final Widget? pageIndicator;

  /// See [MediaViewerChrome.localPath].
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
                // Capped so a long caption can't cover the picture.
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
                // Comments are on the post screen.
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

/// A vertical drag recogniser that accepts only when the total movement is
/// mostly vertical ([dominance] times the horizontal), leaving diagonal
/// swipes to the page view. [onlyAcceptDragOnThreshold] stops the arena
/// handing it an unmatched drag on release.
class MostlyVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  /// How much larger the vertical movement must be than the horizontal.
  static const double dominance = 1.25;

  MostlyVerticalDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  }) : super() {
    onlyAcceptDragOnThreshold = true;
  }

  final Map<int, Offset> _downAt = <int, Offset>{};
  final Map<int, Offset> _lastAt = <int, Offset>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _downAt[event.pointer] = event.position;
    _lastAt[event.pointer] = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) _lastAt[event.pointer] = event.position;
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _downAt.clear();
    _lastAt.clear();
    super.didStopTrackingLastPointer(pointer);
  }

  /// The movement since the finger landed, across every tracked pointer.
  Offset get _travelled {
    var total = Offset.zero;
    for (final entry in _lastAt.entries) {
      total += entry.value - (_downAt[entry.key] ?? entry.value);
    }
    return total;
  }

  static bool isMostlyVertical(Offset travelled, double slop) =>
      travelled.dy.abs() > slop &&
      travelled.dy.abs() > travelled.dx.abs() * dominance;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    if (!super.hasSufficientGlobalDistanceToAccept(
      pointerDeviceKind,
      deviceTouchSlop,
    )) {
      return false;
    }
    return isMostlyVertical(
      _travelled,
      computeHitSlop(pointerDeviceKind, gestureSettings),
    );
  }

  @override
  String get debugDescription => 'mostly vertical drag';
}

/// Closes the viewer on a vertical drag. The media follows the finger and
/// fades as it goes.
class DragToDismiss extends StatefulWidget {
  final Widget child;

  /// Disabled while an image is zoomed, so drags pan instead.
  final bool enabled;

  const DragToDismiss({super.key, required this.child, this.enabled = true});

  @override
  State<DragToDismiss> createState() => _DragToDismissState();
}

class _DragToDismissState extends State<DragToDismiss> {
  /// Distance or velocity past which letting go dismisses.
  static const double _dismissDistance = 120;
  static const double _dismissVelocity = 700;

  double _offset = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final height = MediaQuery.of(context).size.height;
    final progress = (_offset.abs() / height).clamp(0.0, 1.0);

    // Only clearly vertical drags; diagonal swipes go to the gallery.
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        MostlyVerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              MostlyVerticalDragGestureRecognizer
            >(MostlyVerticalDragGestureRecognizer.new, (recognizer) {
              recognizer.onStart = (_) => setState(() => _dragging = true);
              recognizer.onUpdate = (details) =>
                  setState(() => _offset += details.delta.dy);
              recognizer.onEnd = (details) {
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
              };
            }),
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

/// Opens the file on screen in another app.
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

/// Page dots for an album.
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
