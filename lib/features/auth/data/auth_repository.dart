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

  /// gỡ thiết bị nhận push trc (request cần header Authorization, còn
  /// token thì sắp bị xoá), rồi mới xoá token cục bộ.
  Future<void> logout() async {
    // Hai bước, THỨ TỰ quan trọng -- gộp cả hai nhánh vì chúng lo hai việc khác nhau.
    //
    // 1. Gỡ thiết bị nhận push TRƯỚC: request đó cần header Authorization, mà token thì sắp bị
    //    xoá. Bỏ bước này thì máy vẫn nhận thông báo của tài khoản đã đăng xuất.
    // 2. clearSession() thay cho clearAccessToken/clearRefreshToken: nó xoá cả COOKIE, mà
    //    refresh token nằm chính ở đó chứ không phải trong secure storage -- AuthController trả
    //    refreshToken = null trong body và chỉ set cookie. Chỉ xoá token thì cookie phiên cũ
    //    còn nguyên, và người đăng nhập sau trên cùng máy có thể bị làm mới nhầm sang phiên
    //    của người trước.
    //
    // Không gọi API đăng xuất: backend không có endpoint nào cho việc đó (đã kiểm
    // AuthController).
    try {
      await PushMessagingService.unregisterDevice();
    } catch (_) {
      // Gỡ thiết bị hỏng không được phép chặn đăng xuất.
    }
    await TokenRefresher.clearSession();
  }
}
