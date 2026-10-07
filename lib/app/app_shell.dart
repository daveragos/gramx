import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/activity/presentation/activity_screen.dart';
import 'package:gramx/features/activity/presentation/activity_providers.dart';
import 'package:gramx/app/widgets/chat_bubble_icon.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/widgets/app_drawer.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/core/navigation/telegram_link_resolver.dart';
import 'package:gramx/features/activity/data/notification_service.dart';
import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/core/navigation/share_intake.dart';
import 'package:gramx/core/navigation/url_launcher_utils.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/compose/presentation/compose_screen.dart';
import 'package:gramx/app/widgets/shell_fab.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/search/presentation/search_screen.dart';
import 'package:gramx/features/feed/presentation/pending_posts_provider.dart';

/// The bottom bar tabs. The router declares its branches in this order.
enum ShellTab {
  home(Icons.home_outlined, Icons.home, 'Home', '/home'),
  search(Icons.search_outlined, Icons.search, 'Search', '/search'),
  channels(Icons.list_alt_outlined, Icons.list_alt, 'Channels', '/channels'),
  activity(
    Icons.notifications_none_rounded,
    Icons.notifications_rounded,
    'Activity',
    ActivityScreen.route,
  ),
  // Drawn by ChatBubbleIcon; these stand in where an IconData is needed.
  messages(
    Icons.chat_bubble_outline_rounded,
    Icons.chat_bubble_rounded,
    'Messages',
    '/messages',
  );

  const ShellTab(this.icon, this.activeIcon, this.label, this.path);

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// The route this tab's branch is rooted at.
  final String path;
}

/// Chrome geometry and motion shared by the header and bottom bar.
abstract class ShellChrome {
  static const double bottomBarHeight = 56;
  static const Duration slideDuration = Duration(milliseconds: 220);
  static const Curve slideCurve = Curves.easeOutCubic;

  static const double blurSigma = 18;

  /// Opacity of the tint over the blur.
  static const double tintOpacity = 0.72;
}

