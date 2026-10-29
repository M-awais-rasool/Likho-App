import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../../../design/tokens.dart';
import '../../../game/spell_runner/sr_engine.dart';
import 'sr_scene.dart';
import 'sr_v2_boxes.dart';

/// Something beside the road (a tree, flowers, a fence) at [z] on the road
/// (world units from the start), on the left (-1) or right (1) side, [out]
/// beyond the road's edge (in lanes), [size] times its usual height.
class SrScenery {
  const SrScenery({required this.asset, required this.z, required this.side, required this.out, required this.size, this.flip = false});
  final String asset;
  final double z, side, out, size;
  final bool flip;
}

/// How Pencil looks this frame.
class SrRider {
  const SrRider({required this.pose, required this.lane, required this.lean, required this.squash, required this.shake, required this.alpha});
  final String pose;

  /// Where he is across the road (-1..1, gliding between lanes).
  final double lane;
  final double lean, squash, shake, alpha;
}

/// Gloop chasing Pencil from behind: its picture, where it is across the
/// road, how far up into view it has come (0..1), its hop (0..1) and, at
/// the end, how close it has got to him (0..1).
class SrChase {
  const SrChase({required this.pose, required this.lane, required this.rise, required this.hop, required this.near});
  final String pose;
  final double lane, rise, hop, near;
}

/// Paints the moving world: lane lines and seams sliding towards the
/// viewer, the things beside the road, the bubbles, stars and bumps on it,
/// Pencil on his skateboard, all far to near.
class SrWorldPainter extends CustomPainter {
  SrWorldPainter({required this.road, required this.game, required this.scenery, required this.rider, required this.time, required this.hint, this.chase});
  final SrRoad road;
  final SrGame game;
  final List<SrScenery> scenery;
  final SrRider rider;
  final SrChase? chase;
  final double time;

  /// The letter whose bubble glows (after a wrong one), or null.
  final String? hint;

