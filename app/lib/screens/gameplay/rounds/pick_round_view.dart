import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../../../mascot/mascot.dart';
import 'pick_shapes.dart';

/// "pick" rounds: tap the right item. Three layouts from the prototype:
/// field (items placed on a soft card, optional stage on top), patient
/// (Doctor Pencil: tap a body part) and flow (Fix-It: tap a word in a sentence).
class PickRoundView extends StatelessWidget {
  const PickRoundView({super.key, required this.state, required this.round, required this.onPick, required this.time});
  final SessionState state;
  final PickRound round;
  final ValueChanged<int> onPick;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final layout = round.layout ?? state.level.presentation.layout ?? 'field';
    return switch (layout) {
      'patient' => _PatientView(state: state, round: round, onPick: onPick),
      'flow' => _FlowView(state: state, round: round, onPick: onPick),
      _ => _FieldView(state: state, round: round, onPick: onPick, time: time),
    };
  }
}

/// Soft translucent card behind pick / order rounds.
class SoftField extends StatelessWidget {
  const SoftField({super.key, required this.child, this.correct = false});
  final Widget child;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LikhoRadius.writingPad),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [GameColors.white55, GameColors.white15]),
              border: Border.all(color: GameColors.white60, width: 2, strokeAlign: BorderSide.strokeAlignInside),
            ),
          ),
        ),
        Positioned.fill(child: child),
        if (correct) const Positioned.fill(child: CorrectGlow()),
      ],
    );
  }
}

/// Fills the play area like the prototype's flex column, but lets content
/// taller than the area overflow and be clipped (CSS overflow: hidden)
/// instead of breaking the layout on small phones.
class FillOrClip extends SingleChildRenderObjectWidget {
  const FillOrClip({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFillOrClip();
}

class _RenderFillOrClip extends RenderProxyBox {
  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.biggest;
      return;
    }
    final w = constraints.maxWidth;
    c.layout(BoxConstraints(minWidth: w, maxWidth: w), parentUsesSize: true);
    if (c.size.height < constraints.maxHeight) c.layout(BoxConstraints.tightFor(width: w, height: constraints.maxHeight), parentUsesSize: true);
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _clip.layer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, super.paint, oldLayer: _clip.layer);
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// Green inner ring when a round is won (glowIn .25 s).
class CorrectGlow extends StatelessWidget {
  const CorrectGlow({super.key, this.inner = false});
  final bool inner; // the writing pad also glows inward

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        builder: (context, t, _) => Opacity(
          opacity: t,
          child: CustomPaint(painter: _InsetRingPainter(inner: inner)),
        ),
      ),
    );
  }
}

class _InsetRingPainter extends CustomPainter {
  const _InsetRingPainter({required this.inner});
  final bool inner;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(LikhoRadius.writingPad));
    if (inner) {
      canvas.save();
      canvas.clipRRect(r);
      canvas.drawRRect(
        r.inflate(30),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 60
          ..color = GameColors.successGlow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
      canvas.restore();
    }
    canvas.drawRRect(
      r.deflate(2.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = LikhoColors.success,
    );
  }

  @override
  bool shouldRepaint(_InsetRingPainter old) => old.inner != inner;
}

// ------------------------------------------------------------------ field

class _FieldView extends StatelessWidget {
  const _FieldView({required this.state, required this.round, required this.onPick, required this.time});
  final SessionState state;
  final PickRound round;
  final ValueChanged<int> onPick;
  final ValueNotifier<double> time;

  // item centres in % of the field (prototype posF / posG)
  static const _float = {
    2: [(28, 44), (72, 58)],
    3: [(20, 38), (50, 64), (80, 38)],
    4: [(19, 32), (41, 66), (62, 30), (82, 64)],
  };
  static const _grid = {
    2: [(29, 52), (71, 52)],
    3: [(18, 50), (50, 50), (82, 50)],
    4: [(28, 30), (72, 30), (28, 72), (72, 72)],
    5: [(20, 30), (50, 30), (80, 30), (33, 72), (67, 72)],
  };

