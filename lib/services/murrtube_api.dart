import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/media.dart';
import '../models/comment.dart';
import '../models/pagination.dart';
import '../models/announcement.dart';
import '../models/notification.dart';
import '../models/user.dart';
import '../models/playlist.dart';
import '../models/tag.dart';

class InertiaPage {
  final String component;
  final Map<String, dynamic> props;
  final String? version;

  InertiaPage({
    required this.component,
    required this.props,
    this.version,
  });

  factory InertiaPage.fromJson(Map<String, dynamic> json) {
    return InertiaPage(
      component: json['component'] as String,
      props: json['props'] as Map<String, dynamic>,
      version: json['version'] as String?,
    );
  }
}

class MurrtubeApi {
  static const String baseUrl = 'https://murrtube.net';
  static String? _cookieString;

  static String? get cookies => _cookieString;
  static bool get hasCookies => _cookieString != null && _cookieString!.isNotEmpty;
  static bool get isAuthenticated {
    if (_cookieString == null) return false;
    return _cookieString!.contains('session_id=');
  }
  static String? currentUserSlug;

  static void setCookies(String cookies) {
    _cookieString = cookies;
    currentUserSlug = null;
  }

  static void clearCookies() {
    _cookieString = null;
    _inertiaVersion = null;
    currentUserSlug = null;
  }

  static String? _inertiaVersion;

  static void _updateCookiesFromResponse(http.Response response) {
    final setCookies = response.headers['set-cookie'];
    if (setCookies == null) return;

    final jar = <String, String>{};
    if (_cookieString != null) {
      for (final part in _cookieString!.split('; ')) {
        final i = part.indexOf('=');
        if (i != -1) jar[part.substring(0, i)] = part.substring(i + 1);
      }
    }
    for (final raw in setCookies.split(',')) {
      final c = raw.split(';').first.trim();
      final i = c.indexOf('=');
      if (i != -1) jar[c.substring(0, i)] = c.substring(i + 1);
    }
    _cookieString = jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
    debugPrint('Updated cookies from response. Now cookies set? ${hasCookies}');
  }

  static Map<String, String> _headers({String? inertiaVersion, String? homeTab}) {
    final h = {
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'X-Inertia': 'true',
      if (inertiaVersion != null) 'X-Inertia-Version': inertiaVersion,
      if (homeTab != null) 'X-Murrtube-Home-Tab': homeTab,
      'Referer': baseUrl,
      if (_cookieString != null) 'Cookie': _cookieString!,
    };
    debugPrint('--- headers ---');
    h.forEach((k, v) {
      if (k == 'Cookie') {
        debugPrint('Cookie: ${_maskCookie(v)}');
      } else {
        debugPrint('$k: $v');
      }
    });
    return h;
  }

  static String _maskCookie(String cookie) {
    final parts = cookie.split('; ');
    return parts.map((p) {
      final i = p.indexOf('=');
      if (i == -1) return p;
      final name = p.substring(0, i);
      final val = p.substring(i + 1);
      final show = val.length.clamp(0, 12);
      return '$name=${val.substring(0, show)}...(${val.length} chars)';
    }).join('; ');
  }

  static Future<InertiaPage> _get(String path, {String? homeTab}) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('');
    debugPrint('=== MurrtubeApi._get $path ===');
    debugPrint('cookies set? ${hasCookies}');

    // Try with cached version first
    var response = await http.get(
      uri,
      headers: _headers(inertiaVersion: _inertiaVersion, homeTab: homeTab),
    );

    var body = utf8.decode(response.bodyBytes);
    _updateCookiesFromResponse(response);
    debugPrint('First response status: ${response.statusCode}');
    debugPrint('First response body starts with: ${body.isNotEmpty ? body.substring(0, body.length.clamp(0, 60)) : "(empty)"}');

