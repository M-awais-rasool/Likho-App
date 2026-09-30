import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:likho/data/api/api_client.dart';
import 'package:likho/data/api/likho_api.dart';
import 'package:likho/data/auth.dart';
import 'package:likho/data/course_providers.dart';

import 'test_course.dart';

/// A tiny in-memory Likho API (same JSON as backend/README.md) for tests:
/// one parent, Google sign-in, children, results with Idempotency-Key and
/// the room. [offline] makes every call fail like a phone without internet.
class FakeBackend {
  bool offline = false;
  bool newAccount = true;
  final List<String> calls = [];

  /// The ID tokens sign-ins sent (Google's, or `dev:<email>` for the test user).
  final List<String> idTokens = [];
  final Map<String, Map<String, dynamic>> _results = {}; // idempotency key -> answer

  Map<String, dynamic> settings = {'sessionMinutes': 10, 'music': true, 'sfx': true, 'haptics': true, 'leftHanded': false, 'reduceMotion': false};
  Map<String, dynamic> subscription = {'active': false, 'plusUntil': null, 'trialUsed': false};
  final List<Map<String, dynamic>> children = [];
  int _ids = 0, _tokens = 0;
  String? _refresh;

  static const prices = {'party': 8, 'plant': 8, 'rug': 16, 'crown': 40, 'lamp': 10};

  Map<String, dynamic> me() => {
    'account': {'id': 'acc1', 'email': 'ammi@gmail.com', 'name': 'Ammi', 'pictureUrl': ''},
    'settings': settings,
    'subscription': subscription,
    'children': children,
  };

  Map<String, dynamic> addChild(String name, {int age = 6, String color = '#FFC83D', int stars = 0, Map<String, int> levels = const {}}) {
    final c = {
      'id': 'c${++_ids}',
      'name': name,
      'age': age,
      'color': color,
      'stars': stars,
      'wearing': null,
      'owned': <String>[],
      'room': <String>[],
      'progress': {
        appCourseId: {
          'levelStars': {for (final e in levels.entries) e.key: e.value},
        },
      },
      'daysPlayed': 0,
      'minutesThisWeek': 0,
    };
    children.add(c);
    return c;
  }

