import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/progress.dart';
import 'package:likho/screens/world_map/map_geometry.dart';
import 'package:likho/screens/world_map/world_map_screen.dart';

import 'test_course.dart';

void main() {
  test('geometry matches the prototype (390 px wide phone)', () {
    final g = MapGeometry(390);
    expect(MapGeometry.height, 5740);
    // level 1: x = 390 * .32, y = 5740 - 150 - 110
    expect(g.node(1), const Offset(124.8, 5480));
    // level 8 (world 2 mirrors x): x = 390 * (1 - .64), y = 5590 - 900 - 110 - 128
    expect(g.node(8).dx, closeTo(140.4, 1e-9));
    expect(g.node(8).dy, 4452);
    // boss nodes sit 12 px higher
    expect(g.node(6).dy, 5590 - 110 - 640 - 12);
    expect(g.decorations().length, 72);
  });

  testWidgets('taps: current level opens, locked level does not', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <int>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [courseProvider.overrideWith((ref) async => testCourse)],
      child: MaterialApp(home: WorldMapScreen(onOpenLevel: opened.add)),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // pop-ins + glide to level 8
    }
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(tester.element(find.byType(WorldMapScreen)));
    expect(container.read(progressProvider).current, 8);

    // current level 8 sits at 55 % of the screen after the glide
    final g = MapGeometry(390);
    final y8 = 844 * .55;
    await tester.tapAt(Offset(g.node(8).dx, y8));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened, [8]);

    // level 9 is locked: 128 px above level 8 on the map
    await tester.tapAt(Offset(g.node(9).dx, y8 - (g.node(8).dy - g.node(9).dy)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opened, [8]);
  });
}
