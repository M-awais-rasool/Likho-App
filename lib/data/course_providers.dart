import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/course_models.dart';
import 'repositories/course_repository.dart';

/// Swap for a network repository when the course API exists.
final courseRepositoryProvider = Provider<CourseRepository>((ref) => const AssetCourseRepository());

/// The whole course, loaded once (Splash starts loading it).
final courseProvider = FutureProvider<Course>((ref) => ref.watch(courseRepositoryProvider).loadCourse());
