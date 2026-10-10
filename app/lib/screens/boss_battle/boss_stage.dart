import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/tokens.dart';
import '../world_map/boss_painter.dart';
import 'battle_state.dart';

/// Colours of the boss stage's sky, night -> sunrise -> morning. The same
/// in every world (the ground and the boss carry the world), so waking a
/// boss always looks like bringing the morning.
abstract final class StageSky {
  static const nightTop = Color(0xFF1B1F4B), nightBottom = Color(0xFF3A3D78);
  static const dawnTop = Color(0xFF7466B5), dawnBottom = Color(0xFFFFA48A);
  static const dayTop = Color(0xFF9ED8FF), dayBottom = Color(0xFFFFF4DC);
  static const nightTint = Color(0xFF2A2D5C);
  static const moon = Color(0xFFFFF3C4), sun = Color(0xFFFFC83D), sunGlow = Color(0x66FFD45C);
  static const meterFrom = Color(0xFF5B5FC7), meterTo = Color(0xFF8E7BEF);
  static const comboFrom = Color(0xFFFF8A3D), comboTo = Color(0xFFFF4F8B);
  static const zzz = Color(0xFFB9A8FF);

  static Color top(double dawn) => dawn < .5 ? Color.lerp(nightTop, dawnTop, dawn * 2)! : Color.lerp(dawnTop, dayTop, dawn * 2 - 1)!;
  static Color bottom(double dawn) => dawn < .5 ? Color.lerp(nightBottom, dawnBottom, dawn * 2)! : Color.lerp(dawnBottom, dayBottom, dawn * 2 - 1)!;
}

/// Comic words for wake-up hits, in turn.
const _hitWords = ['BONK!', 'DING!', 'POW!', 'RING!', 'BOING!', 'ZAP!'];

/// The boss arena's stage: a sky that turns from night to morning as the
/// boss's sleep runs out, a moon setting and a sun rising, the world's hills,
/// Pencil on the left facing the big boss on the right. Hits make the boss
/// startle, burst into stars with a comic word and shake the stage; a miss
/// makes it snore "Zzz". The combo badge and the phase banner live here.
class BossStage extends StatelessWidget {
  const BossStage({
    super.key,
    required this.battle,
    required this.theme,
    required this.boss,
    required this.time,
    required this.pencil,
    required this.pencilKey,
    required this.bossKey,
    this.bubble,
  });

  final BossBattle battle;
  final WorldTheme theme;
  final int boss; // BossPainter.indexOf(bossId)
  final ValueNotifier<double> time;
  final Widget pencil;
  final GlobalKey pencilKey, bossKey;
  final Widget? bubble;

