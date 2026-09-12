import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:murrmobile/pages/video_detail_page.dart';
import 'package:murrmobile/services/murrtube_api.dart';

import 'support/fake_http.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;

  setUp(() {
    env = installTestEnv();
    SharedPreferences.setMockInitialValues({});
    MurrtubeApi.clearCookies();
    MurrtubeApi.currentUserSlug = null;
  });

  tearDown(() {
    MurrtubeApi.clearCookies();
    MurrtubeApi.currentUserSlug = null;
  });

  void stubVideo([Map<String, dynamic>? props]) {
    env.server.onGet(
      '/v/ABC1',
      (req) => FakeResponse.inertia('Video', props ?? videoProps()),
    );
  }

  void stubCsrf() {
    env.server.onGet('/', (req) => FakeResponse.htmlPage());
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    String shortCode = 'ABC1',
    String? commentId,
    Size size = const Size(800, 3000),
  }) async {
    await pumpApp(
      tester,
      VideoDetailPage(shortCode: shortCode, commentId: commentId),
      size: size,
    );
    await settleAsync(tester);
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    // Fire leftover fake-time timers (cache cleanup, fullscreen UI hide).
    await tester.pump(const Duration(seconds: 11));
  }

  testWidgets('renders video info, tags, comments toggle, watch more', (
    tester,
  ) async {
    stubVideo();
    await pumpDetail(tester);
    expect(find.text('Test Video'), findsOneWidget);
    expect(find.text('Test User'), findsWidgets);
    expect(find.text('@test-user'), findsOneWidget);
    expect(find.text('3943'), findsOneWidget);
    expect(find.text('13 Comments'), findsOneWidget);
    expect(find.text('#test'), findsOneWidget);
    expect(find.text('Watch More'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    // Comments collapsed by default.
    expect(find.text('Nice video!', findRichText: true), findsNothing);
    // The thumbnail 404s through the fake cache manager, building the
    // error widget.
    await awaitImages(tester);
    expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
    await unmount(tester);
  });

  testWidgets('video not found on error', (tester) async {
    env.server.onGet('/v/nope', (req) => const FakeResponse(404, 'no'));
    await pumpDetail(tester, shortCode: 'nope');
    expect(find.text('Video not found'), findsOneWidget);
  });

  testWidgets('description renders when present', (tester) async {
    stubVideo(
      videoProps(
        medium: mediaJson(description: 'check https://example.com out'),
      ),
    );
    await pumpDetail(tester);
    expect(find.textContaining('check', findRichText: true), findsWidgets);
    await unmount(tester);
  });

  testWidgets('toggling comments shows the list and comment box', (
    tester,
  ) async {
    stubVideo();
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    expect(find.text('Nice video!', findRichText: true), findsOneWidget);
    expect(find.text('Add a comment...'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('viewer cannot comment hides input and actions', (tester) async {
    stubVideo(videoProps(viewerCanComment: false));
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    expect(find.text('Nice video!', findRichText: true), findsOneWidget);
    expect(find.text('Add a comment...'), findsNothing);
    expect(find.text('Reply'), findsNothing);
    await unmount(tester);
  });

  testWidgets('post comment calls comments endpoint', (tester) async {
    stubVideo();
    stubCsrf();
    env.server.onPost('/comments', (req) => const FakeResponse(200, '{}'));
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'hello there');
    await tester.tap(find.byIcon(Icons.send).first);
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    final posts = env.server.requests.where(
      (r) => r.method == 'POST' && r.uri.path == '/comments',
    );
    expect(posts, isNotEmpty);
    expect(posts.first.body, contains('comment%5Bbody%5D=hello+there'));
    await unmount(tester);
  });

  testWidgets('post comment failure shows snackbar', (tester) async {
    stubVideo();
    stubCsrf();
    env.server.onPost('/comments', (req) => const FakeResponse(500, 'err'));
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'boom');
    await tester.tap(find.byIcon(Icons.send).first);
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Failed to post comment'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('empty comment is not posted', (tester) async {
    stubVideo();
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send).first);
    await tester.pump();
    await settleAsync(tester);
    expect(
      env.server.requests.where((r) => r.uri.path == '/comments'),
      isEmpty,
    );
    await unmount(tester);
  });

  testWidgets('delete comment confirms then deletes', (tester) async {
    stubVideo(videoProps(comments: [commentJson(isOwner: true)]));
    stubCsrf();
    env.server.onDelete(
      '/comments/comment-1',
      (req) => const FakeResponse(200, '{}'),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Delete comment?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(
      env.server.requests.where(
        (r) => r.method == 'DELETE' && r.uri.path == '/comments/comment-1',
      ),
      isNotEmpty,
    );
    await unmount(tester);
  });

  testWidgets('delete comment cancel does nothing', (tester) async {
    stubVideo(videoProps(comments: [commentJson(isOwner: true)]));
    stubCsrf();
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(env.server.requests.where((r) => r.method == 'DELETE'), isEmpty);
    await unmount(tester);
  });

  testWidgets('delete comment failure shows snackbar', (tester) async {
    stubVideo(videoProps(comments: [commentJson(isOwner: true)]));
    stubCsrf();
    env.server.onDelete(
      '/comments/comment-1',
      (req) => const FakeResponse(500, 'e'),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Delete').last);
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Failed to delete comment'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('reply to comment posts parent_id', (tester) async {
    stubVideo();
    stubCsrf();
    env.server.onPost('/comments', (req) => const FakeResponse(200, '{}'));
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.tap(find.text('Reply'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'a reply');
    await tester.tap(find.byIcon(Icons.send).last);
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    final posts = env.server.requests.where(
      (r) => r.method == 'POST' && r.uri.path == '/comments',
    );
    expect(posts.first.body, contains('comment%5Bparent_id%5D=comment-1'));
    await unmount(tester);
  });

  testWidgets('like toggles and calls likes endpoint', (tester) async {
    stubVideo();
    stubCsrf();
    env.server.onPost('/likes', (req) => const FakeResponse(200, '{}'));
    await pumpDetail(tester);
    await tester.tap(find.text('Likes'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('41'), findsWidgets);
    expect(
      env.server.requests.where(
        (r) => r.method == 'POST' && r.uri.path == '/likes',
      ),
      isNotEmpty,
    );
    await unmount(tester);
  });

  testWidgets('unlike deletes the like', (tester) async {
    stubVideo(videoProps(medium: mediaJson(viewerLiked: true)));
    stubCsrf();
    env.server.onDelete(
      '/likes/media-1',
      (req) => const FakeResponse(200, '{}'),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('Likes'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('39'), findsWidgets);
    expect(
      env.server.requests.where(
        (r) => r.method == 'DELETE' && r.uri.path == '/likes/media-1',
      ),
      isNotEmpty,
    );
    await unmount(tester);
  });

  testWidgets('like failure reverts and shows snackbar', (tester) async {
    stubVideo();
    stubCsrf();
    env.server.onPost('/likes', (req) => const FakeResponse(500, 'err'));
    await pumpDetail(tester);
    await tester.tap(find.text('Likes'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('40'), findsWidgets);
    expect(find.textContaining('Failed to like'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('player initializes with hls url and enables wakelock', (
    tester,
  ) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(env.wakelock.enableCalls, greaterThan(0));
    await unmount(tester);
  });

  testWidgets('mute toggle flips icon and sets volume', (tester) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(env.videoPlayer.volumes.values.last, 0.0);
    await unmount(tester);
  });

  testWidgets('play overlay pauses and resumes', (tester) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    final id = env.videoPlayer.playingStates.keys.last;
    expect(env.videoPlayer.playingStates[id], isTrue);
    // Tap the video area to pause.
    await tester.tap(find.byType(VideoPlayer));
    await tester.pump();
    expect(env.videoPlayer.playingStates[id], isFalse);
    await tester.tap(find.byType(VideoPlayer));
    await tester.pump();
    expect(env.videoPlayer.playingStates[id], isTrue);
    await unmount(tester);
  });

  testWidgets('fullscreen enter and exit', (tester) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('fullscreen UI hides after 3s and tap brings it back', (
    tester,
  ) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Fire the 3s auto-hide timer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    // Tap the overlay to bring controls back.
    await tester.tapAt(const Offset(400, 1500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('timeline tap seeks', (tester) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    final id = env.videoPlayer.positions.keys.last;
    // The seek bar is the 32px-tall container inside the timeline gesture.
    final bar = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints == const BoxConstraints.tightFor(height: 32),
    );
    await tester.tapAt(tester.getCenter(bar));
    await tester.pump();
    expect(env.videoPlayer.positions[id]!.inMilliseconds, greaterThan(0));
    await unmount(tester);
  });

  testWidgets('save button hidden for guests', (tester) async {
    stubVideo();
    await pumpDetail(tester);
    expect(find.text('Save'), findsNothing);
    await unmount(tester);
  });

  testWidgets('save sheet lists playlists and selects one', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    stubVideo();
    stubCsrf();
    env.server.onGet(
      '/playlists/mine',
      (req) => FakeResponse.json({
        'playlists': [playlistJson(name: 'Favs')],
      }),
    );
    env.server.onPost(
      '/playlists/pl-1/items',
      (req) => const FakeResponse(200, '{}'),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Save to playlist'), findsOneWidget);
    expect(find.text('Favs'), findsOneWidget);
    await tester.tap(find.text('Favs'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(env.server.requestsTo('/playlists/pl-1/items'), isNotEmpty);
    expect(find.text('Saved to Favs'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('save sheet create flow makes playlist then adds item', (
    tester,
  ) async {
    MurrtubeApi.setCookies('session_id=abc');
    stubVideo();
    stubCsrf();
    env.server.onGet(
      '/playlists/mine',
      (req) => FakeResponse.json({
        'playlists': [playlistJson(id: 'pl-9', name: 'New List')],
      }),
    );
    env.server.onPost('/playlists', (req) => FakeResponse.json({'slug': 'nl'}));
    env.server.onPost(
      '/playlists/pl-9/items',
      (req) => const FakeResponse(200, '{}'),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Create new playlist'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'New List');
    await tester.tap(find.text('Unlisted'));
    await tester.pump();
    await tester.tap(find.text('Create & save'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.server.requestsTo('/playlists'), isNotEmpty);
    expect(env.server.requestsTo('/playlists/pl-9/items'), isNotEmpty);
    expect(find.text('Saved to New List'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('save sheet shows empty state', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    stubVideo();
    stubCsrf();
    env.server.onGet(
      '/playlists/mine',
      (req) => FakeResponse.json({'playlists': const []}),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('No playlists yet'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('save sheet load error shows empty state', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    stubVideo();
    stubCsrf();
    env.server.onGet(
      '/playlists/mine',
      (req) => const FakeResponse(500, 'err'),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('No playlists yet'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tag chip pushes search page', (tester) async {
    stubVideo();
    env.server.onGet(
      '/search',
      (req) => FakeResponse.inertia('Search', {
        'query': 'test',
        'media': const [],
        'users': const [],
        'tag_matches': const [],
        'pagination': paginationJson(),
      }),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('#test'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.server.requestsTo('/search'), isNotEmpty);
    await unmount(tester);
  });

  testWidgets('uploader row pushes profile page', (tester) async {
    stubVideo();
    env.server.onGet(
      '/test-user',
      (req) => FakeResponse.inertia('Profile', profileProps()),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('@test-user'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.server.requestsTo('/test-user'), isNotEmpty);
    await unmount(tester);
  });

  testWidgets('watch more card loads another video', (tester) async {
    stubVideo();
    env.server.onGet(
      '/v/B2',
      (req) => FakeResponse.inertia(
        'Video',
        videoProps(
          medium: mediaJson(id: 'm2', shortCode: 'B2', title: 'Second'),
        ),
      ),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('More'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(env.server.requestsTo('/v/B2'), isNotEmpty);
    await unmount(tester);
  });

  testWidgets('commentId expands comments and highlights target', (
    tester,
  ) async {
    stubVideo();
    await pumpDetail(tester, commentId: 'comment-1');
    expect(find.text('Nice video!', findRichText: true), findsOneWidget);
    // Let the 400ms scroll timer fire.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await unmount(tester);
  });

  testWidgets('creator badge and replies render', (tester) async {
    stubVideo(
      videoProps(
        comments: [
          commentJson(
            isCreator: true,
            replies: [commentJson(id: 'r1', body: 'a nested reply')],
          ),
        ],
      ),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    expect(find.text('CREATOR'), findsOneWidget);
    expect(find.text('a nested reply', findRichText: true), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('back button pops the page', (tester) async {
    stubVideo();
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VideoDetailPage(shortCode: 'ABC1'),
            ),
          ),
          child: const Text('open'),
        ),
      ),
      size: const Size(800, 3000),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new).first);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(VideoDetailPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('uploader tap pauses video and resumes after pop', (
    tester,
  ) async {
    stubVideo(
      videoProps(
        medium: mediaJson(
          hlsUrl: 'https://murrtube.net/v/abc.m3u8',
          user: userJson(avatarUrl: 'https://x/up.png'),
        ),
      ),
    );
    env.server.onGet(
      '/test-user',
      (req) => FakeResponse.inertia('Profile', profileProps()),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    final id = env.videoPlayer.playingStates.keys.last;
    expect(env.videoPlayer.playingStates[id], isTrue);
    await tester.tap(find.text('@test-user'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Pushing the profile paused the video.
    expect(env.videoPlayer.playingStates[id], isFalse);
    // Pop back to the video; resume runs in the .then continuation.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.videoPlayer.playingStates[id], isTrue);
    await awaitImages(tester);
    await unmount(tester);
  });

  testWidgets('tag chip tap pauses video and resumes after pop', (
    tester,
  ) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    env.server.onGet(
      '/search',
      (req) => FakeResponse.inertia('Search', {
        'query': 'test',
        'media': const [],
        'users': const [],
        'tag_matches': const [],
        'pagination': paginationJson(),
      }),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    final id = env.videoPlayer.playingStates.keys.last;
    await tester.tap(find.text('#test'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.videoPlayer.playingStates[id], isFalse);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.videoPlayer.playingStates[id], isTrue);
    await unmount(tester);
  });

  testWidgets('comment author name and avatar push profile then resume', (
    tester,
  ) async {
    stubVideo(
      videoProps(
        medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8'),
        comments: [
          commentJson(
            user: userJson(name: 'Commenter', avatarUrl: 'https://x/cav.png'),
          ),
        ],
      ),
    );
    env.server.onGet(
      '/test-user',
      (req) => FakeResponse.inertia('Profile', profileProps()),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    // Name tap pushes the profile.
    await tester.tap(find.text('Commenter'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.server.requestsTo('/test-user'), isNotEmpty);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Avatar tap pushes the profile too.
    await tester.tap(find.byType(ClipOval).last);
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.server.requestsTo('/test-user').length, greaterThan(1));
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await awaitImages(tester);
    await unmount(tester);
  });

  testWidgets('fullscreen controls: play pause, timeline drag, back, pop', (
    tester,
  ) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    final id = env.videoPlayer.playingStates.keys.last;
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Center play/pause toggle.
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(env.videoPlayer.playingStates[id], isFalse);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded).last);
    await tester.pump();
    expect(env.videoPlayer.playingStates[id], isTrue);
    // Timeline tap seeks through onTapDown.
    final bar = find.ancestor(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(bar);
    await tester.pump();
    // Timeline drag updates drag progress and seeks on release.
    final gesture = await tester.startGesture(tester.getCenter(bar));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(env.videoPlayer.positions[id]!.inMilliseconds, greaterThan(0));
    // Back arrow exits fullscreen.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    // Re-enter, then a system back exits fullscreen instead of popping.
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(find.byType(VideoDetailPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('fullscreen shows thumbnail while player not initialized', (
    tester,
  ) async {
    env.videoPlayer.emitInitialized = false;
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await awaitImages(tester);
    await unmount(tester);
  });

  testWidgets('portrait video locks portrait in fullscreen', (tester) async {
    env.videoPlayer.videoSize = const Size(720, 1280);
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('hour-long duration renders h:mm:ss', (tester) async {
    env.videoPlayer.videoDuration = const Duration(
      hours: 1,
      minutes: 2,
      seconds: 5,
    );
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('01:02:05'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('timeline drag shows drag position and seeks', (tester) async {
    stubVideo(
      videoProps(medium: mediaJson(hlsUrl: 'https://murrtube.net/v/abc.m3u8')),
    );
    await pumpDetail(tester);
    await settleAsync(tester);
    await tester.pump();
    final bar = find.ancestor(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(GestureDetector),
    );
    final gesture = await tester.startGesture(tester.getCenter(bar));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    // A vertical move hands the gesture to the scroller, cancelling the
    // horizontal drag.
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await unmount(tester);
  });

  testWidgets('comment field keyboard submit posts', (tester) async {
    stubVideo();
    stubCsrf();
    env.server.onPost('/comments', (req) => const FakeResponse(200, '{}'));
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'via keyboard');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    final posts = env.server.requests.where(
      (r) => r.method == 'POST' && r.uri.path == '/comments',
    );
    expect(posts, isNotEmpty);
    expect(posts.first.body, contains('via+keyboard'));
    await unmount(tester);
  });

  testWidgets('posting comment shows spinner while in flight', (tester) async {
    stubVideo();
    stubCsrf();
    final gate = Completer<FakeResponse>();
    env.server.onPost('/comments', (req) => gate.future);
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'slow post');
    await tester.tap(find.byIcon(Icons.send).first);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.complete(const FakeResponse(200, '{}'));
    await settleAsync(tester);
    await tester.pump();
    await unmount(tester);
  });

  testWidgets('reply keyboard submit posts and shows spinner', (tester) async {
    stubVideo();
    stubCsrf();
    final gate = Completer<FakeResponse>();
    env.server.onPost('/comments', (req) => gate.future);
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.tap(find.text('Reply'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'reply text');
    await tester.pump();
    // Send while the post is gated so the reply spinner builds.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump();
    gate.complete(const FakeResponse(200, '{}'));
    await settleAsync(tester);
    await tester.pump();
    final posts = env.server.requests.where(
      (r) => r.method == 'POST' && r.uri.path == '/comments',
    );
    expect(posts.first.body, contains('parent_id'));
    await unmount(tester);
  });

  testWidgets('reply failure shows snackbar', (tester) async {
    stubVideo();
    stubCsrf();
    env.server.onPost('/comments', (req) => const FakeResponse(500, 'err'));
    await pumpDetail(tester);
    await tester.tap(find.text('13 Comments'));
    await tester.pump();
    await tester.tap(find.text('Reply'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'doomed');
    await tester.tap(find.byIcon(Icons.send).last);
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Failed to post reply'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('create flow falls back to first playlist when name missing', (
    tester,
  ) async {
    MurrtubeApi.setCookies('session_id=abc');
    stubVideo();
    stubCsrf();
    env.server.onGet(
      '/playlists/mine',
      (req) => FakeResponse.json({
        'playlists': [playlistJson(id: 'pl-9', name: 'Other')],
      }),
    );
    env.server.onPost('/playlists', (req) => FakeResponse.json({'slug': 'x'}));
    env.server.onPost(
      '/playlists/pl-9/items',
      (req) => const FakeResponse(200, '{}'),
    );
    await pumpDetail(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Create new playlist'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Brand New');
    await tester.tap(find.text('Public'));
    await tester.pump();
    await tester.tap(find.text('Private'));
    await tester.pump();
    await tester.tap(find.text('Create & save'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // getMyPlaylists returned no 'Brand New', so the first playlist got it.
    expect(env.server.requestsTo('/playlists/pl-9/items'), isNotEmpty);
    await unmount(tester);
  });

  testWidgets('tag edit sheet opens and saves new tag list', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    stubVideo();
    stubCsrf();
    env.server.onPost(
      '/tag_edits',
      (req) => FakeResponse.json({
        'tags': [
          {'name': 'test', 'category': 'general', 'count': 10},
          {'name': 'newtag', 'category': 'general', 'count': 1},
        ],
      }),
    );
    env.server.onGet(
      '/search/suggest',
      (req) => FakeResponse.json({'users': [], 'tags': []}),
    );
    await pumpDetail(tester);
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Edit Tags'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'newtag');
    await tester.pump(const Duration(milliseconds: 400));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.tap(find.text('Save').last);
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.server.requestsTo('/tag_edits'), isNotEmpty);
    expect(find.text('#newtag'), findsWidgets);
    await unmount(tester);
  });
}
