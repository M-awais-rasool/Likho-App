import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Where the Likho API is. Set at build time:
///   flutter run --dart-define=LIKHO_API=http://192.168.1.20:8080
/// Debug builds default to the API on this computer (the Android emulator
/// reaches it as 10.0.2.2); release builds to production.
abstract final class ApiConfig {
  static const _override = String.fromEnvironment('LIKHO_API');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kReleaseMode) return 'https://api.likho.io';
    return defaultTargetPlatform == TargetPlatform.android ? 'http://192.168.18.20:8080' : 'http://192.168.18.20:8080';
  }
}

/// An API answer that is not a success. [status] 0 = no connection.
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);
  const ApiException.offline() : status = 0, code = 'offline', message = 'No internet connection';

  final int status;
  final String code;
  final String message;

  bool get offline => status == 0;

  /// The server refused the request itself (a retry would get the same no).
  bool get rejected => status >= 400 && status < 500 && status != 401 && status != 408 && status != 429;

  @override
  String toString() => 'ApiException($status $code: $message)';
}

/// Keeps the refresh token in the Keychain / Android Keystore.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String refreshToken);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'likho.refreshToken';

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (e) {
      debugPrint('TokenStore: $e');
      return null;
    }
  }

  @override
  Future<void> write(String refreshToken) => _storage.write(key: _key, value: refreshToken);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

class MemoryTokenStore implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String refreshToken) async => token = refreshToken;
  @override
  Future<void> clear() async => token = null;
}

/// This build's version; keep it in step with `version:` in pubspec.yaml
/// (test/api_client_headers_test.dart checks it).
const appVersion = '0.1.0+7';

/// What every request says about the device, for the admin panel: the
/// platform, the app version and the region of the phone's language
/// setting (en_PK -> PK; the server prefers the IP's country when it has
/// a GeoIP database). Nothing that identifies the child.
Map<String, String> deviceHeaders() {
  final region = PlatformDispatcher.instance.locale.countryCode;
  return {
    'X-Likho-Platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'X-Likho-App-Version': appVersion,
    if (region != null && region.length == 2) 'X-Likho-Region': region,
  };
}

/// JSON over HTTP with the app's tokens:
/// * adds `Authorization: Bearer <access token>` to signed-in calls
/// * refreshes the access token when it runs out (once, shared by
///   concurrent calls) and repeats the call
/// * turns no connection / timeouts into [ApiException.offline]
/// * calls [onSessionLost] when the session cannot be refreshed any more
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokens, http.Client? client, this.timeout = const Duration(seconds: 15)})
    : _http = client ?? http.Client();

  final String baseUrl;
  final TokenStore tokens;
  final http.Client _http;
  final Duration timeout;

  /// Signed out by the server (refresh token revoked or expired).
  VoidCallback? onSessionLost;

  String? _access;
  DateTime _accessExpires = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _refreshing;

  /// Stores a new token pair (from sign-in or refresh).
  Future<void> setTokens(Map<String, dynamic> t) async {
    _access = t['accessToken'] as String;
    _accessExpires = DateTime.now().add(Duration(seconds: (t['expiresIn'] as num).toInt()));
    await tokens.write(t['refreshToken'] as String);
  }

  Future<void> clearTokens() async {
    _access = null;
    await tokens.clear();
  }

  /// Signs back in with the saved refresh token. False when there is none
  /// or it was refused (offline counts as true: the session is kept).
  Future<bool> restore() async {
    final saved = await tokens.read();
    if (saved == null) return false;
    try {
      await _refresh();
      return true;
    } on ApiException catch (e) {
      if (e.offline) return true;
      return false;
    }
  }

  Future<void> _refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<void> _doRefresh() async {
    final saved = await tokens.read();
    if (saved == null) throw const ApiException(401, 'session_invalid', 'Sign in again');
    try {
      final r = await request('POST', '/v1/auth/refresh', body: {'refreshToken': saved}, auth: false);
      await setTokens(r as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (!e.offline) {
        await clearTokens();
        onSessionLost?.call();
      }
      rethrow;
    }
  }

  /// Sends a request and returns the decoded JSON (null for an empty body).
  Future<Object?> request(String method, String path, {Object? body, bool auth = true, Map<String, String> headers = const {}}) async {
    if (auth && (_access == null || DateTime.now().isAfter(_accessExpires.subtract(const Duration(seconds: 30))))) {
      await _refresh();
    }
    var res = await _send(method, path, body, auth, headers);
    if (auth && res.statusCode == 401) {
      await _refresh();
      res = await _send(method, path, body, auth, headers);
    }
    return _decode(res);
  }

  /// A signed-in GET that keeps the body as text, for ETag handling: (status,
  /// body, ETag). A 304 is not an error.
  Future<(int, String?, String)> requestRaw(String method, String path, {Map<String, String> headers = const {}}) async {
    if (_access == null || DateTime.now().isAfter(_accessExpires.subtract(const Duration(seconds: 30)))) {
      await _refresh();
    }
    var res = await _send(method, path, null, true, headers);
    if (res.statusCode == 401) {
      await _refresh();
      res = await _send(method, path, null, true, headers);
    }
    if (res.statusCode == 304) return (304, null, res.headers['etag'] ?? '');
    _decode(res); // throws on errors
    return (res.statusCode, utf8.decode(res.bodyBytes), res.headers['etag'] ?? '');
  }

  /// A raw GET (for ETag handling), without auth.
  Future<http.Response> getRaw(String path, {Map<String, String> headers = const {}}) => _send('GET', path, null, false, headers);

  Future<http.Response> _send(String method, String path, Object? body, bool auth, Map<String, String> headers) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers.addAll({'Accept': 'application/json', ...deviceHeaders(), ...headers});
    if (auth && _access != null) req.headers['Authorization'] = 'Bearer $_access';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      return await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } on TimeoutException {
      throw const ApiException.offline();
    } on http.ClientException {
      throw const ApiException.offline();
    } catch (e) {
      // SocketException / HandshakeException etc. (dart:io, not imported
      // here so the client also compiles for the web)
      if (e is ApiException) rethrow;
      throw const ApiException.offline();
    }
  }

  static Object? _decode(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    Object? json;
    if (res.body.isNotEmpty) {
      try {
        json = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        json = null;
      }
    }
    if (ok) return json;
    final m = json is Map ? json : const {};
    throw ApiException(res.statusCode, (m['error'] as String?) ?? 'http_${res.statusCode}', (m['message'] as String?) ?? 'Request failed');
  }
}