  /// Where the boss stands in a stage of [size] (art is 120 x 100).
  static Rect bossRect(Size size) {
    final w = math.min(size.width * .5, size.height * 1.02);
    final h = w * 100 / 120;
    return Rect.fromLTWH(size.width - w - 4, size.height - h - 4, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final br = bossRect(size);
          return TweenAnimationBuilder<double>(
            tween: Tween(end: 1 - battle.sleep),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (context, dawn, _) => ValueListenableBuilder<double>(
              valueListenable: time,
              builder: (context, t, _) {
                final hitAge = battle.hitAt == null ? 99.0 : t - battle.hitAt!;
                // the stage jolts when a hit lands
                final jolt = hitAge < .35 ? math.sin(hitAge * 60) * (1 - hitAge / .35) * (battle.bigHit ? 7 : 4) : 0.0;
                final awake = battle.wokeAt != null && t >= battle.wokeAt!;
                // restless in the last phase: tossing and turning
                final toss = !awake && battle.phase == 2 ? math.sin(t * 2.6) * .045 : 0.0;
                return Transform.translate(
                  offset: Offset(jolt, 0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SkyPainter(dawn: dawn, theme: theme, t: t),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 2,
                        width: 84,
                        height: 112,
                        child: SizedBox(key: pencilKey, child: pencil),
                      ),
                      Positioned.fromRect(
                        rect: br,
                        child: Transform.rotate(
                          angle: toss,
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            key: bossKey,
                            child: CustomPaint(
                              painter: BossPainter(
                                world: boss,
                                awake: battle.wokeAt != null,
                                dance: true,
                                danceFor: 60,
                                wokeAt: battle.wokeAt,
                                dozing: battle.phase >= 1,
                                pokedAt: battle.hitAt,
                                time: time,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _ImpactPainter(battle: battle, t: t, boss: br),
                          ),
                        ),
                      ),
                      if (bubble != null)
                        Positioned(
                          left: 84,
                          top: 10,
                          right: br.width * .55,
                          child: Align(alignment: Alignment.topLeft, child: bubble),
                        ),
                      if (battle.combo >= 2) Positioned(top: 10, right: 12, child: ComboBadge(combo: battle.combo)),
                      if (battle.phaseAt != null && t - battle.phaseAt! < 2.0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _PhaseBanner(phase: battle.phase, age: t - battle.phaseAt!),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.dawn, required this.theme, required this.t});
  final double dawn, t;
  final WorldTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [StageSky.top(dawn), StageSky.bottom(dawn)],
        ).createShader(rect),
    );
    // stars fade out by sunrise
    final starAlpha = (1 - dawn * 1.9).clamp(0.0, 1.0);
    if (starAlpha > 0) {
      var s = 7;
      double rnd() {
        s = (s * 9301 + 49297) % 233280;
        return s / 233280;
      }

      for (var k = 0; k < 22; k++) {
        final x = rnd() * w, y = rnd() * h * .6, r = .8 + rnd() * 1.6, ph = rnd() * 6;
        final tw = .55 + .45 * math.sin(t * 2.2 + ph);
        canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: starAlpha * tw));
      }
    }
    // the moon sets, the sun rises behind the hills
    final moonA = (1 - dawn * 1.4).clamp(0.0, 1.0);
    if (moonA > 0) {
      final c = Offset(w * .36, h * (.2 + dawn * .55));
      canvas.drawCircle(c, 17, Paint()..color = StageSky.moon.withValues(alpha: moonA));
      canvas.drawCircle(c + const Offset(7, -5), 14, Paint()..color = StageSky.top(dawn).withValues(alpha: moonA));
    }
    final sunA = (dawn * 2.2).clamp(0.0, 1.0);
    if (sunA > 0) {
      final c = Offset(w * .44, h * (.86 - dawn * .62));
      canvas.drawCircle(c, 34 + 4 * math.sin(t * 2), Paint()..color = StageSky.sunGlow.withValues(alpha: .5 * sunA));
      canvas.drawCircle(c, 22, Paint()..color = StageSky.sun.withValues(alpha: sunA));
    }
    // the world's hills, in night shade until morning
    final shade = (1 - dawn) * .55;
    Color tint(Color c) => Color.lerp(c, StageSky.nightTint, shade)!;
    final far = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w + 6; x += 6) {
      far.lineTo(x, h * .7 - 12 * math.sin(x / w * 2.4 * math.pi + .6));
    }
    far
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(far, Paint()..color = tint(theme.soft));
    final near = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w + 6; x += 6) {
      near.lineTo(x, h * .86 - 8 * math.sin(x / w * 1.6 * math.pi + 2));
    }
    near
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(near, Paint()..color = tint(Color.lerp(theme.soft, theme.accent, .3)!));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.dawn != dawn || old.t != t || old.theme != theme;
}

/// Stars bursting off the boss and a comic word when a hit lands; a sleepy
/// "Zzz" floating up when an answer misses.
class _ImpactPainter extends CustomPainter {
  _ImpactPainter({required this.battle, required this.t, required this.boss});
  final BossBattle battle;
  final double t;
  final Rect boss;

