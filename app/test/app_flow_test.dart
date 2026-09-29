import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/dev/dev_launch.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';

import 'test_course.dart';

void main() {
  testWidgets('dev launcher opens the level over the map', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [courseProvider.overrideWith((ref) async => testCourse)],
      child: const MaterialApp(home: DevLevelLauncher(level: 5)),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(GameplayScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
