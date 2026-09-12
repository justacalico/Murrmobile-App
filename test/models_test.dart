import 'package:flutter_test/flutter_test.dart';
import 'package:murrmobile/models/user.dart';
import 'package:murrmobile/models/media.dart';
import 'package:murrmobile/models/comment.dart';
import 'package:murrmobile/models/tag.dart';
import 'package:murrmobile/models/pagination.dart';
import 'package:murrmobile/models/announcement.dart';
import 'package:murrmobile/models/notification.dart';
import 'package:murrmobile/models/playlist.dart';

import 'support/fixtures.dart';

void main() {
  group('User', () {
    test('fromJson parses all fields', () {
      final user = User.fromJson(
        userJson(
          id: 'u1',
          slug: 'sluggy',
          name: 'Sluggy',
          avatarUrl: 'https://x/a.png',
          isAdmin: true,
          isOwner: true,
        ),
      );
      expect(user.id, 'u1');
      expect(user.slug, 'sluggy');
      expect(user.name, 'Sluggy');
      expect(user.avatarUrl, 'https://x/a.png');
      expect(user.isAdmin, isTrue);
      expect(user.isOwner, isTrue);
      expect(user.preferredVideoQuality, 'auto');
    });

    test('fromJson applies defaults', () {
      final user = User.fromJson({
        'id': 'u2',
        'slug': 's',
        'name': 'n',
        'avatar_url': null,
      });
      expect(user.isAdmin, isFalse);
      expect(user.isOwner, isFalse);
      expect(user.preferredVideoQuality, 'auto');
      expect(user.avatarUrl, isNull);
    });

    test('toJson round-trips', () {
      final user = testUser(avatarUrl: 'https://x/a.png');
      final json = user.toJson();
      final restored = User.fromJson(json);
      expect(restored.id, user.id);
      expect(restored.slug, user.slug);
      expect(restored.avatarUrl, user.avatarUrl);
    });
  });

  group('Tag', () {
    test('fromJson parses fields', () {
      final tag = Tag.fromJson(
        tagJson(name: 'cat', category: 'artist', count: 5),
      );
      expect(tag.name, 'cat');
      expect(tag.category, 'artist');
      expect(tag.count, 5);
    });

    test('fromJson defaults missing count to 0', () {
      final tag = Tag.fromJson({'name': 'x', 'category': 'c'});
      expect(tag.count, 0);
    });

    test('toJson round-trips', () {
      final tag = Tag.fromJson(tagJson());
      final restored = Tag.fromJson(tag.toJson());
      expect(restored.name, tag.name);
      expect(restored.category, tag.category);
      expect(restored.count, tag.count);
    });
  });

  group('Media', () {
    test('fromJson parses everything', () {
      final media = Media.fromJson(
        mediaJson(
          previewUrl: 'https://x/p.gif',
          description: 'desc',
          commentsDisabled: true,
          hlsUrl: 'https://x/v.m3u8',
          viewerLiked: true,
          isOwner: true,
          isLive: true,
          visibility: 'unlisted',
        ),
      );
      expect(media.shortCode, 'ABC1');
      expect(media.duration, 352);
      expect(media.previewUrl, 'https://x/p.gif');
      expect(media.user.slug, 'test-user');
      expect(media.tags, hasLength(1));
      expect(media.commentsDisabled, isTrue);
      expect(media.hlsUrl, 'https://x/v.m3u8');
      expect(media.viewerLiked, isTrue);
      expect(media.isOwner, isTrue);
      expect(media.isLive, isTrue);
      expect(media.visibility, 'unlisted');
      expect(media.publishedAt, DateTime.parse('2026-05-31T23:07:33Z'));
    });

    test('fromJson applies defaults for missing optional fields', () {
      final media = Media.fromJson({
        'id': 'm',
        'short_code': 'X',
        'title': 't',
        'url': '/v/X',
        'duration': 1,
        'duration_label': '0:01',
        'thumbnail_url': 'https://x/t.png',
        'status': 'published',
        'likes_count': 0,
        'views_count': 0,
        'published_at': '2026-01-01T00:00:00Z',
        'created_at': '2026-01-01T00:00:00Z',
        'user': userJson(),
      });
      expect(media.visibility, 'public');
      expect(media.commentsDisabled, isFalse);
      expect(media.commentsCount, 0);
      expect(media.tags, isEmpty);
      expect(media.viewerLiked, isFalse);
      expect(media.isOwner, isFalse);
      expect(media.isLive, isFalse);
      expect(media.hlsUrl, isNull);
      expect(media.previewUrl, isNull);
      expect(media.description, isNull);
    });

    test('toJson round-trips', () {
      final media = testMedia(hlsUrl: 'https://x/v.m3u8', description: 'd');
      final restored = Media.fromJson(media.toJson());
      expect(restored.shortCode, media.shortCode);
      expect(restored.user.slug, media.user.slug);
      expect(restored.tags.length, media.tags.length);
      expect(restored.hlsUrl, media.hlsUrl);
    });
  });

  group('Comment', () {
    test('fromJson parses fields', () {
      final comment = Comment.fromJson(
        commentJson(isCreator: true, isOwner: true, repliesCount: 2),
      );
      expect(comment.id, 'comment-1');
      expect(comment.isCreator, isTrue);
      expect(comment.isOwner, isTrue);
      expect(comment.repliesCount, 2);
      expect(comment.user.slug, 'test-user');
    });

    test('fromJson parses nested replies', () {
      final comment = Comment.fromJson(
        commentJson(
          replies: [
            commentJson(id: 'r1', body: 'reply one'),
            commentJson(id: 'r2', body: 'reply two'),
          ],
        ),
      );
      expect(comment.replies, hasLength(2));
      expect(comment.replies.first.body, 'reply one');
    });

    test('fromJson defaults when fields missing', () {
      final comment = Comment.fromJson({
        'id': 'c',
        'body': 'b',
        'created_at': '2026-01-01T00:00:00Z',
        'user': userJson(),
      });
      expect(comment.repliesCount, 0);
      expect(comment.isCreator, isFalse);
      expect(comment.isOwner, isFalse);
      expect(comment.replies, isEmpty);
    });

    test('toJson round-trips with replies', () {
      final comment = testComment(
        id: 'c1',
        replies: [commentJson(id: 'r1')],
      );
      final restored = Comment.fromJson(comment.toJson());
      expect(restored.id, 'c1');
      expect(restored.replies.single.id, 'r1');
    });
  });

  group('Pagination', () {
    test('fromJson parses fields', () {
      final p = Pagination.fromJson(
        paginationJson(
          page: 2,
          pages: 5,
          count: 100,
          next: '/?page=3',
          prev: '/?page=1',
        ),
      );
      expect(p.page, 2);
      expect(p.pages, 5);
      expect(p.count, 100);
      expect(p.next, '/?page=3');
      expect(p.prev, '/?page=1');
    });

    test('toJson round-trips', () {
      final p = Pagination.fromJson(paginationJson(next: '/n', prev: 0));
      final restored = Pagination.fromJson(p.toJson());
      expect(restored.page, p.page);
      expect(restored.next, p.next);
      expect(restored.prev, p.prev);
    });
  });

  group('Announcement', () {
    test('fromJson parses fields', () {
      final a = Announcement.fromJson(
        announcementJson(ctaUrl: 'https://x', ctaLabel: 'Go'),
      );
      expect(a.id, 1);
      expect(a.title, 'Announcement');
      expect(a.ctaUrl, 'https://x');
      expect(a.ctaLabel, 'Go');
      expect(a.createdAt, DateTime.parse('2026-05-31T23:07:33Z'));
    });

    test('fromJson tolerates missing cta', () {
      final a = Announcement.fromJson(announcementJson());
      expect(a.ctaUrl, isNull);
      expect(a.ctaLabel, isNull);
    });

    test('toJson round-trips', () {
      final a = Announcement.fromJson(
        announcementJson(ctaUrl: 'https://x', ctaLabel: 'L'),
      );
      final restored = Announcement.fromJson(a.toJson());
      expect(restored.title, a.title);
      expect(restored.ctaUrl, a.ctaUrl);
    });
  });

  group('NotificationItem', () {
    test('fromJson parses string id and actor', () {
      final n = NotificationItem.fromJson(
        notificationJson(
          id: 'abc',
          actor: {
            'id': 'u1',
            'slug': 'actor',
            'name': 'Actor',
            'avatar_url': null,
          },
        ),
      );
      expect(n.id, 'abc');
      expect(n.type, 'comment.created');
      expect(n.title, 'Actor commented');
      expect(n.body, 'nice');
      expect(n.read, isTrue);
      expect(n.actor!.name, 'Actor');
    });

    test('fromJson converts int id to string', () {
      final n = NotificationItem.fromJson(notificationJson(id: 42));
      expect(n.id, '42');
    });

    test('fromJson builds title from verb only without actor', () {
      final n = NotificationItem.fromJson(
        notificationJson(verb: 'did a thing'),
      );
      expect(n.actor, isNull);
      expect(n.title, 'did a thing');
    });

    test('fromJson picks body from alternate fields', () {
      expect(
        NotificationItem.fromJson(
          notificationJson(commentBody: null, body: 'b2'),
        ).body,
        'b2',
      );
      expect(
        NotificationItem.fromJson(
          notificationJson(commentBody: null, body: null, videoTitle: 'vt'),
        ).body,
        'vt',
      );
      expect(
        NotificationItem.fromJson(
          notificationJson(commentBody: null, body: null, videoTitle: null),
        ).body,
        '',
      );
    });

    test('fromJson strips carriage returns from body', () {
      final n = NotificationItem.fromJson(
        notificationJson(commentBody: 'a\rb'),
      );
      expect(n.body, 'ab');
    });

    test('fromJson uses kind when key missing and marks unread', () {
      final n = NotificationItem.fromJson({
        'id': 'n1',
        'kind': 'like',
        'created_at': '2026-01-01T00:00:00Z',
        'is_unread': true,
        'link': '/v/ABC#comment-9',
      });
      expect(n.type, 'like');
      expect(n.read, isFalse);
      expect(n.url, '/v/ABC#comment-9');
      expect(n.title, '');
    });

    test('fromJson defaults type to unknown', () {
      final n = NotificationItem.fromJson({
        'id': 'n2',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(n.type, 'unknown');
    });

    test('toJson serializes', () {
      final n = NotificationItem.fromJson(notificationJson());
      final json = n.toJson();
      expect(json['id'], '1');
      expect(json['type'], 'comment.created');
      expect(json['read'], isTrue);
    });

    test('NotificationActor parses avatar', () {
      final actor = NotificationActor.fromJson(const {
        'id': 'u',
        'slug': 's',
        'name': 'n',
        'avatar_url': 'https://x/a.png',
      });
      expect(actor.avatarUrl, 'https://x/a.png');
    });
  });

  group('Playlist', () {
    test('fromJson parses fields', () {
      final p = Playlist.fromJson(
        playlistJson(description: 'd', visibility: 'private', itemsCount: 9),
      );
      expect(p.id, 'pl-1');
      expect(p.name, 'My Playlist');
      expect(p.description, 'd');
      expect(p.visibility, 'private');
      expect(p.slug, 'my-playlist');
      expect(p.itemsCount, 9);
    });

    test('fromJson applies defaults', () {
      final p = Playlist.fromJson(const {'id': 'x', 'name': 'n', 'slug': 's'});
      expect(p.visibility, 'public');
      expect(p.itemsCount, 0);
      expect(p.description, isNull);
    });

    test('toJson round-trips', () {
      final p = Playlist.fromJson(playlistJson(description: 'dd'));
      final restored = Playlist.fromJson(p.toJson());
      expect(restored.slug, p.slug);
      expect(restored.itemsCount, p.itemsCount);
    });
  });
}
