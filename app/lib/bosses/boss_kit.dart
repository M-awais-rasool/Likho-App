import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import '../design/tokens.dart';
import 'boss_pose.dart';

/// Drawing kit for the world bosses, in Pencil's style: flat colour with a
/// light band on the top-left, a darker band on the bottom-right and a
/// darker outline of the same hue; big eyes with a rim, a navy pupil and two
/// highlights; soft cheeks; a red-brown mouth with a tongue.

/// A colour and the shades the art needs.
class Shade {
  const Shade(this.base, this.light, this.dark, this.line);

  factory Shade.of(Color c, {double light = .07, double dark = .08, double line = .3, Color? lineColor}) {
    final h = HSLColor.fromColor(c);
    Color shift(double dl, double ds) =>
        h.withLightness((h.lightness + dl).clamp(0.0, 1.0)).withSaturation((h.saturation + ds).clamp(0.0, 1.0)).toColor();
    return Shade(c, shift(light, 0), shift(-dark, -.04), lineColor ?? shift(-line, -.12));
  }

  final Color base, light, dark, line;
}

/// One cel-shaded shape. The bands are cut once (shapes never change; the
/// rig moves them with canvas transforms).
class Cel {
  Cel(this.path, this.shade, {Offset light = const Offset(2.4, 2.0), Offset dark = const Offset(2.8, 2.4), this.line = 1.6, this.outline = true})
      : _light = Path.combine(PathOperation.difference, path, path.shift(light)),
        _dark = Path.combine(PathOperation.difference, path, path.shift(-dark));

  final Path path;
  final Shade shade;
  final double line;
  final bool outline;
  final Path _light, _dark;

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;

  void paint(Canvas c, {double opacity = 1}) {
    Color a(Color x) => opacity >= 1 ? x : x.withValues(alpha: x.a * opacity);
    if (outline) {
      _stroke
        ..color = a(shade.line)
        ..strokeWidth = line * 2;
      c.drawPath(path, _stroke);
    }
    _fill.color = a(shade.base);
    c.drawPath(path, _fill);
    _fill.color = a(shade.light);
    c.drawPath(_light, _fill);
    _fill.color = a(shade.dark);
    c.drawPath(_dark, _fill);
  }
}

// ------------------------------------------------------------------ shapes

Path oval(double cx, double cy, double w, double h) => Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h));

Path circle(double cx, double cy, double r) => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

Path rrect(double l, double t, double r, double b, double rad) => Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

Path union(List<Path> ps) => ps.skip(1).fold(ps.first, (a, b) => Path.combine(PathOperation.union, a, b));

Path intersect(Path a, Path b) => Path.combine(PathOperation.intersect, a, b);

/// [p] mirrored around x = 60 (the art's centre line).
Path mirror(Path p) => p.transform(Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 120, 0, 0, 1]));

/// [p] rotated by [a] radians around [o] (for shapes cut once at an angle).
Path turned(Path p, Offset o, double a) {
  final c = math.cos(a), s = math.sin(a);
  return p.transform(Float64List.fromList([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, o.dx - c * o.dx + s * o.dy, o.dy - s * o.dx - c * o.dy, 0, 1]));
}

/// Runs [draw] rotated by [a] around [pivot].
void rotateAt(Canvas c, Offset pivot, double a, void Function() draw) {
  if (a == 0) return draw();
  c.save();
  c.translate(pivot.dx, pivot.dy);
  c.rotate(a);
  c.translate(-pivot.dx, -pivot.dy);
  draw();
  c.restore();
}

final Paint _p = Paint()..isAntiAlias = true;
final Paint _s = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void fillPath(Canvas c, Path path, Color color) => c.drawPath(path, _p..color = color);

void strokePath(Canvas c, Path path, Color color, double width) => c.drawPath(
    path,
    _s
      ..color = color
      ..strokeWidth = width);

/// A limb or tail drawn as a thick outlined line (Pencil's arms are drawn the
/// same way: outline, then the colour on top).
void tube(Canvas c, Path path, Shade s, double width) {
  strokePath(c, path, s.line, width + 2.6);
  strokePath(c, path, s.base, width);
}

/// White shine spot (top-left of round things).
void shine(Canvas c, double cx, double cy, double w, double h, {double alpha = .55}) =>
    c.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h), _p..color = BossColors.shine.withValues(alpha: alpha));

// ------------------------------------------------------------------ face

/// Eyes, brows, cheeks and mouth of a boss. [r] is the eye radius; every
/// other size scales with it (Pencil's eye is 32 of a 500-wide artboard).
class Face {
  const Face({
    required this.lid,
    required this.rim,
    this.r = 5.8,
    this.light = false,
    this.brows = true,
    this.mouthWidth = 1,
  });

  /// Eyelid colour (the skin around the eyes).
  final Color lid;

  /// Eye rim, lash line and brows.
  final Color rim;
  final double r;

