import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/pages/search_page.dart';
import 'package:murrmobile/pages/settings_page.dart';
import 'package:murrmobile/pages/upload_page.dart';
import 'package:murrmobile/pages/playlist_page.dart';
import 'package:murrmobile/pages/login_page.dart';
import 'package:murrmobile/services/murrtube_api.dart';
import 'package:murrmobile/utils/app_preferences.dart';

import 'support/fake_http.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;

  setUp(() {
    env = installTestEnv();
    SharedPreferences.setMockInitialValues({});
    MurrtubeApi.clearCookies();
    MurrtubeApi.currentUserSlug = null;
  });

  tearDown(() {
    MurrtubeApi.clearCookies();
    MurrtubeApi.currentUserSlug = null;
  });

  FakeResponse searchPage({
    List<Map<String, dynamic>>? media,
    List<Map<String, dynamic>>? users,
    List<Map<String, dynamic>>? tagMatches,
    Map<String, dynamic>? pagination,
  }) => FakeResponse.inertia('Search', {
    'query': 'q',
    'media': media ?? [mediaJson()],
    'users': users ?? const [],
    'tag_matches': tagMatches ?? const [],
    'pagination': pagination ?? paginationJson(),
  });

  group('SearchPage', () {
    testWidgets('shows prompt before searching', (tester) async {
      await pumpApp(tester, const SearchPage());
      await tester.pump();
      expect(find.text('Type to search'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('searches and shows media results', (tester) async {
      env.server.onGet('/search', (req) => searchPage());
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsOneWidget);
      expect(find.text('Videos (1)'), findsOneWidget);
    });

    testWidgets('search via submit action', (tester) async {
      env.server.onGet('/search', (req) => searchPage());
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsOneWidget);
    });

    testWidgets('shows users and tag matches sections', (tester) async {
      env.server.onGet(
        '/search',
        (req) => searchPage(
          users: [userJson(name: 'Found User', slug: 'founder')],
          tagMatches: [tagJson(name: 'cat', count: 4)],
        ),
      );
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Users (1)'), findsOneWidget);
      expect(find.text('Tags (1)'), findsOneWidget);
      expect(find.text('Found User'), findsOneWidget);
      expect(find.text('@founder'), findsOneWidget);
    });

    testWidgets('empty results shows message', (tester) async {
      env.server.onGet('/search', (req) => searchPage(media: const []));
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets('search error leaves previous state', (tester) async {
      env.server.onGet('/search', (req) => const FakeResponse(500, 'err'));
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'err');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets('initialQuery triggers search on mount', (tester) async {
      env.server.onGet('/search', (req) => searchPage());
      await pumpApp(tester, const SearchPage(initialQuery: 'auto'));
      await settleAsync(tester);
      await tester.pump();
      expect(env.server.requestsTo('/search'), isNotEmpty);
    });

    testWidgets('clear button resets results', (tester) async {
      env.server.onGet('/search', (req) => searchPage());
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(find.text('Type to search'), findsOneWidget);
    });

    testWidgets('suggestions appear while typing', (tester) async {
      env.server.onGet(
        '/search/suggest',
        (req) => FakeResponse.json({
          'query': 'ca',
          'users': [
            {'slug': 'u1', 'name': 'Sugg User', 'avatar_url': null},
          ],
          'tags': [
            {'name': 'cat', 'category': 'general', 'count': 3},
          ],
        }),
      );
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'ca');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Sugg User'), findsOneWidget);
      expect(find.text('cat'), findsOneWidget);
    });

    testWidgets('tapping a suggestion tag searches it', (tester) async {
      env.server.onGet(
        '/search/suggest',
        (req) => FakeResponse.json({
          'query': 'ca',
          'users': [],
          'tags': [
            {'name': 'cat', 'category': 'general', 'count': 3},
          ],
        }),
      );
      env.server.onGet('/search', (req) => searchPage());
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'ca');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('cat'));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsOneWidget);
    });

    testWidgets('short query clears suggestions without a request', (
      tester,
    ) async {
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'c');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester);
      expect(env.server.requestsTo('/search/suggest'), isEmpty);
    });

    testWidgets('suggest failure hides loading', (tester) async {
      env.server.onGet(
        '/search/suggest',
        (req) => const FakeResponse(500, 'err'),
      );
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'ca');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Type to search'), findsOneWidget);
    });

    testWidgets('tapping a user pushes profile page', (tester) async {
      env.server.onGet(
        '/search',
        (req) => searchPage(
          media: const [],
          users: [userJson(name: 'Found User', slug: 'founder')],
        ),
      );
      env.server.onGet(
        '/founder',
        (req) => FakeResponse.inertia('Profile', profileProps()),
      );
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Found User'));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(env.server.requestsTo('/founder'), isNotEmpty);
    });

    testWidgets('tapping a result tag chip searches it', (tester) async {
      env.server.onGet(
        '/search',
        (req) => searchPage(
          media: const [],
          tagMatches: [tagJson(name: 'cat', count: 4)],
        ),
      );
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('cat'));
      await tester.pump();
      await settleAsync(tester);
      // Search ran again with tag name.
      expect(env.server.requestsTo('/search').length, greaterThanOrEqualTo(2));
    });
  });

  group('SettingsPage', () {
    testWidgets('guest shows log in tile and sections', (tester) async {
      await pumpApp(tester, const SettingsPage());
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Small Screen Navigation'), findsOneWidget);
      expect(find.text('Video Quality'), findsOneWidget);
      expect(find.text('Preferred Quality'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Cookie Policy'), findsOneWidget);
      expect(find.text('Reset Age Confirmation'), findsOneWidget);
    });

    testWidgets('authed shows user card and log out', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {
          'user': userJson(name: 'Me', slug: 'me'),
          'current_user': userJson(slug: 'me'),
        }),
      );
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Me'), findsOneWidget);
      expect(find.text('@me'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      expect(MurrtubeApi.currentUserSlug, 'me');
    });

    testWidgets('settings api error renders logged-out view', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet('/settings', (req) => const FakeResponse(500, 'err'));
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('theme sheet opens and selects light', (tester) async {
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.text('Select Theme'), findsOneWidget);
      expect(find.text('Only dark mode available'), findsOneWidget);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(await AppPreferences.getTheme(), 'light');
    });

    testWidgets('navigation mode sheet selects bottom bar', (tester) async {
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Small Screen Navigation'));
      await tester.pumpAndSettle();
      expect(find.text('Select Small Screen Navigation'), findsOneWidget);
      await tester.tap(find.text('Bottom Bar'));
      await tester.pumpAndSettle();
      expect(await AppPreferences.getNavigationMode(), 'bottom_bar');
    });

    testWidgets('quality sheet selects 720p', (tester) async {
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Preferred Quality'));
      await tester.pumpAndSettle();
      expect(find.text('Select Video Quality'), findsOneWidget);
      await tester.tap(find.text('720p'));
      await tester.pumpAndSettle();
      expect(await AppPreferences.getVideoQuality(), '720p');
    });

    testWidgets('server-provided quality options are used', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {
          'user': userJson(),
          'video_quality_options': ['low', 'high'],
        }),
      );
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Preferred Quality'));
      await tester.pumpAndSettle();
      expect(find.text('low'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
      await tester.tap(find.text('high'));
      await tester.pumpAndSettle();
      expect(await AppPreferences.getVideoQuality(), 'high');
    });

    testWidgets('legal links launch urls', (tester) async {
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Terms of Service'));
      await settleAsync(tester);
      expect(
        env.urlLauncher.launchedUrls,
        contains('https://murrtube.net/about/terms'),
      );
      await tester.tap(find.text('Privacy Policy'));
      await settleAsync(tester);
      expect(
        env.urlLauncher.launchedUrls,
        contains('https://murrtube.net/about/privacy'),
      );
      await tester.tap(find.text('Cookie Policy'));
      await settleAsync(tester);
      expect(
        env.urlLauncher.launchedUrls,
        contains('https://murrtube.net/about/cookies'),
      );
    });

    testWidgets('reset age confirmation clears pref and shows snackbar', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Reset Age Confirmation'));
      await settleAsync(tester);
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('age_confirmed'), isNull);
      expect(find.textContaining('Age confirmation reset'), findsOneWidget);
    });

    testWidgets('log out clears cookies and reloads', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {'user': userJson()}),
      );
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Log Out'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      expect(MurrtubeApi.hasCookies, isFalse);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('log in tile pushes login page and reloads on true', (
      tester,
    ) async {
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.text('Log in to Murrtube'), findsOneWidget);
      // Pop with true -> reload.
      Navigator.of(tester.element(find.text('Log in to Murrtube'))).pop(true);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('tapping user row pushes profile', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet(
        '/settings',
        (req) =>
            FakeResponse.inertia('Settings', {'user': userJson(slug: 'me')}),
      );
      env.server.onGet(
        '/me',
        (req) => FakeResponse.inertia('Profile', profileProps()),
      );
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('@me'));
      await tester.pump();
      await settleAsync(tester);
      expect(env.server.requestsTo('/me'), isNotEmpty);
    });
  });

  group('UploadPage', () {
    testWidgets('renders fields and default visibility', (tester) async {
      env.server.onGet(
        '/upload',
        (req) => FakeResponse.inertia('Upload', {
          'visibilities': ['public', 'private'],
          'popular_tags': ['cat', 'dog'],
          'max_title_length': 80,
        }),
      );
      await pumpApp(tester, const UploadPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Visibility'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Popular Tags'), findsOneWidget);
      expect(find.text('cat'), findsOneWidget);
      expect(find.text('Select Video File'), findsOneWidget);
    });

    testWidgets('selecting visibility updates selection', (tester) async {
      env.server.onGet(
        '/upload',
        (req) => FakeResponse.inertia('Upload', {
          'visibilities': ['public', 'private'],
        }),
      );
      await pumpApp(tester, const UploadPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Private'));
      await tester.pump();
      // Private now selected - radio dot present under it.
      expect(find.text('Private'), findsOneWidget);
    });

    testWidgets('map-shaped visibilities and tags render', (tester) async {
      env.server.onGet(
        '/upload',
        (req) => FakeResponse.inertia('Upload', {
          'visibilities': [
            {'value': 'unlisted', 'label': 'Unlisted'},
            42,
          ],
          'popular_tags': [
            {'name': 'maptag'},
            7,
          ],
        }),
      );
      await pumpApp(tester, const UploadPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Unlisted'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('maptag'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('error renders page without sections', (tester) async {
      env.server.onGet('/upload', (req) => const FakeResponse(500, 'err'));
      await pumpApp(tester, const UploadPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Visibility'), findsNothing);
    });

    testWidgets('tapping select file does not crash', (tester) async {
      env.server.onGet('/upload', (req) => FakeResponse.inertia('Upload', {}));
      await pumpApp(tester, const UploadPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Select Video File'));
      await tester.pump();
    });
  });

  group('PlaylistPage', () {
    testWidgets('loads playlist with items and user', (tester) async {
      env.server.onGet(
        '/u1/p/my-playlist',
        (req) => FakeResponse.inertia('Playlist', {
          'playlist': playlistJson(description: 'A desc'),
          'items': [mediaJson()],
          'pagination': paginationJson(),
          'user': userJson(name: 'Owner'),
          'is_owner': true,
        }),
      );
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'my-playlist'),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('My Playlist'), findsOneWidget);
      expect(find.text('public · 3 items'), findsOneWidget);
      expect(find.text('A desc'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Test Video'), findsOneWidget);
    });

    testWidgets('empty playlist shows empty state', (tester) async {
      env.server.onGet(
        '/u1/p/empty',
        (req) => FakeResponse.inertia('Playlist', {
          'playlist': playlistJson(slug: 'empty'),
          'items': const [],
          'pagination': paginationJson(),
        }),
      );
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'empty'),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('No videos in this playlist'), findsOneWidget);
      expect(find.text('0 items'), findsNothing);
    });

    testWidgets('load error shows not found', (tester) async {
      env.server.onGet('/u1/p/x', (req) => const FakeResponse(404, 'no'));
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'x'),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Playlist not found'), findsOneWidget);
    });

    testWidgets('back button pops', (tester) async {
      env.server.onGet(
        '/u1/p/pl',
        (req) => FakeResponse.inertia('Playlist', {
          'playlist': playlistJson(),
          'items': const [],
          'pagination': paginationJson(),
        }),
      );
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const PlaylistPage(userSlug: 'u1', playlistSlug: 'pl'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await settleAsync(tester);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistPage), findsNothing);
    });

    testWidgets('loads more when scrolling to end', (tester) async {
      final items = List.generate(
        10,
        (i) => mediaJson(id: 'm$i', shortCode: 'P$i', title: 'P$i'),
      );
      env.server.onGet(
        '/u1/p/pl',
        (req) => FakeResponse.inertia('Playlist', {
          'playlist': playlistJson(),
          'items': items,
          'pagination': paginationJson(pages: 3, next: '/u1/p/pl?page=2'),
        }),
        matchQuery: (uri) => uri.queryParameters['page'] == null,
      );
      env.server.onGet(
        '/u1/p/pl',
        (req) => FakeResponse.inertia('Playlist', {
          'playlist': playlistJson(),
          'items': [mediaJson(id: 'm11', shortCode: 'P11', title: 'P11')],
          'pagination': paginationJson(page: 2, pages: 3),
        }),
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'pl'),
        size: const Size(500, 900),
      );
      await settleAsync(tester);
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(
        env.server.requests.where((r) => r.uri.queryParameters['page'] == '2'),
        isNotEmpty,
      );
    });

    testWidgets('tapping owner row pushes profile', (tester) async {
      env.server.onGet(
        '/u1/p/pl',
        (req) => FakeResponse.inertia('Playlist', {
          'playlist': playlistJson(),
          'items': const [],
          'pagination': paginationJson(),
          'user': userJson(slug: 'owner1', name: 'Owner'),
        }),
      );
      env.server.onGet(
        '/owner1',
        (req) => FakeResponse.inertia('Profile', profileProps()),
      );
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'pl'),
      );
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Owner'));
      await tester.pump();
      await settleAsync(tester);
      expect(env.server.requestsTo('/owner1'), isNotEmpty);
    });
  });

  group('LoginPage', () {
    testWidgets('renders fields and buttons', (tester) async {
      await pumpApp(tester, const LoginPage(), size: const Size(600, 1600));
      await tester.pump();
      expect(find.text('Log in to Murrtube'), findsOneWidget);
      expect(find.text('Open murrtube.net/sign_in'), findsOneWidget);
      expect(find.text('_murrtube_v3_session'), findsOneWidget);
      expect(find.text('age_check'), findsOneWidget);
      expect(find.text('XSRF-TOKEN'), findsOneWidget);
      expect(find.text('session_id'), findsOneWidget);
      expect(find.text('Save & Connect'), findsOneWidget);
      expect(find.text('REQUIRED'), findsNWidgets(2));
    });

    testWidgets('open browser launches sign-in url', (tester) async {
      await pumpApp(tester, const LoginPage(), size: const Size(600, 1600));
      await tester.tap(find.text('Open murrtube.net/sign_in'));
      await settleAsync(tester);
      expect(
        env.urlLauncher.launchedUrls,
        contains('https://murrtube.net/sign_in'),
      );
    });

    testWidgets('save with empty session shows snackbar', (tester) async {
      await pumpApp(tester, const LoginPage(), size: const Size(600, 1600));
      await tester.tap(find.text('Save & Connect'));
      await tester.pump();
      expect(find.text('Session cookie is required'), findsOneWidget);
    });

    testWidgets('save builds cookie string and pops true', (tester) async {
      bool? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('open'),
          ),
        ),
        size: const Size(600, 1600),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'sess%20val');
      await tester.enterText(fields.at(1), 'age1');
      await tester.enterText(fields.at(2), 'xsrf1');
      await tester.enterText(fields.at(3), 'sid1');
      await tester.runAsync(() async {
        await tester.tap(find.text('Save & Connect'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(result, isTrue);
      expect(MurrtubeApi.isAuthenticated, isTrue);
    });

    testWidgets('save with only session works', (tester) async {
      bool? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('open'),
          ),
        ),
        size: const Size(600, 1600),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'only%session');
      await tester.runAsync(() async {
        await tester.tap(find.text('Save & Connect'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(result, isTrue);
      expect(MurrtubeApi.hasCookies, isTrue);
    });

    testWidgets('clear button on a field empties it', (tester) async {
      await pumpApp(tester, const LoginPage(), size: const Size(600, 1600));
      final field = find.byType(TextField).first;
      await tester.enterText(field, 'abc');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear).first);
      await tester.pump();
      final tf = tester.widget<TextField>(field);
      expect(tf.controller!.text, isEmpty);
    });
  });
}
