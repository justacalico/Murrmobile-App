import 'package:flutter/material.dart';

/// Always false on platforms without dart:io (web).
bool get isDesktopPlatform => false;

/// Overrides the platform used by the window frame; only for tests.
@visibleForTesting
TargetPlatform? debugPlatformOverride;

/// Set by in-app fullscreen content (fullscreen video) so [WindowFrame]
/// hides the title bar while it is up.
final windowContentFullscreen = ValueNotifier<bool>(false);

Future<bool> initializeWindowFrame() async => false;

Future<void> setWindowFullScreen(bool fullscreen) async {}

Object? addWindowFullscreenListener(
  void Function(bool isFullScreen) onChanged,
) => null;

void removeWindowFullscreenListener(Object? token) {}

/// On platforms without dart:io there is no window to frame, so the child
/// is returned untouched.
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, required this.child});

  final Widget child;

  @visibleForTesting
  static Future<bool> Function()? debugInitialize;

  @override
  Widget build(BuildContext context) => child;
}
