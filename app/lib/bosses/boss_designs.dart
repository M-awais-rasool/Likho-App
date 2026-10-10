import 'dart:math' as math;
import 'dart:ui';

import '../design/tokens.dart';
import 'boss_kit.dart';
import 'boss_pose.dart';

/// One world boss: its parts in a 120 x 100 artboard (feet on y = 94) and
/// how each part follows the pose channels.
abstract class BossDesign {
  BossDesign();

  /// Hovers above the ground (fish, cloud).
  bool get floats => false;

  /// Lives in a night world (light "z z z").
  bool get night => false;

  /// Where the "z z z" start (art units, before the body moves).
  Offset get zzzAt;

  /// Things that stay on the ground while the body hops (wheels, lily pad).
  void ground(Canvas c, BossPose p, double t) {}

  void body(Canvas c, BossPose p, double t);

  /// Arms hanging from a shoulder: 0 = down, positive = out to the left.
  static double armLeft(BossPose p) => .28 + p.raise * 2.1 + p.swing * .35 - p.zzz * .1;
  static double armRight(BossPose p) => -(.28 + p.raise * 2.1) + p.swing * .35 + p.zzz * .1;
}

/// Every boss, in [BossPainter.ids] order.
final List<BossDesign> bossDesigns = [
  _Snail(), _Fish(), _Bear(), _RobotBus(), _Cloud(), _Moon(), _Goat(), //
  _Crab(), _Ladybug(), _Monkey(), _Turtle(), _Frog(), _Dragon(), _Penguin(),
];

// ===================================================================== snail

class _Snail extends BossDesign {
  static final skin = Shade.of(BossColors.snailBody);
  static final shell = Shade.of(BossColors.snailShell);
  late final _foot = Cel(union([rrect(12, 72, 110, 93, 10.5), circle(31, 50, 22), rrect(13, 52, 50, 90, 16)]), skin);
  late final _shell = Cel(circle(75, 49, 29), shell, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _tip = Cel(circle(0, 0, 3.6), shell, line: 1.2);
  late final Path _spiral = () {
    final p = Path()..moveTo(77, 51);
    for (var a = .3; a <= 13.6; a += .25) {
      final r = 1.2 + a * 1.45;
      p.lineTo(77 + r * math.cos(a), 51 + r * math.sin(a));
    }
    return p;
  }();
  final _face = Face(lid: BossColors.snailBody, rim: Shade.of(BossColors.snailBody).line, r: 6);

  @override
  Offset get zzzAt => const Offset(102, 30);

  @override
  void body(Canvas c, BossPose p, double t) {
    _foot.paint(c);
    rotateAt(c, const Offset(75, 78), -p.tilt * .5 + p.squash * .6, () {
      _shell.paint(c);
      strokePath(c, _spiral, shell.line, 2.4);
      shine(c, 62, 32, 14, 8);
    });
    for (final (base, tip, side) in [(const Offset(23, 31), const Offset(15, 13), -1), (const Offset(39, 30), const Offset(46, 12), 1)]) {
      final a = side * .35 * p.zzz + .2 * p.swing - side * .1 * p.raise;
      rotateAt(c, base, a, () {
        tube(c, Path()..moveTo(base.dx, base.dy)..lineTo(tip.dx, tip.dy), skin, 3.4);
        c.save();
        c.translate(tip.dx, tip.dy);
        _tip.paint(c);
        c.restore();
      });
    }
    _face.paint(c, p, centre: const Offset(31, 51.5), gap: 13, mouthY: 9, cheekX: 13.5, cheekY: 6.4);
    snoreBubble(c, const Offset(34, 60), p.breath, p.zzz);
  }
}

// ===================================================================== fish

class _Fish extends BossDesign {
  static final skin = Shade.of(BossColors.fishBody, lineColor: BossColors.fishLine);
  static final band = Shade(BossColors.fishBand, BossColors.fishBand, BossColors.fishBandShade, BossColors.fishLine);
  late final _tail = Cel(Path()..moveTo(92, 54)..quadraticBezierTo(102, 40, 116, 31)..quadraticBezierTo(109, 54, 116, 77)..quadraticBezierTo(102, 68, 92, 54)..close(), skin);
  late final _dorsal = Cel(Path()..moveTo(38, 31)..quadraticBezierTo(54, 11, 80, 22)..quadraticBezierTo(80, 28, 76, 32)..close(), skin);
  late final Path _bodyPath = oval(56, 54, 86, 60);
  late final _body = Cel(_bodyPath, skin, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _bands = [oval(51, 54, 13, 72), oval(81, 54, 11, 66)];
  late final _fin = Cel(Path()..moveTo(58, 63)..quadraticBezierTo(70, 63, 74, 75)..quadraticBezierTo(64, 76, 57, 69)..close(), skin, line: 1.3);
  final _face = Face(lid: BossColors.fishBody, rim: BossColors.fishLine, r: 7);

  @override
  bool get floats => true;

  @override
  Offset get zzzAt => const Offset(62, 26);

  @override
  void body(Canvas c, BossPose p, double t) {
    rotateAt(c, const Offset(92, 54), p.swing * .3 + (p.flap - .3) * .25, () => _tail.paint(c));
    rotateAt(c, const Offset(60, 30), (p.flap - .3) * .12, () => _dorsal.paint(c));
    _body.paint(c);
    c.save();
    c.clipPath(_bodyPath);
    for (final b in _bands) {
      fillPath(c, b, band.base);
      strokePath(c, b, band.line, 1.6);
    }
    c.restore();
    strokePath(c, _bodyPath, skin.line, 1.6);
    shine(c, 40, 34, 16, 7);
    rotateAt(c, const Offset(58, 64), (p.flap - .3) * .5, () => _fin.paint(c));
    _face.paint(c, p, centre: const Offset(31, 49), gap: 14.5, mouthY: 11, cheekX: 11, cheekY: 8);
    snoreBubble(c, const Offset(31, 61), p.breath, p.zzz);
  }
}

// ===================================================================== bear

class _Bear extends BossDesign {
  static final fur = Shade.of(BossColors.bearFur);
  static final cream = Shade.of(BossColors.bearCream, lineColor: Shade.of(BossColors.bearFur).line);
  static final leaf = Shade.of(BossColors.autumnLeaf);
  late final _feet = [Cel(oval(44, 91, 21, 11), fur), Cel(oval(76, 91, 21, 11), fur)];
  late final _body = Cel(oval(60, 78, 58, 34), fur);
  late final _belly = Cel(oval(60, 81, 32, 22), cream, line: 0, dark: const Offset(1.6, 1.4));
  late final _armL = Cel(rrect(29, 64, 41, 87, 6), fur);
  late final _armR = Cel(rrect(79, 64, 91, 87, 6), fur);
  late final _ears = [Cel(circle(36, 25, 10.5), fur), Cel(circle(84, 25, 10.5), fur)];
  late final _earIn = [Cel(circle(36.5, 25.5, 5.4), cream, outline: false), Cel(circle(83.5, 25.5, 5.4), cream, outline: false)];
  late final _head = Cel(oval(60, 46, 66, 54), fur, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _muzzle = Cel(oval(60, 57, 27, 18), cream, line: 1.2);
  late final _leaf = Cel(Path()..moveTo(66, 22)..quadraticBezierTo(69, 11, 81, 12)..quadraticBezierTo(77, 22, 66, 22)..close(), leaf, line: 1.2);
  final _face = Face(lid: BossColors.bearFur, rim: Shade.of(BossColors.bearFur).line, r: 6.6);

  @override
  Offset get zzzAt => const Offset(94, 28);

  @override
  void body(Canvas c, BossPose p, double t) {
    for (final f in _feet) {
      f.paint(c);
    }
    fillPath(c, oval(44, 92.5, 9, 4.6), BossColors.pawPad);
    fillPath(c, oval(76, 92.5, 9, 4.6), BossColors.pawPad);
    _body.paint(c);
    _belly.paint(c);
    rotateAt(c, const Offset(35, 67), BossDesign.armLeft(p), () {
      _armL.paint(c);
      fillPath(c, oval(35, 84, 8, 5), BossColors.bearCream);
    });
    rotateAt(c, const Offset(85, 67), BossDesign.armRight(p), () {
      _armR.paint(c);
      fillPath(c, oval(85, 84, 8, 5), BossColors.bearCream);
    });
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1 : 1;
      rotateAt(c, Offset(i == 0 ? 41 : 79, 31), side * (.1 * p.swing.abs() + .08 * p.flap * (1 - p.zzz)), () {
        _ears[i].paint(c);
        _earIn[i].paint(c);
      });
    }
    _head.paint(c);
    _muzzle.paint(c);
    fillPath(c, oval(60, 52.4, 9.5, 6.2), BossColors.bearNose);
    shine(c, 58.4, 51, 3.4, 1.8, alpha: .8);
    rotateAt(c, const Offset(66, 22), .15 * p.swing, () {
      _leaf.paint(c);
      strokePath(c, Path()..moveTo(66, 22)..lineTo(62.5, 24.5), leaf.line, 1.3);
    });
    _face.cheeks(c, const Offset(43.5, 51), const Offset(76.5, 51));
    _face.pair(c, p, const Offset(60, 41.5), 16);
    _face.mouth(c, p, const Offset(60, 59.6));
    snoreBubble(c, const Offset(64, 52), p.breath, p.zzz);
  }
}

// ===================================================================== robot-bus

class _RobotBus extends BossDesign {
  static final paint = Shade.of(BossColors.busBody);
  static final glass = Shade(BossColors.busWindow, BossColors.busWindowLight, BossColors.busWindowShade, BossColors.busWindowLine);
  static final metal = Shade.of(BossColors.robotArm);
  late final _bodyPath = rrect(8, 22, 112, 80, 16);
  late final _body = Cel(_bodyPath, paint, light: const Offset(3, 3), dark: const Offset(3.4, 3.2));
  late final _window = Cel(rrect(16, 29, 104, 60, 10), glass, line: 1.2);
  late final _hand = Cel(circle(0, 0, 3.8), metal, line: 1.1);
  late final _stalk = Shade.of(BossColors.busDark);
  late final _lightOn = Cel(circle(60, 8, 4.2), Shade.of(BossColors.busLightOn, lineColor: BossColors.busDark), line: 1.1);
  late final _lightOff = Cel(circle(60, 8, 4.2), Shade.of(BossColors.busLightOff, lineColor: BossColors.busDark), line: 1.1);
  final _face = Face(lid: BossColors.busWindow, rim: BossColors.busWindowLine, r: 7.6);

