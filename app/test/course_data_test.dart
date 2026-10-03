import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/game/writing/stroke_guide.dart';
import 'package:likho/game/writing/writing_judge.dart';
import 'package:likho/screens/gameplay/rounds/write_round_view.dart';

import 'test_course.dart';

void main() {
  final course = testCourse;

  group('course.json (API-shaped static content)', () {
    test('6 worlds x 6 levels, every level playable', () {
      expect(course.schemaVersion, 1);
      expect(course.worlds.length, 6);
      expect(course.levels.length, 36);
      for (final l in course.levels) {
        expect(l.rounds, isNotEmpty, reason: l.id);
        expect(course.worlds.any((w) => w.id == l.worldId), isTrue, reason: l.id);
        expect(l.isBoss, l.number % 6 == 0, reason: '${l.id}: every 6th level is a boss');
      }
      final ids = [for (final l in course.levels) for (final r in l.rounds) r.id];
      expect(ids.toSet().length, ids.length, reason: 'round ids are unique');
      expect(ids.length, 179);
    });

    test('pick answers exist among the options', () {
      for (final l in course.levels) {
        for (final r in l.rounds.whereType<PickRound>()) {
          if (r.answer == null) continue; // "any" (story choices)
          expect(r.options.any((o) => o.label == r.answer), isTrue, reason: r.id);
        }
      }
    });

    test('write rounds have what their mode needs', () {
      for (final l in course.levels) {
        for (final r in l.rounds.whereType<WriteRound>()) {
          if (r.mode == WriteMode.trace || r.mode == WriteMode.dots) {
            expect(course.glyphs[r.guide], isNotNull, reason: '${r.id} guide ${r.guide}');
          }
          if (r.mode == WriteMode.missing) expect(r.missingIndex, lessThan(r.word!.length), reason: r.id);
          if (r.mode == WriteMode.spell) expect(r.word, isNotEmpty, reason: r.id);
        }
      }
    });

    test('unknown future round types are skipped, not fatal', () {
      final r = Round.fromJson({
        'id': 'x',
        'type': 'hologram',
        'prompt': {'text': 'hi'},
      }, r'$');
      expect(r, isA<UnknownRound>());
      expect(() => Round.fromJson({'id': 'x', 'type': 'pick', 'prompt': {'text': 1}}, r'$.levels[0].rounds[0]'),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(r'$.levels[0].rounds[0].prompt.text'))));
    });
  });

  group('rules', () {
    test('stars from mistakes', () {
      expect([starsFor(0), starsFor(1), starsFor(2), starsFor(3), starsFor(9)], [3, 2, 2, 1, 1]);
    });

    test('tile order is fixed per level/round and never already solved', () {
      for (var lv = 1; lv <= 36; lv++) {
        for (var rd = 0; rd < 5; rd++) {
          for (var n = 2; n <= 4; n++) {
            final o = tileOrder(level: lv, round: rd, count: n);
            expect(o.toSet().length, n);
            expect(o, isNot(List.generate(n, (i) => i)));
            expect(tileOrder(level: lv, round: rd, count: n), o);
          }
        }
      }
    });
  });

  group('step-by-step writing', () {
    const size = Size(342, 400);
    final rounds = [for (final l in [...course.levels, ?course.placement]) ...l.rounds.whereType<WriteRound>()];

    WritePadController padFor(WriteRound r, {int letter = 0}) =>
        WritePadController(round: r, guides: WritePadController.guidesFor(r, course.glyphs, letter: letter), letter: letter)..padSize = size;

    WriteRound round(bool Function(WriteRound r) test) => rounds.firstWhere(test);
    WriteRound trace(String key) => WriteRound(id: 'x', prompt: const Prompt(text: 'Trace'), mode: WriteMode.trace, target: key, guide: key);

    // the child's finger along a stroke (every other point), shifted by [off]
    List<Offset> along(List<Offset> stroke, {Offset off = Offset.zero}) => [
      for (var i = 0; i < stroke.length; i += 2) stroke[i] + off,
      stroke.last + off,
    ];

    /// Writes [ink] (one list per finger-down) and says what happened.
    List<PadEvent> write(WritePadController c, List<List<Offset>> ink) {
      final events = <PadEvent>[];
      c.addEventListener(events.add);
      for (final s in ink) {
        c.start(s.first);
        for (final p in s.skip(1)) {
          c.extend(p);
        }
        c.end();
      }
      c.removeEventListener(events.add);
      return events;
    }

    test('every single letter of the course has strokes to follow', () {
      for (final r in rounds) {
        if (r.sentence || r.story) continue;
        final letters = r.mode == WriteMode.spell ? r.word!.length : 1;
        for (var i = 0; i < letters; i++) {
          expect(WritePadController.guideKey(r, course.glyphs, letter: i), isNotNull, reason: '${r.id} letter $i');
        }
      }
      expect(course.glyphs.keys.toSet(), containsAll('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.split('')));
    });

    test('every letter is accepted when its strokes are followed in order (even a little off the line)', () {
      for (final key in course.glyphs.keys) {
        final r = trace(key);
        for (final off in [Offset.zero, const Offset(.4, .4), const Offset(-.4, -.4), const Offset(-.55, 0)]) {
          final c = padFor(r);
          final h = c.lane!.halfWidth;
          final events = write(c, [for (final s in c.lane!.strokes) along(s, off: off * h)]);
          expect(c.judge(), WritingVerdict.accepted, reason: '$key off=$off events=$events');
          expect(events.last, PadEvent.letterDone, reason: key);
          expect(events.where((e) => e == PadEvent.strokeDone).length, c.lane!.strokes.length - 1, reason: key);
        }
      }
    });

    test('one continuous line through strokes that meet still works (K, B)', () {
      for (final key in ['K', 'B']) {
        final c = padFor(trace(key));
        final strokes = c.lane!.strokes;
        write(c, [along(strokes[0])]);
        // lifts once, then draws the rest without lifting
        write(c, [
          [for (final s in strokes.skip(1)) ...along(s)],
        ]);
        expect(c.guide!.done, isTrue, reason: key);
      }
    });

    test('a stroke must start at its start and go its way', () {
      final c = padFor(round((r) => r.guide == 'L' && r.mode == WriteMode.trace));
      final stem = c.lane!.strokes.first;
      expect(write(c, [along(stem.reversed.toList())]), contains(PadEvent.wrongStart), reason: 'started at the bottom');
      expect(c.strokes, isEmpty, reason: 'no ink for a wrong start');
      expect(c.guide!.stroke, 0);
      final o = padFor(round((r) => r.guide == 'O'));
      final ring = o.lane!.strokes.first;
      write(o, [along([ring.first, ...ring.reversed])]); // the right start, the wrong way round
      expect(o.guide!.stroke, 0, reason: 'O drawn clockwise is not done');
      expect(o.guide!.progress, lessThan(.2));
    });

    test('strokes come in order: the second one first is not accepted', () {
      final c = padFor(round((r) => r.guide == 'T'));
      final events = write(c, [along(c.lane!.strokes[1])]); // the stem before the bar
      expect(events, contains(PadEvent.wrongStart));
      expect(c.guide!.stroke, 0);
      expect(c.judge(), WritingVerdict.rejected);
    });

    test('a lifted finger carries on where it stopped', () {
      final c = padFor(round((r) => r.guide == 'L' && r.mode == WriteMode.trace));
      final stem = c.lane!.strokes.first;
      final mid = stem.length ~/ 2;
      write(c, [along(stem.sublist(0, mid))]);
      expect(c.guide!.progress, closeTo(.5, .12));
      write(c, [along(stem.sublist(mid - 2))]);
      expect(c.guide!.stroke, 1);
    });

    test('half a letter is not enough', () {
      final c = padFor(round((r) => r.guide == 'a'));
      final bowl = c.lane!.strokes.first;
      write(c, [along(bowl)]);
      expect(c.judge(), WritingVerdict.rejected, reason: 'only the bowl: that is a c, not an a');
      final d = padFor(round((r) => r.guide == 'A'));
      write(d, [along(d.lane!.strokes.first.sublist(0, d.lane!.strokes.first.length ~/ 2))]);
      expect(d.judge(), WritingVerdict.rejected, reason: 'half the first stroke');
    });

    test('writing a D when b is asked is not a b', () {
      final b = round((r) => r.mode == WriteMode.free && r.target == 'b');
      final c = padFor(b);
      expect(c.guides, isNotEmpty, reason: 'free letters are guided too');
      // a D drawn big across the pad: stem, then a bowl on the right from top to bottom
      final geo = PadGeometry(size);
      final d = [for (final s in padFor(trace('D')).lane!.strokes) along(s)];
      write(c, d);
      expect(c.judge(), WritingVerdict.rejected);
      expect(c.guide!.stroke, lessThan(2));
      expect(geo.scale, greaterThan(0));
    });

    test('scribbles and taps are not writing', () {
      final c = padFor(round((r) => r.guide == 'L' && r.mode == WriteMode.trace));
      write(c, [
        [for (var i = 0; i < 40; i++) Offset(300 + (i.isEven ? 0 : 20), 20 + i * 2.0)],
      ]);
      expect(c.strokes, isEmpty);
      final l = c.lane!.strokes.first;
      write(c, [
        for (var i = 0; i < l.length; i += 40) [l[i]],
      ]);
      expect(c.guide!.progress, lessThan(.1), reason: 'taps far apart along the stem skip ahead');
      expect(c.judge(), WritingVerdict.rejected);
      expect(padFor(round((r) => r.guide == 'L' && r.mode == WriteMode.trace)).judge(), WritingVerdict.rejected, reason: 'nothing written');
    });

    test('a spelled word guides each letter in turn', () {
      final r = round((r) => r.mode == WriteMode.spell);
      for (var i = 0; i < r.word!.length; i++) {
        expect(padFor(r, letter: i).guides, isNotEmpty, reason: '${r.word}[$i]');
        expect(WritePadController.guideKey(r, course.glyphs, letter: i), r.word![i]);
      }
    });

    test('the eraser starts the letter again', () {
      final c = padFor(round((r) => r.guide == 'L' && r.mode == WriteMode.trace));
      write(c, [along(c.lane!.strokes.first)]);
      expect(c.guide!.stroke, 1);
      c.erase();
      expect((c.guide!.stroke, c.strokes.length), (0, 0));
    });

    test('instructions describe each stroke', () {
      StrokeShape shapeOf(String key, int i) => padFor(trace(key)).guide!.shapeOf(i);
      expect(shapeOf('A', 0), StrokeShape.slantDown);
      expect(shapeOf('A', 2), StrokeShape.right);
      expect(shapeOf('L', 0), StrokeShape.down);
      expect(shapeOf('O', 0), StrokeShape.curve);
      expect(shapeOf('V', 0), StrokeShape.zigzag);
      expect(shapeOf('i', 1), StrokeShape.dot);
    });

    test('sentences take any writing', () {
      final r = round((r) => r.sentence);
      final c = padFor(r);
      expect((c.guides.isEmpty, c.lane), (true, null));
      c.start(const Offset(5, 5));
      for (var x = 10.0; x < 300; x += 10) {
        c.extend(Offset(x, 40));
      }
      expect(c.judge(), WritingVerdict.accepted);
    });
  });
}
