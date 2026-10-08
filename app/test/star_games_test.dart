import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/gameplay/rounds/pop_round_view.dart';
import 'package:likho/screens/gameplay/rounds/write_round_view.dart';

import 'test_course.dart';

/// The games added for varied levels: fix, sort, match, pop, truth and
/// writing from memory (write mode flash).

Round round(String type, Map<String, dynamic> payload, {String id = 'x-r1'}) => Round.fromJson({
  'id': id,
  'type': type,
  'prompt': {'text': 'Play!'},
  'card': null,
  type: payload,
}, r'$');

final fix = round('fix', {
  'items': [
    {'text': 'b', 'wrong': null, 'at': null},
    {'text': 'b', 'wrong': 'mirror', 'at': null},
    {'text': 'b', 'wrong': null, 'at': null},
    {'text': 'bed', 'wrong': 'upside', 'at': 0},
  ],
}) as FixRound;

final monster = round('sort', {
  'bins': [
    {'label': 'b', 'picture': null, 'bin': null},
  ],
  'items': [
    {'label': 'ball', 'picture': null, 'bin': 0},
    {'label': 'sun', 'picture': null, 'bin': null},
    {'label': 'bat', 'picture': null, 'bin': 0},
  ],
}) as SortRound;

final baskets = round('sort', {
  'bins': [
    {'label': 'B', 'picture': null, 'bin': null},
    {'label': 'b', 'picture': null, 'bin': null},
  ],
  'items': [
    {'label': 'B', 'picture': null, 'bin': 0},
    {'label': 'b', 'picture': null, 'bin': 1},
    {'label': 'B', 'picture': null, 'bin': 0},
  ],
}) as SortRound;

final match = round('match', {
  'pairs': [
    for (final (a, b) in [('A', 'a'), ('B', 'b'), ('C', 'c')])
      {
        'a': {'text': a, 'picture': null},
        'b': {'text': b, 'picture': null},
      },
  ],
}) as MatchRound;

final pop = round('pop', {
  'target': 'b',
  'others': ['d', 'p'],
  'count': 4,
}) as PopRound;

final truth = round('truth', {
  'text': 'Ball starts with b.',
  'picture': {'key': 'ball', 'label': 'ball', 'url': null},
  'answer': true,
}) as TruthRound;

final flash = round('write', {
  'mode': 'flash',
  'target': 'L',
  'guide': 'L',
  'word': null,
  'missingIndex': null,
  'sentence': false,
  'story': false,
}) as WriteRound;

CourseLevel levelOf(Round r) => levelWithRounds(testCourse.level(5), [r]);

/// Runs [body] on a fresh session of [r] in fake time.
void play(Round r, void Function(LevelSession s, SessionState Function() st, FakeAsync clock) body) {
  fakeAsync((clock) {
    final level = levelOf(r);
    final c = ProviderContainer();
    final sub = c.listen(levelSessionProvider(level), (_, _) {});
    body(c.read(levelSessionProvider(level).notifier), () => c.read(levelSessionProvider(level)), clock);
    sub.close();
    c.dispose();
  });
}