  @override
  Offset get zzzAt => const Offset(100, 22);

  @override
  void ground(Canvas c, BossPose p, double t) {
    final spin = (1 - p.zzz) * t * 3;
    for (final x in [32.0, 88.0]) {
      fillPath(c, circle(x, 85, 11), BossColors.busDark);
      fillPath(c, circle(x, 85, 5), BossColors.busLightOff);
      for (var k = 0; k < 3; k++) {
        final a = spin + k * 2 * math.pi / 3;
        strokePath(c, Path()..moveTo(x, 85)..lineTo(x + 4.6 * math.cos(a), 85 + 4.6 * math.sin(a)), BossColors.busDark, 1.4);
      }
    }
  }

  @override
  void body(Canvas c, BossPose p, double t) {
    final on = p.zzz < .5;
    // arms behind the body
    for (final (pivot, elbow, hand, a) in [
      (const Offset(14, 58), const Offset(3, 66), const Offset(5, 77), BossDesign.armLeft(p) - .2),
      (const Offset(106, 58), const Offset(117, 66), const Offset(115, 77), BossDesign.armRight(p) + .2),
    ]) {
      rotateAt(c, pivot, a, () {
        tube(c, Path()..moveTo(pivot.dx, pivot.dy)..lineTo(elbow.dx, elbow.dy)..lineTo(hand.dx, hand.dy), metal, 3);
        c.save();
        c.translate(hand.dx, hand.dy);
        _hand.paint(c);
        c.restore();
      });
    }
    rotateAt(c, const Offset(60, 22), .2 * p.swing, () {
      tube(c, Path()..moveTo(60, 22)..lineTo(60, 11), _stalk, 1.8);
      final glow = on ? .6 + .4 * math.sin(t * 5) : 0.0;
      if (on) c.drawCircle(const Offset(60, 8), 7, Paint()..color = BossColors.busLightOn.withValues(alpha: .35 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      (on ? _lightOn : _lightOff).paint(c);
    });
    _body.paint(c);
    c.save();
    c.clipPath(_bodyPath);
    fillPath(c, rrect(4, 64, 116, 70, 0), paint.dark);
    c.restore();
    _window.paint(c);
    shine(c, 30, 34, 14, 4, alpha: .8);
    for (final x in [15.0, 105.0]) {
      fillPath(c, circle(x, 73, 4.4), on ? BossColors.busLightOn : BossColors.busLightOff);
      strokePath(c, circle(x, 73, 4.4), paint.line, 1.2);
    }
    _face.cheeks(c, const Offset(33, 50), const Offset(87, 50));
    _face.pair(c, p, const Offset(60, 42.5), 20);
    _face.mouth(c, p, const Offset(60, 52.5));
  }
}

// ===================================================================== cloud

class _Cloud extends BossDesign {
  static const fluff = Shade(BossColors.cloudBody, BossColors.cloudBody, BossColors.cloudShade, BossColors.cloudLine);
  late final _body = Cel(union([circle(33, 64, 20), circle(56, 47, 25), circle(82, 53, 21), circle(99, 70, 14), rrect(16, 60, 108, 90, 15)]), fluff,
      light: const Offset(2, 2), dark: const Offset(3.6, 3.2));
  late final _puff = Cel(circle(0, 0, 7), fluff, line: 1.3);
  final _face = Face(lid: BossColors.cloudBody, rim: BossColors.cloudLine, r: 7.2);

  @override
  bool get floats => true;

  @override
  Offset get zzzAt => const Offset(100, 34);

  @override
  void body(Canvas c, BossPose p, double t) {
    final rainbow = 1 - p.zzz;
    if (rainbow > 0) {
      for (final (i, col) in BossColors.rainbow.indexed) {
        strokePath(
          c,
          Path()..addArc(Rect.fromCircle(center: const Offset(60, 76), radius: 54 - i * 4.6), math.pi, math.pi),
          col.withValues(alpha: .9 * rainbow),
          4.8,
        );
      }
    }
    for (final (pivot, at, a) in [(const Offset(22, 72), const Offset(12, 77), BossDesign.armLeft(p) - .3), (const Offset(98, 74), const Offset(108, 79), BossDesign.armRight(p) + .3)]) {
      rotateAt(c, pivot, a, () {
        c.save();
        c.translate(at.dx, at.dy);
        _puff.paint(c);
        c.restore();
      });
    }
    _body.paint(c);
    shine(c, 46, 32, 14, 6, alpha: .9);
    _face.paint(c, p, centre: const Offset(58, 64), gap: 16, mouthY: 10.6, cheekX: 19, cheekY: 7.4);
    snoreBubble(c, const Offset(61, 74), p.breath, p.zzz);
  }
}

// ===================================================================== moon

class _Moon extends BossDesign {
  static final moon = Shade.of(BossColors.moon);
  static final crater = Shade(BossColors.moonCrater, BossColors.moon, BossColors.moonCraterShade, BossColors.moonCrater);
  static final cap = Shade.of(BossColors.nightcap);
  static const white = Shade(BossColors.cloudBody, BossColors.cloudBody, BossColors.cloudShade, BossColors.nightcapLine);
  late final _body = Cel(circle(60, 57, 36), moon, light: const Offset(3.2, 2.8), dark: const Offset(3.6, 3.2));
  late final _craters = [Cel(circle(84, 46, 5.4), crater, outline: false, light: const Offset(-1.4, -1.2)), Cel(circle(89, 71, 4), crater, outline: false, light: const Offset(-1.2, -1)), Cel(circle(36, 80, 3.6), crater, outline: false, light: const Offset(-1, -1)), Cel(circle(28, 58, 2.8), crater, outline: false, light: const Offset(-1, -1))];
  late final _arms = [Cel(oval(25, 72, 9, 15), moon, line: 1.3), Cel(oval(95, 72, 9, 15), moon, line: 1.3)];
  late final Path _capPath = Path()
    ..moveTo(25, 48)
    ..quadraticBezierTo(28, 15, 64, 15)
    ..quadraticBezierTo(94, 16, 107, 43)
    ..quadraticBezierTo(97, 35, 89, 36)
    ..lineTo(91, 40)
    ..quadraticBezierTo(60, 26, 25, 48)
    ..close();
  late final _cap = Cel(_capPath, cap);
  late final _pompom = Cel(circle(107, 45, 6.2), white, line: 1.3);
  final _face = Face(lid: BossColors.moon, rim: Shade.of(BossColors.moon).line, r: 7.2);

  @override
  bool get night => true;

  @override
  Offset get zzzAt => const Offset(102, 30);

  @override
  void body(Canvas c, BossPose p, double t) {
    final awake = 1 - p.zzz;
    for (final (i, o) in [const Offset(10, 26), const Offset(112, 22), const Offset(12, 90), const Offset(110, 88)].indexed) {
      twinkle(c, o, 3.6 * (.55 + .45 * math.sin(t * 3 + i * 1.7)) * awake, BossColors.starGold);
    }
    rotateAt(c, const Offset(28, 64), BossDesign.armLeft(p) - .2, () => _arms[0].paint(c));
    rotateAt(c, const Offset(92, 64), BossDesign.armRight(p) + .2, () => _arms[1].paint(c));
    _body.paint(c);
    for (final cr in _craters) {
      cr.paint(c);
    }
    rotateAt(c, const Offset(60, 30), .05 * p.swing, () {
      _cap.paint(c);
      c.save();
      c.clipPath(_capPath);
      for (final x in [52.0, 74.0, 92.0]) {
        strokePath(c, Path()..moveTo(x - 6, 10)..lineTo(x + 4, 46), BossColors.cloudBody.withValues(alpha: .85), 4.2);
      }
      c.restore();
      tube(c, Path()..moveTo(24, 47)..quadraticBezierTo(58, 24, 92, 38), white, 6);
      rotateAt(c, const Offset(96, 36), .3 * p.swing, () => _pompom.paint(c));
    });
    _face.paint(c, p, centre: const Offset(58, 61), gap: 18, mouthY: 11, cheekX: 20, cheekY: 7.6);
    snoreBubble(c, const Offset(62, 71), p.breath, p.zzz);
  }
}

// ===================================================================== goat

class _Goat extends BossDesign {
  static final fur = Shade.of(BossColors.goatFur, lineColor: BossColors.goatLine);
  static final horn = Shade.of(BossColors.goatHorn);
  static final pink = Shade.of(BossColors.goatEarInner, lineColor: BossColors.goatLine);
  static final muzzleShade = Shade.of(BossColors.goatMuzzle, lineColor: BossColors.goatLine);
  static final collar = Shade.of(BossColors.collar);
  static final bell = Shade.of(BossColors.bell);
  late final _legs = [Cel(rrect(43, 78, 53, 95, 4), fur), Cel(rrect(67, 78, 77, 95, 4), fur)];
  late final _body = Cel(oval(60, 80, 52, 26), fur);
  late final Path _earL = turned(oval(24, 49, 25, 11.5), const Offset(36, 45), -.35);
  late final _ears = [Cel(_earL, fur), Cel(mirror(_earL), fur)];
  late final _earIn = [Cel(turned(oval(25, 49, 15, 5.4), const Offset(36, 45), -.35), pink, outline: false), Cel(mirror(turned(oval(25, 49, 15, 5.4), const Offset(36, 45), -.35)), pink, outline: false)];
  late final _head = Cel(union([oval(60, 46, 54, 48), oval(60, 61, 36, 26)]), fur, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _muzzle = Cel(oval(60, 63, 30, 19), muzzleShade, line: 1.1);
  late final _tuft = Cel(union([circle(54, 25, 4.6), circle(60, 22.5, 5.2), circle(66, 25, 4.6)]), fur, line: 1.2);
  late final _collar = Cel(Path()..moveTo(41, 72)..quadraticBezierTo(60, 79, 79, 72)..lineTo(79, 76.5)..quadraticBezierTo(60, 83.5, 41, 76.5)..close(), collar, line: 1.1);
  late final _bell = Cel(circle(60, 84, 4.6), bell, line: 1.1);
  final _face = Face(lid: BossColors.goatFur, rim: BossColors.goatLine, r: 6.6);

  @override
  Offset get zzzAt => const Offset(96, 30);

  @override
  void body(Canvas c, BossPose p, double t) {
    for (final (i, l) in _legs.indexed) {
      rotateAt(c, Offset(i == 0 ? 48 : 72, 80), (i == 0 ? 1 : -1) * .06 * p.raise, () {
        l.paint(c);
        fillPath(c, rrect(i == 0 ? 43 : 67, 91, i == 0 ? 53 : 77, 95.4, 2.2), BossColors.goatHoof);
      });
    }
    _body.paint(c);
    _collar.paint(c);
    for (final (from, ctrl1, ctrl2, to) in [
      (const Offset(48, 30), const Offset(43, 13), const Offset(28, 8), const Offset(25, 21)),
      (const Offset(72, 30), const Offset(77, 13), const Offset(92, 8), const Offset(95, 21)),
    ]) {
      tube(c, Path()..moveTo(from.dx, from.dy)..cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, to.dx, to.dy), horn, 6);
    }
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1 : 1;
      rotateAt(c, Offset(i == 0 ? 37 : 83, 45), side * (.2 * p.swing.abs() + .22 * p.zzz - .1 * p.raise) + .1 * p.swing, () {
        _ears[i].paint(c);
        _earIn[i].paint(c);
      });
    }
    _head.paint(c);
    _tuft.paint(c);
    _muzzle.paint(c);
    fillPath(c, oval(55.6, 60.4, 2.4, 3), BossColors.goatHoof);
    fillPath(c, oval(64.4, 60.4, 2.4, 3), BossColors.goatHoof);
    rotateAt(c, const Offset(60, 79), .5 * p.swing, () {
      _bell.paint(c);
      strokePath(c, Path()..moveTo(57.5, 85.5)..lineTo(62.5, 85.5), bell.line, 1);
    });
    _face.cheeks(c, const Offset(43.5, 53), const Offset(76.5, 53));
    _face.pair(c, p, const Offset(60, 43.5), 16.5);
    _face.mouth(c, p, const Offset(60, 67.5));
    snoreBubble(c, const Offset(65, 61), p.breath, p.zzz);
  }
}

// ===================================================================== crab

class _Crab extends BossDesign {
  static final shell = Shade.of(BossColors.crabShell);
  late final _body = Cel(oval(60, 63, 82, 46), shell, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  final _face = Face(lid: BossColors.crabShell, rim: Shade.of(BossColors.crabShell).line, r: 7.4, brows: false);

  @override
  Offset get zzzAt => const Offset(94, 30);

  static Offset _turn(Offset pt, Offset o, double a) {
    final d = pt - o;
    return o + Offset(d.dx * math.cos(a) - d.dy * math.sin(a), d.dx * math.sin(a) + d.dy * math.cos(a));
  }

  void _claw(Canvas c, BossPose p, int side, double t) {
    // drawn on the left, mirrored for the right
    final open = (p.zzz > .5 ? .05 : .16 + .32 * p.flap) * (1 - .5 * p.zzz);
    const hinge = Offset(16, 40);
    const d = -2.05; // the pincer opens up and to the left
    Offset dir(double a) => Offset(math.cos(a), math.sin(a)) * 22;
    final wedge = Path()
      ..moveTo(hinge.dx, hinge.dy)
      ..lineTo(hinge.dx + dir(d - open).dx, hinge.dy + dir(d - open).dy)
      ..lineTo(hinge.dx + dir(d + open).dx, hinge.dy + dir(d + open).dy)
      ..close();
    final claw = Path.combine(PathOperation.difference, oval(13, 36, 21, 24), wedge);
    final shape = side < 0 ? claw : mirror(claw);
    strokePath(c, shape, shell.line, 3.2);
    fillPath(c, shape, shell.base);
    c.save();
    c.clipPath(shape);
    fillPath(c, (side < 0 ? oval(9, 33, 9, 12) : oval(111, 33, 9, 12)), shell.light);
    c.restore();
  }

  @override
  void body(Canvas c, BossPose p, double t) {
    for (var i = 0; i < 3; i++) {
      final w = math.sin(t * 10 + i * 2) * 1.6 * p.raise;
      for (final side in [-1.0, 1.0]) {
        final x0 = 60 + side * (26 - i * 5.0), y0 = 72 + i * 4.0;
        tube(c, Path()..moveTo(x0, y0)..lineTo(60 + side * (38 - i * 3.0), 80 + i * 3 + w)..lineTo(60 + side * (42 - i * 4.0), 93.5), shell, 2.8);
      }
    }
    for (final side in [-1, 1]) {
      final shoulder = Offset(60 + side * 28.0, 61);
      final a = -side * (.35 * p.raise - .5 * p.zzz) + .2 * p.swing;
      rotateAt(c, shoulder, a, () {
        tube(c, Path()..moveTo(shoulder.dx, shoulder.dy)..quadraticBezierTo(60 + side * 42.0, 58, 60 + side * 44.0, 46), shell, 4.6);
        _claw(c, p, side, t);
      });
    }
    // eye stalks sway; asleep they droop outwards
    final eyes = <Offset>[];
    for (final side in [-1, 1]) {
      final base = Offset(60 + side * 11.0, 46), tip = Offset(60 + side * 15.0, 29);
      final a = .12 * p.swing + side * .3 * p.zzz;
      tube(c, Path()..moveTo(base.dx, base.dy)..lineTo(_turn(tip, base, a).dx, _turn(tip, base, a).dy), shell, 3.2);
      eyes.add(_turn(tip + const Offset(0, -1), base, a));
    }
    _body.paint(c);
    for (final s in [circle(46, 50, 2.6), circle(74, 49, 2.2), circle(60, 46, 1.8)]) {
      fillPath(c, s, shell.light);
    }
    _face.cheeks(c, const Offset(44, 64), const Offset(76, 64));
    _face.eyes(c, p, eyes[0], eyes[1]);
    _face.mouth(c, p, const Offset(60, 65));
    snoreBubble(c, const Offset(63, 66), p.breath, p.zzz);
  }
}

// ===================================================================== ladybug

class _Ladybug extends BossDesign {
  static final shell = Shade.of(BossColors.ladybugShell);
  static final navy = Shade(BossColors.ladybugHead, BossColors.ladybugHeadLight, BossColors.ladybugHeadDark, BossColors.ladybugHeadLine);
  late final Path _shell = circle(60, 64, 30);
  late final _halves = [
    Cel(intersect(_shell, Path()..addRect(const Rect.fromLTRB(20, 30, 60, 100))), shell),
    Cel(intersect(_shell, Path()..addRect(const Rect.fromLTRB(60, 30, 100, 100))), shell),
  ];
  late final _head = Cel(oval(60, 34, 46, 34), navy);
  late final _tip = Cel(circle(0, 0, 3.2), shell, line: 1.1);
  late final _arms = [Cel(oval(33, 66, 8, 15), navy, line: 1.2), Cel(oval(87, 66, 8, 15), navy, line: 1.2)];
  final _face = const Face(lid: BossColors.ladybugHead, rim: BossColors.ladybugHeadLine, r: 7.4, light: true);

