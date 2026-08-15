import '../../../core/device/device_info.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/login_response.dart';

class AuthApi {
  AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginResponse> login({required String login, required String password, required DeviceInfo device}) async {
    final response = await _apiClient.post(ApiEndpoints.login, data: {
      'login': login,
      'password': password,
      'device': device.toJson()
    });
    var data = response.data['data'];
    return LoginResponse.fromJson(data);
  }

  Future<LoginResponse> loginWithGoogle({required String idToken, required DeviceInfo device}) async {
    final response = await _apiClient.post(ApiEndpoints.googleLogin, data: {
      'idToken': idToken,
      'device': device.toJson()
    });
    var data = response.data['data'];
    return LoginResponse.fromJson(data);
  }
}