Future<void> pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// GameplayScreen playing [r] alone; returns the result once won.
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
  test('the new rounds are read from the course JSON', () {
    expect((fix.count, fix.items[1].wrong, fix.items[3].at), (2, FixWrong.mirror, 0));
    expect((monster.monster, monster.count), (true, 2));
    expect((baskets.monster, baskets.count), (false, 3));
    expect((match.cardCount, match.side(2).text, match.side(3).text), (6, 'B', 'b'));
    expect((pop.target, pop.count), ('b', 4));
    expect((truth.answer, truth.picture?.key), (true, 'ball'));
    expect(flash.mode, WriteMode.flash);
    expect(() => round('fix', {'items': [{'text': 'b', 'wrong': 'sideways'}]}), throwsFormatException);
  });

  test('fix: each wrong item must be tapped, a right one is a mistake', () {
    play(fix, (s, st, clock) {
      s.fixItem(0);
      expect((st().mistakes, st().hint), (1, true));
      clock.elapse(GameTiming.afterWrong);
      s.fixItem(1);
      s.fixItem(1);
      expect(st().found, {1});
      expect(st().correct, isFalse);
      s.fixItem(3);
      expect(st().correct, isTrue);
      expect(st().mistakes, 1);
    });
  });

  test('sort: the monster eats what goes in it, other food is a mistake', () {
    play(monster, (s, st, clock) {
      expect(s.sortItem(1, 0), isFalse);
      expect(st().mistakes, 1);
      clock.elapse(GameTiming.afterWrong);
      expect(s.sortItem(0, 0), isTrue);
      expect(s.sortItem(0, 0), isFalse, reason: 'already eaten');
      expect(s.sortItem(2, 0), isTrue);
      clock.elapse(GameTiming.orderSettle);
      expect(st().correct, isTrue);
    });
    play(baskets, (s, st, clock) {
      expect(s.sortItem(0, 1), isFalse);
      clock.elapse(GameTiming.afterWrong);
      s.sortItem(0, 0);
      s.sortItem(1, 1);
      s.sortItem(2, 0);
      clock.elapse(GameTiming.orderSettle);
      expect((st().correct, st().mistakes), (true, 1));
    });
  });

  test('match: a pair stays up, two others turn back down, no mistakes', () {
    play(match, (s, st, clock) {
      final cards = st().cards;
      expect(cards.toSet(), {0, 1, 2, 3, 4, 5});
      int at(int card) => cards.indexOf(card);
      s.flipCard(at(0));
      s.flipCard(at(2)); // A and B: not a pair
      expect(st().open, [at(0), at(2)]);
      s.flipCard(at(4)); // a third card waits
      expect(st().open.length, 2);
      clock.elapse(GameTiming.matchPeek);
      expect(st().open, isEmpty);
      for (final p in [0, 2, 4]) {
        s.flipCard(at(p));
        s.flipCard(at(p + 1));
      }
      expect(st().found.length, 6);
      clock.elapse(GameTiming.orderSettle);
      expect((st().correct, st().mistakes), (true, 0));
    });
  });

  test('pop: bubbles say the target about every other time, never three others in a row', () {
    final labels = [for (var i = 0; i < 60; i++) popLabel(pop, level: 7, round: 2, index: i)];
    expect(labels.where((l) => l == 'b').length, inInclusiveRange(20, 40));
    for (var i = 2; i < labels.length; i++) {
      expect(labels.sublist(i - 2, i + 1).every((l) => l != 'b'), isFalse, reason: 'at $i');
      expect(labels.sublist(i - 2, i + 1).every((l) => l == 'b'), isFalse, reason: 'at $i');
    }
    expect(labels.toSet(), {'b', 'd', 'p'});
    expect(popLabel(pop, level: 7, round: 2, index: 9), labels[9], reason: 'the same every time');
  });

  test('pop: popping targets wins, another letter is a mistake', () {
    play(pop, (s, st, clock) {
      final level = levelOf(pop).number;
      final labels = [for (var i = 0; i < 20; i++) popLabel(pop, level: level, round: 0, index: i)];
      s.popBubble(labels.indexWhere((l) => l != 'b'));
      expect(st().mistakes, 1);
      clock.elapse(GameTiming.afterWrong);
      final targets = [for (var i = 0; i < 20; i++) if (labels[i] == 'b') i];
      for (final i in targets.take(4)) {
        s.popBubble(i);
      }
      expect(st().correct, isTrue);
    });
  });

  test('truth: the right button wins, the other is a mistake', () {
    play(truth, (s, st, clock) {
      s.answerTruth(false);
      expect(st().mistakes, 1);
      s.answerTruth(false); // already wrong
      expect(st().mistakes, 1);
      clock.elapse(GameTiming.afterWrong);
      s.answerTruth(true);
      expect((st().correct, st().picked), (true, 0));
    });
  });

  testWidgets('fix: tap the two wrong ones in Pencil\'s notebook', (tester) async {
    final result = await pumpRound(tester, fix);
    await tester.tap(find.byKey(const ValueKey('x-r1-1')));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('x-r1-3')));
    await pumpFor(tester, const Duration(milliseconds: 2000));
    expect(result()?.stars, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sort: tap food to feed the monster; tap a thing, then its basket', (tester) async {
    var result = await pumpRound(tester, monster);
    await tester.tap(find.byKey(const ValueKey('x-r1-i0')));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('x-r1-i2')));
    await pumpFor(tester, const Duration(milliseconds: 2000));
    expect(result()?.stars, 3);
    await tester.pumpWidget(const SizedBox());

    result = await pumpRound(tester, baskets);
    for (final (i, b) in [(0, 0), (1, 1), (2, 0)]) {
      await tester.tap(find.byKey(ValueKey('x-r1-i$i')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('x-r1-bin$b')));
      await pumpFor(tester, const Duration(milliseconds: 200));
    }
    await pumpFor(tester, const Duration(milliseconds: 2000));
    expect(result()?.stars, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sort: drag a thing into its basket', (tester) async {
    await pumpRound(tester, baskets);
    await tester.drag(find.byKey(const ValueKey('x-r1-i1')), tester.getCenter(find.byKey(const ValueKey('x-r1-bin1'))) - tester.getCenter(find.byKey(const ValueKey('x-r1-i1'))));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('x-r1-i1')), findsNothing, reason: 'it went in the basket');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('match: cards peek, then turn down; find the three pairs', (tester) async {
    final result = await pumpRound(tester, match);
    await pumpFor(tester, const Duration(milliseconds: 2600)); // the peek
    final level = levelOf(match);
    final cards = tileOrder(level: level.number, round: 5, count: 6);
    for (final p in [0, 2, 4]) {
      await tester.tap(find.byKey(ValueKey('x-r1-card${cards.indexOf(p)}')));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.byKey(ValueKey('x-r1-card${cards.indexOf(p + 1)}')));
      await pumpFor(tester, const Duration(milliseconds: 400));
    }
    await pumpFor(tester, const Duration(milliseconds: 2000));
    expect(result()?.stars, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pop: bubbles rise; pop the four b bubbles', (tester) async {
    final result = await pumpRound(tester, pop);
    final level = levelOf(pop).number;
    var popped = 0;
    for (var i = 0; popped < 4 && i < 40; i++) {
      final key = find.byKey(ValueKey('x-r1-b$i'));
      // wait until bubble i is well inside the field
      await pumpFor(tester, Duration(milliseconds: (PopRoundView.gap * 1000).round()));
      if (popLabel(pop, level: level, round: 0, index: i) != 'b') continue;
      expect(key, findsOneWidget);
      await tester.tap(key, warnIfMissed: false);
      popped++;
    }
    await pumpFor(tester, const Duration(milliseconds: 2000));
    expect(tester.takeException(), isNull);
    expect(result()?.stars, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('truth: tap True', (tester) async {
    final result = await pumpRound(tester, truth);
    await tester.tap(find.text('True'));
    await pumpFor(tester, const Duration(milliseconds: 2000));
    expect(result()?.stars, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('flash: the letter shows and the pad waits, then L is written from memory', (tester) async {
    await pumpRound(tester, flash);
    final pad = find.byType(WritePad);
    final c = tester.widget<WritePad>(pad).controller;
    final origin = tester.getTopLeft(pad);
    expect(find.text('Look!'), findsOneWidget);
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(c.penUsed, isFalse, reason: 'no writing while the letter shows');
    await pumpFor(tester, GameTiming.flash);
    expect(find.text('Look!'), findsNothing);
    expect(c.guides, isNotEmpty, reason: 'the hidden letter still guides the ink');
    await tester.pumpWidget(const SizedBox());
  });
}