  @override
  Offset get zzzAt => const Offset(96, 26);

  @override
  void body(Canvas c, BossPose p, double t) {
    for (final side in [-1.0, 1.0]) {
      tube(c, Path()..moveTo(60 + side * 14, 86)..lineTo(60 + side * 18, 94.5), navy, 2.6);
    }
    final open = p.flap < .05 ? 0.0 : ((p.raise - .6) / .4).clamp(0.0, 1.0);
    if (open > 0) {
      for (final side in [-1.0, 1.0]) {
        rotateAt(c, Offset(60 + side * 14, 44), side * (.9 + .35 * p.flap) * open, () {
          final w = oval(60 + side * 14, 68, 22, 44);
          fillPath(c, w, BossColors.ladybugWing.withValues(alpha: .8 * open));
          strokePath(c, w, BossColors.ladybugWingLine.withValues(alpha: open), 1.2);
        });
      }
    }
    for (final (i, h) in _halves.indexed) {
      final side = i == 0 ? -1.0 : 1.0;
      rotateAt(c, const Offset(60, 38), 0, () {
        h.paint(c);
        for (final s in [Offset(60 + side * 16, 54), Offset(60 + side * 20, 72), Offset(60 + side * 9, 85)]) {
          fillPath(c, circle(s.dx, s.dy, side == -1 && s.dy > 80 ? 4 : 5), BossColors.ladybugHead);
        }
      });
    }
    shine(c, 44, 46, 10, 5);
    for (final side in [-1.0, 1.0]) {
      final base = Offset(60 + side * 8, 22);
      final tip = Offset(60 + side * 18, 7);
      rotateAt(c, base, .2 * p.swing + side * .2 * p.zzz, () {
        tube(c, Path()..moveTo(base.dx, base.dy)..quadraticBezierTo(60 + side * 11, 11, tip.dx, tip.dy), navy, 1.8);
        c.save();
        c.translate(tip.dx, tip.dy);
        _tip.paint(c);
        c.restore();
      });
    }
    _head.paint(c);
    rotateAt(c, const Offset(33, 59), BossDesign.armLeft(p), () {
      _arms[0].paint(c);
      fillPath(c, circle(33, 73, 3.6), BossColors.ladybugHead);
    });
    rotateAt(c, const Offset(87, 59), BossDesign.armRight(p), () {
      _arms[1].paint(c);
      fillPath(c, circle(87, 73, 3.6), BossColors.ladybugHead);
    });
    _face.paint(c, p, centre: const Offset(60, 32), gap: 17, mouthY: 11.4, cheekX: 17, cheekY: 7.6);
    snoreBubble(c, const Offset(63, 43), p.breath, p.zzz);
  }
}

// ===================================================================== monkey

class _Monkey extends BossDesign {
  static final fur = Shade.of(BossColors.monkeyFur);
  static final face = Shade.of(BossColors.monkeyFace, lineColor: Shade.of(BossColors.monkeyFur).line);
  late final _feet = [Cel(oval(46, 92, 18, 9), face), Cel(oval(74, 92, 18, 9), face)];
  late final _body = Cel(oval(60, 79, 46, 30), fur);
  late final _belly = Cel(oval(60, 81, 28, 20), face, outline: false);
  late final _arms = [Cel(rrect(36, 65, 44, 88, 4), fur), Cel(rrect(76, 65, 84, 88, 4), fur)];
  late final _hand = Cel(circle(0, 0, 4.6), face, line: 1.1);
  late final _ears = [Cel(circle(29, 44, 11.5), fur), Cel(circle(91, 44, 11.5), fur)];
  late final _earIn = [Cel(circle(29.5, 44.5, 6), face, outline: false), Cel(circle(90.5, 44.5, 6), face, outline: false)];
  late final _head = Cel(circle(60, 44, 27), fur, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _tuft = Cel(Path()..moveTo(53, 20)..quadraticBezierTo(55, 9, 65, 11)..quadraticBezierTo(59, 13, 63, 19)..close(), fur, line: 1.2);
  late final _mask = Cel(union([circle(51, 42, 11.5), circle(69, 42, 11.5), oval(60, 55, 36, 22)]), face, line: 1.2);
  final _face = Face(lid: BossColors.monkeyFace, rim: Shade.of(BossColors.monkeyFur).line, r: 6.6);

  @override
  Offset get zzzAt => const Offset(94, 26);

  @override
  void body(Canvas c, BossPose p, double t) {
    rotateAt(c, const Offset(76, 86), .2 * p.swing, () {
      tube(c, Path()..moveTo(76, 86)..cubicTo(100, 94, 113, 70, 103, 58)..cubicTo(96, 50, 104, 43, 109, 48), fur, 4.4);
    });
    for (final f in _feet) {
      f.paint(c);
    }
    _body.paint(c);
    _belly.paint(c);
    for (final (i, a) in [BossDesign.armLeft(p), BossDesign.armRight(p)].indexed) {
      final x = i == 0 ? 40.0 : 80.0;
      rotateAt(c, Offset(x, 67), a, () {
        _arms[i].paint(c);
        c.save();
        c.translate(x, 88);
        _hand.paint(c);
        c.restore();
      });
    }
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1 : 1;
      rotateAt(c, Offset(i == 0 ? 36 : 84, 44), side * .12 * p.swing.abs(), () {
        _ears[i].paint(c);
        _earIn[i].paint(c);
      });
    }
    _head.paint(c);
    _tuft.paint(c);
    _mask.paint(c);
    fillPath(c, oval(57.6, 52.6, 1.8, 1.4), BossColors.monkeyFur);
    fillPath(c, oval(62.4, 52.6, 1.8, 1.4), BossColors.monkeyFur);
    _face.cheeks(c, const Offset(44, 51), const Offset(76, 51));
    _face.pair(c, p, const Offset(60, 41.5), 18);
    _face.mouth(c, p, const Offset(60, 58.5));
    snoreBubble(c, const Offset(63, 54), p.breath, p.zzz);
  }
}

// ===================================================================== turtle

class _Turtle extends BossDesign {
  static final shell = Shade.of(BossColors.turtleShell);
  static final plate = Shade.of(BossColors.turtlePlate, lineColor: Shade.of(BossColors.turtleShell).line);
  static final rim = Shade.of(BossColors.turtleRim);
  static final skin = Shade.of(BossColors.turtleSkin);
  static final flower = Shade.of(BossColors.hibiscus);
  late final Path _dome = Path()
    ..moveTo(9, 83)
    ..cubicTo(9, 42, 32, 28, 50, 28)
    ..cubicTo(68, 28, 91, 42, 91, 83)
    ..close();
  late final _domeCel = Cel(_dome, shell, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _rim = Cel(oval(50, 82, 86, 15), rim, line: 1.3);
  late final _legs = [Cel(rrect(22, 79, 34, 95, 5), skin), Cel(rrect(72, 79, 84, 95, 5), skin)];
  late final _tail = Cel(Path()..moveTo(13, 80)..lineTo(3, 86)..lineTo(14, 88)..close(), skin, line: 1.2);
  late final _neck = Cel(rrect(78, 56, 94, 84, 8), skin);
  late final _head = Cel(circle(96, 49, 18), skin, light: const Offset(2.6, 2.4), dark: const Offset(3, 2.8));
  late final _petals = Cel(union([for (var i = 0; i < 5; i++) circle(104 + 4.6 * math.cos(i * 2 * math.pi / 5 - math.pi / 2), 31 + 4.6 * math.sin(i * 2 * math.pi / 5 - math.pi / 2), 4.2)]), flower, line: 1.1);
  final _face = Face(lid: BossColors.turtleSkin, rim: Shade.of(BossColors.turtleSkin).line, r: 6.4);

  static Path _plate(double cx, double cy, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + math.pi / 6;
      i == 0 ? p.moveTo(cx + r * math.cos(a), cy + r * math.sin(a)) : p.lineTo(cx + r * math.cos(a), cy + r * math.sin(a));
    }
    return p..close();
  }

