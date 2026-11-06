import 'user.dart';
import 'tag.dart';

class Media {
  final String id;
  final String shortCode;
  final String title;
  final String url;
  final int duration;
  final String durationLabel;
  final String thumbnailUrl;
  final String? previewUrl;
  final String status;
  final int likesCount;
  final int viewsCount;
  final DateTime publishedAt;
  final DateTime createdAt;
  final User user;
  final String? description;
  final String visibility;
  final bool commentsDisabled;
  final int commentsCount;
  final List<Tag> tags;
  final bool viewerLiked;
  final bool isOwner;
  final bool isLive;
  final String? hlsUrl;

  Media({
    required this.id,
    required this.shortCode,
    required this.title,
    required this.url,
    required this.duration,
    required this.durationLabel,
    required this.thumbnailUrl,
    this.previewUrl,
    required this.status,
    required this.likesCount,
    required this.viewsCount,
    required this.publishedAt,
    required this.createdAt,
    required this.user,
    this.description,
    required this.visibility,
    required this.commentsDisabled,
    required this.commentsCount,
    required this.tags,
    required this.viewerLiked,
    required this.isOwner,
    required this.isLive,
    this.hlsUrl,
  });

  Media copyWith({
    List<Tag>? tags,
    int? commentsCount,
    bool? viewerLiked,
    int? likesCount,
  }) {
    return Media(
      id: id,
      shortCode: shortCode,
      title: title,
      url: url,
      duration: duration,
      durationLabel: durationLabel,
      thumbnailUrl: thumbnailUrl,
      previewUrl: previewUrl,
      status: status,
      likesCount: likesCount ?? this.likesCount,
      viewsCount: viewsCount,
      publishedAt: publishedAt,
      createdAt: createdAt,
      user: user,
      description: description,
      visibility: visibility,
      commentsDisabled: commentsDisabled,
      commentsCount: commentsCount ?? this.commentsCount,
      tags: tags ?? this.tags,
      viewerLiked: viewerLiked ?? this.viewerLiked,
      isOwner: isOwner,
      isLive: isLive,
      hlsUrl: hlsUrl,
    );
  }

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'] as String,
      shortCode: json['short_code'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      duration: json['duration'] as int,
      durationLabel: json['duration_label'] as String,
      thumbnailUrl: json['thumbnail_url'] as String,
      previewUrl: json['preview_url'] as String?,
      status: json['status'] as String,
      likesCount: json['likes_count'] as int,
      viewsCount: json['views_count'] as int,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      description: json['description'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      commentsDisabled: json['comments_disabled'] as bool? ?? false,
      commentsCount: json['comments_count'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => Tag.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      viewerLiked: json['viewer_liked'] as bool? ?? false,
      isOwner: json['is_owner'] as bool? ?? false,
      isLive: json['is_live'] as bool? ?? false,
      hlsUrl: json['hls_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'short_code': shortCode,
        'title': title,
        'url': url,
        'duration': duration,
        'duration_label': durationLabel,
        'thumbnail_url': thumbnailUrl,
        'preview_url': previewUrl,
        'status': status,
        'likes_count': likesCount,
        'views_count': viewsCount,
        'published_at': publishedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'user': user.toJson(),
        'description': description,
        'visibility': visibility,
        'comments_disabled': commentsDisabled,
        'comments_count': commentsCount,
        'tags': tags.map((t) => t.toJson()).toList(),
        'viewer_liked': viewerLiked,
        'is_owner': isOwner,
        'is_live': isLive,
        'hls_url': hlsUrl,
      };
}
