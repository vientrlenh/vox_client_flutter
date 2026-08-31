import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/router.dart';
import '../../features/notifications/presentation/notification_destination.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../storage/preference_storage.dart';

/// Thông báo cục bộ (khay hệ thống). Chỉ cần cho push tới lúc app đang MỞ:
/// khi app ở nền hoặc đã thoát, FCM có sẵn khối `notification` nên hệ điều hành
/// tự dựng khay, plugin này không tham gia.
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
      onDidReceiveNotificationResponse: (response) =>
          openFromPush(decodePayload(response.payload)),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Điểm vào chung khi người dùng bấm vào một thông báo, dù là khay cục bộ hay
  /// khay hệ thống của FCM.
  ///
  /// Push mang `target` cùng các khoá điều hướng, nên ở đây dựng được đúng màn hình
  /// thay vì chỉ mở danh sách như trước. Không dựng được thì mở danh sách: thông báo
  /// vẫn đọc được đầy đủ ở đó, và đó là thứ trung thực nhất khi app này không có màn
  /// hình tương ứng (các target dành cho quản trị viên chẳng hạn).
  static void openFromPush(Map<String, String> payload) {
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;

    final destination = notificationDestination(payload) ?? const NotificationsScreen();
    navigator.push(MaterialPageRoute(builder: (_) => destination));
  }

  /// Mở thẳng danh sách, không qua payload. Dùng cho chuông trên thanh tiêu đề.
  static void openNotifications() {
    AppRouter.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  /// Payload của khay cục bộ là chuỗi JSON của chính `data` trong push.
  ///
  /// Hỏng hoặc rỗng thì trả map rỗng chứ không ném: người dùng vừa bấm vào một thông
  /// báo có thật, và mở danh sách vẫn hơn hẳn việc không có gì xảy ra.
  @visibleForTesting
  static Map<String, String> decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value != null) entry.key.toString(): entry.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Dựng khay cho push tới lúc app đang mở (foreground).
  static Future<void> show({
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    if (!await PreferenceStorage().getNotificationsEnabled()) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vox_notifications',
        'Vox Notifications',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: details,
      // Cả map chứ không chỉ `eventType` như trước: đây là toàn bộ thứ còn lại lúc
      // người dùng bấm vào khay, nên thiếu khoá nào là mất khả năng mở khoá đó.
      payload: jsonEncode(data),
    );
  }
}
