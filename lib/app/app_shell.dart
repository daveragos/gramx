import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/widgets/app_drawer.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/features/activity/data/notification_service.dart';
import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/core/navigation/share_intake.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_fab.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';

/// The tabs in the bottom bar, in order.
///
/// This is the single source of truth for tab order: `app/router.dart` declares
/// its branches in this order and takes each route path from [path], so an
/// index can't come to mean two different things.
enum ShellTab {
  home(Icons.home_outlined, Icons.home, 'Home', '/home'),
  search(Icons.search_outlined, Icons.search, 'Search', '/search'),
  channels(Icons.list_alt_outlined, Icons.list_alt, 'Channels', '/channels'),
  messages(
    Icons.mail_outline_rounded,
    Icons.mail_rounded,
    'Messages',
    '/messages',
  );

  const ShellTab(this.icon, this.activeIcon, this.label, this.path);

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// The route this tab's branch is rooted at. The router reads it from here so
  /// the tab order and the branch order cannot drift apart.
  final String path;
}

/// Shared chrome geometry and motion.
///
/// The header and the bottom bar move together, so they share one duration and
/// curve — different values made the two halves of the frame disagree, which is
/// what read as jumpy.
abstract class ShellChrome {
  static const double bottomBarHeight = 56;
  static const Duration slideDuration = Duration(milliseconds: 220);
  static const Curve slideCurve = Curves.easeOutCubic;

  /// Blur behind the bars, so content scrolling under them stays legible
  /// without a hard opaque band.
  static const double blurSigma = 18;

  /// How opaque the tint over that blur is. Enough to carry text contrast,
  /// little enough that the content still reads as continuing underneath.
  static const double tintOpacity = 0.72;
}

/// The shell's own scaffold, so the drawer can be opened from inside a branch.
///
/// A branch builds its own `Scaffold`, and `Scaffold.of` finds *that* one — which
/// has no drawer, so the account avatar in the feed header did nothing at all.
/// Addressing the shell's scaffold directly is what makes that tap work.
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Opens the app drawer from anywhere inside the shell.
void openAppDrawer() => shellScaffoldKey.currentState?.openDrawer();

