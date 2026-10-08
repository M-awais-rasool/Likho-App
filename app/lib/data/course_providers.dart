import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/likho_api.dart';
import 'media.dart';
import 'models/course_models.dart';
import 'repositories/course_repository.dart';

/// The course this app plays: `backend/content/courses/<id>/` on the server.
/// Each child's progress is kept per course.
const appCourseId = 'english-handwriting';

/// The course comes from the backend and is kept on the phone.
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => ApiCourseRepository(ref.watch(apiProvider), ref.watch(localFilesProvider), courseId: appCourseId),
);

/// The whole course, loaded once (Splash starts loading it), with the
/// media manifest (which picture and recording is which file on the server).
final courseProvider = FutureProvider<Course>((ref) async {
  final (course, _) = await (ref.watch(courseRepositoryProvider).loadCourse(), ref.read(mediaProvider).load()).wait;
  return course;
});
