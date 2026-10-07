import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/app_license.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/features/activity/data/notification_service.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/feed/presentation/seen_posts_provider.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_lifecycle.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Initializes services before running the app.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAppLicense();

  final container = ProviderContainer();

  // Must subscribe before TDLib starts polling: `updatesStream` is a broadcast
  // stream and anything emitted earlier is lost.
  container.read(chatCacheProvider);

  // Start loading seen posts from disk before the feed needs them.
  container.read(seenPostsProvider);

  // Awaited so auth state is available before the first frame.
  try {
    await container.read(tdlibServiceProvider).initialize();
    StartupTrace.mark('TDLib client up');
  } catch (e, stack) {
    debugPrint('TDLib initialization error: $e\n$stack');
  }

  // Subscribe to auth events before the first frame rather than waiting for
  // a widget to read the provider.
  container.read(authControllerProvider);

  // Started here so the first `resumed` is not missed.
  container.read(tdlibLifecycleProvider).start();

  // Not awaited: the launch link is parked and collected by the shell.
  unawaited(container.read(pendingDeepLinkProvider.notifier).start());

  // Starting the service makes TDLib generate notification groups, so it
  // only starts when notifications are on. Listened to, not read: the
  // saved settings load after this runs, and a read saw only the default
  // (off), so notifications never started at launch.
  final notifications = container.read(notificationServiceProvider);
  unawaited(notifications.collectLaunchTap());
  container.listen<bool>(
    settingsProvider.select((s) => s.notificationsEnabled),
    (_, enabled) {
      if (enabled) unawaited(notifications.start());
    },
    fireImmediately: true,
  );

  return container;
}
