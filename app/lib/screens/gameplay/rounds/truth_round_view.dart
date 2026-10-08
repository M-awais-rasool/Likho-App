import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/game_bits.dart';
import '../widgets/game_buttons.dart';
import '../widgets/illustration.dart';
import 'pick_round_view.dart';

/// "truth" rounds: a big picture with a sentence under it, and two big
/// buttons: thumbs up "True" and thumbs down "Silly". The right one gets a
/// green ring; a wrong tap dims that button. After a mistake the right
/// button pulses.
class TruthRoundView extends StatelessWidget {
  const TruthRoundView({super.key, required this.state, required this.round, required this.onAnswer, required this.time});
  final SessionState state;
  final TruthRound round;
  final ValueChanged<bool> onAnswer;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final pic = round.picture;
    return SoftField(
      correct: state.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final side = math.min(box.maxHeight - 72, box.maxWidth * .62).clamp(60.0, 190.0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (pic != null) Illustration(picture: pic, width: side, height: side, radius: 24),
                      if (pic != null) const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: BalancedText(round.text, style: LikhoFonts.letter(size: round.text.length > 22 ? 24 : 30).copyWith(height: 1.2)),
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
    final color = value ? LikhoColors.success : LikhoColors.hint;
    final edge = value ? GameColors.successDeep : GameColors.hintDeep;
    Widget button = AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: wrong ? .4 : 1,
      child: PushButton(
        onTap: state.correct || wrong ? null : () => onAnswer(value),
        color: color,
        edgeColor: edge,
        edge: 6,
        height: 74,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        innerHighlight: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(value ? Symbols.thumb_up_rounded : Symbols.thumb_down_rounded, size: 34, fill: 1, color: LikhoColors.surface),
              const SizedBox(width: 8),
              Text(
                value ? 'True' : 'Silly',
                style: LikhoFonts.title(size: 26, weight: FontWeight.w800, color: LikhoColors.surface),
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
                builder: (context, t, _) {
                  final k = right ? 0.0 : const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t % 1.0) - 1).abs());
                  return CustomPaint(
                    painter: _Ring(color: right ? LikhoColors.success : LikhoColors.hint, spread: 14 * k),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }
    return button;
  }
}

class _Ring extends CustomPainter {
  const _Ring({required this.color, required this.spread});
  final Color color;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26));
    if (spread > 0) {
      canvas.drawRRect(
        r.inflate(5 + spread / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spread
          ..color = LikhoColors.primary.withValues(alpha: .35),
      );
    }
    canvas.drawRRect(
      r.inflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.spread != spread || old.color != color;
}
