import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/providers/theme_provider.dart';
import 'package:murrmobile/utils/app_preferences.dart';
import 'package:murrmobile/services/murrtube_api.dart';
import 'package:murrmobile/theme/app_theme.dart';

import 'support/fake_http.dart';
import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServer server;

  setUp(() {
    server = installTestEnv().server;
    MurrtubeApi.clearCookies();
  });

  tearDown(() {
    MurrtubeApi.clearCookies();
  });

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

    test('murrtube theme without auth falls back to dark', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'murrtube'});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.darkThemeData.scaffoldBackgroundColor, AppColors.bg);
    });

    test('murrtube theme fetches remote preference when authed', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'murrtube'});
      MurrtubeApi.setCookies('session_id=abc');
      server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {
          'user': {'theme': 'light'},
        }),
      );
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      await tester0();
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.themeData.brightness, Brightness.light);
    });

    test(
      'murrtube theme falls back to dark when settings fetch fails',
      () async {
        SharedPreferences.setMockInitialValues({'app_theme': 'murrtube'});
        MurrtubeApi.setCookies('session_id=abc');
        server.onGet('/settings', (req) => const FakeResponse(500, 'err'));
        final provider = ThemeProvider();
        await Future<void>.delayed(Duration.zero);
        await tester0();
        expect(provider.themeMode, ThemeMode.dark);
      },
    );

    test('murrtube theme keeps cached when user theme missing', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'murrtube'});
      MurrtubeApi.setCookies('session_id=abc');
      server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {'user': {}}),
      );
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      await tester0();
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('murrtube theme supports amoled remote value', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'murrtube'});
      MurrtubeApi.setCookies('session_id=abc');
      server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {
          'user': {'theme': 'amoled'},
        }),
      );
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      await tester0();
      expect(provider.darkThemeData.scaffoldBackgroundColor, AmoledColors.bg);
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

    test('setTheme to murrtube while authed fetches remote theme', () async {
      SharedPreferences.setMockInitialValues({});
      MurrtubeApi.setCookies('session_id=abc');
      server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {
          'user': {'theme': 'light'},
        }),
      );
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      await provider.setTheme('murrtube');
      expect(provider.themeMode, ThemeMode.light);
    });

    test('setTheme to murrtube while unauthed stays dark', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      await provider.setTheme('murrtube');
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('refreshMurrtubeTheme refetches when murrtube active', () async {
      SharedPreferences.setMockInitialValues({'app_theme': 'murrtube'});
      MurrtubeApi.setCookies('session_id=abc');
      var theme = 'light';
      server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {
          'user': {'theme': theme},
        }),
      );
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      await tester0();
      expect(provider.themeMode, ThemeMode.light);

      theme = 'dark';
      var notified = 0;
      provider.addListener(() => notified++);
      await provider.refreshMurrtubeTheme();
      expect(provider.themeMode, ThemeMode.dark);
      expect(notified, 1);
    });

    test('refreshMurrtubeTheme no-op on other themes', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      var notified = 0;
      provider.addListener(() => notified++);
      await provider.refreshMurrtubeTheme();
      expect(notified, 0);
    });
  });
}

/// Lets the provider's async _load/_fetchMurrtubeTheme microtasks complete.
Future<void> tester0() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
}
