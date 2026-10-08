import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/illustration.dart';
import 'pick_round_view.dart';

/// "match" rounds: a memory game. All cards show for a moment ([peek]),
/// then turn face down; turn two at a time to find the pairs (A and a, a
/// word and its picture). A pair stays up and goes green; two that are not
/// a pair turn back down.
class MatchRoundView extends StatefulWidget {
  const MatchRoundView({super.key, required this.state, required this.round, required this.onFlip});
  final SessionState state;
  final MatchRound round;
  final ValueChanged<int> onFlip;

  static const peek = Duration(milliseconds: 2400);

  @override
  State<MatchRoundView> createState() => _MatchRoundViewState();
}

class _MatchRoundViewState extends State<MatchRoundView> {
  bool _peek = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(MatchRoundView.peek, () {
      if (mounted) setState(() => _peek = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final n = widget.round.cardCount;
    final cards = s.cards;
    final cols = n <= 6 ? 3 : 4;
    final rows = (n / cols).ceil();
    return SoftField(
      correct: s.correct,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, box) {
            const gap = 10.0;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            final h = math.min((box.maxHeight - gap * (rows - 1)) / rows, w * 1.25);
            return Center(
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                alignment: WrapAlignment.center,
                children: [
                  for (var p = 0; p < n; p++)
                    SizedBox(
                      width: math.min(w, h / 1.1),
                      height: h,
                      child: _Card(
                        key: ValueKey('${widget.round.id}-card$p'),
                        side: widget.round.side(cards[p]),
                        up: _peek || s.found.contains(p) || s.open.contains(p),
                        matched: s.found.contains(p),
                        onTap: _peek || s.correct ? null : () => widget.onFlip(p),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.side, required this.up, required this.matched, required this.onTap});
  final MatchSide side;
  final bool up, matched;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: up ? null : onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: up ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        builder: (context, t, _) {
          final showFront = t >= .5;
          final angle = (showFront ? 1 - t : t) * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 1 / 900)
              ..rotateY(angle),
            child: showFront ? _front() : _back(),
          );
        },
      ),
    );
  }

  Widget _back() => DecoratedBox(
    decoration: BoxDecoration(
      color: LikhoColors.secondary,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: GameColors.white60, width: 3, strokeAlign: BorderSide.strokeAlignInside),
      boxShadow: const [BoxShadow(color: GameColors.secondaryDeep, offset: Offset(0, 5))],
    ),
    child: const Center(child: Icon(Symbols.star_rounded, size: 36, fill: 1, color: LikhoColors.primary)),
  );

  Widget _front() => LayoutBuilder(
    builder: (context, box) {
      final pic = side.picture;
      final text = side.text;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: matched ? GameColors.successPale : LikhoColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: matched ? LikhoColors.success : GameColors.ink08, width: 3, strokeAlign: BorderSide.strokeAlignInside),
          boxShadow: [BoxShadow(color: matched ? GameColors.successDeep : GameColors.ink10, offset: const Offset(0, 5))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Center(
            child: pic != null
                ? Illustration(picture: pic, width: box.maxWidth - 16, height: box.maxHeight - 16, radius: 12, padding: 2)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(text ?? '', style: LikhoFonts.letter(size: (text ?? '').length > 2 ? 30 : 46).copyWith(height: 1)),
                  ),
          ),
        ),
      );
    },
  );
}
