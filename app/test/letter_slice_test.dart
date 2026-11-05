import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/games.dart';
import 'package:likho/feedback/sfx.dart';
import 'package:likho/game/letter_slice/ls_engine.dart';
import 'package:likho/game/monster_defense/md_questions.dart';
import 'package:likho/mascot/lip_sync.dart';
import 'package:likho/screens/games/games_screen.dart';
import 'package:likho/screens/games/letter_slice/letter_slice_screen.dart';
import 'package:likho/screens/games/letter_slice/ls_lines.dart';
import 'package:likho/screens/games/letter_slice/ls_scene.dart';

/// Letter Slice: the throws, the blade (a swipe cuts, a press does not),
/// right and wrong letters, words in order, the specials, the round's end,
/// the tasks from what the child learned, the screen.
void main() {
  final words = MdWords.fromJson(jsonDecode(File(MdWords.asset).readAsStringSync()) as Map<String, dynamic>);

  /// Ticks [g] for [seconds] at 60 frames a second; what happened.
  List<LsEvent> run(LsGame g, double seconds, {void Function(LsGame g)? player}) {
    final out = <LsEvent>[];
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      player?.call(g);
      g.tick(1 / 60);
      out.addAll(g.drain());
    }
    return out;
  }

  /// A quick swipe across fruit [f].
  void swipe(LsGame g, LsFruit f) {
    g.bladeDown(f.x - 1.3, f.y - .2);
    g.bladeMove(f.x + 1.3, f.y + .2, dt: .05);
    g.bladeUp();
  }

  /// A good player: now and then slices a fruit with the letter needed.
  void good(LsGame g) {
    if (g.phase != LsPhase.playing || (g.time * 60).round() % 20 != 0) return;
    final f = g.flying.where((f) => !f.cut && !f.bounced && f.letter == g.need && f.y > 1).firstOrNull;
    if (f != null) swipe(g, f);
  }

  /// A game that has started (after the countdown).
  LsGame playing(List<LsTask> tasks, {int seed = 1}) {
    final g = LsGame(tasks: LsList(tasks), height: 21.6, random: math.Random(seed))..start();
    final events = run(g, LsGame.countdownTime + .05).map((e) => e.kind).toList();
    expect(events.where((e) => e == LsEventKind.countdown), hasLength(3));
    expect(events, containsAll([LsEventKind.go, LsEventKind.task]));
    expect(g.phase, LsPhase.playing);
    return g;
  }

  test('fruits fly up with the letter asked among them, and fall back down', () {
    final g = playing([LsTask.letter('B')]);
    final seen = <String>{};
    var withB = 0, throws = 0;
    var before = 0;
    for (var t = 0.0; t < 12; t += 1 / 60) {
      g.tick(1 / 60);
      g.drain();
      final now = g.flying.where((f) => g.time - f.born < 1 / 59).toList();
      if (now.isNotEmpty && g.flying.length > before) {
        throws++;
        if (now.any((f) => f.letter == 'B')) withB++;
      }
      before = g.flying.length;
      for (final f in g.flying) {
        seen.add(f.letter ?? f.art);
        expect(f.x, inInclusiveRange(-1, LsGame.width + 1));
        expect(f.y, lessThan(g.height), reason: 'no fruit leaves the top');
      }
    }
    expect(throws, greaterThan(4));
    expect(withB, greaterThanOrEqualTo(throws - 1), reason: 'every throw has a B');
    expect(seen.length, greaterThan(3), reason: 'other letters too');
    expect(seen.where((l) => l.length == 1).every((l) => l == l.toUpperCase()), isTrue, reason: 'capitals with a capital task');
  });

  test('a swipe slices the right letter; a slow press does not; a wrong one bounces off', () {
    final g = playing([LsTask.letter('B')]);
    run(g, 1.2);
    final b = g.flying.firstWhere((f) => f.letter == 'B');
    // pressing slowly across it: no cut
    g.bladeDown(b.x - .5, b.y);
    g.bladeMove(b.x + .5, b.y, dt: 1);
    g.bladeUp();
    expect(b.cut, isFalse);
    swipe(g, b);
    expect(b.cut, isTrue);
    final cut = g.drain().where((e) => e.kind == LsEventKind.cut).single;
    expect(cut.text, 'B');
    expect(g.got, 1);
    expect(g.score, 10);
    // the wrong letter: it bounces, and costs two seconds (not in the task)
    LsFruit? other;
    run(g, 4, player: (g) => other ??= g.flying.where((f) => f.letter != null && f.letter != 'B' && f.y > 1).firstOrNull);
    final o = g.flying.contains(other) ? other! : g.flying.firstWhere((f) => f.letter != null && f.letter != 'B');
    final left = g.left;
    swipe(g, o);
    expect(o.cut, isFalse);
    expect(o.bounced, isTrue);
    expect(g.left, closeTo(left - 2, 1e-9));
    final wrong = g.drain().where((e) => e.kind == LsEventKind.wrong).single;
    expect(wrong.text, o.letter);
    expect(wrong.value, 2);
    swipe(g, o);
    expect(g.wrong, 1, reason: 'a bounced fruit counts once');
  });

  test('three of a letter finish the task; a word is sliced in order', () {
    final g = playing([LsTask.letter('B'), LsTask.spell('cat')]);
    final events = run(g, 40, player: good);
    final kinds = events.map((e) => e.kind).toList();
    expect(kinds.where((k) => k == LsEventKind.word).length, greaterThanOrEqualTo(2));
    final firstWord = events.firstWhere((e) => e.kind == LsEventKind.word);
    expect(firstWord.text, 'B');
    final cat = events.firstWhere((e) => e.kind == LsEventKind.word && e.text == 'cat');
    final cuts = events.takeWhile((e) => e != cat).where((e) => e.kind == LsEventKind.cut).map((e) => e.text).toList();
    expect(cuts.sublist(cuts.length - 3).join(), 'cat', reason: 'c, a, t in order');
    expect(g.done, greaterThanOrEqualTo(2));
  });

  test('a letter of the word that is not next bounces off but costs no time', () {
    final g = playing([LsTask.spell('cat')]);
    run(g, 1.2);
    final f = g.flying.first;
    // put an "a" before the "c" is sliced
    final a = LsFruit(id: 999, art: 'apple', kind: LsKind.fruit, x: 5, y: 8, vx: 0, vy: 0, spin: 0, r: LsGame.radius, letter: 'a');
    g.flying.add(a);
    final left = g.left;
    swipe(g, a);
    expect(a.bounced, isTrue);
    expect(g.left, left);
    expect(g.need, 'c');
    expect(f.cut, isFalse);
  });

  test('specials: the golden star, slow motion, the fruit party; three in one swipe is a combo', () {
    final g = playing([LsTask.letter('B', times: 50)]);
    LsFruit special(LsKind k) => LsFruit(id: 1000 + k.index, art: k.name, kind: k, x: 5, y: 8, vx: 0, vy: 0, spin: 0, r: LsGame.radius);
    final star = special(LsKind.star), berry = special(LsKind.berry), banana = special(LsKind.banana);
    g.flying.addAll([star, berry, banana]);
    final score = g.score;
    swipe(g, star);
    expect(g.score, score + 50);
    g.flying.remove(banana);
    swipe(g, berry);
    expect(g.slow, isTrue);
    g.flying.add(banana);
    swipe(g, banana);
    expect(g.frenzy, isTrue);
    g.drain();
    final party = run(g, 3);
    expect(party.where((e) => e.kind == LsEventKind.freeze || e.kind == LsEventKind.frenzy), isEmpty);
    final side = g.flying.where((f) => f.letter == 'B' && (f.vx.abs() > 3)).toList();
    expect(side.length, greaterThan(4), reason: 'fruits with B pour in from the sides');
    // three Bs in a row, one swipe
    g.flying.clear();
    for (var i = 0; i < 3; i++) {
      g.flying.add(LsFruit(id: 2000 + i, art: 'apple', kind: LsKind.fruit, x: 2 + i * 3, y: 8, vx: 0, vy: 0, spin: 0, r: LsGame.radius, letter: 'B'));
    }
    g.drain();
    g.bladeDown(.5, 8);
    g.bladeMove(9.5, 8, dt: .05);
    g.bladeUp();
    final combo = g.drain().where((e) => e.kind == LsEventKind.combo).single;
    expect(combo.value, 3);
    expect(g.bestCombo, 3);
  });

  test('the round ends when the time is up; the fruits in the air land first', () {
    final g = LsGame(tasks: LsList([LsTask.letter('m')]), height: 21.6, roundTime: 20, random: math.Random(3))..start();
    final events = run(g, 40, player: good).map((e) => e.kind).toList();
    expect(events, containsAllInOrder([LsEventKind.hurry, LsEventKind.tick, LsEventKind.timeUp, LsEventKind.done]));
    expect(events.where((e) => e == LsEventKind.tick), hasLength(5));
    expect(g.over, isTrue);
    expect(g.sliced, greaterThan(3));
    expect(g.stars, inInclusiveRange(1, 3));
  });

  test('the tasks come from what the child learned', () {
    final r = math.Random(5);
    final caps = LsChildTasks(MdKnowledge.beginner, words, random: r);
    for (var k = 0; k < 10; k++) {
      final t = caps.next(k);
      expect(t.letters, hasLength(3));
      expect(MdKnowledge.starters, contains(t.letters[0]));
      expect(t.say, 'Slice ${t.letters[0]}!');
    }
    const reader = MdKnowledge(capitals: MdKnowledge.starters, smalls: ['a', 'b', 'c', 'd', 'm', 's', 't', 'p', 'n', 'o', 'g'], firstSound: true, words: true);
    final all = LsChildTasks(reader, words, random: r);
    final kinds = <String>{};
    for (var k = 0; k < 40; k++) {
      final t = all.next(k);
      if (t.spelling) {
        kinds.add('word');
        expect(t.letters.length, lessThanOrEqualTo(4));
      } else if (t.picture != null) {
        kinds.add('picture');
        expect(File(t.picture!).existsSync(), isTrue);
      } else {
        kinds.add(t.letters == t.letters.toLowerCase() ? 'small' : 'capital');
      }
    }
    expect(kinds, containsAll(['word', 'picture']));
  });

  test('every picture, sound and line is in the app', () {
    for (final a in [...LsArt.all, LsArt.cover]) {
      expect(File(a).existsSync(), isTrue, reason: a);
    }
    for (final s in Sfx.letterSlice) {
      expect(File('assets/sfx/${s.name}.wav').existsSync(), isTrue, reason: s.name);
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/games/slice/\n'));
    final lock = jsonDecode(File('../tools/voice/app_lines.lock.json').readAsStringSync()) as Map<String, dynamic>;
    void check(String text, String audio) {
      final id = audio.split('/').last.replaceAll('.m4a', '');
      expect(File(audio).existsSync(), isTrue, reason: '$audio: run tools/voice/generate_voice.py --app');
      expect(File(LipSyncEnvelope.lipFileOf(audio)).existsSync(), isTrue, reason: audio);
      expect(((lock[id] as Map?)?['says'] as String?)?.toLowerCase(), text.toLowerCase(), reason: id);
    }

    for (final p in [
      LsLines.intro,
      ...LsLines.count,
      LsLines.go,
      ...LsLines.great,
      LsLines.oops,
      LsLines.combo,
      LsLines.star,
      LsLines.freeze,
      LsLines.frenzy,
      LsLines.hurry,
      LsLines.timeUp,
      LsLines.record,
    ]) {
      check(p.text, p.audio!);
    }
    for (var c = 97; c < 123; c++) {
      final l = String.fromCharCode(c);
      check(LsTask.letter(l).say, LsTask.letter(l).audio);
      check(LsTask.letter(l.toUpperCase()).say, LsTask.letter(l.toUpperCase()).audio);
      check(LsLines.letter(l).text, LsLines.letter(l).audio!);
    }
    for (final w in words.read.where((w) => w.length <= 4)) {
      final t = LsTask.spell(w);
      check(t.say, t.audio);
      check(t.done!, t.doneAudio!);
    }
    for (final w in words.first) {
      expect(File(LsTask.first(w).audio).existsSync(), isTrue, reason: w);
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

    testWidgets('Games shows Letter Slice too', (tester) async {
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
      await tester.scrollUntilVisible(find.byKey(const ValueKey('game-slice')), 200);
      await tester.ensureVisible(find.byKey(const ValueKey('game-slice')));
      await tester.pump();
      expect(find.text('Letter Slice'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('game-slice')));
      expect(opened, GameIds.slice);
    });

    testWidgets('played with a finger: Play, the countdown, the letter asked, a swipe slices it, pause, stop', (tester) async {
      phone(tester);
      var done = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LetterSliceScreen(onDone: () => done = true, tasks: LsList([LsTask.letter('B')]), random: math.Random(2)),
          ),
        ),
      );
      await pumpFor(tester, 300);
      expect(find.text('Letter Slice'), findsOneWidget);
      expect(find.text(LsLines.intro.text), findsOneWidget, reason: 'a first game: the card says how to play');
      await tester.tap(find.byKey(const ValueKey('ls-play')));
      await pumpFor(tester, 400);
      expect(find.text('Three!'), findsOneWidget);
      await pumpFor(tester, 3000);
      expect(find.byKey(const ValueKey('ls-task')), findsOneWidget);
      await pumpFor(tester, 900);
      expect(find.text('Slice B!'), findsOneWidget, reason: 'after "Go!", Pencil asks');
      final state = tester.state(find.byType(LetterSliceScreen)) as dynamic;
      final g = state.debugGame as LsGame;
      final view = state.debugView as LsView;
      expect(g.height, closeTo((844 - view.topInset) / 39, .01), reason: 'the board reserves space for the challenge');
      expect(view.at(5, g.height).dy, greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('ls-task'))).dy));
      // wait for a B high enough, then swipe across it
      LsFruit? b;
      for (var k = 0; k < 80 && b == null; k++) {
        await tester.pump(const Duration(milliseconds: 50));
        b = g.flying.where((f) => f.letter == 'B' && f.y > 6 && f.vy > 0).firstOrNull;
      }
      expect(b, isNotNull);
      final at = view.at(b!.x, b.y);
      final finger = await tester.startGesture(at - const Offset(70, 0));
      for (var k = 1; k <= 4; k++) {
        await finger.moveTo(at + Offset(-70 + 35.0 * k, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await finger.up();
      expect(b.cut, isTrue, reason: 'the swipe sliced it');
      expect(g.got, 1);
      await pumpFor(tester, 600);
      // pause, keep playing, stop
      await tester.tap(find.byKey(const ValueKey('ls-pause')));
      await pumpFor(tester, 300);
      expect(find.text('Paused'), findsOneWidget);
      final t = g.left;
      await pumpFor(tester, 500);
      expect(g.left, t, reason: 'paused: the clock stops');
      await tester.tap(find.byKey(const ValueKey('ls-resume')));
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('ls-pause')));
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('ls-exit')));
      expect(done, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, 100);
    });

    testWidgets('a whole round: time up, Great slicing, the play counted, Play again', (tester) async {
      phone(tester);
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: LetterSliceScreen(onDone: () {}, tasks: LsList([LsTask.letter('m'), LsTask.spell('sun')]), random: math.Random(3)),
              );
            },
          ),
        ),
      );
      await pumpFor(tester, 300);
      await tester.tap(find.byKey(const ValueKey('ls-play')));
      final g = (tester.state(find.byType(LetterSliceScreen)) as dynamic).debugGame as LsGame;
      for (var k = 0; k < 2400 && find.byKey(const ValueKey('ls-result')).evaluate().isEmpty; k++) {
        good(g);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Great slicing!'), findsOneWidget);
      expect(find.textContaining('fruits'), findsOneWidget);
      expect(g.done, greaterThan(0));
      expect(container.read(gameProgressProvider).values.single[GameIds.slice]!.plays, 1);
      await tester.tap(find.byKey(const ValueKey('ls-again')));
      await pumpFor(tester, 600);
      expect(find.text('Three!'), findsOneWidget, reason: 'play again: the countdown');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pumpFor(tester, 100);
    });
  });
}
