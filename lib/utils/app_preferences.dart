import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _themeKey = 'app_theme';
  static const _videoQualityKey = 'video_quality';
  static const _muteKey = 'video_muted';

  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'auto';
  }

  static Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  static Future<String> getVideoQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_videoQualityKey) ?? 'auto';
  }

  static Future<void> setVideoQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_videoQualityKey, quality);
  }

  static Future<bool> getMute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_muteKey) ?? false;
  }

  static Future<void> setMute(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, muted);
  }
}
