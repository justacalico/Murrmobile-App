import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:murrmobile/pages/settings_page.dart';
import 'package:murrmobile/services/murrtube_api.dart';
import 'package:murrmobile/utils/app_preferences.dart';
import 'package:murrmobile/utils/cookie_loader.dart';
import 'package:murrmobile/utils/data_transfer.dart';

import 'support/test_app.dart';

class FakeSharePlatform extends Fake
    with MockPlatformInterfaceMixin
    implements SharePlatform {
  final List<List<String>> sharedPaths = [];
  bool throwUnimplemented = false;

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) {
    if (throwUnimplemented) {
      throw UnimplementedError('shareXFiles not implemented');
    }
    sharedPaths.add(files.map((f) => f.path).toList());
    return Future.value(
      const ShareResult('', ShareResultStatus.success),
    );
  }
}

/// Runs several real-async windows so pending file IO and fake http calls
/// kicked off by widget callbacks can finish.
Future<void> flushRealIo(WidgetTester tester, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await settleAsync(tester, const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataTransfer', () {
    test('exportJson includes preferences, cookies, and app marker', () async {
      installTestEnv();
      await AppPreferences.setTheme('amoled');
      await AppPreferences.setMute(true);
      await CookieLoader.save('session_id=abc; _murrtube_v3_session=xyz');

      final decoded = jsonDecode(await DataTransfer.exportJson())
          as Map<String, dynamic>;

      expect(decoded['app'], 'murrmobile');
      expect(decoded['format_version'], 1);
      expect(decoded['exported_at'], isA<String>());
      final prefs = decoded['preferences'] as Map<String, dynamic>;
      expect(prefs['app_theme'], 'amoled');
      expect(prefs['video_muted'], isTrue);
      expect(
        decoded['cookies'],
        'session_id=abc; _murrtube_v3_session=xyz',
      );
    });

    test('exportToFile writes the json to temp dir', () async {
      installTestEnv();
      final file = await DataTransfer.exportToFile();
      expect(await file.exists(), isTrue);
      final decoded = jsonDecode(await file.readAsString());
      expect(decoded['app'], 'murrmobile');
    });

    test('exportToDocuments writes to the documents dir', () async {
      installTestEnv();
      final file = await DataTransfer.exportToDocuments();
      final docs = (await getApplicationDocumentsDirectory()).path;
      expect(file.path, '$docs/murrmobile_backup.json');
      expect(jsonDecode(await file.readAsString())['app'], 'murrmobile');
    });

    test('import restores preferences and login cookies', () async {
      installTestEnv();
      await AppPreferences.setTheme('amoled');
      await AppPreferences.setVideoQuality('720p');
      await CookieLoader.save('session_id=froma; age_check=yes');
      final backup = await DataTransfer.exportJson();

      // Simulate a fresh device.
      SharedPreferences.setMockInitialValues({});
      MurrtubeApi.clearCookies();
      await CookieLoader.clear();
      expect(await AppPreferences.getTheme(), 'auto');
      expect(MurrtubeApi.isAuthenticated, isFalse);

      await DataTransfer.importJson(backup);

      expect(await AppPreferences.getTheme(), 'amoled');
      expect(await AppPreferences.getVideoQuality(), '720p');
      expect(MurrtubeApi.isAuthenticated, isTrue);
      expect(
        await CookieLoader.load(),
        'session_id=froma; age_check=yes',
      );
    });

    test('import restores value types correctly', () async {
      installTestEnv();
      final backup = jsonEncode({
        'app': 'murrmobile',
        'format_version': 1,
        'preferences': {
          'a_bool': true,
          'an_int': 42,
          'a_double': 1.5,
          'a_string': 'hi',
          'a_list': ['x', 'y'],
        },
      });
      await DataTransfer.importJson(backup);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('a_bool'), isTrue);
      expect(prefs.getInt('an_int'), 42);
      expect(prefs.getDouble('a_double'), 1.5);
      expect(prefs.getString('a_string'), 'hi');
      expect(prefs.getStringList('a_list'), ['x', 'y']);
    });

    test('import without cookies clears login', () async {
      installTestEnv();
      MurrtubeApi.setCookies('session_id=abc');
      await CookieLoader.save('session_id=abc');
      final backup = jsonEncode({
        'app': 'murrmobile',
        'format_version': 1,
        'preferences': <String, dynamic>{},
        'cookies': null,
      });
      await DataTransfer.importJson(backup);
      expect(MurrtubeApi.hasCookies, isFalse);
      expect(await CookieLoader.load(), isNull);
    });

    test('exportJson prefers the live cookie jar over the saved file', () async {
      installTestEnv();
      await CookieLoader.save('session_id=stale');
      MurrtubeApi.setCookies('session_id=rotated');
      final decoded = jsonDecode(await DataTransfer.exportJson());
      expect(decoded['cookies'], 'session_id=rotated');
      MurrtubeApi.clearCookies();
    });

    test('import rejects garbage and other apps', () async {
      installTestEnv();
      expect(
        () => DataTransfer.importJson('not json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DataTransfer.importJson(jsonEncode({'app': 'other'})),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DataTransfer.importJson(jsonEncode([1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
    });

    test('import rejects a newer format version', () async {
      installTestEnv();
      expect(
        () => DataTransfer.importJson(
          jsonEncode({'app': 'murrmobile', 'format_version': 99}),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('import skips wrongly typed values for known keys', () async {
      installTestEnv();
      final backup = jsonEncode({
        'app': 'murrmobile',
        'format_version': 1,
        'preferences': {
          'age_confirmed': 'yes',
          'app_theme': 123,
          'video_quality': '480p',
          'unknown_future_key': 7,
        },
      });
      await DataTransfer.importJson(backup);
      final prefs = await SharedPreferences.getInstance();
      // These would throw TypeError inside the getters if mis-typed values
      // had been stored, which is exactly what the guard prevents.
      expect(prefs.getBool('age_confirmed'), isNull);
      expect(prefs.getString('app_theme'), isNull);
      expect(prefs.getString('video_quality'), '480p');
      expect(prefs.getInt('unknown_future_key'), 7);
    });

    test('import parses a netscape-format cookie dump', () async {
      installTestEnv();
      final backup = jsonEncode({
        'app': 'murrmobile',
        'format_version': 1,
        'cookies':
            '# Netscape HTTP Cookie File\n'
            'murrtube.net\tTRUE\t/\tTRUE\t9999999999\tsession_id\tabc123\n',
      });
      await DataTransfer.importJson(backup);
      expect(MurrtubeApi.isAuthenticated, isTrue);
      expect(await CookieLoader.load(), 'session_id=abc123');
    });

    test('import rejects non-string cookies', () async {
      installTestEnv();
      expect(
        () => DataTransfer.importJson(
          jsonEncode({'app': 'murrmobile', 'cookies': 42}),
        ),
        throwsA(isA<FormatException>()),
      );
      // An unparseable multi-line dump also throws.
      expect(
        () => DataTransfer.importJson(
          jsonEncode({'app': 'murrmobile', 'cookies': 'junk\nlines'}),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('import with no cookies key leaves login untouched', () async {
      installTestEnv();
      MurrtubeApi.setCookies('session_id=keepme');
      await CookieLoader.save('session_id=keepme');
      final backup = jsonEncode({
        'app': 'murrmobile',
        'format_version': 1,
        'preferences': <String, dynamic>{},
      });
      await DataTransfer.importJson(backup);
      expect(MurrtubeApi.isAuthenticated, isTrue);
      expect(await CookieLoader.load(), 'session_id=keepme');
    });
  });

  group('SettingsPage backup', () {
    late TestEnv env;
    late FakeSharePlatform share;

    setUp(() async {
      env = installTestEnv();
      share = FakeSharePlatform();
      SharePlatform.instance = share;
      MurrtubeApi.clearCookies();
      await CookieLoader.clear();
    });

    testWidgets('shows export and import tiles', (tester) async {
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Backup'), findsOneWidget);
      expect(find.text('Export App Data'), findsOneWidget);
      expect(find.text('Import App Data'), findsOneWidget);
    });

    testWidgets('export shares the backup file', (tester) async {
      await AppPreferences.setTheme('amoled');
      await tester.runAsync(() => CookieLoader.save('session_id=abc'));

      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Export App Data'));
      await flushRealIo(tester);

      expect(share.sharedPaths, hasLength(1));
      final path = share.sharedPaths.single.single;
      final contents = await tester.runAsync(() => File(path).readAsString());
      final decoded = jsonDecode(contents!);
      expect(decoded['app'], 'murrmobile');
      expect(decoded['cookies'], 'session_id=abc');
    });

    testWidgets('export falls back to documents when share is unavailable', (
      tester,
    ) async {
      share.throwUnimplemented = true;
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Export App Data'));
      await flushRealIo(tester);

      expect(find.textContaining('Backup saved to'), findsOneWidget);
      final docs = (await getApplicationDocumentsDirectory()).path;
      final file = File('$docs/murrmobile_backup.json');
      expect(await tester.runAsync(() => file.exists()), isTrue);
    });

    testWidgets('export failure shows a snackbar', (tester) async {
      env.pathProvider.failTemporary = true;
      env.pathProvider.failDocuments = true;
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Export App Data'));
      await flushRealIo(tester);
      expect(find.text('Export failed'), findsOneWidget);
    });

    testWidgets('import dialog applies pasted backup', (tester) async {
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Import App Data'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid backup file'), findsNothing);

      final backup = jsonEncode({
        'app': 'murrmobile',
        'format_version': 1,
        'preferences': {'app_theme': 'light', 'video_quality': '480p'},
        'cookies': 'session_id=imported',
      });
      await tester.enterText(find.byType(TextField), backup);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      // The import chain does real file IO and a fake http round trip, so
      // give it a few real-async windows.
      await flushRealIo(tester);

      expect(await AppPreferences.getTheme(), 'light');
      expect(await AppPreferences.getVideoQuality(), '480p');
      expect(MurrtubeApi.isAuthenticated, isTrue);
      expect(find.text('Data imported'), findsOneWidget);
    });

    testWidgets('import dialog rejects bad input', (tester) async {
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Import App Data'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '{"app":"nope"}');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
      await settleAsync(tester);
      await tester.pump();

      expect(find.text('Invalid backup file'), findsOneWidget);
      expect(MurrtubeApi.isAuthenticated, isFalse);
    });
  });
}