/// Hosts the tab bar and the drawer around whichever branch is showing.
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  /// How long a second back press still counts as "I meant it".
  static const Duration _exitWindow = Duration(seconds: 2);

  DateTime? _lastBackPress;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();

    // Sharing into gramX resumes the app rather than starting it, most of the
    // time — so the shared text is collected on every resume as well as here.
    WidgetsBinding.instance.addObserver(this);
    unawaited(_openSharedText());

    // A notification tapped from the lock screen wakes the app from cold, so
    // the route it asks for is parked the same way a link is and collected
    // here, where a navigator exists.
    ref.listenManual<String?>(
      pendingNotificationRouteProvider,
      (_, next) {
        if (next == null) return;
        final route =
            ref.read(pendingNotificationRouteProvider.notifier).take();
        if (route != null && mounted) GoRouter.of(context).push(route);
      },
      fireImmediately: true,
    );

    // A link can arrive before there is anywhere to send it: a cold start from
    // a tapped `t.me` link runs before the first frame, so the link is parked
    // in a provider and collected here, where a navigator exists. Listened to
    // rather than watched — opening one is an action, not a rebuild.
    ref.listenManual<Uri?>(
      pendingDeepLinkProvider,
      (_, next) {
        if (next != null) unawaited(_openDeepLink());
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_openSharedText());
  }

  /// Opens the composer on text shared in from another app.
  ///
  /// Nothing happens when there is nothing to post *to*: the compose button
  /// hides itself for an account that can write nowhere, and a share that
  /// opened a screen saying no would be the same inert control by another
  /// route. Saying so is the honest answer, since the reader did just ask for
  /// something.
  Future<void> _openSharedText() async {
    final text = await ref.read(shareIntakeProvider).take();
    if (text == null || !mounted) return;

    if (ref.read(composeTargetsProvider).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.shareNowhereToPost),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    GoRouter.of(context).push(ComposeFab.route, extra: text);
  }

  /// Opens whatever link is waiting.
  ///
  /// A username costs one `SearchPublicChat` to turn into a chat id, which is
  /// the on-demand, one-tap-one-request shape `docs/TDLIB.md` allows. Anything
  /// this app has no screen for — an invite, a sticker pack, a name Telegram
  /// does not know — is handed to Telegram itself rather than swallowed. That
  /// is the honest end of a link gramX cannot open, and it is what the reader
  /// expected before this app registered for the link at all.
  Future<void> _openDeepLink() async {
    final uri = ref.read(pendingDeepLinkProvider.notifier).take();
    if (uri == null) return;

    final link = TelegramLinks.parse(uri);
    if (link == null) return;

    // A hashtag is not a destination — it is a query put into the search field
    // and a tab switch, the same thing tapping a #tag in a post does. Handled
    // here rather than by a route, because there is no screen to push.
    if (link is TelegramHashtagLink) {
      if (mounted) openHashtagSearch(context, ref, link.tag);
      return;
    }

    var chatId = link is TelegramPrivatePostLink ? link.chatId : null;

    final username = DeepLinkRoutes.usernameToResolve(link);
    if (username != null) {
      final resolved = await ref
          .read(chatsRepositoryProvider)
          .resolveUsername(username);
      chatId = resolved?.chatId;
    }

    final route = DeepLinkRoutes.routeFor(link, chatId: chatId);
    if (route == null) {
      await openExternalUrl(uri);
      return;
    }
    if (!mounted) return;
    GoRouter.of(context).push(route);
  }

  /// Back behaviour for the whole shell.
  ///
  /// From any tab other than Home, back returns to Home — leaving the app from
  /// deep in Settings is not what the gesture means. Only from Home does a
  /// second press within [_exitWindow] actually exit.
  void _handleBack() {
    if (navigationShell.currentIndex != ShellTab.home.index) {
      navigationShell.goBranch(ShellTab.home.index);
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPress;
    if (last == null || now.difference(last) > _exitWindow) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.feedPressBackAgain),
          duration: _exitWindow,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  /// Switches branch, or returns to that branch's root if it is already active
  /// — the standard tab-bar behaviour, and what makes a second tap on Home
  /// mean "take me back to the top".
  void _onTap(int index) {
    final isRetap = index == navigationShell.currentIndex;

    // Branches stay mounted in the indexed stack, so a tab left mid-scroll
    // keeps its chrome offset. Arriving on a screen with the header already
    // retired looks like the app lost its navigation, so every switch starts
    // with the furniture on screen.
    ref.read(chromeOffsetProvider.notifier).show(animate: false);

    // Re-tapping Home means "take me back to the top of what I'm reading".
    // goBranch alone only resets the branch's route stack.
    if (isRetap && index == ShellTab.home.index) {
      ref
          .read(feedScrollToTopProvider.notifier)
          .request(ref.read(activeFolderProvider));
    }
    // Same gesture, same meaning, on the other list you can get lost in.
    if (isRetap && index == ShellTab.messages.index) {
      ref.read(chatsScrollToTopProvider.notifier).request();
    }

    navigationShell.goBranch(index, initialLocation: isRetap);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        key: shellScaffoldKey,
        // The bar is pinned to the bottom of this Scaffold's body, so letting
        // the Scaffold shrink for the keyboard carried the bar up on top of
        // it — a tab strip riding the top edge of the keyboard on every screen
        // with a text field in it. The bar stays where it belongs and the
        // keyboard covers it, which is what every other app does. Each branch
        // keeps its own Scaffold and still resizes its own content, so nothing
        // being typed into is hidden by this.
        resizeToAvoidBottomInset: false,
        // The drawer cannot reach the navigation shell by itself — it is a
        // sibling of it in the tree — so switching tabs is handed to it.
        drawer: AppDrawer(onSelectTab: (tab) => _onTap(tab.index)),
        // The bar overlays the content instead of sitting in the layout.
        // Collapsing its height animated a relayout every frame, which is what
        // made hiding it feel like the page was resizing rather than sliding.
        body: Stack(
          children: [
            navigationShell,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // Tracks the scroll position rather than toggling: the bar leaves
              // with the content that pushed it out and comes back with the
              // content that pulled it in.
              child: ChromeSlide(
                fromTop: false,
                child: BlurredChrome(
                  border: Border(
                    top: BorderSide(color: borderColor, width: 0.5),
                  ),
                  child: SizedBox(
                    height:
                        ShellChrome.bottomBarHeight +
                        MediaQuery.of(context).padding.bottom,
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      currentIndex: navigationShell.currentIndex,
                      onTap: _onTap,
                      items: [
                        for (final tab in ShellTab.values)
                          BottomNavigationBarItem(
                            icon: _TabIcon(tab: tab, icon: tab.icon),
                            activeIcon: _TabIcon(
                              tab: tab,
                              icon: tab.activeIcon,
                            ),
                            label: tab.label,
                            tooltip: tab.label,
                          ),
                      ],
                    ),
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

/// A tab's icon, with the unread badge on the one tab that has a count.
///
/// A `Consumer` around the icon rather than around the bar: the count changes
/// whenever a message arrives, and rebuilding the whole bottom bar for it would
/// rebuild three icons that cannot have changed.
class _TabIcon extends StatelessWidget {
  final ShellTab tab;
  final IconData icon;

  const _TabIcon({required this.tab, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (tab != ShellTab.messages) return Icon(icon);

    return Consumer(
      builder: (context, ref, child) {
        final count = ref.watch(unreadChatCountProvider);
        if (count == 0) return child!;

        return Semantics(
          label: AppStrings.messagesUnreadSemantics(count),
          // The badge is a colour and a number over the icon, so the count is
          // said out loud rather than left to the red dot.
          child: Badge(
            label: Text(AppStrings.messagesUnreadBadge(count)),
            backgroundColor: AppColors.accent,
            child: child,
          ),
        );
      },
      child: Icon(icon),
    );
  }
}

/// A translucent surface that blurs whatever scrolls beneath it.
///
/// Used for both bars so they read as one material. A plain opaque band cuts
/// the page in two; the blur keeps the content visibly continuing underneath.
class BlurredChrome extends StatelessWidget {
  final Widget child;
  final BoxBorder? border;

  const BlurredChrome({super.key, required this.child, this.border});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ShellChrome.blurSigma,
          sigmaY: ShellChrome.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(
              alpha: ShellChrome.tintOpacity,
            ),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
