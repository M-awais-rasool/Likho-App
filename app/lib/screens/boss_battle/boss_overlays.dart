import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/tokens.dart';
import '../world_map/boss_painter.dart';
import 'boss_stage.dart';

TextStyle _comic(double size, Color fill) => LikhoFonts.title(size: size, weight: FontWeight.w800, color: fill).copyWith(height: 1);

/// Text with a thick ink outline (comic style).
class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text, {super.key, required this.size, required this.fill, this.stroke = LikhoColors.ink});
  final String text;
  final double size;
  final Color fill, stroke;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Text(
        text,
        textAlign: TextAlign.center,
        style: _comic(size, fill).copyWith(
          color: null,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * .16
            ..strokeJoin = StrokeJoin.round
            ..color = stroke,
        ),
      ),
      Text(text, textAlign: TextAlign.center, style: _comic(size, fill)),
    ],
  );
}

// ================================================================== intro

/// The boss battle's opening, over the whole screen (tap to skip):
/// the screen darkens, a "BOSS BATTLE" stamp slams down, the sleeping boss
/// slides in with its name plate, then "3, 2, 1, WAKE IT UP!".
class BossIntro extends StatelessWidget {
  const BossIntro({super.key, required this.time, required this.start, required this.boss, required this.bossName, required this.theme, required this.onSkip});

  final ValueNotifier<double> time;
  final double start; // clock time it began
  final int boss;
  final String bossName;
  final WorldTheme theme;
  final VoidCallback onSkip;