  @override
  Widget build(BuildContext context) {
    final level = state.level;
    final shape = PickShape.resolve(round.shape ?? level.presentation.shape);
    final floats = PickShape.floating.contains(shape);
    final stage = level.presentation.stage;
    final hasStage = round.count != null || stage != null;
    final n = round.options.length;
    var pos = ((floats ? _float : _grid)[n] ?? _grid[3]!).map((p) => (p.$1.toDouble(), p.$2.toDouble())).toList();
    if (hasStage) pos = [for (final p in pos) (p.$1, 48 + p.$2 * .48)];
    if (shape == 'cloud' && n == 2) pos = hasStage ? [(30, 70), (70, 70)] : [(30, 42), (70, 64)];

    return SoftField(
      correct: state.correct,
      child: LayoutBuilder(
        builder: (context, box) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (round.count != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 22,
                  child: _Cupcakes(count: round.count!, cherries: state.correct),
                ),
              if (stage == 'house')
                Positioned(
                  left: box.maxWidth / 2 - 70,
                  top: 16,
                  child: _House(paint: ContentColors.byName(state.paint)),
                ),
              if (stage == 'stars')
                Positioned(
                  left: 0,
                  right: 0,
                  top: 26,
                  child: _StarStage(round: state.round, correct: state.correct),
                ),
              for (var i = 0; i < n; i++)
                _PositionedItem(
                  key: ValueKey('${round.id}-$i'),
                  centre: Offset(box.maxWidth * (i < pos.length ? pos[i].$1 : 50) / 100, box.maxHeight * (i < pos.length ? pos[i].$2 : 50) / 100),
                  index: i,
                  shape: shape,
                  floats: floats,
                  time: time,
                  state: state,
                  round: round,
                  onTap: () => onPick(i),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PositionedItem extends StatefulWidget {
  const _PositionedItem({
    super.key,
    required this.centre,
    required this.index,
    required this.shape,
    required this.floats,
    required this.time,
    required this.state,
    required this.round,
    required this.onTap,
  });

  final Offset centre;
  final int index;
  final String shape;
  final bool floats;
  final ValueNotifier<double> time;
  final SessionState state;
  final PickRound round;
  final VoidCallback onTap;

  @override
  State<_PositionedItem> createState() => _PositionedItemState();
}

class _PositionedItemState extends State<_PositionedItem> with SingleTickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(vsync: this);
  bool _pop = false; // true: correct pop, false: wrong wiggle

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.state.correct || widget.state.wrongOptions.contains(widget.index)) return;
    _pop = widget.round.isCorrect(widget.round.options[widget.index]);
    _fx
      ..duration = const Duration(milliseconds: 420)
      ..forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final i = widget.index;
    final o = widget.round.options[i];
    final color = ContentColors.byName(o.color) ?? ContentColors.items[i % 5];
    final ok = s.picked == i;
    final wrongTried = s.wrongOptions.contains(i);
    final hint = s.hint && widget.round.answer != null && o.label == widget.round.answer;
    final label = o.hideLabel ? '' : (widget.round.fixCapital && ok ? o.label[0].toUpperCase() + o.label.substring(1) : o.label);
    final balloonGone = ok && widget.shape == 'balloon';

    Widget? ring;
    if (ok) {
      ring = const _Ring(color: LikhoColors.success, glow: GameColors.successGlowStrong);
    } else if (hint) {
      ring = _PulseRing(time: widget.time);
    }

    Widget item = PickItemBody(shape: widget.shape, color: color, option: o, label: label, ring: ring);
    item = AnimatedBuilder(
      animation: _fx,
      child: item,
      builder: (context, child) {
        final v = _fx.value;
        if (!_fx.isAnimating) return child!;
        if (_pop) {
          final k = const Cubic(.34, 1.56, .64, 1).transform(v < .5 ? v * 2 : 2 - v * 2);
          return Transform.scale(scale: 1 + .25 * k, child: child);
        }
        const keys = [0.0, -12.0, 10.0, -6.0, 0.0];
        final q = (v * 4).floor().clamp(0, 3);
        final deg = keys[q] + (keys[q + 1] - keys[q]) * (v * 4 - q);
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      },
    );
    if (widget.floats) {
      // floatY (3.2 + i*.45) s, delay -0.7 i: up 14 px and rotate ±2°
      final period = 3.2 + i * .45;
      item = ValueListenableBuilder<double>(
        valueListenable: widget.time,
        child: item,
        builder: (context, t, child) {
          final p = ((t + .7 * i) / period) % 1.0;
          final k = const Cubic(.42, 0, .58, 1).transform(p < .5 ? p * 2 : 2 - p * 2);
          return Transform.translate(
            offset: Offset(0, -14 * k),
            child: Transform.rotate(angle: (-2 + 4 * k) * math.pi / 180, child: child),
          );
        },
      );
    }
    item = AnimatedOpacity(
      opacity: balloonGone ? 0 : (wrongTried && s.feedback != RoundFeedback.wrong ? .55 : 1),
      duration: const Duration(milliseconds: 300),
      curve: const Interval(.33, 1),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _tap, child: item),
    );
    return Positioned(
      left: widget.centre.dx,
      top: widget.centre.dy,
      child: FractionalTranslation(translation: const Offset(-.5, -.5), child: item),
    );
  }
}

/// ok ring: 4 px ring + soft glow, 8 px outside, radius 40 (glowIn .2 s).
class _Ring extends StatelessWidget {
  const _Ring({required this.color, required this.glow});
  final Color color, glow;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(color: glow, blurRadius: 30),
              BoxShadow(color: color, spreadRadius: 4),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), color: LikhoColors.clear),
          ),
        ),
      ),
    ),
  );
}

