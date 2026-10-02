import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/grades.dart';
import 'package:likho/data/progress.dart';
import 'package:likho/data/school_year.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/dev/dev_launch.dart';
import 'package:likho/game/writing/writing_judge.dart';
import 'package:likho/screens/app_flow.dart';
import 'package:likho/screens/certificate/certificate_screen.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/level_complete/level_complete_screen.dart';
import 'package:likho/screens/parent/parent_gate.dart';
import 'package:likho/screens/parent/parent_widgets.dart';
import 'package:likho/screens/world_map/map_geometry.dart';
import 'package:likho/screens/world_map/world_map_screen.dart';

import 'test_course.dart';

/// Classes on the map and in the parents' screens (backend rules: see
/// grades_test.dart).

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 3));
}

Future<void> _passGate(WidgetTester t) async {
  final q = t.widget<Text>(find.textContaining(' × ')).data!;
  final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
  await t.tap(find.text('${int.parse(m[1]!) * int.parse(m[2]!)}'));
  await _pumpFor(t, const Duration(milliseconds: 400));
}

/// One child, Ayaan, in [grade] with [done] levels finished (3 stars).
FamilyState _family({Grade grade = Grade.kg, Grade? open, Iterable<int> done = const [], DateTime? confirmed}) => FamilyState(
  profiles: [ChildProfile(id: 'p1', name: 'Ayaan', color: LikhoColors.primary, grade: grade, unlockedGrade: open, gradeConfirmedAt: confirmed ?? DateTime(2026, 9))],
  activeId: 'p1',
  records: {'p1': ChildRecord(levelStars: {for (final n in done) n: 3})},
);

Future<ProviderContainer> _app(WidgetTester t, Widget home, FamilyState family, {DateTime? now}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = ProviderContainer(
    overrides: [
      courseProvider.overrideWith((ref) async => testCourse),
      familyProvider.overrideWith(() => DemoFamilyNotifier(family)),
      if (now != null) clockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(theme: likhoTheme(), navigatorObservers: [AppFlow.observer], home: home)));
  await c.read(courseProvider.future);
  await t.pump();
  return c;
}

/// Scrolls the map so map-space [y] is at the middle of the screen.
Future<void> _scrollMapTo(WidgetTester t, double y) async {
  final s = t.state<ScrollableState>(find.byType(Scrollable).first);
  s.position.jumpTo((MapGeometry.height - y - 844 / 2).clamp(0, s.position.maxScrollExtent));
  await _pumpFor(t, const Duration(milliseconds: 1200));
}

/// Where the banner of the class starting at world [w] is (map space).
double _bannerY(int w) => MapGeometry(390).worldBottom(w) + 14 + 24;

const _kg = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

