import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'course_providers.dart';
import 'family.dart';
import 'grades.dart';
import 'shop_items.dart';
import 'start_levels.dart';

/// One child's progress. Stars per finished level (1..3), and the course's
/// levels by class for this child ([map]).
@immutable
class ChildProgress {
  const ChildProgress({
    required this.name,
    required this.color,
    required this.stars,
    required this.levelStars,
    this.accessory,
    this.map,
    this.levelCount = 36,
    this.focus,
  });

  final String name;
  final BodySwatch color;
  final int stars;
  final Map<int, int> levelStars;
  final String? accessory;

  /// Revision, own class, opened and locked levels (null while the course
  /// loads, or for a saved copy from before classes: levels open in order).
  final ClassMap? map;

  /// Map levels in the course.
  final int levelCount;

  /// A level below the child's class the warm-up suggested starting at.
  final int? focus;

  bool isDone(int n) => levelStars.containsKey(n);
  bool isUnlocked(int n) => map?.isUnlocked(n, isDone) ?? (n <= 1 || isDone(n - 1) || isDone(n));
  Zone zoneOf(int n) => map?.zoneOf(n) ?? Zone.mine;

  /// Where Pencil stands and the map opens: the first open level not
  /// finished yet, from the start of the child's class (or the warm-up's
  /// [focus] below it); the last open level once all are finished.
  int get current {
    final m = map;
    final last = m?.end ?? levelCount;
    var from = m == null || m.start > m.length ? 1 : m.start;
    if (focus case final f? when f >= 1 && f < from) from = f;
    for (var n = from; n <= last; n++) {
      if (!isDone(n) && isUnlocked(n)) return n;
    }
    return math.max(1, last);
  }

  /// Every level of class [g] is finished.
  bool finishedGrade(Grade g) {
    final r = map?.levelsOf(g);
    if (r == null) return false;
    for (var n = r.$1; n <= r.$2; n++) {
      if (!isDone(n)) return false;
    }
    return true;
  }

  /// The certificate earned by finishing [level] for the first time
  /// ([firstTime]): the whole course once every level is done (grade
  /// null), else the level's class once all of it is done, unless that
  /// class is revision. Null when there is none.
  ({Grade? grade})? certificateFor(int level, {required bool firstTime}) {
    if (!firstTime || !isDone(level)) return null;
    if (levelStars.length >= levelCount && levelCount > 0) return (grade: null);
    final m = map;
    if (m == null || level > m.length || m.zoneOf(level) == Zone.revision) return null;
    final g = m.gradeOf(level);
    return finishedGrade(g) ? (grade: g) : null;
  }
}

/// The active child's progress, read from [familyProvider] (the child picked
/// on "Who's playing") and the course's classes.
class ProgressNotifier extends Notifier<ChildProgress> {
  @override
  ChildProgress build() {
    final f = ref.watch(familyProvider);
    final course = ref.watch(courseProvider).value;
    final start = StartLevels.lookup(ref.watch(startLevelsProvider), f.active.id);
    final r = f.record, p = f.active;
    final grades = course?.levelGrades;
    return ChildProgress(
      name: p.name,
      color: p.swatch,
      stars: r.stars,
      levelStars: r.levelStars,
      accessory: ShopItem.byId(r.wearing)?.accessory,
      map: grades == null ? null : ClassMap(grades, grade: p.grade, unlocked: p.unlockedGrade),
      levelCount: course?.levels.length ?? 36,
      focus: start,
    );
  }

  /// A level was finished (prototype finish()); see [FamilyNotifier.recordResult].
  void recordResult(int level, int stars) => ref.read(familyProvider.notifier).recordResult(level, stars);
}

final progressProvider = NotifierProvider<ProgressNotifier, ChildProgress>(ProgressNotifier.new);
