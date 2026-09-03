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

  /// Thu hồi phiên phía server.
  ///
  /// `deviceId` phải là ĐÚNG id đã dùng lúc đăng nhập: backend dọn mọi phiên còn sống của cặp
  /// (userId, deviceId), mà mỗi lần đăng nhập lại tạo một phiên mới nên máy này có thể đang
  /// mang nhiều phiên. Sinh id mới ở đây là thu hồi trượt, im lặng.
  Future<void> logout({required String deviceId}) async {
    await _apiClient.post(ApiEndpoints.logout, data: {'deviceId': deviceId});
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