  @override
  Offset get zzzAt => const Offset(106, 26);

  @override
  void body(Canvas c, BossPose p, double t) {
    for (final (i, l) in _legs.indexed) {
      rotateAt(c, Offset(i == 0 ? 28 : 78, 80), (i == 0 ? 1 : -1) * .25 * p.swing, () => l.paint(c));
    }
    _tail.paint(c);
    _rim.paint(c);
    _domeCel.paint(c);
    c.save();
    c.clipPath(_dome);
    for (final (x, y, r) in [(50.0, 57.0, 10.5), (29.0, 69.0, 9.0), (71.0, 69.0, 9.0), (35.0, 41.0, 8.0), (65.0, 41.0, 8.0), (50.0, 82.0, 7.0)]) {
      final pl = _plate(x, y, r);
      fillPath(c, pl, plate.base);
      strokePath(c, pl, plate.line, 1.3);
    }
    c.restore();
    shine(c, 30, 40, 12, 6);
    rotateAt(c, const Offset(84, 78), p.head * 1.6 - .08 * p.raise, () {
      _neck.paint(c);
      _head.paint(c);
      rotateAt(c, const Offset(104, 31), .3 * math.sin(t * .8), () {
        _petals.paint(c);
        fillPath(c, circle(104, 31, 2.6), BossColors.hibiscusCentre);
      });
      _face.cheeks(c, const Offset(85.6, 55), const Offset(106.4, 55));
      _face.pair(c, p, const Offset(96, 47), 14);
      _face.mouth(c, p, const Offset(96, 57));
      snoreBubble(c, const Offset(99, 57), p.breath, p.zzz);
    });
  }
}

// ===================================================================== frog

class _Frog extends BossDesign {
  static final skin = Shade.of(BossColors.frogSkin);
  static final belly = Shade.of(BossColors.frogBelly, lineColor: Shade.of(BossColors.frogSkin).line);
  static final pad = Shade.of(BossColors.lilyPad);
  static final gold = Shade.of(BossColors.crown);
  late final _pad = Cel(
      Path.combine(PathOperation.difference, oval(60, 94, 106, 14), Path()..moveTo(60, 94)..lineTo(53, 102)..lineTo(65, 102)..close()), pad,
      line: 1.2, light: const Offset(1.6, 1.2), dark: const Offset(1.6, 1.2));
  late final _legs = [Cel(oval(19, 83, 28, 17), skin), Cel(oval(101, 83, 28, 17), skin)];
  late final _body = Cel(union([oval(60, 66, 90, 52), circle(39, 37, 15), circle(81, 37, 15)]), skin, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _belly = Cel(oval(60, 80, 52, 22), belly, outline: false);
  late final _arms = [Cel(oval(39, 85, 10, 14), skin, line: 1.3), Cel(oval(81, 85, 10, 14), skin, line: 1.3)];
  late final _crown = Cel(Path()..moveTo(52, 42)..lineTo(52, 31)..lineTo(56.5, 36)..lineTo(60, 28)..lineTo(63.5, 36)..lineTo(68, 31)..lineTo(68, 42)..close(), gold, line: 1.1);
  final _face = Face(lid: BossColors.frogSkin, rim: Shade.of(BossColors.frogSkin).line, r: 8.4, brows: false, mouthWidth: 1.7);

  @override
  Offset get zzzAt => const Offset(100, 30);

  @override
  void ground(Canvas c, BossPose p, double t) {
    _pad.paint(c);
    for (final a in [-2.6, -2.0, -1.2, -.6]) {
      strokePath(c, Path()..moveTo(60, 94)..lineTo(60 + 46 * math.cos(a), 94 + 6 * math.sin(a)), pad.dark, 1);
    }
  }

  @override
  void body(Canvas c, BossPose p, double t) {
    for (final (i, l) in _legs.indexed) {
      rotateAt(c, Offset(i == 0 ? 28 : 92, 80), (i == 0 ? -1 : 1) * .12 * p.raise, () => l.paint(c));
    }
    _body.paint(c);
    _belly.paint(c);
    rotateAt(c, const Offset(60, 42), .1 * p.swing, () {
      _crown.paint(c);
      fillPath(c, circle(60, 38, 2.1), BossColors.gem);
    });
    shine(c, 33, 28, 9, 4.4, alpha: .7);
    final pouch = p.zzz * p.breath;
    if (pouch > .02) {
      final o = oval(60, 71, 12 + 16 * pouch, 7 + 10 * pouch);
      fillPath(c, o, BossColors.frogBelly.withValues(alpha: .95));
      strokePath(c, o, skin.line.withValues(alpha: .6), 1.1);
    }
    rotateAt(c, const Offset(40, 76), BossDesign.armLeft(p) - .3, () => _arms[0].paint(c));
    rotateAt(c, const Offset(80, 76), BossDesign.armRight(p) + .3, () => _arms[1].paint(c));
    _face.cheeks(c, const Offset(34, 57), const Offset(86, 57));
    _face.eyes(c, p, const Offset(39, 36), const Offset(81, 36));
    _face.mouth(c, p, const Offset(60, 59));
  }
}

// ===================================================================== dragon

class _Dragon extends BossDesign {
  static final skin = Shade.of(BossColors.dragonBody);
  static final belly = Shade.of(BossColors.dragonBelly, lineColor: Shade.of(BossColors.dragonBody).line);
  static final wing = Shade.of(BossColors.dragonWing);
  static final horn = Shade.of(BossColors.dragonHorn);
  late final Path _wingL = Path()
    ..moveTo(41, 47)
    ..quadraticBezierTo(27, 17, 11, 23)
    ..quadraticBezierTo(17, 31, 11, 38)
    ..quadraticBezierTo(20, 39, 17, 47)
    ..quadraticBezierTo(27, 45, 29, 54)
    ..quadraticBezierTo(35, 50, 41, 55)
    ..close();
  late final _wings = [Cel(_wingL, wing), Cel(mirror(_wingL), wing)];
  late final Path _hornL = Path()..moveTo(45, 33)..quadraticBezierTo(39, 23, 41, 14)..quadraticBezierTo(48, 21, 53, 29)..close();
  late final _horns = [Cel(_hornL, horn, line: 1.2), Cel(mirror(_hornL), horn, line: 1.2)];
  late final _crest = Cel(union([Path()..moveTo(55, 29)..lineTo(60, 19)..lineTo(65, 29)..close(), Path()..moveTo(64, 30)..lineTo(70, 24)..lineTo(70, 32)..close()]), wing, line: 1.1);
  late final _body = Cel(union([circle(60, 55, 29), oval(60, 74, 52, 38)]), skin, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _belly = Cel(oval(60, 76, 32, 26), belly, line: 1.1);
  late final _feet = [Cel(oval(45, 91, 19, 10), skin), Cel(oval(75, 91, 19, 10), skin)];
  late final _arms = [Cel(oval(37, 72, 10, 17), skin, line: 1.3), Cel(oval(83, 72, 10, 17), skin, line: 1.3)];
  late final _spade = Cel(Path()..moveTo(109, 50)..quadraticBezierTo(119, 58, 113, 65)..lineTo(109, 62)..lineTo(105, 65)..quadraticBezierTo(99, 58, 109, 50)..close(), wing, line: 1.2);
  final _face = Face(lid: BossColors.dragonBody, rim: Shade.of(BossColors.dragonBody).line, r: 7.4);

  @override
  Offset get zzzAt => const Offset(94, 28);

  @override
  void body(Canvas c, BossPose p, double t) {
    rotateAt(c, const Offset(80, 84), .18 * p.swing, () {
      tube(c, Path()..moveTo(78, 84)..cubicTo(96, 93, 109, 82, 109, 63), skin, 6.4);
      _spade.paint(c);
    });
    final w = (p.flap - .3) * .55 + .25 * p.raise;
    rotateAt(c, const Offset(41, 51), -w, () => _wings[0].paint(c));
    rotateAt(c, const Offset(79, 51), w, () => _wings[1].paint(c));
    for (final h in _horns) {
      h.paint(c);
    }
    _crest.paint(c);
    for (final f in _feet) {
      f.paint(c);
    }
    _body.paint(c);
    _belly.paint(c);
    for (final y in [70.0, 77.0, 84.0]) {
      strokePath(c, Path()..moveTo(51, y)..quadraticBezierTo(60, y + 2.6, 69, y), belly.dark, 1.2);
    }
    rotateAt(c, const Offset(37, 64), BossDesign.armLeft(p), () => _arms[0].paint(c));
    rotateAt(c, const Offset(83, 64), BossDesign.armRight(p), () => _arms[1].paint(c));
    _face.paint(c, p, centre: const Offset(60, 50), gap: 16, mouthY: 11.6, cheekX: 18.5, cheekY: 8);
    snoreBubble(c, const Offset(64, 59), p.breath, p.zzz);
  }
}

// ===================================================================== penguin

class _Penguin extends BossDesign {
  static final feathers = Shade.of(BossColors.penguinBody);
  static final white = Shade(BossColors.penguinWhite, BossColors.penguinWhite, BossColors.penguinWhiteShade, Shade.of(BossColors.penguinBody).line);
  static final beak = Shade.of(BossColors.penguinBeak);
  static final scarf = Shade.of(BossColors.penguinScarf);
  late final _feet = [Cel(oval(48, 92.5, 18, 8), beak, line: 1.2), Cel(oval(72, 92.5, 18, 8), beak, line: 1.2)];
  late final Path _flipL = Path()..moveTo(36, 46)..quadraticBezierTo(22, 56, 19, 76)..quadraticBezierTo(25, 80, 30, 74)..quadraticBezierTo(36, 62, 38, 56)..close();
  late final _flippers = [Cel(_flipL, feathers), Cel(mirror(_flipL), feathers)];
  late final _body = Cel(union([oval(60, 56, 62, 70), oval(60, 74, 66, 40)]), feathers, light: const Offset(3, 2.6), dark: const Offset(3.4, 3));
  late final _belly = Cel(oval(60, 73, 44, 40), white, outline: false);
  late final _mask = Cel(union([circle(50.5, 45, 12.5), circle(69.5, 45, 12.5), oval(60, 52, 28, 18)]), white, line: 1.1);
  late final _tuft = Cel(Path()..moveTo(55, 23)..quadraticBezierTo(57, 13, 65, 15)..quadraticBezierTo(60, 17, 62, 23)..close(), feathers, line: 1.1);
  late final Path _band = Path()..moveTo(31, 62)..quadraticBezierTo(60, 70, 89, 62)..lineTo(88.5, 69)..quadraticBezierTo(60, 77, 31.5, 69)..close();
  late final _scarf = Cel(_band, scarf, line: 1.1);
  late final _scarfEnd = Cel(rrect(70, 67, 79, 86, 3), scarf, line: 1.1);
  late final _upperBeak = Cel(Path()..moveTo(53.5, 50.5)..quadraticBezierTo(60, 47, 66.5, 50.5)..quadraticBezierTo(63.5, 55, 60, 55.6)..quadraticBezierTo(56.5, 55, 53.5, 50.5)..close(), beak, line: 1.1);
  final _face = Face(lid: BossColors.penguinWhite, rim: Shade.of(BossColors.penguinBody).line, r: 6.8);