/// Hint: coral ring with a pulsing yellow glow (glowRing 1 s).
class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.time});
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, _) {
        final k = const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t % 1.0) - 1).abs());
        return CustomPaint(
          painter: _RingPainter(spread: 16 * k, glowAlpha: .35 * k),
        );
      },
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.spread, required this.glowAlpha});
  final double spread, glowAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(40));
    if (spread > 0) {
      canvas.drawRRect(
        r.inflate(4 + spread / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spread
          ..color = LikhoColors.primary.withValues(alpha: glowAlpha),
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
  bool shouldRepaint(_RingPainter old) => old.spread != spread || old.glowAlpha != glowAlpha;
}

// ------------------------------------------------------------------ stages

/// Paint Shop: the house wall takes the colour you picked.
class _House extends StatelessWidget {
  const _House({required this.paint});
  final Color? paint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 130,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, width: 140, height: 52, child: CustomPaint(painter: _RoofPainter())),
          Positioned(
            left: 14,
            top: 50,
            width: 112,
            height: 78,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: paint ?? LikhoColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: GameColors.ink15, width: 3, strokeAlign: BorderSide.strokeAlignInside),
              ),
            ),
          ),
          Positioned(
            left: 30,
            top: 66,
            width: 30,
            height: 28,
            child: Container(
              decoration: BoxDecoration(color: GameColors.window, borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: paint == null ? null : CustomPaint(size: const Size(14, 7), painter: _SmilePainter()),
            ),
          ),
          Positioned(
            left: 78,
            top: 84,
            width: 28,
            height: 44,
            child: Container(
              decoration: const BoxDecoration(
                color: GameColors.door,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoofPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()..addPolygon([Offset(size.width / 2, 0), Offset(size.width, size.height), Offset(0, size.height)], true),
    Paint()..color = GameColors.roof,
  );

  @override
  bool shouldRepaint(_RoofPainter old) => false;
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawArc(
    Rect.fromLTWH(0, -size.height, size.width, size.height * 2),
    .15,
    math.pi - .3,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = LikhoColors.ink,
  );

  @override
  bool shouldRepaint(_SmilePainter old) => false;
}

/// Cupcake Count: [count] cupcakes pop in; cherries drop on when you're right.
class _Cupcakes extends StatelessWidget {
  const _Cupcakes({required this.count, required this.cherries});
  final int count;
  final bool cherries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var k = 0; k < count; k++)
          TweenAnimationBuilder<double>(
            key: ValueKey('cake$k'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + k * 80),
            builder: (context, t, child) {
              final local = ((t * (350 + k * 80) - k * 80) / 350).clamp(0.0, 1.0);
              final s = local < .7 ? 1.1 * const Cubic(.34, 1.56, .64, 1).transform(local / .7) : 1.1 - .1 * ((local - .7) / .3);
              return Transform.scale(scale: s, child: child);
            },
            child: SizedBox(
              width: 52,
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(left: 4, right: 4, bottom: 0, height: 28, child: CustomPaint(painter: _CupPainter())),
                  Positioned(left: 0, right: 0, top: 10, height: 30, child: CustomPaint(painter: _FrostingPainter())),
                  if (cherries)
                    Positioned(
                      left: 19,
                      top: 0,
                      width: 14,
                      height: 14,
                      child: _DropIn(
                        child: Container(
                          decoration: const BoxDecoration(color: GameColors.cherry, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CupPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );
    canvas.save();
    canvas.clipRRect(r);
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 6, size.height), Paint()..color = GameColors.cupcakeA);
      canvas.drawRect(Rect.fromLTWH(x + 6, 0, 3, size.height), Paint()..color = GameColors.cupcakeB);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CupPainter old) => false;
}

class _FrostingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: const Radius.circular(26),
      topRight: const Radius.circular(26),
      bottomLeft: const Radius.circular(10),
      bottomRight: const Radius.circular(10),
    );
    final p = Path()..addRRect(r);
    canvas.drawPath(p, Paint()..color = GameColors.frosting);
    canvas.drawPath(Path.combine(PathOperation.difference, p, p.shift(const Offset(0, -5))), Paint()..color = GameColors.frostingShade);
  }

  @override
  bool shouldRepaint(_FrostingPainter old) => false;
}

