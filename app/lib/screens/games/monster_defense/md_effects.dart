import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// Monster Defense's effects, painted over the scene: Pencil's magic beam,
/// the bubbles, sparkles, confetti and score numbers ([MdBit]), the frost
/// of Freeze and the glow at the edges when a monster is close.

/// A flying bit: a sparkle, a confetti piece or a score number.
class MdBit {
  MdBit({required this.at, required this.v, required this.life, required this.color, this.size = 8, this.kind = MdBitKind.spark, this.text, this.gravity = 0, this.spin = 0});
  Offset at, v;
  double age = 0;
  final double life, size, gravity, spin;
  final Color color;
  final MdBitKind kind;
  final String? text;

  bool get done => age >= life;
  double get left => (1 - age / life).clamp(0.0, 1.0);

  void step(double dt) {
    age += dt;
    v += Offset(0, gravity * dt);
    at += v * dt;
  }

  /// A ring of sparkles around [c].
  static List<MdBit> burst(Offset c, math.Random r, {int n = 14, double speed = 220, List<Color> colors = const [MonsterColors.spark, MonsterColors.magic, MonsterColors.magicCore]}) => [
    for (var k = 0; k < n; k++)
      () {
        final a = 2 * math.pi * k / n + r.nextDouble() * .4;
        final s = speed * (.55 + r.nextDouble() * .6);
        return MdBit(at: c, v: Offset(math.cos(a), math.sin(a)) * s, life: .55 + r.nextDouble() * .35, color: colors[k % colors.length], size: 6 + r.nextDouble() * 7, gravity: 260);
      }(),
  ];

  /// Confetti raining down over the width [w].
  static List<MdBit> confetti(double w, math.Random r, {int n = 60}) => [
    for (var k = 0; k < n; k++)
      MdBit(
        at: Offset(r.nextDouble() * w, -20 - r.nextDouble() * 200),
        v: Offset((r.nextDouble() - .5) * 80, 120 + r.nextDouble() * 160),
        life: 3 + r.nextDouble() * 1.5,
        color: MonsterColors.confetti[k % MonsterColors.confetti.length],
        size: 7 + r.nextDouble() * 6,
        kind: MdBitKind.confetti,
        gravity: 40,
        spin: (r.nextDouble() - .5) * 12,
      ),
  ];

  /// "+150" rising from [c].
  static MdBit score(Offset c, int points) => MdBit(at: c, v: const Offset(0, -70), life: 1.1, color: MonsterColors.score, kind: MdBitKind.text, text: '+$points', size: 26);
}

enum MdBitKind { spark, confetti, text }

/// Pencil's magic flying to a monster: a glowing arc from [from] to [to]
/// that lands after [fly] seconds and fades.
class MdBeam {
  MdBeam(this.from, this.to);
  final Offset from, to;
  double age = 0;
  static const fly = .3, life = .55;
  bool get done => age >= life;
}

class MdEffectsPainter extends CustomPainter {
  MdEffectsPainter({required this.bits, required this.beams, required this.bubbles, required this.time, super.repaint});
  final List<MdBit> bits;
  final List<MdBeam> beams;