  @override
  bool get night => true;

  @override
  Offset get zzzAt => const Offset(92, 30);

  void _beak(Canvas c, BossPose p) {
    final o = switch (p.mouth) {
      BossMouth.snore => .1 + .15 * p.open,
      BossMouth.smile => 0.0,
      BossMouth.grin => .45 + .3 * p.open,
      BossMouth.laugh => .6 + .4 * p.open,
      BossMouth.wow => .7,
      BossMouth.yawn => p.open,
    };
    final drop = 5 * o;
    if (o > .05) {
      fillPath(c, oval(60, 54 + drop * .5, 8, 2 + drop), BossColors.mouth);
      fillPath(c, oval(60, 55 + drop * .8, 5, 1 + drop * .5), BossColors.tongue);
    }
    final lower = Path()
      ..moveTo(55, 53)
      ..quadraticBezierTo(60, 52.6, 65, 53)
      ..quadraticBezierTo(62.5, 57 + drop, 60, 57.6 + drop)
      ..quadraticBezierTo(57.5, 57 + drop, 55, 53)
      ..close();
    strokePath(c, lower, beak.line, 2.2);
    fillPath(c, lower, beak.dark);
    _upperBeak.paint(c);
    if (o < .3 && p.mouth != BossMouth.snore) {
      strokePath(c, Path()..moveTo(53.6, 51)..quadraticBezierTo(52.4, 50.6, 52, 49.2), beak.line, 1);
      strokePath(c, Path()..moveTo(66.4, 51)..quadraticBezierTo(67.6, 50.6, 68, 49.2), beak.line, 1);
    }
  }

