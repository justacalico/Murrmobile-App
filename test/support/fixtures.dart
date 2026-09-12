import 'package:murrmobile/models/comment.dart';
import 'package:murrmobile/models/media.dart';
import 'package:murrmobile/models/user.dart';

Map<String, dynamic> userJson({
  String id = 'user-1',
  String slug = 'test-user',
  String name = 'Test User',
  String? avatarUrl,
  bool isAdmin = false,
  bool isOwner = false,
  String preferredVideoQuality = 'auto',
}) => {
  'id': id,
  'slug': slug,
  'name': name,
  'avatar_url': avatarUrl,
  'is_admin': isAdmin,
  'is_owner': isOwner,
  'preferred_video_quality': preferredVideoQuality,
};

User testUser({
  String id = 'user-1',
  String slug = 'test-user',
  String name = 'Test User',
  String? avatarUrl,
  bool isAdmin = false,
  bool isOwner = false,
}) => User.fromJson(
  userJson(
    id: id,
    slug: slug,
    name: name,
    avatarUrl: avatarUrl,
    isAdmin: isAdmin,
    isOwner: isOwner,
  ),
);

Map<String, dynamic> tagJson({
  String name = 'test',
  String category = 'general',
  int count = 10,
}) => {'name': name, 'category': category, 'count': count};

Map<String, dynamic> mediaJson({
  String id = 'media-1',
  String shortCode = 'ABC1',
  String title = 'Test Video',
  String? url,
  int duration = 352,
  String durationLabel = '5:52',
  String? thumbnailUrl,
  String? previewUrl,
  String status = 'published',
  int likesCount = 40,
  int viewsCount = 3943,
  String publishedAt = '2026-05-31T23:07:33Z',
  String createdAt = '2026-05-31T21:04:45Z',
  Map<String, dynamic>? user,
  String? description,
  String visibility = 'public',
  bool commentsDisabled = false,
  int commentsCount = 13,
  List<Map<String, dynamic>>? tags,
  bool viewerLiked = false,
  bool isOwner = false,
  bool isLive = true,
  String? hlsUrl,
}) => {
  'id': id,
  'short_code': shortCode,
  'title': title,
  'url': url ?? '/v/$shortCode',
  'duration': duration,
  'duration_label': durationLabel,
  'thumbnail_url': thumbnailUrl ?? 'https://murrtube.net/thumbs/$shortCode.png',
  'preview_url': previewUrl,
  'status': status,
  'likes_count': likesCount,
  'views_count': viewsCount,
  'published_at': publishedAt,
  'created_at': createdAt,
  'user': user ?? userJson(),
  'description': description,
  'visibility': visibility,
  'comments_disabled': commentsDisabled,
  'comments_count': commentsCount,
  'tags': tags ?? [tagJson()],
  'viewer_liked': viewerLiked,
  'is_owner': isOwner,
  'is_live': isLive,
  'hls_url': hlsUrl,
};

Media testMedia({
  String id = 'media-1',
  String shortCode = 'ABC1',
  String title = 'Test Video',
  int viewsCount = 3943,
  int likesCount = 40,
  Map<String, dynamic>? user,
  List<Map<String, dynamic>>? tags,
  String? description,
  String? hlsUrl,
  bool viewerLiked = false,
  int commentsCount = 13,
  String? thumbnailUrl,
}) => Media.fromJson(
  mediaJson(
    id: id,
    shortCode: shortCode,
    title: title,
    viewsCount: viewsCount,
    likesCount: likesCount,
    user: user,
    tags: tags,
    description: description,
    hlsUrl: hlsUrl,
    viewerLiked: viewerLiked,
    commentsCount: commentsCount,
    thumbnailUrl: thumbnailUrl,
  ),
);

Map<String, dynamic> commentJson({
  String id = 'comment-1',
  String body = 'Nice video!',
  String createdAt = '2026-05-31T23:07:33Z',
  int repliesCount = 0,
  bool isCreator = false,
  bool isOwner = false,
  Map<String, dynamic>? user,
  List<Map<String, dynamic>>? replies,
}) => {
  'id': id,
  'body': body,
  'created_at': createdAt,
  'replies_count': repliesCount,
  'is_creator': isCreator,
  'is_owner': isOwner,
  'user': user ?? userJson(),
  'replies': replies ?? [],
};

