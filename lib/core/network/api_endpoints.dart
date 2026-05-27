import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String baseUrl = dotenv.get('API_URL', fallback: 'http://localhost:8080/api');

  static const String login = "/v1/auth/login";
}