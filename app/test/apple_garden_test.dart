import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/level_resume.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/screens/gameplay/apple_garden/garden_art.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/gameplay/rounds/write_round_view.dart';
import 'package:likho/screens/level_intro/level_intro_screen.dart';
import 'package:likho/screens/level_complete/level_complete_screen.dart';

import 'test_course.dart';

Future<void> gardenPump(WidgetTester t, int ms) async {
  for (var i = 0; i < ms; i += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Exercise the real pointer input and stroke judge, not a mocked success.
Future<void> gardenTrace(WidgetTester t) async {
  final finder = find.byType(WritePad);
  final origin = t.getTopLeft(finder);
  final pad = t.widget<WritePad>(finder).controller;
  final strokes = pad.lane!.strokes;
  for (final stroke in strokes) {
    final gesture = await t.startGesture(origin + stroke.first);
    for (var i = 1; i < stroke.length; i++) {
      await gesture.moveTo(origin + stroke[i]);
    }
    await gesture.up();
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> gardenAnswer(WidgetTester t, Round round) async {
  switch (round) {
    case PickRound():
      final index = round.options.indexWhere((o) => o.label == round.answer);
      await t.tap(find.byKey(ValueKey('${round.id}-$index')));
    case WriteRound():
      if (round.mode == WriteMode.flash) await gardenPump(t, 2800);
      await gardenTrace(t);
      await gardenPump(t, 400); // the completed letter's automatic submission
    case FixRound():
      for (var i = 0; i < round.items.length; i++) {
        if (round.items[i].wrong == null) continue;
        await t.tap(find.byKey(ValueKey('${round.id}-$i')));
        await t.pump(const Duration(milliseconds: 100));
      }
    case ConnectRound():
      for (var i = 0; i < round.labels.length; i++) {
        await t.tap(find.byKey(ValueKey('${round.id}-$i')));
        await t.pump(const Duration(milliseconds: 60));
      }
      await gardenPump(t, 1700);
    default:
      throw StateError('Unexpected Apple Garden round ${round.runtimeType}');
  }
}

void main() {
  final level = testCourse.level(1);

  for (final size in [const Size(390, 844), const Size(320, 640), const Size(768, 1024)]) {
    testWidgets('all eight A tasks complete through real input at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      LevelResult? result;
      await t.pumpWidget(
        ProviderScope(
          overrides: [courseProvider.overrideWith((ref) => testCourse)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.width == 320 ? 1.3 : 1), padding: const EdgeInsets.only(top: 24, bottom: 20)),
              child: child!,
            ),
            home: GameplayScreen(level: level, onExit: () {}, onFinished: (r) => result = r),
          ),
        ),
      );
      await gardenPump(t, 500);
      final container = ProviderScope.containerOf(t.element(find.byType(GameplayScreen)));
      for (var i = 0; i < level.rounds.length; i++) {
        expect(container.read(levelSessionProvider(level)).round, i);
        expect(t.takeException(), isNull, reason: 'round $i at $size');
        await gardenAnswer(t, level.rounds[i]);
        expect(container.read(levelSessionProvider(level)).correct, isTrue, reason: 'round $i');
        await gardenPump(t, 2050);
      }
      expect(result?.stars, 3);
      expect(result?.mistakes, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('wrong answer can be retried; saved harvest resumes at tracing', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final container = ProviderContainer(overrides: [courseProvider.overrideWith((ref) => testCourse)]);
    addTearDown(container.dispose);
    Widget app() => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GameplayScreen(level: level, onExit: () {}, onFinished: (_) {}),
      ),
    );
    await t.pumpWidget(app());
    await gardenPump(t, 400);
    await t.tap(find.byKey(const ValueKey('level-01-r1-1')));
    await t.pump();
    expect(container.read(levelSessionProvider(level)).mistakes, 1);
    expect(t.widget<GardenBasket>(find.byType(GardenBasket)).apples, 0);
    await gardenAnswer(t, level.rounds.first);
    await gardenPump(t, 2050);
    final child = container.read(familyProvider).active.id;
    expect(container.read(levelResumeProvider.notifier).pointFor(child, level)?.round, 1);
    await t.pumpWidget(const SizedBox());
    await t.pump();
    await t.pumpWidget(app());
    await gardenPump(t, 400);
    expect(find.byType(WritePad), findsOneWidget);
    expect(t.widget<GardenBasket>(find.byType(GardenBasket)).apples, 1);
    expect(container.read(levelSessionProvider(level)).mistakes, 1);
    await t.pumpWidget(const SizedBox());
    await gardenPump(t, 1500); // finish the silent voice fallback's delayed future
  });

  testWidgets('welcome waits for the child and completion actions are usable', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var started = 0, again = 0, next = 0;
    Widget wrap(Widget child) => ProviderScope(
      overrides: [courseProvider.overrideWith((ref) => testCourse)],
      child: MaterialApp(home: child),
    );
    await t.pumpWidget(wrap(LevelIntroScreen(level: level, onDone: () => started++)));
    await gardenPump(t, 11000);
    expect(started, 0);
    await t.ensureVisible(find.byKey(const ValueKey('garden-start')));
    await t.tap(find.byKey(const ValueKey('garden-start')));
    expect(started, 1);
    await t.pumpWidget(
      wrap(
        LevelCompleteScreen(
          level: level,
          outcome: const LevelOutcome(level: 1, stars: 2, gain: 2, firstTime: true),
          onAgain: () => again++,
          onNext: () => next++,
        ),
      ),
    );
    await gardenPump(t, 500);
    expect(find.text('8 apples. One amazing A.'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('garden-next')));
    await t.tap(find.byKey(const ValueKey('garden-next')));
    await t.ensureVisible(find.byKey(const ValueKey('garden-again')));
    await t.tap(find.byKey(const ValueKey('garden-again')));
    expect((again, next), (1, 1));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