Comment testComment({
  String id = 'comment-1',
  String body = 'Nice video!',
  bool isCreator = false,
  bool isOwner = false,
  Map<String, dynamic>? user,
  List<Map<String, dynamic>>? replies,
}) => Comment.fromJson(
  commentJson(
    id: id,
    body: body,
    isCreator: isCreator,
    isOwner: isOwner,
    user: user,
    replies: replies,
  ),
);

Map<String, dynamic> paginationJson({
  int page = 1,
  int pages = 1,
  int count = 1,
  dynamic next,
  dynamic prev,
}) => {
  'page': page,
  'pages': pages,
  'count': count,
  'next': next,
  'prev': prev,
};

Map<String, dynamic> announcementJson({
  dynamic id = 1,
  String title = 'Announcement',
  String body = 'Something happened',
  String? ctaUrl,
  String? ctaLabel,
  String createdAt = '2026-05-31T23:07:33Z',
}) => {
  'id': id,
  'title': title,
  'body': body,
  'cta_url': ctaUrl,
  'cta_label': ctaLabel,
  'created_at': createdAt,
};

Map<String, dynamic> actorJson({
  String id = 'actor-1',
  String slug = 'actor',
  String name = 'Actor',
  String? avatarUrl,
}) => {'id': id, 'slug': slug, 'name': name, 'avatar_url': avatarUrl};

Map<String, dynamic> notificationJson({
  dynamic id = 1,
  String key = 'comment.created',
  String verb = 'commented',
  String? commentBody = 'nice',
  String? body,
  String? videoTitle,
  String? link,
  String createdAt = '2026-05-31T23:07:33Z',
  bool isUnread = false,
  Map<String, dynamic>? actor,
}) => {
  'id': id,
  'key': key,
  'verb': verb,
  'comment_body': commentBody,
  'body': body,
  'video_title': videoTitle,
  'link': link,
  'created_at': createdAt,
  'is_unread': isUnread,
  'actor': actor,
};

Map<String, dynamic> videoProps({
  Map<String, dynamic>? medium,
  List<Map<String, dynamic>>? comments,
  Map<String, dynamic>? commentsPagination,
  List<Map<String, dynamic>>? watchMore,
  bool viewerCanComment = true,
  bool viewerCanLike = true,
}) => {
  'medium': medium ?? mediaJson(),
  'comments': comments ?? [commentJson()],
  'comments_pagination': commentsPagination ?? paginationJson(),
  'watch_more':
      watchMore ?? [mediaJson(id: 'm2', shortCode: 'B2', title: 'More')],
  'viewer_can_comment': viewerCanComment,
  'viewer_can_like': viewerCanLike,
};

Map<String, dynamic> profileProps({
  Map<String, dynamic>? profile,
  List<Map<String, dynamic>>? media,
  Map<String, dynamic>? pagination,
  List<Map<String, dynamic>>? playlists,
  bool isSubscribed = false,
  bool isBlocked = false,
  bool viewingSelf = false,
  Map<String, dynamic>? currentUser,
  Map<String, dynamic>? tabCounts,
}) => {
  'profile': profile ?? userJson(),
  'media': media ?? [mediaJson()],
  'pagination': pagination ?? paginationJson(),
  'playlists': playlists ?? const [],
  'is_subscribed': isSubscribed,
  'is_blocked': isBlocked,
  'viewing_self': viewingSelf,
  'current_user': currentUser,
  'tab_counts':
      tabCounts ??
      const {
        'videos': 1,
        'likes': 0,
        'playlists': 0,
        'subscribers': 5,
        'subscriptions': 2,
      },
};

Map<String, dynamic> richProfileJson({
  String slug = 'test-user',
  String name = 'Test User',
  String? avatarUrl,
  String? bio,
  Map<String, String?>? socialMedia,
  int? subscribersCount,
  int? subscriptionsCount,
}) => {
  'id': 'user-1',
  'slug': slug,
  'name': name,
  'avatar_url': avatarUrl,
  'is_admin': false,
  'is_owner': false,
  'preferred_video_quality': 'auto',
  'bio': bio,
  'subscribers_count': subscribersCount,
  'subscriptions_count': subscriptionsCount,
  'social_media': socialMedia,
};

Map<String, dynamic> playlistJson({
  String id = 'pl-1',
  String name = 'My Playlist',
  String? description,
  String visibility = 'public',
  String slug = 'my-playlist',
  int itemsCount = 3,
}) => {
  'id': id,
  'name': name,
  'description': description,
  'visibility': visibility,
  'slug': slug,
  'items_count': itemsCount,
};
