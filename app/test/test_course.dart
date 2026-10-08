import 'dart:convert';
import 'dart:io';

import 'package:likho/data/models/course_models.dart';

/// The course exactly as the API serves it: test/fixtures/english-handwriting.json,
/// generated from backend/content by `make content-fixture` (CI checks it is
/// up to date).
const testCourseFile = 'test/fixtures/english-handwriting.json';

/// The course, parsed synchronously for tests.
final Course testCourse = Course.fromJson(jsonDecode(File(testCourseFile).readAsStringSync()) as Map<String, dynamic>);

/// The first level with a round that passes [test].
CourseLevel levelWith(bool Function(Round r) test) => testCourse.levels.firstWhere((l) => l.rounds.any(test));

/// [level] with only the rounds that pass [keep] (e.g. a level of picks).
CourseLevel onlyRounds(CourseLevel level, bool Function(Round r) keep) => levelWithRounds(level, level.rounds.where(keep).toList());

/// [level] playing [rounds] instead of its own.
CourseLevel levelWithRounds(CourseLevel level, List<Round> rounds) => CourseLevel(
  id: level.id,
  number: level.number,
  worldId: level.worldId,
  placement: level.placement,
  name: level.name,
  skill: level.skill,
  icon: level.icon,
  isBoss: level.isBoss,
  requiresSubscription: level.requiresSubscription,
  intro: level.intro,
  presentation: level.presentation,
  rounds: rounds,
);

/// Picks whose right answer shows its label (tests tap it by its text).
bool labelledPick(Round r) => r is PickRound && r.options.every((o) => !o.hideLabel);
