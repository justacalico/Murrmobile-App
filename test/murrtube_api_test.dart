import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murrmobile/services/murrtube_api.dart';

import 'support/fake_http.dart';
import 'support/fixtures.dart';

void main() {
  late FakeServer server;

  setUp(() {
    MurrtubeApi.clearCookies();
    server = installFakeHttp();
  });

  FakeResponse homeJson({dynamic next}) => FakeResponse.inertia('Home', {
    'media': [mediaJson()],
    'pagination': paginationJson(next: next),
    'announcements': [announcementJson()],
    'tab': 'trending',
    'current_user': userJson(slug: 'viewer'),
  });

  /// Registers the common "root HTML + inertia JSON" routes used by most
  /// endpoints. The root HTML carries the CSRF token the mutation helpers need.
  void stubRoot({String? inertiaVersion}) {
    server.onGet(
      '/',
      (req) => FakeResponse.htmlPage(inertiaVersion: inertiaVersion),
      matchQuery: (uri) => !uri.queryParameters.containsKey('tab'),
    );
    server.onGet(
      '/',
      (req) => homeJson(),
      matchQuery: (uri) => uri.queryParameters.containsKey('tab'),
    );
  }

  group('cookie state', () {
    test('hasCookies and isAuthenticated reflect jar contents', () {
      expect(MurrtubeApi.hasCookies, isFalse);
      expect(MurrtubeApi.isAuthenticated, isFalse);

      MurrtubeApi.setCookies('a=1; session_id=abc');
      expect(MurrtubeApi.hasCookies, isTrue);
      expect(MurrtubeApi.isAuthenticated, isTrue);

      MurrtubeApi.clearCookies();
      expect(MurrtubeApi.hasCookies, isFalse);
      expect(MurrtubeApi.isAuthenticated, isFalse);
      expect(MurrtubeApi.currentUserSlug, isNull);
    });

    test('set-cookie response headers merge into the jar', () async {
      server.onGet(
        '/',
        (req) => FakeResponse.inertia(
          'Home',
          {
            'media': const [],
            'pagination': paginationJson(),
            'announcements': const [],
          },
          headers: {
            'set-cookie': ['session_id=xyz; Path=/'],
          },
        ),
        matchQuery: (uri) => uri.queryParameters['page'] == '2',
      );
      server.onGet(
        '/',
        (req) => homeJson(),
        matchQuery: (uri) => uri.queryParameters.containsKey('tab'),
      );
      await MurrtubeApi.getHome();
      expect(MurrtubeApi.hasCookies, isFalse);

      await MurrtubeApi.getHome(page: 2);
      expect(MurrtubeApi.isAuthenticated, isTrue);
    });
  });

  group('_get retry logic', () {
    test('parses JSON on first try when it is JSON', () async {
      stubRoot();
      final result = await MurrtubeApi.getHome();
      expect(result.media.single.title, 'Test Video');
      expect(result.tab, 'trending');
      expect(result.currentUser!.slug, 'viewer');
      expect(MurrtubeApi.currentUserSlug, 'viewer');
      expect(result.announcements.single.title, 'Announcement');
      // Exactly one request, no retry.
      expect(server.requests.length, 1);
      expect(server.requests.single.uri.path, '/');
      expect(server.requests.single.uri.queryParameters['tab'], 'trending');
      expect(server.requests.single.header('x-inertia'), 'true');
    });

    test('page 2 appends page param', () async {
      stubRoot();
      await MurrtubeApi.getHome(page: 2);
      expect(server.requests.single.uri.queryParameters['page'], '2');
    });

    test('retries after 409 by extracting version from root HTML', () async {
      var attempts = 0;
      server.onGet('/', (req) {
        attempts++;
        return FakeResponse.htmlPage(inertiaVersion: 'v99');
      }, matchQuery: (uri) => !uri.queryParameters.containsKey('tab'));
      server.onGet('/', (req) {
        attempts++;
        return attempts <= 1 ? const FakeResponse(409, '') : homeJson();
      }, matchQuery: (uri) => uri.queryParameters.containsKey('tab'));

      final result = await MurrtubeApi.getHome();
      expect(result.media, isNotEmpty);
      final tabRequests = server.requests
          .where((r) => r.uri.queryParameters.containsKey('tab'))
          .toList();
      expect(tabRequests.length, 2);
      expect(tabRequests.last.header('x-inertia-version'), 'v99');
    });

    test('retries when body is HTML and extracts version from it', () async {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return const FakeResponse(
            200,
            '<html><script>window.__inertia = {"version":"w9"}</script></html>',
          );
        }
        return homeJson();
      });
      final result = await MurrtubeApi.getHome();
      expect(result.media, isNotEmpty);
      expect(server.requests.last.header('x-inertia-version'), 'w9');
    });

    test('extracts version from data-page attribute', () async {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return const FakeResponse(
            200,
            '<div data-page="{&quot;version&quot;:&quot;dp1&quot;}"></div>',
          );
        }
        return homeJson();
      });
      await MurrtubeApi.getHome();
      expect(server.requests.last.header('x-inertia-version'), 'dp1');
    });

    test('extracts version from single-quoted data-page attribute', () async {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return const FakeResponse(
            200,
            "<div data-page='{&quot;version&quot;:&quot;dp2&quot;}'></div>",
          );
        }
        return homeJson();
      });
      await MurrtubeApi.getHome();
      expect(server.requests.last.header('x-inertia-version'), 'dp2');
    });

    test('extracts version from &quot; escaped json', () async {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return const FakeResponse(
            200,
            '<div>&quot;version&quot;:&quot;qq5&quot;</div>',
          );
        }
        return homeJson();
      });
      await MurrtubeApi.getHome();
      expect(server.requests.last.header('x-inertia-version'), 'qq5');
    });

    test('falls back to version 1 when nothing is found', () async {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return const FakeResponse(200, '<html><body>nothing</body></html>');
        }
        return homeJson();
      });
      await MurrtubeApi.getHome();
      expect(server.requests.last.header('x-inertia-version'), '1');
    });

    test(
      'performs age-check POST when HTML contains an age check form',
      () async {
        var first = true;
        server.onGet('/', (req) {
          if (first) {
            first = false;
            return FakeResponse.htmlPage(ageCheck: true);
          }
          return homeJson();
        });
        server.onPost('/age_check', (req) => const FakeResponse(302, ''));
        await MurrtubeApi.getHome();
        expect(server.requestsTo('/age_check'), isNotEmpty);
        expect(server.requestsTo('/age_check').single.method, 'POST');
        expect(
          server
              .requestsTo('/age_check')
              .single
              .body
              .contains('authenticity_token'),
          isTrue,
        );
      },
    );

    test('uses absolute age-check action URLs', () async {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return const FakeResponse(
            200,
            '<html><head>'
            '<meta name="csrf-token" content="tok"></head>'
            '<body><form action="https://murrtube.net/age_check_now">'
            '</form></body></html>',
          );
        }
        return homeJson();
      });
      server.onPost('/age_check_now', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.getHome();
      expect(server.requestsTo('/age_check_now'), isNotEmpty);
    });

    test('skips age-check POST when no csrf token exists', () async {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return const FakeResponse(
            200,
            '<html><body>age_check <form action="/age_check"></form></body></html>',
          );
        }
        return homeJson();
      });
      await MurrtubeApi.getHome();
      expect(server.requestsTo('/age_check'), isEmpty);
    });

    test('uses default /age_check path when form has no action', () async {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return const FakeResponse(
            200,
            '<html><head><meta name="csrf-token" content="t"></head>'
            '<body>age_check</body></html>',
          );
        }
        return homeJson();
      });
      await MurrtubeApi.getHome();
      expect(server.requestsTo('/age_check'), isNotEmpty);
    });

    test('throws HttpException when retry status is not 200', () async {
      server.onGet('/', (req) => const FakeResponse(500, 'nope'));
      expect(() => MurrtubeApi.getHome(), throwsA(isA<HttpException>()));
    });

    test('throws FormatException when retry still returns HTML', () async {
      server.onGet('/', (req) => const FakeResponse(200, '<html></html>'));
      expect(() => MurrtubeApi.getHome(), throwsA(isA<FormatException>()));
    });
  });

  group('endpoint parsing', () {
    test('getVideo parses medium, comments, watch_more', () async {
      server.onGet(
        '/v/ABC1',
        (req) => FakeResponse.inertia('Video', {
          'medium': mediaJson(shortCode: 'ABC1', hlsUrl: 'https://x/v.m3u8'),
          'comments': [commentJson()],
          'comments_pagination': paginationJson(),
          'watch_more': [mediaJson(id: 'm2', shortCode: 'DEF2')],
          'viewer_can_comment': true,
          'viewer_can_like': true,
        }),
      );
      final result = await MurrtubeApi.getVideo('ABC1');
      expect(result.medium.shortCode, 'ABC1');
      expect(result.comments.single.body, 'Nice video!');
      expect(result.watchMore.single.shortCode, 'DEF2');
      expect(result.viewerCanComment, isTrue);
      expect(result.viewerCanLike, isTrue);
    });

    test('getVideo handles missing optional props', () async {
      server.onGet(
        '/v/NIL',
        (req) => FakeResponse.inertia('Video', {
          'medium': mediaJson(),
          'comments': const [],
          'comments_pagination': paginationJson(),
        }),
      );
      final result = await MurrtubeApi.getVideo('NIL');
      expect(result.watchMore, isEmpty);
      expect(result.viewerCanComment, isFalse);
      expect(result.viewerCanLike, isFalse);
    });

    test('search parses media, users, and tag matches', () async {
      server.onGet(
        '/search',
        (req) => FakeResponse.inertia('Search', {
          'query': req.uri.queryParameters['q'],
          'media': [mediaJson()],
          'users': [userJson(slug: 'found')],
          'tag_matches': [tagJson(name: 'cat')],
          'pagination': paginationJson(),
        }),
      );
      final result = await MurrtubeApi.search(query: 'test query');
      expect(result.query, 'test query');
      expect(result.users.single.slug, 'found');
      expect(result.tagMatches.single.name, 'cat');
      expect(server.requests.single.uri.query, contains('q=test%20query'));
    });

    test('search tolerates missing users and tag_matches', () async {
      server.onGet(
        '/search',
        (req) => FakeResponse.inertia('Search', {
          'media': const [],
          'pagination': paginationJson(),
        }),
      );
      final result = await MurrtubeApi.search();
      expect(result.users, isEmpty);
      expect(result.tagMatches, isEmpty);
    });

    test('searchSuggest parses users and tags', () async {
      server.onGet(
        '/search/suggest',
        (req) => FakeResponse.json({
          'query': 'cat',
          'users': [
            {'slug': 'cathy', 'name': 'Cathy', 'avatar_url': null},
          ],
          'tags': [
            {'name': 'cat', 'category': 'general', 'count': 5},
          ],
        }),
      );
      final result = await MurrtubeApi.searchSuggest('cat');
      expect(result.users.single.slug, 'cathy');
      expect(result.tags.single.name, 'cat');
    });

    test('searchSuggest handles empty lists', () async {
      server.onGet('/search/suggest', (req) => FakeResponse.json({}));
      final result = await MurrtubeApi.searchSuggest('x');
      expect(result.users, isEmpty);
      expect(result.tags, isEmpty);
      expect(result.query, isNull);
    });

    test('getNotifications parses items and display_cap', () async {
      server.onGet(
        '/notifications',
        (req) => FakeResponse.inertia('Notifs', {
          'items': [notificationJson()],
          'display_cap': 50,
        }),
      );
      final result = await MurrtubeApi.getNotifications();
      expect(result.items.single.type, 'comment.created');
      expect(result.displayCap, 50);
    });

    test('getUserProfile parses full profile', () async {
      server.onGet(
        '/someone',
        (req) => FakeResponse.inertia('Profile', {
          'profile': {
            ...userJson(slug: 'someone', name: 'Someone'),
            'bio': 'hello',
            'subscribers_count': 12,
            'social_media': {
              'telegram': 'https://t.me/x',
              'gitlab': 'https://gitlab.com/x',
              'twitter': 'https://x.com/x',
              'furaffinity': 'https://fa.net/x',
              'patreon': 'https://patreon.com/x',
              'kofi': 'https://ko-fi.com/x',
              'bluesky': 'https://bsky.app/x',
              'onlyfans': 'https://of.com/x',
            },
          },
          'media': [mediaJson()],
          'pagination': paginationJson(),
          'playlists': [playlistJson()],
          'is_subscribed': true,
          'is_blocked': true,
          'viewing_self': false,
          'current_user': userJson(slug: 'viewer'),
          'tab_counts': {'videos': 3, 'subscribers': 7},
        }),
      );
      final result = await MurrtubeApi.getUserProfile('someone');
      expect(result.user.slug, 'someone');
      expect(result.bio, 'hello');
      expect(result.isSubscribed, isTrue);
      expect(result.isBlocked, isTrue);
      expect(result.subscribersCount, 7);
      expect(result.subscriptionsCount, isNull);
      expect(result.telegramUrl, 'https://t.me/x');
      expect(result.gitlabUrl, 'https://gitlab.com/x');
      expect(result.twitterUrl, 'https://x.com/x');
      expect(result.furaffinityUrl, 'https://fa.net/x');
      expect(result.patreonUrl, 'https://patreon.com/x');
      expect(result.kofiUrl, 'https://ko-fi.com/x');
      expect(result.blueskyUrl, 'https://bsky.app/x');
      expect(result.onlyfansUrl, 'https://of.com/x');
      expect(result.tabCounts['videos'], 3);
      expect(result.currentUser!.slug, 'viewer');
      expect(result.playlists.single.name, 'My Playlist');
    });

    test('getUserProfile uses tab and page params', () async {
      server.onGet(
        '/u',
        (req) => FakeResponse.inertia('Profile', {
          'profile': userJson(slug: 'u'),
          'media': const [],
          'playlists': const [],
        }),
      );
      await MurrtubeApi.getUserProfile('u', tab: 'likes', page: 3);
      expect(server.requests.single.uri.queryParameters['tab'], 'likes');
      expect(server.requests.single.uri.queryParameters['page'], '3');
    });

    test('getUserProfile builds default pagination when missing', () async {
      server.onGet(
        '/u',
        (req) => FakeResponse.inertia('Profile', {
          'profile': userJson(slug: 'u'),
          'media': [mediaJson(), mediaJson(id: 'm2')],
        }),
      );
      final result = await MurrtubeApi.getUserProfile('u');
      expect(result.pagination.count, 2);
      expect(result.isSelf, isFalse);
    });

    test('getUserProfile sets slug for self-view', () async {
      server.onGet(
        '/me',
        (req) => FakeResponse.inertia('Profile', {
          'profile': userJson(slug: 'me'),
          'viewing_self': true,
        }),
      );
      await MurrtubeApi.getUserProfile('me');
      expect(MurrtubeApi.currentUserSlug, 'me');
    });

    test('getUserProfile throws when profile missing', () async {
      server.onGet(
        '/ghost',
        (req) => FakeResponse.inertia('Profile', {'profile': null}),
      );
      expect(
        () => MurrtubeApi.getUserProfile('ghost'),
        throwsA(isA<Exception>()),
      );
    });

    test('getSettings/getUpload/about pages return props', () async {
      server.onGet(
        '/settings',
        (req) => FakeResponse.inertia('Settings', {'user': userJson()}),
      );
      server.onGet(
        '/upload',
        (req) => FakeResponse.inertia('Upload', {
          'visibilities': ['public'],
        }),
      );
      server.onGet(
        '/about/terms',
        (req) => FakeResponse.inertia('T', {'effective_date': 'x'}),
      );
      server.onGet(
        '/about/privacy',
        (req) => FakeResponse.inertia('P', {'effective_date': 'y'}),
      );
      server.onGet(
        '/about/cookies',
        (req) => FakeResponse.inertia('C', {'effective_date': 'z'}),
      );
      server.onGet(
        '/about/whats-new',
        (req) => FakeResponse.inertia('W', {'effective_date': 'w'}),
      );

      expect((await MurrtubeApi.getSettings())['user'], isNotNull);
      expect((await MurrtubeApi.getUpload())['visibilities'], isNotEmpty);
      expect((await MurrtubeApi.getTerms())['effective_date'], 'x');
      expect((await MurrtubeApi.getPrivacy())['effective_date'], 'y');
      expect((await MurrtubeApi.getCookies())['effective_date'], 'z');
      expect((await MurrtubeApi.getWhatsNew())['effective_date'], 'w');
    });

    test('getPlaylist parses playlist, items, user, ownership', () async {
      server.onGet(
        '/u/p/list',
        (req) => FakeResponse.inertia('Playlist', {
          'playlist': playlistJson(slug: 'list'),
          'items': [mediaJson()],
          'pagination': paginationJson(),
          'user': userJson(slug: 'u'),
          'is_owner': true,
        }),
      );
      final result = await MurrtubeApi.getPlaylist('u', 'list');
      expect(result.playlist.slug, 'list');
      expect(result.media, hasLength(1));
      expect(result.user!.slug, 'u');
      expect(result.isOwner, isTrue);
    });

    test(
      'getPlaylist handles missing optional fields and page param',
      () async {
        server.onGet(
          '/u/p/empty',
          (req) =>
              FakeResponse.inertia('Playlist', {'playlist': playlistJson()}),
        );
        final result = await MurrtubeApi.getPlaylist('u', 'empty', page: 2);
        expect(result.media, isEmpty);
        expect(result.user, isNull);
        expect(result.isOwner, isFalse);
        expect(server.requests.single.uri.queryParameters['page'], '2');
      },
    );
  });

  group('mutations', () {
    void stubCsrf() {
      server.onGet(
        '/',
        (req) => FakeResponse.htmlPage(),
        matchQuery: (uri) => uri.query.isEmpty,
      );
    }

    test('blockUser sends PUT with csrf header', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onPut('/users/x/block', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.blockUser('x');
      final req = server.requestsTo('/users/x/block').single;
      expect(req.method, 'PUT');
      expect(req.header('x-csrf-token'), 'fake-csrf-token-123');
      expect(req.header('cookie'), contains('session_id=abc'));
    });

    test('unblockUser sends PUT', () async {
      stubCsrf();
      server.onPut('/users/x/unblock', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.unblockUser('x');
      expect(server.requestsTo('/users/x/unblock'), isNotEmpty);
    });

    test('subscribeToUser posts follow', () async {
      stubCsrf();
      server.onPost('/users/x/follow', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.subscribeToUser('x');
      expect(server.requestsTo('/users/x/follow'), isNotEmpty);
    });

    test('unsubscribeFromUser posts unfollow', () async {
      stubCsrf();
      server.onPost('/users/x/unfollow', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.unsubscribeFromUser('x');
      expect(server.requestsTo('/users/x/unfollow'), isNotEmpty);
    });

    test('likeVideo posts medium id', () async {
      stubCsrf();
      server.onPost('/likes', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.likeVideo('m1');
      expect(server.requestsTo('/likes').single.body, contains('m1'));
    });

    test('unlikeVideo sends DELETE', () async {
      stubCsrf();
      server.onDelete('/likes/m1', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.unlikeVideo('m1');
      expect(server.requestsTo('/likes/m1').single.method, 'DELETE');
    });

    test('postComment posts body', () async {
      stubCsrf();
      server.onPost('/comments', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.postComment(mediumId: 'm1', body: 'hi');
      final body = server.requestsTo('/comments').single.body;
      expect(body, contains('comment%5Bmedium_id%5D=m1'));
      expect(body, contains('comment%5Bbody%5D=hi'));
    });

    test('replyToComment posts parent id', () async {
      stubCsrf();
      server.onPost('/comments', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.replyToComment(
        mediumId: 'm1',
        parentId: 'c9',
        body: 're',
      );
      expect(
        server.requestsTo('/comments').single.body,
        contains('parent_id%5D=c9'),
      );
    });

    test('deleteComment sends DELETE', () async {
      stubCsrf();
      server.onDelete('/comments/c9', (req) => const FakeResponse(200, ''));
      await MurrtubeApi.deleteComment('c9');
      expect(server.requestsTo('/comments/c9').single.method, 'DELETE');
    });

    test('mutation failures throw HttpException', () async {
      stubCsrf();
      server.onPut('/users/x/block', (req) => const FakeResponse(500, ''));
      server.onPost('/users/x/follow', (req) => const FakeResponse(500, ''));
      server.onPost('/users/x/unfollow', (req) => const FakeResponse(500, ''));
      server.onPost('/likes', (req) => const FakeResponse(500, ''));
      server.onDelete('/likes/m1', (req) => const FakeResponse(500, ''));
      server.onPost('/comments', (req) => const FakeResponse(500, ''));
      server.onDelete('/comments/c9', (req) => const FakeResponse(500, ''));

      expect(() => MurrtubeApi.blockUser('x'), throwsA(isA<HttpException>()));
      expect(() => MurrtubeApi.unblockUser('x'), throwsA(isA<HttpException>()));
      expect(
        () => MurrtubeApi.subscribeToUser('x'),
        throwsA(isA<HttpException>()),
      );
      expect(
        () => MurrtubeApi.unsubscribeFromUser('x'),
        throwsA(isA<HttpException>()),
      );
      expect(() => MurrtubeApi.likeVideo('m1'), throwsA(isA<HttpException>()));
      expect(
        () => MurrtubeApi.unlikeVideo('m1'),
        throwsA(isA<HttpException>()),
      );
      expect(
        () => MurrtubeApi.postComment(mediumId: 'm', body: 'b'),
        throwsA(isA<HttpException>()),
      );
      expect(
        () => MurrtubeApi.deleteComment('c9'),
        throwsA(isA<HttpException>()),
      );
      expect(
        () =>
            MurrtubeApi.replyToComment(mediumId: 'm', parentId: 'p', body: 'b'),
        throwsA(isA<HttpException>()),
      );
    });

    test('mutations throw when csrf token missing', () async {
      server.onGet('/', (req) => const FakeResponse(200, '<html></html>'));
      expect(() => MurrtubeApi.blockUser('x'), throwsA(isA<Exception>()));
    });

    test('getMyPlaylists parses playlist list', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onGet(
        '/playlists/mine',
        (req) => FakeResponse.json({
          'playlists': [playlistJson(), playlistJson(id: 'p2', name: 'Two')],
        }),
      );
      final lists = await MurrtubeApi.getMyPlaylists();
      expect(lists, hasLength(2));
      expect(lists.last.name, 'Two');
    });

    test('getMyPlaylists throws on failure', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onGet('/playlists/mine', (req) => const FakeResponse(500, ''));
      expect(() => MurrtubeApi.getMyPlaylists(), throwsA(isA<HttpException>()));
    });

    test('createPlaylist posts multipart fields', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onPost('/playlists', (req) => FakeResponse.json({'slug': 'new'}));
      final playlist = await MurrtubeApi.createPlaylist(
        name: 'New List',
        description: 'desc',
        visibility: 'private',
      );
      expect(playlist.slug, 'new');
      expect(playlist.name, 'New List');
      final body = server.requestsTo('/playlists').single.body;
      expect(body, contains('playlist[name]'));
      expect(body, contains('New List'));
      expect(body, contains('desc'));
    });

    test('createPlaylist works without description', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onPost('/playlists', (req) => FakeResponse.json({'slug': 's'}));
      final playlist = await MurrtubeApi.createPlaylist(
        name: 'N',
        visibility: 'public',
      );
      expect(playlist.visibility, 'public');
    });

    test('createPlaylist throws on failure', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onPost('/playlists', (req) => const FakeResponse(500, ''));
      expect(
        () => MurrtubeApi.createPlaylist(name: 'N', visibility: 'public'),
        throwsA(isA<HttpException>()),
      );
    });

    test('addToPlaylist posts multipart fields', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onPost(
        '/playlists/p1/items',
        (req) => const FakeResponse(200, ''),
      );
      await MurrtubeApi.addToPlaylist(
        playlistId: 'p1',
        shortCode: 'ABC1',
        mediumId: 'm1',
      );
      final body = server.requestsTo('/playlists/p1/items').single.body;
      expect(body, contains('ABC1'));
      expect(body, contains('m1'));
    });

    test('addToPlaylist throws on failure', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onPost(
        '/playlists/p1/items',
        (req) => const FakeResponse(500, ''),
      );
      expect(
        () => MurrtubeApi.addToPlaylist(
          playlistId: 'p1',
          shortCode: 'A',
          mediumId: 'm',
        ),
        throwsA(isA<HttpException>()),
      );
    });

    test('editTags posts json and parses returned tags', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onPost(
        '/tag_edits',
        (req) => FakeResponse.json({
          'tags': [tagJson(name: 'new')],
        }),
      );
      final tags = await MurrtubeApi.editTags(
        shortCode: 'ABC1',
        additions: ['new'],
        removals: ['old'],
      );
      expect(tags.single.name, 'new');
      final req = server.requestsTo('/tag_edits').single;
      expect(req.header('content-type'), contains('application/json'));
      expect(req.body, contains('"additions":["new"]'));
      expect(req.body, contains('"removals":["old"]'));
    });

    test('editTags throws on failure', () async {
      stubCsrf();
      MurrtubeApi.setCookies('session_id=abc');
      server.onPost('/tag_edits', (req) => const FakeResponse(500, ''));
      expect(
        () => MurrtubeApi.editTags(
          shortCode: 'A',
          additions: const [],
          removals: const [],
        ),
        throwsA(isA<HttpException>()),
      );
    });
  });

  group('cookie jar merging', () {
    test('set-cookie merges with existing cookies', () async {
      MurrtubeApi.setCookies('existing=1');
      server.onGet(
        '/',
        (req) => homeJson(),
        matchQuery: (uri) => uri.queryParameters.containsKey('tab'),
      );
      // First call carries no set-cookie; second call sets one so the jar
      // merge loop runs over the pre-existing cookie.
      server.onGet(
        '/v/M1',
        (req) => FakeResponse.inertia(
          'Video',
          {
            'medium': mediaJson(),
            'comments': const [],
            'comments_pagination': paginationJson(),
          },
          headers: {
            'set-cookie': ['fresh=2; Path=/'],
          },
        ),
      );
      await MurrtubeApi.getVideo('M1');
      expect(MurrtubeApi.hasCookies, isTrue);
    });
  });

  group('authed mutation headers', () {
    void stubCsrf() {
      server.onGet(
        '/',
        (req) => FakeResponse.htmlPage(),
        matchQuery: (uri) => !uri.queryParameters.containsKey('tab'),
      );
    }

    test('mutation helpers send the cookie header when logged in', () async {
      MurrtubeApi.setCookies('session_id=abc');
      stubCsrf();
      server.onPost('/likes', (req) => const FakeResponse(200, '{}'));
      server.onDelete('/likes/m1', (req) => const FakeResponse(200, '{}'));
      server.onPost('/comments', (req) => const FakeResponse(200, '{}'));
      server.onDelete('/comments/c1', (req) => const FakeResponse(200, '{}'));
      server.onPut('/users/u1/unblock', (req) => const FakeResponse(200, '{}'));
      server.onGet(
        '/search/suggest',
        (req) => FakeResponse.json({'users': [], 'tags': []}),
      );

      await MurrtubeApi.likeVideo('m1');
      await MurrtubeApi.unlikeVideo('m1');
      await MurrtubeApi.postComment(mediumId: 'm1', body: 'hi');
      await MurrtubeApi.deleteComment('c1');
      await MurrtubeApi.replyToComment(
        mediumId: 'm1',
        parentId: 'p1',
        body: 're',
      );
      await MurrtubeApi.unblockUser('u1');
      await MurrtubeApi.searchSuggest('q');

      for (final r in server.requests) {
        if (r.uri.path == '/') continue;
        expect(
          r.header('cookie'),
          contains('session_id=abc'),
          reason: r.uri.path,
        );
      }
    });
  });

  group('inertia version extraction', () {
    void stubHtmlThenHome(String html) {
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return FakeResponse(200, html);
        }
        return homeJson();
      });
    }

    test('recovers from invalid double-quoted data-page json', () async {
      stubHtmlThenHome('<html><body data-page="{not json"></body></html>');
      await MurrtubeApi.getHome();
      expect(server.requests.last.header('x-inertia-version'), '1');
    });

    test('recovers from invalid single-quoted data-page json', () async {
      stubHtmlThenHome("<html><body data-page='{not json'></body></html>");
      await MurrtubeApi.getHome();
      expect(server.requests.last.header('x-inertia-version'), '1');
    });

    test('extracts version from window.__inertia script', () async {
      stubHtmlThenHome(
        '<html><script>window.__inertia = {"version" : "v9x"}</script></html>',
      );
      await MurrtubeApi.getHome();
      expect(server.requests.last.header('x-inertia-version'), 'v9x');
    });
  });

  group('authed retry paths', () {
    test('empty-body 409 refetches root with cookie header', () async {
      MurrtubeApi.setCookies('session_id=abc');
      var first = true;
      server.onGet('/', (req) {
        if (first && req.uri.queryParameters.containsKey('tab')) {
          first = false;
          return const FakeResponse(409, '');
        }
        if (req.uri.queryParameters.containsKey('tab')) {
          return homeJson();
        }
        return FakeResponse.htmlPage();
      });
      await MurrtubeApi.getHome();
      final rootReq = server.requests.firstWhere(
        (r) => (r.uri.path.isEmpty || r.uri.path == '/') && r.uri.query.isEmpty,
      );
      expect(rootReq.header('cookie'), contains('session_id=abc'));
    });

    test('age-check POST sends cookie header when logged in', () async {
      MurrtubeApi.setCookies('session_id=abc');
      var first = true;
      server.onGet('/', (req) {
        if (first) {
          first = false;
          return FakeResponse.htmlPage(ageCheck: true);
        }
        return homeJson();
      });
      server.onPost('/age_check', (req) => const FakeResponse(302, ''));
      await MurrtubeApi.getHome();
      expect(
        server.requestsTo('/age_check').single.header('cookie'),
        contains('session_id=abc'),
      );
    });
  });
}
