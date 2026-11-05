import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/cookie_loader.dart';
import '../models/media.dart';
import '../models/comment.dart';
import '../models/pagination.dart';
import '../models/announcement.dart';
import '../models/notification.dart';
import '../models/user.dart';
import '../models/playlist.dart';
import '../models/tag.dart';
import '../utils/logger.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'Session expired: please sign in again';
}

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

class _TimeoutClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(MurrtubeApi.requestTimeout);

  @override
  void close() => _inner.close();
}

class MurrtubeApi {
  static const String baseUrl = 'https://murrtube.net';
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';
  static Duration requestTimeout = const Duration(seconds: 15);
  static http.Client _client = _TimeoutClient();

  /// Rebuilds the underlying HTTP client. Tests install a fresh fake backend
  /// per test, so the client has to be re-created to pick it up.
  static void resetHttpClient() {
    _client.close();
    _client = _TimeoutClient();
  }
  static String? _cookieString;

  static String? get cookies => _cookieString;
  static bool get hasCookies => _cookieString != null && _cookieString!.isNotEmpty;
  static bool get isAuthenticated {
    if (_cookieString == null) return false;
    return _cookieString!.contains('_murrtube_v3_session=');
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

  // A comma only starts a new cookie when what follows looks like
  // `name=`; commas inside Expires dates ("Thu, 01 Jan 1970") don't.
  static final RegExp _cookieSplit = RegExp(r',\s*(?=[^;,\s]+=)');

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
    for (final raw in setCookies.split(_cookieSplit)) {
      final semi = raw.indexOf(';');
      final pair = (semi == -1 ? raw : raw.substring(0, semi)).trim();
      final i = pair.indexOf('=');
      if (i == -1) continue;
      final name = pair.substring(0, i).trim();
      if (name.isEmpty) continue;
      final value = pair.substring(i + 1).trim();
      final attrs = semi == -1 ? '' : raw.substring(semi);
      if (value.isEmpty || _cookieAttrsExpired(attrs)) {
        jar.remove(name);
      } else {
        jar[name] = value;
      }
    }
    final joined = jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
    if (joined == _cookieString) return;
    _cookieString = joined;
    unawaited(
      CookieLoader.save(joined).catchError((Object _) {}),
    );
    netLog('Updated cookies from response. Now cookies set? ${hasCookies}');
  }

