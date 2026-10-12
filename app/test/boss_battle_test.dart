import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/screens/boss_battle/boss_more_rounds.dart';
import 'package:likho/screens/boss_battle/boss_overlays.dart';
import 'package:likho/screens/boss_battle/boss_rounds.dart';
import 'package:likho/screens/boss_battle/boss_stage.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/gameplay/rounds/beats_round_view.dart';
import 'package:likho/screens/gameplay/rounds/connect_round_view.dart';
import 'package:likho/screens/gameplay/rounds/sounds_round_view.dart';

import 'test_course.dart';

Future<void> pumpFor(WidgetTester t, double seconds) async {
  for (var ms = 0; ms < seconds * 1000; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder pillow(String text) => find.descendant(of: find.byType(PillowFightView), matching: find.text(text));

void main() {
  testWidgets('a boss battle: intro, pillow fight with a combo, then the alarm wakes the boss', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boss = testCourse.levels.firstWhere((l) => l.isBoss);
    final picks = testCourse.levels
        .expand((l) => l.rounds)
        .where((r) => labelledPick(r) && PillowFightView.fits(r as PickRound))
        .take(3)
        .toList();
    final level = levelWithRounds(boss, picks);
    LevelResult? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [courseProvider.overrideWith((ref) async => testCourse)],
      child: MaterialApp(home: GameplayScreen(level: level, onExit: () {}, onFinished: (r) => result = r)),
    ));
    await pumpFor(tester, .6);
    // the intro covers the screen; no round yet
    expect(find.byType(BossIntro), findsOneWidget);
    expect(find.byType(PillowFightView), findsNothing);
    await tester.tap(find.byType(BossIntro)); // skip
    await pumpFor(tester, 1.4);
    expect(find.byType(BossIntro), findsNothing);
    expect(find.byType(SleepMeter), findsOneWidget);

    for (final r in picks.cast<PickRound>()) {
      await tester.tap(pillow(r.answer!).last);
      await pumpFor(tester, 2.4);
    }
    expect(tester.takeException(), isNull);
    // three clean rounds: a combo
    expect(find.byType(ComboBadge), findsOneWidget);
    // all rounds won: the alarm, not the result yet
    expect(find.byType(AlarmFinale), findsOneWidget);
    expect(result, isNull);
    for (var k = 0; k < 8; k++) {
      await tester.tap(find.byType(AlarmFinale));
      await pumpFor(tester, .1);
    }
    expect(find.text('You made a new friend!'), findsOneWidget);
    await pumpFor(tester, 4);
    expect(result?.stars, 3);
    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, 2);
  });

  testWidgets('nobody taps the alarm: it rings itself', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boss = testCourse.levels.firstWhere((l) => l.isBoss);
    final pick = testCourse.levels.expand((l) => l.rounds).firstWhere((r) => labelledPick(r) && PillowFightView.fits(r as PickRound)) as PickRound;
    LevelResult? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [courseProvider.overrideWith((ref) async => testCourse)],
      child: MaterialApp(home: GameplayScreen(level: levelWithRounds(boss, [pick]), onExit: () {}, onFinished: (r) => result = r)),
    ));
    await pumpFor(tester, 4.6); // the whole intro
    await tester.tap(pillow(pick.answer!).last);
    await pumpFor(tester, 2.4);
    expect(find.byType(AlarmFinale), findsOneWidget);
    await pumpFor(tester, 16);
    expect(result, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, 2);
  });

  testWidgets('every kind of round plays as its boss game', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boss = testCourse.levels.firstWhere((l) => l.isBoss);
    final all = testCourse.levels.expand((l) => l.rounds).toList();
    for (final (test, view) in <(bool Function(Round), Type)>[
      ((r) => r is PickRound && PillowFightView.fits(r), PillowFightView),
      ((r) => r is PopRound, SnoreBubblesView),
      ((r) => r is SoundsRound, SoundsRoundView),
      ((r) => r is BeatsRound, BeatsRoundView),
      ((r) => r is ConnectRound, ConnectRoundView),
      ((r) => r is TruthRound, SunMoonView),
      ((r) => r is WriteRound, MagicFrame),
      ((r) => r is HuntRound, DreamHuntView),
      ((r) => r is MatchRound, DreamCardsView),
      ((r) => r is OrderRound, WakeWordView),
      ((r) => r is SortRound && r.bins.length > 1, PillowPilesView),
      ((r) => r is SortRound && r.bins.length == 1, PillowPilesView),
      ((r) => r is FixRound, SleepNotesView),
    ]) {
      final level = levelWithRounds(boss, [all.firstWhere(test)]);
      await tester.pumpWidget(ProviderScope(
        key: ValueKey(level.rounds.first.id),
        overrides: [courseProvider.overrideWith((ref) async => testCourse)],
        child: MaterialApp(home: GameplayScreen(level: level, onExit: () {}, onFinished: (_) {})),
      ));
      await tester.tap(find.byType(BossIntro));
      await pumpFor(tester, 1.2);
      expect(find.byType(view), findsOneWidget, reason: '$view');
      expect(tester.takeException(), isNull, reason: '$view');
    }
    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, 2);
  });
}
