import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/illustration.dart';
import 'pick_round_view.dart';

/// "sort" rounds: things to sort on top, where they go at the bottom.
///
/// * one bin: the hungry monster with its letter on its belly. Feed it the
///   things that go there (drag one in, or just tap it); it chews. A wrong
///   one: it shakes its head and the thing jumps back (a mistake).
/// * two or more bins: baskets with a sign. Drag each thing into its
///   basket (or tap it, then tap the basket); sorted things peek over the
///   rim.
///
/// A thing shows its picture, or its label when it has none.
class SortRoundView extends StatefulWidget {
  const SortRoundView({super.key, required this.state, required this.round, required this.onSort, required this.time});
  final SessionState state;
  final SortRound round;

  /// (item, bin) -> true when it goes there.
  final bool Function(int item, int bin) onSort;
  final ValueNotifier<double> time;

  @override
  State<SortRoundView> createState() => _SortRoundViewState();
}

class _SortRoundViewState extends State<SortRoundView> {
  int? _selected; // tapped, waiting for a basket
  int? _hover; // bin a thing is dragged over
  int? _bounced; // the thing that was sent back
  double _bouncedAt = -9, _ateAt = -9, _yuckAt = -9;

  SortRound get round => widget.round;

  void _drop(int item, int bin) {
    final now = widget.time.value;
    final ok = widget.onSort(item, bin);
    setState(() {
      _selected = null;
      _hover = null;
      if (ok) {
        _ateAt = now;
      } else {
        _bounced = item;
        _bouncedAt = now;
        _yuckAt = now;
      }
    });
  }

