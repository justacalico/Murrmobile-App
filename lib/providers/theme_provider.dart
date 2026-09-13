import 'package:flutter/material.dart';
import '../utils/app_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  String _theme = 'auto';

  ThemeMode get themeMode {
    switch (_theme) {
      case 'auto':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.dark;
    }
  }

  ThemeData get themeData => AppTheme.light;

  ThemeData get darkThemeData =>
      _theme == 'amoled' ? AppTheme.amoled : AppTheme.dark;

  String get currentTheme => _theme;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    _theme = await AppPreferences.getTheme();
    if (_theme == 'murrtube') {
      _theme = 'dark';
      await AppPreferences.setTheme(_theme);
    }
    notifyListeners();
  }

  Future<void> reload() => _load();

  Future<void> setTheme(String theme) async {
    if (_theme == theme) return;
    _theme = theme;
    await AppPreferences.setTheme(theme);
    notifyListeners();
  }
}
