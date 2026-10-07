import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/features/compose/presentation/widgets/post_progress_bar.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

/// How far the chrome has slid off screen, as a fraction of its height (0
/// shown, 1 hidden). [animate] is true only when settling after a drag.
@immutable
class ChromeOffset {
  final double hidden;
  final bool animate;

  const ChromeOffset({this.hidden = 0, this.animate = false});

  /// Whether the chrome is more than half hidden.
  bool get isHidden => hidden >= 0.5;

  @override
  bool operator ==(Object other) =>
      other is ChromeOffset &&
      other.hidden == hidden &&
      other.animate == animate;

  @override
  int get hashCode => Object.hash(hidden, animate);

  @override
  String toString() => 'ChromeOffset(hidden: $hidden, animate: $animate)';
}

/// Folds one scroll delta into the offset; [extent] is the chrome's height.
ChromeOffset applyScrollDelta({
  required ChromeOffset current,
  required double delta,
  required double extent,
  required double pixels,
}) {
  // At or above the top (including overscroll bounce) the chrome is shown.
  if (pixels <= 0) return const ChromeOffset();
  if (extent <= 0 || delta == 0) {
    return current.animate ? ChromeOffset(hidden: current.hidden) : current;
  }

  final next = (current.hidden + delta / extent).clamp(0.0, 1.0);
  if (next == current.hidden && !current.animate) return current;
  return ChromeOffset(hidden: next);
}

/// Where the chrome rests after a drag: the nearer end.
ChromeOffset settleChrome(ChromeOffset current) {
  if (current.hidden <= 0) return const ChromeOffset();
  if (current.hidden >= 1) return const ChromeOffset(hidden: 1);
  return ChromeOffset(hidden: current.isHidden ? 1 : 0, animate: true);
}

/// Opacity for header-tied elements; fades over the header's first half.
double chromeTiedOpacity(double hidden) => (1 - hidden * 2).clamp(0.0, 1.0);

/// Whether a tab strip is between tabs, so the chrome should come back.
/// [position] moves before [index] does, so this fires as a swipe starts.
bool tabIsMoving({
  required double position,
  required int index,
  required bool indexIsChanging,
}) => indexIsChanging || (position - index).abs() > 0.01;

class ChromeOffsetNotifier extends Notifier<ChromeOffset> {
  @override
  ChromeOffset build() => const ChromeOffset();

  void onScroll({
    required double delta,
    required double extent,
    required double pixels,
  }) {
    final next = applyScrollDelta(
      current: state,
      delta: delta,
      extent: extent,
      pixels: pixels,
    );
    if (next != state) state = next;
  }

  void settle() {
    final next = settleChrome(state);
    if (next != state) state = next;
  }

  /// Brings the chrome back. Pass [animate] false when leaving a screen.
  void show({bool animate = true}) {
    final next = ChromeOffset(hidden: 0, animate: animate);
    if (next != state) state = next;
  }
}

final chromeOffsetProvider =
    NotifierProvider<ChromeOffsetNotifier, ChromeOffset>(
      ChromeOffsetNotifier.new,
    );

/// Whether the chrome is mostly on screen.
final chromeVisibleProvider = Provider<bool>(
  (ref) => !ref.watch(chromeOffsetProvider).isHidden,
);

/// Feeds a scrollable's deltas into the chrome offset. Only depth-0
/// notifications count, so nested scrollables do not move the header.
class ChromeScrollObserver extends ConsumerWidget {
  final double extent;
  final Widget child;

  const ChromeScrollObserver({
    super.key,
    required this.extent,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read here, not in the callback: a scrollable torn down with this widget
    // can still report a scroll, when ref may no longer be used.
    final notifier = ref.read(chromeOffsetProvider.notifier);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;

        if (notification is ScrollUpdateNotification) {
          final delta = notification.scrollDelta;
          if (delta != null) {
            notifier.onScroll(
              delta: delta,
              extent: extent,
              pixels: notification.metrics.pixels,
            );
          }
        } else if (notification is ScrollEndNotification) {
          notifier.settle();
        }
        return false;
      },
      child: child,
    );
  }
}

/// Rebuilds with the chrome's current position, tweened when it is settling.
/// Everything that tracks the chrome uses this so they stay in sync.
class ChromeMotion extends ConsumerWidget {
  final Widget Function(BuildContext context, double hidden, Widget? child)
  builder;
  final Widget? child;

