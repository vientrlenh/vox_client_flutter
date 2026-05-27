import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/login_response.dart';

class AuthApi {
  AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginResponse> login({required String login, required String password}) async {
    final response = await _apiClient.post(ApiEndpoints.login, data: {
      'login': login,
      'password': password
    });
    var data = response.data['data'];
    return LoginResponse.fromJson(data);
  }
}