  /// A dark face (the ladybug's head): light strokes for closed eyes and
  /// the smile.
  final bool light;
  final bool brows;

  /// Wider mouth (the frog).
  final double mouthWidth;

  double get _k => r / 5.8;

  /// Eyes at [a] and [b] (left and right).
  void eyes(Canvas c, BossPose p, Offset a, Offset b) {
    _eye(c, p, a, -1);
    _eye(c, p, b, 1);
    if (brows && !light) {
      _brow(c, p, a, -1);
      _brow(c, p, b, 1);
    }
  }

  /// Both eyes [gap] apart around [centre].
  void pair(Canvas c, BossPose p, Offset centre, double gap) => eyes(c, p, centre - Offset(gap / 2, 0), centre + Offset(gap / 2, 0));

  void cheeks(Canvas c, Offset a, Offset b) {
    final paint = Paint()
      ..color = BossColors.cheek
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.1 * _k);
    for (final o in [a, b]) {
      c.drawOval(Rect.fromCenter(center: o, width: 8.6 * _k, height: 5.4 * _k), paint);
    }
  }

  void _eye(Canvas c, BossPose p, Offset e, int side) {
    final r = this.r;
    final k = _k;
    final closedStroke = light ? BossColors.faceLight : BossColors.happyEye;
    switch (p.eyes) {
      case BossEyes.happy:
        // ^ ^
        strokePath(c, Path()..moveTo(e.dx - .9 * r, e.dy + .35 * r)..quadraticBezierTo(e.dx, e.dy - .85 * r, e.dx + .9 * r, e.dy + .35 * r), closedStroke, 1.9 * k);
        return;
      case BossEyes.closed:
        // shut: a lash curve smiling downwards
        strokePath(c, Path()..moveTo(e.dx - .85 * r, e.dy)..quadraticBezierTo(e.dx, e.dy + .7 * r, e.dx + .85 * r, e.dy), closedStroke, 1.7 * k);
        strokePath(c, Path()..moveTo(e.dx + side * .78 * r, e.dy + .12 * r)..lineTo(e.dx + side * 1.1 * r, e.dy + .32 * r), closedStroke, 1.2 * k);
        return;
      case BossEyes.open:
      case BossEyes.wow:
        break;
    }
    final wow = p.eyes == BossEyes.wow;
    final wr = r * (wow ? 1.12 : 1);
    c.drawCircle(e, wr + 1.1 * k, _p..color = rim);
    c.drawCircle(e, wr, _p..color = BossColors.eyeWhite);
    final pr = r * (wow ? .5 : .66);
    final travel = wr - pr - .7 * k;
    final pc = e + Offset(-side * .1 * r, .06 * r) + p.look * travel;
    c.drawCircle(pc, pr, _p..color = BossColors.pupil);
    c.drawCircle(pc + Offset(-.3 * pr, -.36 * pr), pr * (wow ? .5 : .42), _p..color = BossColors.eyeWhite);
    c.drawCircle(pc + Offset(.36 * pr, .34 * pr), pr * .17, _p..color = BossColors.eyeWhite);
    final lid = p.eyes == BossEyes.wow ? 0.0 : p.lid.clamp(0.0, 1.0);
    if (lid > .01) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: e, radius: wr + .3 * k)));
      final edge = e.dy - wr - .3 * k + lid * (2 * wr + .6 * k);
      c.drawRect(Rect.fromLTRB(e.dx - wr - k, e.dy - wr - k, e.dx + wr + k, edge), _p..color = this.lid);
      c.restore();
      if (lid < .97) {
        strokePath(c, Path()..moveTo(e.dx - wr, edge)..quadraticBezierTo(e.dx, edge + .25 * r, e.dx + wr, edge), rim, 1.3 * k);
      } else {
        strokePath(c, Path()..moveTo(e.dx - .85 * r, e.dy)..quadraticBezierTo(e.dx, e.dy + .7 * r, e.dx + .85 * r, e.dy), rim, 1.5 * k);
      }
    }
  }

  void _brow(Canvas c, BossPose p, Offset e, int side) {
    final r = this.r, k = _k;
    final y = e.dy - 1.75 * r - p.brow * 1.1 * k;
    final droop = p.brow < 0 ? -p.brow * .9 * k : 0.0; // sleepy: the outer end drops
    strokePath(
      c,
      Path()
        ..moveTo(e.dx - side * .55 * r, y + .15 * r)
        ..quadraticBezierTo(e.dx, y - .3 * r, e.dx + side * .6 * r, y + .1 * r + droop),
      rim,
      1.4 * k,
    );
  }

  /// The mouth, centred at [m].
  void mouth(Canvas c, BossPose p, Offset m) {
    final k = math.min(_k, 1.1) * .95;
    final w = mouthWidth;
    final open = p.open.clamp(0.0, 1.0);
    final ink = light ? BossColors.faceLight : BossColors.mouth;
    switch (p.mouth) {
      case BossMouth.smile:
        strokePath(c, Path()..moveTo(m.dx - 4 * k * w, m.dy - .6 * k)..quadraticBezierTo(m.dx, m.dy + 3.6 * k, m.dx + 4 * k * w, m.dy - .6 * k), ink, 1.6 * k);
      case BossMouth.snore:
        final s = .55 + .45 * open;
        _filled(c, Path()..addOval(Rect.fromCenter(center: m, width: 3.2 * k * s, height: 3.8 * k * s)), tongue: false);
      case BossMouth.wow:
        _filled(c, Path()..addOval(Rect.fromCenter(center: m + Offset(0, k), width: 3.8 * k, height: (4 + 2.4 * open) * k)));
      case BossMouth.yawn:
        _filled(c, Path()..addOval(Rect.fromCenter(center: m + Offset(0, (1 + 2 * open) * k), width: (4 + 1.8 * open) * k * w, height: (3 + 6 * open) * k)));
      case BossMouth.grin:
      case BossMouth.laugh:
        final laugh = p.mouth == BossMouth.laugh;
        final hw = (laugh ? 5.2 : 4.4) * k * w;
        final h = (laugh ? 4 + 3.6 * open : 3.4 + 1.6 * open) * k;
        final path = Path()
          ..moveTo(m.dx - hw, m.dy - .8 * k)
          ..quadraticBezierTo(m.dx, m.dy + .4 * k, m.dx + hw, m.dy - .8 * k)
          ..cubicTo(m.dx + hw * .9, m.dy + h * .9, m.dx - hw * .9, m.dy + h * .9, m.dx - hw, m.dy - .8 * k)
          ..close();
        _filled(c, path, teeth: laugh);
    }
  }

  void _filled(Canvas c, Path path, {bool tongue = true, bool teeth = false}) {
    final k = math.min(_k, 1.1) * .95;
    final b = path.getBounds();
    if (light) c.drawPath(path, _s..color = BossColors.faceLight..strokeWidth = 1.4 * k);
    c.drawPath(path, _p..color = BossColors.mouth);
    c.save();
    c.clipPath(path);
    if (teeth) c.drawRect(Rect.fromLTRB(b.left, b.top - k, b.right, b.top + 1.3 * k), _p..color = BossColors.eyeWhite);
    if (tongue && b.height > 2.6 * k) {
      c.drawOval(Rect.fromCenter(center: Offset(b.center.dx, b.bottom), width: b.width * .9, height: b.height * .9), _p..color = BossColors.tongue);
    }
    c.restore();
  }

  void paint(Canvas c, BossPose p, {required Offset centre, required double gap, required double mouthY, double cheekX = 15, double cheekY = 6}) {
    cheeks(c, centre + Offset(-cheekX, cheekY), centre + Offset(cheekX, cheekY));
    pair(c, p, centre, gap);
    mouth(c, p, centre + Offset(0, mouthY));
  }
}

