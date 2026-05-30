

import 'package:vox_client_flutter/features/auth/data/models/login_response.dart';

import '../../../core/device/device_info.dart';
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
    await _secureStorage.saveAccessToken(result.accessToken);
    await _secureStorage.saveRefreshToken(result.refreshToken);
    await _secureStorage.saveDeviceId(device.deviceId);
    return result;
  }
}