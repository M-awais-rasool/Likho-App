import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:likho/data/games.dart';
import 'package:likho/feedback/sfx.dart';
import 'package:likho/game/monster_defense/md_questions.dart';
import 'package:likho/game/monster_smash/ms_engine.dart';
import 'package:likho/mascot/lip_sync.dart';
import 'package:likho/screens/games/games_screen.dart';
import 'package:likho/screens/games/monster_smash/monster_smash_screen.dart';
import 'package:likho/screens/games/monster_smash/ms_lines.dart';
import 'package:likho/screens/games/monster_smash/ms_scene.dart';

/// Monster Smash: the towers, the slingshot, the letters (one a shot), the
/// help after misses, the questions from what the child learned, the screen.
void main() {
  final words = MdWords.fromJson(jsonDecode(File(MdWords.asset).readAsStringSync()) as Map<String, dynamic>);

  /// Ticks [g] for [seconds] at 60 frames a second; what happened.
  List<MsEvent> run(MsGame g, double seconds) {
    final out = <MsEvent>[];
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      g.tick(1 / 60);
      out.addAll(g.drain());
    }
    return out;
  }

  /// Ticks until the ball is back in the slingshot (or the tower is down).
  List<MsEvent> settle(MsGame g) {
    final out = <MsEvent>[];
    for (var k = 0; k < 60 * 15 && g.phase != MsPhase.aim && g.phase != MsPhase.cleared && !g.over; k++) {
      g.tick(1 / 60);
      out.addAll(g.drain());
    }
    return out;
  }

  /// A good player: aims at the asked letter (a high lob after a miss).
  void shoot(MsGame g) {
    final t = g.target!;
    g.launch(g.solve(t.position, high: g.misses.isOdd, ignore: {t.id}) ?? Vector2(-1, -.5));
  }

  /// A game whose tower is built and whose first question is asked.
  MsGame ready({int seed = 1, String letters = 'BDPRMNEFHKST'}) {
    final g = MsGame(asks: MsLetterList(letters), seed: seed)..start();
    run(g, 1.5);
    expect(g.phase, MsPhase.aim);
    return g;
  }

  test('a tower is built with its letters and monsters, and stands still', () {
    for (final seed in [1, 2, 3, 4]) {
      final g = MsGame(asks: MsLetterList('BDPRMNEFHKST'), seed: seed)..start();
      final events = run(g, 1.5).map((e) => e.kind).toList();
      expect(events, containsAllInOrder([MsEventKind.build, MsEventKind.ask]));
      expect(g.blocks.where((b) => b.letter != null).map((b) => b.letter), unorderedEquals(['B', 'D', 'P']));
      expect(g.towerAsks.map((a) => a.letter), unorderedEquals(['B', 'D']), reason: 'one the ball can reach first');
      final asked = g.blocks.where((b) => g.towerAsks.any((a) => a.letter == b.letter));
      if (asked.any(g.reachable)) expect(g.reachable(g.target!), isTrue, reason: 'seed $seed: the first letter asked is in sight');
      expect(g.monsters, hasLength(2));
      expect(g.balls, hasLength(4), reason: 'two spare balls');
      final at = {for (final b in g.blocks) b.id: b.position.clone()};
      final up = {for (final m in g.monsters) m.id: m.position.clone()};
      run(g, 5);
      for (final b in g.blocks) {
        expect(b.position.distanceTo(at[b.id]!), lessThan(.02), reason: 'seed $seed: nothing falls by itself');
      }
      for (final m in g.monsters) {
        expect(m.position.distanceTo(up[m.id]!), lessThan(.02));
        expect(m.friend, isFalse);
      }
    }
  });

  test('pulling the band: a small pull goes back, a big one sends the ball the other way', () {
    final g = ready();
    expect(g.grab(Vector2(12, 3)), isFalse, reason: 'the towers side is not the slingshot');
    expect(g.grab(MsGame.rest.clone()), isTrue);
    g.drag(MsGame.rest + Vector2(-.1, 0));
    g.release();
    expect(g.phase, MsPhase.aim, reason: 'a tiny pull: nothing flies');
    expect(g.balls, hasLength(4));
    g.grab(MsGame.rest.clone());
    g.drag(MsGame.rest + Vector2(-5, -1));
    expect(g.pull!.length, closeTo(MsGame.maxPull, 1e-6), reason: 'the band stretches only so far');
    final dots = MsGame.path(g.pull!);
    expect(dots[1].x, greaterThan(dots[0].x), reason: 'pulled left, it flies right');
    g.release();
    expect(g.phase, MsPhase.flying);
    expect(g.balls, hasLength(3));
    expect(g.drain().map((e) => e.kind), contains(MsEventKind.launch));
    final v = g.shot!.body.linearVelocity;
    expect(v.x, greaterThan(0));
    expect(v.y, greaterThan(0));
  });

  test('a monster knocked onto its side hops back onto its feet', () {
    final g = ready();
    final m = g.monsters.first;
    m.body.setTransform(Vector2(6, MsSize.monster + .02), math.pi / 2);
    m.body.linearVelocity = Vector2.zero();
    m.body.angularVelocity = 0;
    run(g, 4);
    expect(math.atan2(math.sin(m.angle), math.cos(m.angle)).abs(), lessThan(.35));
  });

  test('the asked letter bursts when the ball hits it; the next one is asked after the shot', () {
    // the first tower of a game whose first shot goes in (the bot's aim is
    // not always clear)
    var checked = 0;
    for (var seed = 1; seed <= 8; seed++) {
      final g = ready(seed: seed);
      final b = g.target!;
      final first = b.letter;
      shoot(g);
      final events = settle(g);
      final hits = events.where((e) => e.kind == MsEventKind.hit).toList();
      if (hits.isEmpty) continue;
      checked++;
      expect(hits, hasLength(1), reason: 'one letter a shot');
      expect(hits.single.text, first);
      expect(hits.single.value, 150, reason: 'first try');
      expect(b.gone, isTrue);
      expect(events.map((e) => e.kind), contains(MsEventKind.ask));
      expect(g.ask!.letter, isNot(first));
      expect(['B', 'D'], contains(g.ask!.letter));
      expect(g.found, 1);
      expect(g.misses, 0);
    }
    expect(checked, greaterThan(3));
  });

  test('a wrong letter is said; misses bring a hint, then Pencil pops it himself', () {
    final g = ready(seed: 3);
    final wrong = g.blocks.firstWhere((b) => b.letter != null && b.letter != g.ask!.letter);
    g.launch(g.solve(wrong.position, ignore: {wrong.id})!);
    final first = settle(g);
    final said = first.where((e) => e.kind == MsEventKind.wrong).toList();
    expect(said, hasLength(1));
    expect(said.single.text, wrong.letter);
    expect(wrong.gone, isFalse, reason: 'letters only burst when asked');
    expect(g.misses, 1);
    // into the ground, short of everything
    final all = <MsEvent>[];
    final asked = g.ask!.letter;
    while (g.misses < 5 && g.ask?.letter == asked) {
      g.launch(Vector2(.4, .4));
      all.addAll(settle(g));
    }
    expect(all.map((e) => e.kind), containsAll([MsEventKind.miss, MsEventKind.hint, MsEventKind.refill, MsEventKind.hit]));
    expect(all.firstWhere((e) => e.kind == MsEventKind.hint).text, asked);
    expect(g.ask!.letter, isNot(asked), reason: 'after five misses it popped by itself');
    expect(g.blocks.firstWhere((b) => b.letter == asked).gone, isTrue);
    expect(g.refills, greaterThan(0), reason: 'the basket filled up again');
    expect(g.stars, lessThan(3));
  });

  test('three towers make a game; every monster ends a friend', () {
    for (final seed in [1, 2, 5]) {
      final g = MsGame(asks: MsLetterList('BDPRMNEFHKST'), seed: seed)..start();
      final towers = <int>[];
      for (var k = 0; k < 60 * 60 * 6 && !g.over; k++) {
        if (g.phase == MsPhase.aim) shoot(g);
        g.tick(1 / 60);
        for (final e in g.drain()) {
          if (e.kind == MsEventKind.build) towers.add(e.value.round());
        }
        if (g.phase == MsPhase.cleared) expect(g.monsters.every((m) => m.friend), isTrue);
      }
      expect(g.over, isTrue, reason: 'seed $seed');
      expect(towers, [0, 1, 2]);
      expect(g.found, 2 + 3 + 3);
      expect(g.asked, g.found);
      expect(g.score, greaterThan(500));
      expect(g.stars, inInclusiveRange(1, 3));
    }
  });

  test('the questions come from what the child learned, about the tower\'s own letters', () {
    final r = math.Random(4);
    final caps = MsChildAsks(MdKnowledge.beginner, words, random: r);
    for (var k = 0; k < 20; k++) {
      final (shown, asks) = caps.tower(4, 3);
      expect(shown.toSet(), hasLength(4));
      expect(asks, hasLength(3));
      expect(MdKnowledge.starters, contains(asks.first.letter));
      for (final a in asks) {
        expect(shown, contains(a.letter));
        expect(a.letter, a.letter.toUpperCase());
        expect(a.audio, 'assets/voice/md_find_${a.letter.toLowerCase()}.m4a');
      }
      expect(asks.map((a) => a.letter).toSet(), hasLength(3), reason: 'each letter asked once');
    }
    const reader = MdKnowledge(capitals: MdKnowledge.starters, smalls: ['a', 'b', 'c', 'd', 'm', 's', 't', 'p', 'n', 'o', 'g'], firstSound: true);
    final mixed = MsChildAsks(reader, words, random: r);
    var pictures = 0;
    for (var k = 0; k < 30; k++) {
      final (shown, asks) = mixed.tower(5, 3);
      for (final a in asks) {
        expect(shown, contains(a.letter));
        if (a.picture != null) {
          pictures++;
          expect(File(a.picture!).existsSync(), isTrue);
          expect(a.picture, contains('/${a.letter}'), reason: 'the picture starts with the letter');
        }
      }
    }
    expect(pictures, greaterThan(0));
  });

  test('every picture, sound and line is in the app', () {
    for (final a in [...MsArt.all, MsArt.cover, for (final b in MsBackground.all) b.asset]) {
      expect(File(a).existsSync(), isTrue, reason: a);
    }
    for (final s in Sfx.monsterSmash) {
      expect(File('assets/sfx/${s.name}.wav').existsSync(), isTrue, reason: s.name);
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/games/smash/\n'));
    final lock = jsonDecode(File('../tools/voice/app_lines.lock.json').readAsStringSync()) as Map<String, dynamic>;
    for (final p in [
      MsLines.intro,
      MsLines.pullHint,
      MsLines.tower,
      ...MsLines.great,
      MsLines.miss,
      MsLines.oops,
      MsLines.hint,
      MsLines.refill,
      MsLines.cleared,
      MsLines.done,
      MsLines.record,
    ]) {
      final id = p.audio!.split('/').last.replaceAll('.m4a', '');
      expect(File(p.audio!).existsSync(), isTrue, reason: p.audio);
      expect(File(LipSyncEnvelope.lipFileOf(p.audio!)).existsSync(), isTrue, reason: p.audio);
      expect((lock[id] as Map?)?['says'], p.text, reason: id);
    }
    for (var c = 97; c < 123; c++) {
      final l = String.fromCharCode(c);
      expect(File(MsAsk.capital(l).nameAudio).existsSync(), isTrue);
      expect(File(MsAsk.capital(l).audio).existsSync(), isTrue);
      expect(File(MsAsk.small(l).audio).existsSync(), isTrue);
    }
  });

  group('the screen', () {
    void sideways(WidgetTester tester) {
      tester.view.physicalSize = const Size(932, 430);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpFor(WidgetTester t, int ms) async {
      for (var i = 0; i < ms; i += 50) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('Games shows Monster Smash too', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? opened;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: GamesScreen(onBack: () {}, onOpen: (id) => opened = id),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('game-smash')), 200);
      await tester.ensureVisible(find.byKey(const ValueKey('game-smash')));
      await tester.pump();
      expect(find.text('Monster Smash'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('game-smash')));
      expect(opened, GameIds.smash);
    });

    testWidgets('played with a finger: Play, the letter asked, pull and let go, pause, stop', (tester) async {
      sideways(tester);
      var done = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MonsterSmashScreen(onDone: () => done = true, asks: MsLetterList('BDPRMNEFHKST'), seed: 2),
          ),
        ),
      );
      await pumpFor(tester, 300);
      expect(find.text('Monster Smash'), findsOneWidget);
      expect(find.text(MsLines.intro.text), findsOneWidget, reason: 'a first game: the card says how to play');
      await tester.tap(find.byKey(const ValueKey('ms-play')));
      await pumpFor(tester, 1600);
      MsGame g0() => (tester.state(find.byType(MonsterSmashScreen)) as dynamic).debugGame as MsGame;
      expect(find.byKey(const ValueKey('ms-ask')), findsOneWidget);
      expect(find.text(g0().ask!.letter), findsWidgets);
      final g = (tester.state(find.byType(MonsterSmashScreen)) as dynamic).debugGame as MsGame;
      expect(g.phase, MsPhase.aim);
      expect(find.text(g0().ask!.say), findsOneWidget, reason: 'Pencil asks');
      await pumpFor(tester, 1500);
      // the finger on the ball, pulled back and down, let go
      final view = MsView(const Size(932, 430), MsBackground.meadow);
      final from = view.of(MsGame.rest);
      final drag = await tester.startGesture(from);
      for (var k = 1; k <= 10; k++) {
        await drag.moveTo(from + Offset(-6.0 * k, 3.0 * k));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(g.pull, isNotNull);
      expect(g.pull!.x, lessThan(0));
      await drag.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(g.phase, MsPhase.flying);
      expect(g.shots, 1);
      await pumpFor(tester, 2000);
      // pause, keep playing, stop
      await tester.tap(find.byKey(const ValueKey('ms-pause')));
      await pumpFor(tester, 300);
      expect(find.text('Paused'), findsOneWidget);
      final t = g.time;
      await pumpFor(tester, 500);
      expect(g.time, t, reason: 'paused: the world stops');
      await tester.tap(find.byKey(const ValueKey('ms-resume')));
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('ms-pause')));
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('ms-exit')));
      expect(done, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, 100);
    });

    testWidgets('a whole game: three towers, All smashed, the play counted, Play again', (tester) async {
      sideways(tester);
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: MonsterSmashScreen(onDone: () {}, asks: MsLetterList('BDPRMNEFHKST'), seed: 5),
              );
            },
          ),
        ),
      );
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('ms-play')));
      final g = (tester.state(find.byType(MonsterSmashScreen)) as dynamic).debugGame as MsGame;
      for (var k = 0; k < 4000 && find.byKey(const ValueKey('ms-result')).evaluate().isEmpty; k++) {
        if (g.phase == MsPhase.aim) shoot(g);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('All smashed!'), findsOneWidget);
      expect(find.textContaining('new friends'), findsOneWidget);
      expect(container.read(gameProgressProvider).values.single[GameIds.smash]!.plays, 1);
      await tester.tap(find.byKey(const ValueKey('ms-again')));
      await pumpFor(tester, 600);
      expect(find.text('Tower 1'), findsOneWidget, reason: 'play again: the first tower');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, 100);
    });
  });
}
