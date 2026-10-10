import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../design/tokens.dart';
import 'map_geometry.dart';

/// Section background: the world's [color] at the bottom fading to its
/// [sky] at the top. The cloud banks hide the edges between worlds, so a
/// world never blends into its neighbour's colour.
class SectionBackgroundPainter extends CustomPainter {
  const SectionBackgroundPainter({required this.color, Color? sky}) : sky = sky ?? color;
  final Color color, sky;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, sky],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(SectionBackgroundPainter old) => old.color != color || old.sky != sky;
}

/// The path through the levels: a wide soft band plus white dots
/// (stroke 26 at 55 % white, then stroke 8 dashed "1 20", round caps).
/// Painted per section, shifted by the section's top; dots are cached.
class MapPathPainter extends CustomPainter {
  MapPathPainter({required this.geometry, required this.sectionTop});
  final MapGeometry geometry;
  final double sectionTop;

  static final Map<double, (Path, List<(Offset, double)>)> _cache = {};

  (Path, List<(Offset, double)>) get _data => _cache.putIfAbsent(geometry.width, () {
        final path = geometry.path();
        final dots = <(Offset, double)>[];
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d <= m.length; d += 21) {
            final t = m.getTangentForOffset(d + .5);
            if (t != null) dots.add((t.position, t.angle));
          }
        }
        return (path, dots);
      });

  @override
  void paint(Canvas canvas, Size size) {
    final (path, dots) = _data;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -sectionTop);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..color = MapColors.pathBand,
    );
    // each dash is 1 px long with round caps: a 9 x 8 capsule along the path
    final dot = Paint()..color = MapColors.pathDots;
    final top = sectionTop - 10, bottom = sectionTop + size.height + 10;
    for (final (p, a) in dots) {
      if (p.dy < top || p.dy > bottom) continue;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(-a);
      canvas.drawRRect(RRect.fromLTRBR(-4.5, -4, 4.5, 4, const Radius.circular(4)), dot);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MapPathPainter old) => old.geometry.width != geometry.width || old.sectionTop != sectionTop;
}

/// The cloud bank between two worlds. Every world sits on one and the path
/// climbs through it into the next world, so each new world arrives the same
/// way. A section paints the banks on its own edges ([seams]: y in the
/// section and the bank's seed), clipped to itself, so the halves painted
/// by the two neighbouring sections meet exactly.
class CloudBankPainter extends CustomPainter {
  const CloudBankPainter({required this.seams});
  final List<(double, int)> seams;

  /// How far a bank reaches above and below its seam.
  static const double reach = 66;

  static final Paint _white = Paint()..color = MapColors.cloudWhite;
  static final Paint _shade = Paint()..color = MapColors.cloudShade;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final (y, seed) in seams) {
      _bank(canvas, size.width, y, seed);
    }
    canvas.restore();
  }

  static void _bank(Canvas c, double w, double y, int seed) {
    var s = seed * 4931 + 7;
    double rnd() {
      s = (s * 9301 + 49297) % 233280;
      return s / 233280;
    }

    // shaded puffs underneath give the bank its belly
    final under = Path();
    for (var x = -30.0; x < w + 40; x += 30 + rnd() * 16) {
      under.addOval(Rect.fromCircle(center: Offset(x, y + 30 + rnd() * 8), radius: 20 + rnd() * 8));
    }
    final top = Path()..addRect(Rect.fromLTRB(-10, y - 16, w + 10, y + 14));
    for (var x = -24.0; x < w + 40; x += 38 + rnd() * 22) {
      top.addOval(Rect.fromCircle(center: Offset(x, y - 12 + rnd() * 10), radius: 28 + rnd() * 22));
    }
    // a scalloped underside
    for (var x = -10.0; x < w + 30; x += 26 + rnd() * 12) {
      top.addOval(Rect.fromCircle(center: Offset(x, y + 16 + rnd() * 6), radius: 16 + rnd() * 6));
    }
    c.drawPath(under, _shade);
    c.drawPath(top.shift(const Offset(0, 7)), _shade);
    c.drawPath(top, _white);
  }

  @override
  bool shouldRepaint(CloudBankPainter old) => !listEquals(old.seams, seams);
}

/// Decorations of one world, animated from one shared clock (seconds).
class DecorationPainter extends CustomPainter {
  DecorationPainter({required this.decos, required this.sectionTop, required this.time}) : super(repaint: time);
  final List<MapDeco> decos;
  final double sectionTop;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (final d in decos) {
      final k = d.kind;
      final r = d.rect.shift(Offset(0, -sectionTop));
      // keyframes 0%,100% -> a; 50% -> b; ease-in-out per half (CSS)
      final p = k.seconds == 0 ? 0.0 : ((t + d.phase) / k.seconds) % 1.0;
      final half = Curves.easeInOut.transform(p < .5 ? p * 2 : 2 - p * 2);
      var opacity = .95;
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      switch (k.anim) {
        case DecoAnim.sway:
          canvas.rotate((-4 + 8 * half) * math.pi / 180);
        case DecoAnim.drift:
          canvas.translate(16 * half, 0);
        case DecoAnim.waveBob:
          canvas.translate(0, 6 * half);
        case DecoAnim.twinkle:
          opacity *= .25 + .75 * half;
          canvas.scale(.8 + .35 * half);
        case DecoAnim.fall:
          // drifts down and sways, fading in and out
          canvas.translate(10 * math.sin(p * 2 * math.pi), 34 * p - 17);
          canvas.rotate(math.sin(p * 2 * math.pi) * .5);
          opacity *= math.sin(p * math.pi);
        case DecoAnim.flap:
          canvas.translate(8 * math.sin(p * 2 * math.pi * .5), 4 * math.sin(p * 2 * math.pi));
        case DecoAnim.none:
          break;
      }
      paintMotif(canvas, k, Size(r.width, r.height), opacity, k.anim == DecoAnim.flap ? p : 0);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DecorationPainter old) => old.decos != decos || old.sectionTop != sectionTop;
}

