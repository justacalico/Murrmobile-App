class Announcement {
  final String id;
  final String title;
  final String body;
  final String? ctaUrl;
  final String? ctaLabel;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.ctaUrl,
    this.ctaLabel,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: '${json['id']}',
      title: json['title'] as String,
      body: json['body'] as String,
      ctaUrl: json['cta_url'] as String?,
      ctaLabel: json['cta_label'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'cta_url': ctaUrl,
        'cta_label': ctaLabel,
        'created_at': createdAt.toIso8601String(),
      };
}
