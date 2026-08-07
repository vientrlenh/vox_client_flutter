import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_endpoints.dart';

/// Registers the device's FCM push token with the backend.
/// One endpoint, so a standalone function is enough — no repository needed.
class PushTokenApi {
  PushTokenApi._();

  static Future<void> register(String deviceId, String token) async {
    try {
      await ApiClient().put(
        ApiEndpoints.pushToken,
        data: {'deviceId': deviceId, 'pushToken': token},
      );
    } catch (e) {
      // ponytail: best-effort registration; never block login/app startup on this.
      debugPrint('PushTokenApi.register failed: $e');
    }
  }
}