/// dropIn .4 s: falls from 320 px above, squashes, settles.
class _DropIn extends StatelessWidget {
  const _DropIn({required this.child, this.duration = const Duration(milliseconds: 400), this.delay = Duration.zero});
  final Widget child;
  final Duration duration, delay;

  @override
  Widget build(BuildContext context) {
    final total = duration + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      child: child,
      builder: (context, t, child) {
        final p = ((t * total.inMilliseconds - delay.inMilliseconds) / duration.inMilliseconds).clamp(0.0, 1.0);
        double y, sy = 1;
        if (p < .6) {
          y = -320 * (1 - p / .6);
          if (p > .5) sy = 1 - .14 * ((p - .5) / .1);
        } else if (p < .8) {
          y = -10 * ((p - .6) / .2);
          sy = .86 + .14 * ((p - .6) / .2);
        } else {
          y = -10 * (1 - (p - .8) / .2);
        }
        return Opacity(
          opacity: p > 0 ? 1 : 0,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.scale(scaleY: sy, child: child),
          ),
        );
      },
    );
  }
}

/// Star Questions: three big stars light up as rounds are answered.
class _StarStage extends StatelessWidget {
  const _StarStage({required this.round, required this.correct});
  final int round;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final k = round % 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var j = 0; j < 3; j++) ...[
          if (j > 0) const SizedBox(width: 18),
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: (k > j || (k == j && correct)) ? LikhoColors.primary : GameColors.ink15),
            duration: const Duration(milliseconds: 400),
            builder: (context, c, _) => Icon(
              Symbols.star_rounded,
              size: 64,
              fill: 1,
              opticalSize: 48,
              color: c,
              shadows: const [Shadow(color: GameColors.glowYellowSoft, blurRadius: 20)],
            ),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ patient

