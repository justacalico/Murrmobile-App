import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:murrmobile/services/murrtube_api.dart';

// Live tests against murrtube.net. Skipped by default; run with:
//   flutter test test/api_real_test.dart --dart-define=LIVE_API=true
const _runLive = bool.fromEnvironment('LIVE_API');

void main() {
  setUpAll(() {
    final cookieFile = File('/tmp/murrtube_netscape_cookies.txt');
    if (cookieFile.existsSync()) {
      final lines = cookieFile.readAsLinesSync();
      final pairs = <String>[];
      for (final line in lines) {
        if (line.startsWith('#') || line.trim().isEmpty) continue;
        final parts = line.split('\t');
        if (parts.length >= 7) {
          pairs.add('${parts[5]}=${parts[6]}');
        }
      }
      MurrtubeApi.setCookies(pairs.join('; '));
    }
  });

  group('Real Murrtube API Tests', () {
    test('getHome trending returns videos', () async {
      final result = await MurrtubeApi.getHome(tab: 'trending');
      expect(result.media, isNotEmpty);
      expect(result.media.first.title, isNotEmpty);
      expect(result.pagination.pages, greaterThan(0));
    });

    test('getVideo returns video details', () async {
      final result = await MurrtubeApi.getVideo('A1JY');
      expect(result.medium.shortCode, 'A1JY');
      expect(result.medium.title, isNotEmpty);
      expect(result.comments, isA<List>());
      expect(result.watchMore, isA<List>());
    });

    test('search returns results', () async {
      final result = await MurrtubeApi.search(query: 'test');
      expect(result.media, isA<List>());
    });

    test('getNotifications returns list', () async {
      final result = await MurrtubeApi.getNotifications();
      expect(result.items, isA<List>());
    });

    test('getSettings returns user data', () async {
      final props = await MurrtubeApi.getSettings();
      expect(props['user'], isNotNull);
    });

    test('getUpload returns visibilities', () async {
      final props = await MurrtubeApi.getUpload();
      expect(props['visibilities'], isA<List>());
    });

    test('getTerms returns effective_date', () async {
      final props = await MurrtubeApi.getTerms();
      expect(props['effective_date'], isNotNull);
    });

    test('getPrivacy returns effective_date', () async {
      final props = await MurrtubeApi.getPrivacy();
      expect(props['effective_date'], isNotNull);
    });

    test('getCookies returns effective_date', () async {
      final props = await MurrtubeApi.getCookies();
      expect(props['effective_date'], isNotNull);
    });
  }, skip: !_runLive);
}
