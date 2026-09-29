import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../data/models/course_models.dart';
import '../level_session.dart';
import 'trace_lane.dart';

/// Maps the letter-guide space onto the writing pad like the prototype's
/// SVG (viewBox "15 10 70 85", preserveAspectRatio xMidYMid meet).
class PadGeometry {
  PadGeometry(this.size)
      : scale = math.min(size.width / 70, size.height / 85),
        origin = Offset.zero {
    _offset = Offset((size.width - 70 * scale) / 2 - 15 * scale, (size.height - 85 * scale) / 2 - 10 * scale);
  }

  final Size size;
  final double scale;
  final Offset origin;
  late final Offset _offset;

  /// Guide space (0..100, baseline y = 70) -> pad pixels.
  Offset toPad(Offset guide) => _offset + guide * scale;

  /// Draw in guide space from here on.
  void apply(Canvas c) {
    c.translate(_offset.dx, _offset.dy);
    c.scale(scale);
  }

  /// A guide path moved into pad pixels (for the lane and the checks).
  Path padPath(Path guide) => guide.transform((Float64List(16)
        ..[0] = scale
        ..[5] = scale
        ..[10] = 1
        ..[15] = 1
        ..[12] = _offset.dx
        ..[13] = _offset.dy));

  /// The tracing lane around [guides] (guide space) on this pad.
  TraceLane lane(List<Path> guides) => TraceLane([for (final g in guides) padPath(g)], halfWidth: WritingJudge.laneWidth / 2 * scale);
}

/// How well a drawing matches a traced letter.
class TraceScore {
  const TraceScore({required this.strokes, required this.inside, required this.inkShare});

  /// Share of each guide stroke that was traced (0..1).
  final List<double> strokes;

  /// Share of the ink inside the lane (0..1).
  final double inside;

  /// Ink length / guide length (taps along the letter are not tracing).
  final double inkShare;

  double get weakest => strokes.isEmpty ? 1 : strokes.reduce(math.min);

  bool get passed => weakest >= WritingJudge.strokeCoverage && inside >= WritingJudge.insideShare && inkShare >= WritingJudge.minInkShare;
}

/// Decides if a drawing is good enough.
///
/// * trace / dots: the ink stays in the lane around the letter (the pad
///   does not draw outside it), every stroke of the letter is traced along
///   at least 80 % of its length, and it is real tracing (ink at least 60 %
///   of the letter's length, not a few taps)
/// * free: 50 px of ink (160 for sentences)
/// * spell / missing: 50 px of ink per letter
abstract final class WritingJudge {
  /// Width of the lane children trace in, in guide units (the letter box is
  /// 100 high; the drawn guide line is 7 wide).
  static const laneWidth = 15.0;

  /// Every stroke must be traced along this share of its length.
  static const strokeCoverage = .8;

  /// Share of the ink that must be inside the lane.
  static const insideShare = .9;

  /// Ink length compared with the letter's length.
  static const minInkShare = .6;

  /// Half the width of the drawn ink line (pad pixels).
  static const inkRadius = 7.0;

  /// How much moving across a stroke (rather than along it) counts against
  /// giving that stroke the ink, in lane half-widths.
  static const directionWeight = 2.0;

  static double inkLength(List<List<Offset>> strokes) {
    var l = 0.0;
    for (final s in strokes) {
      for (var i = 1; i < s.length; i++) {
        l += (s[i] - s[i - 1]).distance;
      }
    }
    return l;
  }

  /// Ink as points every [TraceLane.step] px, with the direction the
  /// finger was moving (zero for a tap).
  static List<(Offset, Offset)> _resample(List<List<Offset>> strokes) {
    final out = <(Offset, Offset)>[];
    for (final s in strokes) {
      final pts = <Offset>[if (s.isNotEmpty) s.first];
      for (var i = 1; i < s.length; i++) {
        final n = math.max(1, ((s[i] - s[i - 1]).distance / TraceLane.step).ceil());
        for (var k = 1; k <= n; k++) {
          pts.add(Offset.lerp(s[i - 1], s[i], k / n)!);
        }
      }
      for (var i = 0; i < pts.length; i++) {
        out.add((pts[i], _unit(pts[math.min(pts.length - 1, i + 2)] - pts[math.max(0, i - 2)])));
      }
    }
    return out;
  }

  static Offset _unit(Offset v) => v.distance == 0 ? Offset.zero : v / v.distance;

  /// How much of each stroke of [lane] the ink traces, and how much of the
  /// ink is inside it.
  ///
  /// Each bit of ink counts for one guide stroke: the one it is closest to
  /// and moving along (a diagonal is not filled in by ink crossing it, and
  /// the bowl of "a" does not fill in its stem). So every stroke must be
  /// traced, while a finger a little off the line still counts.
  static TraceScore score(TraceLane lane, List<List<Offset>> strokes) {
    final reach = lane.halfWidth + inkRadius;
    final spread = math.max(1, (inkRadius / TraceLane.step).round()); // an ink point covers ± this many guide points
    final tangents = [
      for (final s in lane.strokes) [for (var i = 0; i < s.length; i++) _unit(s[math.min(s.length - 1, i + 1)] - s[math.max(0, i - 1)])],
    ];
    final covered = [for (final s in lane.strokes) List<bool>.filled(s.length, false)];
    final ink = _resample(strokes);
    var inside = 0;
    for (final (q, dir) in ink) {
      if (lane.contains(q)) inside++;
      var best = double.infinity;
      var bs = -1, bi = -1;
      for (var si = 0; si < lane.strokes.length; si++) {
        final s = lane.strokes[si];
        for (var i = 0; i < s.length; i++) {
          final d = (s[i] - q).distance;
          if (d > reach) continue;
          // moving across a stroke instead of along it costs extra
          final t = tangents[si][i];
          final across = dir == Offset.zero ? 0.0 : 1 - (dir.dx * t.dx + dir.dy * t.dy).abs();
          final cost = d + directionWeight * lane.halfWidth * across;
          if (cost < best) (best, bs, bi) = (cost, si, i);
        }
      }
      if (bs < 0) continue;
      final c = covered[bs];
      for (var i = math.max(0, bi - spread); i <= math.min(c.length - 1, bi + spread); i++) {
        c[i] = true;
      }
    }
    final guide = lane.length;
    return TraceScore(
      strokes: [for (final c in covered) c.isEmpty ? 1 : c.where((x) => x).length / c.length],
      inside: ink.isEmpty ? 0 : inside / ink.length,
      inkShare: guide == 0 ? 1 : inkLength(strokes) / guide,
    );
  }

  /// [lane] = the tracing lane of the round (trace and dots), or null.
  static WritingVerdict judge(WriteRound r, List<List<Offset>> strokes, TraceLane? lane) {
    final ok = switch (r.mode) {
      WriteMode.trace || WriteMode.dots => lane == null ? inkLength(strokes) > 80 : score(lane, strokes).passed,
      WriteMode.free => inkLength(strokes) > (r.sentence ? 160 : 50),
      WriteMode.missing || WriteMode.spell => inkLength(strokes) > 50,
    };
    return ok ? WritingVerdict.accepted : WritingVerdict.rejected;
  }
}
