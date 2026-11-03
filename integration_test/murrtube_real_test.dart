import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:murrmobile/main.dart' as app;
import 'package:murrmobile/services/murrtube_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Load cookies from user's Zen Browser
    final cookieFile = File('/tmp/murrtube_netscape_cookies.txt');
    if (await cookieFile.exists()) {
      final lines = await cookieFile.readAsLines();
      final cookiePairs = <String>[];
      for (final line in lines) {
        if (line.startsWith('#') || line.trim().isEmpty) continue;
        final parts = line.split('\t');
        if (parts.length >= 7) {
          cookiePairs.add('${parts[5]}=${parts[6]}');
        }
      }
      MurrtubeApi.setCookies(cookiePairs.join('; '));
    }
  });

  group('Murrtube Real API Tests', () {
    testWidgets('Home trending loads real videos', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Murrtube'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      // Should find video cards with actual data
      expect(find.byType(Card), findsAtLeastNWidgets(1));
    });

    testWidgets('Video detail loads real video', (tester) async {
      final result = await MurrtubeApi.getVideo('A1JY');
      expect(result.medium.shortCode, 'A1JY');
      expect(result.medium.title.isNotEmpty, true);
      expect(result.comments, isA<List>());
    });

    testWidgets('Search returns real results', (tester) async {
      final result = await MurrtubeApi.search(query: 'test', page: 1);
      expect(result.media, isA<List>());
    });

    testWidgets('Notifications load', (tester) async {
      final result = await MurrtubeApi.getNotifications();
      expect(result.items, isA<List>());
    });

    testWidgets('Settings load', (tester) async {
      final props = await MurrtubeApi.getSettings();
      expect(props['user'], isNotNull);
    });

    testWidgets('Upload page loads', (tester) async {
      final props = await MurrtubeApi.getUpload();
      expect(props['visibilities'], isA<List>());
    });

  });
}
