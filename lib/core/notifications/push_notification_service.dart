import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/push_token_api.dart';
import '../storage/secure_storage.dart';
import 'notification_service.dart';
import 'notification_store.dart';

/// Wires FCM push notifications into the existing local-notification
class PushNotificationService {
  PushNotificationService._();

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Missing google-services.json / GoogleService-Info.plist before the
      // real Firebase project is wired up. Don't crash the app for it.
      debugPrint('PushNotificationService: Firebase init failed: $e');
      return;
    }

    await FirebaseMessaging.instance.requestPermission();

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);

    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

    FirebaseMessaging.onMessage.listen((message) => _handleMessage(message));
    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _handleMessage(message, navigate: true));

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage, navigate: true);
    }
  }

  static Future<void> _registerToken(String token) async {
    final deviceId = await SecureStorage().getDeviceId();
    if (deviceId == null) {
      debugPrint('PushNotificationService: no deviceId yet, skipping registration');
      return;
    }
    await PushTokenApi.register(deviceId, token);
  }

  static void _handleMessage(RemoteMessage message, {bool navigate = false}) {
    final type = message.data['type'];
    final examId = message.data['examId'] as String?;
    final NKind kind;
    final String title;
    final String body;
    switch (type) {
      case 'exam_candidate_added':
        kind = NKind.newExam;
        title = message.notification?.title ?? 'You have a new exam';
        body = message.notification?.body ?? 'Tap to view the exam.';
        break;
      case 'exam_member_assigned':
        kind = NKind.examAssignment;
        title = message.notification?.title ?? "You've been assigned to an exam";
        body = message.notification?.body ?? 'Tap to view the exam.';
        break;
      default:
        return;
    }

    final n = Notif(
      id: 'push-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      title: title,
      body: body,
      time: 'Just now',
      unread: true,
      target: NTarget.exam,
      examId: examId,
    );
    NotificationStore.instance.items.value = [n, ...NotificationStore.instance.items.value];

    if (navigate) {
      NotificationService.openNotifications(n.id);
    } else {
      NotificationService.show(title: title, body: body, payload: n.id);
    }
  }
}
