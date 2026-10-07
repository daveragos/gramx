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

/// The route a tapped notification wants opened. Held in a provider because a
/// tap can cold-start the app before there is a navigator.
class PendingNotificationRoute extends Notifier<String?> {
  @override
  String? build() => null;

  void offer(String route) => state = route;

  /// Reads and clears the pending route in one step, so it can't open twice.
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

/// Shows the notifications TDLib decides on; TDLib applies mute settings and
/// removes ones read elsewhere. TDLib sends no `updateNotificationGroup` until
/// `notification_group_count_max` is set, since it defaults to zero.
class NotificationService {
  /// How many chats can have notifications up at once, and how many each may
  /// carry. TDLib's own ceiling for both is 25.
  static const int groupCountMax = 10;
  static const int groupSizeMax = 10;

  /// The Android notification channel.
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

  /// Sets up the plugin, enables TDLib notifications and listens. Idempotent.
  /// Once started it only turns TDLib's notifications back on, which
  /// [disableTdlibNotifications] turns off: it used to return early, so
  /// notifications switched off and on again stayed off until a restart.
  Future<void> start() async {
    if (_started) {
      await _enableTdlibNotifications();
      return;
    }
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
            // Requested from Settings via requestPermission, not at launch.
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

  /// Turns TDLib's notifications on. Without this it emits none.
  Future<void> _enableTdlibNotifications() async {
    await _setIntOption('notification_group_count_max', groupCountMax);
    await _setIntOption('notification_group_size_max', groupSizeMax);
  }

  /// Turns TDLib's notifications off, so no groups are generated at all.
  Future<void> disableTdlibNotifications() async {
    await _setIntOption('notification_group_count_max', 0);
    await _plugin.cancelAll();
    _groupOfNotification.clear();
  }

  Future<void> _setIntOption(String name, int value) async {
    try {
      await _tdlib.sendRequest(
        td.SetOption(
          name: name,
          value: td.OptionValueInteger(value: value),
        ),
      );
    } catch (e) {
      debugPrint('[Notify] could not set $name: $e');
    }
  }

  /// Asks for notification permission (required on Android 13+), from Settings.
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
    // Removals first, so a replaced notification and its successor are never
    // on screen together.
    for (final id in update.removedNotificationIds) {
      _groupOfNotification.remove(id);
      await _cancel(id);
    }

    final chat = _chatCache.chat(update.chatId);
    final chatTitle = chat?.title ?? '';
    final chatType = chat?.type;
    final isChannel = chatType is td.ChatTypeSupergroup && chatType.isChannel;

    for (final notification in update.addedNotifications) {
      final mapped = NotificationMapper.map(
        notification,
        groupId: update.notificationGroupId,
        chatId: update.chatId,
        chatTitle: chatTitle,
        isChannelPost: isChannel,
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
            // One stack per chat.
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

  /// Picks up a notification tap that launched the app. The plugin received it
  /// before Dart was running, so it has to be queried.
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
