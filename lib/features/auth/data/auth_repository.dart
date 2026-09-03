import 'package:vox_client_flutter/features/auth/data/models/login_response.dart';

import '../../../core/device/device_info.dart';
import '../../../core/messaging/push_messaging_service.dart';
import '../../../core/network/token_refresher.dart';
import '../../../core/storage/secure_storage.dart';
import 'auth_api.dart';

class AuthRepository {
  AuthRepository({
    required this._authApi,
    required this._secureStorage,
  });

  final AuthApi _authApi;
  final SecureStorage _secureStorage;

  Future<LoginResponse> login({
    required String login,
    required String password,
    required DeviceInfo device
  }) async {
    final result = await _authApi.login(login: login, password: password, device: device);
    return _onLoginSuccess(result, device);
  }

  Future<LoginResponse> loginWithGoogle({
    required String idToken,
    required DeviceInfo device,
  }) async {
    final result = await _authApi.loginWithGoogle(idToken: idToken, device: device);
    return _onLoginSuccess(result, device);
  }

  Future<LoginResponse> _onLoginSuccess(LoginResponse result, DeviceInfo device) async {
    await _secureStorage.saveAccessToken(result.accessToken);
    await _secureStorage.saveRefreshToken(result.refreshToken);
    await _secureStorage.saveDeviceId(device.deviceId);
    _registerPushDevice();
    return result;
  }

  /// Đăng ký thiết bị nhận push, fire-and-forget.
  ///
  /// Phải chạy SAU khi lưu access token và deviceId: endpoint
  /// `POST /v1/notifications/devices` yêu cầu đã xác thực, và bản ghi thiết bị
  /// gắn với đúng deviceId của phiên này -- backend gỡ nó theo deviceId khi phiên
  /// bị thu hồi. Bản thân việc đăng ký đã nuốt lỗi bên trong nên không có gì
  /// chặn được luồng đăng nhập.
  void _registerPushDevice() {
    PushMessagingService.registerDevice();
  }

  /// Gỡ thiết bị nhận push và thu hồi phiên phía server TRƯỚC, rồi mới xoá phiên cục bộ.
  Future<void> logout() async {
    // Ba bước, THỨ TỰ là phần quan trọng nhất.
    //
    // 1. Gỡ thiết bị nhận push TRƯỚC: request đó cần header Authorization, mà token thì sắp bị
    //    xoá. Bỏ bước này thì máy vẫn nhận thông báo của tài khoản đã đăng xuất.
    // 2. Thu hồi phiên phía server. Cũng phải chạy TRƯỚC clearSession(): lời gọi này cần cả
    //    access token lẫn cookie refresh_token, và clearSession() xoá đúng hai thứ đó.
    // 3. clearSession() thay cho clearAccessToken/clearRefreshToken: nó xoá cả COOKIE, mà
    //    refresh token nằm chính ở đó chứ không phải trong secure storage -- AuthController trả
    //    refreshToken = null trong body và chỉ set cookie. Chỉ xoá token thì cookie phiên cũ
    //    còn nguyên, và người đăng nhập sau trên cùng máy có thể bị làm mới nhầm sang phiên
    //    của người trước.
    try {
      await PushMessagingService.unregisterDevice();
    } catch (_) {
      // Gỡ thiết bị hỏng không được phép chặn đăng xuất.
    }

    // Nuốt lỗi có chủ đích: bước dưới xoá sạch phiên cục bộ bất kể kết quả, nên ném lỗi ra
    // ngoài chỉ tạo ra trạng thái tệ nhất -- người dùng đã bấm đăng xuất mà vẫn bị giữ lại
    // trong app. Backend cũng được viết theo đúng giao kèo đó: /logout luôn trả 200, kể cả khi
    // không có gì để thu hồi.
    try {
      final deviceId = await _secureStorage.getDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        await _authApi.logout(deviceId: deviceId);
      }
    } catch (_) {
      // Mất mạng hay 403 CSRF đều không được phép chặn đường đăng xuất.
    }

    await TokenRefresher.clearSession();
  }
}
