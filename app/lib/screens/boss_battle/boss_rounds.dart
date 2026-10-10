import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/course_models.dart';
import '../../design/tokens.dart';
import '../../game/level_session.dart';
import '../gameplay/rounds/pick_round_view.dart';
import '../gameplay/widgets/game_buttons.dart';
import '../gameplay/widgets/illustration.dart';
import 'boss_stage.dart';

/// Colours of the boss rounds' "dream" fields.
abstract final class DreamColors {
  static const nightTop = Color(0xFF2B2F63), nightBottom = Color(0xFF4A4590);
  static const lightTop = Color(0xFFEDE8FF), lightBottom = Color(0xFFFFFFFF);
  static const pillows = [Color(0xFFF4F0FF), Color(0xFFE3F6EE), Color(0xFFFFEBDD), Color(0xFFE2F1FF)];
  static const stitch = Color(0x669B8BD6);
  static const bubble = Color(0x6699D8FF), bubbleRim = Color(0xCCFFFFFF);
  static const moonButton = Color(0xFF3A3D78), moonEdge = Color(0xFF262959);
}

double dreamPulse(double t) => const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t % 1.0) - 1).abs());

TextStyle dreamLetter(double s, Color c) => LikhoFonts.letter(size: s, color: c).copyWith(fontWeight: FontWeight.w700, height: 1);

/// A rounded "dream" field behind a boss round: night blue or soft lavender.
class DreamField extends StatelessWidget {
  const DreamField({super.key, required this.child, this.night = false, this.correct = false, this.time});
  final Widget child;
  final bool night, correct;
  final ValueNotifier<double>? time;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(LikhoRadius.writingPad);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: night ? const [DreamColors.nightTop, DreamColors.nightBottom] : const [DreamColors.lightTop, DreamColors.lightBottom],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .7), width: 2.5, strokeAlign: BorderSide.strokeAlignInside),
            ),
          ),
        ),
        if (night && time != null)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: r,
              child: CustomPaint(painter: _DreamStars(time!)),
            ),
          ),
        Positioned.fill(
          child: ClipRRect(borderRadius: r, child: child),
        ),
        if (correct) const Positioned.fill(child: CorrectGlow()),
      ],
    );
  }
}

class _DreamStars extends CustomPainter {
  _DreamStars(this.time) : super(repaint: time);
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    var s = 3;
    double rnd() {
      s = (s * 9301 + 49297) % 233280;
      return s / 233280;
    }

    for (var k = 0; k < 26; k++) {
      final p = Offset(rnd() * size.width, rnd() * size.height);
      final a = .25 + .5 * (.5 + .5 * math.sin(time.value * 2 + rnd() * 6));
      canvas.drawCircle(p, .8 + rnd() * 1.4, Paint()..color = Colors.white.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_DreamStars old) => false;
}

// ================================================================== pillow fight

/// Boss "pick" rounds: the sleepy boss tosses pillows, one answer on each.
/// They tumble down from the boss and land in front of Pencil; tap the right
/// pillow and it flies back up at the boss. A wrong pillow goes flat with a
/// puff of feathers. After a mistake the right pillow glows.
class PillowFightView extends StatefulWidget {
  const PillowFightView({super.key, required this.state, required this.round, required this.onPick, required this.time});
  final SessionState state;
  final PickRound round;
  final ValueChanged<int> onPick;
  final ValueNotifier<double> time;

  /// Plain picks (no shop, paint pot, counting stage or capital fix) with 2–4
  /// answers play as a pillow fight.
  static bool fits(PickRound r) => r.stage == null && !r.fixCapital && r.options.length >= 2 && r.options.length <= 4;

  @override
  State<PillowFightView> createState() => _PillowFightViewState();
}

class _PillowFightViewState extends State<PillowFightView> {
  late final double _start = widget.time.value;
  final _tapAt = <int, double>{};

