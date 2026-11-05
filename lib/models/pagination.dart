class Pagination {
  final int page;
  final int pages;
  final int count;
  final int? next;
  final int? prev;

  Pagination({
    required this.page,
    required this.pages,
    required this.count,
    this.next,
    this.prev,
  });

  static int? _pageFrom(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final direct = int.tryParse(value);
      if (direct != null) return direct;
      final uri = Uri.tryParse(value);
      final p = uri?.queryParameters['page'];
      if (p != null) return int.tryParse(p);
    }
    return null;
  }

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] as int? ?? 1,
      pages: json['pages'] as int? ?? 1,
      count: json['count'] as int? ?? 0,
      next: _pageFrom(json['next']),
      prev: _pageFrom(json['prev']),
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'pages': pages,
        'count': count,
        'next': next,
        'prev': prev,
      };
}
