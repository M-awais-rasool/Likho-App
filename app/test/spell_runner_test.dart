import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/games.dart';
import 'package:likho/feedback/sfx.dart';
import 'package:likho/game/monster_defense/md_questions.dart';
import 'package:likho/game/spell_runner/sr_engine.dart';
import 'package:likho/mascot/lip_sync.dart';
import 'package:likho/screens/games/games_screen.dart';
import 'package:likho/screens/games/spell_runner/sr_lines.dart';
import 'package:likho/screens/games/spell_runner/sr_scene.dart';
import 'package:likho/screens/games/spell_runner/spell_runner_screen.dart';

import 'test_course.dart';

/// Spell Runner: the rules (lanes, letters, bumps, jumps, words, the finish),
/// the tasks from what the child learned.
void main() {
  final words = MdWords.fromJson(jsonDecode(File(MdWords.asset).readAsStringSync()) as Map<String, dynamic>);

  /// Ticks [g] for [seconds] at 60 frames a second; what happened.
  List<SrEvent> run(SrGame g, double seconds, {void Function(SrGame g)? player}) {
    final out = <SrEvent>[];
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      player?.call(g);
      g.tick(1 / 60);
      out.addAll(g.drain());
    }
    return out;
  }

  /// A good player: goes to the bubble with the letter needed, jumps what is
  /// in the way, slides under what is high.
  void good(SrGame g) {
    if (g.phase != SrPhase.running) return;
    final ahead = g.things.where((t) => !t.taken && !t.cleared && !t.bumped && t.z - g.dist > 0).toList()..sort((a, b) => a.z.compareTo(b.z));
    final bubble = ahead.where((t) => t.kind == SrKind.letter && t.label == g.need && t.z - g.dist < 14).firstOrNull;
    if (bubble != null) g.moveTo(bubble.lane);
    // a cart ahead in his lane: over to the nearest lane without one
    bool blocked(int l) => ahead.any((t) => t.kind.blocker && t.lane == l && t.z - g.dist < 8);
    if (blocked(g.targetLane)) {
      final to = ([-1, 0, 1]..sort((a, b) => (a - (bubble?.lane ?? 0)).abs().compareTo((b - (bubble?.lane ?? 0)).abs()))).where((l) => !blocked(l)).firstOrNull;
      if (to != null) g.moveTo(to);
    }
    final bump = ahead.where((t) => t.kind.obstacle && !t.kind.blocker && (t.lane == g.targetLane || t.lane == g.lane.round()) && t.z - g.dist < 1.6).firstOrNull;
    if (bump != null) bump.kind.high ? g.slide() : g.jump();
  }

  SrGame game(List<String> ws, {int seed = 1}) => SrGame(tasks: SrList([for (final w in ws) SrTask.spell(w)]), random: math.Random(seed));

  test('the countdown, then he rides; the first bubbles show the first letter', () {
    final g = game(['cat']);
    g.start();
    expect(g.phase, SrPhase.countdown);
    final events = run(g, SrGame.countdownTime + .1).map((e) => e.kind).toList();
    expect(events.where((e) => e == SrEventKind.countdown), hasLength(3));
    expect(events, containsAll([SrEventKind.go, SrEventKind.task]));
    expect(g.phase, SrPhase.running);
    final first = g.things.where((t) => t.kind == SrKind.letter && t.row == 0).toList();
    expect(first, hasLength(3));
    expect(first.where((t) => t.label == 'c'), hasLength(1));
    expect(first.map((t) => t.label).toSet(), hasLength(3), reason: 'three different letters');
  });

  test('a good player rides on and on: word after word, faster, never a bump, it never ends', () {
    final g = game(['cat', 'sun', 'frog']);
    g.start();
    final events = run(g, 150, player: good);
    final kinds = events.map((e) => e.kind).toList();
    expect(g.phase, SrPhase.running, reason: 'endless');
    expect(kinds.where((e) => e == SrEventKind.word).length, greaterThanOrEqualTo(9));
    expect(events.where((e) => e.kind == SrEventKind.letter).map((e) => e.text).join(), startsWith('catsunfrogcatsunfrog'));
    expect(g.bumps, 0);
    expect(g.wrong, 0);
    expect(g.hearts, SrGame.hearts0);
    expect(g.stage, greaterThan(1));
    expect(g.speed, greaterThan(SrGame.startSpeed), reason: 'faster each stage');
    expect(g.metres, greaterThan(500));
    expect(g.stars, g.done >= 14 ? 3 : 2);
  });

  test('words get longer: 3 letters, then 4, 5, then 5 and 6; not the same word again soon', () {
    final s = SrSpelling(words, math.Random(4));
    final lengths = [for (var d = 0; d < 30; d++) s.next(d).letters.length];
    expect(lengths.take(SrSpelling.three), everyElement(3));
    expect(lengths.sublist(SrSpelling.three, SrSpelling.four), everyElement(4));
    expect(lengths.sublist(SrSpelling.four, SrSpelling.five), everyElement(5));
    expect(lengths.sublist(SrSpelling.five), everyElement(anyOf(5, 6)));
    expect(lengths.sublist(SrSpelling.five), contains(6));
    final asked = [for (var d = 0; d < 12; d++) s.next(d + 40).word];
    expect(asked.toSet(), hasLength(asked.length), reason: 'no repeats among recent words');
    expect(s.stage(0), lessThan(s.stage(20)));
  });

  test('nobody steers: bumps cost hearts (and he is safe for a moment after each); the third ends the run', () {
    final g = game(['cat']);
    g.start();
    final events = <SrEvent>[];
    for (var k = 0; k < 300 && g.phase != SrPhase.done; k++) {
      events.addAll(run(g, 1));
    }
    final kinds = events.map((e) => e.kind).toList();
    expect(g.phase, SrPhase.done);
    expect(g.hearts, 0);
    expect(kinds.where((e) => e == SrEventKind.bump || e == SrEventKind.skid), hasLength(SrGame.hearts0));
    expect(kinds, containsAllInOrder([SrEventKind.crash, SrEventKind.done]));
    expect(g.stars, greaterThanOrEqualTo(1));
  });

  test('a wrong bubble pops the whole row; a bump makes him stumble and costs a heart; a jump clears it', () {
    final g = game(['cat']);
    g.start();
    run(g, SrGame.countdownTime + .1);
    final row = g.things.where((t) => t.row == 0).toList();
    final wrong = row.firstWhere((t) => t.label != 'c');
    g.moveTo(wrong.lane);
    final events = <SrEvent>[];
    for (var k = 0; k < 600 && !events.any((e) => e.kind == SrEventKind.wrong); k++) {
      events.addAll(run(g, 1 / 60));
    }
    expect(row.every((t) => t.taken), isTrue);
    expect(g.wrong, 1);
    expect(g.got, 0);
    expect(g.hearts, SrGame.hearts0, reason: 'a wrong letter costs no heart');
    final bump = SrThing(id: 999, kind: SrKind.log, lane: g.targetLane, z: g.dist + .3);
    g.things.add(bump);
    run(g, .2);
    expect(bump.bumped, isTrue);
    expect(g.hearts, SrGame.hearts0 - 1);
    expect(g.stumble, greaterThan(0));
    // safe for a moment: the next one does not bump him
    final next = SrThing(id: 1000, kind: SrKind.rock, lane: g.targetLane, z: g.dist + .5);
    g.things.add(next);
    run(g, .4);
    expect(next.bumped, isFalse);
    expect(g.hearts, SrGame.hearts0 - 1);
    run(g, SrGame.safeTime);
    g.things.add(SrThing(id: 1001, kind: SrKind.hay, lane: g.targetLane, z: g.dist + 1.3));
    g.jump();
    expect(run(g, 1).map((e) => e.kind), contains(SrEventKind.cleared));
    // a heart on the road gives one back
    g.things.add(SrThing(id: 1002, kind: SrKind.heart, lane: g.targetLane, z: g.dist + .3));
    expect(run(g, .3).map((e) => e.kind), contains(SrEventKind.heart));
    expect(g.hearts, SrGame.hearts0);
  });

  test('a ramp throws him into a big jump', () {
    final g = game(['cat']);
    g.start();
    run(g, SrGame.countdownTime + .1);
    g.things.add(SrThing(id: 999, kind: SrKind.ramp, lane: g.targetLane, z: g.dist + .4));
    final events = run(g, .2).map((e) => e.kind).toList();
    expect(events, contains(SrEventKind.ramp));
    run(g, .6);
    expect(g.air, greaterThan(1), reason: 'higher than a jump');
  });

  test('a high bar: he slides under it; riding or jumping into it is a bump; in the air a slide drops him first', () {
    final g = game(['cat']);
    g.start();
    run(g, SrGame.countdownTime + .1);
    g.things.removeWhere((t) => t.kind.obstacle);
    // sliding: under it, no bump
    final bar = SrThing(id: 999, kind: SrKind.bar, lane: g.targetLane, z: g.dist + 1.2);
    g.things.add(bar);
    g.slide();
    expect(g.sliding, isTrue);
    final passed = run(g, .4).map((e) => e.kind).toList();
    expect(passed, contains(SrEventKind.cleared));
    expect(bar.bumped, isFalse);
    expect(g.hearts, SrGame.hearts0);
    run(g, 1);
    expect(g.sliding, isFalse, reason: 'a slide ends by itself');
    // jumping into it: a bump
    final high = SrThing(id: 1000, kind: SrKind.bar, lane: g.targetLane, z: g.dist + 1.2);
    g.things.add(high);
    g.jump();
    run(g, .4);
    expect(high.bumped, isTrue);
    expect(g.hearts, SrGame.hearts0 - 1);
    // a slide in the air: down at once, then sliding
    run(g, SrGame.safeTime + 1);
    g.jump();
    run(g, .1);
    g.slide();
    expect(run(g, .2).map((e) => e.kind), containsAllInOrder([SrEventKind.land, SrEventKind.slide]));
    expect(g.sliding, isTrue);
    // and a jump gets him up from a slide
    g.jump();
    expect(g.sliding, isFalse);
  });

  test('a cart fills its lane: jumping or sliding into it is a bump, going around it is fine; the new low things are jumped', () {
    final g = game(['cat']);
    g.start();
    run(g, SrGame.countdownTime + .1);
    g.things.removeWhere((t) => t.kind.obstacle);
    final cart = SrThing(id: 999, kind: SrKind.cart, lane: g.targetLane, z: g.dist + 1.4);
    g.things.add(cart);
    g.jump();
    run(g, .4);
    expect(cart.bumped, isTrue, reason: 'too big to jump');
    run(g, SrGame.safeTime + .5);
    final other = SrThing(id: 1000, kind: SrKind.cart, lane: g.targetLane, z: g.dist + 4);
    g.things.add(other);
    g.move(g.targetLane == 1 ? -1 : 1);
    run(g, .8);
    expect(other.bumped, isFalse);
    expect(g.hearts, SrGame.hearts0 - 1);
    for (final k in [SrKind.bench, SrKind.flowerbox]) {
      final low = SrThing(id: 1001 + k.index, kind: k, lane: g.targetLane, z: g.dist + 1.3);
      g.things.add(low);
      g.jump();
      run(g, 1);
      expect(low.cleared, isTrue, reason: k.name);
    }
  });

  test('high bars come from the second stage on, never on the first words', () {
    final g = game(['cat', 'dog', 'sun', 'hat', 'bus', 'pen', 'cup', 'fox'], seed: 4);
    g.start();
    run(g, SrGame.countdownTime + .1);
    expect(g.things.where((t) => t.kind.high), isEmpty);
    run(g, 120, player: good);
    expect(g.stage, greaterThanOrEqualTo(1));
    expect(g.bumps, 0, reason: 'a good player slides under them');
    expect(g.things.where((t) => t.kind.high), isNotEmpty);
  });

  test('power-ups: the magnet pulls in stars from every lane, the shield takes a bump, the spring jumps over high bars, 2x doubles the points', () {
    final g = game(['cat']);
    g.start();
    run(g, SrGame.countdownTime + .1);
    g.things.removeWhere((t) => t.kind != SrKind.letter);
    void pick(SrKind k) {
      g.things.add(SrThing(id: 900 + k.index, kind: k, lane: g.targetLane, z: g.dist + .3));
      expect(run(g, .2).where((e) => e.kind == SrEventKind.power).map((e) => e.text), [k.name]);
      expect(g.has(k), isTrue);
    }

    // the magnet: a star in another lane
    pick(SrKind.magnet);
    final far = SrThing(id: 990, kind: SrKind.coin, lane: g.targetLane == 1 ? -1 : 1, z: g.dist + .4);
    g.things.add(far);
    run(g, .2);
    expect(far.taken, isTrue);
    // the shield: no heart lost, the thing broken, the shield gone
    pick(SrKind.shield);
    final log = SrThing(id: 991, kind: SrKind.log, lane: g.targetLane, z: g.dist + .3);
    g.things.add(log);
    expect(run(g, .2).map((e) => e.kind), contains(SrEventKind.shielded));
    expect(g.hearts, SrGame.hearts0);
    expect(g.has(SrKind.shield), isFalse);
    // the spring: over a high bar
    run(g, 1.2);
    pick(SrKind.spring);
    g.things.add(SrThing(id: 992, kind: SrKind.bar, lane: g.targetLane, z: g.dist + 2));
    g.jump();
    expect(run(g, .5).map((e) => e.kind), contains(SrEventKind.cleared));
    expect(g.hearts, SrGame.hearts0);
    run(g, 1.2);
    // 2x: a star is worth twice as much
    pick(SrKind.double);
    final before = g.score;
    g.things.add(SrThing(id: 993, kind: SrKind.coin, lane: g.targetLane, z: g.dist + .3));
    run(g, .1);
    expect(g.score - before, greaterThanOrEqualTo(20));
    // and each runs out
    run(g, 11);
    expect(g.powers, isEmpty);
  });

  test('a new part of the road every 500 m', () {
    final g = game(['cat', 'dog', 'sun', 'hat', 'bus', 'pen', 'cup', 'fox'], seed: 7);
    g.start();
    run(g, SrGame.countdownTime + .1);
    g.dist = (SrGame.zoneMetres - 1) / SrGame.metre;
    g.things.clear();
    final events = run(g, .5).where((e) => e.kind == SrEventKind.zone).toList();
    expect(events.map((e) => e.value), [1]);
    expect(g.zone, 1);
  });

  test('tasks follow what the child learned: capitals, small letters, then words to spell', () {
    final r = math.Random(3);
    final caps = SrTasks.forChild(MdKnowledge.of(testCourse, const []), words, r);
    expect(caps, isA<SrHunting>());
    final t = caps.next(0);
    expect(t.hunt && t.letters.length == 3 && t.letters == t.letters.toUpperCase(), isTrue);
    expect(t.say, startsWith('Catch '));
    expect(caps.next(7).letters.length, 4, reason: 'more catches later');
    final smallsDone = [for (final l in testCourse.levels) if (l.number <= 60) l.number];
    final smalls = SrTasks.forChild(MdKnowledge.of(testCourse, smallsDone), words, r);
    final small = smalls.next(0).letters;
    expect(small, small.toLowerCase());
    final readers = SrTasks.forChild(MdKnowledge.of(testCourse, [for (final l in testCourse.levels) if (l.number < 70) l.number]), words, r);
    expect(readers, isA<SrSpelling>());
    expect(readers.next(0).picture, isNotNull);
  });

  test('every picture and sound the game uses is in the app', () {
    for (final a in [...SrArt.all, SrArt.cover]) {
      expect(File(a).existsSync(), isTrue, reason: '$a: run tools/games/cut_runner_art.py');
    }
    for (final s in Sfx.spellRunner) {
      expect(File(s.asset).existsSync(), isTrue, reason: '${s.asset}: run tool/sound_design/generate_sfx.dart');
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/games/runner/\n'));
  });

  test('Pencil says every line as his bubble shows it (recorded in the app)', () {
    final lock = jsonDecode(File('../tools/voice/app_lines.lock.json').readAsStringSync()) as Map<String, dynamic>;
    void check(String text, String audio, {bool anyCase = false}) {
      final id = audio.split('/').last.replaceAll('.m4a', '');
      expect(File(audio).existsSync(), isTrue, reason: '$audio: run tools/voice/generate_voice.py --app');
      expect(File(LipSyncEnvelope.lipFileOf(audio)).existsSync(), isTrue, reason: audio);
      final says = (lock[id] as Map?)?['says'] as String?;
      expect(anyCase ? says?.toLowerCase() : says, anyCase ? text.toLowerCase() : text, reason: id);
    }

    for (final p in [SrLines.intro, ...SrLines.count, SrLines.go, ...SrLines.great, SrLines.oops, SrLines.bump, SrLines.jumpHint, SrLines.slideHint, SrLines.duck, SrLines.around, for (final k in [SrKind.magnet, SrKind.shield, SrKind.spring, SrKind.double]) SrLines.power(k), ...SrLines.zones, SrLines.record, SrLines.longer, SrLines.heart, SrLines.crash]) {
      check(p.text, p.audio!);
    }
    for (var c = 97; c < 123; c++) {
      final l = String.fromCharCode(c);
      check(SrLines.letter(l).text, SrLines.letter(l).audio!, anyCase: true);
      check(SrTask.hunt(l, small: true).say, SrTask.hunt(l, small: true).audio);
      check(SrTask.hunt(l.toUpperCase(), small: false).say, SrTask.hunt(l.toUpperCase(), small: false).audio);
    }
    for (final w in [...words.read, ...words.long]) {
      final t = SrTask.spell(w);
      check(t.say, t.audio);
      check(t.done!, t.doneAudio!);
      expect(File(t.picture!).existsSync(), isTrue, reason: w);
    }
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

    testWidgets('Games shows Spell Runner too', (tester) async {
      phone(tester);
      String? opened;
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: GamesScreen(onBack: () {}, onOpen: (id) => opened = id))));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('game-runner')), 200);
      expect(find.text('Spell Runner'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('game-runner')));
      expect(opened, GameIds.runner);
    });

    testWidgets('played with swipes and taps: Play, the countdown, the word, a lane, a jump, pause, stop', (tester) async {
      phone(tester);
      var done = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: SpellRunnerScreen(onDone: () => done = true, random: math.Random(2), tasks: SrList([SrTask.spell('cat')]))),
      ));
      await pumpFor(tester, 300);
      expect(find.text('Spell Runner'), findsOneWidget);
      expect(find.text(SrLines.intro.text), findsOneWidget, reason: 'a first game: the card says how to play');
      await tester.tap(find.byKey(const ValueKey('sr-play')));
      await pumpFor(tester, 400);
      expect(find.text('Three!'), findsOneWidget);
      await pumpFor(tester, 3400);
      expect(find.text('Go!'), findsWidgets);
      await pumpFor(tester, 1200);
      expect(find.text('Spell cat!'), findsOneWidget, reason: 'after "Go!", Pencil asks');
      expect(find.byKey(const ValueKey('sr-word')), findsOneWidget);
      final g = (tester.state(find.byType(SpellRunnerScreen)) as dynamic).debugGame as SrGame;
      expect(g.phase, SrPhase.running);
      // swipe right: a lane over; swipe up: a jump
      await tester.fling(find.byType(SpellRunnerScreen), const Offset(160, 0), 1200);
      await pumpFor(tester, 300);
      expect(g.targetLane, 1);
      await tester.fling(find.byType(SpellRunnerScreen), const Offset(0, -160), 1200);
      await tester.pump(const Duration(milliseconds: 100));
      expect(g.air, greaterThan(0));
      await pumpFor(tester, 900);
      await tester.tap(find.byKey(const ValueKey('sr-jump')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(g.air, greaterThan(0), reason: 'the Jump button');
      // swipe down: a slide; the Slide button comes with the first high bar
      await pumpFor(tester, 900);
      await tester.fling(find.byType(SpellRunnerScreen), const Offset(0, 160), 1200);
      await tester.pump(const Duration(milliseconds: 50));
      expect(g.sliding, isTrue);
      expect(find.byKey(const ValueKey('sr-slide')), findsNothing);
      g.things.add(SrThing(id: 5000, kind: SrKind.bar, lane: -1, z: g.dist + 30));
      await pumpFor(tester, 900);
      expect(find.byKey(const ValueKey('sr-slide')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sr-slide')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(g.sliding, isTrue, reason: 'the Slide button');
      // pause, keep playing, stop
      await pumpFor(tester, 900);
      await tester.tap(find.byKey(const ValueKey('sr-pause')));
      await pumpFor(tester, 300);
      expect(find.text('Paused'), findsOneWidget);
      final d = g.dist;
      await pumpFor(tester, 500);
      expect(g.dist, d, reason: 'paused: the road stops');
      await tester.tap(find.byKey(const ValueKey('sr-resume')));
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('sr-pause')));
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('sr-exit')));
      expect(done, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, 100);
    });

    testWidgets('a run until the third bump: Great run, the metres and words, the play counted, Play again', (tester) async {
      phone(tester);
      late ProviderContainer container;
      await tester.pumpWidget(ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(home: SpellRunnerScreen(onDone: () {}, random: math.Random(3), tasks: SrList([SrTask.spell('sun')])));
          },
        ),
      ));
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('sr-play')));
      final g = (tester.state(find.byType(SpellRunnerScreen)) as dynamic).debugGame as SrGame;
      // a good player for a while, then nobody steers
      for (var k = 0; k < 400; k++) {
        good(g);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(g.done, greaterThan(0));
      expect(find.byKey(const ValueKey('sr-hearts')), findsOneWidget);
      expect(find.byKey(const ValueKey('sr-metres')), findsOneWidget);
      for (var k = 0; k < 3000 && find.byKey(const ValueKey('sr-result')).evaluate().isEmpty; k++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Great run!'), findsOneWidget);
      expect(find.textContaining(' m · '), findsOneWidget);
      expect(container.read(gameProgressProvider).values.single[GameIds.runner]!.plays, 1);
      await tester.tap(find.byKey(const ValueKey('sr-again')));
      await pumpFor(tester, 600);
      expect(find.text('Three!'), findsOneWidget, reason: 'play again: the countdown');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, 100);
    });
  });
}
