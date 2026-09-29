import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/level_session.dart';
import 'package:likho/game/writing/writing_judge.dart';
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

  group('writing judge', () {
    const size = Size(342, 400);
    final geo = PadGeometry(size);
    final guideL = [for (final d in course.glyphs['L']!) geo.padPath(parseSvgPathData(d))];
    final write = course.level(3).rounds.whereType<WriteRound>().first; // "Trace L"

    List<Offset> along(Path p) {
      final m = p.computeMetrics().first;
      return [for (var i = 0; i <= 30; i++) m.getTangentForOffset(m.length * i / 30)!.position];
    }

    test('tracing the guide is accepted', () {
      final strokes = [for (final g in guideL) along(g)];
      expect(WritingJudge.judge(write, strokes, guideL), WritingVerdict.accepted);
    });

    test('a scribble somewhere else is rejected', () {
      final scribble = [
        [for (var i = 0; i < 40; i++) Offset(300 + (i.isEven ? 0 : 20), 20 + i * 2.0)],
      ];
      expect(WritingJudge.judge(write, scribble, guideL), WritingVerdict.rejected);
      expect(WritingJudge.judge(write, const [], guideL), WritingVerdict.rejected);
    });
  });
}
