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

  static Future<Set<String>> getDismissedAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('dismissed_announcements') ?? []).toSet();
  }

  static Future<void> dismissAnnouncement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('dismissed_announcements') ?? [];
    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setStringList('dismissed_announcements', ids);
    }
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
