import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  Future<void> saveAccessToken(String token) {
    return _storage.write(key: 'access_token', value: token);
  }

  Future<String?> getAccessToken() {
    return _storage.read(key: 'access_token');
  }

  Future<void> clearAccessToken() {
    return _storage.delete(key: 'access_token');
  }

  Future<void> saveRefreshToken(String token) {
    return _storage.write(key: 'refresh_token', value: token);
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: 'refresh_token');
  }

  Future<void> clearRefreshToken() {
    return _storage.delete(key: 'refresh_token');
  }
}