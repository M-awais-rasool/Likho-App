import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../data/models/course_models.dart';
import '../level_session.dart';
import 'stroke_guide.dart';
import 'trace_lane.dart';

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

  Offset toPad(Offset guide) => _offset + guide * scale;

  Offset toGuide(Offset pad) => (pad - _offset) / scale;

  void apply(Canvas c) {
    c.translate(_offset.dx, _offset.dy);
    c.scale(scale);
  }

  Path padPath(Path guide) => guide.transform((Float64List(16)
        ..[0] = scale
        ..[5] = scale
        ..[10] = 1
        ..[15] = 1
        ..[12] = _offset.dx
        ..[13] = _offset.dy));

  TraceLane lane(List<Path> guides) => TraceLane([for (final g in guides) padPath(g)], halfWidth: WritingJudge.laneWidth / 2 * scale);
}

abstract final class WritingJudge {
  static const laneWidth = 12.0;

  static double inkLength(List<List<Offset>> strokes) {
    var l = 0.0;
    for (final s in strokes) {
      for (var i = 1; i < s.length; i++) {
        l += (s[i] - s[i - 1]).distance;
      }
    }
    return l;
  }

  static WritingVerdict judge(WriteRound r, List<List<Offset>> strokes, StrokeGuide? guide) {
    final ok = guide != null ? guide.done : inkLength(strokes) > (r.mode == WriteMode.free && r.sentence ? 160 : 50);
    return ok ? WritingVerdict.accepted : WritingVerdict.rejected;
  }
}
