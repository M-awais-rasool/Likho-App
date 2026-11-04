import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/progress.dart';
import 'package:likho/mascot/mascot.dart';
import 'package:likho/screens/home/home_tabs.dart';
import 'package:likho/screens/world_map/journey_scenery.dart';
import 'package:likho/screens/world_map/map_geometry.dart';
import 'package:likho/screens/world_map/map_painters.dart';
import 'package:likho/screens/world_map/world_map_screen.dart';

import 'test_course.dart';

void main() {
  test('route gives every level a clear target and space for Pencil', () {
    for (final width in [320.0, 390.0, 768.0]) {
      final g = MapGeometry(width);
      expect(g.height, MapGeometry.top + 6 * MapGeometry.block + MapGeometry.bottom);
      for (var n = 1; n <= g.levels; n++) {
        final node = g.node(n);
        expect(node.dx, inInclusiveRange(52, width - 52));
        expect(g.worldAt(node.dy), (n - 1) ~/ 6);
        if (n > 1) expect(g.node(n - 1).dy - node.dy, greaterThanOrEqualTo(MapGeometry.levelSpacing));
      }
      final path = g.path().computeMetrics().single;
      expect(path.getTangentForOffset(0)!.position.dy, greaterThan(g.node(1).dy));
      expect(path.getTangentForOffset(path.length)!.position.dy, lessThan(g.node(g.levels).dy));
    }
  });

  test('course edits at the same width generate a fresh route', () {
    final short = MapGeometry(390, levelsPerWorld: const [2]);
    final long = MapGeometry(390, levelsPerWorld: const [8, 3]);
    expect(long.path().computeMetrics().single.length, greaterThan(short.path().computeMetrics().single.length));
    expect(identical(long.path(), short.path()), isFalse);
    expect(MapPathPainter(geometry: long, sectionTop: 0).shouldRepaint(MapPathPainter(geometry: short, sectionTop: 0)), isTrue);
    expect(MapGeometry(390, levelsPerWorld: const []).scrollFor(1, 844), 0);
  });

  test('levels added in the admin panel: a taller last world and a new world on top', () {
    final g = MapGeometry(390, levelsPerWorld: const [6, 6, 6, 6, 6, 7, 2]);
    expect(g.levels, 39);
    expect(g.worlds, 7);
    // the 7-level world grows to fit the trail, the new world sits above it
    expect(MapGeometry.blockOf(7), greaterThan(MapGeometry.block));
    expect(g.height, MapGeometry.top + 6 * MapGeometry.block + MapGeometry.blockOf(7) + MapGeometry.bottom);
    expect(g.node(37).dy, lessThan(g.node(36).dy)); // level 37 above 36
    expect(g.node(38).dy, lessThan(g.node(37).dy)); // new world above
    expect(g.node(38).dy, lessThan(g.worldBottom(6)));
    // every node is inside its world's section
    for (var w = 0; w < g.worlds; w++) {
      final (top, h) = g.section(w);
      expect(top, greaterThanOrEqualTo(0));
      expect(h, greaterThan(0));
    }
  });

  testWidgets('taps: current level opens, locked level does not', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [courseProvider.overrideWith((ref) async => testCourse), familyProvider.overrideWith(DemoFamilyNotifier.new)],
        child: MaterialApp(home: WorldMapScreen(onOpenLevel: opened.add)),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // pop-ins + glide to level 8
    }
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(tester.element(find.byType(WorldMapScreen)));
    expect(container.read(progressProvider).current, 8);

    // current level 8 sits at 55 % of the screen after the glide
    final g = MapGeometry(390, levelsPerWorld: [for (final w in testCourse.worlds) testCourse.levelsOf(w).length]);
    final y8 = 844 * .55;
    await tester.tapAt(Offset(g.node(8).dx, y8));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened, [8]);

    // level 9 is locked: one trail step above level 8
    await tester.tapAt(Offset(g.node(9).dx, y8 - (g.node(8).dy - g.node(9).dy)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opened, [8]);
  });

  testWidgets('exploring updates the world card and My level returns to the learner', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [courseProvider.overrideWith((ref) => testCourse), familyProvider.overrideWith(DemoFamilyNotifier.new)],
        child: const MaterialApp(home: WorldMapScreen()),
      ),
    );
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final scroll = t.widget<ListView>(find.byType(ListView)).controller!;
    final initial = scroll.offset;
    final g = MapGeometry(390, levelsPerWorld: [for (final w in testCourse.worlds) testCourse.levelsOf(w).length]);
    scroll.jumpTo(g.height - 844 - g.scrollFor(g.firstLevel(1), 844));
    await t.pump();
    await t.pump(const Duration(milliseconds: 650));
    expect(find.text('WORLD 2 / ${testCourse.worlds.length}'), findsOneWidget);
    expect(find.text('My level').hitTestable(), findsOneWidget);
    await t.tap(find.text('My level'));
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(scroll.offset, closeTo(initial, .1));
    expect(find.text('My level').hitTestable(), findsNothing);
    expect(find.text('WORLD 1 / ${testCourse.worlds.length}'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion keeps the scene still and the current level usable', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final demo = FamilyState.demo();
    final opened = <int>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          courseProvider.overrideWith((ref) => testCourse),
          familyProvider.overrideWith(() => DemoFamilyNotifier(demo.copyWith(settings: demo.settings.copyWith(reduceMotion: true)))),
        ],
        child: MaterialApp(home: WorldMapScreen(onOpenLevel: opened.add)),
      ),
    );
    await t.pump();
    await t.pump();
    final atmospheres = t.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<JourneyAtmospherePainter>();
    final clock = atmospheres.first.time;
    final before = clock.value;
    await t.pump(const Duration(seconds: 2));
    expect(clock.value, before);
    final g = MapGeometry(320, levelsPerWorld: [for (final w in testCourse.worlds) testCourse.levelsOf(w).length]);
    await t.tapAt(Offset(g.node(8).dx, 640 * .55));
    expect(opened, [8]);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Pencil stays below the journey card on compact phones with tabs', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 44, bottom: 24);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [courseProvider.overrideWith((ref) => testCourse), familyProvider.overrideWith(DemoFamilyNotifier.new)],
        child: MaterialApp(
          home: HomeTabs(page: (_, _) => const WorldMapScreen(), onParents: () {}, canOpen: (_) => true),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final pencil = find.byWidgetPredicate((w) => w is PencilMascot && w.size == 86);
    final card = find.byKey(ValueKey(testCourse.worlds.first.id));
    expect(t.getTopLeft(pencil).dy, greaterThan(t.getBottomLeft(card).dy + 8));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a new world glides into view after returning from a lesson', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final demo = FamilyState.demo();
    final family = FamilyState(
      profiles: [demo.active.copyWith(name: 'Transition learner')],
      activeId: demo.activeId,
      records: {
        demo.activeId: demo.record.copyWith(levelStars: {for (var n = 1; n < 15; n++) n: 3}),
      },
    );
    await t.pumpWidget(
      ProviderScope(
        key: const ValueKey('world-transition'),
        overrides: [courseProvider.overrideWith((ref) => testCourse), familyProvider.overrideWith(() => DemoFamilyNotifier(family))],
        child: const MaterialApp(home: WorldMapScreen()),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final context = t.element(find.byType(WorldMapScreen));
    final container = ProviderScope.containerOf(context);
    final nav = Navigator.of(context);
    final scroll = t.widget<ListView>(find.byType(ListView)).controller!;
    final before = scroll.offset;
    nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Lesson'))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    container.read(familyProvider.notifier).recordResult(15, 3);
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(scroll.offset, closeTo(before, .1), reason: 'the transition must wait until the map is visible');
    nav.pop();
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final g = MapGeometry(390, levelsPerWorld: [for (final w in testCourse.worlds) testCourse.levelsOf(w).length]);
    final target = g.height - 844 - g.scrollFor(16, 844);
    expect(scroll.offset, greaterThan(before));
    expect(scroll.offset, lessThan(target - 1), reason: 'the environment should still be transforming');
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(scroll.offset, closeTo(target, .1));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('all course worlds lay out on a small phone with larger text', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final demo = FamilyState.demo();
    for (final world in testCourse.worlds) {
      final n = testCourse.levelsOf(world).first.number;
      final family = demo.copyWith(
        records: {
          ...demo.records,
          demo.activeId: demo.record.copyWith(levelStars: {for (var i = 1; i < n; i++) i: 3}),
        },
      );
      await t.pumpWidget(
        ProviderScope(
          key: ValueKey(world.id),
          overrides: [courseProvider.overrideWith((ref) => testCourse), familyProvider.overrideWith(() => DemoFamilyNotifier(family))],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!,
            ),
            home: const WorldMapScreen(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(t.takeException(), isNull, reason: world.name);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 100));
    }
  });
}
