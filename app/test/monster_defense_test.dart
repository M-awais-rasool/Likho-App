import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/games.dart';
import 'package:likho/feedback/sfx.dart';
import 'package:likho/game/monster_defense/md_engine.dart';
import 'package:likho/game/monster_defense/md_questions.dart';
import 'package:likho/mascot/lip_sync.dart';
import 'package:likho/screens/games/games_screen.dart';
import 'package:likho/screens/games/monster_defense/md_lines.dart';
import 'package:likho/screens/games/monster_defense/md_scene.dart';
import 'package:likho/screens/games/monster_defense/monster_defense_screen.dart';

import 'test_course.dart';

/// Always asks for "A", the first monster of a group carrying it.
class _AskA implements MdQuestionSource {
  int asked = 0;
  final missedOnes = <MdQuestion>[];

  @override
  MdQuestion next(int count) {
    asked++;
    return MdQuestion(skill: MdSkill.capitals, answer: 'A', choices: ['A', 'B', 'C', 'D'].take(count).toList(), say: 'Find A!', audio: 'assets/voice/md_find_a.m4a', letter: 'A');
  }

  @override
  void missed(MdQuestion q) => missedOnes.add(q);
}

/// Monster Defense: the rules (waves, catches, misses, the gate, Bonk, the
/// boss, power-ups), questions from what the child learned, its art, sounds
/// and Pencil's lines in the app, and the screen played with taps.
void main() {
  final words = MdWords.fromJson(jsonDecode(File(MdWords.asset).readAsStringSync()) as Map<String, dynamic>);

  /// Ticks [g] for [seconds] at 60 frames a second; what happened.
  List<MdEvent> run(MdGame g, double seconds) {
    final out = <MdEvent>[];
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      g.tick(1 / 60);
      out.addAll(g.drain());
    }
    return out;
  }

  /// [g] started and its first group out of the cave.
  MdGame playing(MdGame g) {
    g.start();
    run(g, MdGame.bannerTime + .1);
    expect(g.phase, MdPhase.playing);
    run(g, 2.5);
    expect(g.question, isNotNull);
    expect(g.monsters.every((m) => m.out), isTrue, reason: 'all out of the cave');
    return g;
  }

  MdMonster withLabel(MdGame g, String label) => g.monsters.firstWhere((m) => m.label == label && m.tappable);

  group('the rules', () {
    test('a right tap catches the monster in a bubble; the others run back; it pops into a friend', () {
      final g = playing(MdGame(questions: _AskA(), random: math.Random(1)));
      final a = withLabel(g, 'A'), b = withLabel(g, 'B');
      expect(g.tap(a.id), MdTap.right);
      expect(a.mood, MdMood.trapped);
      expect(b.mood, MdMood.fleeing);
      expect(g.score, greaterThan(100));
      expect(g.combo, 1);
      expect(g.question, isNull, reason: 'the next group comes after a moment');
      final events = run(g, 2.2).map((e) => e.kind).toList();
      expect(events, contains(MdEventKind.popped));
      expect(a.mood, MdMood.friendly);
      run(g, 2);
      expect(g.question, isNotNull, reason: 'the next group');
      expect(g.monsters.map((m) => m.id), isNot(contains(a.id)), reason: 'the friend waved and went');
    });

    test('a wrong tap: the monster roars and jumps closer, the answer comes back later; two misses light the right one', () {
      final q = _AskA();
      final g = playing(MdGame(questions: q, random: math.Random(2)));
      final b = withLabel(g, 'B');
      final before = b.u;
      expect(g.tap(b.id), MdTap.wrong);
      expect(b.mood, MdMood.roaring);
      expect(b.u, greaterThan(before + .05));
      expect(g.combo, 0);
      expect(q.missedOnes, hasLength(1));
      expect(g.hint, isFalse);
      run(g, .8);
      expect(b.mood, MdMood.walking);
      g.tap(b.id);
      expect(g.hint, isTrue);
      expect(g.drain().map((e) => e.kind), contains(MdEventKind.hint));
    });

    test('nobody tapped: the first monster reaches the gate, a heart is lost, the group runs back', () {
      final g = playing(MdGame(questions: _AskA(), random: math.Random(3)));
      final events = run(g, 20).map((e) => e.kind).toList();
      expect(events, contains(MdEventKind.hurry));
      expect(events, contains(MdEventKind.gate));
      expect(g.hearts, MdGame.hearts0 - 1);
    });

    test('monsters walk faster near the gate, a wave takes about its seconds', () {
      final g = MdGame(
        questions: _AskA(),
        random: math.Random(4),
        waves: const [
          MdWave([
            [MdKind.gloop],
          ], seconds: 10),
        ],
      );
      g.start();
      run(g, MdGame.bannerTime + .05);
      run(g, .2);
      final m = g.monsters.single;
      final at = <double>[];
      for (var k = 0; k < 5; k++) {
        final u0 = m.u;
        run(g, 1);
        at.add(m.u - u0);
      }
      expect(at.last, greaterThan(at.first), reason: 'closer looks faster');
      run(g, 6);
      expect(g.hearts, 2, reason: 'at the gate within the wave\'s ~10 s');
    });

    test('a stone Bonk needs two catches: the first cracks its bubble and Pencil asks again', () {
      final q = _AskA();
      final g = playing(
        MdGame(
          questions: q,
          random: math.Random(5),
          waves: const [
            MdWave([
              [MdKind.bonk, MdKind.gloop],
            ], seconds: 30),
          ],
        ),
      );
      final bonk = g.monsters.firstWhere((m) => m.kind == MdKind.bonk);
      expect(bonk.label, 'A');
      final asked = q.asked;
      expect(g.tap(bonk.id), MdTap.cracked);
      expect(bonk.mood, MdMood.cracked);
      expect(q.asked, asked + 1, reason: 'a new question');
      expect(g.tap(bonk.id), MdTap.ignored, reason: 'dizzy for a moment');
      run(g, 1.1);
      expect(g.tap(bonk.id), MdTap.right);
      expect(bonk.mood, MdMood.trapped);
    });

    test('a whole game: the waves, Big Bonk with balloons (three catches), won with three stars', () {
      final g = MdGame(
        questions: _AskA(),
        random: math.Random(6),
        waves: const [
          MdWave([
            [MdKind.gloop, MdKind.fuzz],
            [MdKind.boo, MdKind.gloop],
          ], seconds: 20),
        ],
      );
      final events = <MdEventKind>[];
      g.start();
      while (g.phase != MdPhase.won) {
        events.addAll(run(g, .2).map((e) => e.kind));
        if (g.phase == MdPhase.playing && g.question != null && !g.isBoss) {
          final a = g.monsters.where((m) => m.label == 'A' && m.tappable && m.out && m.u > .05).firstOrNull;
          if (a != null) g.tap(a.id);
        }
        if (g.isBoss && g.balloons.isNotEmpty) {
          expect(g.balloons, ['A', 'B', 'C']);
          g.tapBalloon(0);
          events.addAll(run(g, 1.4).map((e) => e.kind));
        }
        expect(g.phase, isNot(MdPhase.lost));
      }
      events.addAll(g.drain().map((e) => e.kind));
      expect(events.where((e) => e == MdEventKind.banner), hasLength(1));
      expect(events, containsAll([MdEventKind.bossIntro, MdEventKind.bossHit, MdEventKind.trapped, MdEventKind.won]));
      expect(events.where((e) => e == MdEventKind.bossHit), hasLength(2), reason: 'the third catch is the bubble');
      expect(g.caught, 2 + 3);
      expect(g.stars, 3);
      expect(g.score, greaterThan(5 * 100 + 3 * 250));
    });

    test('three hearts lost: the game is over', () {
      final g = MdGame(questions: _AskA(), random: math.Random(7));
      g.start();
      final events = <MdEventKind>[];
      for (var s = 0; s < 120 && g.phase != MdPhase.lost; s++) {
        events.addAll(run(g, 1).map((e) => e.kind));
      }
      expect(g.phase, MdPhase.lost);
      expect(g.hearts, 0);
      expect(events.where((e) => e == MdEventKind.gate), hasLength(3));
      expect(events.last, MdEventKind.lost);
      expect(g.stars, 0);
    });

    test('three right in a row earn Freeze (the monsters stop), five earn Double magic', () {
      final g = playing(
        MdGame(
          questions: _AskA(),
          random: math.Random(8),
          waves: const [
            MdWave([
              [MdKind.gloop, MdKind.gloop],
              [MdKind.gloop, MdKind.gloop],
              [MdKind.gloop, MdKind.gloop],
              [MdKind.gloop, MdKind.gloop],
              [MdKind.gloop, MdKind.gloop],
              [MdKind.gloop, MdKind.gloop],
            ], seconds: 30),
          ],
        ),
      );
      for (var k = 0; k < 5; k++) {
        while (g.question == null || !g.monsters.any((m) => m.label == 'A' && m.tappable && m.out)) {
          run(g, .1);
        }
        g.tap(withLabel(g, 'A').id);
        if (k == 2) expect(g.freezes, 1);
      }
      expect(g.potions, 1);
      while (g.question == null || !g.monsters.every((m) => m.out || !m.alive)) {
        run(g, .1);
      }
      expect(g.useFreeze(), isTrue);
      final m = g.monsters.firstWhere((m) => m.mood == MdMood.walking);
      final u = m.u;
      run(g, 2);
      expect(m.u, u, reason: 'frozen');
      run(g, 3);
      expect(m.u, greaterThan(u));
      expect(g.usePotion(), isTrue);
      final before = g.score;
      g.tap(withLabel(g, 'A').id);
      expect(g.score - before, greaterThanOrEqualTo(2 * 100), reason: 'double points');
    });
  });

  group('the questions', () {
    test('a new child: capitals A to E only', () {
      final k = MdKnowledge.of(testCourse, const []);
      expect(k.skills, [MdSkill.capitals]);
      expect(k.capitals, MdKnowledge.starters);
      final q = MdQuestions(k, words, random: math.Random(1));
      for (var i = 0; i < 40; i++) {
        final x = q.next(3);
        expect(MdKnowledge.starters, contains(x.answer));
        expect(x.choices, hasLength(3));
        expect(x.choices.toSet(), hasLength(3));
        expect(x.choices, contains(x.answer));
        expect(x.letter, x.answer);
        expect(x.say, 'Find ${x.answer}!');
      }
    });

    test('what the child learned opens more: small letters, first sounds, then words to read', () {
      final done = [
        for (final l in testCourse.levels)
          if (l.number < 70) l.number,
      ];
      final k = MdKnowledge.of(testCourse, done);
      expect(k.capitals, hasLength(26));
      expect(k.smalls, hasLength(26));
      expect(k.skills, MdSkill.values);
      final q = MdQuestions(k, words, random: math.Random(2));
      final seen = <MdSkill>{};
      for (var i = 0; i < 200; i++) {
        final x = q.next(3);
        seen.add(x.skill);
        expect(x.choices.toSet(), hasLength(3), reason: '$x');
        expect(x.choices, contains(x.answer));
        switch (x.skill) {
          case MdSkill.smalls:
            expect(x.answer, x.answer.toLowerCase());
            expect(x.letter, x.answer.toUpperCase());
          case MdSkill.firstSound:
            final word = x.picture!.split('/').last.split('.').first;
            expect(x.answer, word[0]);
            expect(x.choices.where((c) => c == 'c' || c == 'k'), hasLength(lessThan(2)), reason: 'c and k sound alike');
          case MdSkill.words:
            expect(x.choices.every((c) => c.length == x.answer.length), isTrue, reason: '$x: the same length, so it is read');
          case MdSkill.capitals:
            break;
        }
      }
      expect(seen, MdSkill.values.toSet());
    });

    test('a missed answer is asked again after two others', () {
      final q = MdQuestions(MdKnowledge.beginner, words, random: math.Random(3));
      final first = q.next(2);
      q.missed(first);
      q.next(2);
      q.next(2);
      expect(q.next(2).answer, first.answer);
    });
  });

  group('in the app', () {
    test('every picture, sound and line the game uses is there', () {
      for (final a in [...MdArt.all, MdArt.cover, for (final k in MdKind.values) MdArt.idle(k)]) {
        expect(File(a).existsSync(), isTrue, reason: '$a: run tools/games/cut_art.py');
      }
      for (final w in {...words.first, ...words.read}) {
        expect(File(MdWords.picture(w)).existsSync(), isTrue, reason: w);
      }
      for (final s in Sfx.monsterDefense) {
        expect(File(s.asset).existsSync(), isTrue, reason: '${s.asset}: run tool/sound_design/generate_sfx.dart');
      }
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final dir in ['assets/games/', 'assets/games/monsters/', 'assets/games/words/']) {
        expect(pubspec, contains('- $dir\n'));
      }
    });

    test('Pencil says every line as his bubble shows it (recorded in the app)', () {
      final lock = jsonDecode(File('../tools/voice/app_lines.lock.json').readAsStringSync()) as Map<String, dynamic>;
      String id(String audio) => audio.split('/').last.replaceAll('.m4a', '');
      void check(String text, String audio) {
        expect(File(audio).existsSync(), isTrue, reason: '$audio: run tools/voice/generate_voice.py --app');
        expect(File(LipSyncEnvelope.lipFileOf(audio)).existsSync(), isTrue, reason: audio);
        expect((lock[id(audio)] as Map?)?['says'], text, reason: id(audio));
      }

      for (final p in [
        MdLines.intro,
        MdLines.go,
        MdLines.wave,
        MdLines.boss,
        MdLines.bossHit,
        ...MdLines.great,
        ...MdLines.oops,
        MdLines.hurry,
        MdLines.gate,
        MdLines.crack,
        MdLines.power,
        MdLines.freeze,
        MdLines.potion,
        MdLines.win,
        MdLines.lose,
        MdLines.record,
      ]) {
        check(p.text, p.audio!);
      }
      final all = MdKnowledge(capitals: [for (var c = 65; c < 91; c++) String.fromCharCode(c)], smalls: [for (var c = 97; c < 123; c++) String.fromCharCode(c)], firstSound: true, words: true);
      final q = MdQuestions(all, words, random: math.Random(4));
      final heard = <String>{};
      for (var i = 0; i < 3000; i++) {
        final x = q.next(3);
        if (heard.add(x.audio)) check(x.say, x.audio);
      }
      expect(heard.length, greaterThan(100));
    });

    test('the path runs from the cave to the gate inside the picture, things nearer are bigger', () {
      final p = MdPath.shared;
      final cave = p.feet(0, 0), gate = p.feet(1, 0);
      expect((cave - MdPath.cave).distance, lessThan(.03));
      expect((gate - MdPath.gate).distance, lessThan(.01));
      for (var u = 0.0; u <= 1; u += .05) {
        for (final lane in [-1.0, 0.0, 1.0]) {
          final f = p.feet(u, lane);
          expect(f.dx, inInclusiveRange(.2, .8), reason: 'u $u lane $lane');
        }
      }
      expect(MdPath.depth(gate.dy), greaterThan(MdPath.depth(cave.dy) * 1.8), reason: "nearer is bigger");
      expect(MdPath.depth(cave.dy), greaterThanOrEqualTo(.5), reason: "far monsters stay big enough to see");
      // on a phone and a tablet, the cave and the gate are on screen
      for (final screen in const [Size(390, 844), Size(375, 667), Size(820, 1180)]) {
        final f = MdFrame(screen);
        final c = f.at(MdPath.cave), g = f.at(MdPath.gate);
        expect(c.dy, inInclusiveRange(60, screen.height * .3), reason: '$screen cave');
        expect(g.dy, inInclusiveRange(screen.height * .6, screen.height - 40), reason: '$screen gate');
        expect(c.dx, inInclusiveRange(0, screen.width));
      }
    });

    test('a best score is kept per child, with the plays', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(gameProgressProvider.notifier);
      expect(n.record('kid', GameIds.monsters, score: 900, stars: 2), isFalse, reason: 'the first game is no record');
      expect(n.record('kid', GameIds.monsters, score: 700, stars: 3), isFalse);
      expect(n.record('kid', GameIds.monsters, score: 1200, stars: 1), isTrue);
      final r = c.read(gameProgressProvider)['kid']![GameIds.monsters]!;
      expect((r.best, r.stars, r.plays), (1200, 3, 3));
    });
  });

  group('the screen', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpFor(WidgetTester t, int ms) async {
      for (var i = 0; i < ms; i += 50) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('Games: Monster Defense to play', (tester) async {
      phone(tester);
      String? opened;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: GamesScreen(onBack: () {}, onOpen: (id) => opened = id),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Monster Defense'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('game-monsters')));
      expect(opened, GameIds.monsters);
    });

    testWidgets('played with taps: Play, the wave, catch the right monster, a wrong one roars, pause, stop', (tester) async {
      phone(tester);
      var done = false;
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [courseProvider.overrideWith((ref) => testCourse)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: MonsterDefenseScreen(onDone: () => done = true, random: math.Random(9), questions: _AskA()),
              );
            },
          ),
        ),
      );
      await pumpFor(tester, 300);
      expect(find.text('Monster Defense'), findsOneWidget);
      expect(find.text(MdLines.intro.text), findsOneWidget, reason: 'a first game: Pencil says what to do');
      await tester.tap(find.byKey(const ValueKey('md-play')));
      await pumpFor(tester, 500);
      expect(find.text('Wave 1'), findsOneWidget);
      await pumpFor(tester, 3800);
      expect(find.text('Find A!'), findsOneWidget, reason: 'the question card');
      expect(find.byKey(const ValueKey('md-sign-A')), findsOneWidget);

      // a wrong one, then the right one
      await tester.tap(find.byKey(const ValueKey('md-sign-B')), warnIfMissed: false);
      await pumpFor(tester, 200);
      expect(find.text(MdLines.oops.first.text), findsOneWidget);
      await pumpFor(tester, 900);
      await tester.tap(find.byKey(const ValueKey('md-sign-A')), warnIfMissed: false);
      await pumpFor(tester, 200);
      expect(find.text(MdLines.great.first.text), findsOneWidget);
      expect(find.byKey(const ValueKey('md-sign-A')), findsNothing, reason: 'caught: no sign in the bubble');
      final score = tester.widget<Text>(find.byKey(const ValueKey('md-score')));
      await pumpFor(tester, 600);
      expect(tester.widget<Text>(find.byKey(const ValueKey('md-score'))).data, isNot(score.data), reason: 'the score counts up');

      // pause, keep playing, pause, stop
      await tester.tap(find.byKey(const ValueKey('md-pause')));
      await pumpFor(tester, 400);
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('md-resume')));
      await pumpFor(tester, 400);
      expect(find.text('Paused'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('md-pause')));
      await pumpFor(tester, 400);
      await tester.tap(find.byKey(const ValueKey('md-exit')));
      expect(done, isTrue);
      expect(container.read(gameProgressProvider), isEmpty, reason: 'a game stopped half way is not counted');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, 100);
    });

    testWidgets('a lost game: the result card, the play counted, Play again', (tester) async {
      phone(tester);
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: MonsterDefenseScreen(onDone: () {}, random: math.Random(10), questions: _AskA()),
              );
            },
          ),
        ),
      );
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('md-play')));
      // nobody taps: three monsters reach the gate
      for (var s = 0; s < 90 && find.byKey(const ValueKey('md-result')).evaluate().isEmpty; s++) {
        await pumpFor(tester, 1000);
      }
      expect(find.text('Good try!'), findsOneWidget);
      final r = container.read(gameProgressProvider).values.single[GameIds.monsters]!;
      expect(r.plays, 1);
      await tester.tap(find.byKey(const ValueKey('md-again')));
      await pumpFor(tester, 600);
      expect(find.text('Wave 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, 100);
    });
  });
}