  void _tap(int i) {
    final s = widget.state;
    if (s.correct || s.wrongOptions.contains(i)) return;
    _tapAt[i] = widget.time.value;
    widget.onPick(i);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.round;
    final n = r.options.length;
    final pics = r.options.any((o) => o.picture != null);
    return DreamField(
      correct: widget.state.correct,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          final rows = n <= 2 ? 1 : 2;
          final pw = math.min(156.0, (w - 3 * 16) / 2);
          final ph = math.min(pw * (pics ? .98 : .74), (h - (rows + 1) * 18) / rows);
          final gapY = (h - rows * ph) / (rows + 1);
          Offset slot(int i) {
            final row = rows == 1 ? 0 : (i < 2 ? 0 : 1);
            final inRow = row == 0 ? math.min(2, n) : n - 2;
            final col = row == 0 ? i : i - 2;
            final gapX = (w - inRow * pw) / (inRow + 1);
            return Offset(gapX + col * (pw + gapX), gapY + row * (ph + gapY));
          }

          return ValueListenableBuilder<double>(
            valueListenable: widget.time,
            builder: (context, t, _) => Stack(clipBehavior: Clip.none, children: [for (var i = 0; i < n; i++) _pillow(i, slot(i), Size(pw, ph), w, t)]),
          );
        },
      ),
    );
  }

  Widget _pillow(int i, Offset target, Size size, double fieldW, double t) {
    final s = widget.state;
    final o = widget.round.options[i];
    final wrong = s.wrongOptions.contains(i);
    final won = s.correct && s.picked == i;
    final hint = s.hint && !s.correct && widget.round.isCorrect(o) && widget.round.answer != null;
    // tossed in from the top (the boss), one after another
    final e = ((t - _start - i * .18) / .6).clamp(0.0, 1.0);
    final k = Curves.easeOutCubic.transform(e);
    final from = Offset(fieldW / 2 - size.width / 2, -size.height * 1.2);
    var pos = Offset.lerp(from, target, k)! - Offset(0, math.sin(math.pi * e) * 46);
    var angle = (1 - k) * (i.isEven ? 2.6 : -2.6) + math.sin(t * 1.7 + i) * .05;
    var scale = .45 + .55 * k;
    var sx = 1.0, sy = 1.0, opacity = e <= 0 ? 0.0 : 1.0;
    if (e >= 1) pos += Offset(0, math.sin(t * 2.1 + i * 1.3) * 3);
    final tapAge = _tapAt[i] == null ? null : t - _tapAt[i]!;
    if (won && tapAge != null) {
      // thrown back up at the boss
      final f = Curves.easeIn.transform((tapAge / .5).clamp(0.0, 1.0));
      pos -= Offset(0, f * (target.dy + size.height * 1.6));
      angle += f * 6;
      scale *= 1 - .5 * f;
      opacity = 1 - f;
    } else if (wrong) {
      final f = tapAge == null ? 1.0 : Curves.easeOutBack.transform((tapAge / .3).clamp(0.0, 1.0));
      sx = 1 + .16 * f;
      sy = 1 - .42 * f;
      opacity = .5;
    }
    final base = ContentColors.byName(o.color) ?? DreamColors.pillows[i % DreamColors.pillows.length];
    Widget body = CustomPaint(
      painter: PillowPainter(base),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: _content(o, size)),
        ),
      ),
    );
    if (hint) {
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: -8, top: -8, right: -8, bottom: -8, child: CustomPaint(painter: RoundRing(LikhoColors.hint, 12 * dreamPulse(t)))),
          Positioned.fill(child: body),
        ],
      );
    }
    final children = <Widget>[
      Positioned(
        left: pos.dx,
        top: pos.dy,
        width: size.width,
        height: size.height,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: angle,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(sx * scale, sy * scale, 1),
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: (_) => _tap(i), child: body),
            ),
          ),
        ),
      ),
    ];
    // a wrong pillow puffs out feathers
    if (wrong && tapAge != null && tapAge < .9) {
      final f = tapAge / .9;
      for (var q = 0; q < 6; q++) {
        final a = q * math.pi / 3 + .4;
        final c = target + Offset(size.width / 2, size.height * .7) + Offset(math.cos(a) * 60 * f, math.sin(a) * 30 * f - 40 * f);
        children.add(
          Positioned(
            left: c.dx - 7,
            top: c.dy - 4,
            child: Opacity(
              opacity: 1 - f,
              child: Transform.rotate(
                angle: a + f * 3,
                child: Container(
                  width: 14,
                  height: 7,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _content(PickOption o, Size size) {
    final pic = o.picture;
    final label = o.hideLabel ? '' : o.label;
    final fontSize = label.length <= 2 ? 46.0 : (label.length <= 6 ? 32.0 : 24.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pic != null) Illustration(picture: pic, width: size.width * .5, height: size.height * .46, radius: 12, padding: 2),
        if (pic != null && label.isNotEmpty) const SizedBox(height: 4),
        if (label.isNotEmpty) Text(label, style: dreamLetter(pic != null ? math.min(fontSize, 28) : fontSize, LikhoColors.ink)),
      ],
    );
  }
}

/// A puffy pillow: bulging sides, pinched corner tufts, a soft top light,
/// a darker belly and a stitched seam.
class PillowPainter extends CustomPainter {
  const PillowPainter(this.color);
  final Color color;

  Path _shape(Size s) {
    final w = s.width, h = s.height, b = math.min(w, h) * .09;
    return Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w / 2, -b, w, 0)
      ..quadraticBezierTo(w + b, h / 2, w, h)
      ..quadraticBezierTo(w / 2, h + b, 0, h)
      ..quadraticBezierTo(-b, h / 2, 0, 0)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size);
    canvas.drawPath(shape.shift(const Offset(0, 5)), Paint()..color = LikhoColors.shadowSoft);
    canvas.drawPath(shape, Paint()..color = color);
    canvas.save();
    canvas.clipPath(shape);
    final hsl = HSLColor.fromColor(color);
    final belly = hsl.withLightness((hsl.lightness - .1).clamp(0.0, 1.0)).toColor();
    canvas.drawOval(Rect.fromLTWH(-size.width * .1, size.height * .62, size.width * 1.2, size.height * .7), Paint()..color = belly.withValues(alpha: .55));
    canvas.drawOval(
      Rect.fromLTWH(size.width * .12, size.height * .06, size.width * .5, size.height * .22),
      Paint()..color = Colors.white.withValues(alpha: .55),
    );
    canvas.restore();
    // stitched seam
    final inset = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(8), Radius.circular(size.shortestSide * .2)));
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = DreamColors.stitch;
    for (final m in inset.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 4.5), dash);
      }
    }
    // corner tufts
    for (final c in [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)]) {
      canvas.drawCircle(c, 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(PillowPainter old) => old.color != color;
}

class RoundRing extends CustomPainter {
  const RoundRing(this.color, this.spread);
  final Color color;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.shortestSide * .3));
    if (spread > 0) {
      canvas.drawRRect(
        r.inflate(spread / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spread
          ..color = LikhoColors.primary.withValues(alpha: .35),
      );
    }
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(RoundRing old) => old.spread != spread || old.color != color;
}

