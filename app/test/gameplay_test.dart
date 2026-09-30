import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/gameplay/rounds/write_round_view.dart';
import 'package:likho/screens/gameplay/widgets/game_bits.dart';

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

  testWidgets('the warm-up A is written stroke by stroke, then the round is won by itself', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final level = testCourse.placement!;
    await tester.pumpWidget(ProviderScope(
      overrides: [courseProvider.overrideWith((ref) => testCourse)],
      child: MaterialApp(home: GameplayScreen(level: level, onExit: () {}, onFinished: (_) {})),
    ));
    await pumpFor(tester, const Duration(milliseconds: 1800)); // "Trace A", then the first step
    final bubble = find.byType(SpeechBubble);
    String said() => tester.widget<SpeechBubble>(bubble).text;
    int? step() => tester.widget<SpeechBubble>(bubble).step;
    expect((said(), step()), ('Tircha neeche', 1));

    // the bubble sits beside the card, never on it
    final card = tester.getRect(find.byType(PromptCardView));
    expect(tester.getRect(bubble).bottom, lessThanOrEqualTo(card.top));

    final pad = find.byType(WritePad);
    final origin = tester.getTopLeft(pad);
    final c = tester.widget<WritePad>(pad).controller;
    Future<void> trace(List<Offset> s) async {
      final g = await tester.startGesture(origin + s.first);
      for (var i = 3; i < s.length; i += 3) {
        await g.moveTo(origin + s[i]);
      }
      await g.moveTo(origin + s.last);
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
    }

    final strokes = c.lane!.strokes;
    await trace(strokes[1]); // the second stroke first (same start dot): the wrong way
    expect(c.guide!.stroke, 0);
    expect(said(), 'Teer ke saath chalo!');
    await pumpFor(tester, const Duration(milliseconds: 1600));
    await trace(strokes[0].reversed.toList()); // from the bottom: the wrong start
    expect(said(), 'Neele dot se shuru karo!');
    await pumpFor(tester, const Duration(milliseconds: 1600));

    await trace(strokes[0]);
    expect((said(), step()), ('Tircha neeche', 2));
    await trace(strokes[1]);
    expect((said(), step()), ('Daayein taraf', 3));
    await trace(strokes[2]);
    await pumpFor(tester, const Duration(milliseconds: 400));
    final container = ProviderScope.containerOf(tester.element(pad));
    expect(container.read(levelSessionProvider(level)).correct, isTrue);
    expect(container.read(levelSessionProvider(level)).mistakes, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