  @override
  void paint(Canvas canvas, Size size) {
    final c = boss.center - Offset(0, boss.height * .1);
    final hit = battle.hitAt;
    if (hit != null && t - hit < .8 && t >= hit) {
      final a = (t - hit) / .8;
      final big = battle.bigHit;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - a)
        ..color = Colors.white.withValues(alpha: 1 - a);
      canvas.drawCircle(c, 20 + a * (big ? 110 : 70), ring);
      final n = big ? 14 : 9;
      for (var k = 0; k < n; k++) {
        final ang = k * 2 * math.pi / n + battle.hitNumber;
        final d = 18 + Curves.easeOut.transform(a) * (big ? 95 : 60);
        final p = c + Offset(math.cos(ang), math.sin(ang)) * d;
        _star(canvas, p, (big ? 9 : 6) * (1 - a * .6), [LikhoColors.primary, StageSky.comboTo, Colors.white][k % 3].withValues(alpha: 1 - a));
      }
      // the comic word pops over the boss
      final pop = a < .2 ? Curves.easeOutBack.transform(a / .2) : 1.0;
      final word = _hitWords[(battle.hitNumber - 1) % _hitWords.length];
      _label(canvas, word, Offset(boss.center.dx, boss.top + 6 - a * 14), (big ? 30 : 24) * pop, LikhoColors.primary, (1 - (a - .6) / .4).clamp(0.0, 1.0));
    }
    final miss = battle.missAt;
    if (miss != null && t - miss < 1.4 && t >= miss) {
      final a = (t - miss) / 1.4;
      for (var k = 0; k < 3; k++) {
        final ak = (a - k * .12).clamp(0.0, 1.0);
        if (ak <= 0) continue;
        _label(
          canvas,
          'Z',
          Offset(boss.left + boss.width * .3 - k * 14 - ak * 20, boss.top + 10 - ak * 50 - k * 12),
          18 + k * 6.0,
          StageSky.zzz,
          (1 - ak).clamp(0.0, 1.0),
        );
      }
    }
  }

  static void _star(Canvas canvas, Offset c, double r, Color col) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * .45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final q = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = col);
  }

  static void _label(Canvas canvas, String text, Offset centre, double size, Color fill, double alpha) {
    if (size <= 1 || alpha <= 0) return;
    final style = LikhoFonts.title(size: size, weight: FontWeight.w800);
    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * .16
            ..strokeJoin = StrokeJoin.round
            ..color = LikhoColors.ink.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final body = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: fill.withValues(alpha: alpha)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final o = centre - Offset(body.width / 2, body.height / 2);
    stroke.paint(canvas, o);
    body.paint(canvas, o);
  }

  @override
  bool shouldRepaint(_ImpactPainter old) => true;
}

/// "x3 COMBO!": rounds won in a row without a mistake.
class ComboBadge extends StatelessWidget {
  const ComboBadge({super.key, required this.combo});
  final int combo;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(combo),
      tween: Tween(begin: 1.6, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 12, 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [StageSky.comboFrom, StageSky.comboTo]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: LikhoColors.shadowSoft, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.local_fire_department_rounded, size: 18, fill: 1, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              'x$combo',
              style: LikhoFonts.title(size: 18, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1.1),
            ),
            const SizedBox(width: 4),
            Text(
              'COMBO',
              style: LikhoFonts.body(size: 10, weight: FontWeight.w800, color: Colors.white).copyWith(letterSpacing: 1.1, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.phase, required this.age});
  final int phase;
  final double age;

