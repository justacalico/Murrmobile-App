import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/providers/theme_provider.dart';
import 'package:murrmobile/providers/navigation_provider.dart';
import 'package:murrmobile/theme/app_theme.dart';

import 'fake_http.dart';
import 'fake_platforms.dart';

/// Holds references to all installed fakes so tests can inspect them.
class TestEnv {
  final FakeServer server;
  final FakeVideoPlayerPlatform videoPlayer;
  final FakeUrlLauncherPlatform urlLauncher;
  final FakeWakelockPlus wakelock;
  final FakePathProvider pathProvider;

  TestEnv({
    required this.server,
    required this.videoPlayer,
    required this.urlLauncher,
    required this.wakelock,
    required this.pathProvider,
  });
}

/// Installs every fake and clears shared preferences. Call in setUp.
TestEnv installTestEnv({FakeServer? server}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final s = installFakeHttp(server);
  SharedPreferences.setMockInitialValues({});
  CachedNetworkImageProvider.defaultCacheManager = FakeCacheManager();
  return TestEnv(
    server: s,
    videoPlayer: installFakeVideoPlayer(),
    urlLauncher: installFakeUrlLauncher(),
    wakelock: installFakeWakelock(),
    pathProvider: installFakePathProvider(),
  );
}

/// Pumps [home] inside the app's provider tree + MaterialApp.
Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(500, 900),
  ThemeData? theme,
  NavigatorObserver? navigatorObserver,
  Map<String, WidgetBuilder>? routes,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        home: home,
        navigatorObservers: navigatorObserver != null
            ? [navigatorObserver]
            : [],
        routes: routes ?? {},
      ),
    ),
  );
}

/// Lets real-async work (file IO through the cache manager) finish, then
/// settles the widget tree.
Future<void> settleAsync(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 50),
]) async {
  await tester.runAsync(() => Future<void>.delayed(duration));
  await tester.pump();
}

/// CachedNetworkImage failures travel through the cache manager over several
/// real-async hops, so errorWidget builders need more than one pump.
Future<void> awaitImages(WidgetTester tester, [int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
}

/// Unmounts the tree and fires the fake-time cache-cleanup timer so tests
/// that load images don't leak pending timers into teardown.
Future<void> unmountForImages(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(seconds: 11));
}

/// Counts text occurrences.
Finder textContaining(String substring) => find.textContaining(substring);