  const ChromeMotion({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(chromeOffsetProvider);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: offset.hidden),
      duration: offset.animate ? ShellChrome.slideDuration : Duration.zero,
      curve: ShellChrome.slideCurve,
      builder: builder,
      child: child,
    );
  }
}

/// Slides its child off the top or bottom edge as the chrome retires.
class ChromeSlide extends StatelessWidget {
  final bool fromTop;
  final Widget child;

  const ChromeSlide({super.key, required this.fromTop, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChromeMotion(
      builder: (context, hidden, child) => FractionalTranslation(
        translation: Offset(0, fromTop ? -hidden : hidden),
        child: child,
      ),
      child: child,
    );
  }
}

/// A blurred strip under the status bar, faded in as the header leaves.
class StatusBarScrim extends StatelessWidget {
  const StatusBarScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).padding.top;
    if (height <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: ChromeMotion(
        builder: (context, hidden, child) =>
            Opacity(opacity: hidden.clamp(0.0, 1.0), child: child),
        child: BlurredChrome(
          child: SizedBox(height: height, width: double.infinity),
        ),
      ),
    );
  }
}

/// The height of a screen header, status bar included.
double chromeHeaderHeight(BuildContext context) =>
    MediaQuery.of(context).padding.top + ChromeScaffold.headerHeight;

/// Room the bottom bar takes over the content.
double chromeBottomInset(BuildContext context) =>
    ShellChrome.bottomBarHeight + MediaQuery.of(context).padding.bottom;

/// A screen whose header overlays the body and slides away with it. [body]
/// receives the space the header and bottom bar cover.
class ChromeScaffold extends StatelessWidget {
  /// Height of the header row itself, above the status bar inset.
  static const double headerHeight = 56;

  final Widget header;

  /// Content below the header row that hides with it, such as folder tabs.
  final Widget? headerBottom;

  final double headerBottomHeight;

  final Widget Function(
    BuildContext context,
    double topPadding,
    double bottomPadding,
  )
  body;

  /// Whether to observe the body's scrolling. False when the body reports for
  /// itself, as with the feed's tabs.
  final bool observeScroll;

  const ChromeScaffold({
    super.key,
    required this.header,
    required this.body,
    this.headerBottom,
    this.headerBottomHeight = 0,
    this.observeScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final totalHeight = chromeHeaderHeight(context) + headerBottomHeight;
    final bottomInset = chromeBottomInset(context);

    Widget content = body(context, totalHeight, bottomInset);
    if (observeScroll) {
      content = ChromeScrollObserver(extent: totalHeight, child: content);
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: content),
          const Positioned(top: 0, left: 0, right: 0, child: StatusBarScrim()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ChromeSlide(
              fromTop: true,
              child: BlurredChrome(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 0.5),
                ),
                child: SizedBox(
                  height: totalHeight,
                  // Overlaid on the header's bottom edge so it never shifts the
                  // feed, and hides with the header.
                  child: Stack(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            SizedBox(height: headerHeight, child: header),
                            if (headerBottom != null)
                              SizedBox(
                                height: headerBottomHeight,
                                child: headerBottom,
                              ),
                          ],
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: PostProgressBar(),
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

/// The standard header row: a title, and optional actions on the right.
class ChromeHeaderRow extends StatelessWidget {
  /// The page's name. Null when [titleWidget] carries it instead.
  final String? title;

  /// Drawn in place of [title], such as the home tab's mark.
  final Widget? titleWidget;

  final List<Widget> actions;

  /// Drawn before the title, such as the feed's account avatar.
  final Widget? leading;

  /// Centres the title on the header regardless of [leading]'s width. Used for
  /// the home tab's mark; page titles stay left-aligned.
  final bool centerTitle;

  const ChromeHeaderRow({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.leading,
    this.centerTitle = false,
  }) : assert(
         title != null || titleWidget != null,
         'A header row names its page, in words or as a mark.',
       );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onSurface;
    final titleText =
        titleWidget ??
        Text(
          title!,
          style: AppTypography.heading(color: primary),
          overflow: TextOverflow.ellipsis,
        );

    final row = Row(
      children: [
        if (leading != null) leading! else const SizedBox(width: AppSpacing.lg),
        Expanded(child: centerTitle ? const SizedBox.shrink() : titleText),
        ...actions,
        const SizedBox(width: AppSpacing.xs),
      ],
    );

    if (!centerTitle) return row;

    return Stack(
      alignment: Alignment.center,
      children: [
        row,
        IgnorePointer(child: titleText),
      ],
    );
  }
}
