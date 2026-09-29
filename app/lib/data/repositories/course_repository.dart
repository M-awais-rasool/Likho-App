import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/course_models.dart';

/// Where course content comes from. The app only talks to this interface.
///
/// Today: [AssetCourseRepository] reads assets/data/course.json (static data
/// in the API's exact shape). Later: an `ApiCourseRepository` that GETs the
/// same JSON (e.g. `/v1/courses/likho-english-v1`), caches it, and falls back
/// to the bundled file offline. Swap it in `courseRepositoryProvider`.
abstract interface class CourseRepository {
  Future<Course> loadCourse();
}

class AssetCourseRepository implements CourseRepository {
  const AssetCourseRepository({this.asset = 'assets/data/course.json', this.bundle});
  final String asset;
  final AssetBundle? bundle;

  @override
  Future<Course> loadCourse() async {
    final text = await (bundle ?? rootBundle).loadString(asset);
    // parse off the UI thread; the file is ~200 KB
    return compute(_parse, text);
  }

  static Course _parse(String text) => Course.fromJson(jsonDecode(text) as Map<String, dynamic>);
}
