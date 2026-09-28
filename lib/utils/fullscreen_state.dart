import 'package:flutter/foundation.dart';

/// True while a video is playing fullscreen. The shell hides its
/// navigation chrome (bottom bar / rail) and safe-area padding so the
/// video can cover the whole window.
final fullscreenMode = ValueNotifier<bool>(false);