  void _tapItem(int item) {
    if (widget.state.correct) return;
    if (round.monster) {
      _drop(item, 0);
    } else {
      setState(() => _selected = _selected == item ? null : item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final left = [for (var i = 0; i < round.items.length; i++) i].where((i) => !s.found.contains(i)).toList();
    // after a mistake: one thing still to sort pulses
    final hintAt = s.hint ? left.where((i) => round.items[i].bin != null).firstOrNull : null;
    return SoftField(
      correct: s.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: LayoutBuilder(
          builder: (context, box) {
            final binH = math.min(box.maxHeight * .46, 190.0);
            final token = math.min(84.0, math.min((box.maxWidth - 30) / 4, (box.maxHeight - binH - 20) / 2)).clamp(52.0, 84.0);
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        // a sorted thing leaves its place empty: the others never move under a finger
                        for (var i = 0; i < round.items.length; i++)
                          s.found.contains(i) ? SizedBox.square(dimension: token) : _draggable(i, token, hint: hintAt == i),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: binH,
                  child: round.monster
                      ? Center(child: _target(0, AspectRatio(aspectRatio: 1.1, child: _monster())))
                      : Row(
                          children: [
                            for (var b = 0; b < round.bins.length; b++) ...[
                              if (b > 0) const SizedBox(width: 12),
                              Expanded(child: _target(b, _basket(b))),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _target(int bin, Widget child) => DragTarget<int>(
    onWillAcceptWithDetails: (_) {
      if (_hover != bin) setState(() => _hover = bin);
      return !widget.state.correct;
    },
    onLeave: (_) => setState(() => _hover = null),
    onAcceptWithDetails: (d) => _drop(d.data, bin),
    builder: (context, _, _) => GestureDetector(
      key: ValueKey('${round.id}-bin$bin'),
      behavior: HitTestBehavior.opaque,
      onTap: _selected == null ? null : () => _drop(_selected!, bin),
      child: child,
    ),
  );

  Widget _draggable(int i, double size, {required bool hint}) {
    final token = _Token(thing: round.items[i], size: size, selected: _selected == i, hint: hint, time: widget.time);
    final bounce = _bounced == i
        ? ValueListenableBuilder<double>(
            valueListenable: widget.time,
            child: token,
            builder: (context, now, child) {
              final since = now - _bouncedAt;
              if (since > .5) return child!;
              return Transform.translate(offset: Offset(math.sin(since * 40) * 8 * (1 - since / .5), 0), child: child);
            },
          )
        : token;
    return Draggable<int>(
      data: i,
      maxSimultaneousDrags: widget.state.correct ? 0 : 1,
      feedback: Transform.scale(scale: 1.12, child: _Token(thing: round.items[i], size: size, selected: true, hint: false, time: widget.time)),
      childWhenDragging: Opacity(opacity: .25, child: token),
      onDragEnd: (_) => setState(() => _hover = null),
      child: GestureDetector(key: ValueKey('${round.id}-i$i'), onTap: () => _tapItem(i), child: bounce),
    );
  }

  Widget _monster() => ValueListenableBuilder<double>(
    valueListenable: widget.time,
    builder: (context, now, _) {
      final eat = now - _ateAt, yuck = now - _yuckAt;
      var open = _hover == 0 ? 1.0 : .15;
      var angle = 0.0;
      if (eat < .7) open = (math.sin(eat * math.pi * 4).abs()) * .55;
      if (yuck < .7) {
        angle = math.sin(yuck * 28) * .09 * (1 - yuck / .7);
        open = .3;
      }
      final blink = (now % 3.4) > 3.25;
      return Transform.rotate(
        angle: angle,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _MonsterPainter(open: open, blink: blink, yuck: yuck < .7, bob: math.sin(now * 2.4))),
                ),
                // its letter (or picture) on the belly
                Positioned(
                  left: w * .3,
                  right: w * .3,
                  top: h * .7,
                  bottom: h * .04,
                  child: _Sign(thing: round.bins[0]),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  Widget _basket(int b) {
    final s = widget.state;
    final inside = [for (var i = 0; i < round.items.length; i++) i].where((i) => s.found.contains(i) && round.items[i].bin == b).toList();
    return AnimatedScale(
      scale: _hover == b ? 1.06 : 1,
      duration: const Duration(milliseconds: 160),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          const mini = 36.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // sorted things peek over the rim
              for (final (k, i) in inside.indexed)
                Positioned(
                  left: w / 2 - mini / 2 + (k - (inside.length - 1) / 2) * mini * .62,
                  top: h * .25 - mini * .85,
                  width: mini,
                  height: mini,
                  child: _Token(thing: round.items[i], size: mini, selected: false, hint: false, time: widget.time),
                ),
              Positioned.fill(child: CustomPaint(painter: _BasketPainter(lit: _hover == b || _selected != null))),
              Positioned(
                left: w * .24,
                right: w * .24,
                top: h * .44,
                bottom: h * .1,
                child: _Sign(thing: round.bins[b]),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A thing to sort: a white tile with its picture, or its label.
class _Token extends StatelessWidget {
  const _Token({required this.thing, required this.size, required this.selected, required this.hint, required this.time});
  final SortThing thing;
  final double size;
  final bool selected, hint;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final pic = thing.picture;
    final r = size * .24;
    Widget tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: LikhoColors.surface,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: selected ? LikhoColors.secondary : GameColors.ink08, width: size > 50 ? 3 : 2, strokeAlign: BorderSide.strokeAlignInside),
        boxShadow: const [BoxShadow(color: GameColors.ink10, offset: Offset(0, 4))],
      ),
      padding: EdgeInsets.all(size * .08),
      child: Center(
        child: pic != null
            ? Illustration(picture: pic, width: size * .82, height: size * .82, radius: r * .6, padding: 2)
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(thing.label, style: LikhoFonts.letter(size: size * (thing.label.length > 2 ? .32 : .5)).copyWith(height: 1)),
              ),
      ),
    );
    if (hint) {
      tile = ValueListenableBuilder<double>(
        valueListenable: time,
        child: tile,
        builder: (context, t, child) {
          final k = const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t % 1.0) - 1).abs());
          return Transform.scale(scale: 1 + .08 * k, child: child);
        },
      );
    }
    return tile;
  }
}

/// A bin's sign: its letter in big type, or its picture.
class _Sign extends StatelessWidget {
  const _Sign({required this.thing});
  final SortThing thing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final pic = thing.picture;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: LikhoColors.surface,
          borderRadius: BorderRadius.circular(math.min(box.maxWidth, box.maxHeight) * .3),
          boxShadow: const [BoxShadow(color: GameColors.black12, offset: Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Center(
            child: pic != null
                ? Illustration(picture: pic, width: box.maxWidth - 8, height: box.maxHeight - 8, radius: 8, padding: 1)
                : FittedBox(fit: BoxFit.scaleDown, child: Text(thing.label, style: LikhoFonts.letter(size: 40).copyWith(height: 1))),
          ),
        ),
      );
    },
  );
}

/// The hungry monster: a round purple body, two horns, big eyes and a mouth
/// that opens [open] (0..1) when food comes near; [yuck] sticks its tongue out.
class _MonsterPainter extends CustomPainter {
  const _MonsterPainter({required this.open, required this.blink, required this.yuck, required this.bob});
  final double open, bob;
  final bool blink, yuck;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()..isAntiAlias = true;
    canvas.translate(0, bob * h * .015);
    // feet and horns behind the body
    p.color = GameColors.monsterDeep;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .3, h * .96), width: w * .26, height: h * .1), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .7, h * .96), width: w * .26, height: h * .1), p);
    for (final x in [.26, .74]) {
      final horn = Path()
        ..moveTo(w * (x - .07), h * .2)
        ..quadraticBezierTo(w * (x - .02), h * .02, w * (x + (x < .5 ? -.04 : .04)), h * .02)
        ..quadraticBezierTo(w * (x + .02), h * .1, w * (x + .07), h * .2)
        ..close();
      canvas.drawPath(horn, p);
    }
    // body
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * .04, h * .12, w * .92, h * .84),
      topLeft: Radius.circular(w * .46),
      topRight: Radius.circular(w * .46),
      bottomLeft: Radius.circular(w * .3),
      bottomRight: Radius.circular(w * .3),
    );
    canvas.drawRRect(body.shift(Offset(0, h * .03)), p..color = GameColors.monsterDeep);
    canvas.drawRRect(body, p..color = GameColors.monster);
    canvas.drawOval(Rect.fromLTWH(w * .2, h * .17, w * .3, h * .12), p..color = GameColors.white20);
    // eyes
    for (final x in [.34, .66]) {
      final c = Offset(w * x, h * .34);
      final r = w * .12;
      if (blink) {
        canvas.drawLine(
          c - Offset(r, 0),
          c + Offset(r, 0),
          Paint()
            ..strokeWidth = w * .025
            ..strokeCap = StrokeCap.round
            ..color = GameColors.monsterMouth,
        );
        continue;
      }
      canvas.drawCircle(c, r, p..color = LikhoColors.surface);
      canvas.drawCircle(c + Offset(0, r * .2), r * .5, p..color = LikhoColors.ink);
      canvas.drawCircle(c + Offset(-r * .15, 0), r * .17, p..color = LikhoColors.surface);
    }
    // mouth
    final mw = w * .46, mh = h * (.04 + .24 * open);
    final mouth = RRect.fromRectAndCorners(
      Rect.fromCenter(center: Offset(w * .5, h * .55 + mh / 2), width: mw, height: mh),
      topLeft: Radius.circular(mh * .3),
      topRight: Radius.circular(mh * .3),
      bottomLeft: Radius.circular(mw * .5),
      bottomRight: Radius.circular(mw * .5),
    );
    canvas.drawRRect(mouth, p..color = GameColors.monsterMouth);
    if (open > .2 || yuck) {
      canvas.save();
      canvas.clipRRect(yuck ? mouth.inflate(h * .2) : mouth);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * .5, mouth.bottom + (yuck ? h * .04 : 0)), width: mw * .5, height: math.max(mh * .7, h * .1)), p..color = GameColors.monsterTongue);
      canvas.restore();
    }
    // two teeth
    p.color = LikhoColors.surface;
    for (final x in [.42, .58]) {
      final t = Path()
        ..moveTo(w * (x - .04), mouth.top)
        ..lineTo(w * (x + .04), mouth.top)
        ..lineTo(w * x, mouth.top + math.min(mh * .9, h * .06))
        ..close();
      canvas.drawPath(t, p);
    }
  }

  @override
  bool shouldRepaint(_MonsterPainter old) => old.open != open || old.blink != blink || old.yuck != yuck || old.bob != bob;
}

