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
  static const String googleLogin = "/oauth2/google/token";
  static const String logout = "/v1/auth/logout";
  static const String pushToken = "/v1/devices/push-token";
  static const String examAppeals = "/v1/exam-appeals";

  static const String classTests = "/v1/class-tests";
  static String classTestById(String id) => "/v1/class-tests/$id";
  static String classTestQuestions(String id) => "/v1/class-tests/$id/questions";
  static String classTestStatus(String id) => "/v1/class-tests/$id/status";
}