void main() {
  testWidgets('a KG child\'s map: their class in yellow, a board before Class 1, later classes locked', (t) async {
    await _app(t, const WorldMapScreen(), _family(done: [1, 2]));
    await _pumpFor(t, const Duration(milliseconds: 1500));
    await _scrollMapTo(t, _bannerY(0));
    expect(find.text('Meri class · KG'), findsOneWidget);
    await _scrollMapTo(t, _bannerY(2));
    expect(find.text('Class 1 ki tayyari'), findsOneWidget);
    await _scrollMapTo(t, _bannerY(4));
    expect(find.text('Class 2'), findsOneWidget, reason: 'after the next class: a plain locked tag');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a Class 1 child\'s map: KG is revision, levels there are open', (t) async {
    final opened = <int>[];
    final c = await _app(t, WorldMapScreen(onOpenLevel: opened.add), _family(grade: Grade.class1));
    await _pumpFor(t, const Duration(milliseconds: 1500));
    expect(c.read(progressProvider).current, 13, reason: 'the map opens at Class 1');
    await _scrollMapTo(t, _bannerY(0));
    expect(find.text('KG · Revision'), findsOneWidget);
    // level 2 (revision) opens without level 1 played
    final g = MapGeometry(390);
    final s = t.state<ScrollableState>(find.byType(Scrollable).first);
    final top = MapGeometry.height - s.position.pixels - 844; // map y at the top of the screen
    await t.tapAt(Offset(g.node(2).dx, g.node(2).dy - top));
    await _pumpFor(t, const Duration(milliseconds: 300));
    expect(opened, [2]);
    await _scrollMapTo(t, _bannerY(2));
    expect(find.text('Meri class · Class 1'), findsOneWidget);
    await _scrollMapTo(t, _bannerY(4));
    expect(find.text('Class 2 ki tayyari'), findsOneWidget);
    await _close(t);
  });

  testWidgets('the board: "finish first" before the class is done, then a parent opens the next class', (t) async {
    // KG half done: the board only wiggles
    var c = await _app(t, DevScreenLauncher(screen: 'map'), _family(done: [1, 2, 3]));
    await _pumpFor(t, const Duration(milliseconds: 1500));
    await _scrollMapTo(t, _bannerY(2));
    await t.tap(find.text('Class 1 ki tayyari'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Pehle KG mukammal karo!'), findsOneWidget);
    expect(find.byType(ParentGate), findsNothing);
    await _close(t);

    // KG done: the parent gate asks, the right answer opens Class 1
    c = await _app(t, DevScreenLauncher(screen: 'map'), _family(done: _kg));
    await _pumpFor(t, const Duration(milliseconds: 1500));
    expect(c.read(progressProvider).current, 12, reason: 'Pencil waits on the last KG level');
    await _scrollMapTo(t, _bannerY(2));
    await t.tap(find.text('Class 1 ki tayyari'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    expect(find.text('Kya Class 1 ke levels kholein?'), findsOneWidget);
    expect(find.text('Ayaan ne KG mukammal kar liya. Kholne ke liye sahi jawab chunein:'), findsOneWidget);
    await _passGate(t);
    expect(c.read(familyProvider).active.unlockedGrade, Grade.class1);
    expect(c.read(familyProvider).active.grade, Grade.kg, reason: 'the class stays KG');
    expect(c.read(progressProvider).current, 13);
    expect(find.text('Agli class · Class 1'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('finishing the last KG level: "KG Complete!" certificate with the parents\' link', (t) async {
    final c = await _app(t, DevScreenLauncher(screen: 'map'), _family(done: _kg.take(11)));
    await _pumpFor(t, const Duration(milliseconds: 1500));
    AppFlow.openLevel(t.element(find.byType(WorldMapScreen)), 12, skipIntro: true);
    await _pumpFor(t, const Duration(milliseconds: 600));
    final game = t.widget<GameplayScreen>(find.byType(GameplayScreen));
    game.onFinished(LevelResult(level: game.level, stars: 3, mistakes: 0));
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(t.widget<LevelCompleteScreen>(find.byType(LevelCompleteScreen)).certificate, isTrue);
    await t.tap(find.text('Certificate'));
    await _pumpFor(t, const Duration(milliseconds: 1500));
    final cert = t.widget<CertificateScreen>(find.byType(CertificateScreen));
    expect(cert.grade, Grade.kg);
    expect(find.text('KG Complete!'), findsOneWidget);
    expect(find.text('ne KG — Letter Land aur Small Letter Cove — mukammal kar liya!'), findsOneWidget);
    await t.tap(find.text('Walidain: Class 1 ke levels kholein'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    await _passGate(t);
    expect(c.read(familyProvider).active.unlockedGrade, Grade.class1);
    await _close(t);
  });

  test('certificates: a class the first time it is all done, the course when everything is, none for revision', () async {
    final c = ProviderContainer(overrides: [
      courseProvider.overrideWith((ref) async => testCourse),
      familyProvider.overrideWith(() => DemoFamilyNotifier(_family(done: _kg))),
    ]);
    addTearDown(c.dispose);
    await c.read(courseProvider.future);
    final p = c.read(progressProvider);
    expect(p.certificateFor(12, firstTime: true), (grade: Grade.kg));
    expect(p.certificateFor(12, firstTime: false), isNull, reason: 'a replay earns none');
    expect(p.certificateFor(11, firstTime: true), (grade: Grade.kg), reason: 'any level can be the last one missing');

    // a Class 1 child finishing KG revision: no certificate
    c.read(familyProvider.notifier).state = _family(grade: Grade.class1, done: _kg);
    expect(c.read(progressProvider).certificateFor(12, firstTime: true), isNull);

    // everything done: the whole course
    c.read(familyProvider.notifier).state = _family(grade: Grade.class3, done: [for (var n = 1; n <= 36; n++) n]);
    expect(c.read(progressProvider).certificateFor(36, firstTime: true), (grade: null));
  });

  testWidgets('dashboard: a parent changes the class and opens the next one', (t) async {
    final c = await _app(t, DevScreenLauncher(screen: 'dashboard'), _family(done: [1]));
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.text('Class: KG / Prep'), findsOneWidget);
    await t.tap(find.text('Class badlein'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    expect(find.text('Ayaan kis class mein hai?'), findsOneWidget);
    await t.tap(find.text('Class 1'));
    await t.tap(find.text('Save karein'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    expect(c.read(familyProvider).active.grade, Grade.class1);
    expect(c.read(familyProvider).record.levelStars, {1: 3}, reason: 'stars never change with the class');
    expect(find.text('Class: Class 1'), findsOneWidget);

    expect(find.text('Class 2 ke levels kholein'), findsOneWidget);
    await t.tap(find.byType(ParentSwitch).first);
    await _pumpFor(t, const Duration(milliseconds: 400));
    expect(c.read(familyProvider).active.unlockedGrade, Grade.class2);
    await t.tap(find.byType(ParentSwitch).first);
    await _pumpFor(t, const Duration(milliseconds: 400));
    expect(c.read(familyProvider).active.unlockedGrade, Grade.class1, reason: 'and closes it again');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('Who\'s playing: a class guessed from the age is checked once by a parent', (t) async {
    final family = FamilyState(
      profiles: [
        ChildProfile(id: 'p1', name: 'Ayaan', color: LikhoColors.primary, gradeConfirmedAt: DateTime(2026, 9)),
        ChildProfile(id: 'p2', name: 'Zara', color: LikhoColors.secondary, grade: Grade.class2, age: 7),
      ],
      activeId: 'p1',
      records: const {},
    );
    final c = await _app(t, DevScreenLauncher(screen: 'whos'), family, now: DateTime(2026, 10, 3));
    await _pumpFor(t, const Duration(milliseconds: 1000));
    await t.tap(find.text('Walidain: class check karein'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    await _passGate(t);
    expect(find.text('Zara kis class mein hai?'), findsOneWidget);
    expect(find.text('Umar se andaza: Class 2. Sahi class chunein:'), findsOneWidget);
    await t.tap(find.text('Save karein'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    final zara = c.read(familyProvider).profiles.last;
    expect((zara.grade, zara.gradeConfirmedAt != null), (Grade.class2, true));
    expect(find.text('Walidain: class check karein'), findsNothing);
    await _close(t);
  });

  testWidgets('Who\'s playing: a new school year asks "Kya Ayaan ab Class 1 mein hai?"', (t) async {
    final c = await _app(t, DevScreenLauncher(screen: 'whos'), _family(confirmed: DateTime(2026, 9)), now: DateTime(2027, 4, 2));
    await _pumpFor(t, const Duration(milliseconds: 1000));
    await t.tap(find.text('Naya school saal! Class check karein'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    await _passGate(t);
    expect(find.text('Kya Ayaan ab Class 1 mein hai?'), findsOneWidget);
    await t.tap(find.text('Save karein'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    expect(c.read(familyProvider).active.grade, Grade.class1);
    expect(c.read(schoolYearProvider), DateTime.april, reason: 'moved up in April: an April school');
    await _close(t);
  });

  test('school years: asked in April and August until the family\'s month is known, then once a year', () {
    ChildProfile p(DateTime? at) => ChildProfile(id: 'p', name: 'Ali', color: LikhoColors.primary, gradeConfirmedAt: at);
    expect(p(null).gradeCheck(DateTime(2026, 10)), GradeCheck.guessed);
    expect(p(DateTime(2026, 9)).gradeCheck(DateTime(2026, 12)), isNull, reason: 'not a school-year month');
    expect(p(DateTime(2026, 9)).gradeCheck(DateTime(2027, 4, 1)), GradeCheck.newSchoolYear);
    expect(p(DateTime(2027, 4, 3)).gradeCheck(DateTime(2027, 4, 20)), isNull, reason: 'answered this month');
    expect(p(DateTime(2027, 4, 3)).gradeCheck(DateTime(2027, 8, 10)), GradeCheck.newSchoolYear, reason: 'their school may start in August');
    expect(p(DateTime(2027, 4, 3)).gradeCheck(DateTime(2027, 8, 10), schoolMonth: DateTime.april), isNull, reason: 'an April school: once a year');
    expect(p(DateTime(2027, 4, 3)).gradeCheck(DateTime(2028, 4, 2), schoolMonth: DateTime.april), GradeCheck.newSchoolYear);
    expect(p(DateTime(2026, 8, 5)).gradeCheck(DateTime(2027, 4, 2), schoolMonth: DateTime.august), isNull);
    expect(FamilyState.guest().gradeChecks(DateTime(2027, 4)), isEmpty, reason: 'never for guests');
  });

  test('handwriting: a gentler lane for KG, a stricter one for Class 3', () {
    final widths = [for (final g in Grade.values) WritingJudge.laneWidthFor(g)];
    expect(widths, [18, 15, 13, 12]);
    expect(WritingJudge.laneWidthFor(Grade.class1), WritingJudge.laneWidth, reason: 'Class 1 keeps the tuned default');
    final geo = PadGeometry(const Size(300, 300));
    final guide = [Path()..moveTo(30, 20)..lineTo(30, 70)];
    expect(geo.lane(guide, width: 18).halfWidth, greaterThan(geo.lane(guide, width: 12).halfWidth));
  });
}
