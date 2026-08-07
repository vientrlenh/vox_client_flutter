import 'package:shared_preferences/shared_preferences.dart';

class PreferenceStorage {
  static const _rememberMeKey = 'remember_me';
  static const _lastLoginKey = 'last_login';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _languageCodeKey = 'language_code';
  static const _practiceOnboardingKey = 'practice_onboarding_done';

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

  Future<void> saveNotificationsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsEnabledKey, value);
  }

  Future<bool> getNotificationsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> saveLanguageCode(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languageCodeKey, value);
  }

  Future<String?> getLanguageCode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_languageCodeKey);
  }

  /// Whether the learner finished the personalized-practice onboarding.
  /// Gates the "Luyện nói" tab between the intro and the practice home.
  Future<void> savePracticeOnboardingDone(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_practiceOnboardingKey, value);
  }

  Future<bool> getPracticeOnboardingDone() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_practiceOnboardingKey) ?? false;
  }
}
