import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A captured HTTP request made through [FakeHttpClient].
class FakeRequest {
  final String method;
  final Uri uri;
  final Map<String, List<String>> headers;
  final List<int> bodyBytes;

  FakeRequest(this.method, this.uri, this.headers, this.bodyBytes);

  String get body => utf8.decode(bodyBytes);

  String? header(String name) => headers[name.toLowerCase()]?.join(',');
}

/// A canned response returned by [FakeServer].
class FakeResponse {
  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;

  const FakeResponse(
    this.statusCode,
    this.body, [
    this.headers = const <String, List<String>>{},
  ]);

  factory FakeResponse.json(
    Map<String, dynamic> json, {
    int status = 200,
    Map<String, List<String>> headers = const {},
  }) {
    return FakeResponse(status, jsonEncode(json), {
      'content-type': ['application/json; charset=utf-8'],
      ...headers,
    });
  }

  /// Wraps [props] in an Inertia page envelope like the real server returns.
  factory FakeResponse.inertia(
    String component,
    Map<String, dynamic> props, {
    int status = 200,
    Map<String, List<String>> headers = const {},
  }) {
    return FakeResponse.json(
      {
        'component': component,
        'props': props,
        'url': '/',
        'version': 'test-version',
      },
      status: status,
      headers: headers,
    );
  }

  /// An HTML page containing a CSRF meta tag, like murrtube.net serves.
  factory FakeResponse.htmlPage({
    String? inertiaVersion,
    bool ageCheck = false,
  }) {
    final buffer = StringBuffer(
      '<!DOCTYPE html><html><head>'
      '<meta name="csrf-token" content="fake-csrf-token-123">',
    );
    if (inertiaVersion != null) {
      buffer.write(
        '<script type="application/json">'
        '{"version":"$inertiaVersion"}'
        '</script>',
      );
    }
    if (ageCheck) {
      buffer.write(
        '</head><body>'
        '<form action="/age_check" method="post" class="age_check">'
        '</form></body></html>',
      );
    } else {
      buffer.write('</head><body></body></html>');
    }
    return FakeResponse(200, buffer.toString(), {
      'content-type': ['text/html; charset=utf-8'],
    });
  }
}

typedef FakeHandler = FutureOr<FakeResponse> Function(FakeRequest request);

class _Route {
  final String method;
  final Pattern pattern;
  final bool Function(Uri uri)? matchQuery;
  final FakeHandler handler;

  _Route(this.method, this.pattern, this.handler, this.matchQuery);

  bool matches(FakeRequest request) {
    if (method != request.method) return false;
    // Uri.parse('https://host') yields an empty path; treat as '/'.
    final path = request.uri.path.isEmpty ? '/' : request.uri.path;
    final p = pattern;
    final pathMatches = p is String ? p == path : (p as RegExp).hasMatch(path);
    if (!pathMatches) return false;
    if (matchQuery != null && !matchQuery!(request.uri)) return false;
    return true;
  }
}

/// Routes fake HTTP traffic. Register handlers with [on]; the first matching
/// route wins. Requests that match nothing return [fallback] or a 404.
class FakeServer {
  final List<_Route> _routes = [];
  final List<FakeRequest> requests = [];

  /// Called when no route matches. Defaults to a 404 JSON error.
  FakeHandler? fallback;

  void on(
    String method,
    Pattern path,
    FakeHandler handler, {
    bool Function(Uri uri)? matchQuery,
  }) {
    _routes.add(_Route(method, path, handler, matchQuery));
  }

  void onGet(
    Pattern path,
    FakeHandler handler, {
    bool Function(Uri uri)? matchQuery,
  }) => on('GET', path, handler, matchQuery: matchQuery);

  void onPost(Pattern path, FakeHandler handler) => on('POST', path, handler);

  void onPut(Pattern path, FakeHandler handler) => on('PUT', path, handler);

  void onDelete(Pattern path, FakeHandler handler) =>
      on('DELETE', path, handler);

  Future<FakeResponse> dispatch(FakeRequest request) async {
    requests.add(request);
    for (final route in _routes) {
      if (route.matches(request)) {
        return await route.handler(request);
      }
    }
    if (fallback != null) return await fallback!(request);
    return FakeResponse.json({'error': 'no route'}, status: 404);
  }

  /// All requests sent to [path] (query ignored).
  List<FakeRequest> requestsTo(String path) => requests
      .where((r) => (r.uri.path.isEmpty ? '/' : r.uri.path) == path)
      .toList();
}

/// Installs [server] as the process-wide HTTP backend. Returns the server.
FakeServer installFakeHttp([FakeServer? server]) {
  final s = server ?? FakeServer();
  HttpOverrides.global = _FakeHttpOverrides(s);
  return s;
}

class _FakeHttpOverrides extends HttpOverrides {
  final FakeServer server;
  _FakeHttpOverrides(this.server);

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      FakeHttpClient(server);
}

class FakeHttpClient implements HttpClient {
  final FakeServer server;
  bool _closed = false;

  FakeHttpClient(this.server);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (_closed) {
      throw const HttpException('client closed');
    }
    return FakeHttpClientRequest(method, url, server);
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  final FakeServer _server;
  final _headers = FakeHttpHeaders();
  final _body = <int>[];

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  bool bufferOutput = true;

  FakeHttpClientRequest(this.method, this.uri, this._server);

  @override
  HttpHeaders get headers => _headers;

  @override
  void add(List<int> data) => _body.addAll(data);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.addAll(chunk);
    }
  }

  @override
  void write(Object? object) {
    _body.addAll(utf8.encode(object.toString()));
  }

  @override
  Future<HttpClientResponse> close() async {
    final request = FakeRequest(method, uri, _headers._values, _body);
    final response = await _server.dispatch(request);
    return FakeHttpClientResponse(response);
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  Future<HttpClientResponse> get done => close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final FakeResponse _response;
  late final FakeHttpHeaders _headers;

  FakeHttpClientResponse(this._response) {
    _headers = FakeHttpHeaders();
    _response.headers.forEach((key, values) {
      for (final v in values) {
        _headers.add(key, v);
      }
    });
  }

  @override
  int get statusCode => _response.statusCode;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _responseBodyBytes.length;

  List<int> get _responseBodyBytes => utf8.encode(_response.body);

  @override
  HttpHeaders get headers => _headers;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_responseBodyBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<Socket> detachSocket() => throw UnsupportedError('no socket');

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => []).add('$value');
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = ['$value'];
  }

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  String? value(String name) {
    final v = _values[name.toLowerCase()];
    return v == null || v.isEmpty ? null : v.join(',');
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  void remove(String name, Object value) {
    _values[name.toLowerCase()]?.remove('$value');
  }

  @override
  void removeAll(String name) {
    _values.remove(name.toLowerCase());
  }

  @override
  void noFolding(String name) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
