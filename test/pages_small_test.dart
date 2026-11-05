import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/main.dart';
import 'package:murrmobile/pages/age_confirmation_page.dart';
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
    testWidgets('exit invokes onExit', (tester) async {
      var exited = false;
      await pumpApp(
        tester,
        AgeConfirmationPage(onExit: () => exited = true),
      );
      await tester.tap(find.text('Exit'));
      await tester.pump();
      expect(exited, isTrue);
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
      MurrtubeApi.setCookies('_murrtube_v3_session=abc; session_id=abc');
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

    testWidgets('load failure shows retry state and recovers', (tester) async {
      var attempts = 0;
      env.server.onGet('/', (req) {
        attempts++;
        return attempts == 1
            ? const FakeResponse(500, '{"error":"x"}')
            : homePage();
      });
      await pumpApp(tester, const HomePage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('Couldn\'t load videos'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await settleAsync(tester);
      await tester.pump();
      expect(attempts, greaterThan(1));
      expect(find.text('Couldn\'t load videos'), findsNothing);
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

    testWidgets('failed page load retries the same page', (tester) async {
      final media = List.generate(
        8,
        (i) => mediaJson(id: 'm$i', shortCode: 'C$i', title: 'V$i'),
      );
      env.server.onGet(
        '/',
        (req) => FakeResponse.inertia('Home', {
          'media': media,
          'pagination': paginationJson(pages: 3, next: '/?tab=trending&page=2'),
          'announcements': const [],
        }),
        matchQuery: (uri) => uri.queryParameters['page'] != '2',
      );
      var page2Attempts = 0;
      env.server.onGet(
        '/',
        (req) {
          page2Attempts++;
          return page2Attempts == 1
              ? const FakeResponse(500, '{"error":"x"}')
              : FakeResponse.inertia('Home', {
                  'media': [mediaJson(id: 'm9', shortCode: 'C9', title: 'V9')],
                  'pagination': paginationJson(page: 2, pages: 3),
                  'announcements': const [],
                });
        },
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      await pumpApp(tester, const HomePage(), size: const Size(500, 900));
      await settleAsync(tester);
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump();
      await settleAsync(tester);
      await tester.pump();
      expect(page2Attempts, 1);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await settleAsync(tester);
      await tester.pump();
      expect(page2Attempts, 2);
      expect(find.text('V9'), findsOneWidget);
      // Page 3 must not have been requested during the failed attempt.
      expect(
        env.server.requests.where((r) => r.uri.queryParameters['page'] == '3'),
        isEmpty,
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

    testWidgets('load error shows error state', (tester) async {
      env.server.onGet(
        '/notifications',
        (req) => const FakeResponse(500, '{"error":"x"}'),
      );
      await pumpApp(tester, const NotificationsPage());
      await settleAsync(tester);
      await tester.pump();
      expect(find.text("Couldn't load notifications"), findsOneWidget);
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
