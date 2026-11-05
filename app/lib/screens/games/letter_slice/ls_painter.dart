import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../design/tokens.dart';
import '../../../game/letter_slice/ls_engine.dart';
import 'ls_scene.dart';
import 'ls_art.dart';
import 'ls_theme.dart';

/// Half of a sliced fruit, flying off (screen units).
class LsHalf {
  LsHalf({required this.art, required this.at, required this.v, required this.angle, required this.spin, required this.upper, required this.size});
  final String art;
  Offset at, v;
  double angle, spin, age = 0;
  final bool upper;
  final double size;

  void step(double dt, double gravity) {
    age += dt;
    v += Offset(0, gravity * dt);
    at += v * dt;
    angle += spin * dt;
  }
}

/// A juice stain on the board, fading.
class LsSplat {
  LsSplat(this.at, this.color, this.size, this.born, this.seed);
  final Offset at;
  final Color color;
  final double size, born;
  final int seed;
}

/// The blade's trail: where the finger was, and when.
class LsTrail {
  final points = <(Offset, double)>[];

  void add(Offset p, double t) => points.add((p, t));

  void forget(double now) => points.removeWhere((p) => now - p.$2 > .16);
}

/// Paints juice, glossy letter fruit, sliced halves and the swipe trail.
class LsPainter extends CustomPainter {
  LsPainter({required this.view, required this.game, required this.halves, required this.splats, required this.trail, required this.time});
  final LsView view;
  final LsGame game;
  final List<LsHalf> halves;
  final List<LsSplat> splats;
  final LsTrail trail;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in splats) {
      _splat(canvas, s);
    }
    for (final h in halves) {
      _half(canvas, h);
    }
    final glow = game.dropped >= 2;
    for (final f in game.flying) {
      if (!f.cut) _fruit(canvas, f, glow && f.letter == game.need && !f.bounced);
    }
    _trail(canvas);
  }

  void _splat(Canvas canvas, LsSplat s) {
    final age = time - s.born;
    final a = (1 - age / 4).clamp(0.0, 1.0) * .18;
    if (a <= 0) return;
    final rnd = math.Random(s.seed);
    final paint = Paint()..color = s.color.withValues(alpha: a);
    canvas.drawCircle(s.at, s.size * .55, paint);
    for (var k = 0; k < 9; k++) {
      final ang = rnd.nextDouble() * math.pi * 2;
      final d = s.size * (.45 + rnd.nextDouble() * .5);
      canvas.drawCircle(s.at + Offset(math.cos(ang), math.sin(ang)) * d, s.size * (.08 + rnd.nextDouble() * .18), paint);
    }
  }

  void _fruit(Canvas canvas, LsFruit f, bool glow) {
    final c = view.at(f.x, f.y);
    final r = f.r * view.scale;
    final age = game.time - f.born;
    final pop = age < .25 ? .7 + .3 * math.sin(age / .25 * math.pi / 2) : 1.0;
    if (glow || f.kind != LsKind.fruit) {
      final k = .5 + .5 * math.sin(time * 6);
      canvas.drawCircle(
        c,
        r * (1.15 + .08 * k),
        Paint()
          ..color = (glow ? LsTheme.gold : LsFruitArt.colors(f.art).$1).withValues(alpha: .22 + .15 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(pop);
    if (f.bounced) canvas.saveLayer(Rect.fromCircle(center: Offset.zero, radius: r * 1.4), Paint()..color = const Color(0xBFFFFFFF));
    LsFruitArt.draw(canvas, art: f.art, radius: r, letter: f.letter, angle: -f.angle);
    if (f.bounced) canvas.restore();
    canvas.restore();
  }

  void _half(Canvas canvas, LsHalf h) {
    final a = (1 - (h.age - .9) / .5).clamp(0.0, 1.0);
    final r = h.size / 2;
    canvas.save();
    canvas.translate(h.at.dx, h.at.dy);
    canvas.rotate(h.angle);
    canvas.clipRect(h.upper ? Rect.fromLTRB(-r * 1.3, -r * 1.3, r * 1.3, 0) : Rect.fromLTRB(-r * 1.3, 0, r * 1.3, r * 1.3));
    canvas.saveLayer(Rect.fromCircle(center: Offset.zero, radius: r * 1.4), Paint()..color = Color.fromRGBO(255, 255, 255, a));
    LsFruitArt.draw(canvas, art: h.art, radius: r, cut: true);
    canvas.restore();
    canvas.restore();
  }

  /// A glowing white streak, thin at its tail.
  void _trail(Canvas canvas) {
    final pts = trail.points;
    if (pts.length < 2) return;
    final n = pts.length;
    for (var i = 1; i < n; i++) {
      final k = i / (n - 1);
      final a = pts[i - 1].$1, b = pts[i].$1;
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = LsTheme.teal.withValues(alpha: .35 * k)
          ..strokeWidth = 4 + 14 * k
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = SliceColors.blade.withValues(alpha: .4 + .6 * k)
          ..strokeWidth = 1.5 + 6 * k
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LsPainter old) => true;
}
