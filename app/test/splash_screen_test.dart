import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/dev/reference_overlay.dart';
import 'package:likho/screens/splash_screen.dart';

import 'test_course.dart';

void main() {
  testWidgets('splash finishes after 2.5 s, or holds while the overlay is on', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var done = 0;
    final container = ProviderContainer(overrides: [courseProvider.overrideWith((ref) async => testCourse)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: SplashScreen(onDone: () => done++)),
    ));
    await tester.pump(const Duration(milliseconds: 2400));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, 1);

    // overlay on: holds on the last frame
    container.read(referenceOverlayProvider.notifier).toggle();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: SplashScreen(key: UniqueKey(), onDone: () => done++)),
    ));
    await tester.pump(const Duration(seconds: 3));
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });
}
