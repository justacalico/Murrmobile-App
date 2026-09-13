import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Fake video player that reports an initialized 1280x720 video and tracks
/// play/pause/seek state so the real [VideoPlayerController] works normally.
class FakeVideoPlayerPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _eventControllers = {};
  final Map<int, Duration> positions = {};
  final Map<int, bool> playingStates = {};
  final Map<int, bool> loopingStates = {};
  final Map<int, double> volumes = {};
  int _nextId = 0;

  Duration videoDuration = const Duration(seconds: 100);
  Size videoSize = const Size(1280, 720);
  bool emitInitialized = true;

  StreamController<VideoEvent> _eventsFor(int id) =>
      _eventControllers.putIfAbsent(id, () => StreamController<VideoEvent>());

  void emitEvent(int id, VideoEvent event) {
    _eventsFor(id).add(event);
  }

  /// Emit the initialized event for an existing player. Called automatically
  /// by [createWithOptions] unless [emitInitialized] is false.
  void emitInitializedFor(int id) {
    _eventsFor(id).add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: videoDuration,
        size: videoSize,
      ),
    );
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++_nextId;
    positions[id] = Duration.zero;
    playingStates[id] = false;
    loopingStates[id] = false;
    volumes[id] = 1.0;
    if (emitInitialized) {
      // Single-subscription controllers buffer events until listened, so this
      // lands once the controller subscribes in initialize().
      emitInitializedFor(id);
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _eventsFor(playerId).stream;

  @override
  Future<void> dispose(int playerId) async {
    positions.remove(playerId);
    playingStates.remove(playerId);
    loopingStates.remove(playerId);
    volumes.remove(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    loopingStates[playerId] = looping;
  }

  @override
  Future<void> play(int playerId) async {
    playingStates[playerId] = true;
    emitEvent(
      playerId,
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    playingStates[playerId] = false;
    emitEvent(
      playerId,
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes[playerId] = volume;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

FakeVideoPlayerPlatform installFakeVideoPlayer() {
  final fake = FakeVideoPlayerPlatform();
  VideoPlayerPlatform.instance = fake;
  return fake;
}

/// Records launched URLs and lets tests control canLaunch/launch results.
class FakeUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launchedUrls = [];
  bool canLaunchResult = true;
  bool launchResult = true;

  @override
  Future<bool> canLaunch(String url) async => canLaunchResult;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return launchResult;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    Map<String, String> headers = const <String, String>{},
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return launchResult;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<void> closeWebView() async {}
}

FakeUrlLauncherPlatform installFakeUrlLauncher() {
  final fake = FakeUrlLauncherPlatform();
  UrlLauncherPlatform.instance = fake;
  return fake;
}

class FakeWakelockPlus extends Fake
    with MockPlatformInterfaceMixin
    implements WakelockPlusPlatformInterface {
  bool _enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  bool get isMock => true;

  @override
  Future<void> toggle({required bool enable}) async {
    _enabled = enable;
    if (enable) {
      enableCalls++;
    } else {
      disableCalls++;
    }
  }

  @override
  Future<bool> get enabled async => _enabled;
}

FakeWakelockPlus installFakeWakelock() {
  final fake = FakeWakelockPlus();
  WakelockPlusPlatformInterface.instance = fake;
  // wakelock_plus caches the platform in a top-level variable on first use,
  // so each new fake has to be assigned there too.
  wakelockPlusPlatformInstance = fake;
  return fake;
}

/// Serves path_provider calls from a real temp directory so file IO works.
class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  FakePathProvider(this.root);

  final Directory root;

  /// When true, documents lookups fail like a device with no storage.
  bool failDocuments = false;

  /// When true, temp dir lookups fail.
  bool failTemporary = false;

  String _dir(String name) {
    final d = Directory('${root.path}/$name')..createSync(recursive: true);
    return d.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      failDocuments ? null : _dir('documents');

  @override
  Future<String?> getApplicationSupportPath() async => _dir('support');

  @override
  Future<String?> getTemporaryPath() async =>
      failTemporary ? null : _dir('tmp');

  @override
  Future<String?> getApplicationCachePath() async => _dir('cache');

  @override
  Future<String?> getLibraryPath() async => _dir('library');

  @override
  Future<String?> getDownloadsPath() async => _dir('downloads');
}

FakePathProvider installFakePathProvider() {
  final root = Directory.systemTemp.createTempSync('murrmobile_test_');
  final fake = FakePathProvider(root);
  PathProviderPlatform.instance = fake;
  return fake;
}

/// Fails every image fetch so CachedNetworkImage widgets land on their
/// errorWidget branch without real file IO or sqflite.
class FakeCacheManager extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream<FileResponse>.error(Exception('image unavailable'));
}