final Paint _f = Paint()..isAntiAlias = true;
final Paint _l = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Color _a(Color c, double o) => c.withValues(alpha: c.a * o);

void _dot(Canvas c, double x, double y, double r, Color col) => c.drawCircle(Offset(x, y), r, _f..color = col);

void _line(Canvas c, Path p, Color col, double w) => c.drawPath(
    p,
    _l
      ..color = col
      ..strokeWidth = w);

Color _darker(Color c, [double by = .12]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - by).clamp(0.0, 1.0)).toColor();
}

/// One decoration, centred on the origin, [s] big. [beat] drives wings.
void paintMotif(Canvas c, DecoKind k, Size s, double o, double beat) {
  final w = s.width, h = s.height;
  final col = _a(k.color, o), col2 = _a(k.color2, o);
  switch (k.motif) {
    case DecoMotif.bush:
      final dark = _a(_darker(k.color, .06), o);
      _dot(c, -w * .26, h * .12, h * .36, dark);
      _dot(c, w * .26, h * .14, h * .34, dark);
      _dot(c, 0, -h * .02, h * .48, col);
      _dot(c, -w * .24, h * .08, h * .32, col);
      _dot(c, w * .25, h * .1, h * .3, col);
      for (final (x, y) in [(-.2, -.1), (.12, -.22), (.3, .02)]) {
        _dot(c, w * x, h * y, h * .06, col2.withValues(alpha: .55 * o));
      }
    case DecoMotif.flower:
      final r = w * .24;
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5 - math.pi / 2;
        _dot(c, r * math.cos(a), r * math.sin(a), w * .2, col);
      }
      _dot(c, 0, 0, w * .17, col2);
    case DecoMotif.cloud:
      final body = Path()
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-w / 2, -h * .05, w / 2, h / 2), Radius.circular(h * .27)))
        ..addOval(Rect.fromCircle(center: Offset(-w * .14, -h * .02), radius: h * .38))
        ..addOval(Rect.fromCircle(center: Offset(w * .16, h * .04), radius: h * .3));
      c.drawPath(body, _f..color = _a(k.color, .85 * o));
    case DecoMotif.pennant:
      _line(c, Path()..moveTo(-w * .3, h / 2)..lineTo(-w * .3, -h / 2), _a(const Color(0xFF8A6A50), o), 2.4);
      final flag = Path()
        ..moveTo(-w * .3, -h / 2)
        ..lineTo(w / 2, -h * .3)
        ..lineTo(-w * .3, -h * .08)
        ..close();
      c.drawPath(flag, _f..color = col);
      _dot(c, -w * .3, -h / 2, 2.6, col2);
    case DecoMotif.sparkle:
      final r = w / 2;
      final star = Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..quadraticBezierTo(0, 0, 0, r)
        ..quadraticBezierTo(0, 0, -r, 0)
        ..quadraticBezierTo(0, 0, 0, -r)
        ..close();
      c.drawPath(star, _f..color = col);
    case DecoMotif.bubble:
      c.drawCircle(Offset.zero, w / 2, _f..color = _a(k.color, .25 * o));
      c.drawCircle(Offset.zero, w / 2, _l..color = _a(k.color, .8 * o)..strokeWidth = 1.6);
      _dot(c, -w * .17, -w * .17, w * .1, col);
    case DecoMotif.shell:
      final fan = Path()
        ..moveTo(0, h / 2)
        ..lineTo(-w / 2, -h * .05)
        ..arcToPoint(Offset(w / 2, -h * .05), radius: Radius.circular(w / 2))
        ..close();
      c.drawPath(fan, _f..color = col);
      for (final x in [-.25, 0.0, .25]) {
        _line(c, Path()..moveTo(0, h / 2)..lineTo(w * x, -h * .4), _a(_darker(k.color, .1), o), 1.4);
      }
    case DecoMotif.wave:
      final p = Path()..moveTo(-w / 2, 0);
      for (var i = 0; i < 4; i++) {
        final x0 = -w / 2 + i * w / 4;
        p.quadraticBezierTo(x0 + w / 8, i.isEven ? -h / 2 : h / 2, x0 + w / 4, 0);
      }
      _line(c, p, _a(k.color, .75 * o), 3);
    case DecoMotif.snowflake:
      for (var i = 0; i < 3; i++) {
        c.save();
        c.rotate(i * math.pi / 3);
        _line(c, Path()..moveTo(0, -w / 2)..lineTo(0, w / 2), col, 1.8);
        for (final y in [-w * .3, w * .3]) {
          final sy = y.sign;
          _line(c, Path()..moveTo(-w * .12, y + sy * w * .1)..lineTo(0, y)..lineTo(w * .12, y + sy * w * .1), col, 1.4);
        }
        c.restore();
      }
    case DecoMotif.pine:
      _dot(c, 0, 0, 0, col); // keeps the paint colour in sync
      c.drawRect(Rect.fromLTRB(-w * .08, h * .32, w * .08, h / 2), _f..color = _a(const Color(0xFF7A5238), o));
      for (var i = 0; i < 3; i++) {
        final top = -h / 2 + i * h * .22, bot = top + h * .42, half = w * (.28 + i * .11);
        final tri = Path()
          ..moveTo(0, top)
          ..lineTo(half, bot)
          ..lineTo(-half, bot)
          ..close();
        c.drawPath(tri, _f..color = col);
        final cap = Path()
          ..moveTo(0, top)
          ..lineTo(half * .45, top + (bot - top) * .45)
          ..quadraticBezierTo(0, top + (bot - top) * .32, -half * .45, top + (bot - top) * .45)
          ..close();
        c.drawPath(cap, _f..color = _a(k.color2, .9 * o));
      }
    case DecoMotif.tree:
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-w * .07, h * .1, w * .07, h / 2), const Radius.circular(3)), _f..color = col2);
      final dark = _a(_darker(k.color, .08), o);
      _dot(c, -w * .2, -h * .02, w * .3, dark);
      _dot(c, w * .2, 0, w * .28, dark);
      _dot(c, 0, -h * .2, w * .36, col);
      _dot(c, -w * .18, -h * .06, w * .26, col);
      _dot(c, w * .18, -h * .04, w * .24, col);
      _dot(c, -w * .1, -h * .3, w * .1, _a(const Color(0xFFFFFFFF), .35 * o));
    case DecoMotif.mushroom:
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-w * .14, -h * .05, w * .14, h / 2), Radius.circular(w * .1)), _f..color = _a(const Color(0xFFFFF1DC), o));
      final cap = Path()
        ..moveTo(-w / 2, h * .05)
        ..quadraticBezierTo(-w / 2, -h / 2, 0, -h / 2)
        ..quadraticBezierTo(w / 2, -h / 2, w / 2, h * .05)
        ..close();
      c.drawPath(cap, _f..color = col);
      for (final (x, y, r) in [(-.22, -.18, .09), (.12, -.3, .08), (.26, -.06, .07), (-.02, -.05, .06)]) {
        _dot(c, w * x, h * y, w * r, col2);
      }
    case DecoMotif.leaf:
      final leaf = Path()
        ..moveTo(-w / 2, 0)
        ..quadraticBezierTo(0, -h * .9, w / 2, 0)
        ..quadraticBezierTo(0, h * .9, -w / 2, 0)
        ..close();
      c.drawPath(leaf, _f..color = col);
      _line(c, Path()..moveTo(-w / 2, 0)..lineTo(w * .4, 0), _a(k.color2, .7 * o), 1.2);
    case DecoMotif.house:
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-w * .4, -h * .1, w * .4, h / 2), const Radius.circular(3)), _f..color = _a(const Color(0xFFFFFFFF), .92 * o));
      final roof = Path()
        ..moveTo(-w / 2, -h * .06)
        ..lineTo(0, -h / 2)
        ..lineTo(w / 2, -h * .06)
        ..close();
      c.drawPath(roof, _f..color = col2);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-w * .1, h * .18, w * .1, h / 2), const Radius.circular(2)), _f..color = col);
      c.drawRect(Rect.fromLTRB(-w * .3, h * .02, -w * .16, h * .16), _f..color = _a(const Color(0xFFFFE07A), o));
      c.drawRect(Rect.fromLTRB(w * .16, h * .02, w * .3, h * .16), _f..color = _a(const Color(0xFFFFE07A), o));
    case DecoMotif.rock:
      final rock = Path()
        ..moveTo(-w / 2, h / 2)
        ..quadraticBezierTo(-w * .5, -h * .1, -w * .15, -h * .4)
        ..quadraticBezierTo(w * .2, -h * .55, w * .42, -h * .05)
        ..quadraticBezierTo(w * .55, h * .3, w / 2, h / 2)
        ..close();
      c.drawPath(rock, _f..color = col);
      _line(c, Path()..moveTo(-w * .1, -h * .2)..lineTo(w * .05, h * .1), _a(k.color2, .35 * o), 1.6);
    case DecoMotif.beachBall:
      final r = w / 2;
      c.drawCircle(Offset.zero, r, _f..color = _a(const Color(0xFFFFFFFF), o));
      for (final (i, cc) in [col, col2, _a(const Color(0xFFFFC93C), o)].indexed) {
        c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), -math.pi / 2 + i * 2 * math.pi / 3, math.pi / 3, true, _f..color = cc);
      }
      _dot(c, -r * .3, -r * .3, r * .18, _a(const Color(0xFFFFFFFF), .7 * o));
    case DecoMotif.starfish:
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5 - math.pi / 2;
        final r = i.isEven ? w / 2 : w * .22;
        i == 0 ? p.moveTo(r * math.cos(a), r * math.sin(a)) : p.lineTo(r * math.cos(a), r * math.sin(a));
      }
      p.close();
      c.drawPath(p, _f..color = col);
      c.drawPath(p, _l..color = col..strokeWidth = w * .12);
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5 - math.pi / 2;
        _dot(c, w * .22 * math.cos(a), w * .22 * math.sin(a), 1.3, _a(k.color2, .7 * o));
      }
    case DecoMotif.butterfly:
      final open = .35 + .65 * (.5 + .5 * math.cos(beat * 2 * math.pi * 4));
      c.save();
      c.scale(open, 1);
      for (final sx in [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(sx * w * .24, -h * .14), width: w * .46, height: h * .56), _f..color = col);
        c.drawOval(Rect.fromCenter(center: Offset(sx * w * .2, h * .22), width: w * .32, height: h * .4), _f..color = col2);
      }
      c.restore();
      _line(c, Path()..moveTo(0, -h * .3)..lineTo(0, h * .35), _a(const Color(0xFF3A3D5C), o), 2);
    case DecoMotif.kite:
      final kite = Path()
        ..moveTo(0, -h / 2)
        ..lineTo(w * .36, -h * .12)
        ..lineTo(0, h * .22)
        ..lineTo(-w * .36, -h * .12)
        ..close();
      c.drawPath(kite, _f..color = col);
      c.drawPath(Path()..moveTo(0, -h / 2)..lineTo(w * .36, -h * .12)..lineTo(0, -h * .12)..close(), _f..color = col2);
      _line(c, Path()..moveTo(0, h * .22)..quadraticBezierTo(w * .25, h * .34, 0, h / 2), _a(const Color(0xFF6B7AA6), o), 1.2);
    case DecoMotif.bird:
      _line(c, Path()..moveTo(-w / 2, 0)..quadraticBezierTo(-w / 4, -h / 2, 0, h * .1)..quadraticBezierTo(w / 4, -h / 2, w / 2, 0), col, 2.2);
    case DecoMotif.fern:
      final leaf = Path()
        ..moveTo(-w / 2, h / 2)
        ..quadraticBezierTo(-w * .4, -h * .4, w / 2, -h / 2)
        ..quadraticBezierTo(w * .1, h * .2, -w / 2, h / 2)
        ..close();
      c.drawPath(leaf, _f..color = col);
      final rib = Path()
        ..moveTo(-w / 2, h / 2)
        ..quadraticBezierTo(-w * .15, -h * .1, w / 2, -h / 2);
      _line(c, rib, _a(_darker(k.color, .12), o), 1.6);
      for (var i = 1; i < 5; i++) {
        final t = i / 5;
        final x = -w / 2 + t * w, y = h / 2 - t * h;
        _line(c, Path()..moveTo(x, y)..lineTo(x - w * .06, y - h * .16), _a(_darker(k.color, .12), o), 1.2);
      }
    case DecoMotif.palm:
      _line(c, Path()..moveTo(-w * .05, h / 2)..quadraticBezierTo(w * .08, 0, -w * .02, -h * .28), col2, w * .1);
      for (final a in [-2.6, -2.0, -1.2, -.6, -.1]) {
        final tip = Offset(-w * .02 + w * .5 * math.cos(a), -h * .28 + h * .3 * math.sin(a) + h * .12);
        final frond = Path()
          ..moveTo(-w * .02, -h * .28)
          ..quadraticBezierTo((tip.dx - w * .02) / 2, -h * .5, tip.dx, tip.dy)
          ..quadraticBezierTo((tip.dx - w * .02) / 2, -h * .32, -w * .02, -h * .28)
          ..close();
        c.drawPath(frond, _f..color = col);
      }
      _dot(c, w * .02, -h * .24, w * .06, _a(const Color(0xFF7A5238), o));
    case DecoMotif.lilyPad:
      final pad = Path.combine(PathOperation.difference, Path()..addOval(Rect.fromCenter(center: Offset.zero, width: w, height: h)),
          Path()..moveTo(0, 0)..lineTo(w * .1, h / 2)..lineTo(w * .4, h / 2)..close());
      c.drawPath(pad, _f..color = col);
      _dot(c, -w * .12, -h * .12, w * .12, col2);
      _dot(c, -w * .12, -h * .12, w * .05, _a(const Color(0xFFFFE07A), o));
    case DecoMotif.reed:
      for (final (x, top) in [(-w * .25, -h * .3), (0.0, -h / 2), (w * .25, -h * .2)]) {
        _line(c, Path()..moveTo(x, h / 2)..lineTo(x, top + h * .2), col, 2.2);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x - w * .09, top, x + w * .09, top + h * .24), Radius.circular(w * .09)), _f..color = col2);
      }
    case DecoMotif.planet:
      c.drawCircle(Offset.zero, w * .34, _f..color = col);
      c.drawCircle(Offset(w * .08, w * .08), w * .34, _f..color = _a(const Color(0x2E000000), o));
      c.drawCircle(Offset.zero, w * .3, _f..color = col);
      c.save();
      c.rotate(-.35);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h * .26), _l..color = col2..strokeWidth = 2.6);
      c.restore();
  }
}

