import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../data/models/course_models.dart';
import '../level_session.dart';
import 'stroke_guide.dart';
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

  /// Pad pixels -> guide space.
  Offset toGuide(Offset pad) => (pad - _offset) / scale;

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

/// Decides if a drawing is good enough.
///
/// * a letter with a guide (trace, dots, and free / missing / spell letters
///   that have strokes in the glyph table): every stroke written in order,
///   from its start, in its direction ([StrokeGuide])
/// * anything else (sentences, stories, letters without strokes): enough
///   ink: 50 px (160 for sentences)
abstract final class WritingJudge {
  /// Width of the lane children write in, in guide units (the letter box is
  /// 100 high; the drawn guide line is 7 wide).
  static const laneWidth = 15.0;

  static double inkLength(List<List<Offset>> strokes) {
    var l = 0.0;
    for (final s in strokes) {
      for (var i = 1; i < s.length; i++) {
        l += (s[i] - s[i - 1]).distance;
      }
    }
    return l;
  }

  /// [guide] = the round's step-by-step guide, or null when it has none.
  static WritingVerdict judge(WriteRound r, List<List<Offset>> strokes, StrokeGuide? guide) {
    final ok = guide != null ? guide.done : inkLength(strokes) > (r.mode == WriteMode.free && r.sentence ? 160 : 50);
    return ok ? WritingVerdict.accepted : WritingVerdict.rejected;
  }
}
