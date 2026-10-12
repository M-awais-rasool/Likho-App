import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';

import 'test_course.dart';

/// The games that took the place of saying things aloud (the app does not
/// listen): sound buttons, clap the beats, connect the dots. Played with
/// taps on the real screen.

Round round(String type, Map<String, dynamic> payload) => Round.fromJson({
  'id': 'x-r1',
  'type': type,
  'prompt': {'text': 'Play!'},
  'card': null,
  type: payload,
}, r'$');

Map<String, dynamic> pic(String key) => {'key': key, 'label': key, 'url': null};

final sounds = round('sounds', {
  'word': 'cat',
  'parts': [
    {'text': 'c', 'say': '{/c/|kʌ}'},
    {'text': 'a', 'say': '{/a/|æ}'},
    {'text': 't', 'say': '{/t/|tʌ}'},
  ],
  'blend': {'text': 'cat', 'say': 'cat!'},
  'choices': [
    {'label': 'dog', 'picture': pic('dog')},
    {'label': 'cat', 'picture': pic('cat')},
    {'label': 'sun', 'picture': pic('sun')},
  ],
  'answer': 1,
}) as SoundsRound;

final beats = round('beats', {
  'text': 'apple',
  'parts': ['ap', 'ple'],
  'unit': 'syllable',
  'picture': pic('apple'),
  'hint': {'text': 'ap-ple', 'say': 'Apple. Two beats!'},
}) as BeatsRound;

final connect = round('connect', {
  'labels': ['A', 'B', 'C', 'D', 'E', 'F'],
  'points': [
    [50, 3],
    [80, 26],
    [88, 42],
    [50, 97],
    [12, 42],
    [20, 26],
  ],
  'picture': pic('kite'),
  'done': {'text': 'A kite!', 'say': "It's a kite!"},
}) as ConnectRound;

CourseLevel levelOf(Round r) => levelWithRounds(testCourse.level(5), [r]);

Future<void> pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<LevelResult? Function()> pumpRound(WidgetTester tester, Round r) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  LevelResult? result;
  await tester.pumpWidget(ProviderScope(
    overrides: [courseProvider.overrideWith((ref) => testCourse)],
    child: MaterialApp(home: GameplayScreen(level: levelOf(r), onExit: () {}, onFinished: (x) => result = x)),
  ));
  await pumpFor(tester, const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
  return () => result;
}

void main() {
  test('the rounds are read from the course JSON', () {
    expect((sounds.word, sounds.parts.map((p) => p.text).join(), sounds.blend.spoken, sounds.answer), ('cat', 'cat', 'cat!', 1));
    expect((beats.count, beats.words, beats.hint?.spoken), (2, false, 'Apple. Two beats!'));
    expect((connect.labels.length, connect.points[3], connect.done?.text), (6, const Offset(.5, .97), 'A kite!'));
    expect(() => round('connect', {'labels': ['A'], 'points': [[1]]}), throwsFormatException);
  });

  testWidgets('sound buttons: tap c, a, t, slide to read, tap the cat', (tester) async {
    final result = await pumpRound(tester, sounds);
    expect(find.text('Tap each sound!'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('x-r1-s$i')));
      await pumpFor(tester, const Duration(milliseconds: 300));
    }
    expect(find.text('Slide to read!'), findsOneWidget);
    expect(find.byKey(const ValueKey('x-r1-c1')), findsNothing, reason: 'the pictures wait for reading');
    await tester.drag(find.byKey(const ValueKey('x-r1-arrow')), const Offset(300, 0));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('x-r1-c0'))); // dog
    await pumpFor(tester, const Duration(milliseconds: 1400));
    await tester.tap(find.byKey(const ValueKey('x-r1-c1'))); // cat
    await pumpFor(tester, const Duration(milliseconds: 2000));
    expect(tester.takeException(), isNull);
    expect(result()?.mistakes, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clap the beats: two taps on the drum, Done', (tester) async {
    final result = await pumpRound(tester, beats);
    expect(find.text('apple'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('x-r1-drum')));
    await pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('x-r1-drum')));
    await pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(find.text('Done'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('ap'), findsOneWidget, reason: 'split into its beats');
    await pumpFor(tester, const Duration(milliseconds: 2000));
    expect(tester.takeException(), isNull);
    expect(result()?.stars, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('connect the dots: A to F, the kite shows', (tester) async {
    final result = await pumpRound(tester, connect);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(ValueKey('x-r1-d$i')));
      await pumpFor(tester, const Duration(milliseconds: 150));
    }
    await pumpFor(tester, GameTiming.dotsReveal + const Duration(milliseconds: 2000));
    expect(tester.takeException(), isNull);
    expect(result()?.stars, 3);
    await tester.pumpWidget(const SizedBox());
  });
}