/// The far scenery of a world, behind the path: a landscape along the
/// section's bottom (hills, towers, a tree line, a skyline, peaks, dunes…)
/// and a few big shapes up the sides. Painted once per section.
class SceneryPainter extends CustomPainter {
  const SceneryPainter({required this.theme, required this.seed, required this.contentLeft, required this.contentWidth});
  final WorldTheme theme;
  final int seed;
  final double contentLeft, contentWidth;

  @override
  void paint(Canvas canvas, Size size) {
    var s = seed * 7919 + 13;
    double rnd() {
      s = (s * 9301 + 49297) % 233280;
      return s / 233280;
    }

    final w = size.width, h = size.height;
    // the ground bands run past the bottom edge (under the cloud bank):
    // keep them out of the world below
    canvas.clipRect(Offset.zero & size);
    final t = theme;
    final soft = t.soft, pop = t.pop;
    final mid = Color.lerp(t.soft, t.accent, .22)!;
    const white = MapColors.cloudWhite;
    // y positions up the section for side features (bottom landscape excluded)
    final rows = [for (var y = h - 420.0; y > 180; y -= 430 + rnd() * 80) y];

    switch (t.scene) {
      case WorldScene.meadow:
        _hills(canvas, w, h - 150, 26, 2.2, soft, rnd());
        _hills(canvas, w, h - 90, 20, 3.1, mid, rnd());
        for (final (i, y) in rows.indexed) {
          final left = i.isEven;
          _mound(canvas, left ? 0 : w, y, 70 + rnd() * 30, soft);
          for (var k = 0; k < 4; k++) {
            _dot(canvas, (left ? 10 : w - 10) + (left ? 1 : -1) * rnd() * 40, y - 10 - rnd() * 30, 3, _a(pop, .8));
          }
        }
      case WorldScene.castle:
        _hills(canvas, w, h - 110, 16, 1.6, soft, rnd());
        _castle(canvas, w * .14, h - 120, 1.0, mid, pop);
        _castle(canvas, w * .86, h - 110, .8, mid, pop);
        for (final (i, y) in rows.indexed) {
          _tower(canvas, i.isEven ? 26 : w - 26, y, 1.0, _a(mid, .8), pop);
        }
      case WorldScene.cove:
        for (var y = h - 60.0; y > 60; y -= 210) {
          _waveLine(canvas, w, y, _a(white, .55), 3, rnd() * 40);
        }
        _seaBand(canvas, w, h - 70, _a(soft, .9));
        for (final (i, y) in rows.indexed) {
          _rock(canvas, i.isEven ? 20 : w - 20, y, 40, _a(mid, .9));
        }
      case WorldScene.frost:
        for (var k = 0; k < (h / 18).round(); k++) {
          _dot(canvas, rnd() * w, rnd() * h, .8 + rnd() * 1.4, _a(white, .25 + rnd() * .5));
        }
        for (final y in [h * .25, h * .62]) {
          _aurora(canvas, w, y, pop, rnd());
        }
        _hills(canvas, w, h - 130, 24, 2.4, const Color(0xFF2B5A80), rnd());
        _hills(canvas, w, h - 80, 18, 3.4, const Color(0xFFDCEBF7).withValues(alpha: .9), rnd());
      case WorldScene.forest:
        _treeLine(canvas, w, h - 110, soft, mid, rnd);
        for (final (i, y) in rows.indexed) {
          final x = i.isEven ? 22.0 : w - 22;
          _roundTree(canvas, x, y, 34, i % 3 == 0 ? _a(pop, .55) : mid);
        }
      case WorldScene.town:
        _skyline(canvas, w, h - 70, soft, mid, t.sky, rnd);
        for (final (i, y) in rows.indexed) {
          _cloud(canvas, i.isEven ? 50 : w - 50, y, 90, _a(white, .75));
        }
      case WorldScene.mountain:
        _peaks(canvas, w, h - 70, _a(pop, .35), 150, rnd, snow: false);
        _peaks(canvas, w, h - 40, mid, 120, rnd);
        for (final (i, y) in rows.indexed) {
          final x = i.isEven ? 0.0 : w;
          _peak(canvas, x, y, 90, 120, _a(soft, .95));
        }
      case WorldScene.beach:
        _seaBand(canvas, w, h - 170, _a(pop, .30));
        _waveLine(canvas, w, h - 150, _a(white, .7), 3, rnd() * 40);
        _hills(canvas, w, h - 100, 18, 1.4, soft, rnd());
        for (final (i, y) in rows.indexed) {
          _umbrella(canvas, i.isEven ? 30 : w - 30, y, i.isEven ? t.accent : pop);
        }
      case WorldScene.garden:
        _hedge(canvas, w, h - 100, _a(pop, .45), t.accent, rnd);
        for (final (i, y) in rows.indexed) {
          final x = i.isEven ? 26.0 : w - 26;
          for (var k = 0; k < 5; k++) {
            _flower(canvas, x + (rnd() - .5) * 40, y + (rnd() - .5) * 60, 6 + rnd() * 4, k.isEven ? t.accent : _a(t.accent, .6));
          }
        }
      case WorldScene.sky:
        _rainbow(canvas, Offset(w / 2, h * .55), math.min(w, 520) * .42, .28);
        for (var k = 0; k < 5; k++) {
          _cloud(canvas, k * w / 4, h - 40 - rnd() * 30, 120 + rnd() * 40, _a(white, .9));
        }
        for (final (i, y) in rows.indexed) {
          _cloud(canvas, i.isEven ? 30 : w - 30, y, 110, _a(white, .8));
        }
      case WorldScene.jungle:
        _hills(canvas, w, h - 100, 22, 2.8, mid, rnd());
        for (final (i, y) in rows.indexed) {
          final left = i.isEven;
          _vine(canvas, left ? 14 : w - 14, y - 160, 170, Color.lerp(mid, t.deep, .3)!, pop);
        }
        _bigLeaf(canvas, 0, h - 60, 1, Color.lerp(mid, t.deep, .25)!);
        _bigLeaf(canvas, w, h - 70, -1, Color.lerp(mid, t.deep, .35)!);
      case WorldScene.island:
        _seaBand(canvas, w, h - 120, _a(pop, .28));
        _waveLine(canvas, w, h - 120, _a(white, .7), 3, 0);
        const sand = Color(0xFFF6DDAF);
        _islandBump(canvas, w * .18, h - 110, 70, sand);
        _islandBump(canvas, w * .84, h - 104, 56, sand);
        for (final y in rows) {
          _waveLine(canvas, w, y, _a(white, .45), 2.4, rnd() * 30);
        }
      case WorldScene.river:
        _hills(canvas, w, h - 170, 18, 2.2, soft, rnd());
        _seaBand(canvas, w, h - 120, _a(pop, .28));
        _waveLine(canvas, w, h - 104, _a(white, .6), 2.6, rnd() * 40);
        _hills(canvas, w, h - 60, 12, 3.0, mid, rnd());
      case WorldScene.space:
        for (var k = 0; k < (h / 14).round(); k++) {
          _dot(canvas, rnd() * w, rnd() * h, .7 + rnd() * 1.5, _a(white, .2 + rnd() * .6));
        }
        for (final (i, y) in rows.indexed) {
          _ringPlanet(canvas, i.isEven ? 30 : w - 30, y, 26 + rnd() * 10, i % 3 == 0 ? pop : soft);
        }
        _hills(canvas, w, h - 60, 14, 1.8, _a(soft, .9), rnd());
    }
  }