// ------------------------------------------------------------------ sleep effects

/// Three "z" drifting up and fading (Pencil's zzz effect), drawn as strokes.
void zzzEffect(Canvas c, Offset at, double t, Color color, double amount) {
  if (amount <= 0) return;
  for (var i = 0; i < 3; i++) {
    final p = ((t - i * .9) / 2.7) % 1.0;
    final e = 1 - math.pow(1 - p, 2).toDouble();
    final a = (p < .25 ? p / .25 : 1 - (p - .25) / .75) * amount;
    final s = 4.5 + 3.5 * e;
    final o = at + Offset(10 * e, -20 * e);
    final z = Path()
      ..moveTo(o.dx - s / 2, o.dy - s / 2)
      ..lineTo(o.dx + s / 2, o.dy - s / 2)
      ..lineTo(o.dx - s / 2, o.dy + s / 2)
      ..lineTo(o.dx + s / 2, o.dy + s / 2);
    strokePath(c, z, color.withValues(alpha: a.clamp(0.0, 1.0)), 1.5 + .5 * e);
  }
}

/// A snore bubble that swells with each breath.
void snoreBubble(Canvas c, Offset at, double breath, double amount) {
  if (amount <= 0) return;
  final r = 1.2 + 4.4 * breath;
  final o = at + Offset(r * .8, -r * .4);
  c.drawCircle(o, r, _p..color = BossColors.bubble.withValues(alpha: .45 * amount));
  c.drawCircle(o, r, _s..color = BossColors.bubbleRim.withValues(alpha: .9 * amount)..strokeWidth = .8);
  c.drawCircle(o + Offset(-r * .35, -r * .35), r * .22, _p..color = BossColors.eyeWhite.withValues(alpha: amount));
}

/// A four-point twinkle star.
void twinkle(Canvas c, Offset o, double r, Color color) {
  if (r <= .05) return;
  final path = Path()
    ..moveTo(o.dx, o.dy - r)
    ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
    ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
    ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
    ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
    ..close();
  fillPath(c, path, color);
}