  @override
  void body(Canvas c, BossPose p, double t) {
    for (final f in _feet) {
      f.paint(c);
    }
    final flap = .08 + p.raise * 1.3 + (p.flap - .5) * .3 * p.raise;
    rotateAt(c, const Offset(35, 50), flap + p.swing * .2, () => _flippers[0].paint(c));
    rotateAt(c, const Offset(85, 50), -flap + p.swing * .2, () => _flippers[1].paint(c));
    _tuft.paint(c);
    _body.paint(c);
    _belly.paint(c);
    _mask.paint(c);
    _scarf.paint(c);
    c.save();
    c.clipPath(_band);
    for (final x in [40.0, 52.0, 64.0, 76.0]) {
      fillPath(c, rrect(x, 58, x + 3.4, 80, 0), BossColors.penguinWhite);
    }
    c.restore();
    rotateAt(c, const Offset(74.5, 68), .15 + .25 * p.swing, () {
      _scarfEnd.paint(c);
      fillPath(c, rrect(70.5, 74, 78.5, 77, 0), BossColors.penguinWhite);
      fillPath(c, rrect(70.5, 80, 78.5, 83, 0), BossColors.penguinWhite);
    });
    _face.cheeks(c, const Offset(45, 51), const Offset(75, 51));
    _face.pair(c, p, const Offset(60, 43.5), 16);
    _beak(c, p);
    snoreBubble(c, const Offset(63, 53), p.breath, p.zzz);
  }
}
