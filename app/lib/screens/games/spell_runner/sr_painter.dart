import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens.dart';
import '../../../game/spell_runner/sr_engine.dart';
import 'sr_scene.dart';

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
  const SrRider({required this.pose, required this.lean, required this.squash, required this.shake, required this.alpha});
  final String pose;
  final double lean, squash, shake, alpha;
}

/// Paints the moving world: lane lines and seams sliding towards the
/// viewer, the things beside the road, the bubbles, stars and bumps on it,
/// Pencil on his skateboard, all far to near.
class SrWorldPainter extends CustomPainter {
  SrWorldPainter({required this.road, required this.game, required this.scenery, required this.rider, required this.time, required this.hint});
  final SrRoad road;
  final SrGame game;
  final List<SrScenery> scenery;
  final SrRider rider;
  final double time;

  /// The letter whose bubble glows (after a wrong one), or null.
  final String? hint;

  static final _letterCache = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    _lines(canvas);
    // far to near: scenery, things, Pencil (at 0), things that passed him
    final items = <(double, void Function())>[
      for (final s in scenery)
        if (s.z - game.dist > -3 && s.z - game.dist < SrGame.view + 6) (s.z - game.dist, () => _scenery(canvas, s, size)),
      for (final t in game.things)
        if (!t.taken && t.z - game.dist > -6 && t.z - game.dist < SrGame.view + 4) (t.z - game.dist, () => _thing(canvas, t)),
      (0.0, () => _pencil(canvas)),
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
        final hover = lw * .55 + math.sin(time * 4 + t.id) * lw * .05;
        _shadow(canvas, foot, lw * .3, alpha: fade);
        sprite(canvas, SrArt.star, foot - Offset(0, hover), lw * .38, scaleX: math.cos(time * 4 + t.id).abs() * .8 + .2, alpha: fade);
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
    // the shine
    canvas.drawOval(Rect.fromCenter(center: c + Offset(-r * .42, -r * .5), width: r * .45, height: r * .24), Paint()..color = MonsterColors.magicCore.withValues(alpha: .9 * fade));
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
    canvas.saveLayer(rect.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, fade));
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2 + size * .04));
    canvas.restore();
  }

  // ------------------------------------------------------------ Pencil

  /// Pencil's height on the screen.
  double get pencilHeight => SrRoad.pencilHeight(road.screen);

  /// Where Pencil's board touches the road (or would, in the air).
  Offset get pencilFoot => Offset(road.at(0, game.lane).dx, road.player);

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
    sprite(canvas, rider.pose, at, h, rotation: rider.lean, content: SrArt.box(rider.pose), alpha: rider.alpha);
    canvas.restore();
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
