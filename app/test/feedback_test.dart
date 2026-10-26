import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/feedback/app_feedback.dart';
import 'package:likho/feedback/game_feedback.dart';
import 'package:likho/feedback/haptics.dart';
import 'package:likho/feedback/sfx.dart';
import 'package:likho/feedback/sound_engine.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/screens/level_complete/level_complete_screen.dart';
import 'package:likho/screens/splash_screen.dart';

import 'test_course.dart';

class RecordingSound implements SoundEngine {
  final List<String> played = [];
  final List<String> loops = [];
  final Map<String, double> loopVolumes = {};
  @override
  Future<void> preload(Iterable<Sfx> sounds) async {}
  @override
  void play(Sfx sound, {double volume = 1}) => played.add(sound.name);
  @override
  void loop(Sfx sound, {double volume = 1}) => loops.add(sound.name);
  @override
  void stopLoop(Sfx sound) => loops.remove(sound.name);
  @override
  void loopVolume(Sfx sound, double volume) => loopVolumes[sound.name] = volume;
  @override
  void dispose() {}
}

class RecordingHaptics implements HapticsEngine {
  final List<HapticCue> played = [];
  @override
  void play(HapticCue cue) => played.add(cue);
}

(ProviderContainer, RecordingSound, RecordingHaptics) _container() {
  final sound = RecordingSound(), haptics = RecordingHaptics();
  final c = ProviderContainer(
    overrides: [
      courseProvider.overrideWith((ref) async => testCourse),
      soundEngineProvider.overrideWithValue(sound),
      hapticsProvider.overrideWithValue(haptics),
    ],
  );
  addTearDown(c.dispose);
  return (c, sound, haptics);
}

Future<void> _pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms; i += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('every sound file exists, and the folder is bundled', () {
    for (final s in Sfx.all) {
      expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
    }
    expect(Sfx.all.toSet().length, Sfx.all.length, reason: 'no duplicates');
    expect(Sfx.warm.every(Sfx.all.contains), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/sfx/'));
  });

  test('families clamp to the sounds that exist', () {
    expect(Sfx.correct(0).name, 'correct_1');
    expect(Sfx.correct(9).name, 'correct_5');
    expect(Sfx.step(8).name, 'step_6');
    expect(Sfx.star(3).name, 'star_3');
    expect({for (var i = 0; i < 6; i++) Sfx.tap(i).name}, {'tap_1', 'tap_2', 'tap_3'});
  });

  test('the parent\'s settings switch sounds and vibration off separately', () {
    final (c, sound, haptics) = _container();
    final fb = c.read(feedbackProvider);
    fb.correct();
    expect(sound.played, ['correct_1']);
    expect(haptics.played, [HapticCue.success]);

    c.read(familyProvider.notifier).updateSettings((s) => s.copyWith(sfx: false));
    fb.wrong();
    expect(sound.played, ['correct_1'], reason: 'sound off');
    expect(haptics.played.last, HapticCue.gentleError, reason: 'vibration still on');

    c.read(familyProvider.notifier).updateSettings((s) => s.copyWith(sfx: true, haptics: false));
    fb.reward();
    expect(sound.played.last, 'reward');
    expect(haptics.played.length, 2, reason: 'vibration off');
  });

  test('Monster Smash: the band creaks higher as it stretches; the music ducks under Pencil', () {
    final (c, sound, _) = _container();
    final fb = c.read(feedbackProvider);
    for (final level in [1, 2, 3]) {
      fb.stretch(level);
    }
    expect(sound.played, ['ms_stretch', 'ms_stretch_2', 'ms_stretch_3']);
    fb.smashMusic(true);
    fb.smashMusicQuiet(true);
    expect(sound.loopVolumes['ms_music'], lessThan(.2));
    fb.smashMusicQuiet(false);
    expect(sound.loopVolumes['ms_music'], .45);
  });

  testWidgets('gameplay: the chime climbs with each right answer in a row and resets after a mistake', (t) async {
    final (c, sound, haptics) = _container();
    // four picks of the first letters, the first on balloons
    final picks = [for (final n in [1, 2, 3, 4, 5]) ...testCourse.level(n).rounds.whereType<PickRound>()].take(4).toList();
    final level = levelWithRounds(testCourse.level(1), picks);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: GameFeedback(level: level, child: const SizedBox()),
        ),
      ),
    );
    final session = c.read(levelSessionProvider(level).notifier);
    int answer() {
      final r = c.read(levelSessionProvider(level)).current as PickRound;
      return r.options.indexWhere(r.isCorrect);
    }

    session.pick(answer());
    await t.pump();
    expect(sound.played, ['correct_1', 'balloon_pop'], reason: 'balloons pop too');
    await t.pump(GameTiming.afterCorrect);
    expect(sound.played.last, 'round_next');

    session.pick(answer());
    await t.pump();
    expect(sound.played.where((s) => s.startsWith('correct')), ['correct_1', 'correct_2']);
    await t.pump(GameTiming.afterCorrect);

    final wrong = (c.read(levelSessionProvider(level)).current as PickRound).options.indexWhere(
      (o) => !(c.read(levelSessionProvider(level)).current as PickRound).isCorrect(o),
    );
    session.pick(wrong);
    await t.pump();
    expect(sound.played.last, 'wrong');
    expect(haptics.played.last, HapticCue.gentleError);
    await t.pump(GameTiming.afterWrong);

    session.pick(answer());
    await t.pump();
    expect(sound.played.where((s) => s.startsWith('correct')).last, 'correct_1', reason: 'streak restarts');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('gameplay: tiles rise one note per step, then the chime', (t) async {
    final (c, sound, _) = _container();
    final level = onlyRounds(testCourse.level(5), (r) => r is OrderRound); // ABC order
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: GameFeedback(level: level, child: const SizedBox()),
        ),
      ),
    );
    final s = c.read(levelSessionProvider(level));
    final session = c.read(levelSessionProvider(level).notifier);
    for (var k = 0; k < s.tiles.length; k++) {
      session.placeTile(s.tiles.indexOf(k));
      await t.pump();
    }
    await t.pump(GameTiming.orderSettle);
    expect(sound.played, ['step_1', 'step_2', 'step_3', 'correct_1']);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('level complete: ta-da, one rising bell per star, confetti, coin, flourish', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (c, sound, haptics) = _container();
    await c.read(courseProvider.future);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: LevelCompleteScreen(
            level: testCourse.level(15),
            outcome: const LevelOutcome(level: 15, stars: 3, gain: 5, firstTime: true),
            onAgain: () {},
            onNext: () {},
          ),
        ),
      ),
    );
    await _pumpFor(t, 3700);
    expect(sound.played, ['complete_tada', 'star_1', 'boss_wake', 'star_2', 'star_3', 'confetti', 'coin', 'perfect']);
    expect(haptics.played.take(2), [HapticCue.celebrate, HapticCue.land]);
    expect(haptics.played, contains(HapticCue.landBig));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('splash: landing, a scribble per letter, swish, signature chime', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (c, sound, haptics) = _container();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: SplashScreen(onDone: () {})),
      ),
    );
    await _pumpFor(t, 2600);
    expect(sound.played.first, 'splash_land');
    expect(sound.played.where((s) => s.startsWith('scribble_')).length, 5);
    expect(sound.played.sublist(sound.played.length - 2), ['splash_swish', 'splash_chime']);
    expect(haptics.played, [HapticCue.land, HapticCue.press]);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
