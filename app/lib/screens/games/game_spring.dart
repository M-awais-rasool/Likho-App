import 'dart:math' as math;
import 'dart:ui';

/// A damped spring: [value] chases [target] and overshoots a little, which
/// is what makes a body, an arm or a monster feel soft and alive instead of
/// snapping. [stiffness] is how hard it pulls, [damping] how fast the
/// wobble dies.
class Spring {
  Spring(this.value, {this.stiffness = 120, this.damping = 10}) : target = value;
  double value, target, velocity = 0;
  final double stiffness, damping;

  /// A kick (units per second), e.g. a landing or a let-go.
  void kick(double v) => velocity += v;

  /// Jumps to [v] and stays there.
  void snap(double v) {
    value = target = v;
    velocity = 0;
  }

  double step(double dt) {
    // small steps keep a stiff spring stable on a slow frame
    var left = dt;
    while (left > 0) {
      final h = math.min(left, 1 / 120);
      velocity += (-stiffness * (value - target) - damping * velocity) * h;
      value += velocity * h;
      left -= h;
    }
    return value;
  }
}

/// Two [Spring]s, for a point.
class Spring2 {
  Spring2(Offset at, {double stiffness = 120, double damping = 10})
    : _x = Spring(at.dx, stiffness: stiffness, damping: damping),
      _y = Spring(at.dy, stiffness: stiffness, damping: damping);
  final Spring _x, _y;

  Offset get value => Offset(_x.value, _y.value);
  set target(Offset t) {
    _x.target = t.dx;
    _y.target = t.dy;
  }

  void snap(Offset at) {
    _x.snap(at.dx);
    _y.snap(at.dy);
  }

  Offset step(double dt) => Offset(_x.step(dt), _y.step(dt));
}
