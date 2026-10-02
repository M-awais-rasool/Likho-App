import 'package:flutter/foundation.dart';

/// School classes, lowest first (the backend's domain.Grades). Every child
/// is in one (a parent picks it when adding the child) and every world of a
/// course is for one.
enum Grade {
  kg('kg', 'KG / Prep', 'ABC seekh rahe hain'),
  class1('class-1', 'Class 1', 'Chhote words likh lete hain'),
  class2('class-2', 'Class 2', 'Sentences likhte hain'),
  class3('class-3', 'Class 3', 'Kahani parh aur likh lete hain');

  const Grade(this.id, this.label, this.hint);

  /// The id in the API and the content ("kg", "class-1" …).
  final String id;

  /// What parents pick: "KG / Prep", "Class 1" …
  final String label;

  /// One line under the label for a parent who is not sure which to pick.
  final String hint;

  /// The class in a sentence: "KG", "Class 1" …
  String get short => this == kg ? 'KG' : label;

  /// The class after this one (null after the last).
  Grade? get next => index + 1 < values.length ? values[index + 1] : null;

  static Grade? byId(String? id) => values.where((g) => g.id == id).firstOrNull;

  /// The usual class at an age (5 KG … 8 Class 3), for children added
  /// before the app asked for the class.
  static Grade forAge(int age) => values[(age - 5).clamp(0, values.length - 1)];
}

/// A parent changes a child's class [grade] and the highest open class
/// [open] (the backend's domain.ChangeGrade): a new class opens only the
/// classes up to it, and [toOpen] opens classes up to it, never below the
/// class.
(Grade, Grade) changeGrade(Grade grade, Grade open, {Grade? to, Grade? toOpen}) {
  if (to != null && to != grade) (grade, open) = (to, to);
  if (toOpen != null && toOpen.index >= grade.index) open = toOpen;
  return (grade, open);
}

/// Where a map level is for one child.
enum Zone {
  /// A lower class: open for revision, never needed to go on.
  revision,

  /// The child's own class: played in order.
  mine,

  /// A higher class a parent opened: played in order after the child's class.
  opened,

  /// A higher class not opened yet.
  locked,
}

/// One child's map of a course by class: the same rule as the server's
/// domain.Ladder. Lower classes are revision (open in any order), the
/// child's class and classes a parent opened play in order from the first
/// level of the child's class, and higher classes stay locked.
@immutable
class ClassMap {
  /// [levelGrades] = the class of each map level (level n at n - 1). A
  /// course that starts above the child's class starts them at its first
  /// class.
  factory ClassMap(List<Grade> levelGrades, {required Grade grade, required Grade unlocked}) {
    final g = levelGrades.isNotEmpty && levelGrades.first.index > grade.index ? levelGrades.first : grade;
    return ClassMap._(levelGrades, g, unlocked.index > g.index ? unlocked : g);
  }

  const ClassMap._(this.levelGrades, this.grade, this.unlocked);

  final List<Grade> levelGrades;

  /// The child's class on this course, and the highest class open.
  final Grade grade, unlocked;

  int get length => levelGrades.length;

  Grade gradeOf(int n) => levelGrades[n - 1];

  Zone zoneOf(int n) {
    final g = gradeOf(n);
    if (g.index < grade.index) return Zone.revision;
    if (g.index > unlocked.index) return Zone.locked;
    return g == grade ? Zone.mine : Zone.opened;
  }

  /// The first level of the child's class (or of the next class that has
  /// levels); past the last level when the whole course is below them.
  int get start {
    for (var n = 1; n <= length; n++) {
      if (gradeOf(n).index >= grade.index) return n;
    }
    return length + 1;
  }

  /// The last level that is not locked.
  int get end {
    for (var n = length; n >= 1; n--) {
      if (gradeOf(n).index <= unlocked.index) return n;
    }
    return 0;
  }

  bool isUnlocked(int n, bool Function(int n) done) {
    if (n < 1 || n > length) return false;
    return switch (zoneOf(n)) {
      Zone.revision => true,
      Zone.locked => false,
      _ => n == start || done(n) || done(n - 1),
    };
  }

  /// First and last level of class [g], or null when the course has none.
  (int, int)? levelsOf(Grade g) {
    final first = levelGrades.indexOf(g), last = levelGrades.lastIndexOf(g);
    return first < 0 ? null : (first + 1, last + 1);
  }

  /// The classes this course has levels for, lowest first.
  List<Grade> get grades => [for (final g in Grade.values) if (levelGrades.contains(g)) g];
}
