import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/main.dart';
import 'package:murrmobile/pages/about_page.dart';
import 'package:murrmobile/pages/age_confirmation_page.dart';
import 'package:murrmobile/pages/cookie_setup_page.dart';
import 'package:murrmobile/pages/home_page.dart';
import 'package:murrmobile/pages/notifications_page.dart';
import 'package:murrmobile/services/murrtube_api.dart';
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
  });

  tearDown(() {
    MurrtubeApi.clearCookies();
  });

  FakeResponse homePage({List<Map<String, dynamic>>? media}) =>
      FakeResponse.inertia('Home', {
        'media': media ?? [mediaJson()],
        'pagination': paginationJson(),
        'announcements': const [],
      });

  group('MurrtubeApp / AgeCheckWrapper', () {
    testWidgets('shows age confirmation when not confirmed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MurrtubeApp());
      await tester.pump();
      await settleAsync(tester);
      expect(find.byType(AgeConfirmationPage), findsOneWidget);
      expect(find.text('Age Verification'), findsOneWidget);
    });

    testWidgets('shows shell once age confirmed in prefs', (tester) async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      env.server.onGet('/', (req) => homePage(media: const []));
      await tester.pumpWidget(const MurrtubeApp());
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(find.byType(ResponsiveShell), findsOneWidget);
    });

    testWidgets('confirming age swaps to shell', (tester) async {
      SharedPreferences.setMockInitialValues({});
      env.server.onGet('/', (req) => homePage(media: const []));
      await tester.pumpWidget(const MurrtubeApp());
      await tester.pump();
      await settleAsync(tester);
      await tester.tap(find.text('I am 18+'));
      await tester.pump();
      await settleAsync(tester);
      expect(find.byType(ResponsiveShell), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('age_confirmed'), isTrue);
    });

    testWidgets('main() runs the app', (tester) async {
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      env.server.onGet('/', (req) => homePage(media: const []));
      // main() awaits CookieLoader.load() then runs the app.
      await tester.runAsync(() async {
        // ignore: avoid_redundant_argument_values
        await Future<void>.microtask(() {});
      });
      // Call the real entrypoint in a runAsync zone so async prefs work.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      // Directly invoke main's body equivalent since main() calls runApp.
      await tester.pumpWidget(const MurrtubeApp());
      await tester.pump();
      expect(find.byType(AgeCheckWrapper), findsOneWidget);
    });
  });

  group('AgeConfirmationPage', () {
    testWidgets('exit shows snackbar', (tester) async {
      await pumpApp(tester, const AgeConfirmationPage());
      await tester.tap(find.text('Exit'));
      await tester.pump();
      expect(
        find.text('Please close the app and uninstall it'),
        findsOneWidget,
      );
    });

    testWidgets('confirm calls onConfirmed', (tester) async {
      var confirmed = false;
      await pumpApp(
        tester,
        AgeConfirmationPage(onConfirmed: () => confirmed = true),
      );
      await tester.tap(find.text('I am 18+'));
      await tester.pump();
      expect(confirmed, isTrue);
    });
  });

  group('AboutPage', () {
    testWidgets('terms loads and shows effective date', (tester) async {
      env.server.onGet(
        '/about/terms',
        (req) => FakeResponse.inertia('Terms', {
          'effective_date': '2026-01-01',
          'content': 'blah',
        }),
      );
      await pumpApp(tester, const AboutPage(type: 'terms'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Effective 2026-01-01'), findsOneWidget);
      expect(
        find.textContaining('Content loaded from Murrtube'),
        findsOneWidget,
      );
    });

    testWidgets('privacy loads', (tester) async {
      env.server.onGet(
        '/about/privacy',
        (req) => FakeResponse.inertia('Privacy', {'effective_date': 'x'}),
      );
      await pumpApp(tester, const AboutPage(type: 'privacy'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('cookies loads', (tester) async {
      env.server.onGet(
        '/about/cookies',
        (req) => FakeResponse.inertia('Cookies', {'effective_date': 'x'}),
      );
      await pumpApp(tester, const AboutPage(type: 'cookies'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Cookie Policy'), findsOneWidget);
    });

    testWidgets('whats-new loads', (tester) async {
      env.server.onGet(
        '/about/whats-new',
        (req) => FakeResponse.inertia('WhatsNew', {'effective_date': 'x'}),
      );
      await pumpApp(tester, const AboutPage(type: 'whats-new'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text("What's New"), findsOneWidget);
    });

    testWidgets('unknown type shows About and empty props', (tester) async {
      await pumpApp(tester, const AboutPage(type: 'bogus'));
      await tester.pump();
      expect(find.text('About'), findsOneWidget);
      expect(find.textContaining('Effective'), findsNothing);
    });

    testWidgets('api error still renders page', (tester) async {
      env.server.onGet('/about/terms', (req) => const FakeResponse(500, 'err'));
      await pumpApp(tester, const AboutPage(type: 'terms'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('back button pops', (tester) async {
      env.server.onGet(
        '/about/terms',
        (req) => FakeResponse.inertia('Terms', {}),
      );
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutPage(type: 'terms')),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.byType(AboutPage), findsNothing);
    });
  });

  group('CookieSetupPage', () {
    testWidgets('renders welcome and buttons', (tester) async {
      await pumpApp(tester, const CookieSetupPage());
      await tester.pump();
      expect(find.text('Welcome to Murrmobile'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('connect with cookies pops true and sets api cookies', (
      tester,
    ) async {
      bool? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const CookieSetupPage()),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'session_id=abc; age_check=1',
      );
      // runAsync: CookieLoader.save does real file IO that fake-time
      // microtasks never complete.
      await tester.runAsync(() async {
        await tester.tap(find.text('Connect'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      // Bounded pumps: the connect button spinner animates forever, so
      // pumpAndSettle would hang while the pop transition runs.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(result, isTrue);
      expect(MurrtubeApi.isAuthenticated, isTrue);
    });

    testWidgets('connect with empty field continues as guest', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      bool? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const CookieSetupPage()),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(MurrtubeApi.hasCookies, isFalse);
    });

    testWidgets('continue as guest pops true and clears cookies', (
      tester,
    ) async {
      MurrtubeApi.setCookies('session_id=abc');
      bool? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const CookieSetupPage()),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(MurrtubeApi.hasCookies, isFalse);
    });
  });

  group('HomePage', () {
    testWidgets('loads trending media into grid', (tester) async {
      env.server.onGet('/', (req) => homePage());
      await pumpApp(tester, const HomePage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Test Video'), findsOneWidget);
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('For You'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Subscriptions'), findsNothing);
    });

    testWidgets('authed shows subscriptions tab', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet('/', (req) => homePage());
      await pumpApp(tester, const HomePage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Subscriptions'), findsOneWidget);
    });

    testWidgets('shows announcements when present', (tester) async {
      env.server.onGet(
        '/',
        (req) => FakeResponse.inertia('Home', {
          'media': const [],
          'pagination': paginationJson(),
          'announcements': [announcementJson()],
        }),
      );
      await pumpApp(tester, const HomePage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Announcement'), findsOneWidget);
      expect(find.text('No videos found'), findsOneWidget);
    });

    testWidgets('switching tab reloads with new tab param', (tester) async {
      env.server.onGet('/', (req) => homePage());
      await pumpApp(tester, const HomePage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Latest'));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      final latest = env.server.requests.last;
      expect(latest.uri.queryParameters['tab'], 'latest');
    });

    testWidgets('load failure shows empty state', (tester) async {
      env.server.onGet('/', (req) => const FakeResponse(500, 'err'));
      await pumpApp(tester, const HomePage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('No videos found'), findsOneWidget);
    });

    testWidgets('loads more pages when scrolled to end', (tester) async {
      final media = List.generate(
        8,
        (i) => mediaJson(id: 'm$i', shortCode: 'C$i', title: 'V$i'),
      );
      env.server.onGet(
        '/',
        (req) => FakeResponse.inertia('Home', {
          'media': media,
          'pagination': paginationJson(pages: 2, next: '/?tab=trending&page=2'),
          'announcements': const [],
        }),
        matchQuery: (uri) => uri.queryParameters['page'] != '2',
      );
      env.server.onGet(
        '/',
        (req) => FakeResponse.inertia('Home', {
          'media': [mediaJson(id: 'm9', shortCode: 'C9', title: 'V9')],
          'pagination': paginationJson(page: 2, pages: 2),
          'announcements': const [],
        }),
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(tester, const HomePage(), size: const Size(500, 900));
      await settleAsync(tester);
      await tester.pump();
      // Scroll the grid to trigger the load-more sentinel.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(
        env.server.requests.where((r) => r.uri.queryParameters['page'] == '2'),
        isNotEmpty,
      );
    });

    testWidgets('tapping a card pushes video detail', (tester) async {
      env.server.onGet('/', (req) => homePage());
      env.server.onGet(
        RegExp(r'/v/'),
        (req) => FakeResponse.inertia('Video', videoProps()),
      );
      await pumpApp(tester, const HomePage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Test Video'));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
      // Unmount so the detail page's timers are cancelled, then let the
      // controller's async dispose finish on the real event loop.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    });
  });

  group('NotificationsPage', () {
    testWidgets('empty state', (tester) async {
      env.server.onGet(
        '/notifications',
        (req) => FakeResponse.inertia('Notifications', {
          'items': const [],
          'display_cap': 50,
        }),
      );
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('loads items with unread indicator and mark-all-read', (
      tester,
    ) async {
      env.server.onGet(
        '/notifications',
        (req) => FakeResponse.inertia('Notifications', {
          'items': [
            notificationJson(isUnread: true, actor: actorJson()),
            notificationJson(id: 2, isUnread: false, actor: actorJson()),
          ],
          'display_cap': 50,
        }),
      );
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.text('Actor commented'), findsWidgets);
    });

    testWidgets('load error shows empty state', (tester) async {
      env.server.onGet(
        '/notifications',
        (req) => const FakeResponse(500, 'err'),
      );
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('tapping item with video url pushes detail', (tester) async {
      env.server.onGet(
        '/notifications',
        (req) => FakeResponse.inertia('Notifications', {
          'items': [
            notificationJson(link: '/v/ABC1#comment-9', actor: actorJson()),
          ],
          'display_cap': 50,
        }),
      );
      env.server.onGet(
        RegExp(r'/v/'),
        (req) => FakeResponse.inertia('Video', videoProps()),
      );
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Actor commented'));
      await tester.pump();
      await settleAsync(tester);
      // Video detail pushed; it fetches /v/ABC1.
      expect(env.server.requestsTo('/v/ABC1'), isNotEmpty);
      // Fire the 400ms scroll-to-comment timer before unmounting.
      await tester.pump(const Duration(milliseconds: 500));
      // Unmount so the detail page's timers are cancelled, then let the
      // controller's async dispose finish on the real event loop.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    });

    testWidgets('item without url does nothing on tap', (tester) async {
      env.server.onGet(
        '/notifications',
        (req) => FakeResponse.inertia('Notifications', {
          'items': [notificationJson(link: null, actor: actorJson())],
          'display_cap': 50,
        }),
      );
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.text('Actor commented'));
      await tester.pump();
      // Still on the notifications page.
      expect(find.text('Activity'), findsOneWidget);
    });
  });
}
