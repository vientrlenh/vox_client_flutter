import 'package:shared_preferences/shared_preferences.dart';

class PreferenceStorage {
  static const _rememberMeKey = 'remember_me';
  static const _lastLoginKey = 'last_login';

  Future<void> saveRememberMe(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberMeKey, value);
  }

  Future<bool> getRememberMe() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_rememberMeKey) ?? true;
  }

  Future<void> saveLastLogin(String login) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastLoginKey, login);
  }

  Future<String?> getLastLogin() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_lastLoginKey);
  }

  Future<void> clearLoginPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_rememberMeKey);
    await preferences.remove(_lastLoginKey);
  }
}
