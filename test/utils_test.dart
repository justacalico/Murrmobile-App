import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/utils/app_preferences.dart';
import 'package:murrmobile/utils/cookie_loader.dart';
import 'package:murrmobile/utils/page_transitions.dart';
import 'package:path_provider/path_provider.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPreferences', () {
    test('returns defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AppPreferences.getTheme(), 'auto');
      expect(await AppPreferences.getVideoQuality(), 'auto');
      expect(await AppPreferences.getMute(), isFalse);
    });

    test('persists and reads back all values', () async {
      SharedPreferences.setMockInitialValues({});
      await AppPreferences.setTheme('amoled');
      await AppPreferences.setVideoQuality('720p');
      await AppPreferences.setMute(true);
      expect(await AppPreferences.getTheme(), 'amoled');
      expect(await AppPreferences.getVideoQuality(), '720p');
      expect(await AppPreferences.getMute(), isTrue);
    });
  });

  group('CookieLoader', () {
    test('parse extracts name=value from netscape format', () {
      const content =
          '# Netscape HTTP Cookie File\n'
          'murrtube.net\tTRUE\t/\tTRUE\t9999999999\tsession_id\tabc123\n'
          'murrtube.net\tTRUE\t/\tFALSE\t9999999999\tother\txyz\n'
          '\n'
          'bad line with no tabs\n';
      expect(CookieLoader.parse(content), 'session_id=abc123; other=xyz');
    });

    test('parse returns null for empty or comment-only input', () {
      expect(CookieLoader.parse(''), isNull);
      expect(CookieLoader.parse('# just a comment\n'), isNull);
    });

    test('save, load, and clear round-trip through documents dir', () async {
      final env = installTestEnv();
      final docs = (await getApplicationDocumentsDirectory()).path;
      expect(docs, contains(env.pathProvider.root.path));

      await CookieLoader.save('session_id=abc');
      final file = File('$docs/murrtube_cookies.txt');
      expect(await file.exists(), isTrue);

      // Cached value returned without touching disk.
      expect(await CookieLoader.load(), 'session_id=abc');

      await CookieLoader.clear();
      expect(await file.exists(), isFalse);
      expect(await CookieLoader.load(), isNull);
    });

    test('load parses netscape content from disk', () async {
      installTestEnv();
      final docs = (await getApplicationDocumentsDirectory()).path;
      // Reset static cache by clearing through the public API.
      await CookieLoader.clear();
      File('$docs/murrtube_cookies.txt').writeAsStringSync(
        'murrtube.net\tTRUE\t/\tTRUE\t9999999999\tsession_id\tfromdisk\n',
      );
      expect(await CookieLoader.load(), 'session_id=fromdisk');
    });

    test('load returns raw content when not netscape format', () async {
      installTestEnv();
      await CookieLoader.clear();
      final docs = (await getApplicationDocumentsDirectory()).path;
      File(
        '$docs/murrtube_cookies.txt',
      ).writeAsStringSync('rawcookie=abc; session_id=zzz');
      expect(await CookieLoader.load(), 'rawcookie=abc; session_id=zzz');
    });

    test('set stores the cached value', () async {
      installTestEnv();
      await CookieLoader.clear();
      CookieLoader.set('session_id=setdirectly');
      expect(await CookieLoader.load(), 'session_id=setdirectly');
      await CookieLoader.clear();
    });

    test('load returns null when documents dir is unavailable', () async {
      final env = installTestEnv();
      await CookieLoader.clear();
      env.pathProvider.failDocuments = true;
      expect(await CookieLoader.load(), isNull);
    });
  });

  group('AppPageRoute', () {
    testWidgets('navigates with fade/slide transition on non-Apple platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => pushPage(
                context,
                builder: (_) => const Scaffold(body: Text('pushed')),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      // Mid-transition the route is animating.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('pushed'), findsOneWidget);
    });

    testWidgets('pushReplacementPage replaces the current route', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => pushReplacementPage(
                context,
                builder: (_) => const Scaffold(body: Text('replaced')),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('replaced'), findsOneWidget);
      expect(find.text('go'), findsNothing);
    });

    testWidgets('pushAndRemoveUntilPage clears the stack', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => pushAndRemoveUntilPage(
                context,
                builder: (_) => const Scaffold(body: Text('root')),
                predicate: (route) => false,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      // Back navigation should not pop to the old page.
      expect(Navigator.of(tester.element(find.text('root'))).canPop(), isFalse);
    });

    testWidgets('fullscreenDialog flag is applied', (tester) async {
      late Route<dynamic> captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                captured = AppPageRoute<void>(
                  builder: (_) => const SizedBox(),
                  fullscreenDialog: true,
                );
                Navigator.of(context).push(captured);
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect((captured as PageRoute).fullscreenDialog, isTrue);
    });
  });
}