/// Doctor Pencil: a child figure with five tappable spots.
class _PatientView extends StatelessWidget {
  const _PatientView({required this.state, required this.round, required this.onPick});
  final SessionState state;
  final PickRound round;
  final ValueChanged<int> onPick;

  static const _spots = {'nose': Offset(150, 122), 'eye': Offset(176, 96), 'ear': Offset(244, 106), 'mouth': Offset(150, 156), 'hand': Offset(262, 268)};

  @override
  Widget build(BuildContext context) {
    Widget blob(double l, double t, double w, double h, Color c, {BorderRadius? r, BoxShape shape = BoxShape.rectangle, List<BoxShadow>? sh}) => Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c, borderRadius: r, shape: shape, boxShadow: sh),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(LikhoRadius.writingPad),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [GameColors.clinicTop, LikhoColors.surface]),
              ),
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, height: 70, child: ColoredBox(color: GameColors.clinicFloor)),
          Center(
            child: SizedBox(
              width: 300,
              height: 380,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  blob(
                    52,
                    176,
                    196,
                    190,
                    GameColors.shirt,
                    r: const BorderRadius.vertical(top: Radius.circular(70), bottom: Radius.circular(30)),
                  ),
                  blob(240, 240, 44, 44, GameColors.hand, shape: BoxShape.circle),
                  blob(16, 240, 44, 44, GameColors.hand, shape: BoxShape.circle),
                  Positioned(
                    left: 44,
                    top: 88,
                    width: 34,
                    height: 40,
                    child: Container(
                      decoration: const ShapeDecoration(color: GameColors.ear, shape: OvalBorder()),
                    ),
                  ),
                  Positioned(
                    left: 222,
                    top: 88,
                    width: 34,
                    height: 40,
                    child: Container(
                      decoration: const ShapeDecoration(color: GameColors.ear, shape: OvalBorder()),
                    ),
                  ),
                  Positioned(left: 60, top: 18, width: 180, height: 180, child: CustomPaint(painter: _HeadPainter())),
                  blob(
                    64,
                    14,
                    172,
                    62,
                    GameColors.hair,
                    r: const BorderRadius.vertical(top: Radius.circular(90), bottom: Radius.circular(30)),
                  ),
                  Positioned(
                    left: 115,
                    top: 88,
                    width: 16,
                    height: 18,
                    child: Container(
                      decoration: const ShapeDecoration(color: LikhoColors.ink, shape: OvalBorder()),
                    ),
                  ),
                  Positioned(
                    left: 169,
                    top: 88,
                    width: 16,
                    height: 18,
                    child: Container(
                      decoration: const ShapeDecoration(color: LikhoColors.ink, shape: OvalBorder()),
                    ),
                  ),
                  Positioned(
                    left: 140,
                    top: 110,
                    width: 20,
                    height: 22,
                    child: Container(
                      decoration: const ShapeDecoration(color: GameColors.nose, shape: OvalBorder()),
                    ),
                  ),
                  Positioned(left: 132, top: 146, width: 36, height: 16, child: CustomPaint(painter: _MouthPainter())),
                  Positioned(
                    left: 98,
                    top: 128,
                    width: 20,
                    height: 10,
                    child: Container(
                      decoration: const ShapeDecoration(color: GameColors.blush, shape: OvalBorder()),
                    ),
                  ),
                  Positioned(
                    left: 182,
                    top: 128,
                    width: 20,
                    height: 10,
                    child: Container(
                      decoration: const ShapeDecoration(color: GameColors.blush, shape: OvalBorder()),
                    ),
                  ),
                  for (var i = 0; i < round.options.length; i++) _spot(i),
                ],
              ),
            ),
          ),
          if (state.correct) const Positioned.fill(child: CorrectGlow()),
        ],
      ),
    );
  }

  Widget _spot(int i) {
    final o = round.options[i];
    final p = _spots[o.label] ?? Offset.zero;
    final ok = state.picked == i;
    final hint = state.hint && o.label == round.answer;
    return Positioned(
      left: p.dx - 22,
      top: p.dy - 22,
      width: 44,
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok
                ? GameColors.successTint
                : hint
                ? GameColors.hintTint
                : GameColors.white01,
            boxShadow: [
              BoxShadow(
                color: ok
                    ? LikhoColors.success
                    : hint
                    ? LikhoColors.hint
                    : GameColors.ink00,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()..addOval(Offset.zero & size);
    canvas.drawPath(p, Paint()..color = GameColors.face);
    canvas.drawPath(Path.combine(PathOperation.difference, p, p.shift(const Offset(-10, -10))), Paint()..color = GameColors.faceShade);
  }

  @override
  bool shouldRepaint(_HeadPainter old) => false;
}

class _MouthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // border-bottom 5 px with 0 0 20px 20px corners
    final r = RRect.fromRectAndCorners(Offset.zero & size, bottomLeft: const Radius.circular(20), bottomRight: const Radius.circular(20));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRRect(r), Path()..addRRect(r.shift(const Offset(0, -5)))),
      Paint()..color = GameColors.lips,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MouthPainter old) => false;
}

