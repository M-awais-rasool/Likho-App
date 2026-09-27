import 'dart:convert';
import 'dart:io';

import 'package:likho/data/models/course_models.dart';

/// The bundled course, parsed synchronously for tests.
final Course testCourse = Course.fromJson(jsonDecode(File('assets/data/course.json').readAsStringSync()) as Map<String, dynamic>);
