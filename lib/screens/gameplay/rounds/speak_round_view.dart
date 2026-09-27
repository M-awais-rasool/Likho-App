import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/game_buttons.dart';
import 'pick_round_view.dart';

/// "speak" rounds (Talk to Aliens): tap the mic and say it. The alien flips
/// with joy when you're done. Listening is simulated like the prototype
/// (a real speech check can replace LevelSession.listen later).
class SpeakRoundView extends StatelessWidget {
  const SpeakRoundView({super.key, required this.state, required this.onMic, required this.time});
  final SessionState state;
  final VoidCallback onMic;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final listening = state.listening;
    return ClipRRect(
      borderRadius: BorderRadius.circular(LikhoRadius.writingPad),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: Alignment(0, -.4), radius: 1, colors: [GameColors.spaceTop, GameColors.spaceBottom], stops: [0, .7]),
              ),
            ),
          ),
          _Twinkle(left: 30, top: 40, size: 5, color: GameColors.starDot, period: 2, time: time),
          _Twinkle(right: 50, top: 90, size: 4, color: LikhoColors.surface, period: 3, time: time),
          _Twinkle(left: 70, bottom: 130, size: 4, color: LikhoColors.surface, period: 2.6, time: time),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: state.correct ? .5 : 0,
                  duration: const Duration(milliseconds: 600),
                  curve: const Cubic(.34, 1.56, .64, 1),
                  child: AnimatedSlide(
                    offset: Offset(0, state.correct ? -20 / 170 : 0),
                    duration: const Duration(milliseconds: 600),
                    curve: const Cubic(.34, 1.56, .64, 1),
                    child: _Alien(listening: listening, time: time),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (listening) ...[_MicPulse(time: time, offset: 0), _MicPulse(time: time, offset: .5)],
                      PushButton(
                        onTap: onMic,
                        color: LikhoColors.hint,
                        edgeColor: GameColors.hintDeep,
                        edge: 7,
                        width: 104,
                        height: 104,
                        pressScale: .95,
                        innerHighlight: true,
                        shape: const CircleBorder(),
                        child: const Icon(Symbols.mic_rounded, size: 52, fill: 1, opticalSize: 48, color: LikhoColors.surface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (state.correct) const Positioned.fill(child: CorrectGlow()),
        ],
      ),
    );
  }
}

class _Twinkle extends StatelessWidget {
  const _Twinkle({this.left, this.right, this.top, this.bottom, required this.size, required this.color, required this.period, required this.time});
  final double? left, right, top, bottom;
  final double size, period;
  final Color color;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    right: right,
    top: top,
    bottom: bottom,
    child: ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, _) {
        final k = const Cubic(.25, .1, .25, 1).transform(1 - (2 * ((t / period) % 1.0) - 1).abs());
        return Opacity(
          opacity: .25 + .75 * k,
          child: Transform.scale(
            scale: .8 + .35 * k,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    ),
  );
}

class _MicPulse extends StatelessWidget {
  const _MicPulse({required this.time, required this.offset});
  final ValueNotifier<double> time;
  final double offset;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: time,
    builder: (context, t, _) {
      final p = Curves.easeOut.transform(((t + offset)) % 1.0);
      return Opacity(
        opacity: .6 * (1 - p),
        child: Transform.scale(
          scale: 1 + .75 * p,
          child: Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(color: LikhoColors.hint, shape: BoxShape.circle),
          ),
        ),
      );
    },
  );
}

class _Alien extends StatelessWidget {
  const _Alien({required this.listening, required this.time});
  final bool listening;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 170,
      child: ValueListenableBuilder<double>(
        valueListenable: time,
        builder: (context, t, _) => CustomPaint(
          painter: _AlienPainter(t: t, listening: listening),
        ),
      ),
    );
  }
}

class _AlienPainter extends CustomPainter {
  const _AlienPainter({required this.t, required this.listening});
  final double t;
  final bool listening;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    // antennas: 6 x 40 at left 44 / right 44, swaying ±12° (2.4 s, .3 s when listening)
    final period = listening ? .3 : 2.4;
    final k = Curves.easeInOut.transform(1 - (2 * ((t / period) % 1.0) - 1).abs());
    final angle = (-12 + 24 * k) * math.pi / 180;
    for (final (x, ball) in [(44.0, LikhoColors.primary), (size.width - 44 - 6, LikhoColors.hint)]) {
      canvas.save();
      canvas.translate(x + 3, 40);
      canvas.rotate(angle);
      canvas.drawRRect(RRect.fromLTRBR(-3, -40, 3, 0, const Radius.circular(3)), paint..color = GameColors.alien);
      canvas.drawCircle(const Offset(0, -41), 9, paint..color = ball);
      canvas.restore();
    }
    // body 150 x 136 at top 34, radius 70 70 56 56, inset -12 -12 shade
    final body = RRect.fromRectAndCorners(
      const Rect.fromLTWH(0, 34, 150, 136),
      topLeft: const Radius.circular(70),
      topRight: const Radius.circular(70),
      bottomLeft: const Radius.circular(56),
      bottomRight: const Radius.circular(56),
    ).scaleRadii();
    final bp = Path()..addRRect(body);
    canvas.drawPath(bp, paint..color = GameColors.alien);
    canvas.drawPath(Path.combine(PathOperation.difference, bp, bp.shift(const Offset(-12, -12))), paint..color = GameColors.black10);
    // one big eye
    canvas.drawCircle(const Offset(75, 90), 28, paint..color = LikhoColors.surface);
    canvas.drawCircle(const Offset(77, 92), 12, paint..color = LikhoColors.ink);
    canvas.drawCircle(const Offset(81, 86), 4, paint..color = LikhoColors.surface);
    // smile: 40 x 16 border-bottom 5
    final m = RRect.fromRectAndCorners(const Rect.fromLTWH(55, 130, 40, 16), bottomLeft: const Radius.circular(20), bottomRight: const Radius.circular(20));
    canvas.save();
    canvas.clipRRect(m);
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRRect(m), Path()..addRRect(m.shift(const Offset(0, -5)))),
      paint..color = LikhoColors.ink,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AlienPainter old) => old.t != t || old.listening != listening;
}