  /// Bubbles to draw: (centre, radius, 0..1 how formed, wobble seed).
  final List<(Offset, double, double, int)> bubbles;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      paintBubble(canvas, b.$1, b.$2, b.$3, time + b.$4);
    }
    for (final b in beams) {
      _beam(canvas, b);
    }
    for (final b in bits) {
      _bit(canvas, b);
    }
  }

  static Offset _arc(Offset a, Offset b, double t) {
    // a curve bending up and over to the monster
    final mid = Offset.lerp(a, b, .5)! + Offset(0, -math.min(160.0, (b - a).distance * .35));
    final u = 1 - t;
    return a * (u * u) + mid * (2 * u * t) + b * (t * t);
  }

  void _beam(Canvas canvas, MdBeam b) {
    final head = (b.age / MdBeam.fly).clamp(0.0, 1.0);
    final fade = b.age < MdBeam.fly ? 1.0 : (1 - (b.age - MdBeam.fly) / (MdBeam.life - MdBeam.fly)).clamp(0.0, 1.0);
    final tail = (head - .45).clamp(0.0, 1.0);
    final path = Path();
    const steps = 24;
    for (var k = 0; k <= steps; k++) {
      final p = _arc(b.from, b.to, tail + (head - tail) * k / steps);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = MonsterColors.magicGlow.withValues(alpha: .55 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = MonsterColors.magic.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = MonsterColors.magicCore.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // the star at its head
    final p = _arc(b.from, b.to, head);
    paintStar(canvas, p, 13 * (b.age < MdBeam.fly ? 1 : fade), MonsterColors.spark, b.age * 9);
  }

  void _bit(Canvas canvas, MdBit b) {
    final a = b.left;
    switch (b.kind) {
      case MdBitKind.spark:
        paintStar(canvas, b.at, b.size * (.4 + .6 * a), b.color.withValues(alpha: a), b.age * 6);
      case MdBitKind.confetti:
        canvas.save();
        canvas.translate(b.at.dx, b.at.dy);
        canvas.rotate(b.age * b.spin);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * .55), const Radius.circular(2)),
          Paint()..color = b.color.withValues(alpha: math.min(1, a * 3)),
        );
        canvas.restore();
      case MdBitKind.text:
        final grow = Curves.elasticOut.transform((b.age / .45).clamp(0.0, 1.0));
        final tp = TextPainter(
          text: TextSpan(
            text: b.text,
            style:
                LikhoFonts.title(
                  size: b.size * (.6 + .4 * grow),
                  weight: FontWeight.w800,
                  color: b.color.withValues(alpha: a),
                ).copyWith(
                  shadows: [
                    Shadow(
                      color: MonsterColors.scoreEdge.withValues(alpha: a),
                      offset: const Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, b.at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(MdEffectsPainter old) => true;
}

/// A five-point star.
void paintStar(Canvas canvas, Offset c, double r, Color color, double turn) {
  if (r <= .5) return;
  final path = Path();
  for (var k = 0; k < 10; k++) {
    final rr = k.isEven ? r : r * .45;
    final a = turn + math.pi * k / 5 - math.pi / 2;
    final p = c + Offset(math.cos(a), math.sin(a)) * rr;
    k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path..close(), Paint()..color = color);
}

/// Pencil's magic bubble: see-through, a bright rim, a shine, wobbling as
/// it floats. [formed] grows it from a ring of sparkles (0) to whole (1).
void paintBubble(Canvas canvas, Offset c, double r, double formed, double time) {
  if (formed <= 0) return;
  final f = Curves.easeOutBack.transform(formed.clamp(0.0, 1.0));
  final wob = math.sin(time * 7) * .035 * f;
  final rect = Rect.fromCenter(center: c, width: 2 * r * f * (1 + wob), height: 2 * r * f * (1 - wob));
  canvas.drawOval(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.3, -.35),
        radius: .9,
        colors: [MonsterColors.bubble.withValues(alpha: .05), MonsterColors.bubble, MonsterColors.bubbleTint.withValues(alpha: .45)],
        stops: const [0, .7, 1],
      ).createShader(rect),
  );
  canvas.drawOval(
    rect,
    Paint()
      ..color = MonsterColors.bubbleRim
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, r * .05),
  );
  // the shine
  final s = Rect.fromCenter(center: c + Offset(-r * .42, -r * .45) * f, width: r * .42 * f, height: r * .24 * f);
  canvas.save();
  canvas.translate(s.center.dx, s.center.dy);
  canvas.rotate(-.6);
  canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s.width, height: s.height), Paint()..color = MonsterColors.magicCore.withValues(alpha: .85));
  canvas.restore();
  canvas.drawCircle(c + Offset(r * .5, r * .42) * f, r * .07 * f, Paint()..color = MonsterColors.magicCore.withValues(alpha: .7));
}

