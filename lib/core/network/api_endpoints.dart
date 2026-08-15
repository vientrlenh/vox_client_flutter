import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String baseUrl = dotenv.get('API_URL');

  static String get graphqlBaseUrl => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  /// Base URL of the Python realtime/AI service (`agents/`) -- a SEPARATE service from the
  /// Java backend above. Mirrors WPF's `AppSettings.PythonBaseUrl` (same default port 8000).
  static String get aiServiceBaseUrl =>
      dotenv.env['AI_SERVICE_URL'] ?? 'http://localhost:8000';

  /// Same host/port as [aiServiceBaseUrl], scheme swapped for a WebSocket connection
  /// (http->ws, https->wss) -- mirrors RealtimeSessionClient.cs's ConnectCoreAsync.
  static String get aiServiceWsBaseUrl => aiServiceBaseUrl
      .replaceFirst(RegExp(r'^https'), 'wss')
      .replaceFirst(RegExp(r'^http'), 'ws');

  static const String login = "/v1/auth/login";
  /// Xác thực Google idToken lấy được native trên app (khác hẳn luồng redirect
  /// trình duyệt mà web dùng) -- backend trả thẳng accessToken/refreshToken trong body vì app không dùng cookie.
  static const String googleLogin = "/v1/auth/oauth2/google/token";
  // Không có endpoint đăng xuất phía backend: logout chỉ gỡ thiết
  // bị nhận push rồi xoá token cục bộ -- xem AuthRepository.logout().
  /// Web gửi refresh token qua cookie HttpOnly; app không có cookie jar nên gửi
  /// thẳng trong body (xem `ApiClient._refreshAccessToken`) và backend trả
  /// refreshToken mới lại trong body thay vì chỉ set cookie.
  static const String refresh = "/v1/auth/refresh";
  /// Thiết bị nhận thông báo đẩy. Định danh là FID (Firebase Installation ID),
  /// KHÔNG phải FCM token -- backend gửi push bằng `MulticastMessage.addAllFids`.
  static const String notificationDevices = "/v1/notifications/devices";
  static String notificationDevice(String installationId) =>
      "/v1/notifications/devices/$installationId";
  static String notificationRead(String id) => "/v1/notifications/$id/read";
  static const String notificationsReadAll = "/v1/notifications/read-all";
  static const String examAppeals = "/v1/exam-appeals";

  static const String classTests = "/v1/class-tests";
  static String classTestById(String id) => "/v1/class-tests/$id";
  static String classTestQuestions(String id) => "/v1/class-tests/$id/questions";
  static String classTestStatus(String id) => "/v1/class-tests/$id/status";
}