// ================================================================== snore bubbles

/// Boss "pop" rounds: the boss's snores float down as bubbles across a night
/// sky, each with a letter or word ([popLabel]). Pop the ones Pencil asks
/// for; a wrong one turns coral and wobbles away. Missed bubbles drift off
/// (no mistake). After a mistake the next right bubble gets a ring.
class SnoreBubblesView extends StatefulWidget {
  const SnoreBubblesView({super.key, required this.state, required this.round, required this.onPop, required this.time});
  final SessionState state;
  final PopRound round;
  final ValueChanged<int> onPop;
  final ValueNotifier<double> time;

  static const gap = 1.0, fall = 6.6;

  @override
  State<SnoreBubblesView> createState() => _SnoreBubblesViewState();
}

class _SnoreBubblesViewState extends State<SnoreBubblesView> {
  late final double _start = widget.time.value + .3;
  final _poppedAt = <int, double>{};
  double? _doneAt;

  String _label(int i) => popLabel(widget.round, level: widget.state.level.number, round: widget.state.round, index: i);

  static int _lane(int i) => const [1, 3, 0, 2, 4, 1, 4, 2, 0, 3][i % 10];

  void _pop(int i) {
    final s = widget.state;
    if (s.correct || s.found.contains(i) || s.wrongOptions.contains(i)) return;
    _poppedAt[i] = widget.time.value;
    widget.onPop(i);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (s.correct) _doneAt ??= widget.time.value;
    return DreamField(
      night: true,
      time: widget.time,
      correct: s.correct,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < widget.round.count; k++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(
                      Symbols.bubble_chart_rounded,
                      size: 24,
                      fill: 1,
                      color: k < s.found.length ? LikhoColors.primary : Colors.white.withValues(alpha: .3),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => ValueListenableBuilder<double>(
                valueListenable: widget.time,
                builder: (context, now, _) => Stack(clipBehavior: Clip.none, children: _bubbles(box.biggest, now)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bubbles(Size field, double now) {
    final s = widget.state;
    const size = 84.0;
    final t = now - _start;
    final last = (((_doneAt ?? now) - _start) / SnoreBubblesView.gap).floor();
    final first = math.max(0, ((t - SnoreBubblesView.fall) / SnoreBubblesView.gap).floor());
    int? hint;
    if (s.hint) {
      for (var i = last; i >= first; i--) {
        final age = t - i * SnoreBubblesView.gap;
        if (age > 0 && age < SnoreBubblesView.fall * .8 && !s.found.contains(i) && _label(i) == widget.round.target) hint = i;
      }
    }
    final laneW = (field.width - size) / 4;
    final out = <Widget>[];
    for (var i = first; i <= last; i++) {
      final age = t - i * SnoreBubblesView.gap;
      if (age <= 0) continue;
      final b = _bubble(i, age, laneW, field, size, now, hint == i);
      if (b != null) out.add(b);
    }
    return out;
  }

  Widget? _bubble(int i, double age, double laneW, Size field, double size, double now, bool hint) {
    final s = widget.state;
    final popped = s.found.contains(i);
    final wrong = s.wrongOptions.contains(i);
    final since = _poppedAt[i] == null ? null : now - _poppedAt[i]!;
    if (popped && (since == null || since > .35)) return null;
    if (wrong && since != null && since > 1.1) return null;
    final p = age / SnoreBubblesView.fall;
    if (p > 1) return null;
    // puffed out at the top (the boss's snore), spreading into a lane as it sinks
    final spread = Curves.easeOut.transform((p * 2.6).clamp(0.0, 1.0));
    final x = field.width / 2 - size / 2 + (laneW * _lane(i) - (field.width / 2 - size / 2)) * spread + math.sin(age * 1.5 + i) * 12;
    final y = -size * .6 + (field.height + size * .8) * p;
    var scale = .5 + .5 * spread, opacity = 1.0, angle = 0.0;
    if (popped && since != null) {
      scale *= 1 + since * 2.4;
      opacity = (1 - since / .35).clamp(0.0, 1.0);
    } else if (wrong && since != null) {
      angle = math.sin(since * 26) * .2 * (1 - since / 1.1);
      opacity = (1.1 - since).clamp(0.0, 1.0);
    }
    return Positioned(
      key: ValueKey('${widget.round.id}-s$i'),
      left: x,
      top: y,
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _pop(i),
              child: CustomPaint(
                painter: _SnoreBubblePainter(wrong: wrong, ring: hint ? 10 * dreamPulse(now) : null),
                child: Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_label(i), style: dreamLetter(38, Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SnoreBubblePainter extends CustomPainter {
  const _SnoreBubblePainter({required this.wrong, this.ring});
  final bool wrong;
  final double? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2 - 2;
    final ringSpread = ring;
    if (ringSpread != null) {
      canvas.drawCircle(
        c,
        r + 6 + ringSpread / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringSpread
          ..color = LikhoColors.primary.withValues(alpha: .35),
      );
      canvas.drawCircle(
        c,
        r + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = LikhoColors.hint,
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.4),
          colors: wrong ? [LikhoColors.hint.withValues(alpha: .5), LikhoColors.hint.withValues(alpha: .8)] : const [Color(0x33FFFFFF), DreamColors.bubble],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = DreamColors.bubbleRim,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-r * .38, -r * .45), width: r * .5, height: r * .28),
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
    // a little "z" on the rim
    final tp = TextPainter(
      text: TextSpan(
        text: 'z',
        style: LikhoFonts.title(size: 14, weight: FontWeight.w800, color: StageSky.zzz),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(r * .45, -r * .95));
  }

  @override
  bool shouldRepaint(_SnoreBubblePainter old) => old.wrong != wrong || old.ring != ring;
}

// ================================================================== wake-up shout

/// Boss "speak" rounds: a big megaphone. Tap it and say the words loud;
/// sound waves roll up towards the boss while Pencil listens.
class ShoutView extends StatelessWidget {
  const ShoutView({super.key, required this.state, required this.onMic, required this.time});
  final SessionState state;
  final VoidCallback onMic;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final listening = state.listening;
    return DreamField(
      correct: state.correct,
      child: Stack(
        children: [
          if (listening)
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _WavesPainter(time))),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.correct ? 'WAKE UP!' : (listening ? 'Louder!' : 'Say it LOUD!'),
                  style: LikhoFonts.title(size: state.correct ? 40 : 28, weight: FontWeight.w800, color: StageSky.meterFrom),
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<double>(
                  valueListenable: time,
                  builder: (context, t, child) => Transform.scale(scale: listening ? 1 + .06 * math.sin(t * 18) : 1 + .04 * dreamPulse(t * .8), child: child),
                  child: PushButton(
                    onTap: state.correct || listening ? null : onMic,
                    color: LikhoColors.hint,
                    edgeColor: GameColors.hintDeep,
                    edge: 8,
                    width: 128,
                    height: 128,
                    pressScale: .94,
                    innerHighlight: true,
                    shape: const CircleBorder(),
                    child: const Icon(Symbols.campaign_rounded, size: 66, fill: 1, opticalSize: 48, color: LikhoColors.surface),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sound waves rolling up from the megaphone.
class _WavesPainter extends CustomPainter {
  _WavesPainter(this.time) : super(repaint: time);
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 30);
    for (var k = 0; k < 4; k++) {
      final p = ((time.value * .9 + k / 4) % 1.0);
      final r = 70 + p * size.height * .8;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi * .82,
        math.pi * .64,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (1 - p)
          ..strokeCap = StrokeCap.round
          ..color = LikhoColors.hint.withValues(alpha: (1 - p) * .8),
      );
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) => false;
}

// ================================================================== sun or moon

/// Boss "truth" rounds: true wakes the world up (the sun), silly sends it
/// back to sleep (the moon). A wrong tap dims that button; after a mistake
/// the right one pulses.
class SunMoonView extends StatelessWidget {
  const SunMoonView({super.key, required this.state, required this.round, required this.onAnswer, required this.time});
  final SessionState state;
  final TruthRound round;
  final ValueChanged<bool> onAnswer;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final pic = round.picture;
    return DreamField(
      correct: state.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final side = math.min(box.maxHeight - 72, box.maxWidth * .6).clamp(56.0, 180.0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (pic != null) Illustration(picture: pic, width: side, height: side, radius: 24),
                      if (pic != null) const SizedBox(height: 10),
                      Text(
                        round.text,
                        textAlign: TextAlign.center,
                        style: LikhoFonts.letter(size: round.text.length > 22 ? 24 : 30).copyWith(height: 1.2),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _answer(true)),
                const SizedBox(width: 14),
                Expanded(child: _answer(false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _answer(bool value) {
    final index = value ? 0 : 1;
    final wrong = state.wrongOptions.contains(index);
    final right = state.correct && state.picked == index;
    final hint = state.hint && value == round.answer && !state.correct;
    Widget button = AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: wrong ? .4 : 1,
      child: PushButton(
        onTap: state.correct || wrong ? null : () => onAnswer(value),
        color: value ? LikhoColors.primary : DreamColors.moonButton,
        edgeColor: value ? LikhoColors.primaryDeep : DreamColors.moonEdge,
        edge: 6,
        height: 78,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        innerHighlight: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(value ? Symbols.wb_sunny_rounded : Symbols.dark_mode_rounded, size: 36, fill: 1, color: value ? LikhoColors.ink : StageSky.moon),
              const SizedBox(width: 8),
              Text(
                value ? 'True!' : 'Silly!',
                style: LikhoFonts.title(size: 26, weight: FontWeight.w800, color: value ? LikhoColors.ink : Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
    if (right || hint) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: time,
                builder: (context, t, _) => CustomPaint(painter: RoundRing(right ? LikhoColors.success : LikhoColors.hint, right ? 0 : 12 * dreamPulse(t))),
              ),
            ),
          ),
        ],
      );
    }
    return button;
  }
}

// ================================================================== magic spell

/// Boss writing rounds: the paper becomes a magic spell, framed by a
/// turning rainbow glow with twinkling sparkles at its corners.
class MagicFrame extends StatelessWidget {
  const MagicFrame({super.key, required this.child, required this.theme, required this.time});
  final Widget child;
  final WorldTheme theme;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    const radius = LikhoRadius.writingPad;
    return ValueListenableBuilder<double>(
      valueListenable: time,
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
      builder: (context, t, child) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + 5),
                gradient: SweepGradient(
                  colors: [theme.accent, LikhoColors.primary, StageSky.meterTo, theme.pop, theme.accent],
                  transform: GradientRotation(t * 1.3),
                ),
                boxShadow: [BoxShadow(color: StageSky.meterTo.withValues(alpha: .35 + .15 * math.sin(t * 3)), blurRadius: 18)],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(5), child: child),
          for (final (i, a) in const [Alignment(-1, -1), Alignment(1, -1), Alignment(-1, 1), Alignment(1, 1)].indexed)
            Align(
              alignment: a,
              child: FractionalTranslation(
                translation: Offset(a.x * .2, a.y * .2),
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: .6 + .5 * dreamPulse(t * .7 + i * .25),
                    child: const Icon(Symbols.auto_awesome_rounded, size: 26, fill: 1, color: LikhoColors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
