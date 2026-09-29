import 'dart:convert';
import 'dart:io';

import 'package:likho/data/models/course_models.dart';

/// The course exactly as the API serves it: test/fixtures/english-handwriting.json,
/// generated from backend/content by `make content-fixture` (CI checks it is
/// up to date).
const testCourseFile = 'test/fixtures/english-handwriting.json';

/// The course, parsed synchronously for tests.
final Course testCourse = Course.fromJson(jsonDecode(File(testCourseFile).readAsStringSync()) as Map<String, dynamic>);