    // 409 = Inertia version mismatch. Body may be empty, so fetch root page
    // without Inertia headers to get HTML and extract the version.
    if (response.statusCode == 409 || !body.startsWith('{')) {
      debugPrint('Need to extract Inertia version and retry...');

      // If body is empty (common for 409), fetch root page normally
      if (body.isEmpty) {
        debugPrint('Body empty, fetching root page without Inertia headers...');
        final rootResp = await http.get(
          Uri.parse(baseUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Referer': baseUrl,
            if (_cookieString != null) 'Cookie': _cookieString!,
          },
        );
        _updateCookiesFromResponse(rootResp);
        final rootBody = utf8.decode(rootResp.bodyBytes);
        debugPrint('Root page status: ${rootResp.statusCode}');
        debugPrint('Root page body starts with: ${rootBody.isNotEmpty ? rootBody.substring(0, rootBody.length.clamp(0, 60)) : "(empty)"}');
        _inertiaVersion = _extractInertiaVersion(rootBody);
        // Check if age check is needed and bypass it
        await _maybeBypassAgeCheck(rootBody);
      } else {
        _inertiaVersion = _extractInertiaVersion(body);
        await _maybeBypassAgeCheck(body);
      }

      if (_inertiaVersion == null) {
        debugPrint('Version extraction failed, trying default version 1');
        _inertiaVersion = '1';
      }
      debugPrint('Extracted version: $_inertiaVersion');
      response = await http.get(
        uri,
        headers: _headers(inertiaVersion: _inertiaVersion, homeTab: homeTab),
      );
      _updateCookiesFromResponse(response);
      body = utf8.decode(response.bodyBytes);
      debugPrint('Retry response status: ${response.statusCode}');
      debugPrint('Retry response body starts with: ${body.isNotEmpty ? body.substring(0, body.length.clamp(0, 2000)) : "(empty)"}');
    }

    if (response.statusCode != 200) {
      debugPrint('Final status code not 200, throwing.');
      throw HttpException('HTTP ${response.statusCode} for $path');
    }

    if (!body.startsWith('{')) {
      debugPrint('Body is not JSON after retries, throwing.');
      throw FormatException('Expected JSON for $path, got HTML');
    }

