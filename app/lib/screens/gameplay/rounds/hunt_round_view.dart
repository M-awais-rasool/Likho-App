import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import 'pick_round_view.dart';

/// "hunt" rounds: a grid of letter tiles; tap every one that is the target.
/// Found tiles turn green with a tick, a wrong tile wiggles and fades; the
/// counter on top shows how many are left. After a mistake one tile still
/// to find pulses.
class HuntRoundView extends StatelessWidget {
  const HuntRoundView({super.key, required this.state, required this.round, required this.onTap, required this.time});
  final SessionState state;
  final HuntRound round;
  final ValueChanged<int> onTap;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final n = round.grid.length;
    // words (sight words, "cat"): three wide tiles a row; letters: up to four
    final words = round.grid.any((c) => c.length > 1);
    final cols = words || n <= 6 ? 3 : 4;
    final rows = (n / cols).ceil();
    final hintAt = state.hint ? [for (var i = 0; i < n; i++) i].where((i) => round.grid[i] == round.target && !state.found.contains(i)).firstOrNull : null;
    return SoftField(
      correct: state.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          children: [
            _Counter(found: state.found.length, of: round.count),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  const gap = 10.0;
                  final size = math.min((box.maxWidth - gap * (cols - 1)) / cols, (box.maxHeight - gap * (rows - 1)) / rows).clamp(40.0, 92.0);
                  return Center(
                    child: Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < n; i++)
                          SizedBox.square(
                            dimension: size,
                            child: _Tile(
                              key: ValueKey('${round.id}-$i'),
                              label: round.grid[i],
                              found: state.found.contains(i),
                              wrong: state.wrongOptions.contains(i),
                              showWrong: state.feedback == RoundFeedback.wrong,
                              hint: hintAt == i,
                              time: time,
                              onTap: state.correct ? null : () => onTap(i),
                              isTarget: round.grid[i] == round.target,
                              word: words,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "2 of 4" with a dot per letter to find.
class _Counter extends StatelessWidget {
  const _Counter({required this.found, required this.of});
  final int found, of;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < of; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: const Cubic(.34, 1.56, .64, 1),
          width: i < found ? 22 : 16,
          height: i < found ? 22 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < found ? LikhoColors.success : GameColors.ink14,
          ),
          child: i < found ? const Icon(Symbols.check_rounded, size: 15, weight: 700, color: LikhoColors.surface) : null,
        ),
      ],
    ],
  );
}

class _Tile extends StatefulWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.found,
    required this.wrong,
    required this.showWrong,
    required this.hint,
    required this.time,
    required this.onTap,
    required this.isTarget,
    this.word = false,
  });

  final String label;
  final bool found, wrong, showWrong, hint, isTarget;

  /// A word tile: a rounded square, the text sized to fit.
  final bool word;
  final ValueNotifier<double> time;
  final VoidCallback? onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> with SingleTickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  bool _pop = false;

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.onTap == null || widget.found || widget.wrong) return;
    _pop = widget.isTarget;
    _fx.forward(from: 0);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final found = widget.found;
    Widget tile = LayoutBuilder(
      builder: (context, box) => DecoratedBox(
        decoration: BoxDecoration(
          shape: widget.word ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: widget.word ? BorderRadius.circular(box.maxWidth * .26) : null,
          color: found ? LikhoColors.success : (widget.wrong && widget.showWrong ? GameColors.hintPale : LikhoColors.surface),
          border: Border.all(color: found ? GameColors.successDeep : GameColors.ink08, width: 3, strokeAlign: BorderSide.strokeAlignInside),
          boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: LikhoFonts.letter(size: math.min(box.maxWidth * .5, box.maxWidth * 1.5 / widget.label.length), color: found ? LikhoColors.surface : LikhoColors.ink).copyWith(height: 1),
          ),
        ),
      ),
    );
    if (widget.hint) {
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: tile),
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: widget.time,
                builder: (context, t, _) {
                  final k = const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t % 1.0) - 1).abs());
                  return CustomPaint(painter: _HintRing(spread: 12 * k));
                },
              ),
            ),
          ),
        ],
      );
    }
    tile = AnimatedBuilder(
      animation: _fx,
      child: tile,
      builder: (context, child) {
        final v = _fx.value;
        if (!_fx.isAnimating) return child!;
        if (_pop) {
          final k = const Cubic(.34, 1.56, .64, 1).transform(v < .5 ? v * 2 : 2 - v * 2);
          return Transform.scale(scale: 1 + .2 * k, child: child);
        }
        const keys = [0.0, -12.0, 10.0, -6.0, 0.0];
        final q = (v * 4).floor().clamp(0, 3);
        final deg = keys[q] + (keys[q + 1] - keys[q]) * (v * 4 - q);
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      },
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: widget.wrong && !widget.showWrong ? .45 : 1,
        child: tile,
      ),
    );
  }
}

class _HintRing extends CustomPainter {
  const _HintRing({required this.spread});
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (spread > 0) {
      canvas.drawCircle(
        c,
        r + 4 + spread / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spread
          ..color = LikhoColors.primary.withValues(alpha: .35),
      );
    }
    canvas.drawCircle(
      c,
      r + 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = LikhoColors.hint,
    );
  }

  @override
  bool shouldRepaint(_HintRing old) => old.spread != spread;
}