  // ------------------------------------------------------------ scenery parts
  static void _hills(Canvas c, double w, double y, double amp, double bumps, Color col, double phase) {
    final p = Path()..moveTo(0, y + 400);
    for (var x = 0.0; x <= w + 8; x += 8) {
      p.lineTo(x, y - amp * (.5 + .5 * math.sin(x / w * bumps * 2 * math.pi + phase * 6)));
    }
    p
      ..lineTo(w, y + 400)
      ..close();
    c.drawPath(p, _f..color = col);
  }

  static void _mound(Canvas c, double x, double y, double r, Color col) =>
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 1.2), _f..color = col);

  static void _tower(Canvas c, double x, double y, double k, Color col, Color flag) {
    c.drawRect(Rect.fromLTRB(x - 14 * k, y - 50 * k, x + 14 * k, y + 30 * k), _f..color = col);
    for (var i = -1; i <= 1; i++) {
      c.drawRect(Rect.fromLTRB(x + i * 9.5 * k - 4 * k, y - 58 * k, x + i * 9.5 * k + 4 * k, y - 49 * k), _f..color = col);
    }
    c.drawPath(Path()..moveTo(x - 17 * k, y - 50 * k)..lineTo(x, y - 84 * k)..lineTo(x + 17 * k, y - 50 * k)..close(), _f..color = Color.lerp(col, flag, .25)!);
    _line(c, Path()..moveTo(x, y - 84 * k)..lineTo(x, y - 98 * k), col, 2);
    c.drawPath(Path()..moveTo(x, y - 98 * k)..lineTo(x + 14 * k, y - 93 * k)..lineTo(x, y - 88 * k)..close(), _f..color = flag);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x - 4 * k, y - 30 * k, x + 4 * k, y - 18 * k), Radius.circular(4 * k)), _f..color = _a(MapColors.cloudWhite, .5));
  }

  static void _castle(Canvas c, double x, double y, double k, Color col, Color flag) {
    c.drawRect(Rect.fromLTRB(x - 40 * k, y - 34 * k, x + 40 * k, y + 60 * k), _f..color = col);
    for (var i = -3; i <= 3; i++) {
      c.drawRect(Rect.fromLTRB(x + i * 11 * k - 4 * k, y - 42 * k, x + i * 11 * k + 4 * k, y - 33 * k), _f..color = col);
    }
    _tower(c, x - 42 * k, y, k, col, flag);
    _tower(c, x + 42 * k, y, k, col, flag);
    _tower(c, x, y - 34 * k, k * 1.15, col, flag);
    c.drawPath(
        Path()
          ..moveTo(x - 12 * k, y + 60 * k)
          ..lineTo(x - 12 * k, y + 24 * k)
          ..arcToPoint(Offset(x + 12 * k, y + 24 * k), radius: Radius.circular(12 * k))
          ..lineTo(x + 12 * k, y + 60 * k)
          ..close(),
        _f..color = _a(MapColors.cloudWhite, .45));
  }

  static void _waveLine(Canvas c, double w, double y, Color col, double width, double phase) {
    final p = Path()..moveTo(-20, y);
    for (var x = -20.0; x <= w + 20; x += 6) {
      p.lineTo(x, y + 5 * math.sin((x + phase) / 22));
    }
    _line(c, p, col, width);
  }

  static void _seaBand(Canvas c, double w, double y, Color col) {
    final p = Path()..moveTo(-10, y + 2000);
    for (var x = -10.0; x <= w + 10; x += 6) {
      p.lineTo(x, y + 6 * math.sin(x / 18));
    }
    p
      ..lineTo(w + 10, y + 2000)
      ..close();
    c.drawPath(p, _f..color = col);
  }

  static void _rock(Canvas c, double x, double y, double r, Color col) {
    final p = Path()
      ..moveTo(x - r, y + r * .4)
      ..quadraticBezierTo(x - r, y - r * .3, x - r * .2, y - r * .5)
      ..quadraticBezierTo(x + r * .6, y - r * .6, x + r, y + r * .4)
      ..close();
    c.drawPath(p, _f..color = col);
  }

  static void _aurora(Canvas c, double w, double y, Color col, double phase) {
    final p = Path()..moveTo(-30, y);
    for (var x = -30.0; x <= w + 30; x += 8) {
      p.lineTo(x, y + 36 * math.sin(x / w * 2.4 * math.pi + phase * 6) + 14 * math.sin(x / 40));
    }
    for (final (width, alpha, colour) in [(70.0, .10, col), (38.0, .16, col), (14.0, .22, const Color(0xFFFF9EC4))]) {
      c.drawPath(
          p,
          _l
            ..strokeWidth = width
            ..color = colour.withValues(alpha: alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, width / 4));
    }
    _l.maskFilter = null;
  }

  static void _roundTree(Canvas c, double x, double y, double r, Color col) {
    c.drawRect(Rect.fromLTRB(x - r * .12, y, x + r * .12, y + r * 1.1), _f..color = _a(const Color(0xFF9A6A44), .55));
    _dot(c, x, y - r * .2, r, col);
    _dot(c, x - r * .6, y + r * .2, r * .7, col);
    _dot(c, x + r * .6, y + r * .25, r * .65, col);
  }

  static void _treeLine(Canvas c, double w, double y, Color back, Color front, double Function() rnd) {
    for (var x = -20.0; x < w + 30; x += 34 + rnd() * 16) {
      _dot(c, x, y - 20 - rnd() * 24, 30 + rnd() * 10, back);
    }
    c.drawRect(Rect.fromLTRB(0, y, w, y + 400), _f..color = back);
    for (var x = -10.0; x < w + 30; x += 40 + rnd() * 20) {
      _roundTree(c, x, y + 26, 22 + rnd() * 8, front);
    }
  }

  static void _skyline(Canvas c, double w, double y, Color back, Color front, Color window, double Function() rnd) {
    for (var x = -10.0; x < w + 10;) {
      final bw = 30 + rnd() * 26, bh = 40 + rnd() * 70;
      final col = rnd() > .5 ? back : front;
      c.drawRect(Rect.fromLTRB(x, y - bh, x + bw, y + 400), _f..color = col);
      if (rnd() > .5) {
        c.drawPath(Path()..moveTo(x - 3, y - bh)..lineTo(x + bw / 2, y - bh - 18)..lineTo(x + bw + 3, y - bh)..close(), _f..color = front);
      }
      for (var wy = y - bh + 10; wy < y - 8; wy += 16) {
        for (var wx = x + 7; wx < x + bw - 10; wx += 12) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(wx, wy, 6, 8), const Radius.circular(1.5)), _f..color = _a(window, .85));
        }
      }
      x += bw + 2;
    }
  }

  static void _peak(Canvas c, double x, double y, double halfW, double ht, Color col, {bool snow = true}) {
    c.drawPath(Path()..moveTo(x - halfW, y + ht * .4)..lineTo(x, y - ht * .6)..lineTo(x + halfW, y + ht * .4)..close(), _f..color = col);
    if (!snow) return;
    final s = .28;
    c.drawPath(
        Path()
          ..moveTo(x, y - ht * .6)
          ..lineTo(x + halfW * s, y - ht * .6 + ht * s)
          ..lineTo(x + halfW * s * .4, y - ht * .6 + ht * s * .8)
          ..lineTo(x, y - ht * .6 + ht * s)
          ..lineTo(x - halfW * s * .4, y - ht * .6 + ht * s * .8)
          ..lineTo(x - halfW * s, y - ht * .6 + ht * s)
          ..close(),
        _f..color = _a(MapColors.cloudWhite, .95));
  }

  static void _peaks(Canvas c, double w, double y, Color col, double ht, double Function() rnd, {bool snow = true}) {
    for (var x = -30.0; x < w + 60; x += 70 + rnd() * 40) {
      _peak(c, x, y, 60 + rnd() * 30, ht * (.7 + rnd() * .4), col, snow: snow);
    }
    c.drawRect(Rect.fromLTRB(0, y + ht * .38, w, y + 400), _f..color = col);
  }

  static void _umbrella(Canvas c, double x, double y, Color col) {
    _line(c, Path()..moveTo(x, y - 30)..lineTo(x + 4, y + 30), _a(const Color(0xFF9A6A44), .6), 2.2);
    final top = Path()
      ..moveTo(x - 30, y - 22)
      ..quadraticBezierTo(x, y - 62, x + 30, y - 22)
      ..close();
    c.drawPath(top, _f..color = _a(col, .7));
  }

  static void _flower(Canvas c, double x, double y, double r, Color col) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      _dot(c, x + r * .9 * math.cos(a), y + r * .9 * math.sin(a), r * .7, col);
    }
    _dot(c, x, y, r * .55, const Color(0xFFFFE07A));
  }

  static void _hedge(Canvas c, double w, double y, Color col, Color bloom, double Function() rnd) {
    for (var x = -10.0; x < w + 20; x += 26 + rnd() * 10) {
      _dot(c, x, y - rnd() * 14, 24 + rnd() * 8, col);
    }
    c.drawRect(Rect.fromLTRB(0, y, w, y + 400), _f..color = col);
    for (var k = 0; k < (w / 30).round(); k++) {
      _flower(c, rnd() * w, y - 10 + rnd() * 40, 4 + rnd() * 2, _a(bloom, .75));
    }
  }

  static void _cloud(Canvas c, double x, double y, double wd, Color col) {
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: wd, height: wd * .32), Radius.circular(wd * .16)))
      ..addOval(Rect.fromCircle(center: Offset(x - wd * .12, y - wd * .12), radius: wd * .2))
      ..addOval(Rect.fromCircle(center: Offset(x + wd * .14, y - wd * .08), radius: wd * .15));
    c.drawPath(p, _f..color = col);
  }

  static void _rainbow(Canvas c, Offset o, double r, double alpha) {
    const cols = [Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFD43B), Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFF9775FA)];
    for (final (i, col) in cols.indexed) {
      c.drawArc(Rect.fromCircle(center: o, radius: r - i * 11), math.pi, math.pi, false,
          _l
            ..color = col.withValues(alpha: alpha)
            ..strokeWidth = 11
            ..strokeCap = StrokeCap.butt);
    }
    _l.strokeCap = StrokeCap.round;
  }

  static void _vine(Canvas c, double x, double y, double len, Color col, Color bloom) {
    final p = Path()..moveTo(x, y);
    for (var d = 0.0; d <= len; d += 6) {
      p.lineTo(x + 8 * math.sin(d / 22), y + d);
    }
    _line(c, p, col, 2.6);
    for (var d = 20.0; d < len; d += 26) {
      final lx = x + 8 * math.sin(d / 22);
      final side = (d ~/ 26).isEven ? 1 : -1;
      c.drawOval(Rect.fromCenter(center: Offset(lx + side * 7, y + d), width: 14, height: 8), _f..color = col);
    }
    _dot(c, x + 8 * math.sin(len / 22), y + len, 5, _a(bloom, .8));
  }

  static void _bigLeaf(Canvas c, double x, double y, double dir, Color col) {
    for (final (a, l) in [(-1.2, 120.0), (-.7, 140.0), (-.25, 110.0)]) {
      c.save();
      c.translate(x, y);
      c.scale(dir, 1);
      c.rotate(a);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(l * .5, -l * .28, l, 0)
        ..quadraticBezierTo(l * .5, l * .28, 0, 0)
        ..close();
      c.drawPath(leaf, _f..color = col);
      c.restore();
    }
  }

  static void _islandBump(Canvas c, double x, double y, double r, Color sand) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y + 6), width: r * 2, height: r * .5), _f..color = sand);
    final palm = DecoKind(r * .9, r * 1.1, DecoMotif.palm, const Color(0x9943A85E), const Color(0x99B0794A), DecoAnim.none, 0);
    c.save();
    c.translate(x - r * .2, y - r * .48);
    paintMotif(c, palm, Size(palm.w, palm.h), 1, 0);
    c.restore();
  }

  static void _ringPlanet(Canvas c, double x, double y, double r, Color col) {
    c.drawCircle(Offset(x, y), r, _f..color = col.withValues(alpha: .55));
    c.save();
    c.translate(x, y);
    c.rotate(-.4);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 3, height: r * .7), _l..color = col.withValues(alpha: .45)..strokeWidth = 3);
    c.restore();
  }

  @override
  bool shouldRepaint(SceneryPainter old) => old.theme != theme || old.seed != seed || old.contentWidth != contentWidth;
}

