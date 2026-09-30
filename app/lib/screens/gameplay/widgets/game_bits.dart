import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../world_map/boss_painter.dart';
import 'illustration.dart';

/// Round progress: done = green, current = wide yellow, rest = faint.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.count, required this.current, required this.currentDone, required this.dark});
  final int count, current;
  final bool currentDone, dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: const Cubic(.34, 1.56, .64, 1),
            height: 14,
            width: i == current ? 30 : 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: i < current || (i == current && currentDone)
                  ? LikhoColors.success
                  : i == current
                  ? LikhoColors.primary
                  : (dark ? GameColors.white25 : GameColors.ink14),
            ),
          ),
        ],
      ],
    );
  }
}

/// The white card next to the mascot: picture and/or text.
class PromptCardView extends StatelessWidget {
  const PromptCardView({super.key, required this.card});
  final PromptCard? card;

  /// Prototype: > 26 chars 17 px, > 14 22 px, > 3 30 px, else 48 px.
  static double fontFor(String t) => t.length > 26
      ? 17
      : t.length > 14
      ? 22
      : t.length > 3
      ? 30
      : 48;

  @override
  Widget build(BuildContext context) {
    final text = card?.text ?? '';
    final pic = card?.picture;
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LikhoColors.surface,
        borderRadius: BorderRadius.circular(LikhoRadius.card),
        boxShadow: const [
          BoxShadow(color: GameColors.ink06, offset: Offset(0, 6)),
          BoxShadow(color: GameColors.ink08, offset: Offset(0, 12), blurRadius: 30),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (pic != null) Illustration(picture: pic, width: 78, height: 84),
          if (pic != null && text.isNotEmpty) const SizedBox(width: 10),
          // the text box is `flex:1; min-width:0`: it takes the rest of the
          // card, and a word too long for it overflows instead of shrinking
          if (text.isNotEmpty)
            Expanded(
              child: BalancedText(text, style: LikhoFonts.letter(size: fontFor(text)).copyWith(height: 1.2)),
            ),
        ],
      ),
    );
  }
}

/// Centred text laid out like the prototype's CSS (`text-align: center;
/// text-wrap: balance`) in the width it is given:
/// * balance: as many lines as at full width, but the narrowest width that
///   keeps that count, so lines come out about equally long ("A → C").
/// * a word longer than the box is never broken; its line overflows to the
///   right (CSS start-aligns an overflowing line, other lines stay centred).
class BalancedText extends LeafRenderObjectWidget {
  const BalancedText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  RenderBalancedText createRenderObject(BuildContext context) =>
      RenderBalancedText(text, style, MediaQuery.textScalerOf(context), Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderBalancedText renderObject) => renderObject
    ..text = text
    ..style = style
    ..scaler = MediaQuery.textScalerOf(context)
    ..direction = Directionality.of(context);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('text', text));
  }
}

class RenderBalancedText extends RenderBox {
  RenderBalancedText(this._text, this._style, this._scaler, this._direction);

  String _text;
  TextStyle _style;
  TextScaler _scaler;
  TextDirection _direction;
  TextPainter? _tp;

  set text(String v) {
    if (v == _text) return;
    _text = v;
    markNeedsLayout();
  }

  set style(TextStyle v) {
    if (v == _style) return;
    _style = v;
    markNeedsLayout();
  }

  set scaler(TextScaler v) {
    if (v == _scaler) return;
    _scaler = v;
    markNeedsLayout();
  }

  set direction(TextDirection v) {
    if (v == _direction) return;
    _direction = v;
    markNeedsLayout();
  }

  TextPainter _lay(double w) => TextPainter(
    text: TextSpan(text: _text, style: _style),
    textAlign: TextAlign.center,
    textDirection: _direction,
    textScaler: _scaler,
  )..layout(maxWidth: w);