  static bool _cookieAttrsExpired(String attrs) {
    final maxAge = RegExp(
      'max-age\\s*=\\s*"?(-?\\d+)"?',
      caseSensitive: false,
    ).firstMatch(attrs);
    if (maxAge != null && (int.tryParse(maxAge.group(1)!) ?? 1) <= 0) {
      return true;
    }
    final expires = RegExp(
      'expires\\s*=\\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(attrs);
    if (expires != null) {
      try {
        if (!HttpDate.parse(expires.group(1)!.trim()).isAfter(
          DateTime.now(),
        )) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  static Map<String, String> _headers({String? inertiaVersion, String? homeTab}) {
    final h = {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'X-Inertia': 'true',
      if (inertiaVersion != null) 'X-Inertia-Version': inertiaVersion,
      if (homeTab != null) 'X-Murrtube-Home-Tab': homeTab,
      'Referer': baseUrl,
      if (_cookieString != null) 'Cookie': _cookieString!,
    };
    netLog('--- headers ---');
    h.forEach((k, v) {
      if (k == 'Cookie') {
        netLog('Cookie: ${_maskCookie(v)}');
      } else {
        netLog('$k: $v');
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

  static Map<String, String> _htmlHeaders() => {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': baseUrl,
        if (_cookieString != null) 'Cookie': _cookieString!,
      };

  static Future<InertiaPage> _get(String path, {String? homeTab}) async {
    final uri = Uri.parse('$baseUrl$path');
    netLog('');
    netLog('=== MurrtubeApi._get $path ===');
    netLog('cookies set? ${hasCookies}');

    var response = await _client.get(
      uri,
      headers: _headers(inertiaVersion: _inertiaVersion, homeTab: homeTab),
    );
    var body = utf8.decode(response.bodyBytes);
    _updateCookiesFromResponse(response);
    netLog('First response status: ${response.statusCode}');

    bool authDenied() =>
        response.statusCode == 401 || response.statusCode == 403;

    // 409 = Inertia version mismatch; an HTML body means we got a full page
    // (or the age gate) instead of JSON. Re-extract the version and retry,
    // up to a few attempts since the '1' fallback may itself need a second
    // 409 to converge.
    for (var attempt = 0;
        attempt < 3 &&
            (response.statusCode != 200 || !body.startsWith('{')) &&
            !authDenied();
        attempt++) {
      netLog('Attempt ${attempt + 1} failed (${response.statusCode}), retrying...');
      if (body.isEmpty) {
        netLog('Body empty, fetching root page without Inertia headers...');
        final rootResp = await _client.get(
          Uri.parse(baseUrl),
          headers: _htmlHeaders(),
        );
        _updateCookiesFromResponse(rootResp);
        body = utf8.decode(rootResp.bodyBytes);
      }
      _inertiaVersion = _extractInertiaVersion(body) ?? '1';
      netLog('Extracted version: $_inertiaVersion');
      await _maybeBypassAgeCheck(body);
      response = await _client.get(
        uri,
        headers: _headers(inertiaVersion: _inertiaVersion, homeTab: homeTab),
      );
      _updateCookiesFromResponse(response);
      body = utf8.decode(response.bodyBytes);
      netLog('Retry response status: ${response.statusCode}');
      if (authDenied()) break;
    }

    if (response.statusCode != 200) {
      netLog('Final status code not 200, throwing.');
      if (isAuthenticated &&
          (response.statusCode == 401 || response.statusCode == 403)) {
        clearCookies();
        throw const SessionExpiredException();
      }
      throw HttpException('HTTP ${response.statusCode} for $path');
    }

    if (!body.startsWith('{')) {
      netLog('Body is not JSON after retries, throwing.');
      if (isAuthenticated && body.contains('sign_in')) {
        clearCookies();
        throw const SessionExpiredException();
      }
      throw FormatException('Expected JSON for $path, got HTML');
    }

    netLog('Parsing JSON response...');
    return InertiaPage.fromJson(jsonDecode(body));
  }

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (value is! List) return [];
    final out = <T>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) continue;
      try {
        out.add(parse(item));
      } catch (e) {
        netLog('Skipping malformed item: $e');
      }
    }
    return out;
  }

  static Pagination _pagination(dynamic value, int itemCount) =>
      value is Map<String, dynamic>
          ? Pagination.fromJson(value)
          : Pagination(page: 1, pages: 1, count: itemCount);

  static Future<void> _maybeBypassAgeCheck(String html) async {
    // Check if this is an age-check page
    if (!html.contains('age_check') && !html.contains('age-check')) return;

    // Extract CSRF token from meta tag
    final csrfRegex = RegExp(r'<meta name="csrf-token" content="([^"]+)"');
    final csrfMatch = csrfRegex.firstMatch(html);
    final csrfToken = csrfMatch?.group(1);
    if (csrfToken == null) {
      netLog('Age check detected but no CSRF token found');
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

    netLog('Age check detected. POSTing to: $ageUrl');
    final request = http.MultipartRequest('POST', Uri.parse(ageUrl))
      ..fields['authenticity_token'] = csrfToken;

    request.headers.addAll({
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': baseUrl,
      if (_cookieString != null) 'Cookie': _cookieString!,
    });

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    _updateCookiesFromResponse(response);
    netLog('Age check POST status: ${response.statusCode}');
  }

  static String? _versionFromDataPage(String raw) {
    try {
      final cleaned = raw
          .replaceAll('&quot;', '"')
          .replaceAll('\\"', '"')
          .replaceAll('\\n', '\n');
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded['version'] as String?;
      }
    } catch (e) {
      netLog('data-page parse failed: $e');
    }
    return null;
  }

  static String? _extractInertiaVersion(String html) {
    netLog('Extracting Inertia version from HTML (${html.length} chars)');
    // 1. data-page attribute (the protocol's own version field)
    for (final re in [
      RegExp(r'data-page="([^"]+)"'),
      RegExp(r"data-page='([^']+)'"),
    ]) {
      final m = re.firstMatch(html);
      if (m != null) {
        final v = _versionFromDataPage(m.group(1)!);
        if (v != null) {
          netLog('Found version via data-page: $v');
          return v;
        }
      }
    }
    // 2. HTML-escaped &quot;version&quot; in raw HTML
    final quotMatch =
        RegExp(r'&quot;version&quot;:&quot;([^&]+)&quot;').firstMatch(html);
    if (quotMatch != null) {
      final v = quotMatch.group(1);
      netLog('Found version via &quot; regex: $v');
      return v;
    }
    // 3. window.__inertia or similar script variable
    final scriptMatch = RegExp(
      r'window\.__inertia\s*=\s*\{[^}]*"version"\s*:\s*"([^"]+)"',
    ).firstMatch(html);
    if (scriptMatch != null) {
      final v = scriptMatch.group(1);
      netLog('Found version via script: $v');
      return v;
    }
    // 4. Bare "version":"x" JSON fragment. Checked last: it can also match a
    // version field nested inside page props rather than the protocol one.
    final match = RegExp(r'"version":"([^"]+)"').firstMatch(html);
    if (match != null) {
      final v = match.group(1);
      netLog('Found version via regex: $v');
      return v;
    }
    final dump = html.substring(0, html.length.clamp(0, 500));
    netLog('No version found. HTML snippet: $dump');
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
    final q = Uri(queryParameters: {'tab': tab, if (page != 1) 'page': '$page'}).query;
    final path = '/?$q';
    final inertia = await _get(path, homeTab: tab);
    final props = inertia.props;
    final mediaList = _parseList(props['media'], Media.fromJson);
    final pagination = _pagination(props['pagination'], mediaList.length);
    final announcements =
        _parseList(props['announcements'], Announcement.fromJson);
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
    final inertia = await _get('/v/${Uri.encodeComponent(shortCode)}');
    final props = inertia.props;
    final medium = Media.fromJson(props['medium'] as Map<String, dynamic>);
    final comments = _parseList(props['comments'], Comment.fromJson);
    final commentsPagination =
        _pagination(props['comments_pagination'], comments.length);
    final watchMore = _parseList(props['watch_more'], Media.fromJson);
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
    final mediaList = _parseList(props['media'], Media.fromJson);
    final users = _parseList(props['users'], User.fromJson);
    final tagMatches = _parseList(props['tag_matches'], Tag.fromJson);
    final pagination = _pagination(props['pagination'], mediaList.length);
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
    final response = await _client.get(
      Uri.parse('$baseUrl/search/suggest?q=$query'),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Referer': baseUrl,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for /search/suggest');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final users = _parseList(
      json['users'],
      (u) => (
        slug: u['slug'] as String? ?? '',
        name: u['name'] as String? ?? u['slug'] as String? ?? '',
        avatarUrl: u['avatar_url'] as String?,
      ),
    );
    final tags = _parseList(
      json['tags'],
      (t) => (
        name: t['name'] as String? ?? '',
        category: t['category'] as String? ?? 'general',
        count: t['count'] as int? ?? 0,
      ),
    );
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
    final items =
        _parseList(props['items'], NotificationItem.fromJson);
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
    var path = '/${Uri.encodeComponent(slug)}';
    if (tab != 'videos') path += '?tab=${Uri.encodeComponent(tab)}';
    if (page != 1) path += path.contains('?') ? '&page=$page' : '?page=$page';
    final inertia = await _get(path);
    final props = inertia.props;

    final profileRaw = props['profile'];
    if (profileRaw == null || profileRaw is! Map<String, dynamic>) {
      netLog('ProfilePage missing profile. Available props keys: ${props.keys.toList()}');
      throw Exception('User not found for slug: $slug');
    }
    final user = User.fromJson(profileRaw);

    final mediaList = _parseList(props['media'], Media.fromJson);
    final pagination = _pagination(props['pagination'], mediaList.length);
    final playlists = _parseList(props['playlists'], Playlist.fromJson);
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
    final response = await _client.put(
      Uri.parse('$baseUrl/users/${Uri.encodeComponent(slug)}/block'),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    netLog('blockUser status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> unblockUser(String slug) async {
    final token = await _fetchCsrfToken();
    final response = await _client.put(
      Uri.parse('$baseUrl/users/${Uri.encodeComponent(slug)}/unblock'),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    netLog('unblockUser status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> subscribeToUser(String slug) async {
    final token = await _fetchCsrfToken();
    final response = await _client.post(
      Uri.parse('$baseUrl/users/${Uri.encodeComponent(slug)}/follow'),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    netLog('subscribeToUser status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> unsubscribeFromUser(String slug) async {
    final token = await _fetchCsrfToken();
    final response = await _client.post(
      Uri.parse('$baseUrl/users/${Uri.encodeComponent(slug)}/unfollow'),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    netLog('unsubscribeFromUser status: ${response.statusCode}');
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

  // Like / Unlike
  static Future<String> _fetchCsrfToken() async {
    // The XSRF-TOKEN cookie may be stale. Fetch a fresh token from HTML.
    final response = await _client.get(
      Uri.parse(baseUrl),
      headers: _htmlHeaders(),
    );
    _updateCookiesFromResponse(response);
    final html = utf8.decode(response.bodyBytes);
    final match = RegExp(r'<meta name="csrf-token" content="([^"]+)"').firstMatch(html);
    final token = match?.group(1);
    netLog('Fetched CSRF token: ${token != null ? "${token.substring(0, token.length.clamp(0, 30))}..." : "NOT FOUND"}');
    if (token == null || token.isEmpty) {
      throw Exception('CSRF token not found in HTML');
    }
    return token;
  }

  static Future<void> likeVideo(String mediumId) async {
    final token = await _fetchCsrfToken();
    final response = await _client.post(
      Uri.parse('$baseUrl/likes'),
      headers: {
        'User-Agent': userAgent,
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
    netLog('likeVideo status: ${response.statusCode}');
    netLog('likeVideo response body: ${utf8.decode(response.bodyBytes)}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> postComment({required String mediumId, required String body}) async {
    final token = await _fetchCsrfToken();
    final response = await _client.post(
      Uri.parse('$baseUrl/comments'),
      headers: {
        'User-Agent': userAgent,
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
    netLog('postComment status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> deleteComment(String commentId) async {
    final token = await _fetchCsrfToken();
    final response = await _client.delete(
      Uri.parse('$baseUrl/comments/${Uri.encodeComponent(commentId)}'),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    netLog('deleteComment status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> replyToComment({required String mediumId, required String parentId, required String body}) async {
    final token = await _fetchCsrfToken();
    final response = await _client.post(
      Uri.parse('$baseUrl/comments'),
      headers: {
        'User-Agent': userAgent,
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
    netLog('replyToComment status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  static Future<void> unlikeVideo(String mediumId) async {
    final token = await _fetchCsrfToken();
    final response = await _client.delete(
      Uri.parse('$baseUrl/likes/$mediumId'),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Referer': baseUrl,
        'Origin': baseUrl,
        'X-Requested-With': 'XMLHttpRequest',
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    netLog('unlikeVideo status: ${response.statusCode}');
    netLog('unlikeVideo response body: ${utf8.decode(response.bodyBytes)}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
  }

  // Playlists
  static Future<List<Playlist>> getMyPlaylists() async {
    final token = await _fetchCsrfToken();
    final response = await _client.get(
      Uri.parse('$baseUrl/playlists/mine'),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Referer': baseUrl,
        'x-csrf-token': token,
        if (_cookieString != null) 'Cookie': _cookieString!,
      },
    );
    _updateCookiesFromResponse(response);
    final body = utf8.decode(response.bodyBytes);
    netLog('getMyPlaylists status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return _parseList(json['playlists'], Playlist.fromJson);
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
      'User-Agent': userAgent,
      'Accept': 'application/json',
      'Referer': baseUrl,
      'Origin': baseUrl,
      'X-Requested-With': 'XMLHttpRequest',
      'x-csrf-token': token,
      if (_cookieString != null) 'Cookie': _cookieString!,
    });

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    _updateCookiesFromResponse(response);
    final body = utf8.decode(response.bodyBytes);
    netLog('createPlaylist status: ${response.statusCode}');
    netLog('createPlaylist body: $body');
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
    var path = '/${Uri.encodeComponent(userSlug)}/p/${Uri.encodeComponent(playlistSlug)}';
    if (page != 1) path += '?page=$page';
    final inertia = await _get(path);
    final props = inertia.props;
    final playlist = Playlist.fromJson(props['playlist'] as Map<String, dynamic>);
    final mediaList = _parseList(props['items'], Media.fromJson);
    final pagination = _pagination(props['pagination'], mediaList.length);
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
      Uri.parse('$baseUrl/playlists/${Uri.encodeComponent(playlistId)}/items'),
    )
      ..fields['short_code'] = shortCode
      ..fields['medium_id'] = mediumId;
    request.headers.addAll({
      'User-Agent': userAgent,
      'Accept': 'application/json',
      'Referer': baseUrl,
      'Origin': baseUrl,
      'X-Requested-With': 'XMLHttpRequest',
      'x-csrf-token': token,
      if (_cookieString != null) 'Cookie': _cookieString!,
    });

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    _updateCookiesFromResponse(response);
    final body = utf8.decode(response.bodyBytes);
    netLog('addToPlaylist status: ${response.statusCode}');
    netLog('addToPlaylist body: $body');
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
    final response = await _client.post(
      Uri.parse('$baseUrl/tag_edits'),
      headers: {
        'User-Agent': userAgent,
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
    netLog('editTags status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return _parseList(json['tags'], Tag.fromJson);
  }

  // Sign out. Best-effort: the server session is invalidated if the endpoint
  // exists, and the local jar is always cleared.
  static Future<void> signOut() async {
    try {
      final token = await _fetchCsrfToken();
      for (final path in ['/sign_out', '/users/sign_out']) {
        final response = await _client.delete(
          Uri.parse('$baseUrl$path'),
          headers: {
            'User-Agent': userAgent,
            'Accept': 'application/json',
            'Referer': baseUrl,
            'Origin': baseUrl,
            'x-csrf-token': token,
            if (_cookieString != null) 'Cookie': _cookieString!,
          },
        );
        _updateCookiesFromResponse(response);
        netLog('signOut $path status: ${response.statusCode}');
        if (response.statusCode != 404) break;
      }
    } catch (e) {
      netLog('signOut request failed: $e');
    } finally {
      clearCookies();
      unawaited(CookieLoader.clear().catchError((Object _) {}));
    }
  }
}
