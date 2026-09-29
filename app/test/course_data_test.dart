import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/game/writing/trace_lane.dart';
import 'package:likho/game/writing/writing_judge.dart';
import 'package:likho/screens/gameplay/rounds/write_round_view.dart';
import 'package:path_drawing/path_drawing.dart';

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

  group('writing judge (tracing)', () {
    const size = Size(342, 400);
    final geo = PadGeometry(size);
    TraceLane laneOf(String glyph) => geo.lane([for (final d in course.glyphs[glyph]!) parseSvgPathData(d)]);
    final traceL = course.level(3).rounds.whereType<WriteRound>().first; // "Trace L"
    final traceA = course.level(8).rounds.whereType<WriteRound>().firstWhere((r) => r.target == 'a');

    // the child's finger along a guide stroke, shifted by [off]
    List<Offset> along(List<Offset> stroke, {Offset off = Offset.zero}) => [
      for (var i = 0; i < stroke.length; i += 2) stroke[i] + off,
    ];

    test('every trace and dots round accepts its letter traced (even a little off the line)', () {
      for (final l in [...course.levels, ?course.placement]) {
        for (final r in l.rounds.whereType<WriteRound>()) {
          if (r.guide == null || (r.mode != WriteMode.trace && r.mode != WriteMode.dots)) continue;
          final lane = laneOf(r.guide!);
          final h = lane.halfWidth;
          // on the line, a little off it in each direction, and traced backwards
          final tries = <String, List<List<Offset>>>{
            'on the line': [for (final s in lane.strokes) along(s)],
            'down-right': [for (final s in lane.strokes) along(s, off: Offset(h * .45, h * .45))],
            'up-left': [for (final s in lane.strokes) along(s, off: Offset(-h * .45, -h * .45))],
            'left': [for (final s in lane.strokes) along(s, off: Offset(-h * .6, 0))],
            'backwards': [for (final s in lane.strokes) along(s.reversed.toList())],
          };
          for (final MapEntry(key: off, value: ink) in tries.entries) {
            final sc = WritingJudge.score(lane, ink);
            expect(WritingJudge.judge(r, ink, lane), WritingVerdict.accepted,
                reason: '${r.id} off=$off strokes=${sc.strokes.map((x) => x.toStringAsFixed(2))} inside=${sc.inside.toStringAsFixed(2)} ink=${sc.inkShare.toStringAsFixed(2)}');
          }
        }
      }
    });

    test('half a letter is not enough: every stroke must be traced', () {
      final l = laneOf('L');
      expect(WritingJudge.judge(traceL, [along(l.strokes.first)], l), WritingVerdict.rejected, reason: 'only the stem of L');
      final a = laneOf('a');
      expect(WritingJudge.judge(traceA, [along(a.strokes.first)], a), WritingVerdict.rejected, reason: 'only the bowl: that is a c, not an a');
      final half = a.strokes.first.sublist(0, a.strokes.first.length ~/ 2);
      expect(WritingJudge.judge(traceA, [along(half), along(a.strokes.last)], a), WritingVerdict.rejected, reason: 'half the bowl');
    });

    test('scribbles and taps are not tracing', () {
      final l = laneOf('L');
      final elsewhere = [
        [for (var i = 0; i < 40; i++) Offset(300 + (i.isEven ? 0 : 20), 20 + i * 2.0)],
      ];
      expect(WritingJudge.judge(traceL, elsewhere, l), WritingVerdict.rejected);
      expect(WritingJudge.judge(traceL, const [], l), WritingVerdict.rejected);
      final allOver = [
        for (var y = 0.0; y < size.height; y += 12) [const Offset(0, 0) + Offset(0, y), Offset(size.width, y)],
      ];
      expect(WritingJudge.judge(traceL, allOver, l), WritingVerdict.rejected, reason: 'most of the ink is outside the lane');
      final taps = [
        for (final s in l.strokes)
          for (var i = 0; i < s.length; i += 3) [s[i]],
      ];
      expect(WritingJudge.judge(traceL, taps, l), WritingVerdict.rejected, reason: 'dots along the letter are not a line');
    });
  });

  group('writing pad', () {
    const size = Size(342, 400);
    WritePadController pad(String glyph, WriteMode mode) {
      final r = course.levels.expand((l) => l.rounds).whereType<WriteRound>().firstWhere((r) => r.guide == glyph && r.mode == mode);
      return WritePadController(round: r, guides: WritePadController.guidesFor(r, course.glyphs))..padSize = size;
    }

    test('ink only goes inside the lane', () {
      final c = pad('L', WriteMode.trace);
      var left = 0;
      c.onLeaveLane = () => left++;
      final stem = c.lane!.strokes.first;
      c.start(const Offset(5, 5)); // outside: nothing
      expect(c.strokes, isEmpty);
      expect(left, 1);
      c.end();
      c.start(stem.first);
      c.extend(stem[10]);
      expect(c.extend(const Offset(330, 20)), isFalse, reason: 'slid out of the lane');
      expect(left, 2);
      expect(c.extend(stem[20]), isTrue, reason: 'back in: a new stroke');
      expect(c.strokes.length, 2);
      expect(c.strokes.expand((s) => s).every(c.lane!.contains), isTrue);
    });

    test('a fast jump across the gap between two strokes is not drawn', () {
      final c = pad('E', WriteMode.dots);
      final top = c.lane!.strokes[1], middle = c.lane!.strokes[2]; // the top and middle bars
      c.start(top.last);
      c.extend(middle.last); // straight down across the empty space
      expect(c.strokes.length, 2, reason: 'the move is cut, the middle bar starts a new stroke');
      expect(c.strokes.first.length, 1);
    });

    test('free writing has no lane', () {
      final r = course.level(6).rounds.whereType<WriteRound>().first; // "Write A"
      final c = WritePadController(round: r, guides: WritePadController.guidesFor(r, course.glyphs))..padSize = size;
      expect(c.lane, isNull);
      c.start(const Offset(5, 5));
      c.extend(const Offset(40, 40));
      expect(c.strokes.single.length, 2);
    });
  });
}
