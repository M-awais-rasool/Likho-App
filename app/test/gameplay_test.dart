import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';

import 'test_course.dart';

Future<void> pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('every level renders its first round without errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final level in testCourse.levels) {
      await tester.pumpWidget(ProviderScope(
        key: ValueKey(level.id),
        overrides: [courseProvider.overrideWith((ref) async => testCourse)],
        child: MaterialApp(home: GameplayScreen(level: level, onExit: () {}, onFinished: (_) {})),
      ));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: level.id);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('play Balloon Pop to the end by tapping the right balloons', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final level = testCourse.level(1);
    LevelResult? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [courseProvider.overrideWith((ref) async => testCourse)],
      child: MaterialApp(home: GameplayScreen(level: level, onExit: () {}, onFinished: (r) => result = r)),
    ));
    await pumpFor(tester, const Duration(milliseconds: 400));
    for (final r in level.rounds.cast<PickRound>()) {
      await tester.tap(find.text(r.answer!).last, warnIfMissed: false);
      await pumpFor(tester, const Duration(milliseconds: 2000)); // celebrate + flip to the next round
    }
    expect(result, isNotNull);
    expect(result!.stars, 3);
    await tester.pumpWidget(const SizedBox());
  });
}
