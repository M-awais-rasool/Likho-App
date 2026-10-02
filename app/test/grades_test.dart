import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/grades.dart';
import 'package:likho/data/progress.dart';
import 'package:likho/data/start_levels.dart';
import 'package:likho/design/tokens.dart';

import 'test_course.dart';

/// The same cases as the server's domain tests (backend/internal/domain/
/// grades_test.go): the app and the API must agree on every unlock.
void main() {
  final course = testCourse.levelGrades!;
  bool Function(int) doneUpTo(int last, [Set<int> also = const {}]) => (n) => also.contains(n) || (n >= 1 && n <= last);

  test('the course: KG 1-12, Class 1 13-24, Class 2 25-30, Class 3 31-36', () {
    expect(course.length, 36);
    expect([course[0], course[11], course[12], course[23], course[24], course[29], course[30], course[35]],
        [Grade.kg, Grade.kg, Grade.class1, Grade.class1, Grade.class2, Grade.class2, Grade.class3, Grade.class3]);
    expect(testCourse.worldsOf(Grade.kg).map((w) => w.name), ['Letter Land', 'Small Letter Cove']);
  });

  test('unlocks by class', () {
    final cases = [
      ('KG from the start: in order', Grade.kg, Grade.kg, doneUpTo(0), [1], [0, 2, 12, 13, 37]),
      ('KG after 2 levels', Grade.kg, Grade.kg, doneUpTo(2), [1, 2, 3], [4, 12]),
      ('KG finished: Class 1 waits for a parent', Grade.kg, Grade.kg, doneUpTo(12), [12], [13, 14]),
      ('KG with Class 1 opened', Grade.kg, Grade.class1, doneUpTo(12), [13], [14, 25]),
      ('Class 1 opened before KG is done: still in order', Grade.kg, Grade.class1, doneUpTo(5), [6], [7, 13]),
      ('Class 1: KG is revision, 13 is the start', Grade.class1, Grade.class1, doneUpTo(0), [1, 7, 12, 13], [14, 25]),
      ('Class 1 played on', Grade.class1, Grade.class1, doneUpTo(0, {13, 14}), [13, 14, 15, 5], [16, 24]),
      ('Class 3: everything below is revision', Grade.class3, Grade.class3, doneUpTo(0), [1, 24, 30, 31], [32]),
      ('moved down a class: higher levels lock, stars kept', Grade.kg, Grade.kg, doneUpTo(27), [1, 12], [13, 20, 27]),
    ];
    for (final (name, grade, open, done, unlocked, locked) in cases) {
      final m = ClassMap(course, grade: grade, unlocked: open);
      for (final n in unlocked) {
        expect(m.isUnlocked(n, done), isTrue, reason: '$name: level $n should be open');
      }
      for (final n in locked) {
        expect(m.isUnlocked(n, done), isFalse, reason: '$name: level $n should be locked');
      }
    }
  });

  test('zones, start, end and the levels of a class', () {
    final m = ClassMap(course, grade: Grade.class1, unlocked: Grade.class2);
    expect([m.zoneOf(1), m.zoneOf(13), m.zoneOf(25), m.zoneOf(31)], [Zone.revision, Zone.mine, Zone.opened, Zone.locked]);
    expect((m.start, m.end), (13, 30));
    expect((m.levelsOf(Grade.kg), m.levelsOf(Grade.class3)), ((1, 12), (31, 36)));
    expect(m.grades, Grade.values);
  });

  test('a course above or below the child', () {
    final l = [Grade.class1, Grade.class1, Grade.class1, Grade.class2, Grade.class2];
    final kg = ClassMap(l, grade: Grade.kg, unlocked: Grade.kg);
    expect((kg.grade, kg.unlocked), (Grade.class1, Grade.class1), reason: 'starts at the course\'s first class');
    expect([kg.isUnlocked(1, doneUpTo(0)), kg.isUnlocked(2, doneUpTo(0)), kg.isUnlocked(4, doneUpTo(3))], [true, false, false]);
    final big = ClassMap(l, grade: Grade.class3, unlocked: Grade.class3);
    expect(big.isUnlocked(5, doneUpTo(0)), isTrue, reason: 'all revision');
    expect(big.start, 6);
  });

  test('a parent changes the class (the server\'s ChangeGrade)', () {
    expect(changeGrade(Grade.kg, Grade.class1, to: Grade.kg), (Grade.kg, Grade.class1), reason: 'confirming keeps an opened class');
    expect(changeGrade(Grade.kg, Grade.class1, to: Grade.class1), (Grade.class1, Grade.class1), reason: 'a new class locks higher ones');
    expect(changeGrade(Grade.class2, Grade.class3, to: Grade.kg), (Grade.kg, Grade.kg));
    expect(changeGrade(Grade.kg, Grade.kg, toOpen: Grade.class1), (Grade.kg, Grade.class1));
    expect(changeGrade(Grade.kg, Grade.kg, to: Grade.class1, toOpen: Grade.class2), (Grade.class1, Grade.class2));
    expect(changeGrade(Grade.class1, Grade.class1, toOpen: Grade.kg), (Grade.class1, Grade.class1), reason: 'never below the class');
  });

  test('the warm-up starts a child above KG lower when the letters were hard', () {
    expect(StartLevels.afterWarmUp(testCourse, Grade.class1, 1)?.name, 'Small Letter Cove');
    expect(StartLevels.afterWarmUp(testCourse, Grade.class3, 1)?.name, 'Small Letter Cove', reason: 'the warm-up checks letters');
    expect(StartLevels.afterWarmUp(testCourse, Grade.class1, 2), isNull, reason: 'one or two mistakes are fine');
    expect(StartLevels.afterWarmUp(testCourse, Grade.kg, 1), isNull, reason: 'KG starts at level 1 anyway');
  });

  test('ages and ids', () {
    expect([for (final a in [5, 6, 7, 8, 3, 12]) Grade.forAge(a)], [Grade.kg, Grade.class1, Grade.class2, Grade.class3, Grade.kg, Grade.class3]);
    expect([Grade.byId('class-2'), Grade.byId('Class 2'), Grade.byId(null)], [Grade.class2, null, null]);
    expect([Grade.kg.short, Grade.class1.short, Grade.class3.next], ['KG', 'Class 1', null]);
  });

  group('where Pencil stands (current)', () {
    ChildProgress progress(Grade grade, Map<int, int> stars, {Grade? open, int? focus}) => ChildProgress(
      name: 'Zara',
      color: BodySwatch.options.first,
      stars: 0,
      levelStars: stars,
      map: ClassMap(course, grade: grade, unlocked: open ?? grade),
      focus: focus,
    );

    test('the first unfinished level of the child\'s class', () {
      expect(progress(Grade.kg, {}).current, 1);
      expect(progress(Grade.class1, {}).current, 13, reason: 'KG is revision, not where Pencil starts');
      expect(progress(Grade.class1, {13: 3, 14: 2}).current, 15);
    });

    test('a finished class: Pencil stays on its last level until a parent opens the next', () {
      final kg = {for (var n = 1; n <= 12; n++) n: 3};
      expect(progress(Grade.kg, kg).current, 12);
      expect(progress(Grade.kg, kg).finishedGrade(Grade.kg), isTrue);
      expect(progress(Grade.kg, kg, open: Grade.class1).current, 13);
    });

    test('the warm-up can start a child lower (letters were hard)', () {
      expect(progress(Grade.class1, {}, focus: 7).current, 7);
      expect(progress(Grade.class1, {for (var n = 7; n <= 12; n++) n: 2}, focus: 7).current, 13, reason: 'played past it');
      expect(progress(Grade.class1, {}, focus: 20).current, 13, reason: 'a start above the class start is ignored');
    });

    test('without classes (an old saved course) levels open in order', () {
      final p = ChildProgress(name: 'Zara', color: BodySwatch.options.first, stars: 0, levelStars: const {1: 3});
      expect((p.current, p.isUnlocked(2), p.isUnlocked(3)), (2, true, false));
    });
  });
}
