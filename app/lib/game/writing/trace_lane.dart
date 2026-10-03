import 'dart:math' as math;
import 'dart:ui';

/// The area a child may write in when tracing: every point within
/// [halfWidth] of a guide stroke (pad pixels). Ink outside it is not drawn,
/// so the letter can only be traced inside the lane the pad shows.
class TraceLane {
  TraceLane(List<Path> guides, {required this.halfWidth}) : strokes = [for (final g in guides) ..._sample(g)];

  /// Each guide stroke (every contour of every guide path) as a polyline.
  final List<List<Offset>> strokes;

  /// How far from the guide line ink may go (pad pixels).
  final double halfWidth;

  /// Distance between polyline points (pad pixels).
  static const step = 3.0;

  static Iterable<List<Offset>> _sample(Path p) sync* {
    for (final m in p.computeMetrics()) {
      final n = math.max(1, (m.length / step).ceil());
      yield [
        for (var i = 0; i <= n; i++)
          if (m.getTangentForOffset(m.length * i / n) case final t?) t.position,
      ];
    }
  }

  /// Total length of the guide strokes.
  double get length {
    var l = 0.0;
    for (final s in strokes) {
      for (var i = 1; i < s.length; i++) {
        l += (s[i] - s[i - 1]).distance;
      }
    }
    return l;
  }

  /// Distance from [p] to the nearest guide line.
  double distance(Offset p) {
    var best = double.infinity;
    for (final s in strokes) {
      if (s.length == 1) best = math.min(best, (p - s.first).distance);
      for (var i = 1; i < s.length; i++) {
        best = math.min(best, segmentDistance(p, s[i - 1], s[i]));
      }
    }
    return best;
  }

  bool contains(Offset p) => distance(p) <= halfWidth;

  /// Distance from [p] to the segment [a]–[b].
  static double segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}
