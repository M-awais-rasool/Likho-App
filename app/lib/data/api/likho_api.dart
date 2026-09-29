import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

/// Every call the app makes to the Likho API (backend/README.md), returning
/// decoded JSON.
class LikhoApi {
  LikhoApi(this.client);
  final ApiClient client;

  Map<String, dynamic> _map(Object? v) => (v as Map).cast<String, dynamic>();

  // ------------------------------------------------------------ account
  /// "Continue with Google": creates the account the first time, continues
  /// it afterwards. Stores the tokens. Returns {isNewAccount, me, …}.
  Future<Map<String, dynamic>> signInWithGoogle(String idToken, {String device = ''}) async {
    final r = _map(await client.request('POST', '/v1/auth/google', body: {'idToken': idToken, 'device': device}, auth: false));
    await client.setTokens(r);
    return r;
  }

  Future<void> logout() async {
    try {
      await client.request('POST', '/v1/auth/logout');
    } on ApiException catch (_) {
      // signing out on the phone works offline too
    }
    await client.clearTokens();
  }

  Future<Map<String, dynamic>> me() async => _map(await client.request('GET', '/v1/me'));

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> patch) async =>
      _map(await client.request('PATCH', '/v1/me/settings', body: patch));

  Future<Map<String, dynamic>> startTrial() async => _map(await client.request('POST', '/v1/me/trial'));

  Future<void> deleteAccount() async {
    await client.request('DELETE', '/v1/me');
    await client.clearTokens();
  }

  // ------------------------------------------------------------ children
  Future<Map<String, dynamic>> createChild({required String name, required int age, required String color}) async =>
      _map(await client.request('POST', '/v1/children', body: {'name': name, 'age': age, 'color': color}));

  Future<Map<String, dynamic>> updateChild(String id, {String? name, int? age, String? color}) async => _map(
    await client.request('PATCH', '/v1/children/$id', body: {'name': ?name, 'age': ?age, 'color': ?color}),
  );

  Future<void> deleteChild(String id) => client.request('DELETE', '/v1/children/$id');

  /// A finished level of [courseId]. [key] makes retries safe (stars are
  /// awarded once).
  Future<Map<String, dynamic>> recordResult(
    String childId, {
    required String courseId,
    required int level,
    required int stars,
    required int seconds,
    required String key,
  }) async => _map(
        await client.request(
          'POST',
          '/v1/children/$childId/courses/$courseId/results',
          body: {'level': level, 'stars': stars, 'seconds': seconds},
          headers: {'Idempotency-Key': key},
        ),
      );

  /// A Mascot Room tap (buy / wear / place …) → the room after it.
  Future<Map<String, dynamic>> tapItem(String childId, String itemId) async =>
      _map(await client.request('POST', '/v1/children/$childId/room/$itemId'));

  /// The courses the server offers (GET /v1/courses).
  Future<List<Map<String, dynamic>>> courses() async => [
    for (final c in _map(await client.request('GET', '/v1/courses', auth: false))['courses'] as List) _map(c),
  ];

  // ------------------------------------------------------------ course
  /// A whole course as JSON, or null when the phone already has version
  /// [etag].
  Future<(String?, String)> course(String courseId, {String? etag}) async {
    final res = await client.getRaw('/v1/courses/$courseId', headers: {'If-None-Match': ?etag});
    if (res.statusCode == 304) return (null, etag ?? '');
    if (res.statusCode != 200) throw ApiException(res.statusCode, 'course_unavailable', 'Course could not be loaded');
    return (utf8.decode(res.bodyBytes), res.headers['etag'] ?? '');
  }
}

/// Small files the app keeps between launches (the course, the last account
/// snapshot, results waiting to be sent). Missing storage (tests) is
/// treated as empty.
class LocalFiles {
  const LocalFiles([this.dirOverride]);
  final Directory? dirOverride;

  Future<File?> _file(String name) async {
    try {
      final dir = dirOverride ?? await getApplicationSupportDirectory();
      return File('${dir.path}/$name');
    } catch (_) {
      return null;
    }
  }

  Future<String?> read(String name) async {
    final f = await _file(name);
    try {
      return f != null && f.existsSync() ? await f.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String name, String text) async {
    final f = await _file(name);
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      await f.writeAsString(text, flush: true);
    } catch (e) {
      debugPrint('LocalFiles.write $name: $e');
    }
  }

  Future<void> delete(String name) async {
    final f = await _file(name);
    try {
      if (f != null && f.existsSync()) await f.delete();
    } catch (_) {}
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => const SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(baseUrl: ApiConfig.baseUrl, tokens: ref.watch(tokenStoreProvider)));

final apiProvider = Provider<LikhoApi>((ref) => LikhoApi(ref.watch(apiClientProvider)));

final localFilesProvider = Provider<LocalFiles>((ref) => const LocalFiles());