// ------------------------------------------------------------------ flow

/// Fix-It Pencil: a sentence on lined paper; tap the word that needs a
/// capital. A full stop drops in when fixed. Pencil watches in blue, thinking,
/// with round glasses (prototype).
class _FlowView extends StatefulWidget {
  const _FlowView({required this.state, required this.round, required this.onPick});
  final SessionState state;
  final PickRound round;
  final ValueChanged<int> onPick;

  @override
  State<_FlowView> createState() => _FlowViewState();
}

class _FlowViewState extends State<_FlowView> {
  final MascotController _thinker = MascotController()
    ..setBodyColor(LikhoColors.secondary)
    ..wear(MascotAccessory.roundGlasses)
    ..play(MascotState.think);

  @override
  void dispose() {
    _thinker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final r = widget.round;
    return SoftField(
      correct: s.correct,
      child: FillOrClip(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 88,
                height: 120,
                child: OverflowBox(maxWidth: 100, child: PencilMascot(controller: _thinker, size: 120)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                decoration: BoxDecoration(
                  color: GameColors.paperNote,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: GameColors.ink06, offset: Offset(0, 6)),
                    BoxShadow(color: GameColors.ink08, offset: Offset(0, 12), blurRadius: 30),
                  ],
                ),
                child: CustomPaint(
                  painter: _RuledPainter(),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < r.options.length; i++) _token(i),
                      if (r.fixCapital && s.picked != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: _DropIn(
                            duration: const Duration(milliseconds: 450),
                            delay: const Duration(milliseconds: 200),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(color: LikhoColors.ink, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _token(int i) {
    final s = widget.state;
    final r = widget.round;
    final o = r.options[i];
    final ok = s.picked == i;
    final hint = s.hint && o.label == r.answer;
    final text = r.fixCapital && ok ? o.label[0].toUpperCase() + o.label.substring(1) : o.label;
    return GestureDetector(
      onTap: () => widget.onPick(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: const BoxConstraints(minWidth: 56),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: ok
              ? GameColors.successPale
              : hint
              ? GameColors.hintPale
              : LikhoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ok
                ? LikhoColors.success
                : hint
                ? LikhoColors.hint
                : GameColors.ink10,
            width: 3,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: const [BoxShadow(color: GameColors.ink06, offset: Offset(0, 4))],
        ),
        child: Center(widthFactor: 1, child: Text(text, style: LikhoFonts.letter(size: 32).copyWith(height: 1))),
      ),
    );
  }
}

/// repeating-linear-gradient(180deg, transparent 0 46px, blue 18% 46px 48px)
class _RuledPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = GameColors.ruled;
    for (var y = 46.0 - 22; y < size.height; y += 48) {
      canvas.drawRect(Rect.fromLTWH(-18, y, size.width + 36, 2), p);
    }
  }

  @override
  bool shouldRepaint(_RuledPainter old) => false;
}