  static final _letterCache = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    _clouds(canvas, size);
    _grit(canvas);
    _kerbs(canvas);
    _lines(canvas);
    // far to near: scenery, things, Pencil (at 0), things that passed him
    final items = <(double, void Function())>[
      for (final s in scenery)
        if (s.z - game.dist > -3 && s.z - game.dist < SrGame.view + 6) (s.z - game.dist, () => _scenery(canvas, s, size)),
      for (final t in game.things)
        if (!t.taken && t.z - game.dist > -6 && t.z - game.dist < SrGame.view + 4) (t.z - game.dist, () => _thing(canvas, t)),
      (0.0, () => _pencil(canvas)),
      if (chase != null) (-1.0, () => _gloop(canvas, chase!)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, draw) in items) {
      draw();
    }
    _speedLines(canvas, size);
  }

  // ------------------------------------------------------------ the road

  void _lines(Canvas canvas) {
    final d = game.dist;
    // dashes between the lanes, sliding towards us
    const period = 4.0, len = 1.7;
    final paint = Paint()..color = MonsterColors.panel;
    for (var k = 0; k < 22; k++) {
      final z0 = k * period - (d % period) - 1.5;
      if (z0 > 70) break;
      final fade = (road.s(z0) * 3).clamp(0.0, 1.0);
      if (fade <= .02) continue;
      for (final b in [-.5, .5]) {
        final w = .045;
        final path = Path()
          ..moveTo(road.at(z0, b - w).dx, road.at(z0, b - w).dy)
          ..lineTo(road.at(z0, b + w).dx, road.at(z0, b + w).dy)
          ..lineTo(road.at(z0 + len, b + w).dx, road.at(z0 + len, b + w).dy)
          ..lineTo(road.at(z0 + len, b - w).dx, road.at(z0 + len, b - w).dy)
          ..close();
        canvas.drawPath(path, paint..color = MonsterColors.panel.withValues(alpha: .85 * fade));
      }
    }
    // faint seams across the road: you feel the speed
    const seams = 6.0;
    final seam = Paint()
      ..color = MonsterColors.shadow
      ..strokeWidth = 1.4;
    for (var k = 0; k < 14; k++) {
      final z = k * seams - (d % seams) + 2;
      final s = road.s(z);
      if (s < .12) continue;
      final a = road.at(z, -1.5), b = road.at(z, 1.5);
      canvas.drawLine(a, b, seam..color = MonsterColors.shadow.withValues(alpha: .35 * s));
    }
  }

  /// A strip of road [z0]..[z1] ahead between lanes [a] and [b].
  Path _strip(double z0, double z1, double a, double b) {
    final p0 = road.at(z0, a), p1 = road.at(z0, b), p2 = road.at(z1, b), p3 = road.at(z1, a);
    return Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
  }

  /// Red and white kerbs along both edges, rushing past.
  void _kerbs(Canvas canvas) {
    const period = 2.4, inner = 1.5, outer = 1.6;
    final red = Paint()..color = RunnerColors.kerbRed;
    final white = Paint()..color = RunnerColors.kerbWhite;
    final edge = Paint()..color = RunnerColors.kerbEdge;
    for (var k = 0; k < 30; k++) {
      final z0 = k * period - (game.dist % period) - 2;
      final s = road.s(z0);
      if (s < .1) break;
      final a = (s * 4).clamp(0.0, 1.0);
      for (final side in [-1.0, 1.0]) {
        final (i, o) = (side * inner, side * outer);
        canvas.drawPath(_strip(z0, z0 + period / 2, i, o), red..color = RunnerColors.kerbRed.withValues(alpha: a));
        canvas.drawPath(_strip(z0 + period / 2, z0 + period, i, o), white..color = RunnerColors.kerbWhite.withValues(alpha: a));
        canvas.drawPath(_strip(z0, z0 + period, i - side * .02, i), edge);
      }
    }
  }

  /// Specks of grit in the asphalt, the same pattern every few steps, so
  /// the road itself seems to rush by.
  void _grit(Canvas canvas) {
    const period = 7.0;
    final dark = Paint()..color = RunnerColors.grit;
    final light = Paint()..color = RunnerColors.gritLight;
    for (var k = 0; k < 10; k++) {
      final base = k * period - (game.dist % period) - 2;
      for (final (lane, dz, big) in _gritDots) {
        final z = base + dz;
        final s = road.s(z);
        if (s < .2) continue;
        final p = road.at(z, lane);
        final r = road.laneWidth * s * (big ? .035 : .02);
        canvas.drawOval(Rect.fromCenter(center: p, width: r * 2.4, height: r), big ? light : dark);
      }
    }
  }

  static final _gritDots = () {
    final r = math.Random(11);
    return [for (var i = 0; i < 26; i++) (r.nextDouble() * 2.8 - 1.4, r.nextDouble() * 7.0, i % 4 == 0)];
  }();

  /// Clouds drifting slowly over the sky, above the far hills.
  void _clouds(Canvas canvas, Size size) {
    final p = Paint()..color = RunnerColors.cloud;
    final top = road.vanish.dy;
    for (final (x0, y, k, speed) in const [(.1, .2, 1.0, 7.0), (.62, .34, .75, 5.0), (.9, .12, .6, 9.0)]) {
      final span = size.width + 160;
      final x = (x0 * span - time * speed) % span - 80;
      final at = Offset(x, top * y);
      for (final (dx, dy, r) in const [(-26.0, 6.0, 18.0), (0.0, -4.0, 26.0), (26.0, 4.0, 20.0), (8.0, 10.0, 18.0)]) {
        canvas.drawCircle(at + Offset(dx, dy) * k, r * k, p);
      }
    }
  }

  // ------------------------------------------------------------ drawing a picture

  /// [asset] standing with its bottom middle on [foot], [height] tall.
  static Rect? sprite(Canvas canvas, String asset, Offset foot, double height, {double rotation = 0, bool flip = false, double alpha = 1, double scaleX = 1, Rect? content}) {
    final img = SrSprites.of(asset);
    if (img == null || height <= 1 || alpha <= 0) return null;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final w = height * img.width / img.height;
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.scale((flip ? -1 : 1) * scaleX, 1);
    final c = content ?? const Rect.fromLTRB(0, 0, 1, 1);
    // the thing itself stands on the foot, wherever it sits in its picture
    final dst = Rect.fromLTWH(-w * c.center.dx, -height * c.bottom, w, height);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (alpha < 1) paint.color = Color.fromRGBO(0, 0, 0, alpha);
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();
    return dst.shift(foot);
  }

  void _shadow(Canvas canvas, Offset at, double w, {double alpha = 1}) {
    canvas.drawOval(Rect.fromCenter(center: at, width: w, height: w * .22), Paint()..color = MonsterColors.shadow.withValues(alpha: MonsterColors.shadow.a * alpha));
  }

  void _scenery(Canvas canvas, SrScenery s, Size size) {
    final z = s.z - game.dist;
    final lane = s.side * (1.75 + s.out);
    final foot = road.at(z, lane);
    if (foot.dx < -size.width * .6 || foot.dx > size.width * 1.6) return;
    final h = road.laneWidth * 1.9 * s.size * road.s(z);
    final fade = ((SrGame.view + 6 - z) / 10).clamp(0.0, 1.0); // fades in far away
    sprite(canvas, s.asset, foot, h, flip: s.flip, alpha: fade);
  }

  void _thing(Canvas canvas, SrThing t) {
    final z = t.z - game.dist;
    final s = road.s(z);
    final lw = road.laneWidth * s;
    final foot = road.at(z, t.lane.toDouble());
    final fade = ((SrGame.view + 4 - z) / 10).clamp(0.0, 1.0);
    switch (t.kind) {
      case SrKind.letter:
        _bubble(canvas, t, foot, lw, fade);
      case SrKind.coin:
        // the magnet pulls the stars over to him as they come near
        var at = foot;
        if (game.has(SrKind.magnet) && z < 7) {
          final k = Curves.easeIn.transform((1 - z / 7).clamp(0.0, 1.0));
          at = road.at(z, t.lane + (rider.lane - t.lane) * k) - Offset(0, lw * .6 * k);
        }
        final hover = lw * .55 + math.sin(time * 4 + t.id) * lw * .05;
        _shadow(canvas, foot, lw * .3, alpha: fade);
        sprite(canvas, SrArt.star, at - Offset(0, hover), lw * .38, scaleX: math.cos(time * 4 + t.id).abs() * .8 + .2, alpha: fade);
        _glint(canvas, at - Offset(-lw * .1, hover + lw * .3), lw * .12, (time * .9 + t.id * .37) % 1, fade);
      case SrKind.magnet || SrKind.shield || SrKind.spring || SrKind.double:
        _orb(canvas, t, foot, lw, fade);
      case SrKind.bar || SrKind.banner || SrKind.branch:
        _high(canvas, t, foot, lw, road.s(z), fade);
      case SrKind.heart:
        // a heart floats over the road, beating
        final hover = lw * .6 + math.sin(time * 3 + t.id) * lw * .06;
        final beat = 1 + .1 * math.sin(time * 9).abs();
        _shadow(canvas, foot, lw * .36, alpha: fade);
        canvas.drawCircle(foot - Offset(0, hover + lw * .2), lw * .32, Paint()..color = MonsterColors.gem.withValues(alpha: .3 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        sprite(canvas, SrArt.heart, foot - Offset(0, hover), lw * .44 * beat, alpha: fade);
      default:
        final w = lw *
            switch (t.kind) {
              SrKind.puddle => 1.0,
              SrKind.log => .95,
              SrKind.rock => .7,
              SrKind.hay => .78,
              SrKind.cone => .48,
              SrKind.banana => .55,
              SrKind.ramp => .9,
              SrKind.cart => 1.15,
              SrKind.bench => .98,
              SrKind.flowerbox => .98,
              _ => .7,
            };
        final img = SrSprites.of(SrArt.thing(t.kind));
        if (img == null) return;
        final h = w * img.height / img.width;
        if (t.kind != SrKind.puddle) _shadow(canvas, foot, w * .9, alpha: fade);
        // a bumped thing wobbles
        final wob = t.bumped ? math.sin(time * 30) * .08 : 0.0;
        sprite(canvas, SrArt.thing(t.kind), foot, h, rotation: wob, alpha: fade);
    }
  }

  /// A power-up floating over the road: a shiny orb of its colour with its
  /// picture, turning sparkles around it.
  void _orb(Canvas canvas, SrThing t, Offset foot, double lw, double fade) {
    final r = lw * .34;
    final hover = lw * .62 + math.sin(time * 3 + t.id) * lw * .06;
    final c = foot - Offset(0, hover);
    final color = SrPowerArt.color(t.kind);
    _shadow(canvas, foot, r * 1.4, alpha: fade);
    canvas.drawCircle(c, r * 1.45, Paint()..shader = ui.Gradient.radial(c, r * 1.45, [color.withValues(alpha: .45 * fade), color.withValues(alpha: 0)]));
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = ui.Gradient.radial(c - Offset(r * .35, r * .4), r * 1.4, [Color.lerp(color, MonsterColors.magicCore, .55)!.withValues(alpha: fade), color.withValues(alpha: fade)]),
    );
    canvas.drawCircle(c, r, Paint()..color = MonsterColors.magicCore.withValues(alpha: .95 * fade)..style = PaintingStyle.stroke..strokeWidth = math.max(1.5, r * .12));
    SrPowerArt.icon(canvas, t.kind, c, r * .58, MonsterColors.magicCore.withValues(alpha: fade));
    canvas.drawOval(Rect.fromCenter(center: c + Offset(-r * .4, -r * .48), width: r * .42, height: r * .22), Paint()..color = MonsterColors.magicCore.withValues(alpha: .7 * fade));
    for (var k = 0; k < 3; k++) {
      final a = time * 2.4 + k * math.pi * 2 / 3;
      _glint(canvas, c + Offset(math.cos(a) * r * 1.35, math.sin(a) * r * .9), r * .32, ((time * 1.3 + k * .33) % 1) * .18, fade);
    }
  }

  /// A twinkle that flashes now and then ([phase] 0..1 of its cycle).
  void _glint(Canvas canvas, Offset at, double r, double phase, double fade) {
    if (phase > .18) return;
    final k = math.sin(phase / .18 * math.pi);
    final p = Paint()..color = MonsterColors.magicCore.withValues(alpha: .95 * fade * k);
    final a = r * k, b = r * .22 * k;
    canvas.drawPath(
      Path()
        ..moveTo(at.dx, at.dy - a)
        ..quadraticBezierTo(at.dx + b, at.dy - b, at.dx + a, at.dy)
        ..quadraticBezierTo(at.dx + b, at.dy + b, at.dx, at.dy + a)
        ..quadraticBezierTo(at.dx - b, at.dy + b, at.dx - a, at.dy)
        ..quadraticBezierTo(at.dx - b, at.dy - b, at.dx, at.dy - a)
        ..close(),
      p,
    );
  }

  /// A high thing across the lane (a bar, a banner, a branch): its top
  /// part as drawn, the posts under it drawn taller, so that the open space
  /// under it is a little more than Pencil sliding and less than Pencil
  /// standing.
  void _high(Canvas canvas, SrThing t, Offset foot, double lw, double s, double fade) {
    final img = SrSprites.of(SrArt.thing(t.kind));
    if (img == null) return;
    final w = lw * 1.06;
    final k = w / img.width;
    final gap = SrArt.gap(t.kind);
    final src = Size(img.width.toDouble(), img.height.toDouble());
    final topH = src.height * (1 - gap) * k;
    final picture = pencilHeight * s; // the rider picture's height there
    final room = math.max(src.height * gap * k, picture * (srRiderFoot - srSlideTop) * 1.12);
    _shadow(canvas, foot - Offset(w * .4, 0), w * .22, alpha: fade);
    _shadow(canvas, foot + Offset(w * .4, 0), w * .22, alpha: fade);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (fade < 1) paint.color = Color.fromRGBO(0, 0, 0, fade);
    final left = foot.dx - w / 2;
    canvas.drawImageRect(img, Rect.fromLTWH(0, src.height * (1 - gap), src.width, src.height * gap), Rect.fromLTWH(left, foot.dy - room, w, room), paint);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, src.width, src.height * (1 - gap)), Rect.fromLTWH(left, foot.dy - room - topH, w, topH), paint);
  }

  void _bubble(Canvas canvas, SrThing t, Offset foot, double lw, double fade) {
    if (t.label.isEmpty) return;
    var r = lw * .47;
    // a new letter pops in
    if (t.relabeled < .3) r *= 1 + .3 * math.sin(t.relabeled / .3 * math.pi);
    final bob = math.sin(time * 3 + t.id) * r * .08;
    final c = foot - Offset(0, r * 1.25 + bob);
    _shadow(canvas, foot, r * 1.2, alpha: fade * .8);
    final glow = hint != null && t.label == hint;
    if (glow) {
      canvas.drawCircle(c, r * (1.2 + .08 * math.sin(time * 8)), Paint()..color = MonsterColors.hintGlow.withValues(alpha: .7 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    final rect = Rect.fromCircle(center: c, radius: r);
    // a soft halo, the bubble wobbling as it floats
    canvas.drawCircle(
      c,
      r * 1.22,
      Paint()..shader = ui.Gradient.radial(c, r * 1.22, [MonsterColors.bubbleTint.withValues(alpha: .38 * fade), MonsterColors.bubbleTint.withValues(alpha: 0)], [.72, 1]),
    );
    final wob = math.sin(time * 5 + t.id * 1.7) * .035;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1 + wob, 1 - wob);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c - Offset(r * .3, r * .35), r * 1.3, [
          MonsterColors.magicCore.withValues(alpha: .97 * fade),
          MonsterColors.bubbleTint.withValues(alpha: .95 * fade),
        ]),
    );
    canvas.drawCircle(c, r, Paint()..color = MonsterColors.ribbon.withValues(alpha: .9 * fade)..style = PaintingStyle.stroke..strokeWidth = math.max(1.5, r * .09));
    // the shine, a little spark beside it, and light along the bottom rim
    canvas.drawOval(Rect.fromCenter(center: c + Offset(-r * .42, -r * .5), width: r * .45, height: r * .24), Paint()..color = MonsterColors.magicCore.withValues(alpha: .9 * fade));
    canvas.drawCircle(c + Offset(-r * .12, -r * .66), r * .07, Paint()..color = MonsterColors.magicCore.withValues(alpha: .85 * fade));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * .82),
      math.pi * .2,
      math.pi * .6,
      false,
      Paint()
        ..color = MonsterColors.magicCore.withValues(alpha: .5 * fade)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.0, r * .07),
    );
    canvas.restore();
    // the letter
    final size = (r * 1.2).roundToDouble();
    if (size < 4) return;
    final key = '${t.label}@$size';
    final tp = _letterCache.putIfAbsent(key, () {
      if (_letterCache.length > 400) _letterCache.clear();
      return TextPainter(
        text: TextSpan(text: t.label, style: LikhoFonts.letter(size: size, color: MonsterColors.signInk).copyWith(height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    // (a layer only while it fades in: layers are slow on phones)
    final fading = fade < .99;
    if (fading) canvas.saveLayer(rect.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, fade));
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2 + size * .04));
    if (fading) canvas.restore();
  }

  // ------------------------------------------------------------ Pencil

  /// Pencil's height on the screen.
  double get pencilHeight => SrRoad.pencilHeight(road.screen);

  /// Where Pencil's board touches the road (or would, in the air).
  Offset get pencilFoot => Offset(road.at(0, rider.lane).dx, road.player);

  void _pencil(Canvas canvas) {
    final h = pencilHeight;
    final foot = pencilFoot;
    final up = game.air * road.screen.height * .14;
    _shadow(canvas, foot, h * .55 * (1 - (game.air * .35).clamp(0.0, .5)), alpha: 1 - (game.air * .4).clamp(0.0, .6));
    // the board rumbles on the road
    final rumble = game.air > 0 ? 0.0 : math.sin(time * 42) * .8 + math.sin(time * 27) * .6;
    final at = foot + Offset(rider.shake, -up + rumble);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1 + (1 - rider.squash) * .6, rider.squash);
    canvas.translate(-at.dx, -at.dy);
    // spring shoes: a green glow under the board
    if (game.has(SrKind.spring)) {
      canvas.drawOval(Rect.fromCenter(center: foot, width: h * .7, height: h * .16), Paint()..shader = ui.Gradient.radial(foot, h * .35, [RunnerColors.springGlow, RunnerColors.springGlow.withValues(alpha: 0)]));
    }
    sprite(canvas, rider.pose, at, h, rotation: rider.lean, content: SrArt.riderBox, alpha: rider.alpha);
    canvas.restore();
    // the shield: a bubble around him (it blinks before it ends)
    final shield = game.powers[SrKind.shield] ?? 0;
    if (shield > 0 && (shield > 2 || (time * 6).floor().isEven)) {
      final c = at - Offset(0, h * .5);
      final r = h * (.62 + .02 * math.sin(time * 6));
      canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c, r, [RunnerColors.shieldGlow.withValues(alpha: 0), RunnerColors.shieldGlow], [.7, 1]));
      canvas.drawCircle(c, r, Paint()..color = MonsterColors.magicCore.withValues(alpha: .6)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * .82), math.pi * 1.1, math.pi * .45, false, Paint()..color = MonsterColors.magicCore.withValues(alpha: .7)..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = 4);
    }
  }

  /// Gloop behind him (nearer to us, so bigger and lower on the screen):
  /// it comes up from below, hops along, and at the end reaches him.
  void _gloop(Canvas canvas, SrChase c) {
    final h = pencilHeight * .78;
    final x = road.at(0, c.lane).dx;
    final y = road.player + h * (.42 - .3 * c.near) + (1 - c.rise) * h * 1.3;
    final up = c.hop * h * .12;
    _shadow(canvas, Offset(x, y), h * .5 * (1 - c.hop * .2), alpha: c.rise);
    sprite(canvas, c.pose, Offset(x, y - up), h, content: const Rect.fromLTRB(0, 0, 1, srGloopFoot), alpha: c.rise.clamp(0.0, 1.0));
  }

  void _speedLines(Canvas canvas, Size size) {
    final fast = game.boost > 0 ? 1.0 : ((game.speed - 8.5) / 3).clamp(0.0, .6);
    if (fast <= 0) return;
    final r = math.Random(7);
    final p = Paint()..strokeCap = StrokeCap.round;
    for (var k = 0; k < 18; k++) {
      final a = r.nextDouble() * 2 * math.pi;
      final dir = Offset(math.cos(a), math.sin(a) * .7);
      final run = (time * (2.2 + r.nextDouble()) + r.nextDouble()) % 1;
      final from = road.vanish + dir * (size.width * (.35 + run * .6));
      final to = from + dir * size.width * .12;
      canvas.drawLine(from, to, p..color = MonsterColors.panel.withValues(alpha: .55 * fast * (1 - run))..strokeWidth = 2 + 2 * run);
    }
  }

  @override
  bool shouldRepaint(SrWorldPainter old) => true;
}

