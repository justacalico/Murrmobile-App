import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'window_title_bar.dart';

/// Whether the current platform is a desktop target that gets the custom
/// title bar. Uses [defaultTargetPlatform]; tests can pretend to be on
/// another platform via [debugPlatformOverride].
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return const {
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  }.contains(_platform);
}

/// Overrides the platform used by the window frame; only for tests.
@visibleForTesting
TargetPlatform? debugPlatformOverride;

TargetPlatform get _platform => debugPlatformOverride ?? defaultTargetPlatform;

/// Set by in-app fullscreen content (fullscreen video) so [WindowFrame]
/// hides the title bar while it is up.
final windowContentFullscreen = ValueNotifier<bool>(false);

/// Initializes the desktop window: hides the native title bar so
/// [WindowFrame] can draw its own, and sets a sane minimum size.
/// Returns false when no usable window manager is around.
/// Memoized so main() and [WindowFrame] share one channel round-trip.
Future<bool> initializeWindowFrame() {
  if (!isDesktopPlatform) return Future.value(false);
  return _initFuture ??= _initializeWindow();
}

Future<bool>? _initFuture;

Future<bool> _initializeWindow() async {
  try {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(360, 500));
    await windowManager.setTitle('Murrmobile');
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    return true;
  } catch (_) {
    return false;
  }
}

/// Sets OS-level fullscreen on desktop; a no-op elsewhere or when the
/// window manager is unavailable.
Future<void> setWindowFullScreen(bool fullscreen) async {
  if (!isDesktopPlatform) return;
  try {
    await windowManager.setFullScreen(fullscreen);
  } catch (_) {}
}

/// Registers [onChanged] for OS fullscreen transitions so in-app content
/// can stay in sync. Returns a token for [removeWindowFullscreenListener],
/// or null when unsupported.
Object? addWindowFullscreenListener(
  void Function(bool isFullScreen) onChanged,
) {
  if (!isDesktopPlatform) return null;
  final listener = _FullscreenCallbackListener(onChanged);
  windowManager.addListener(listener);
  return listener;
}

/// Removes a listener token returned by [addWindowFullscreenListener].
void removeWindowFullscreenListener(Object? token) {
  if (token is WindowListener) windowManager.removeListener(token);
}

class _FullscreenCallbackListener with WindowListener {
  _FullscreenCallbackListener(this.onChanged);

  final void Function(bool isFullScreen) onChanged;

  @override
  void onWindowEnterFullScreen() => onChanged(true);

  @override
  void onWindowLeaveFullScreen() => onChanged(false);
}

/// Wraps [child] in a frameless-window scaffold that draws a macOS-style
/// title bar on desktop platforms. Returns [child] untouched elsewhere.
class WindowFrame extends StatefulWidget {
  const WindowFrame({super.key, required this.child});

  final Widget child;

  @visibleForTesting
  static Future<bool> Function()? debugInitialize;

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> with WindowListener {
  bool _active = false;
  bool _isFocused = true;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    if (isDesktopPlatform) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    }
  }

  Future<void> _init() async {
    final initialize = WindowFrame.debugInitialize ?? initializeWindowFrame;
    final ok = await initialize();
    if (!ok || !mounted) return;
    windowManager.addListener(this);
    unawaited(_syncState());
    if (mounted) setState(() => _active = true);
  }

  Future<void> _syncState() async {
    try {
      final isFullScreen = await windowManager.isFullScreen();
      final isFocused = await windowManager.isFocused();
      if (mounted) {
        setState(() {
          _isFullScreen = isFullScreen;
          _isFocused = isFocused;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_active) windowManager.removeListener(this);
    super.dispose();
  }

  void _invoke(Future<void> Function() action) {
    () async {
      try {
        await action();
      } catch (_) {}
    }();
  }

  Future<void> _toggleMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  @override
  void onWindowFocus() => setState(() => _isFocused = true);

  @override
  void onWindowBlur() => setState(() => _isFocused = false);

  @override
  void onWindowEnterFullScreen() => setState(() => _isFullScreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _isFullScreen = false);

  @override
  Widget build(BuildContext context) {
    // The child's slot in the tree must not move when the bar appears, or
    // the whole Navigator subtree would remount.
    Widget content = Column(
      children: [
        if (_active && !_isFullScreen)
          ValueListenableBuilder<bool>(
            valueListenable: windowContentFullscreen,
            builder: (context, contentFullscreen, _) {
              if (contentFullscreen) return const SizedBox.shrink();
              return WindowTitleBar(
                title: 'Murrmobile',
                isFocused: _isFocused,
                showControls: _platform != TargetPlatform.macOS,
                onDragStart: () => _invoke(windowManager.startDragging),
                onMinimize: () => _invoke(windowManager.minimize),
                onToggleMaximize: () => _invoke(_toggleMaximize),
                onClose: () => _invoke(windowManager.close),
              );
            },
          ),
        Expanded(child: ClipRect(child: widget.child)),
      ],
    );
    // TitleBarStyle.hidden strips all decorations on X11 window managers
    // without a GtkHeaderBar, leaving the window unresizable.
    if (_platform == TargetPlatform.linux) {
      content = DragToResizeArea(child: content);
    }
    return content;
  }
}
