import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/features/activity/data/notification_service.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_lifecycle.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Initializes services before running the app.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Subscribe the chat mirror BEFORE TDLib starts polling. ChatCache replaces
  // the per-chat GetChat fan-out, and `updatesStream` is a broadcast stream —
  // it buffers nothing, so anything emitted before this line is lost and those
  // channels never reach the feed. Order matters here.
  container.read(chatCacheProvider);

  // Initialize TDLib Service and start Updates Isolate asynchronously.
  // We await this so auth state is available before the first frame renders.
  try {
    await container.read(tdlibServiceProvider).initialize();
  } catch (e, stack) {
    debugPrint('TDLib initialization error: $e\n$stack');
  }

  // Eagerly prime the AuthController so it subscribes to TDLib auth events
  // BEFORE the first frame. Without this, the auth subscription only starts
  // when a widget reads authControllerProvider — which may never happen if
  // the router hasn't redirected to /auth yet.
  container.read(authControllerProvider);

  // Start observing the app's lifecycle and the device's network.
  //
  // Here rather than in a widget: an observer created by whichever screen
  // happened to read it first would miss every transition before that screen
  // was built, and the transition that matters most — the first `resumed` —
  // is the earliest one there is.
  container.read(tdlibLifecycleProvider).start();

  // Start listening for links, and pick up the one the app was launched with.
  // Not awaited: a launch link is parked in the provider and collected by the
  // shell once there is a navigator, so nothing here has to wait for it.
  unawaited(container.read(pendingDeepLinkProvider.notifier).start());

  // Notifications, but only for a reader who has said yes. Starting the
  // service is also what tells TDLib to generate notification groups at all —
  // it produces none until asked — so a reader with the setting off costs
  // nothing rather than costing groups that are thrown away here.
  //
  // The launch tap is collected either way: it is a tap that already happened,
  // and the setting may have been turned off since.
  final notifications = container.read(notificationServiceProvider);
  unawaited(notifications.collectLaunchTap());
  if (container.read(settingsProvider).notificationsEnabled) {
    unawaited(notifications.start());
  }

  return container;
}
