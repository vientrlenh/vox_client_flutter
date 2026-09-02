import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_storage.dart';
import 'notification_device_api.dart';
import 'pending_push_navigation.dart';
import 'notification_service.dart';
import 'notification_signal.dart';

/// Kết nối FCM với backend.
///
/// Backend định danh thiết bị bằng FID (Firebase Installation ID), không phải FCM
/// token: nó gửi push qua `MulticastMessage.addAllFids`. Token vẫn cần tồn tại --
/// FID chỉ là địa chỉ, còn bản cài đặt chỉ thật sự nhận được khi đã đăng ký với
/// FCM/APNs -- nhưng token không còn được gửi lên server nữa.
class PushMessagingService {
  PushMessagingService._();

  static bool _firebaseReady = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      // Chưa cắm google-services.json / GoogleService-Info.plist. Không được
      // làm chết app chỉ vì thiếu thông báo đẩy.
      debugPrint('PushMessagingService: Firebase init failed: $e');
      return;
    }

    await FirebaseMessaging.instance.requestPermission();

    // Ép bản cài đặt đăng ký với FCM/APNs. Giá trị trả về cố tình bỏ đi.
    try {
      await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('PushMessagingService: getToken failed: $e');
    }

    // Đăng ký lại mỗi lần mở app: backend upsert theo FID nên không sinh rác, đổi
    // lại `last_seen_at` được làm mới -- thiết bị im lặng quá 90 ngày sẽ bị job dọn
    // xoá, mà một người dùng đăng nhập liên tục thì không bao giờ gọi lại lúc login.
    await registerDevice();

    // FID chỉ đổi khi app bị cài lại / xoá dữ liệu, KHÔNG đổi theo token refresh --
    // nên đây là chỗ thay cho `onTokenRefresh` của luồng cũ.
    FirebaseInstallations.instance.onIdChange.listen((_) => registerDevice());

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App đang chạy nền: navigator đã tồn tại và người dùng đã đăng nhập, điều hướng
    // được ngay.
    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => NotificationService.openFromPush(_dataOf(message)));

    // App đã tắt hẳn: hàm này chạy trong `main()`, TRƯỚC `runApp`, nên chưa có
    // navigator để điều hướng và cũng chưa đăng nhập. Cất lại, MainShell tiêu thụ.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      PendingPushNavigation.remember(_dataOf(initialMessage));
    }
  }

  /// FID của bản cài đặt này, `null` nếu Firebase chưa sẵn sàng hoặc nền tảng
  /// không có plugin (`firebase_app_installations` chỉ có android/ios/macos).
  static Future<String?> installationId() async {
    if (!_firebaseReady) return null;
    try {
      return await FirebaseInstallations.instance.getId();
    } catch (e) {
      debugPrint('PushMessagingService: getId failed: $e');
      return null;
    }
  }

  /// Ghi thiết bị này vào danh sách nhận push của tài khoản đang đăng nhập.
  ///
  /// Best-effort tuyệt đối: endpoint cần access token nên trước khi đăng nhập
  /// sẽ không có `deviceId` để gọi, và một lần hỏng cũng không được phép chặn
  /// luồng đăng nhập hay khởi động app.
  static Future<void> registerDevice() async {
    final platform = currentPushPlatform();
    if (platform == null) return; // desktop: backend không có enum tương ứng

    final deviceId = await SecureStorage().getDeviceId();
    if (deviceId == null) return; // chưa đăng nhập

    final installation = await installationId();
    if (installation == null) return;

    try {
      await NotificationDeviceApi.register(
        deviceId: deviceId,
        platform: platform,
        installationId: installation,
      );
    } catch (e) {
      debugPrint('PushMessagingService: register device failed: $e');
    }
  }

  /// Chỉ dùng khi người dùng chủ động tắt thông báo trên máy này. Đăng xuất thì
  /// backend đã tự gỡ theo `DeviceSessionRevokedEvent`.
  static Future<void> unregisterDevice() async {
    final installation = await installationId();
    if (installation == null) return;
    try {
      await NotificationDeviceApi.unregister(installation);
    } catch (e) {
      debugPrint('PushMessagingService: unregister device failed: $e');
    }
  }

  /// Push tới lúc app đang mở thì hệ điều hành không dựng khay, phải tự dựng.
  ///
  /// Nội dung hiển thị lấy nguyên từ khối `notification` của FCM (backend đã
  /// dựng sẵn tiêu đề/nội dung tiếng Việt); phần `data` chỉ dùng để điều hướng.
  static void _onForegroundMessage(RemoteMessage message) {
    NotificationSignal.instance.onPushReceived();

    final title = message.notification?.title;
    if (title == null) return;

    NotificationService.show(
      title: title,
      body: message.notification?.body ?? '',
      data: _dataOf(message),
    );
  }

  /// `RemoteMessage.data` là `Map<String, dynamic>` dù FCM chỉ chở được chuỗi.
  static Map<String, String> _dataOf(RemoteMessage message) => {
        for (final entry in message.data.entries)
          if (entry.value != null) entry.key: entry.value.toString(),
      };
}