/// A woven basket with a rim; brighter when something can be dropped in.
class _BasketPainter extends CustomPainter {
  const _BasketPainter({required this.lit});
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path()
      ..moveTo(w * .04, h * .32)
      ..lineTo(w * .96, h * .32)
      ..lineTo(w * .86, h * .94)
      ..quadraticBezierTo(w * .85, h, w * .78, h)
      ..lineTo(w * .22, h)
      ..quadraticBezierTo(w * .15, h, w * .14, h * .94)
      ..close();
    canvas.drawPath(body.shift(Offset(0, h * .025)), Paint()..color = GameColors.black12);
    canvas.drawPath(body, Paint()..color = lit ? Color.lerp(GameColors.basketA, LikhoColors.primary, .35)! : GameColors.basketA);
    canvas.save();
    canvas.clipPath(body);
    final weave = Paint()
      ..color = GameColors.basketB
      ..strokeWidth = 3;
    for (var y = h * .42; y < h; y += h * .12) {
      canvas.drawLine(Offset(0, y), Offset(w, y), weave);
    }
    for (var x = -w * .1; x < w * 1.1; x += w * .12) {
      canvas.drawLine(Offset(x, h * .32), Offset(x + w * .04, h), weave..strokeWidth = 2);
    }
    canvas.restore();
    // rim
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, h * .24, w, h * .12), Radius.circular(h * .06)),
      Paint()..color = GameColors.basketDeep,
    );
  }

  @override
  bool shouldRepaint(_BasketPainter old) => old.lit != lit;
}
