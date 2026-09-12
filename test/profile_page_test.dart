import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murrmobile/pages/profile_page.dart';
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

  void stubProfile([Map<String, dynamic>? props]) {
    env.server.onGet(
      '/test-user',
      (req) => FakeResponse.inertia('Profile', props ?? profileProps()),
    );
  }

  testWidgets('loads profile with stats and tabs', (tester) async {
    stubProfile();
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Test User'), findsWidgets);
    expect(find.text('@test-user'), findsOneWidget);
    expect(find.text('Videos'), findsWidgets);
    expect(find.text('Subscribers'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Test Video'), findsOneWidget);
    // Subscribe buttons hidden for guests.
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Block'), findsNothing);
  });

  testWidgets('user not found on missing profile', (tester) async {
    env.server.onGet('/ghost', (req) => const FakeResponse(404, 'no'));
    await pumpApp(tester, const ProfilePage(slug: 'ghost'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('User not found'), findsOneWidget);
  });

  testWidgets('empty videos tab shows message', (tester) async {
    stubProfile(profileProps(media: const []));
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('No videos yet'), findsOneWidget);
  });

  testWidgets('bio and social links render', (tester) async {
    stubProfile(
      profileProps(
        profile: richProfileJson(
          bio: 'Hello world',
          socialMedia: {
            'gitlab': 'https://gitlab.com/x',
            'twitter': 'https://x.com/x',
            'furaffinity': 'https://fa.net/x',
            'patreon': 'https://pa.com/x',
            'kofi': 'https://ko.com/x',
            'bluesky': 'https://bs.com/x',
            'onlyfans': 'https://of.com/x',
          },
        ),
      ),
    );
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Hello world'), findsOneWidget);
    expect(find.text('GitLab'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);
    expect(find.text('FurAffinity'), findsOneWidget);
    expect(find.text('Patreon'), findsOneWidget);
    expect(find.text('Ko-fi'), findsOneWidget);
    expect(find.text('Bluesky'), findsOneWidget);
    expect(find.text('OnlyFans'), findsOneWidget);
  });

  testWidgets('telegram link row renders', (tester) async {
    stubProfile(
      profileProps(
        profile: richProfileJson(socialMedia: {'telegram': 'https://t.me/x'}),
      ),
    );
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Telegram'), findsOneWidget);
    await tester.tap(find.text('Telegram'));
    await tester.pump();
  });

  testWidgets('tab badges show counts', (tester) async {
    stubProfile(
      profileProps(
        tabCounts: {
          'videos': 1200,
          'likes': 2500000,
          'playlists': 3,
          'subscribers': 5,
          'subscriptions': 2,
        },
      ),
    );
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Videos 1.2K'), findsOneWidget);
    expect(find.text('Likes 2.5M'), findsOneWidget);
    expect(find.text('Playlists 3'), findsOneWidget);
  });

  testWidgets('switching to likes tab refetches with tab param', (
    tester,
  ) async {
    env.server.onGet(
      '/test-user',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          media: [mediaJson(title: 'Liked Vid', shortCode: 'LK1')],
        ),
      ),
      matchQuery: (uri) => uri.queryParameters['tab'] == 'likes',
    );
    stubProfile();
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.textContaining('Likes'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Liked Vid'), findsOneWidget);
    expect(
      env.server.requests.where((r) => r.uri.queryParameters['tab'] == 'likes'),
      isNotEmpty,
    );
  });

  testWidgets('playlists tab lists playlists and pushes playlist page', (
    tester,
  ) async {
    env.server.onGet(
      '/test-user',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          playlists: [playlistJson(name: 'Favs', itemsCount: 7)],
          media: const [],
        ),
      ),
      matchQuery: (uri) => uri.queryParameters['tab'] == 'playlists',
    );
    stubProfile();
    env.server.onGet(
      '/test-user/p/my-playlist',
      (req) => FakeResponse.inertia('Playlist', {
        'playlist': playlistJson(),
        'items': const [],
        'pagination': paginationJson(),
      }),
    );
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.textContaining('Playlists'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Favs'), findsOneWidget);
    expect(find.text('public · 7 items'), findsOneWidget);
    await tester.tap(find.text('Favs'));
    await tester.pump();
    await settleAsync(tester);
    expect(env.server.requestsTo('/test-user/p/my-playlist'), isNotEmpty);
  });

  testWidgets('empty playlists tab shows message', (tester) async {
    env.server.onGet(
      '/test-user',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(playlists: const [], media: const []),
      ),
      matchQuery: (uri) => uri.queryParameters['tab'] == 'playlists',
    );
    stubProfile();
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.textContaining('Playlists'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('No playlists yet'), findsOneWidget);
  });

  testWidgets('authed user sees subscribe and block buttons', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    stubProfile(profileProps(profile: richProfileJson(slug: 'other')));
    env.server.onGet(
      '/other',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          profile: richProfileJson(slug: 'other', name: 'Other'),
        ),
      ),
    );
    await pumpApp(tester, const ProfilePage(slug: 'other'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
  });

  testWidgets('subscribe calls follow endpoint', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    env.server.onGet(
      '/other',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          profile: richProfileJson(slug: 'other', name: 'Other'),
        ),
      ),
    );
    env.server.onGet('/', (req) => FakeResponse.htmlPage());
    env.server.onPost(
      '/users/other/follow',
      (req) => const FakeResponse(200, '{}'),
    );
    await pumpApp(tester, const ProfilePage(slug: 'other'));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.text('Subscribe'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Subscribed'), findsOneWidget);
    expect(env.server.requestsTo('/users/other/follow'), isNotEmpty);
  });

  testWidgets('subscribe failure reverts state', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    env.server.onGet(
      '/other',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          profile: richProfileJson(slug: 'other', name: 'Other'),
        ),
      ),
    );
    env.server.onGet('/', (req) => FakeResponse.htmlPage());
    env.server.onPost(
      '/users/other/follow',
      (req) => const FakeResponse(500, 'err'),
    );
    await pumpApp(tester, const ProfilePage(slug: 'other'));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.text('Subscribe'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets('unsubscribe calls unfollow endpoint', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    env.server.onGet(
      '/other',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          profile: richProfileJson(slug: 'other', name: 'Other'),
          isSubscribed: true,
        ),
      ),
    );
    env.server.onGet('/', (req) => FakeResponse.htmlPage());
    env.server.onPost(
      '/users/other/unfollow',
      (req) => const FakeResponse(200, '{}'),
    );
    await pumpApp(tester, const ProfilePage(slug: 'other'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Subscribed'), findsOneWidget);
    await tester.tap(find.text('Subscribed'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Subscribe'), findsOneWidget);
    expect(env.server.requestsTo('/users/other/unfollow'), isNotEmpty);
  });

  testWidgets('block calls block endpoint and toggles label', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    env.server.onGet(
      '/other',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          profile: richProfileJson(slug: 'other', name: 'Other'),
        ),
      ),
    );
    env.server.onGet('/', (req) => FakeResponse.htmlPage());
    env.server.onPut(
      '/users/other/block',
      (req) => const FakeResponse(200, '{}'),
    );
    await pumpApp(tester, const ProfilePage(slug: 'other'));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.text('Block'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Unblock'), findsOneWidget);
    expect(env.server.requestsTo('/users/other/block'), isNotEmpty);
  });

  testWidgets('block failure reverts and shows snackbar', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    env.server.onGet(
      '/other',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          profile: richProfileJson(slug: 'other', name: 'Other'),
        ),
      ),
    );
    env.server.onGet('/', (req) => FakeResponse.htmlPage());
    env.server.onPut(
      '/users/other/block',
      (req) => const FakeResponse(500, 'err'),
    );
    await pumpApp(tester, const ProfilePage(slug: 'other'));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.text('Block'));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('Failed to update block status'), findsOneWidget);
  });

  testWidgets('self profile hides subscribe/block', (tester) async {
    MurrtubeApi.setCookies('session_id=abc');
    env.server.onGet(
      '/me',
      (req) => FakeResponse.inertia(
        'Profile',
        profileProps(
          profile: richProfileJson(slug: 'me', name: 'Me'),
          viewingSelf: true,
          currentUser: userJson(slug: 'me'),
        ),
      ),
    );
    await pumpApp(tester, const ProfilePage(slug: 'me'));
    await settleAsync(tester);
    await tester.pump();
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Block'), findsNothing);
    expect(MurrtubeApi.currentUserSlug, 'me');
  });

  testWidgets('tapping a video card pushes detail page', (tester) async {
    stubProfile();
    env.server.onGet(
      RegExp(r'/v/'),
      (req) => FakeResponse.inertia('Video', videoProps()),
    );
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    await tester.tap(find.text('Test Video'));
    await tester.pump();
    await settleAsync(tester);
    expect(env.server.requestsTo('/v/ABC1'), isNotEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  });

  testWidgets('fromRoot hides back button', (tester) async {
    stubProfile();
    await pumpApp(tester, const ProfilePage(slug: 'test-user', fromRoot: true));
    await settleAsync(tester);
    await tester.pump();
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });

  testWidgets('back button pops when not fromRoot', (tester) async {
    stubProfile();
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProfilePage(slug: 'test-user'),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await settleAsync(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ProfilePage), findsNothing);
  });

  testWidgets('avatar image rendered when avatarUrl present', (tester) async {
    stubProfile(
      profileProps(profile: richProfileJson(avatarUrl: 'https://x/av.png')),
    );
    await pumpApp(tester, const ProfilePage(slug: 'test-user'));
    await settleAsync(tester);
    await tester.pump();
    // The 96px avatar ClipOval contains a CachedNetworkImage.
    expect(find.byType(ClipOval), findsWidgets);
  });
}
