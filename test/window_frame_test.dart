import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murrmobile/widgets/window_frame.dart';
import 'package:murrmobile/widgets/window_title_bar.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    installTestEnv();
    windowContentFullscreen.value = false;
    WindowFrame.debugInitialize = null;
    debugPlatformOverride = null;
  });

  tearDown(() {
    windowContentFullscreen.value = false;
    WindowFrame.debugInitialize = null;
    debugPlatformOverride = null;
  });

  // Widget tests default to TargetPlatform.android; pretend to be a desktop
  // platform so WindowFrame activates.
  void useDesktopPlatform([TargetPlatform platform = TargetPlatform.linux]) {
    debugPlatformOverride = platform;
  }

  group('WindowTitleBar', () {
    testWidgets('renders title and three traffic lights', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: WindowTitleBar(title: 'Murrmobile')),
      );
      expect(find.text('Murrmobile'), findsOneWidget);
      expect(find.byKey(const ValueKey('window-close')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-minimize')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-maximize')), findsOneWidget);
    });

    testWidgets('button callbacks fire', (tester) async {
      var closed = 0;
      var minimized = 0;
      var maximized = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: WindowTitleBar(
            title: 'Murrmobile',
            onClose: () => closed++,
            onMinimize: () => minimized++,
            onToggleMaximize: () => maximized++,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('window-close')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('window-minimize')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('window-maximize')));
      await tester.pump();
      expect(closed, 1);
      expect(minimized, 1);
      expect(maximized, 1);
    });

    testWidgets('glyphs appear when hovering the controls', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: WindowTitleBar(title: 'Murrmobile')),
      );
      expect(find.byIcon(Icons.close), findsNothing);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('window-close'))),
      );
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('showControls false hides traffic lights', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: WindowTitleBar(title: 'Murrmobile', showControls: false),
        ),
      );
      expect(find.text('Murrmobile'), findsOneWidget);
      expect(find.byKey(const ValueKey('window-close')), findsNothing);
    });

    testWidgets('pan invokes onDragStart', (tester) async {
      var drags = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: WindowTitleBar(title: 'Murrmobile', onDragStart: () => drags++),
        ),
      );
      await tester.drag(
        find.text('Murrmobile'),
        const Offset(80, 0),
        warnIfMissed: false,
      );
      expect(drags, 1);
    });

    testWidgets('double tap toggles maximize', (tester) async {
      var maximized = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: WindowTitleBar(
            title: 'Murrmobile',
            onToggleMaximize: () => maximized++,
          ),
        ),
      );
      await tester.tap(find.text('Murrmobile'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('Murrmobile'), warnIfMissed: false);
      await tester.pump();
      expect(maximized, 1);
    });

    testWidgets('button taps never reach the double-tap handler', (
      tester,
    ) async {
      var closed = 0;
      var maximized = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: WindowTitleBar(
            title: 'Murrmobile',
            onClose: () => closed++,
            onToggleMaximize: () => maximized++,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('window-close')));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(const ValueKey('window-close')));
      await tester.pump();
      expect(closed, 2);
      expect(maximized, 0);
    });
  });

  group('WindowFrame', () {
    testWidgets('renders child untouched when init fails', (tester) async {
      // No debugInitialize: real ensureInitialized() fails in tests, so the
      // frame falls back to the plain child.
      useDesktopPlatform();
      await pumpApp(tester, const WindowFrame(child: Text('content')));
      await tester.pump();
      await tester.pump();
      expect(find.text('content'), findsOneWidget);
      expect(find.byType(WindowTitleBar), findsNothing);
    });

    testWidgets('renders title bar once initialized', (tester) async {
      useDesktopPlatform();
      WindowFrame.debugInitialize = () async => true;
      await pumpApp(tester, const WindowFrame(child: Text('content')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(WindowTitleBar), findsOneWidget);
      expect(find.text('Murrmobile'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      expect(find.byKey(const ValueKey('window-close')), findsOneWidget);
    });

    testWidgets('macOS keeps native controls, draws none', (tester) async {
      useDesktopPlatform(TargetPlatform.macOS);
      WindowFrame.debugInitialize = () async => true;
      await pumpApp(tester, const WindowFrame(child: Text('content')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(WindowTitleBar), findsOneWidget);
      expect(find.text('Murrmobile'), findsOneWidget);
      expect(find.byKey(const ValueKey('window-close')), findsNothing);
    });

    testWidgets('non-desktop platform renders child only', (tester) async {
      useDesktopPlatform(TargetPlatform.android);
      WindowFrame.debugInitialize = () async => true;
      await pumpApp(tester, const WindowFrame(child: Text('content')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(WindowTitleBar), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('hides bar while in-app content is fullscreen', (tester) async {
      useDesktopPlatform();
      WindowFrame.debugInitialize = () async => true;
      await pumpApp(tester, const WindowFrame(child: Text('content')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(WindowTitleBar), findsOneWidget);
      windowContentFullscreen.value = true;
      await tester.pump();
      expect(find.byType(WindowTitleBar), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('control taps do not crash without a real manager', (
      tester,
    ) async {
      useDesktopPlatform();
      WindowFrame.debugInitialize = () async => true;
      await pumpApp(tester, const WindowFrame(child: Text('content')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('window-close')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('window-minimize')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('window-maximize')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('init returning false renders child without bar', (
      tester,
    ) async {
      useDesktopPlatform();
      WindowFrame.debugInitialize = () async => false;
      await pumpApp(tester, const WindowFrame(child: Text('content')));
      await tester.pump();
      await tester.pump();
      expect(find.text('content'), findsOneWidget);
      expect(find.byType(WindowTitleBar), findsNothing);
    });

    testWidgets('child is not remounted when the bar appears', (tester) async {
      var inits = 0;
      useDesktopPlatform();
      WindowFrame.debugInitialize = () async => true;
      await pumpApp(
        tester,
        WindowFrame(child: _InitCounter(onInit: () => inits++)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(WindowTitleBar), findsOneWidget);
      expect(inits, 1);
    });

    test('fullscreen listener add/remove round-trip', () {
      useDesktopPlatform();
      var calls = 0;
      final token = addWindowFullscreenListener((_) => calls++);
      expect(token, isNotNull);
      removeWindowFullscreenListener(token);
      removeWindowFullscreenListener(token);
      removeWindowFullscreenListener(null);
      expect(calls, 0);
    });
  });
}

class _InitCounter extends StatefulWidget {
  const _InitCounter({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_InitCounter> createState() => _InitCounterState();
}

class _InitCounterState extends State<_InitCounter> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const Text('content');
}
