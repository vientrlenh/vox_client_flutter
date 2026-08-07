import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/router.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../storage/preference_storage.dart';
import 'notification_store.dart';

class NotificationService {
  NotificationService._();
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open');
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        linux: linuxInit,
      ),
      onDidReceiveNotificationResponse: _onTap,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void _onTap(NotificationResponse response) {
    final id = response.payload;
    if (id == null) return;
    openNotifications(id);
  }

  /// Shared tap-handling entry point: marks the notification read and
  /// navigates to the notifications screen. Used both by local-notification
  /// taps and by push notification taps (foreground/background/terminated).
  static void openNotifications(String id) {
    NotificationStore.instance.markRead(id);
    AppRouter.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  /// Shows a local notification using the already-initialized plugin.
  /// Used by push notifications arriving in the foreground.
  static Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!await PreferenceStorage().getNotificationsEnabled()) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: payload.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