    debugPrint('Parsing JSON response...');
    return InertiaPage.fromJson(jsonDecode(body));
  }

  static Future<void> _maybeBypassAgeCheck(String html) async {
    // Check if this is an age-check page
    if (!html.contains('age_check') && !html.contains('age-check')) return;

    // Extract CSRF token from meta tag
    final csrfRegex = RegExp(r'<meta name="csrf-token" content="([^"]+)"');
    final csrfMatch = csrfRegex.firstMatch(html);
    final csrfToken = csrfMatch?.group(1);
    if (csrfToken == null) {
      debugPrint('Age check detected but no CSRF token found');
      return;
    }

    // Extract the actual form action from HTML
    final actionRegex = RegExp(r'action="([^"]*age_check[^"]*)"');
    final actionMatch = actionRegex.firstMatch(html);
    var ageUrl = actionMatch?.group(1);
    if (ageUrl == null) {
      // Fallback: try common patterns
      ageUrl = '/age_check';
    }
    if (!ageUrl.startsWith('http')) {
      ageUrl = '$baseUrl$ageUrl';
    }

    debugPrint('Age check detected. POSTing to: $ageUrl');
    final request = http.MultipartRequest('POST', Uri.parse(ageUrl))
      ..fields['authenticity_token'] = csrfToken;

    request.headers.addAll({
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': baseUrl,
      if (_cookieString != null) 'Cookie': _cookieString!,
    });

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _updateCookiesFromResponse(response);
    debugPrint('Age check POST status: ${response.statusCode}');
  }

  static String? _extractInertiaVersion(String html) {
    debugPrint('Extracting Inertia version from HTML (${html.length} chars)');
    // 1. Plain JSON in script tags
    final versionRegex = RegExp(r'"version":"([^"]+)"');
    final match = versionRegex.firstMatch(html);
    if (match != null) {
      final v = match.group(1);
      debugPrint('Found version via regex: $v');
      return v;
    }
    // 2. data-page attribute with double quotes
    final dataPageRegex = RegExp(r'data-page="([^"]+)"');
    final dataMatch = dataPageRegex.firstMatch(html);
    if (dataMatch != null) {
      try {
        final raw = dataMatch.group(1)!;
        final cleaned = raw
            .replaceAll('&quot;', '"')
            .replaceAll('\\"', '"')
            .replaceAll('\\n', '\n');
        final decoded = jsonDecode(cleaned);
        if (decoded is Map<String, dynamic>) {
          final v = decoded['version'] as String?;
          debugPrint('Found version via data-page: $v');
          return v;
        }
      } catch (e) {
        debugPrint('data-page parse failed: $e');
      }
    }
    // 2b. data-page with single quotes
    final dataPageRegex2 = RegExp(r"data-page='([^']+)'");
    final dataMatch2 = dataPageRegex2.firstMatch(html);
    if (dataMatch2 != null) {
      try {
        final raw = dataMatch2.group(1)!;
        final cleaned = raw
            .replaceAll('&quot;', '"')
            .replaceAll('\\"', '"')
            .replaceAll('\\n', '\n');
        final decoded = jsonDecode(cleaned);
        if (decoded is Map<String, dynamic>) {
          final v = decoded['version'] as String?;
          debugPrint('Found version via data-page single: $v');
          return v;
        }
      } catch (e) {
        debugPrint('data-page single parse failed: $e');
      }
    }
    // 3. HTML-escaped &quot;version&quot; in raw HTML
    final quotRegex = RegExp(r'&quot;version&quot;:&quot;([^&]+)&quot;');
    final quotMatch = quotRegex.firstMatch(html);
    if (quotMatch != null) {
      final v = quotMatch.group(1);
      debugPrint('Found version via &quot; regex: $v');
      return v;
    }
    // 4. window.__inertia or similar script variable
    final scriptRegex = RegExp(r'window\.__inertia\s*=\s*\{[^}]*"version"\s*:\s*"([^"]+)"');
    final scriptMatch = scriptRegex.firstMatch(html);
    if (scriptMatch != null) {
      final v = scriptMatch.group(1);
      debugPrint('Found version via script: $v');
      return v;
    }
    // 5. Any occurrence of version in first 500 chars
    final dump = html.substring(0, html.length.clamp(0, 500));
    debugPrint('No version found. HTML snippet: $dump');
    return null;
  }

  // Home (trending / subscriptions)
  static Future<({
    List<Media> media,
    Pagination pagination,
    List<Announcement> announcements,
    String tab,
    User? currentUser,
  })> getHome({String tab = 'trending', int page = 1}) async {
    final path = page == 1 ? '/?tab=$tab' : '/?tab=$tab&page=$page';
    final inertia = await _get(path, homeTab: tab);
    final props = inertia.props;
    final mediaList = (props['media'] as List<dynamic>)
        .map((m) => Media.fromJson(m as Map<String, dynamic>))
        .toList();
    final pagination = Pagination.fromJson(props['pagination'] as Map<String, dynamic>);
    final announcements = (props['announcements'] as List<dynamic>)
        .map((a) => Announcement.fromJson(a as Map<String, dynamic>))
        .toList();
    final currentUser = props['current_user'] != null
        ? User.fromJson(props['current_user'] as Map<String, dynamic>)
        : null;
    if (currentUser != null) {
      currentUserSlug = currentUser.slug;
    }
    return (
      media: mediaList,
      pagination: pagination,
      announcements: announcements,
      tab: props['tab'] as String? ?? tab,
      currentUser: currentUser,
    );
  }

  // Video detail
  static Future<({
    Media medium,
    List<Comment> comments,
    Pagination commentsPagination,
    List<Media> watchMore,
    bool viewerCanComment,
    bool viewerCanLike,
  })> getVideo(String shortCode) async {
    final inertia = await _get('/v/$shortCode');
    final props = inertia.props;
    final medium = Media.fromJson(props['medium'] as Map<String, dynamic>);
    final comments = (props['comments'] as List<dynamic>)
        .map((c) => Comment.fromJson(c as Map<String, dynamic>))
        .toList();
    final commentsPagination =
        Pagination.fromJson(props['comments_pagination'] as Map<String, dynamic>);
    final watchMore = (props['watch_more'] as List<dynamic>? ?? [])
        .map((m) => Media.fromJson(m as Map<String, dynamic>))
        .toList();
    return (
      medium: medium,
      comments: comments,
      commentsPagination: commentsPagination,
      watchMore: watchMore,
      viewerCanComment: props['viewer_can_comment'] as bool? ?? false,
      viewerCanLike: props['viewer_can_like'] as bool? ?? false,
    );
  }

  // Search
  static Future<({
    String? query,
    List<Media> media,
    List<User> users,
    List<Tag> tagMatches,
    Pagination pagination,
  })> search({String? query, int page = 1}) async {
    final q = query != null && query.isNotEmpty ? Uri.encodeComponent(query) : '';
    final path = '/search?q=$q&page=$page';
    final inertia = await _get(path);
    final props = inertia.props;
    final mediaList = (props['media'] as List<dynamic>)
        .map((m) => Media.fromJson(m as Map<String, dynamic>))
        .toList();
    final users = (props['users'] as List<dynamic>? ?? [])
        .map((u) => User.fromJson(u as Map<String, dynamic>))
        .toList();
    final tagMatches = (props['tag_matches'] as List<dynamic>? ?? [])
        .map((t) => Tag.fromJson(t as Map<String, dynamic>))
        .toList();
    final pagination =
        Pagination.fromJson(props['pagination'] as Map<String, dynamic>);
    return (
      query: props['query'] as String?,
      media: mediaList,
      users: users,
      tagMatches: tagMatches,
      pagination: pagination,
    );
  }

  // Search Suggestions
  static Future<({
    String? query,
    List<({String slug, String name, String? avatarUrl})> users,
    List<({String name, String category, int count})> tags,
  })> searchSuggest(String q) async {
    final query = Uri.encodeComponent(q);
    final response = await http.get(
      Uri.parse('$baseUrl/search/suggest?q=$query'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Referer': baseUrl,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final users = (json['users'] as List<dynamic>? ?? [])
        .map((u) => (
              slug: u['slug'] as String,
              name: u['name'] as String,
              avatarUrl: u['avatar_url'] as String?,
            ))
        .toList();
    final tags = (json['tags'] as List<dynamic>? ?? [])
        .map((t) => (
              name: t['name'] as String,
              category: t['category'] as String,
              count: t['count'] as int,
            ))
        .toList();
    return (
      query: json['query'] as String?,
      users: users,
      tags: tags,
    );
  }

  // Notifications
  static Future<({
    List<NotificationItem> items,
    int displayCap,
  })> getNotifications() async {
    final inertia = await _get('/notifications');
    final props = inertia.props;
    final items = (props['items'] as List<dynamic>)
        .map((i) => NotificationItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return (
      items: items,
      displayCap: props['display_cap'] as int? ?? 0,
    );
  }

  // User Profile
  static Future<({
    User user,
    List<Media> media,
    Pagination pagination,
    List<Playlist> playlists,
    bool isSubscribed,
    bool isBlocked,
    bool isSelf,
    User? currentUser,
    int? subscribersCount,
    int? subscriptionsCount,
    String? bio,
    String? telegramUrl,
    Map<String, int> tabCounts,
    String? gitlabUrl,
    String? twitterUrl,
    String? furaffinityUrl,
    String? patreonUrl,
    String? kofiUrl,
    String? blueskyUrl,
    String? onlyfansUrl,
  })> getUserProfile(String slug, {int page = 1, String tab = 'videos'}) async {
    var path = '/$slug';
    if (tab != 'videos') path += '?tab=$tab';
    if (page != 1) path += path.contains('?') ? '&page=$page' : '?page=$page';
    final inertia = await _get(path);
    final props = inertia.props;

    final profileRaw = props['profile'];
    if (profileRaw == null || profileRaw is! Map<String, dynamic>) {
      debugPrint('ProfilePage missing profile. Available props keys: ${props.keys.toList()}');
      throw Exception('User not found for slug: $slug');
    }
    final user = User.fromJson(profileRaw);

    final mediaList = (props['media'] as List<dynamic>? ?? [])
        .map((m) => Media.fromJson(m as Map<String, dynamic>))
        .toList();
    final pagination = Pagination.fromJson(
      props['pagination'] as Map<String, dynamic>? ??
          {'page': 1, 'pages': 1, 'count': mediaList.length, 'next': null, 'prev': null},
    );
    final playlists = (props['playlists'] as List<dynamic>? ?? [])
        .map((p) => Playlist.fromJson(p as Map<String, dynamic>))
        .toList();
    final currentUser = props['current_user'] != null
        ? User.fromJson(props['current_user'] as Map<String, dynamic>)
        : null;
    if (currentUser != null) {
      currentUserSlug = currentUser.slug;
    }
    final isSelf = props['viewing_self'] as bool? ?? false;
    if (isSelf) {
      currentUserSlug = user.slug;
    }
    final rawTabCounts = props['tab_counts'] as Map<String, dynamic>?;
    final tabCounts = <String, int>{};
    if (rawTabCounts != null) {
      for (final e in rawTabCounts.entries) {
        tabCounts[e.key] = e.value as int? ?? 0;
      }
    }

    // Parse social media from nested social_media object
    final socialMedia = profileRaw['social_media'] as Map<String, dynamic>?;
    final telegramUrl = socialMedia != null ? (socialMedia['telegram'] as String?) : null;
    final gitlabUrl = socialMedia != null ? (socialMedia['gitlab'] as String?) : null;
    final twitterUrl = socialMedia != null ? (socialMedia['twitter'] as String?) : null;
    final furaffinityUrl = socialMedia != null ? (socialMedia['furaffinity'] as String?) : null;
    final patreonUrl = socialMedia != null ? (socialMedia['patreon'] as String?) : null;
    final kofiUrl = socialMedia != null ? (socialMedia['kofi'] as String?) : null;
    final blueskyUrl = socialMedia != null ? (socialMedia['bluesky'] as String?) : null;
    final onlyfansUrl = socialMedia != null ? (socialMedia['onlyfans'] as String?) : null;

    return (
      user: user,
      media: mediaList,
      pagination: pagination,
      playlists: playlists,
      isSubscribed: props['is_subscribed'] as bool? ?? false,
      isBlocked: props['is_blocked'] as bool? ?? false,
      isSelf: isSelf,
      currentUser: currentUser,
      subscribersCount: tabCounts['subscribers'] ?? profileRaw['subscribers_count'] as int?,
      subscriptionsCount: tabCounts['subscriptions'] ?? profileRaw['subscriptions_count'] as int?,
      bio: profileRaw['bio'] as String? ?? profileRaw['description'] as String?,
      telegramUrl: telegramUrl,
      tabCounts: tabCounts,
      gitlabUrl: gitlabUrl,
      twitterUrl: twitterUrl,
      furaffinityUrl: furaffinityUrl,
      patreonUrl: patreonUrl,
      kofiUrl: kofiUrl,
      blueskyUrl: blueskyUrl,
      onlyfansUrl: onlyfansUrl,
    );
  }

  static Future<void> blockUser(String slug) async {
    final token = await _fetchCsrfToken();
    final response = await http.put(
      Uri.parse('$baseUrl/users/$slug/block'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    debugPrint('blockUser status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> unblockUser(String slug) async {
    final token = await _fetchCsrfToken();
    final response = await http.put(
      Uri.parse('$baseUrl/users/$slug/unblock'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    debugPrint('unblockUser status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> subscribeToUser(String slug) async {
    final token = await _fetchCsrfToken();
    final response = await http.post(
      Uri.parse('$baseUrl/users/$slug/follow'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    debugPrint('subscribeToUser status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> unsubscribeFromUser(String slug) async {
    final token = await _fetchCsrfToken();
    final response = await http.post(
      Uri.parse('$baseUrl/users/$slug/unfollow'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    debugPrint('unsubscribeFromUser status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  // Settings
  static Future<Map<String, dynamic>> getSettings() async {
    final inertia = await _get('/settings');
    return inertia.props;
  }

  // Upload
  static Future<Map<String, dynamic>> getUpload() async {
    final inertia = await _get('/upload');
    return inertia.props;
  }

  // About pages
  static Future<Map<String, dynamic>> getTerms() async {
    final inertia = await _get('/about/terms');
    return inertia.props;
  }

  static Future<Map<String, dynamic>> getPrivacy() async {
    final inertia = await _get('/about/privacy');
    return inertia.props;
  }

  static Future<Map<String, dynamic>> getCookies() async {
    final inertia = await _get('/about/cookies');
    return inertia.props;
  }

  static Future<Map<String, dynamic>> getWhatsNew() async {
    final inertia = await _get('/about/whats-new');
    return inertia.props;
  }

  // Like / Unlike
  static Future<String> _fetchCsrfToken() async {
    // The XSRF-TOKEN cookie may be stale. Fetch a fresh token from HTML.
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': baseUrl,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    final html = utf8.decode(response.bodyBytes);
    final match = RegExp(r'<meta name="csrf-token" content="([^"]+)"').firstMatch(html);
    final token = match?.group(1);
    debugPrint('Fetched CSRF token: ${token != null ? "${token.substring(0, token.length.clamp(0, 30))}..." : "NOT FOUND"}');
    if (token == null || token.isEmpty) {
      throw Exception('CSRF token not found in HTML');
    }
    return token;
  }

  static Future<void> likeVideo(String mediumId) async {
    final token = await _fetchCsrfToken();
    final response = await http.post(
      Uri.parse('$baseUrl/likes'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
      body: {'like[medium_id]': mediumId},
    );
    _updateCookiesFromResponse(response);
    debugPrint('likeVideo status: ${response.statusCode}');
    debugPrint('likeVideo response body: ${utf8.decode(response.bodyBytes)}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> postComment({required String mediumId, required String body}) async {
    final token = await _fetchCsrfToken();
    final response = await http.post(
      Uri.parse('$baseUrl/comments'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
      body: {
        'comment[medium_id]': mediumId,
        'comment[body]': body,
      },
    );
    _updateCookiesFromResponse(response);
    debugPrint('postComment status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> deleteComment(String commentId) async {
    final token = await _fetchCsrfToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/comments/$commentId'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    debugPrint('deleteComment status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> replyToComment({required String mediumId, required String parentId, required String body}) async {
    final token = await _fetchCsrfToken();
    final response = await http.post(
      Uri.parse('$baseUrl/comments'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
      body: {
        'comment[medium_id]': mediumId,
        'comment[parent_id]': parentId,
        'comment[body]': body,
      },
    );
    _updateCookiesFromResponse(response);
    debugPrint('replyToComment status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> unlikeVideo(String mediumId) async {
    final token = await _fetchCsrfToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/likes/$mediumId'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    debugPrint('unlikeVideo status: ${response.statusCode}');
    debugPrint('unlikeVideo response body: ${utf8.decode(response.bodyBytes)}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  // Playlists
  static Future<List<Playlist>> getMyPlaylists() async {
    final token = await _fetchCsrfToken();
    final response = await http.get(
      Uri.parse('$baseUrl/playlists/mine'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Referer': baseUrl,
        'x-csrf-token': token,
        'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    final body = utf8.decode(response.bodyBytes);
    debugPrint('getMyPlaylists status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final playlists = (json['playlists'] as List<dynamic>? ?? [])
        .map((p) => Playlist.fromJson(p as Map<String, dynamic>))
        .toList();
    return playlists;
  }

  static Future<Playlist> createPlaylist({
    required String name,
    String? description,
    required String visibility,
  }) async {
    final token = await _fetchCsrfToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/playlists'))
      ..fields['playlist[name]'] = name
      ..fields['playlist[visibility]'] = visibility;
    if (description != null && description.isNotEmpty) {
      request.fields['playlist[description]'] = description;
    }
    request.headers.addAll({
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'Accept': 'application/json',
      'Referer': baseUrl,
      'Origin': baseUrl,
      'X-Requested-With': 'XMLHttpRequest',
      'x-csrf-token': token,
      'Cookie': _cookieString!,
    });

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _updateCookiesFromResponse(response);
    final body = utf8.decode(response.bodyBytes);
    debugPrint('createPlaylist status: ${response.statusCode}');
    debugPrint('createPlaylist body: $body');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return Playlist(
      id: '',
      name: name,
      description: description,
      visibility: visibility,
      slug: json['slug'] as String,
    );
  }

  static Future<({
    Playlist playlist,
    List<Media> media,
    Pagination pagination,
    User? user,
    bool isOwner,
  })> getPlaylist(String userSlug, String playlistSlug, {int page = 1}) async {
    var path = '/$userSlug/p/$playlistSlug';
    if (page != 1) path += '?page=$page';
    final inertia = await _get(path);
    final props = inertia.props;
    final playlist = Playlist.fromJson(props['playlist'] as Map<String, dynamic>);
    final mediaList = (props['items'] as List<dynamic>? ?? [])
        .map((m) => Media.fromJson(m as Map<String, dynamic>))
        .toList();
    final pagination = Pagination.fromJson(
      props['pagination'] as Map<String, dynamic>? ??
          {'page': 1, 'pages': 1, 'count': mediaList.length, 'next': null, 'prev': null},
    );
    final user = props['user'] != null
        ? User.fromJson(props['user'] as Map<String, dynamic>)
        : null;
    return (
      playlist: playlist,
      media: mediaList,
      pagination: pagination,
      user: user,
      isOwner: props['is_owner'] as bool? ?? false,
    );
  }

  static Future<void> addToPlaylist({
    required String playlistId,
    required String shortCode,
    required String mediumId,
  }) async {
    final token = await _fetchCsrfToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/playlists/$playlistId/items'),
    )
      ..fields['short_code'] = shortCode
      ..fields['medium_id'] = mediumId;
    request.headers.addAll({
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'Accept': 'application/json',
      'Referer': baseUrl,
      'Origin': baseUrl,
      'X-Requested-With': 'XMLHttpRequest',
      'x-csrf-token': token,
      'Cookie': _cookieString!,
    });

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _updateCookiesFromResponse(response);
    final body = utf8.decode(response.bodyBytes);
    debugPrint('addToPlaylist status: ${response.statusCode}');
    debugPrint('addToPlaylist body: $body');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<List<Tag>> editTags({
    required String shortCode,
    required List<String> additions,
    required List<String> removals,
  }) async {
    final token = await _fetchCsrfToken();
    final response = await http.post(
      Uri.parse('$baseUrl/tag_edits'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
      body: jsonEncode({
        'taggable_type': 'Medium',
        'short_code': shortCode,
        'additions': additions,
        'removals': removals,
      }),
    );
    _updateCookiesFromResponse(response);
    debugPrint('editTags status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final tags = (json['tags'] as List<dynamic>? ?? [])
        .map((t) => Tag.fromJson(t as Map<String, dynamic>))
        .toList();
    return tags;
  }
}