  /// Seconds the intro lasts; the drum roll starts at [drumAt].
  static const seconds = 4.0, stampAt = .25, drumAt = 1.95;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSkip,
      child: ValueListenableBuilder<double>(
        valueListenable: time,
        builder: (context, now, _) {
          final a = now - start;
          double seg(double from, double len) => ((a - from) / len).clamp(0.0, 1.0);
          final dim = seg(0, .3) * (1 - seg(seconds - .4, .4));
          final stamp = seg(stampAt, .28);
          final bossIn = Curves.easeOutCubic.transform(seg(.75, .55));
          final plate = Curves.easeOutBack.transform(seg(1.25, .35));
          // 3, 2, 1 from 2.0 s, each .45 s, then the call
          final count = a < 2.0 ? null : (a < 3.35 ? 3 - ((a - 2.0) / .45).floor() : 0);
          final countAge = count == null ? 0.0 : (count > 0 ? (a - 2.0) % .45 : a - 3.35);
          return Opacity(
            opacity: dim,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.1),
                  radius: 1.1,
                  colors: [Color.lerp(theme.deep, LikhoColors.ink, .45)!, LikhoColors.ink.withValues(alpha: .97)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // the stamp
                    Opacity(
                      opacity: stamp > 0 ? 1 : 0,
                      child: Transform.rotate(
                        angle: -.12,
                        child: Transform.scale(
                          scale: 1 + 1.8 * (1 - Curves.easeOutBack.transform(stamp)),
                          child: Column(
                            children: [
                              const OutlinedText('BOSS', size: 76, fill: LikhoColors.primary),
                              OutlinedText('BATTLE', size: 38, fill: Colors.white, stroke: theme.deep),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // the sleeping boss slides in
                    Transform.translate(
                      offset: Offset((1 - bossIn) * 420, 0),
                      child: SizedBox(
                        width: 220,
                        height: 183,
                        child: CustomPaint(
                          painter: BossPainter(world: boss, awake: false, time: time),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Transform.scale(
                      scale: plate,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: theme.deep, offset: const Offset(0, 4))],
                        ),
                        child: Text(bossName, style: _comic(22, Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 96,
                      child: count == null
                          ? Opacity(
                              opacity: seg(1.5, .3),
                              child: Text(
                                'Get ready to wake it up!',
                                style: LikhoFonts.body(size: 18, weight: FontWeight.w800, color: Colors.white),
                              ),
                            )
                          : Transform.scale(
                              scale: 1.6 - .6 * Curves.easeOutBack.transform((countAge / .25).clamp(0.0, 1.0)),
                              child: OutlinedText(
                                count > 0 ? '$count' : 'WAKE IT UP!',
                                size: count > 0 ? 84 : 46,
                                fill: count > 0 ? Colors.white : LikhoColors.primary,
                              ),
                            ),
                    ),
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: .6,
                      child: Text(
                        'Tap to skip',
                        style: LikhoFonts.body(size: 13, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================================================================== finale

/// In place of the prompt during the finale: the last move, no question.
class FinalMoveCard extends StatelessWidget {
  const FinalMoveCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [StageSky.comboFrom, StageSky.comboTo]),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: LikhoColors.shadowSoft, offset: Offset(0, 5))],
    ),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.alarm_rounded, size: 34, fill: 1, color: Colors.white),
          const SizedBox(width: 10),
          Text('FINAL MOVE!', style: _comic(28, Colors.white).copyWith(letterSpacing: 1.2)),
        ],
      ),
    ),
  );
}

/// The last move of a boss battle, over the play area: a big alarm clock.
/// Every tap rings it and fills its ring; when it is full the clock bursts,
/// the boss wakes up and a friendly message shows.
class AlarmFinale extends StatelessWidget {
  const AlarmFinale({
    super.key,
    required this.time,
    required this.taps,
    required this.needed,
    required this.lastTapAt,
    required this.rangAt,
    required this.bossName,
    required this.onTap,
  });

  final ValueNotifier<double> time;
  final int taps, needed;
  final double? lastTapAt, rangAt; // clock times
  final String bossName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, _) {
        final rang = rangAt != null;
        final burst = rang ? ((t - rangAt!) / .45).clamp(0.0, 1.0) : 0.0;
        final shakeAge = lastTapAt == null ? 9.0 : t - lastTapAt!;
        final shake = shakeAge < .3 ? math.sin(shakeAge * 70) * .22 * (1 - shakeAge / .3) : math.sin(t * 16) * .03;
        final bounce = rang ? 0.0 : (math.sin(t * 8) * 4).abs();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: rang ? null : (_) => onTap(),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: rang ? const [StageSky.dawnTop, StageSky.dawnBottom] : const [StageSky.nightTop, StageSky.nightBottom],
              ),
              borderRadius: BorderRadius.circular(LikhoRadius.writingPad),
              border: Border.all(color: Colors.white.withValues(alpha: .7), width: 2.5, strokeAlign: BorderSide.strokeAlignInside),
            ),
            child: Column(
              children: [
                const Spacer(),
                if (!rang) ...[
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: OutlinedText('RING THE ALARM!', size: 30, fill: LikhoColors.primary),
                  ),
                  const SizedBox(height: 14),
                ],
                Opacity(
                  opacity: 1 - burst,
                  child: Transform.translate(
                    offset: Offset(0, -bounce),
                    child: Transform.rotate(
                      angle: shake,
                      child: Transform.scale(
                        scale: 1 + burst * .8,
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: CustomPaint(
                            painter: _AlarmClockPainter(progress: taps / needed, t: t),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!rang) ...[
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 1 + .15 * math.sin(t * 9).abs(),
                          child: const Icon(Symbols.touch_app_rounded, size: 30, fill: 1, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tap, tap, tap!',
                          style: LikhoFonts.body(size: 18, weight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Transform.scale(
                    scale: Curves.easeOutBack.transform(((t - rangAt!) / .4).clamp(0.0, 1.0)),
                    child: Column(
                      children: [
                        OutlinedText('$bossName\nis awake!', size: 32, fill: LikhoColors.primary),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: ((t - rangAt! - 1.0) / .4).clamp(0.0, 1.0),
                          child: Text(
                            'You made a new friend!',
                            style: LikhoFonts.body(size: 19, weight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A red twin-bell alarm clock; its face ring fills with [progress] and the
/// hammer buzzes between the bells.
class _AlarmClockPainter extends CustomPainter {
  _AlarmClockPainter({required this.progress, required this.t});
  final double progress, t;

  static const _red = Color(0xFFFF6B6B), _redDeep = Color(0xFFD94C4C), _gold = Color(0xFFFFC83D), _goldDeep = Color(0xFFE0A21A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 180;
    canvas.save();
    canvas.scale(s);
    const c = Offset(90, 100);
    final fill = Paint();
    // legs
    for (final dir in [-1.0, 1.0]) {
      canvas.drawLine(
        c + Offset(dir * 40, 50),
        c + Offset(dir * 56, 74),
        Paint()
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = _redDeep,
      );
    }
    // bells and hammer
    final buzz = math.sin(t * 50) * 6;
    for (final dir in [-1.0, 1.0]) {
      canvas.drawCircle(c + Offset(dir * 46, -60), 24, fill..color = _goldDeep);
      canvas.drawCircle(c + Offset(dir * 46, -63), 21, fill..color = _gold);
    }
    canvas.drawLine(
      c + const Offset(0, -56),
      c + Offset(buzz, -84),
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = _redDeep,
    );
    canvas.drawCircle(c + Offset(buzz, -86), 7, fill..color = _redDeep);
    // body and face
    canvas.drawCircle(c + const Offset(0, 5), 66, fill..color = _redDeep);
    canvas.drawCircle(c, 66, fill..color = _red);
    canvas.drawCircle(c, 52, fill..color = Colors.white);
    // the tap ring
    canvas.drawCircle(
      c,
      45,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = LikhoColors.inkFaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 45),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = StageSky.comboFrom,
    );
    // hands
    final hand = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = LikhoColors.ink;
    canvas.drawLine(c, c + const Offset(0, -28), hand);
    canvas.drawLine(c, c + Offset(math.cos(t * 4) * 20, math.sin(t * 4) * 20), hand..strokeWidth = 4);
    canvas.drawCircle(c, 6, fill..color = LikhoColors.ink);
    // shine
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(-30, -40), width: 24, height: 12), fill..color = Colors.white.withValues(alpha: .5));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AlarmClockPainter old) => true;
}
