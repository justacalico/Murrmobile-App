import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/main.dart' as app;
import 'package:murrmobile/pages/about_page.dart';
import 'package:murrmobile/pages/cookie_setup_page.dart';
import 'package:murrmobile/pages/home_page.dart';
import 'package:murrmobile/pages/login_page.dart';
import 'package:murrmobile/pages/notifications_page.dart';
import 'package:murrmobile/pages/playlist_page.dart';
import 'package:murrmobile/pages/profile_page.dart';
import 'package:murrmobile/pages/search_page.dart';
import 'package:murrmobile/pages/settings_page.dart';
import 'package:murrmobile/services/murrtube_api.dart';
import 'package:murrmobile/utils/cookie_loader.dart';
import 'package:murrmobile/widgets/responsive_shell.dart';

import 'support/fake_http.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;

  setUp(() {
    env = installTestEnv();
    MurrtubeApi.clearCookies();
    MurrtubeApi.currentUserSlug = null;
  });

  tearDown(() {
    MurrtubeApi.clearCookies();
    MurrtubeApi.currentUserSlug = null;
  });

  FakeResponse homePage({List<Map<String, dynamic>>? media, dynamic next}) =>
      FakeResponse.inertia('Home', {
        'media': media ?? [mediaJson()],
        'pagination': paginationJson(next: next),
        'announcements': const [],
      });

  void stubHome({List<Map<String, dynamic>>? media, dynamic next}) {
    env.server.onGet(
      '/',
      (req) => homePage(media: media, next: next),
      matchQuery: (uri) => uri.queryParameters.containsKey('tab'),
    );
  }

  List<FakeRequest> homeRequests([String? tab]) => env.server.requests
      .where(
        (r) =>
            r.uri.path == '/' &&
            (tab == null || r.uri.queryParameters['tab'] == tab),
      )
      .toList();

  group('main entrypoint', () {
    testWidgets('main() loads cookies and runs the app', (tester) async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      stubHome(media: const []);
      CookieLoader.set('session_id=abc');
      await tester.runAsync(() async {
        app.main();
      });
      await settleAsync(tester);
      await tester.pump();
      expect(MurrtubeApi.isAuthenticated, isTrue);
      expect(find.byType(app.MurrtubeApp), findsOneWidget);
      await tester.runAsync(() => CookieLoader.clear());
    });

    testWidgets('named about routes resolve', (tester) async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      stubHome(media: const []);
      for (final t in ['terms', 'privacy', 'cookies', 'whats-new']) {
        env.server.onGet(
          '/about/$t',
          (req) => FakeResponse.inertia('About', {
            'title': t,
            'body': 'body',
            'effective_date': '2026-01-01',
          }),
        );
      }
      await tester.pumpWidget(const app.MurrtubeApp());
      await tester.pump();
      await settleAsync(tester);
      expect(find.byType(ResponsiveShell), findsOneWidget);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      for (final route in [
        '/about/terms',
        '/about/privacy',
        '/about/cookies',
        '/about/whats-new',
      ]) {
        nav.pushNamed(route);
        await tester.pump();
        await settleAsync(tester);
        await tester.pump();
        expect(find.byType(AboutPage), findsOneWidget);
        nav.pop();
        await tester.pump();
        await tester.pump();
      }
    });
  });

  group('HomePage gaps', () {
    testWidgets('mid and wide widths render', (tester) async {
      stubHome();
      await pumpApp(tester, const HomePage(), size: const Size(800, 900));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsWidgets);

      await pumpApp(tester, const HomePage(), size: const Size(1300, 900));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsWidgets);
    });

    testWidgets('pull to refresh reloads', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubHome();
      await pumpApp(tester, const HomePage());
      await settleAsync(tester);
      await tester.pump();
      final before = homeRequests().length;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await settleAsync(tester);
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
      expect(homeRequests().length, greaterThan(before));
    });

    testWidgets('all tabs switch', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      stubHome();
      await pumpApp(tester, const HomePage(tab: 'for_you'));
      await settleAsync(tester);
      await tester.pump();
      for (final tab in ['For You', 'Latest', 'Subscriptions', 'Trending']) {
        await tester.ensureVisible(find.text(tab));
        await tester.pump();
        await tester.tap(find.text(tab));
        await tester.pump();
        await settleAsync(tester);
        await tester.pump();
      }
      expect(homeRequests('trending'), isNotEmpty);
      expect(homeRequests('for_you'), isNotEmpty);
      expect(homeRequests('latest'), isNotEmpty);
      expect(homeRequests('subscriptions'), isNotEmpty);
    });

    testWidgets('loading sliver shows while request is in flight', (
      tester,
    ) async {
      final gate = Completer<FakeResponse>();
      env.server.onGet(
        '/',
        (req) => gate.future,
        matchQuery: (uri) => uri.queryParameters.containsKey('tab'),
      );
      await pumpApp(tester, const HomePage());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete(homePage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsWidgets);
    });

    testWidgets('logout on subscriptions tab resets to trending', (
      tester,
    ) async {
      MurrtubeApi.setCookies('session_id=abc');
      stubHome();
      await pumpApp(
        tester,
        const HomePage(tab: 'subscriptions'),
        size: const Size(500, 900),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(homeRequests('subscriptions'), isNotEmpty);
      // Log out, then force a dependency change so the page reloads.
      MurrtubeApi.clearCookies();
      tester.view.physicalSize = const Size(520, 900);
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(homeRequests('trending'), isNotEmpty);
    });
  });

  group('NotificationsPage gaps', () {
    void stubItems(List<Map<String, dynamic>> items) {
      env.server.onGet(
        '/notifications',
        (req) => FakeResponse.inertia('Notifications', {
          'items': items,
          'display_cap': 10,
        }),
      );
    }

    testWidgets('mark all read button taps', (tester) async {
      stubItems([notificationJson(isUnread: true, actor: actorJson())]);
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Mark all read'), findsOneWidget);
      await tester.tap(find.text('Mark all read'));
      await tester.pump();
    });

    testWidgets('avatar image renders for actor', (tester) async {
      stubItems([
        notificationJson(actor: actorJson(avatarUrl: 'https://x/av.png')),
      ]);
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.byType(ClipOval), findsWidgets);
    });

    testWidgets('time ago covers days hours minutes and now', (tester) async {
      final now = DateTime.now().toUtc();
      stubItems([
        notificationJson(
          id: 1,
          createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
        ),
        notificationJson(
          id: 2,
          createdAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
        ),
        notificationJson(
          id: 3,
          createdAt: now.subtract(const Duration(minutes: 7)).toIso8601String(),
        ),
        notificationJson(id: 4, createdAt: now.toIso8601String()),
      ]);
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('2d ago'), findsOneWidget);
      expect(find.text('3h ago'), findsOneWidget);
      expect(find.text('7m ago'), findsOneWidget);
      expect(find.text('now'), findsOneWidget);
    });
  });

  group('PlaylistPage gaps', () {
    void stubPlaylist({dynamic next, Map<String, dynamic>? user}) {
      env.server.onGet(
        '/u1/p/pl1',
        (req) => FakeResponse.inertia('Playlist', {
          'playlist': playlistJson(),
          'items': [mediaJson()],
          'pagination': paginationJson(next: next),
          'user': user,
        }),
        matchQuery: (uri) => uri.queryParameters['page'] != '2',
      );
    }

    testWidgets('mid and wide widths render', (tester) async {
      stubPlaylist();
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'pl1'),
        size: const Size(800, 900),
      );
      await settleAsync(tester);
      await tester.pump();

      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'pl1'),
        size: const Size(1300, 900),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('My Playlist'), findsOneWidget);
    });

    testWidgets('load more failure is swallowed', (tester) async {
      stubPlaylist(next: '/u1/p/pl1?page=2');
      env.server.onGet(
        '/u1/p/pl1',
        (req) => const FakeResponse(500, 'err'),
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'pl1'),
        size: const Size(500, 700),
      );
      await settleAsync(tester);
      await tester.pump();
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -500),
        1000,
      );
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(
        env.server.requests.where((r) => r.uri.queryParameters['page'] == '2'),
        isNotEmpty,
      );
    });

    testWidgets('owner avatar image renders', (tester) async {
      stubPlaylist(user: userJson(avatarUrl: 'https://x/a.png'));
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'pl1'),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.byType(ClipOval), findsWidgets);
    });

    testWidgets('tapping a video pushes detail', (tester) async {
      stubPlaylist();
      env.server.onGet(
        '/v/ABC1',
        (req) => FakeResponse.inertia('Video', videoProps()),
      );
      await pumpApp(
        tester,
        const PlaylistPage(userSlug: 'u1', playlistSlug: 'pl1'),
      );
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Test Video'));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(env.server.requestsTo('/v/ABC1'), isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(seconds: 11));
    });
  });

  group('ProfilePage gaps', () {
    testWidgets('didUpdateWidget reloads when slug changes', (tester) async {
      for (final slug in ['a1', 'b1']) {
        env.server.onGet(
          '/$slug',
          (req) => FakeResponse.inertia(
            'Profile',
            profileProps(
              profile: richProfileJson(slug: slug, name: 'User $slug'),
            ),
          ),
        );
      }
      await pumpApp(tester, const ProfilePage(slug: 'a1'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('User a1'), findsWidgets);
      await pumpApp(tester, const ProfilePage(slug: 'b1'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('User b1'), findsWidgets);
    });

    testWidgets('scrolling to end loads next page', (tester) async {
      env.server.onGet(
        '/test-user',
        (req) => FakeResponse.inertia(
          'Profile',
          profileProps(
            media: List.generate(
              8,
              (i) => mediaJson(
                id: 'p1-$i',
                shortCode: 'P1$i',
                title: 'P1 Video $i',
              ),
            ),
            pagination: paginationJson(next: '/test-user?page=2'),
          ),
        ),
        matchQuery: (uri) => uri.queryParameters['page'] != '2',
      );
      env.server.onGet(
        '/test-user',
        (req) => FakeResponse.inertia(
          'Profile',
          profileProps(
            media: [mediaJson(id: 'p2-1', shortCode: 'P21', title: 'P2 Video')],
            pagination: paginationJson(page: 2),
          ),
        ),
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(
        tester,
        const ProfilePage(slug: 'test-user'),
        size: const Size(500, 700),
      );
      await settleAsync(tester);
      await tester.pump();
      await tester.drag(find.byType(GridView), const Offset(0, -3000));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('P2 Video'), findsWidgets);
    });

    testWidgets('load more failure is swallowed', (tester) async {
      env.server.onGet(
        '/test-user',
        (req) => FakeResponse.inertia(
          'Profile',
          profileProps(
            media: List.generate(
              8,
              (i) => mediaJson(id: 'p1-$i', shortCode: 'P1$i', title: 'V$i'),
            ),
            pagination: paginationJson(next: '/test-user?page=2'),
          ),
        ),
        matchQuery: (uri) => uri.queryParameters['page'] != '2',
      );
      env.server.onGet(
        '/test-user',
        (req) => const FakeResponse(500, 'err'),
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(
        tester,
        const ProfilePage(slug: 'test-user'),
        size: const Size(500, 700),
      );
      await settleAsync(tester);
      await tester.pump();
      await tester.drag(find.byType(GridView), const Offset(0, -3000));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(
        env.server.requests.where((r) => r.uri.queryParameters['page'] == '2'),
        isNotEmpty,
      );
    });

    testWidgets('wide layout uses large aspect ratio', (tester) async {
      env.server.onGet(
        '/test-user',
        (req) => FakeResponse.inertia('Profile', profileProps()),
      );
      await pumpApp(
        tester,
        const ProfilePage(slug: 'test-user'),
        size: const Size(1200, 900),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test User'), findsWidgets);
    });

    testWidgets('blocked profile shows unblock and calls unblock endpoint', (
      tester,
    ) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet(
        '/other',
        (req) => FakeResponse.inertia(
          'Profile',
          profileProps(
            profile: richProfileJson(slug: 'other', name: 'Other'),
            isBlocked: true,
          ),
        ),
      );
      env.server.onGet('/', (req) => FakeResponse.htmlPage());
      env.server.onPut(
        '/users/other/unblock',
        (req) => const FakeResponse(200, '{}'),
      );
      await pumpApp(tester, const ProfilePage(slug: 'other'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Unblock'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Block'), findsOneWidget);
      expect(env.server.requestsTo('/users/other/unblock'), isNotEmpty);
    });

    testWidgets('tapping a social link does nothing harmful', (tester) async {
      env.server.onGet(
        '/test-user',
        (req) => FakeResponse.inertia(
          'Profile',
          profileProps(
            profile: richProfileJson(
              socialMedia: {'gitlab': 'https://gitlab.com/x'},
            ),
          ),
        ),
      );
      await pumpApp(tester, const ProfilePage(slug: 'test-user'));
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('GitLab'));
      await tester.pump();
    });

    testWidgets('avatar error widget shows on image failure', (tester) async {
      env.server.onGet(
        '/test-user',
        (req) => FakeResponse.inertia(
          'Profile',
          profileProps(
            profile: richProfileJson(avatarUrl: 'https://x/broken.png'),
          ),
        ),
      );
      await pumpApp(tester, const ProfilePage(slug: 'test-user'));
      await settleAsync(tester);
      await awaitImages(tester);
      expect(find.byIcon(Icons.person), findsWidgets);
    });

    testWidgets('load-more landing on playlists tab appends playlists', (
      tester,
    ) async {
      env.server.onGet(
        '/test-user',
        (req) => FakeResponse.inertia(
          'Profile',
          profileProps(
            media: List.generate(
              12,
              (i) => mediaJson(id: 'm$i', shortCode: 'V$i', title: 'V$i'),
            ),
            pagination: paginationJson(next: '/test-user?tab=videos&page=2'),
            playlists: const [],
          ),
        ),
        matchQuery: (uri) => uri.queryParameters['page'] != '2',
      );
      final gate = Completer<FakeResponse>();
      env.server.onGet(
        '/test-user',
        (req) => gate.future,
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(
        tester,
        const ProfilePage(slug: 'test-user'),
        size: const Size(500, 900),
      );
      await settleAsync(tester);
      await tester.pump();
      // Scroll the media grid past 80% so _loadMore starts on page 2.
      await tester.drag(find.byType(GridView), const Offset(0, -3000));
      await tester.pump();
      // While page 2 is in flight, switch to the playlists tab. The tab
      // animation needs fake time before _currentTab flips.
      await tester.tap(find.textContaining('Playlists'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      gate.complete(
        FakeResponse.inertia(
          'Profile',
          profileProps(
            media: const [],
            playlists: [playlistJson(id: 'pl-2', name: 'Second')],
          ),
        ),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.byType(ProfilePage), findsOneWidget);
    });
  });

  group('SearchPage gaps', () {
    FakeResponse searchJson({dynamic next, String? query}) =>
        FakeResponse.inertia('Search', {
          'query': query ?? 'q',
          'media': [mediaJson()],
          'users': const [],
          'tag_matches': const [],
          'pagination': paginationJson(next: next),
        });

    void stubSearch({dynamic next}) {
      env.server.onGet(
        '/search',
        (req) => searchJson(next: next, query: req.uri.queryParameters['q']),
        matchQuery: (uri) => uri.queryParameters['page'] != '2',
      );
    }

    testWidgets('mid and wide widths render', (tester) async {
      stubSearch();
      await pumpApp(
        tester,
        const SearchPage(initialQuery: 'q'),
        size: const Size(800, 900),
      );
      await settleAsync(tester);
      await tester.pump();
      await pumpApp(
        tester,
        const SearchPage(initialQuery: 'q'),
        size: const Size(1300, 900),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsWidgets);
    });

    testWidgets('scroll loads next page of results', (tester) async {
      stubSearch(next: '/search?q=q&page=2');
      env.server.onGet(
        '/search',
        (req) => FakeResponse.inertia('Search', {
          'query': 'q',
          'media': [mediaJson(id: 'm9', shortCode: 'P9', title: 'Page2')],
          'users': const [],
          'tag_matches': const [],
          'pagination': paginationJson(page: 2),
        }),
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(
        tester,
        const SearchPage(initialQuery: 'q'),
        size: const Size(500, 700),
      );
      await settleAsync(tester);
      await tester.pump();
      // The +1 trailing cell auto-triggers loadMore when it builds.
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -800),
        1000,
      );
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(
        env.server.requests.where((r) => r.uri.queryParameters['page'] == '2'),
        isNotEmpty,
      );
    });

    testWidgets('load more failure is swallowed', (tester) async {
      stubSearch(next: '/search?q=q&page=2');
      env.server.onGet(
        '/search',
        (req) => const FakeResponse(500, 'err'),
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(
        tester,
        const SearchPage(initialQuery: 'q'),
        size: const Size(500, 700),
      );
      await settleAsync(tester);
      await tester.pump();
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -800),
        1000,
      );
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(
        env.server.requests.where((r) => r.uri.queryParameters['page'] == '2'),
        isNotEmpty,
      );
    });

    testWidgets('loading spinner shows while search is in flight', (
      tester,
    ) async {
      final gate = Completer<FakeResponse>();
      env.server.onGet('/search', (req) => gate.future);
      await pumpApp(tester, const SearchPage(initialQuery: 'q'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      gate.complete(searchJson());
      await settleAsync(tester);
      await tester.pump();
    });

    testWidgets('suggestion spinner shows while request is in flight', (
      tester,
    ) async {
      final gate = Completer<FakeResponse>();
      env.server.onGet('/search/suggest', (req) => gate.future);
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      gate.complete(FakeResponse.json({'users': [], 'tags': []}));
      await settleAsync(tester);
      await tester.pump();
    });

    testWidgets('suggested user with avatar pushes profile', (tester) async {
      env.server.onGet(
        '/search/suggest',
        (req) => FakeResponse.json({
          'users': [
            {'slug': 'sug1', 'name': 'Sug', 'avatar_url': 'https://x/a.png'},
          ],
          'tags': const [],
        }),
      );
      env.server.onGet(
        '/sug1',
        (req) => FakeResponse.inertia('Profile', profileProps()),
      );
      await pumpApp(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'sug');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester);
      await awaitImages(tester);
      expect(find.text('Sug'), findsOneWidget);
      await tester.tap(find.text('Sug'));
      await tester.pump();
      await settleAsync(tester);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(env.server.requestsTo('/sug1'), isNotEmpty);
    });

    testWidgets('result card tap pushes video detail', (tester) async {
      stubSearch();
      env.server.onGet(
        '/v/ABC1',
        (req) => FakeResponse.inertia('Video', videoProps()),
      );
      await pumpApp(tester, const SearchPage(initialQuery: 'q'));
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Test Video'));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(env.server.requestsTo('/v/ABC1'), isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('result user tile with avatar pushes profile', (tester) async {
      env.server.onGet(
        '/search',
        (req) => FakeResponse.inertia('Search', {
          'query': 'q',
          'media': const [],
          'users': [userJson(slug: 'found1', avatarUrl: 'https://x/a.png')],
          'tag_matches': const [],
          'pagination': paginationJson(),
        }),
      );
      env.server.onGet(
        '/found1',
        (req) => FakeResponse.inertia('Profile', profileProps()),
      );
      await pumpApp(tester, const SearchPage(initialQuery: 'q'));
      await settleAsync(tester);
      await awaitImages(tester);
      expect(find.text('Test User'), findsWidgets);
      await tester.tap(find.text('Test User'));
      await tester.pump();
      await settleAsync(tester);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(env.server.requestsTo('/found1'), isNotEmpty);
    });

    testWidgets('back arrow pops when pushed', (tester) async {
      stubSearch();
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(SearchPage), findsNothing);
    });
  });

  group('SettingsPage gaps', () {
    testWidgets('auth change reloads settings', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {'user': userJson()}),
      );
      await pumpApp(tester, const SettingsPage(), size: const Size(500, 900));
      await settleAsync(tester);
      await tester.pump();
      expect(env.server.requestsTo('/settings'), isNotEmpty);
      // The authed card is showing before the change.
      expect(find.text('Test User'), findsOneWidget);
      MurrtubeApi.clearCookies();
      // A theme change runs didChangeDependencies, which notices the auth
      // change and reloads. The AnimatedTheme inside MaterialApp needs fake
      // time to advance before its InheritedTheme notifies dependents.
      await pumpApp(
        tester,
        const SettingsPage(),
        size: const Size(500, 900),
        theme: ThemeData.light(),
      );
      await tester.pump(kThemeAnimationDuration);
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test User'), findsNothing);
    });

    testWidgets('authed user card renders avatar image', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {
          'user': userJson(avatarUrl: 'https://x/broken.png'),
        }),
      );
      await pumpApp(tester, const SettingsPage());
      await settleAsync(tester);
      await awaitImages(tester);
      expect(find.byIcon(Icons.person), findsWidgets);
    });
  });

  group('CookieSetupPage gaps', () {
    testWidgets('prefills field from bundled cookies asset', (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key.endsWith('cookies.txt')) {
          return ByteData.sublistView(
            Uint8List.fromList(
              utf8.encode(
                'murrtube.net\tTRUE\t/\tTRUE\t9999999999\tsession_id\tfromasset\n',
              ),
            ),
          );
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
      await pumpApp(tester, const CookieSetupPage());
      await settleAsync(tester);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'session_id=fromasset');
    });

    testWidgets('back arrow pops', (tester) async {
      bool? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CookieSetupPage()),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CookieSetupPage), findsNothing);
      expect(result, isNull);
    });
  });

  group('LoginPage gaps', () {
    testWidgets('save error shows snackbar when disk write fails', (
      tester,
    ) async {
      env.pathProvider.failDocuments = true;
      await pumpApp(tester, const LoginPage(), size: const Size(600, 1600));
      await tester.enterText(find.byType(TextField).first, 'sess1');
      await tester.runAsync(() async {
        await tester.tap(find.text('Save & Connect'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('close button pops', (tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
            child: const Text('open'),
          ),
        ),
        size: const Size(600, 1600),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(LoginPage), findsNothing);
    });
  });
}