/// How the power-ups look: their colour and their picture (drawn in white
/// on the road's orbs, in colour on the timers).
abstract final class SrPowerArt {
  static Color color(SrKind k) => switch (k) {
    SrKind.magnet => RunnerColors.magnet,
    SrKind.shield => RunnerColors.shield,
    SrKind.spring => RunnerColors.spring,
    _ => RunnerColors.double2x,
  };

  static final _glyphs = <String, TextPainter>{};

  /// [k]'s picture at [c], [r] its half size.
  static void icon(Canvas canvas, SrKind k, Offset c, double r, Color color) {
    if (k == SrKind.magnet) {
      // a horseshoe magnet, its tips up
      final w = r * .62, t = r * .42;
      final u = Path()
        ..moveTo(c.dx - w, c.dy - r * .75)
        ..lineTo(c.dx - w, c.dy + r * .02)
        ..arcToPoint(Offset(c.dx + w, c.dy + r * .02), radius: Radius.circular(w), clockwise: false)
        ..lineTo(c.dx + w, c.dy - r * .75);
      canvas.drawPath(u, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = t);
      final tips = Paint()..color = RunnerColors.magnetTip.withValues(alpha: color.a);
      for (final x in [-w, w]) {
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx + x, c.dy - r * .62), width: t, height: r * .3), tips);
      }
      return;
    }
    final size = (r * 2).roundToDouble();
    if (size < 3) return;
    final key = '${k.name}@$size@${color.toARGB32()}';
    final tp = _glyphs.putIfAbsent(key, () {
      if (_glyphs.length > 120) _glyphs.clear();
      final style = k == SrKind.double
          ? LikhoFonts.title(size: size * .8, weight: FontWeight.w800, color: color).copyWith(height: 1)
          : TextStyle(
              fontFamily: (k == SrKind.shield ? Symbols.shield_rounded : Symbols.keyboard_double_arrow_up_rounded).fontFamily,
              package: (k == SrKind.shield ? Symbols.shield_rounded : Symbols.keyboard_double_arrow_up_rounded).fontPackage,
              fontSize: size,
              height: 1,
              color: color,
              fontVariations: const [FontVariation('FILL', 1), FontVariation('wght', 700)],
            );
      final text = switch (k) {
        SrKind.shield => String.fromCharCode(Symbols.shield_rounded.codePoint),
        SrKind.spring => String.fromCharCode(Symbols.keyboard_double_arrow_up_rounded.codePoint),
        _ => 'x2',
      };
      return TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    });
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }
}
