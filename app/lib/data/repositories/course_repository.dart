import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/likho_api.dart';
import '../models/course_models.dart';

/// Where course content comes from. The app only talks to this interface.
abstract interface class CourseRepository {
  Future<Course> loadCourse();
}

/// The course (worlds, levels, rounds) comes from the backend
/// (GET /v1/courses/{id}, built from backend/content/courses/{id}/) and is
/// kept on the phone:
/// * first launch: downloaded (needs internet)
/// * later launches: the saved copy is used at once unless a newer version
///   arrives within [freshWait]; a newer version is saved for next time
/// * offline: the saved copy
/// The server's ETag means an unchanged course is never downloaded again.
class ApiCourseRepository implements CourseRepository {
  const ApiCourseRepository(this.api, this.files, {required this.courseId, this.freshWait = const Duration(milliseconds: 1500)});

  final LikhoApi api;
  final LocalFiles files;
  final String courseId;
  final Duration freshWait;

  String get _body => 'course.$courseId.json';
  String get _etag => 'course.$courseId.etag';

  @override
  Future<Course> loadCourse() async {
    final cached = await files.read(_body);
    final etag = cached == null ? null : await files.read(_etag);
    final fetch = _download(etag);

    if (cached == null) {
      final fresh = await fetch;
      if (fresh == null) throw const ApiException(500, 'course_unavailable', 'Course could not be loaded');
      return _parse(fresh);
    }
    try {
      final fresh = await fetch.timeout(freshWait);
      return await _parse(fresh ?? cached);
    } catch (_) {
      // slow or offline: play with the saved copy (the download keeps going
      // and saves a newer course for next time)
      unawaited(fetch.catchError((Object _) => null));
      return _parse(cached);
    }
  }

  /// Downloads the course if it changed; null = the saved copy is current.
  Future<String?> _download(String? etag) async {
    final (body, newTag) = await api.course(courseId, etag: etag);
    if (body == null) return null;
    await files.write(_body, body);
    await files.write(_etag, newTag);
    return body;
  }

  // parse off the UI thread; the file is ~200 KB
  static Future<Course> _parse(String text) => compute(_decode, text);
  static Course _decode(String text) => Course.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