  @override
  Widget build(BuildContext context) {
    final inK = Curves.easeOutBack.transform((age / .35).clamp(0.0, 1.0));
    final out = ((age - 1.6) / .4).clamp(0.0, 1.0);
    final title = 'PHASE ${phase + 1}';
    final sub = phase == 1 ? "It's stirring!" : 'Almost awake!';
    return Center(
      child: Opacity(
        opacity: 1 - out,
        child: Transform.scale(
          scale: .4 + .6 * inK,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            decoration: BoxDecoration(
              color: LikhoColors.ink.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: LikhoColors.primary, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: LikhoFonts.title(size: 28, weight: FontWeight.w800, color: LikhoColors.primary).copyWith(height: 1.1, letterSpacing: 1.5),
                ),
                Text(
                  sub,
                  style: LikhoFonts.body(size: 15, weight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The boss's sleep meter (its "health bar"): the boss's name, a moon, the
/// bar of sleep left with the three phases marked, and the sun it runs to.
class SleepMeter extends StatelessWidget {
  const SleepMeter({super.key, required this.battle, required this.bossName, this.dark = false});
  final BossBattle battle;
  final String bossName;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : LikhoColors.ink;
    return ListenableBuilder(
      listenable: battle,
      builder: (context, _) => Row(
        children: [
          const _MeterIcon(icon: Symbols.bedtime_rounded, color: StageSky.meterFrom),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bossName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LikhoFonts.body(size: 11, weight: FontWeight.w800, color: ink.withValues(alpha: .75)).copyWith(letterSpacing: 1.1, height: 1.2),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 16,
                  child: LayoutBuilder(
                    builder: (context, box) => TweenAnimationBuilder<double>(
                      tween: Tween(end: battle.sleep),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(color: ink.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
                          ),
                          Container(
                            width: math.max(0, box.maxWidth * v),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [StageSky.meterFrom, StageSky.meterTo]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 6),
                            child: v > .12
                                ? Text(
                                    'zzz',
                                    style: LikhoFonts.body(size: 10, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1),
                                  )
                                : null,
                          ),
                          for (final f in const [1 / 3, 2 / 3])
                            Positioned(
                              left: box.maxWidth * f - 1,
                              top: 2,
                              bottom: 2,
                              width: 2,
                              child: ColoredBox(color: Colors.white.withValues(alpha: .7)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _MeterIcon(icon: Symbols.wb_sunny_rounded, color: battle.sleep <= 0 ? LikhoColors.primary : LikhoColors.primary.withValues(alpha: .55)),
        ],
      ),
    );
  }
}

class _MeterIcon extends StatelessWidget {
  const _MeterIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: LikhoColors.shadowSoft, offset: Offset(0, 2))],
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: 19, fill: 1, color: color),
  );
}

/// A wake-up shot on its way from the play area to the boss.
class Shot {
  Shot({required this.from, required this.to, required this.start, required this.kind, required this.big, this.label});
  final Offset from, to; // in the shot layer
  final double start; // clock time
  final ShotKind kind;
  final bool big;
  final String? label; // the letter of a letter shot

  static const seconds = .5;
}

/// Draws the shots flying in an arc, with a sparkly (rainbow for combo) trail.
class ShotPainter extends CustomPainter {
  ShotPainter({required this.shots, required this.t});
  final List<Shot> shots;
  final double t;

  static const _rainbow = [Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFD43B), Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFF9775FA)];

  Offset _at(Shot s, double p) {
    final q = Offset.lerp(s.from, s.to, p)!;
    return q - Offset(0, 140 * 4 * p * (1 - p) * (s.big ? 1.2 : 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in shots) {
      final p = (t - s.start) / Shot.seconds;
      if (p < 0 || p > 1) continue;
      final e = Curves.easeIn.transform(p);
      for (var k = 1; k <= 8; k++) {
        final pk = Curves.easeIn.transform((p - k * .035).clamp(0.0, 1.0));
        final col = s.big ? _rainbow[k % _rainbow.length] : Colors.white;
        canvas.drawCircle(_at(s, pk), (s.big ? 9 : 6) * (1 - k / 9), Paint()..color = col.withValues(alpha: .8 * (1 - k / 9)));
      }
      final c = _at(s, e);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(p * math.pi * 2);
      canvas.scale(s.big ? 1.5 : 1.1);
      _draw(canvas, s);
      canvas.restore();
    }
  }

  static void _draw(Canvas c, Shot s) {
    final white = Paint()..color = Colors.white;
    switch (s.kind) {
      case ShotKind.star:
        _ImpactPainter._star(c, Offset.zero, 15, Colors.white);
        _ImpactPainter._star(c, Offset.zero, 12, LikhoColors.primary);
      case ShotKind.bell:
        final body = Path()
          ..moveTo(-11, 8)
          ..quadraticBezierTo(-11, -12, 0, -12)
          ..quadraticBezierTo(11, -12, 11, 8)
          ..close();
        c.drawPath(body, Paint()..color = LikhoColors.primary);
        c.drawRRect(RRect.fromLTRBR(-13, 6, 13, 10, const Radius.circular(2)), Paint()..color = LikhoColors.primaryDeep);
        c.drawCircle(const Offset(0, 12), 3.5, Paint()..color = LikhoColors.primaryDeep);
      case ShotKind.pillow:
        final r = RRect.fromLTRBR(-16, -11, 16, 11, const Radius.circular(9));
        c.drawRRect(r, Paint()..color = const Color(0xFFE9E3FF));
        c.drawRRect(
          r.deflate(3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0xFFB9A8FF),
        );
      case ShotKind.bubble:
        c.drawCircle(Offset.zero, 13, Paint()..color = const Color(0x8899D8FF));
        c.drawCircle(
          Offset.zero,
          13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white,
        );
        c.drawCircle(const Offset(-4, -5), 3.5, white);
      case ShotKind.letter:
        final tp = TextPainter(
          text: TextSpan(
            text: s.label ?? '?',
            style: LikhoFonts.letter(size: 26, color: Colors.white).copyWith(
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Color(0xFFB9A8FF), blurRadius: 10)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      case ShotKind.wave:
        for (var k = 0; k < 3; k++) {
          c.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: 6.0 + k * 6),
            -math.pi * .8,
            math.pi * .6,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 3
              ..color = Colors.white,
          );
        }
      case ShotKind.sun:
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4;
          c.drawLine(
            Offset(math.cos(a), math.sin(a)) * 12,
            Offset(math.cos(a), math.sin(a)) * 17,
            Paint()
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round
              ..color = LikhoColors.primary,
          );
        }
        c.drawCircle(Offset.zero, 10, Paint()..color = LikhoColors.primary);
    }
  }

  @override
  bool shouldRepaint(ShotPainter old) => true;
}
