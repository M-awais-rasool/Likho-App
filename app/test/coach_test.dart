import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/coach.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/gameplay/widgets/game_bits.dart';

import 'new_games_test.dart' as games;
import 'star_games_test.dart' as stars;
import 'test_course.dart';

/// Pencil's step-by-step coaching: every game says what to do, his bubble
/// shows the words he says, and the step moves on with the child.
void main() {
  SessionState at(Round r, {Set<int> found = const {}, bool blended = false, List<int> open = const []}) =>
      SessionState(level: games.levelOf(r), found: found, blended: blended, open: open);

  test('every game in the course has a step, with a line saying how to play', () {
    for (final level in [...testCourse.levels, if (testCourse.placement != null) testCourse.placement!]) {
      for (var i = 0; i < level.rounds.length; i++) {
        final r = level.rounds[i];
        if (r is WriteRound && r.guide != null) continue; // the strokes are explained one by one
        final step = coachStep(SessionState(level: level, round: i));
        expect(step?.line, isNotNull, reason: '${r.id} (${r.type})');
        expect(step!.text, CoachLines.words[step.line], reason: 'the bubble shows the words Pencil says');
      }
    }
  });

  test('the course has no drum game and no sound marks like /b/ in what Pencil says', () {
    final slash = RegExp(r'/[a-z]{1,4}/');
    for (final level in testCourse.levels) {
      for (final r in level.rounds) {
        expect(r, isNot(isA<BeatsRound>()), reason: r.id);
        expect(r.prompt.spoken, isNot(contains(slash)), reason: '${r.id}: ${r.prompt.spoken}');
        if (r is SoundsRound) {
          for (final p in r.parts) {
            expect(p.spoken, isNot(contains(slash)), reason: r.id);
          }
        }
      }
    }
  });

  test('a count of what is left once the child starts', () {
    final hunt = stars.round('hunt', {'target': 'L', 'grid': ['L', 'T', 'L', 'L']}) as HuntRound;
    expect(coachStep(at(hunt))!.line, CoachLines.hunt);
    expect((coachStep(at(hunt, found: {0}))!.text, coachStep(at(hunt, found: {0}))!.line), ('2 more to go!', null));
    expect(coachStep(at(hunt, found: {0, 2}))!.text, 'Just one more!');
  });

  test('sound buttons: tap the dots, slide, then pick (said as each step begins)', () {
    final r = games.sounds;
    expect(coachStep(at(r))!.line, CoachLines.soundsTap);
    expect(coachStep(at(r, found: {0}))!.text, 'Now tap the next dot!');
    final slide = coachStep(at(r, found: {0, 1, 2}))!;
    expect((slide.text, slide.sayNow), ('Now slide the arrow to read the word!', true));
    expect(coachStep(at(r, found: {0, 1, 2}, blended: true))!.text, 'Which picture is it? Tap it!');
  });

  test('connect the dots says the next letter', () {
    final r = games.connect;
    expect(coachStep(at(r))!.line, CoachLines.connect);
    expect(coachStep(at(r, found: {0, 1}))!.text, 'Now tap C!');
  });

  test('boss games say what their buttons are', () {
    expect(coachStep(at(stars.truth))!.line, CoachLines.truth);
    expect(coachStep(at(stars.truth), boss: true)!.line, CoachLines.truthBoss);
  });

  test('a won round says nothing (Pencil cheers instead)', () {
    expect(coachStep(at(stars.truth).copyWith(feedback: RoundFeedback.correct)), isNull);
  });

  test('the recorded lines say the words the bubble shows', () {
    final lock = jsonDecode(File('../tools/voice/app_lines.lock.json').readAsStringSync()) as Map<String, dynamic>;
    for (final MapEntry(key: line, value: words) in CoachLines.words.entries) {
      final id = line.split('/').last.replaceFirst('.m4a', '');
      expect((lock[id] as Map?)?['says'], words, reason: '$id: run tools/voice/generate_voice.py --app');
    }
  });

  testWidgets('the bubble shows the prompt Pencil says, and keeps it until the child moves on', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = stars.round('hunt', {'target': 'L', 'grid': ['L', 'T', 'L', 'I']});
    final level = levelWithRounds(testCourse.level(5), [r]);
    await tester.pumpWidget(ProviderScope(
      overrides: [courseProvider.overrideWith((ref) => testCourse)],
      child: MaterialApp(home: GameplayScreen(level: level, onExit: () {}, onFinished: (_) {})),
    ));
    String said() => tester.widget<SpeechBubble>(find.byType(SpeechBubble)).text;
    await tester.pump(const Duration(milliseconds: 300));
    expect(said(), r.prompt.spoken, reason: 'while he says it');
    await tester.pump(const Duration(milliseconds: 3000));
    expect(said(), r.prompt.spoken, reason: 'after: the last thing he said');
    await tester.tap(find.text('L').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(said(), 'Just one more!');
    await tester.pumpWidget(const SizedBox());
  });
}