/// Big Bonk's golden crown, filling its box.
class MdCrownPainter extends CustomPainter {
  const MdCrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path()
      ..moveTo(w * .06, h * .95)
      ..lineTo(0, h * .28)
      ..lineTo(w * .28, h * .58)
      ..lineTo(w * .5, h * .05)
      ..lineTo(w * .72, h * .58)
      ..lineTo(w, h * .28)
      ..lineTo(w * .94, h * .95)
      ..close();
    canvas.drawPath(body, Paint()..color = MonsterColors.gold);
    canvas.drawRect(Rect.fromLTRB(w * .06, h * .74, w * .94, h * .95), Paint()..color = MonsterColors.goldDeep.withValues(alpha: .35));
    canvas.drawPath(
      body,
      Paint()
        ..color = MonsterColors.goldDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, w * .035)
        ..strokeJoin = StrokeJoin.round,
    );
    for (final (x, y) in [(0.0, .28), (.5, .05), (1.0, .28)]) {
      canvas.drawCircle(Offset(w * x, h * y), w * .07, Paint()..color = MonsterColors.gold);
      canvas.drawCircle(
        Offset(w * x, h * y),
        w * .07,
        Paint()
          ..color = MonsterColors.goldDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, w * .025),
      );
    }
    canvas.drawCircle(Offset(w * .5, h * .78), w * .08, Paint()..color = MonsterColors.gem);
    canvas.drawCircle(Offset(w * .24, h * .8), w * .055, Paint()..color = MonsterColors.gemBlue);
    canvas.drawCircle(Offset(w * .76, h * .8), w * .055, Paint()..color = MonsterColors.gemBlue);
  }

  @override
  bool shouldRepaint(MdCrownPainter old) => false;
}

/// The frost of Freeze over the whole scene ([v] 0..1 fades it).
class MdFrostPainter extends CustomPainter {
  const MdFrostPainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v <= 0) return;
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = MonsterColors.ice.withValues(alpha: MonsterColors.ice.a * v));
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          radius: .95,
          colors: [
            MonsterColors.iceEdge.withValues(alpha: 0),
            MonsterColors.iceEdge.withValues(alpha: .75 * v),
          ],
          stops: const [.55, 1],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(MdFrostPainter old) => old.v != v;
}

/// The edges glow (softly, never red) while a monster is close; [v] 0..1
/// (it beats with the heart).
class MdDangerPainter extends CustomPainter {
  const MdDangerPainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v <= 0) return;
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          radius: .9,
          colors: [
            MonsterColors.danger.withValues(alpha: 0),
            MonsterColors.danger.withValues(alpha: MonsterColors.danger.a * v),
          ],
          stops: const [.6, 1],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(MdDangerPainter old) => old.v != v;
}

/// A balloon of Big Bonk's with a choice on it, its string down to [string]
/// (relative to the balloon's box; none when null).
class MdBalloonPainter extends CustomPainter {
  const MdBalloonPainter({required this.color, required this.edge, required this.string, required this.glow});
  final Color color, edge;
  final Offset? string;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final knot = Offset(w / 2, h * .96), to = string;
    if (to != null) {
      canvas.drawPath(
        Path()
          ..moveTo(knot.dx, knot.dy)
          ..quadraticBezierTo(knot.dx + 10, (knot.dy + to.dy) / 2, to.dx, to.dy),
        Paint()
          ..color = MonsterColors.string
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final body = Rect.fromLTWH(0, 0, w, h * .9);
    if (glow > 0) {
      canvas.drawOval(
        body.inflate(10 * glow),
        Paint()
          ..color = MonsterColors.hintGlow.withValues(alpha: .8 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawOval(body, Paint()..color = color);
    canvas.drawOval(
      body,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w / 2 - 7, h * .9 + 6)
        ..lineTo(w / 2 + 7, h * .9 + 6)
        ..lineTo(w / 2, h * .89)
        ..close(),
      Paint()..color = edge,
    );
    canvas.save();
    canvas.translate(w * .3, h * .22);
    canvas.rotate(-.5);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * .2, height: h * .1), Paint()..color = MonsterColors.magicCore.withValues(alpha: .55));
    canvas.restore();
  }

  @override
  bool shouldRepaint(MdBalloonPainter old) => old.glow != glow || old.string != string || old.color != color;
}
