import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/providers/theme_provider.dart';
import 'package:murrmobile/utils/app_preferences.dart';
import 'package:murrmobile/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    test('defaults to auto -> system mode, dark data', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.darkThemeData.brightness, Brightness.dark);
      expect(provider.currentTheme, 'auto');
    });

    test('light theme maps correctly', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'light'});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.themeData.brightness, Brightness.light);
    });

    test('amoled theme maps to dark mode with black scaffold', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'amoled'});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.darkThemeData.scaffoldBackgroundColor, AmoledColors.bg);
    });

    test('dark theme maps to dark', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'dark'});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      expect(provider.darkThemeData.scaffoldBackgroundColor, AppColors.bg);
    });

    test('stored murrtube theme migrates to dark', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'murrtube'});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      expect(provider.currentTheme, 'dark');
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.darkThemeData.scaffoldBackgroundColor, AppColors.bg);
      expect(await AppPreferences.getTheme(), 'dark');
    });

    test('setTheme persists and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      var notified = 0;
      provider.addListener(() => notified++);
      await provider.setTheme('light');
      expect(provider.currentTheme, 'light');
      expect(provider.themeMode, ThemeMode.light);
      expect(notified, greaterThan(0));
      expect(await AppPreferences.getTheme(), 'light');
    });

    test('setTheme same value is a no-op', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      var notified = 0;
      provider.addListener(() => notified++);
      await provider.setTheme('auto');
      expect(notified, 0);
    });
  });
}
