import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/activity/domain/app_notification.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// The route a tapped notification wants opened.
///
/// Parked in a provider rather than pushed, for the same reason a deep link is:
/// a tap can wake the app from cold, which happens before there is a navigator.
class PendingNotificationRoute extends Notifier<String?> {
  @override
  String? build() => null;

  void offer(String route) => state = route;

  /// Takes the pending route, leaving nothing behind — so a rebuild between
  /// the read and the clear cannot open it twice.
  String? take() {
    final pending = state;
    state = null;
    return pending;
  }
}

final pendingNotificationRouteProvider =
    NotifierProvider<PendingNotificationRoute, String?>(
      PendingNotificationRoute.new,
    );

/// Draws the notifications TDLib decides on.
///
/// **The division of labour matters here.** TDLib decides *what* is worth
/// notifying about: it applies the reader's per-chat mute settings, their scope
/// settings, and — the part no local implementation could do — it takes a
/// notification down when the reader reads that message on another device. It
/// simply has no way to put one on the screen. That is all this is.
///
/// One consequence is worth stating: **TDLib generates no notification groups
/// until it is told how many to keep.** `notification_group_count_max` defaults
/// to zero, so a client that never sets it receives `updateNotificationGroup`
/// exactly never — which looks like the update stream being broken rather than
/// an option being unset.
class NotificationService {
  /// How many chats can have notifications up at once, and how many each may
  /// carry. TDLib's own ceiling for both is 25.
  static const int groupCountMax = 10;
  static const int groupSizeMax = 10;

  /// The Android channel. Named after what it carries, because this is a
  /// string the reader reads in their own system settings.
  static const String androidChannelId = 'gramx_messages';

  final TdlibService _tdlib;
  final ChatCache _chatCache;
  final FlutterLocalNotificationsPlugin _plugin;
  final Ref _ref;

  StreamSubscription<td.TdObject>? _sub;
  bool _started = false;

  /// Which chat each live notification belongs to, so a group being taken down
  /// can cancel the right ids. TDLib gives removals as ids without a chat.
  final Map<int, int> _groupOfNotification = {};

  NotificationService(
    this._ref,
    this._tdlib,
    this._chatCache, {
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Sets up the plugin, tells TDLib to start generating groups, and listens.
  ///
  /// Safe to call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _initialisePlugin();
    await _enableTdlibNotifications();

    _sub = _tdlib.updatesStream.listen(
      _onUpdate,
      onError: (Object e) => debugPrint('[Notify] update stream error: $e'),
    );
  }

  Future<void> _initialisePlugin() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Asked for explicitly below, on a screen that has explained what
            // it is for — not silently at launch.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );

      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                androidChannelId,
                AppStrings.notificationsChannelName,
                description: AppStrings.notificationsChannelBody,
                importance: Importance.high,
              ),
            );
      }
    } catch (e) {
      debugPrint('[Notify] could not initialise: $e');
    }
  }

  /// Turns TDLib's notification machinery on.
  ///
  /// Without this it emits nothing at all — see the class comment.
  Future<void> _enableTdlibNotifications() async {
    await _setIntOption('notification_group_count_max', groupCountMax);
    await _setIntOption('notification_group_size_max', groupSizeMax);
  }

  /// Turns it off again, which is what a reader switching notifications off
  /// should get: no groups generated, rather than groups generated and thrown
  /// away here.
  Future<void> disableTdlibNotifications() async {
    await _setIntOption('notification_group_count_max', 0);
    await _plugin.cancelAll();
    _groupOfNotification.clear();
  }

  Future<void> _setIntOption(String name, int value) async {
    try {
      await _tdlib.sendRequest(
        td.SetOption(name: name, value: td.OptionValueInteger(value: value)),
      );
    } catch (e) {
      debugPrint('[Notify] could not set $name: $e');
    }
  }

  /// Asks for permission to post notifications.
  ///
  /// Android 13+ requires it and refuses silently otherwise; iOS has always
  /// required it. Called from Settings, where the reader has just asked for
  /// this — never at launch, where a permission dialog with no context is the
  /// one every reader declines.
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } catch (e) {
      debugPrint('[Notify] permission request failed: $e');
      return false;
    }
  }

  void _onUpdate(td.TdObject object) {
    if (object is! td.UpdateNotificationGroup) return;
    if (!_ref.read(settingsProvider).notificationsEnabled) return;

    unawaited(_applyGroup(object));
  }

  Future<void> _applyGroup(td.UpdateNotificationGroup update) async {
    // Removals first: a group that both loses and gains notifications in one
    // update is Telegram replacing what is on screen, and showing the new one
    // before cancelling the old leaves both up for a frame.
    for (final id in update.removedNotificationIds) {
      _groupOfNotification.remove(id);
      await _cancel(id);
    }

    final chatTitle = _chatCache.chat(update.chatId)?.title ?? '';

    for (final notification in update.addedNotifications) {
      final mapped = NotificationMapper.map(
        notification,
        groupId: update.notificationGroupId,
        chatId: update.chatId,
        chatTitle: chatTitle,
      );
      if (mapped == null) continue;

      _groupOfNotification[mapped.id] = mapped.groupId;
      await _show(mapped);
    }
  }

  Future<void> _show(AppNotification notification) async {
    try {
      await _plugin.show(
        notification.id,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannelId,
            AppStrings.notificationsChannelName,
            channelDescription: AppStrings.notificationsChannelBody,
            importance: Importance.high,
            priority: Priority.high,
            // One stack per chat, which is how Telegram groups them and how
            // Android expects them.
            groupKey: 'chat_${notification.chatId}',
            silent: notification.isSilent,
            playSound: !notification.isSilent,
          ),
          iOS: DarwinNotificationDetails(
            threadIdentifier: 'chat_${notification.chatId}',
            presentSound: !notification.isSilent,
          ),
        ),
        payload: notification.route,
      );
    } catch (e) {
      debugPrint('[Notify] could not show ${notification.id}: $e');
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[Notify] could not cancel $id: $e');
    }
  }

  void _onTap(NotificationResponse response) {
    final route = response.payload;
    if (route == null || route.isEmpty) return;
    _ref.read(pendingNotificationRouteProvider.notifier).offer(route);
  }

  /// The route a notification tapped while the app was closed asked for.
  ///
  /// The plugin holds it from before Dart was running, so it has to be asked
  /// for rather than waited on.
  Future<void> collectLaunchTap() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      final route = details?.notificationResponse?.payload;
      if (route == null || route.isEmpty) return;
      _ref.read(pendingNotificationRouteProvider.notifier).offer(route);
    } catch (e) {
      debugPrint('[Notify] could not read the launch tap: $e');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    ref,
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
