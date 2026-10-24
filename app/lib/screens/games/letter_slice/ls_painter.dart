import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../design/tokens.dart';
import '../../../game/letter_slice/ls_engine.dart';
import 'ls_scene.dart';

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

/// Pencil's pose this frame, with a little hop.
class LsPencil {
  const LsPencil(this.pose, {this.hop = 0});
  final String pose;
  final double hop;
}

/// Paints the board's life: the juice stains, Pencil in his corner, the
/// fruits (spinning, their letters upright), the halves of the sliced ones
/// and the blade's glowing trail.
class LsPainter extends CustomPainter {
  LsPainter({
    required this.view,
    required this.game,
    required this.halves,
    required this.splats,
    required this.trail,
    required this.pencil,
    required this.time,
  });
  final LsView view;
  final LsGame game;
  final List<LsHalf> halves;
  final List<LsSplat> splats;
  final LsTrail trail;
  final LsPencil pencil;
  final double time;

  static final _letters = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in splats) {
      _splat(canvas, s);
    }
    _pencil(canvas, size);
    for (final h in halves) {
      _half(canvas, h);
    }
    final glow = game.dropped >= 2;
    for (final f in game.flying) {
      if (!f.cut) _fruit(canvas, f, glow && f.letter == game.need && !f.bounced);
    }
    _trail(canvas);
  }

  void _image(Canvas canvas, String asset, Rect dst, {double alpha = 1}) {
    final img = LsSprites.of(asset);
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, alpha),
    );
  }

  void _splat(Canvas canvas, LsSplat s) {
    final age = time - s.born;
    final a = (1 - age / 4).clamp(0.0, 1.0) * .55;
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

  void _pencil(Canvas canvas, Size size) {
    final asset = LsArt.pencil(pencil.pose);
    final img = LsSprites.of(asset);
    if (img == null) return;
    final h = (size.height * .16).clamp(100.0, 170.0);
    final w = h * img.width / img.height;
    // in the bottom-left corner, a little cut off by the edge
    _image(canvas, asset, Rect.fromLTWH(-w * .12, size.height - h * .92 - pencil.hop, w, h), alpha: .95);
  }

  void _fruit(Canvas canvas, LsFruit f, bool glow) {
    final c = view.at(f.x, f.y);
    final r = f.r * view.scale;
    // it pops as it appears
    final age = game.time - f.born;
    final pop = age < .25 ? .7 + .3 * math.sin(age / .25 * math.pi / 2) : 1.0;
    if (glow) {
      final k = .5 + .5 * math.sin(time * 8);
      canvas.drawCircle(
        c,
        r * (1.15 + .08 * k),
        Paint()
          ..color = MonsterColors.hintGlow.withValues(alpha: .5 + .3 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    // a soft shadow below it
    canvas.drawCircle(c + Offset(0, r * .12), r * .95, Paint()..color = SliceColors.shadow);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-f.angle);
    canvas.scale(pop);
    // the pictures have a margin around the fruit
    final side = r * 2 / .8;
    _image(
      canvas,
      LsArt.whole(f.art),
      Rect.fromCenter(center: Offset.zero, width: side, height: side),
      alpha: f.bounced ? .8 : 1,
    );
    canvas.restore();
    final l = f.letter;
    if (l == null) return;
    // the letter on a round sticker, always upright
    final br = r * .5 * pop;
    final at = c + Offset(0, r * .28);
    canvas.drawCircle(at + const Offset(0, 2), br, Paint()..color = SliceColors.shadow);
    canvas.drawCircle(at, br, Paint()..color = f.bounced ? SliceColors.stickerOff : SliceColors.sticker);
    canvas.drawCircle(
      at,
      br,
      Paint()
        ..color = SliceColors.stickerEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final tp = _letter(l, br * 1.45);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2 + br * .04));
  }

  TextPainter _letter(String l, double size) => _letters.putIfAbsent(
    '$l ${size.round()}',
    () => TextPainter(
      text: TextSpan(
        text: l,
        style: LikhoFonts.letter(size: size, color: SliceColors.ink).copyWith(height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  void _half(Canvas canvas, LsHalf h) {
    final img = LsSprites.of(LsArt.cut(h.art));
    if (img == null) return;
    final a = (1 - (h.age - .9) / .5).clamp(0.0, 1.0);
    final side = h.size / .8;
    canvas.save();
    canvas.translate(h.at.dx, h.at.dy);
    canvas.rotate(h.angle);
    // the cut runs along the local x axis: one half above it, one below
    canvas.clipRect(h.upper ? Rect.fromLTRB(-side, -side, side, 0) : Rect.fromLTRB(-side, 0, side, side));
    _image(
      canvas,
      LsArt.cut(h.art),
      Rect.fromCenter(center: Offset.zero, width: side, height: side),
      alpha: a,
    );
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
          ..color = SliceColors.bladeGlow.withValues(alpha: .35 * k)
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