  Map<String, dynamic> _tokenPair() {
    _refresh = 'r${++_tokens}';
    return {'accessToken': 'a$_tokens', 'expiresIn': 900, 'refreshToken': _refresh};
  }

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request req) async {
    if (offline) throw http.ClientException('offline');
    final path = req.url.path;
    calls.add('${req.method} $path');
    final body = req.body.isEmpty ? const <String, dynamic>{} : (jsonDecode(req.body) as Map).cast<String, dynamic>();
    http.Response json(Object? v, [int status = 200]) =>
        http.Response.bytes(utf8.encode(jsonEncode(v)), status, headers: {'content-type': 'application/json; charset=utf-8'});
    http.Response error(int status, String code) => json({'error': code, 'message': code}, status);
    Map<String, dynamic>? child(String id) => children.where((c) => c['id'] == id).firstOrNull;

    final seg = path.split('/').where((s) => s.isNotEmpty).toList(); // v1, …
    switch ((req.method, seg.skip(1).toList())) {
      case ('POST', ['auth', 'google']):
        idTokens.add(body['idToken'] as String);
        final isNew = newAccount;
        newAccount = false;
        return json({..._tokenPair(), 'isNewAccount': isNew, 'me': me()}, isNew ? 201 : 200);
      case ('POST', ['auth', 'refresh']):
        if (body['refreshToken'] != _refresh) return error(401, 'session_invalid');
        return json(_tokenPair());
      case ('POST', ['auth', 'logout']):
        _refresh = null;
        return http.Response('', 204);
      case ('GET', ['me']):
        return json(me());
      case ('PATCH', ['me', 'settings']):
        settings = {...settings, ...body};
        return json(settings);
      case ('POST', ['me', 'trial']):
        if (subscription['trialUsed'] == true) return error(409, 'trial_used');
        subscription = {'active': true, 'plusUntil': '2026-10-06T00:00:00Z', 'trialUsed': true};
        return json(subscription);
      case ('GET', ['courses']):
        return json({
          'courses': [
            {'id': appCourseId, 'title': 'English Handwriting', 'version': 'v1'},
          ],
        });
      case ('GET', ['courses', final id]):
        if (id != appCourseId) return error(404, 'course_not_found');
        final etag = '"v1"';
        if (req.headers['If-None-Match'] == etag) return http.Response('', 304);
        return http.Response.bytes(File(testCourseFile).readAsBytesSync(), 200, headers: {'etag': etag});
      case ('POST', ['children']):
        if (children.length >= 4) return error(409, 'too_many_children');
        return json(addChild(body['name'] as String, age: body['age'] as int, color: body['color'] as String), 201);
      case ('PATCH', ['children', final id]):
        final c = child(id);
        if (c == null) return error(404, 'not_found');
        c.addAll(body);
        return json(c);
      case ('DELETE', ['children', final id]):
        if (children.length == 1) return error(409, 'last_child');
        children.removeWhere((c) => c['id'] == id);
        return http.Response('', 204);
      case ('POST', ['children', final id, 'courses', final courseId, 'results']):
        if (courseId != appCourseId) return error(404, 'course_not_found');
        final key = req.headers['Idempotency-Key'] ?? '';
        if (_results[key] case final done?) return json(done);
        final c = child(id);
        if (c == null) return error(404, 'not_found');
        final level = body['level'] as int, stars = body['stars'] as int;
        final best = (((c['progress'] as Map)[appCourseId] as Map)['levelStars'] as Map).cast<String, int>();
        bool done(int n) => best.containsKey('$n');
        if (level > 1 && !done(level) && !done(level - 1)) return error(409, 'level_locked');
        final old = best['$level'];
        final gain = old == null ? stars + 2 : math.max(0, stars - old);
        best['$level'] = math.max(stars, old ?? 0);
        c['stars'] = (c['stars'] as int) + gain;
        final answer = {'courseId': courseId, 'level': level, 'stars': stars, 'bestStars': best['$level'], 'gain': gain, 'firstTime': old == null, 'totalStars': c['stars']};
        _results[key] = answer;
        return json(answer, 201);
      case ('POST', ['children', final id, 'room', final item]):
        final c = child(id)!;
        final owned = (c['owned'] as List).cast<String>();
        if (!owned.contains(item)) {
          final price = prices[item] ?? 0;
          if ((c['stars'] as int) < price) return error(409, 'not_enough_stars');
          c['stars'] = (c['stars'] as int) - price;
          owned.add(item);
        }
        return json({'action': 'buy', 'stars': c['stars'], 'wearing': c['wearing'], 'owned': owned, 'room': c['room']});
    }
    return error(404, 'not_found');
  }
}

/// Files kept in memory (real file IO does not finish inside widget tests'
/// fake time).
class MemoryFiles extends LocalFiles {
  MemoryFiles();
  final Map<String, String> files = {};
  @override
  Future<String?> read(String name) async => files[name];
  @override
  Future<void> write(String name, String text) async => files[name] = text;
  @override
  Future<void> delete(String name) async => files.remove(name);
}

/// Signs in with any Google account (the fake backend accepts every token).
class FakeGoogle implements GoogleIdentity {
  bool cancel = false;
  @override
  Future<String?> idToken() async => cancel ? null : 'google-token';
  @override
  Future<void> signOut() async {}
}

/// Provider overrides that point the app at [backend], keep files in a
/// memory and use [google] for sign-in. The course comes from the
/// repo copy unless [realCourse] (then it goes through the API).
List<Override> fakeBackendOverrides(FakeBackend backend, {FakeGoogle? google, bool realCourse = false, LocalFiles? files, TokenStore? tokens}) {
  files ??= MemoryFiles();
  tokens ??= MemoryTokenStore();
  return [
    apiClientProvider.overrideWith((ref) => ApiClient(baseUrl: 'http://fake', tokens: tokens!, client: backend.client)),
    localFilesProvider.overrideWithValue(files),
    googleIdentityProvider.overrideWithValue(google ?? FakeGoogle()),
    if (!realCourse) courseProvider.overrideWith((ref) async => testCourse),
  ];
}
