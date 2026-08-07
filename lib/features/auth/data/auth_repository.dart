

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vox_client_flutter/features/auth/data/models/login_response.dart';

import '../../../core/device/device_info.dart';
import '../../../core/network/push_token_api.dart';
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
    final deviceWithPushToken = await _withPushToken(device);
    final result = await _authApi.login(login: login, password: password, device: deviceWithPushToken);
    return _onLoginSuccess(result, device);
  }

  Future<LoginResponse> loginWithGoogle({
    required String idToken,
    required DeviceInfo device,
  }) async {
    final deviceWithPushToken = await _withPushToken(device);
    final result = await _authApi.loginWithGoogle(idToken: idToken, device: deviceWithPushToken);
    return _onLoginSuccess(result, device);
  }

  // a missing FCM token must never block login — the token can still be registered later.
  Future<DeviceInfo> _withPushToken(DeviceInfo device) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token != null ? device.copyWith(pushToken: token) : device;
    } catch (e) {
      return device;
    }
  }

  Future<LoginResponse> _onLoginSuccess(LoginResponse result, DeviceInfo device) async {
    await _secureStorage.saveAccessToken(result.accessToken);
    await _secureStorage.saveRefreshToken(result.refreshToken);
    await _secureStorage.saveDeviceId(device.deviceId);
    _registerPushToken(device.deviceId);
    return result;
  }

  // fire-and-forget — a missing/failed push token must never block login.
  // try/catch (not just .catchError) because FirebaseMessaging.instance itself
  // throws synchronously if Firebase never initialized — that throw happens
  // before a Future even exists to attach .catchError to.
  void _registerPushToken(String deviceId) {
    try {
      FirebaseMessaging.instance.getToken().then((token) {
        if (token != null) PushTokenApi.register(deviceId, token);
      }).catchError((Object e) {
        // Token fetch/registration failed after Firebase init succeeded — ignore.
      });
    } catch (e) {
      // Firebase not initialized (e.g. missing config file yet) — ignore.
    }
  }

  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (_) {
      // local logout must succeed regardless
    }
    await _secureStorage.clearAccessToken();
    await _secureStorage.clearRefreshToken();
  }
}