/// The shell's scaffold, for opening the drawer from inside a branch.
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

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  /// How long a second back press still counts as confirming exit.
  static const Duration _exitWindow = Duration(seconds: 2);

  /// The floating button's distance from the edge and from the bar.
  static const double _fabMargin = 16;

  DateTime? _lastBackPress;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();

    // Shares usually arrive on resume, so they are also collected there.
    WidgetsBinding.instance.addObserver(this);
    _afterFrame(_openSharedText);

    // Notification taps and links from a cold start wait here for a navigator.
    ref.listenManual<String?>(pendingNotificationRouteProvider, (_, next) {
      if (next != null) _afterFrame(_openNotificationRoute);
    }, fireImmediately: true);

    ref.listenManual<Uri?>(pendingDeepLinkProvider, (_, next) {
      if (next != null) _afterFrame(_openDeepLink);
    }, fireImmediately: true);

    // Shares from the iOS share extension, which arrive as links.
    ref.listenManual<String?>(pendingSharedTextProvider, (_, next) {
      if (next != null) _afterFrame(_openSharedText);
    }, fireImmediately: true);
  }

  /// Runs [action] after the current frame, scheduling one if the app is
  /// idle. On a cold start the listeners above fire inside initState, where
  /// taking a pending item (which clears it) would change a provider
  /// mid-build.
  void _afterFrame(Future<void> Function() action) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) unawaited(action());
      })
      ..ensureVisualUpdate();
  }

  Future<void> _openNotificationRoute() async {
    final route = ref.read(pendingNotificationRouteProvider.notifier).take();
    if (route != null && mounted) GoRouter.of(context).push(route);
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

  /// Opens the composer on shared text, if the account can post anywhere.
  Future<void> _openSharedText() async {
    final text =
        ref.read(pendingSharedTextProvider.notifier).take() ??
        await ref.read(shareIntakeProvider).take();
    if (text == null || !mounted) return;

    var hasTargets = ref.read(composeTargetsProvider).isNotEmpty;
    // At a cold start the chats are still loading, and the share was turned
    // away as having nowhere to go. A guest has nowhere anyway.
    if (!hasTargets && ref.read(readerCapabilitiesProvider).canPost) {
      await ref
          .read(chatCacheProvider)
          .ensureFirstPage()
          .timeout(const Duration(seconds: 15), onTimeout: () {});
      if (!mounted) return;
      hasTargets = ref.read(composeTargetsSourceProvider)().isNotEmpty;
    }

    if (!hasTargets) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.shareNowhereToPost),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    GoRouter.of(context).push(ComposeScreen.route, extra: text);
  }

  /// Opens the pending deep link (a username costs one `SearchPublicChat`).
  /// Links with no screen here are opened externally.
  Future<void> _openDeepLink() async {
    final uri = ref.read(pendingDeepLinkProvider.notifier).take();
    if (uri == null) return;

    // Offline; see TelegramLinkResolver.
    final link = await ref.read(telegramLinkResolverProvider).resolve(uri);
    if (link == null) {
      await openExternalUrl(uri);
      return;
    }

    // A hashtag opens a search rather than a route.
    if (link is TelegramHashtagLink) {
      if (mounted) openHashtagSearch(context, ref, link.tag);
      return;
    }

    var chatId = link is TelegramPrivatePostLink ? link.chatId : null;
    var kind = ResolvedChatKind.channel;

    // A private message link can be a group's, which opens as a chat.
    if (link is TelegramPrivatePostLink) {
      kind =
          await ref.read(chatsRepositoryProvider).chatKind(link.chatId) ?? kind;
    }

    final username = DeepLinkRoutes.usernameToResolve(link);
    if (username != null) {
      final resolved = await ref
          .read(chatsRepositoryProvider)
          .resolveUsername(username);
      chatId = resolved?.chatId;
      kind = resolved?.kind ?? kind;
    }

    final route = DeepLinkRoutes.routeFor(link, chatId: chatId, kind: kind);
    if (route == null) {
      await openExternalUrl(uri);
      return;
    }
    if (!mounted) return;
    GoRouter.of(context).push(route);
  }

  /// Back from another tab returns to Home. On Home, a second press within
  /// [_exitWindow] exits.
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

  /// Switches branch, or returns to the branch's root if it is already active.
  void _onTap(int index) {
    final isRetap = index == navigationShell.currentIndex;

    // Branches stay mounted, so reset the chrome on every switch.
    ref.read(chromeOffsetProvider.notifier).show(animate: false);

    // goBranch only resets the route stack; a retap also scrolls to the top.
    if (isRetap && index == ShellTab.home.index) {
      ref
          .read(feedScrollToTopProvider.notifier)
          .request(ref.read(activeFolderProvider));
    }
    if (isRetap && index == ShellTab.messages.index) {
      ref.read(chatsScrollToTopProvider.notifier).request();
    }
    // As on X, tapping Search again starts a search.
    if (isRetap && index == ShellTab.search.index) {
      ref.read(searchFocusTriggerProvider.notifier).trigger();
    }
    // Activity reloads when there's something new, or when asked again.
    if (index == ShellTab.activity.index &&
        (isRetap || ref.read(activityBadgeProvider) > 0)) {
      ref.invalidate(activityFeedProvider);
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
        // Keeps the bar off the keyboard; branches still resize for it.
        resizeToAvoidBottomInset: false,
        // A sibling of the navigation shell, so tab switching is passed in.
        drawer: AppDrawer(onSelectTab: (tab) => _onTap(tab.index)),
        // The bar overlays the content so hiding it does not relayout.
        body: Stack(
          children: [
            navigationShell,
            // Above the bar, where a Scaffold would float it.
            PositionedDirectional(
              end: _fabMargin,
              bottom:
                  ShellChrome.bottomBarHeight +
                  MediaQuery.viewPaddingOf(context).bottom +
                  _fabMargin,
              child: ShellFab(
                tab: ShellTab.values[navigationShell.currentIndex],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // Follows the scroll position rather than toggling.
              child: ChromeSlide(
                fromTop: false,
                child: BlurredChrome(
                  border: Border(
                    top: BorderSide(color: borderColor, width: 0.5),
                  ),
                  // viewPadding, as BottomNavigationBar pads by it: padding
                  // drops to zero under the keyboard and squeezes the bar.
                  child: SizedBox(
                    height:
                        ShellChrome.bottomBarHeight +
                        MediaQuery.viewPaddingOf(context).bottom,
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      // The labels are hidden but still laid out; at full
                      // size their line pushes the icons past the bar.
                      selectedFontSize: 0,
                      unselectedFontSize: 0,
                      currentIndex: navigationShell.currentIndex,
                      onTap: _onTap,
                      items: [
                        for (final tab in ShellTab.values)
                          BottomNavigationBarItem(
                            icon: _TabIcon(tab: tab, active: false),
                            activeIcon: _TabIcon(tab: tab, active: true),
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

/// A tab's icon, with the unread badge on Messages. The `Consumer` wraps only
/// the icon so a new message does not rebuild the whole bar.
class _TabIcon extends StatelessWidget {
  final ShellTab tab;
  final bool active;

  const _TabIcon({required this.tab, required this.active});

  @override
  Widget build(BuildContext context) {
    final icon = active ? tab.activeIcon : tab.icon;
    return switch (tab) {
      ShellTab.home => _HomeIcon(icon: icon),
      ShellTab.activity => Consumer(
        builder: (context, ref, child) => _CountBadge(
          count: ref.watch(activityBadgeProvider),
          semanticsLabel: AppStrings.a11yActivity,
          child: child!,
        ),
        child: Icon(icon),
      ),
      ShellTab.messages => Consumer(
        builder: (context, ref, child) => _CountBadge(
          count: ref.watch(unreadChatCountProvider),
          semanticsLabel: AppStrings.messagesUnreadSemantics,
          child: child!,
        ),
        child: ChatBubbleIcon(filled: active),
      ),
      _ => Icon(icon),
    };
  }
}

/// A tab icon with an unread count, as on X's bell and messages.
class _CountBadge extends StatelessWidget {
  final int count;
  final String Function(int count) semanticsLabel;
  final Widget child;

  const _CountBadge({
    required this.count,
    required this.semanticsLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Semantics(
      label: semanticsLabel(count),
      child: Badge(
        label: Text(AppStrings.messagesUnreadBadge(count)),
        backgroundColor: AppColors.accent,
        child: child,
      ),
    );
  }
}

/// The Home icon, with a dot when new posts are waiting.
class _HomeIcon extends StatelessWidget {
  final IconData icon;

  const _HomeIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // "All" tab pending posts, so muted channels do not light the dot.
        final waiting = ref.watch(
          pendingPostsForFolderProvider('All').select((p) => p.isNotEmpty),
        );
        if (!waiting) return child!;

        return Semantics(
          label: AppStrings.homeNewPostsSemantics,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: Icon(icon),
    );
  }
}

/// A translucent surface that blurs what scrolls beneath it.
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
