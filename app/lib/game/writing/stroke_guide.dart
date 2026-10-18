import 'dart:math' as math;
import 'dart:ui';

import 'trace_lane.dart';

/// What a move of the finger did to the stroke being written.
enum Follow {
  /// Along the stroke (or back over the part already written): ink.
  on,

  /// Off the stroke, too far ahead, or the wrong way: no ink.
  off,

  /// The stroke is finished at this point; the next one starts.
  completed,
}

/// The shape of one stroke, for the mascot's instruction.
enum StrokeShape {
  dot,
  down,
  up,
  right,
  left,
  slantDown,
  slantUp,
  curve,
  zigzag;

  /// What to do with the stroke, as Pencil says it.
  String get instruction => switch (this) {
    dot => 'Add a dot',
    down => 'Top to bottom',
    up => 'Bottom to top',
    right => 'Left to right',
    left => 'Right to left',
    slantDown => 'Slant down',
    slantUp => 'Slant up',
    curve => 'Curve around',
    zigzag => 'Follow the arrow',
  };
}

/// Writing a letter step by step: one stroke at a time, in the letter's
/// order, starting at the stroke's start and moving in its direction.
///
/// The finger has to follow the stroke: it may only move a little ahead of
/// the part already written ([ahead]) and must stay within the lane's
/// half-width of the line. So a stroke cannot be started at the wrong end,
/// drawn backwards, skipped or replaced by another letter. A lifted finger
/// carries on where it stopped. The letter is complete when every stroke is.
class StrokeGuide {
  StrokeGuide(this.lane) : _arcs = [for (final s in lane.strokes) _cumulative(s)];

  /// The letter's strokes (pad pixels), in writing order.
  final TraceLane lane;
  final List<List<double>> _arcs;

  /// The stroke being written (== [count] when the letter is complete).
  int stroke = 0;

  /// How far along [stroke] the finger has come (index into its points).
  int reached = 0;

  int get count => lane.strokes.length;
  bool get done => stroke >= count;

  List<Offset> get points => lane.strokes[stroke];

  /// How near the start a stroke must begin.
  double get startRadius => lane.halfWidth * 1.4;

  /// How far past the written part the finger may be (a fast finger or a
  /// wide line is fine, jumping ahead is not).
  double get ahead => math.max(lane.halfWidth * 2, 24);

  /// Where the current stroke starts, or carries on after a lifted finger.
  Offset? get resumeAt => done ? null : points[reached];

  /// Share of the current stroke already written (0..1).
  double get progress {
    if (done) return 1;
    final a = _arcs[stroke];
    return a.last == 0 ? 0 : a[reached] / a.last;
  }

  /// Back to the first stroke (the eraser).
  void reset() {
    stroke = 0;
    reached = 0;
  }

  /// Moves on to the stroke after the current one (a finished stroke).
  void _next() {
    stroke++;
    reached = 0;
  }

  /// Can a finger put down at [p] begin the current stroke (near its start)
  /// or carry it on (on the part written so far)?
  bool canStart(Offset p) {
    if (done) return false;
    if (reached == 0) return (p - points.first).distance <= startRadius;
    return _match(p, resume: true) != null;
  }

  /// Follows the finger from [a] to [b] (a was accepted before). Also call
  /// it with a == b right after [canStart] to register the touch (a dot is
  /// finished by touching it).
  Follow move(Offset a, Offset b) {
    if (done) return Follow.off;
    final n = math.max(1, ((b - a).distance / TraceLane.step).ceil());
    for (var k = 1; k <= n; k++) {
      final i = _match(Offset.lerp(a, b, k / n)!);
      if (i == null) return Follow.off;
      if (i > reached) reached = i;
      if (_finished) {
        _next();
        return Follow.completed;
      }
    }
    return Follow.on;
  }

  /// The point of the current stroke the finger at [q] is at, looking up
  /// to [ahead] past the written part and a lane width back, or back to
  /// the start when a lifted finger carries on ([resume]). Null when it is
  /// not near.
  ///
  /// Of the points about as near as the nearest one, the furthest along
  /// wins: turning a sharp corner (V, N, M) the finger is nearly as close
  /// to the side it leaves as to the one it goes on with.
  int? _match(Offset q, {bool resume = false}) {
    final pts = points, arc = _arcs[stroke], h = lane.halfWidth;
    final limit = arc[reached] + ahead, back = resume ? 0.0 : arc[reached] - h;
    final d = <int, double>{};
    var nearest = double.infinity;
    for (var i = 0; i < pts.length && arc[i] <= limit; i++) {
      if (arc[i] < back) continue;
      final di = (pts[i] - q).distance;
      if (di > h) continue;
      d[i] = di;
      nearest = math.min(nearest, di);
    }
    int? best;
    for (final MapEntry(key: i, value: di) in d.entries) {
      if (di <= nearest + h * slack) best = i;
    }
    return best;
  }

  /// "About as near", in lane half-widths.
  static const slack = .35;

  bool get _finished {
    final arc = _arcs[stroke];
    final total = arc.last;
    return arc[reached] >= total - math.min(lane.halfWidth * .5, total * .25);
  }

  /// Rough shape of stroke [i], for telling the child what to do.
  StrokeShape shapeOf(int i) => shape(lane.strokes[i], lane.halfWidth);

  static StrokeShape shape(List<Offset> s, double halfWidth) {
    final arc = _cumulative(s);
    final len = arc.last;
    if (len < halfWidth * .5) return StrokeShape.dot;
    final chord = s.last - s.first;
    if (chord.distance / len > .97) {
      final dx = chord.dx, dy = chord.dy;
      if (dx.abs() < dy.abs() * .35) return dy > 0 ? StrokeShape.down : StrokeShape.up;
      if (dy.abs() < dx.abs() * .35) return dx > 0 ? StrokeShape.right : StrokeShape.left;
      return dy > 0 ? StrokeShape.slantDown : StrokeShape.slantUp;
    }
    // a sharp corner (V, M, Z…) or a smooth curve (C, O, S…)
    final step = halfWidth * .6;
    final pts = <Offset>[s.first];
    var next = step;
    for (var i = 1; i < s.length; i++) {
      if (arc[i] >= next) {
        pts.add(s[i]);
        next += step;
      }
    }
    for (var i = 2; i < pts.length; i++) {
      final u = pts[i - 1] - pts[i - 2], v = pts[i] - pts[i - 1];
      if (u.distance == 0 || v.distance == 0) continue;
      final cos = (u.dx * v.dx + u.dy * v.dy) / (u.distance * v.distance);
      if (cos < .5) return StrokeShape.zigzag; // turns more than 60°
    }
    return StrokeShape.curve;
  }

  static List<double> _cumulative(List<Offset> s) {
    final out = List<double>.filled(s.length, 0);
    for (var i = 1; i < s.length; i++) {
      out[i] = out[i - 1] + (s[i] - s[i - 1]).distance;
    }
    return out;
  }
}
