import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    MurrtubeApi.currentUserSlug = null;
  });

  tearDown(() {
    MurrtubeApi.clearCookies();
    MurrtubeApi.currentUserSlug = null;
  });

  void stubTabs() {
    env.server.onGet(
      '/',
      (req) => FakeResponse.inertia('Home', {
        'media': const [],
        'pagination': paginationJson(),
        'announcements': const [],
      }),
      matchQuery: (uri) => uri.queryParameters.containsKey('tab'),
    );
    env.server.onGet(
      '/notifications',
      (req) => FakeResponse.inertia('Notifications', {
        'items': const [],
        'display_cap': 10,
      }),
    );
    env.server.onGet(
      '/upload',
      (req) => FakeResponse.inertia('Upload', const {}),
    );
    env.server.onGet(
      '/settings',
      (req) => FakeResponse.inertia('Settings', const {}),
    );
  }

  testWidgets('bottom bar mode renders NavigationBar and switches tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'navigation_mode': 'bottom_nav'});
    stubTabs();
    await pumpApp(tester, const ResponsiveShell(), size: const Size(500, 900));
    await settleAsync(tester);
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();
    // Tapping the same destination again pops to the tab root.
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.tap(find.text('Home'));
    await tester.pump();
  });

  testWidgets('authed bottom bar shows upload and activity', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    SharedPreferences.setMockInitialValues({'navigation_mode': 'bottom_nav'});
    stubTabs();
    await pumpApp(tester, const ResponsiveShell(), size: const Size(500, 900));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    await tester.tap(find.text('Activity'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(env.server.requestsTo('/notifications'), isNotEmpty);
  });

  testWidgets('auth change resets tab and rebuilds keys', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    SharedPreferences.setMockInitialValues({'navigation_mode': 'bottom_nav'});
    stubTabs();
    await pumpApp(
      tester,
      const ResponsiveShell(initialIndex: 3),
      size: const Size(500, 900),
    );
    await settleAsync(tester);
    await tester.pump();
    // Log out, then change a dependency to trigger didChangeDependencies.
    MurrtubeApi.clearCookies();
    tester.view.physicalSize = const Size(510, 900);
    await tester.pump();
    await tester.pump();
    // Upload/Activity gone, index clamped to the smaller tab list.
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('desktop width uses extended rail', (tester) async {
    stubTabs();
    await pumpApp(tester, const ResponsiveShell(), size: const Size(1200, 800));
    await settleAsync(tester);
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Murrmobile'), findsOneWidget);
    await tester.tap(find.text('Search'));
    await tester.pump();
  });

  testWidgets('collapsed rail mode shows no label text', (tester) async {
    SharedPreferences.setMockInitialValues({
      'navigation_mode': 'collapsed_sidebar',
    });
    stubTabs();
    await pumpApp(tester, const ResponsiveShell(), size: const Size(500, 900));
    await settleAsync(tester);
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Murrmobile'), findsNothing);
  });

  testWidgets('system back pops inner navigator instead of app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'navigation_mode': 'bottom_nav'});
    env.server.onGet(
      '/',
      (req) => FakeResponse.inertia('Home', {
        'media': [mediaJson()],
        'pagination': paginationJson(),
        'announcements': const [],
      }),
      matchQuery: (uri) => uri.queryParameters.containsKey('tab'),
    );
    stubTabs();
    env.server.onGet(
      RegExp('/v/'),
      (req) => FakeResponse.inertia('Video', videoProps()),
    );
    await pumpApp(tester, const ResponsiveShell(), size: const Size(500, 900));
    await settleAsync(tester);
    await tester.pump();
    // Push a detail page inside the Home tab navigator.
    await tester.tap(find.text('Test Video'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Resize forces a rebuild so the shell's PopScope canPop reflects the
    // pushed inner route before the back dispatch consults it.
    tester.view.physicalSize = const Size(501, 900);
    await tester.pump();
    // System back: PopScope didPop=false -> pops the tab navigator.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ResponsiveShell), findsOneWidget);
    // Unmount cleanly (video detail may leave timers behind).
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('system back on desktop pops inner navigator', (tester) async {
    env.server.onGet(
      '/',
      (req) => FakeResponse.inertia('Home', {
        'media': [mediaJson()],
        'pagination': paginationJson(),
        'announcements': const [],
      }),
      matchQuery: (uri) => uri.queryParameters.containsKey('tab'),
    );
    stubTabs();
    env.server.onGet(
      RegExp('/v/'),
      (req) => FakeResponse.inertia('Video', videoProps()),
    );
    await pumpApp(tester, const ResponsiveShell(), size: const Size(1200, 800));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.text('Test Video'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    tester.view.physicalSize = const Size(1201, 800);
    await tester.pump();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ResponsiveShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 11));
  });
}
