import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

/// How far the app chrome has slid off screen.
///
/// [hidden] is a fraction of the chrome's own height: 0 is fully on screen, 1
/// fully gone. It is a fraction rather than a bool because the bars track the
/// scroll position one-to-one — the header leaves with the content that pushed
/// it out, instead of snapping away once a threshold is crossed.
///
/// [animate] says whether the change should be tweened. A drag sets it false so
/// the bars follow the thumb exactly; a settle sets it true so the leftover
/// distance is covered smoothly.
@immutable
class ChromeOffset {
  final double hidden;
  final bool animate;

  const ChromeOffset({this.hidden = 0, this.animate = false});

  /// Whether the chrome is more gone than not — what anything needing a plain
  /// yes/no (the "new posts" pill, semantics) should ask.
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

/// Folds one scroll delta into the chrome offset.
///
/// Pure so the rule — the only part of this that can be subtly wrong — is
/// testable without a viewport. [extent] is the chrome's height, which is what
/// makes the movement one-to-one with the content: scrolling the list by the
/// header's height retires exactly the header.
ChromeOffset applyScrollDelta({
  required ChromeOffset current,
  required double delta,
  required double extent,
  required double pixels,
}) {
  // At (or above) the top there is nothing to scroll away from, and a bounce
  // past the edge must not leave the header stranded off screen.
  if (pixels <= 0) return const ChromeOffset();
  if (extent <= 0 || delta == 0) {
    return current.animate ? ChromeOffset(hidden: current.hidden) : current;
  }

  final next = (current.hidden + delta / extent).clamp(0.0, 1.0);
  if (next == current.hidden && !current.animate) return current;
  return ChromeOffset(hidden: next);
}

/// Where the chrome comes to rest when the finger leaves.
///
/// Half-retired chrome is nobody's intent, so a partial offset finishes in the
/// direction it was already going.
ChromeOffset settleChrome(ChromeOffset current) {
  if (current.hidden <= 0) return const ChromeOffset();
  if (current.hidden >= 1) return const ChromeOffset(hidden: 1);
  return ChromeOffset(hidden: current.isHidden ? 1 : 0, animate: true);
}

/// Opacity for anything that belongs to the header rather than to the page —
/// the "new posts" pill, most of all.
///
/// It fades out over the first half of the header's travel, so the pill is gone
/// well before the header is: offering "3 new posts" while the bar that owns
/// the feed is off screen just clutters the reading surface.
double chromeTiedOpacity(double hidden) => (1 - hidden * 2).clamp(0.0, 1.0);

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

  /// Brings the chrome back. [animate] false is for leaving a screen, where a
  /// tween would play over whatever comes next.
  void show({bool animate = true}) {
    final next = ChromeOffset(hidden: 0, animate: animate);
    if (next != state) state = next;
  }
}

final chromeOffsetProvider =
    NotifierProvider<ChromeOffsetNotifier, ChromeOffset>(
        ChromeOffsetNotifier.new);

/// Whether the chrome is mostly on screen.
///
/// For the callers that only need a yes/no — the pill, and anything that has to
/// stop offering a control the user can't see.
final chromeVisibleProvider =
    Provider<bool>((ref) => !ref.watch(chromeOffsetProvider).isHidden);

/// Feeds a scrollable's deltas into the chrome offset.
///
/// [extent] is how much scrolling retires the chrome completely — pass the
/// header's height so the two move together.
///
/// Only depth-0 notifications count. A horizontal reaction strip inside a post,
/// or a `TabBarView` above the list, would otherwise drive the header sideways.
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
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;

        final notifier = ref.read(chromeOffsetProvider.notifier);
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
///
/// One place owns the tween so every piece that tracks the chrome — the bars
/// themselves, the status-bar scrim, the "new posts" pill — moves on the same
/// value rather than on four animations that drift apart.
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
///
/// Without it the status-bar text sits directly on scrolling content.
class StatusBarScrim extends StatelessWidget {
  const StatusBarScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).padding.top;
    if (height <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: ChromeMotion(
        builder: (context, hidden, child) => Opacity(
          opacity: hidden.clamp(0.0, 1.0),
          child: child,
        ),
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

/// A screen whose header slides away with the content, like the feed's.
///
/// The header overlays the body rather than sitting above it in the layout, so
/// retiring it never reflows what is underneath — the reason this is a Stack
/// and not an `AppBar`. [body] is handed the space the header and the bottom
/// bar are covering so its scrollable can reserve it.
class ChromeScaffold extends StatelessWidget {
  /// Height of the header row itself, above the status bar inset.
  static const double headerHeight = 56;

  /// Contents of the header row.
  final Widget header;

  /// Anything below the header row that scrolls away with it — the feed's
  /// folder tabs, a filter strip.
  final Widget? headerBottom;

  /// Height of [headerBottom], if there is one.
  final double headerBottomHeight;

  final Widget Function(
    BuildContext context,
    double topPadding,
    double bottomPadding,
  ) body;

  /// Whether this scaffold watches its own body for scrolling. False when the
  /// body owns several scrollables and reports for itself — the feed's tabs.
  final bool observeScroll;

  final Widget? floatingActionButton;

  const ChromeScaffold({
    super.key,
    required this.header,
    required this.body,
    this.headerBottom,
    this.headerBottomHeight = 0,
    this.observeScroll = true,
    this.floatingActionButton,
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
      floatingActionButton: floatingActionButton,
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
                  child: SafeArea(
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
  final String title;
  final List<Widget> actions;

  /// Drawn before the title — the feed's account avatar.
  final Widget? leading;

  const ChromeHeaderRow({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        if (leading != null) leading! else const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(
            title,
            style: AppTypography.heading(color: primary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...actions,
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
