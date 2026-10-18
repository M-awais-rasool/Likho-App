import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/story.dart';
import 'package:likho/mascot/lip_sync.dart';
import 'package:likho/screens/gameplay/rounds/write_round_view.dart';
import 'package:likho/screens/stories/episode_a_screen.dart';
import 'package:likho/screens/stories/stories_screen.dart';
import 'package:likho/screens/stories/story_art.dart';

import 'test_course.dart';

/// Story A, "Dada's Apple Garden": its words recorded as the bubble shows
/// them, its art in the app, and the whole story played to the golden apple.
void main() {
  final story = StoryEpisode.fromJson(jsonDecode(File(StoryEpisode.asset('a')).readAsStringSync()) as Map<String, dynamic>);
  final source = File('lib/screens/stories/episode_a_screen.dart').readAsStringSync();

  Future<void> pumpFor(WidgetTester t, int ms) async {
    for (var i = 0; i < ms; i += 50) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('every line the story says is in story.json, recorded with the words the bubble shows', () {
    final lock = jsonDecode(File('../tools/voice/app_lines.lock.json').readAsStringSync()) as Map<String, dynamic>;
    for (final m in RegExp(r"_say\('([a-z0-9_]+)'").allMatches(source)) {
      expect(story.lines.containsKey(m[1]), isTrue, reason: 'line "${m[1]}"');
    }
    for (final l in story.lines.values) {
      expect(story.names.containsKey(l.who), isTrue, reason: l.id);
      expect(File(l.audio).existsSync(), isTrue, reason: '${l.audio}: run tools/voice/generate_voice.py --app');
      expect(File(LipSyncEnvelope.lipFileOf(l.audio)).existsSync(), isTrue, reason: l.audio);
      expect((lock['story_a_${l.id}'] as Map?)?['says'], l.shown, reason: l.id);
      expect(l.shown, isNot(contains(RegExp(r'[{|}]'))), reason: '${l.id}: plain words in the bubble');
    }
  });

  test('every picture the story uses is in the app', () {
    for (final m in RegExp(r"name: '([a-z_]+)'").allMatches(source)) {
      expect(File(StoryArt.prop('a', m[1]!)).existsSync(), isTrue, reason: m[1]);
    }
    for (final m in RegExp(r"thing\('([a-z]+)'").allMatches(source)) {
      if (m[1] != 'airplane') expect(File(StoryArt.prop('a', m[1]!)).existsSync(), isTrue, reason: m[1]);
    }
    for (final who in ['ayan', 'dada', 'aunty', 'ant']) {
      expect(File(StoryArt.pose('a', who, 'idle')).existsSync(), isTrue, reason: who);
    }
    for (final m in RegExp(r"\('(ayan|dada|aunty|ant)', \([^)]*\), '([a-z]+)'\)").allMatches(source)) {
      expect(File(StoryArt.pose('a', m[1]!, m[2]!)).existsSync(), isTrue, reason: '${m[1]} ${m[2]}');
    }
    for (final m in RegExp(r"pose: '([a-z]+)'").allMatches(source)) {
      final pose = m[1]!;
      final anyone = ['ayan', 'dada', 'aunty', 'ant'].any((w) => File(StoryArt.pose('a', w, pose)).existsSync());
      expect(anyone, isTrue, reason: 'pose $pose');
    }
    for (final p in ['house', 'garden', 'market']) {
      expect(File(StoryArt.bg('a', p)).existsSync(), isTrue, reason: p);
    }
  });

  test('stars: gentle with mistakes, the best kept', () {
    expect([storyStars(0), storyStars(2), storyStars(3), storyStars(5), storyStars(6)], [3, 3, 2, 2, 1]);
  });

  testWidgets('the Stories screen: story A to play, the other letters coming', (tester) async {
    phone(tester);
    String? opened;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: StoriesScreen(onBack: () {}, onOpen: (id) => opened = id))));
    await tester.pump();
    expect(find.text("Dada's Apple Garden"), findsOneWidget);
    expect(find.text('Z'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('story-a')));
    expect(opened, 'a');
  });

  testWidgets('story A from the knock at the door to the golden apple', (tester) async {
    phone(tester);
    var done = false;
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: [courseProvider.overrideWith((ref) => testCourse)],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(home: EpisodeAScreen(onDone: () => done = true));
        },
      ),
    ));
    /// Pumps until [f] shows (the story goes on by itself between taps).
    Future<void> until(Finder f, {int max = 30000}) async {
      for (var ms = 0; ms < max; ms += 50) {
        if (f.evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 50));
      }
      final texts = [for (final e in find.byType(Text).evaluate()) (e.widget as Text).data].whereType<String>().toList();
      fail('never showed: $f; on screen: $texts; error: ${tester.takeException()}');
    }

    Finder line(String id) => find.text(story.line(id).shown);

    await until(line('knock'));
    await until(line('pick'));
    await pumpFor(tester, 1600);

    // pick the five apples
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(ValueKey('apple-$i')));
      await pumpFor(tester, 700);
    }
    await until(line('find'));
    await pumpFor(tester, 1600);

    // find: a wrong one (the bird), then the airplane, the ant, the apple
    await tester.tap(find.byKey(const ValueKey('find-bird')));
    await pumpFor(tester, 1700);
    await tester.tap(find.byKey(const ValueKey('find-airplane')));
    await pumpFor(tester, 1700);
    await tester.tap(find.byKey(const ValueKey('person-ant')));
    await pumpFor(tester, 1700);
    await tester.tap(find.byKey(const ValueKey('find-apple')));

    Future<void> writeA() async {
      await until(find.byType(WritePad));
      await pumpFor(tester, 500);
      final pad = find.byType(WritePad);
      final origin = tester.getTopLeft(pad);
      final c = tester.widget<WritePad>(pad).controller;
      for (final s in c.lane!.strokes) {
        final g = await tester.startGesture(origin + s.first);
        for (var i = 3; i < s.length; i += 3) {
          await g.moveTo(origin + s[i]);
        }
        await g.moveTo(origin + s.last);
        await g.up();
        await tester.pump(const Duration(milliseconds: 50));
      }
      await pumpFor(tester, 1500);
      expect(find.byType(WritePad), findsNothing, reason: 'the close-up closes once A is written');
    }

    // market: write A on the empty sign, then on three tags
    await until(line('sign'));
    await writeA();
    await until(line('signed'));
    for (final step in ['trace', 'dots', 'free']) {
      await until(line(step));
      await writeA();
    }
    await until(line('tagged'));

    // Aunty wants three apples
    await until(line('give'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('give-$i-false')));
      await pumpFor(tester, 700);
    }
    await until(line('thanks'));
    await until(line('saved'));
    await until(find.text('You won a golden apple!'));
    expect(container.read(storyProgressProvider).values.first['a'], 3, reason: 'one mistake: three stars');
    await tester.tap(find.text('Done'));
    expect(done, isTrue);
    expect(tester.takeException(), isNull);
    await pumpFor(tester, 3000);
    await tester.pumpWidget(const SizedBox());
  });
}