/// A level button: solid 6 px "3D" edge below, body, and the inset top
/// highlight (box-shadow 0 6px 0 deep, inset 0 3px 0 rgba(255,255,255,.35)).
class NodePainter extends CustomPainter {
  const NodePainter({required this.color, required this.deep});
  final Color color, deep;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()..isAntiAlias = true;
    paint.color = deep;
    canvas.drawCircle(c + const Offset(0, 6), r, paint);
    paint.color = color;
    canvas.drawCircle(c, r, paint);
    final body = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final shifted = Path()..addOval(Rect.fromCircle(center: c + const Offset(0, 3), radius: r));
    paint.color = MapColors.nodeInnerHighlight;
    canvas.drawPath(Path.combine(PathOperation.difference, body, shifted), paint);
  }

  @override
  bool shouldRepaint(NodePainter old) => old.color != color || old.deep != deep;
}

/// Current level: yellow ring growing 1 -> 1.75 while fading .6 -> 0 (1.6 s).
class PulsePainter extends CustomPainter {
  PulsePainter({required this.time}) : super(repaint: time);
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Curves.easeOut.transform((time.value / 1.6) % 1.0);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 * (1 + .75 * p),
      Paint()..color = LikhoColors.primary.withValues(alpha: .6 * (1 - p)),
    );
  }

  @override
  bool shouldRepaint(PulsePainter old) => false;
}
