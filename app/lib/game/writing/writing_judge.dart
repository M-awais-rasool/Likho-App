import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../data/models/course_models.dart';
import '../level_session.dart';

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

  /// A guide path moved into pad pixels (for the coverage check).
  Path padPath(Path guide) => guide.transform((Float64List(16)
        ..[0] = scale
        ..[5] = scale
        ..[10] = 1
        ..[15] = 1
        ..[12] = _offset.dx
        ..[13] = _offset.dy));
}

/// Decides if a drawing is good enough (the prototype's check()).
///
/// * trace / dots: at least 80 px of ink and >= 50 % of guide checkpoints
///   (15 per stroke) have ink within 34 px
/// * free: 50 px of ink (160 for sentences)
/// * spell / missing: 50 px of ink per letter
abstract final class WritingJudge {
  static const checkpoints = 15;
  static const reach = 34.0;

  static double inkLength(List<List<Offset>> strokes) {
    var l = 0.0;
    for (final s in strokes) {
      for (var i = 1; i < s.length; i++) {
        l += (s[i] - s[i - 1]).distance;
      }
    }
    return l;
  }

  /// Share of checkpoints along [guides] (pad pixels) that have ink nearby.
  static double coverage(List<Path> guides, List<List<Offset>> strokes) {
    if (guides.isEmpty) return 1;
    final ink = [for (final s in strokes) ...s];
    var hit = 0, total = 0;
    for (final g in guides) {
      for (final m in g.computeMetrics()) {
        for (var i = 0; i < checkpoints; i++) {
          final t = m.getTangentForOffset(m.length * i / (checkpoints - 1));
          if (t == null) continue;
          total++;
          if (ink.any((p) => (p - t.position).distance < reach)) hit++;
        }
      }
    }
    return total == 0 ? 1 : hit / total;
  }

  static WritingVerdict judge(WriteRound r, List<List<Offset>> strokes, List<Path> padGuides) {
    final ink = inkLength(strokes);
    final ok = switch (r.mode) {
      WriteMode.trace || WriteMode.dots => ink > 80 && coverage(padGuides, strokes) >= .5,
      WriteMode.free => ink > (r.sentence ? 160 : 50),
      WriteMode.missing || WriteMode.spell => ink > 50,
    };
    return ok ? WritingVerdict.accepted : WritingVerdict.rejected;
  }
}