  double _longestWord() {
    final p = _lay(double.infinity);
    final w = p.minIntrinsicWidth.ceilToDouble();
    p.dispose();
    return w;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0; // min-width:0

  @override
  double computeMaxIntrinsicWidth(double height) {
    final p = _lay(double.infinity);
    final w = p.maxIntrinsicWidth.ceilToDouble();
    p.dispose();
    return w;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final p = _balanced(constraints.maxWidth);
    final s = constraints.constrain(Size(constraints.maxWidth, p.height));
    p.dispose();
    return s;
  }

  TextPainter _balanced(double box) {
    final layoutW = math.max(box, _longestWord());
    var p = _lay(layoutW);
    final lines = p.computeLineMetrics().length;
    if (lines < 2) return p;
    var lo = 0.0, hi = layoutW;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      final q = _lay(mid);
      final m = q.computeLineMetrics();
      // same line count and no word broken across lines
      final fits = m.length <= lines && mid >= q.minIntrinsicWidth;
      q.dispose();
      if (fits) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    p.dispose();
    // exactly the width that was tested: rounding up could pull a word back
    // onto the first line ("A →" / "C" instead of the balanced "A" / "→ C")
    return _lay(hi);
  }

  /// Width of each laid-out line (tests).
  @visibleForTesting
  List<double> get debugLineWidths => [for (final l in _tp?.computeLineMetrics() ?? const <LineMetrics>[]) l.width];

  @override
  void performLayout() {
    _tp?.dispose();
    final box = constraints.maxWidth;
    _tp = _balanced(box);
    size = constraints.constrain(Size(box, _tp!.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final tp = _tp;
    if (tp == null) return;
    final canvas = context.canvas;
    final box = size.width;
    for (final line in tp.computeLineMetrics()) {
      // where CSS puts this line: centred in the box, or at its start when
      // the line is wider than the box
      final want = line.width <= box ? (box - line.width) / 2 : 0.0;
      final top = line.baseline - line.ascent;
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(-1e4, offset.dy + top, 1e4, offset.dy + top + line.height))
        ..translate(offset.dx + want - line.left, offset.dy);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _text
      ..textDirection = _direction;
  }

  @override
  void dispose() {
    _tp?.dispose();
    _tp = null;
    super.dispose();
  }
}

/// What Pencil says: a white bubble next to him, its tail pointing left at
/// his face. [step] (writing) puts the stroke number in a blue dot, the
/// same dot that marks where the stroke starts on the pad.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.step});
  final String text;
  final int? step;

  @override
  Widget build(BuildContext context) {
    final style = LikhoFonts.title(size: 16, weight: FontWeight.w800).copyWith(height: 1);
    return TweenAnimationBuilder<double>(
      key: ValueKey((text, step)),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, t, child) {
        final s = t < .7 ? 1.08 * const Cubic(.34, 1.56, .64, 1).transform(t / .7) : 1.08 - .08 * ((t - .7) / .3);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(-8 * (1 - t), 0),
            child: Transform.scale(scale: s, alignment: Alignment.centerLeft, child: child),
          ),
        );
      },
      child: CustomPaint(
        painter: const _BubbleTail(),
        child: Container(
          margin: const EdgeInsets.only(left: _BubbleTail.size),
          padding: EdgeInsets.fromLTRB(step == null ? 12 : 6, 6, 12, 6),
          decoration: BoxDecoration(
            color: LikhoColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: GameColors.ink12, offset: Offset(0, 4), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (step != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: LikhoColors.secondary, shape: BoxShape.circle),
                  child: Text('$step', style: LikhoFonts.title(size: 13, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1)),
                ),
                const SizedBox(width: 7),
              ],
              Flexible(child: Text(text, softWrap: false, overflow: TextOverflow.fade, style: style)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bubble's little triangle on its left edge, at mid height.
class _BubbleTail extends CustomPainter {
  const _BubbleTail();
  static const size = 8.0;

  @override
  void paint(Canvas canvas, Size box) {
    final y = box.height / 2;
    canvas.drawPath(
      Path()
        ..moveTo(size + 2, y - 7)
        ..lineTo(0, y + 2)
        ..lineTo(size + 2, y + 6)
        ..close(),
      Paint()..color = LikhoColors.surface,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail old) => false;
}

/// Boss levels: the sleeping boss plus one bubble per round that pops when
/// the round is won. The boss wakes up and dances after the last round.
class BossStrip extends StatelessWidget {
  const BossStrip({super.key, required this.world, required this.rounds, required this.done, required this.awake, required this.time});
  final int world, rounds, done;
  final bool awake;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 100,
            height: 84,
            child: CustomPaint(
              painter: BossPainter(world: world, awake: awake, time: time, dance: awake),
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              children: [
                for (var i = 0; i < rounds; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  AnimatedScale(
                    scale: i < done ? 1.8 : 1,
                    duration: const Duration(milliseconds: 350),
                    curve: const Cubic(.34, 1.56, .64, 1),
                    child: AnimatedOpacity(
                      opacity: i < done ? 0 : 1,
                      duration: const Duration(milliseconds: 350),
                      // CSS content-box: 24 px + 2 px border each side = 28 px.
                      // The gradient is `circle at 35% 30%` of the 24 px padding
                      // box, sized to its farthest corner (22.9 px).
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: GameColors.bubbleRim, width: 2),
                          gradient: const RadialGradient(
                            center: Alignment(-.257, -.343),
                            radius: .819,
                            colors: [LikhoColors.surface, LikhoColors.surface, GameColors.bubbleMid, GameColors.bubbleMid, GameColors.bubbleBlue],
                            stops: [0, .18, .2, .7, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Letter boxes for "missing" and "spell" writing rounds.
class LetterBoxes extends StatelessWidget {
  const LetterBoxes({super.key, required this.round, required this.spellFilled, required this.correct});
  final WriteRound round;
  final int spellFilled;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final word = round.word ?? '';
    final missing = round.mode == WriteMode.missing;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // flex items like the prototype: boxes shrink a little for long words
        for (var i = 0; i < word.length; i++) ...[if (i > 0) const SizedBox(width: 10), Flexible(child: _box(word[i], i, missing))],
      ],
    );
  }

  Widget _box(String ch, int i, bool missing) {
    final shown = missing ? (i != round.missingIndex || correct) : i < spellFilled;
    final active = missing ? i == round.missingIndex && !correct : i == spellFilled;
    final border = active
        ? LikhoColors.hint
        : shown && (!missing || i == round.missingIndex)
        ? LikhoColors.success
        : GameColors.ink12;
    return AnimatedScale(
      scale: active ? 1.08 : 1,
      duration: const Duration(milliseconds: 300),
      curve: const Cubic(.34, 1.56, .64, 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 62,
        height: 70,
        decoration: BoxDecoration(
          color: active ? GameColors.hintBox : LikhoColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 3, strokeAlign: BorderSide.strokeAlignInside),
          boxShadow: const [BoxShadow(color: GameColors.ink06, offset: Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(shown ? ch : '', style: LikhoFonts.letter(size: 40).copyWith(fontWeight: FontWeight.w700, height: 1)),
      ),
    );
  }
}

/// Confetti + stars thrown from the play area when a round is won
/// (26 pieces, 0.9 s, the prototype's burst()).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger, required this.child});

  /// Increments to fire a burst.
  final int trigger;
  final Widget child;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final _rnd = math.Random();
  List<_Piece> _pieces = const [];

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) {
      _pieces = [
        for (var i = 0; i < 26; i++)
          _Piece(
            color: GameColors.confetti[i % 5],
            star: i % 3 == 0,
            angle: _rnd.nextDouble() * math.pi * 2,
            dist: 90 + _rnd.nextDouble() * 130,
            spin: _rnd.nextDouble() * 500,
          ),
      ];
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => _c.isAnimating ? CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)) : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Piece {
  const _Piece({required this.color, required this.star, required this.angle, required this.dist, required this.spin});
  final Color color;
  final bool star;
  final double angle, dist, spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  static const _ease = Cubic(.2, .8, .3, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final e = _ease.transform(t);
    final paint = Paint();
    for (final p in pieces) {
      // keyframes: 0 -> (70 %) out and up 40 px -> (100 %) further, falling 30 px, fading
      final Offset d;
      final double scale, rot, alpha;
      if (e < .7) {
        final k = e / .7;
        d = Offset(math.cos(p.angle) * p.dist * k, (math.sin(p.angle) * p.dist - 40) * k);
        scale = .3 + .7 * k;
        rot = p.spin * k;
        alpha = 1;
      } else {
        final k = (e - .7) / .3;
        d = Offset(math.cos(p.angle) * p.dist * (1 + .1 * k), math.sin(p.angle) * p.dist - 40 + 70 * k);
        scale = 1 - .2 * k;
        rot = p.spin + (600 - p.spin) * k;
        alpha = 1 - k;
      }
      canvas.save();
      canvas.translate(c.dx + d.dx, c.dy + d.dy);
      canvas.rotate(rot * math.pi / 180);
      canvas.scale(scale);
      paint.color = p.color.withValues(alpha: alpha);
      if (p.star) {
        canvas.drawPath(_star(9), paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -7, 10, 14), const Radius.circular(3)), paint);
      }
      canvas.restore();
    }
  }

  static Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * .45;
      final pt = Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
