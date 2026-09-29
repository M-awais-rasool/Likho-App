import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/likho_api.dart';
import 'models/course_models.dart';
import 'repositories/course_repository.dart';

/// The course this app plays: `backend/content/courses/<id>/` on the server.
/// Each child's progress is kept per course.
const appCourseId = 'english-handwriting';

/// The course comes from the backend and is kept on the phone.
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => ApiCourseRepository(ref.watch(apiProvider), ref.watch(localFilesProvider), courseId: appCourseId),
);

/// The whole course, loaded once (Splash starts loading it).
final courseProvider = FutureProvider<Course>((ref) => ref.watch(courseRepositoryProvider).loadCourse());
