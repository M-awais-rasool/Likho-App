import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/game_bits.dart';
import 'pick_round_view.dart';

/// "fix" rounds: Pencil's notebook page, his letters written on ruled paper.
/// Some are backwards or upside down; tap each one and it turns the right
/// way (a flip), then goes green. Tapping a letter that was right is a
/// mistake. After a mistake one letter still to fix pulses.
class FixRoundView extends StatelessWidget {
  const FixRoundView({super.key, required this.state, required this.round, required this.onTap, required this.time});
  final SessionState state;
  final FixRound round;
  final ValueChanged<int> onTap;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final n = round.items.length;
    final words = round.items.any((i) => i.text.length > 1);
    final cols = words ? 2 : (n <= 6 ? 3 : 4);
    final rows = (n / cols).ceil();
    final hintAt = state.hint ? [for (var i = 0; i < n; i++) i].where((i) => round.items[i].wrong != null && !state.found.contains(i)).firstOrNull : null;
    return SoftField(
      correct: state.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          children: [
            FoundCounter(found: state.found.length, of: round.count),
            const SizedBox(height: 10),
            Expanded(
              child: _Notebook(
                child: LayoutBuilder(
                  builder: (context, box) {
                    const gap = 10.0;
                    final w = (box.maxWidth - gap * (cols - 1)) / cols;
                    final h = math.min((box.maxHeight - gap * (rows - 1)) / rows, words ? 76.0 : 92.0);
                    final size = Size(w, math.max(44, h));
                    return Center(
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < n; i++)
                            SizedBox.fromSize(
                              size: words ? size : Size.square(math.min(size.width, size.height)),
                              child: _Item(
                                key: ValueKey('${round.id}-$i'),
                                item: round.items[i],
                                fixed: state.found.contains(i),
                                wrong: state.wrongOptions.contains(i),
                                showWrong: state.feedback == RoundFeedback.wrong,
                                hint: hintAt == i,
                                time: time,
                                onTap: state.correct ? null : () => onTap(i),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A page of Pencil's notebook: ruled lines and a red margin.
class _Notebook extends StatelessWidget {
  const _Notebook({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: GameColors.paperNote,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 6))],
    ),
    child: CustomPaint(
      painter: const _RulePainter(),
      child: Padding(padding: const EdgeInsets.fromLTRB(30, 14, 14, 14), child: child),
    ),
  );
}

class _RulePainter extends CustomPainter {
  const _RulePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = GameColors.lineTop
      ..strokeWidth = 1.5;
    for (var y = 34.0; y < size.height - 8; y += 30) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), line);
    }
    canvas.drawLine(
      const Offset(20, 6),
      Offset(20, size.height - 6),
      Paint()
        ..color = LikhoColors.hint.withValues(alpha: .45)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RulePainter old) => false;
}

class _Item extends StatefulWidget {
  const _Item({
    super.key,
    required this.item,
    required this.fixed,
    required this.wrong,
    required this.showWrong,
    required this.hint,
    required this.time,
    required this.onTap,
  });

  final FixItem item;
  final bool fixed, wrong, showWrong, hint;
  final ValueNotifier<double> time;
  final VoidCallback? onTap;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> with TickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  /// 1 = shown wrong, 0 = turned the right way.
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: widget.fixed ? 0 : 1);

  @override
  void didUpdateWidget(_Item old) {
    super.didUpdateWidget(old);
    if (widget.fixed && !old.fixed) _turn.animateTo(0, curve: const Cubic(.34, 1.56, .64, 1));
  }

  @override
  void dispose() {
    _fx.dispose();
    _turn.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.onTap == null || widget.fixed || widget.wrong) return;
    if (widget.item.wrong == null) _fx.forward(from: 0);
    widget.onTap!();
  }

  /// The letter (or the one wrong letter of a word), drawn the wrong way by
  /// [t] (1 = fully wrong).
  Widget _glyph(String s, double size, Color color, double t) {
    final text = Text(
      s,
      style: LikhoFonts.letter(size: size, color: color).copyWith(height: 1),
    );
    if (t == 0 || widget.item.wrong == null) return text;
    // a flip through the edge: scale goes 1 -> -1 as t goes 0 -> 1
    final k = math.cos(t * math.pi);
    final m = widget.item.wrong == FixWrong.mirror ? Matrix4.diagonal3Values(k, 1, 1) : Matrix4.diagonal3Values(1, k, 1);
    return Transform(alignment: Alignment.center, transform: m, child: text);
  }

  @override
  Widget build(BuildContext context) {
    final fixed = widget.fixed;
    final item = widget.item;
    Widget tile = LayoutBuilder(
      builder: (context, box) {
        final len = item.text.length;
        final size = math.min(box.maxHeight * .62, box.maxWidth * 1.3 / math.max(1, len));
        final color = fixed ? LikhoColors.surface : LikhoColors.ink;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: fixed ? LikhoColors.success : (widget.wrong && widget.showWrong ? GameColors.hintPale : LikhoColors.surface),
            border: Border.all(color: fixed ? GameColors.successDeep : GameColors.ink08, width: 3, strokeAlign: BorderSide.strokeAlignInside),
            boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 4))],
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedBuilder(
                      animation: _turn,
                      builder: (context, _) {
                        final t = _turn.value;
                        if (item.at == null) return _glyph(item.text, size, color, t);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [for (var i = 0; i < len; i++) i == item.at ? _glyph(item.text[i], size, color, t) : _glyph(item.text[i], size, color, 0)],
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (fixed) const Positioned(right: 4, top: 4, child: Icon(Symbols.check_circle_rounded, size: 20, fill: 1, color: LikhoColors.surface)),
            ],
          ),
        );
      },
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
                  return CustomPaint(painter: _HintBox(spread: 12 * k));
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
        if (!_fx.isAnimating) return child!;
        final v = _fx.value;
        const keys = [0.0, -10.0, 8.0, -5.0, 0.0];
        final q = (v * 4).floor().clamp(0, 3);
        final deg = keys[q] + (keys[q + 1] - keys[q]) * (v * 4 - q);
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      },
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedOpacity(duration: const Duration(milliseconds: 250), opacity: widget.wrong && !widget.showWrong ? .45 : 1, child: tile),
    );
  }
}

/// [HintRing] for a rounded square.
class _HintBox extends CustomPainter {
  const _HintBox({required this.spread});
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    if (spread > 0) {
      canvas.drawRRect(
        r.inflate(4 + spread / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spread
          ..color = LikhoColors.primary.withValues(alpha: .35),
      );
    }
    canvas.drawRRect(
      r.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = LikhoColors.hint,
    );
  }

  @override
  bool shouldRepaint(_HintBox old) => old.spread != spread;
}
