import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/mascot/lip_sync.dart';

import 'test_course.dart';

/// The course's pictures and recordings are in the app: no placeholder and
/// no silent line ships. (Pictures: tools/illustrations; recordings:
/// tools/voice, at the repository root.)
void main() {
  bool asset(String path) => File(path).existsSync();

  test('every picture the course shows has an illustration', () {
    final keys = <String>{};
    for (final l in [...testCourse.levels, ?testCourse.placement]) {
      if (l.intro.picture case final p?) keys.add(p.key);
      for (final r in l.rounds) {
        if (r.card?.picture case final p?) keys.add(p.key);
        if (r is PickRound) {
          for (final o in r.options) {
            if (o.picture case final p?) keys.add(p.key);
          }
          // My Story's picks are drawn together on Level Complete
          if (r.choiceKey != null) keys.addAll(r.options.map((o) => o.label));
        }
        // story strips show a picture per tile
        if (r is OrderRound && l.presentation.slot == 'panel') keys.addAll(r.tiles.map((t) => t.replaceAll(' ', '_')));
      }
    }
    final missing = [for (final k in keys) if (!asset('assets/illustrations/$k.png')) k]..sort();
    expect(missing, isEmpty, reason: 'run tools/illustrations/build_illustrations.py');
    expect(keys.length, greaterThan(90));
  });

  test('every intro and prompt has a recording with its mouth movement', () {
    final audio = <String>[];
    for (final l in [...testCourse.levels, ?testCourse.placement]) {
      if (l.number > 0) {
        expect(l.intro.say, isNotNull, reason: 'level ${l.number} intro');
        audio.add(l.intro.audio ?? 'level ${l.number} intro has no audio');
      }
      for (final r in l.rounds) {
        audio.add(r.prompt.audio ?? '${r.id} has no audio');
      }
    }
    final missing = [for (final a in audio) if (!asset(a) || !asset(LipSyncEnvelope.lipFileOf(a))) a];
    expect(missing, isEmpty, reason: 'run tools/voice/generate_voice.py');
    expect(audio.length, 36 + 182);
  });

  test('device voice reads the shown part of a pronunciation', () {
    expect(spokenText('Trace small {a|ˈeɪ}.'), 'Trace small a.');
    expect(spokenText('Which letter says {/b/|bʌ}?'), 'Which letter says /b/?');
    expect(const Prompt(text: 'c _ t', say: 'Cat! Which letter is missing?').spoken, 'Cat! Which letter is missing?');
    expect(const Prompt(text: 'Find B!').spoken, 'Find B!');
  });

  test('a recording\'s mouth movement: one byte per 1/100 s', () {
    final env = LipSyncEnvelope.fromBytes(ByteData.sublistView(Uint8List.fromList([0, 255, 128])))!;
    expect(env.levelAt(Duration.zero), 0);
    expect(env.levelAt(const Duration(milliseconds: 15)), 1);
    expect(env.levelAt(const Duration(milliseconds: 25)), closeTo(.5, .01));
    expect(env.levelAt(const Duration(seconds: 1)), 0, reason: 'after the end: closed');
    expect(LipSyncEnvelope.lipFileOf('assets/voice/level-01-intro.m4a'), 'assets/voice/level-01-intro.lip');
    final real = LipSyncEnvelope.fromBytes(ByteData.sublistView(File('assets/voice/level-01-intro.lip').readAsBytesSync()))!;
    expect(real.values.length, greaterThan(200), reason: 'the intro line lasts a few seconds');
  });
}
