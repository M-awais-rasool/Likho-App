import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/course_models.dart';
import '../../design/tokens.dart';
import '../../game/level_session.dart';
import '../gameplay/widgets/illustration.dart';
import 'boss_rounds.dart';
import 'boss_stage.dart';

/// A little shake for [age] seconds after a wrong tap (0 when none).
double _shake(double? age) => age == null || age > .4 ? 0 : math.sin(age * 40) * 7 * (1 - age / .4);

/// Stars counting what is found so far: "★ ★ ☆ ☆".
class _StarCount extends StatelessWidget {
  const _StarCount({required this.found, required this.of, this.light = true});
  final int found, of;
  final bool light;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var k = 0; k < of; k++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Symbols.star_rounded,
            size: of > 8 ? 18 : 24,
            fill: 1,
            color: k < found ? LikhoColors.primary : (light ? Colors.white.withValues(alpha: .3) : LikhoColors.inkFaint),
          ),
        ),
    ],
  );
}

// ================================================================== dream hunt

/// Boss "hunt" rounds: the boss dreams of letters floating on little clouds
/// in a night sky. Tap every [HuntRound.target]: it turns into a golden star.
/// A wrong cloud shakes; after a mistake one still to find gets a ring.
class DreamHuntView extends StatefulWidget {
  const DreamHuntView({super.key, required this.state, required this.round, required this.onTap, required this.time});
  final SessionState state;
  final HuntRound round;
  final ValueChanged<int> onTap;
  final ValueNotifier<double> time;

  @override
  State<DreamHuntView> createState() => _DreamHuntViewState();
}

class _DreamHuntViewState extends State<DreamHuntView> {
  final _tapAt = <int, double>{};

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final r = widget.round;
    final n = r.grid.length;
    final cols = n <= 9 ? 3 : (n <= 16 ? 4 : 5);
    final rows = (n / cols).ceil();
    final hintAt = s.hint ? [for (var i = 0; i < n; i++) i].where((i) => r.grid[i] == r.target && !s.found.contains(i)).firstOrNull : null;
    return DreamField(
      night: true,
      time: widget.time,
      correct: s.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            _StarCount(found: s.found.length, of: r.count),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  const gap = 8.0;
                  final side = math.min((box.maxWidth - gap * (cols - 1)) / cols, (box.maxHeight - gap * (rows - 1)) / rows);
                  return Center(
                    child: ValueListenableBuilder<double>(
                      valueListenable: widget.time,
                      builder: (context, t, _) => Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        alignment: WrapAlignment.center,
                        children: [for (var i = 0; i < n; i++) _cell(i, side, t, hintAt == i)],
                      ),
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

  Widget _cell(int i, double side, double t, bool hint) {
    final s = widget.state;
    final found = s.found.contains(i);
    final wrong = s.wrongOptions.contains(i);
    final age = _tapAt[i] == null ? null : t - _tapAt[i]!;
    final bob = math.sin(t * 1.6 + i * .9) * 3;
    final pop = found && age != null && age < .35 ? 1 + .3 * math.sin(age / .35 * math.pi) : 1.0;
    return SizedBox(
      key: ValueKey('${widget.round.id}-$i'),
      width: side,
      height: side,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: s.correct || found || wrong
            ? null
            : (_) {
                _tapAt[i] = widget.time.value;
                widget.onTap(i);
              },
        child: Transform.translate(
          offset: Offset(wrong ? _shake(age) : 0, found ? 0 : bob),
          child: Transform.scale(
            scale: pop,
            child: CustomPaint(
              painter: _DreamCellPainter(found: found, wrong: wrong, ring: hint ? 10 * dreamPulse(t) : null, twinkle: t + i),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(side * .22),
                  child: FittedBox(
                    child: Text(widget.round.grid[i], style: dreamLetter(40, found ? LikhoColors.ink : Colors.white.withValues(alpha: wrong ? .45 : 1))),
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

/// A soft cloud puff, or (found) a golden star with a glow.
class _DreamCellPainter extends CustomPainter {
  const _DreamCellPainter({required this.found, required this.wrong, required this.ring, required this.twinkle});
  final bool found, wrong;
  final double? ring;
  final double twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2;
    final spread = ring;
    if (spread != null) {
      canvas.drawCircle(
        c,
        r - 2 + spread / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spread
          ..color = LikhoColors.primary.withValues(alpha: .35),
      );
      canvas.drawCircle(
        c,
        r - 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = LikhoColors.hint,
      );
    }
    if (found) {
      canvas.drawCircle(c, r * .95, Paint()..color = StageSky.sunGlow);
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? r * .92 : r * .55;
        final a = -math.pi / 2 + i * math.pi / 5;
        final q = c + Offset(math.cos(a), math.sin(a)) * rr;
        i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
      }
      p.close();
      canvas.drawPath(p, Paint()..color = LikhoColors.primary);
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = LikhoColors.primaryDeep,
      );
      return;
    }
    final col = wrong ? LikhoColors.hint.withValues(alpha: .35) : Colors.white.withValues(alpha: .16);
    final puff = Path()
      ..addOval(Rect.fromCircle(center: c + Offset(0, r * .12), radius: r * .62))
      ..addOval(Rect.fromCircle(center: c + Offset(-r * .42, r * .22), radius: r * .4))
      ..addOval(Rect.fromCircle(center: c + Offset(r * .42, r * .2), radius: r * .42))
      ..addOval(Rect.fromCircle(center: c + Offset(-r * .1, -r * .3), radius: r * .45));
    canvas.drawPath(puff, Paint()..color = col);
    // a tiny twinkle on the cloud
    final a = .4 + .6 * (.5 + .5 * math.sin(twinkle * 3));
    canvas.drawCircle(c + Offset(r * .55, -r * .5), 2.2, Paint()..color = Colors.white.withValues(alpha: a));
  }

  @override
  bool shouldRepaint(_DreamCellPainter old) => true;
}

// ================================================================== dream cards

/// Boss "match" rounds: memory cards with a moon-and-stars back. All show
/// for a moment, then turn over; find the pairs. A pair stays up with a
/// golden glow; two that are not a pair turn back down (not a mistake).
class DreamCardsView extends StatefulWidget {
  const DreamCardsView({super.key, required this.state, required this.round, required this.onFlip});
  final SessionState state;
  final MatchRound round;
  final ValueChanged<int> onFlip;

  static const peek = Duration(milliseconds: 2400);

  @override
  State<DreamCardsView> createState() => _DreamCardsViewState();
}

class _DreamCardsViewState extends State<DreamCardsView> {
  bool _peek = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(DreamCardsView.peek, () {
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
    return DreamField(
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
                      key: ValueKey('${widget.round.id}-card$p'),
                      width: math.min(w, h / 1.1),
                      height: h,
                      child: _DreamCard(
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

class _DreamCard extends StatelessWidget {
  const _DreamCard({required this.side, required this.up, required this.matched, required this.onTap});
  final MatchSide side;
  final bool up, matched;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: up ? null : onTap,
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: up ? 1 : 0),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        final front = t >= .5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 1 / 900)
            ..rotateY((front ? 1 - t : t) * math.pi),
          child: front ? _front() : _back(),
        );
      },
    ),
  );

  Widget _back() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [DreamColors.nightTop, DreamColors.nightBottom]),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .6), width: 3, strokeAlign: BorderSide.strokeAlignInside),
      boxShadow: const [BoxShadow(color: DreamColors.moonEdge, offset: Offset(0, 5))],
    ),
    child: const CustomPaint(painter: _MoonBackPainter()),
  );

  Widget _front() => LayoutBuilder(
    builder: (context, box) {
      final pic = side.picture;
      final text = side.text ?? '';
      return DecoratedBox(
        decoration: BoxDecoration(
          color: matched ? const Color(0xFFFFF4CF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: matched ? LikhoColors.primary : LikhoColors.inkFaint, width: 3, strokeAlign: BorderSide.strokeAlignInside),
          boxShadow: [
            BoxShadow(color: matched ? LikhoColors.primaryDeep : LikhoColors.shadowSoft, offset: const Offset(0, 5)),
            if (matched) const BoxShadow(color: StageSky.sunGlow, blurRadius: 14),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Center(
            child: pic != null
                ? Illustration(picture: pic, width: box.maxWidth - 16, height: box.maxHeight - 16, radius: 12, padding: 2)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(text, style: dreamLetter(text.length > 2 ? 30 : 46, LikhoColors.ink)),
                  ),
          ),
        ),
      );
    },
  );
}

/// A crescent moon and three stars on a card's back.
class _MoonBackPainter extends CustomPainter {
  const _MoonBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * .22;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c + Offset(r * .45, -r * .3), radius: r * .85)),
    );
    canvas.drawPath(moon, Paint()..color = StageSky.moon);
    for (final (dx, dy, s) in const [(.22, .2, 4.0), (.78, .28, 3.0), (.72, .8, 3.5)]) {
      canvas.drawCircle(Offset(size.width * dx, size.height * dy), s, Paint()..color = Colors.white.withValues(alpha: .85));
    }
  }

  @override
  bool shouldRepaint(_MoonBackPainter old) => false;
}

// ================================================================== wake-up word

/// Boss "order" rounds: the parts (letters, words) ride on little pillows;
/// tap them in order and they jump onto the wake-up banner over the field.
/// A wrong pillow shakes; after a mistake the next one gets a ring.
class WakeWordView extends StatefulWidget {
  const WakeWordView({super.key, required this.state, required this.round, required this.onTile, required this.time});
  final SessionState state;
  final OrderRound round;
  final ValueChanged<int> onTile;
  final ValueNotifier<double> time;

  @override
  State<WakeWordView> createState() => _WakeWordViewState();
}

class _WakeWordViewState extends State<WakeWordView> {
  final _tapAt = <int, double>{};

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final r = widget.round;
    final order = s.tiles; // position -> index in the right order
    final words = r.tiles.any((x) => x.length > 2);
    final next = s.placed.length;
    final hintPos = s.hint && !s.correct ? [for (var p = 0; p < order.length; p++) p].where((p) => order[p] == next).firstOrNull : null;
    final style = dreamLetter(words ? 24 : 34, LikhoColors.ink);
    return DreamField(
      correct: s.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          children: [
            // the banner with the slots
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [StageSky.meterFrom, StageSky.meterTo]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: DreamColors.moonEdge, offset: Offset(0, 4))],
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var k = 0; k < r.tiles.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      constraints: BoxConstraints(minWidth: words ? 44 : 40, minHeight: words ? 40 : 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: k < next ? Colors.white : Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: .7), width: 2),
                      ),
                      child: Text(k < next ? r.tiles[k] : '', textAlign: TextAlign.center, style: style),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.time,
                  builder: (context, t, _) => Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 12,
                    children: [
                      for (var p = 0; p < order.length; p++)
                        if (!s.placed.contains(p)) _tile(p, r.tiles[order[p]], style, t, hintPos == p, words),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(int p, String text, TextStyle style, double t, bool hint, bool words) {
    final age = _tapAt[p] == null ? null : t - _tapAt[p]!;
    Widget pillow = CustomPaint(
      painter: PillowPainter(DreamColors.pillows[p % DreamColors.pillows.length]),
      child: Container(
        constraints: BoxConstraints(minWidth: words ? 84 : 88, minHeight: words ? 66 : 84),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(text, textAlign: TextAlign.center, style: style),
        ),
      ),
    );
    if (hint) {
      pillow = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: -7, top: -7, right: -7, bottom: -7, child: CustomPaint(painter: RoundRing(LikhoColors.hint, 10 * dreamPulse(t)))),
          pillow,
        ],
      );
    }
    return GestureDetector(
      key: ValueKey('${widget.round.id}-tile$p'),
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.state.correct
          ? null
          : (_) {
              _tapAt[p] = widget.time.value;
              widget.onTile(p);
            },
      child: Transform.translate(
        offset: Offset(_shake(age), math.sin(t * 1.8 + p) * 2.5),
        child: Transform.rotate(angle: math.sin(t * 1.2 + p * 2) * .04, child: pillow),
      ),
    );
  }
}

// ================================================================== pillow piles

/// Boss "sort" rounds.
///
/// Two or more bins: one thing floats in the middle at a time; tap the
/// pillow pile it belongs on and it flies there. One bin (the hungry
/// monster): a midnight snack, tap every thing the boss can eat and it flies
/// up to the boss; tapping one it cannot eat is a mistake.
class PillowPilesView extends StatefulWidget {
  const PillowPilesView({super.key, required this.state, required this.round, required this.onSort, required this.time});
  final SessionState state;
  final SortRound round;
  final bool Function(int item, int bin) onSort;
  final ValueNotifier<double> time;

  @override
  State<PillowPilesView> createState() => _PillowPilesViewState();
}

class _PillowPilesViewState extends State<PillowPilesView> {
  final _tapAt = <int, double>{}; // item -> time it was tapped
  int? _shakeItem;
  double? _shakeAt;

  SortRound get r => widget.round;

  /// The next thing to sort (in its order), or null when all are.
  int? get _current {
    for (var i = 0; i < r.items.length; i++) {
      if (r.items[i].bin != null && !widget.state.found.contains(i)) return i;
    }
    return null;
  }

  void _drop(int item, int bin) {
    final now = widget.time.value;
    if (widget.onSort(item, bin)) {
      setState(() => _tapAt[item] = now);
    } else {
      setState(() {
        _shakeItem = item;
        _shakeAt = now;
      });
    }
  }

  @override
  Widget build(BuildContext context) => DreamField(
    correct: widget.state.correct,
    child: ValueListenableBuilder<double>(valueListenable: widget.time, builder: (context, t, _) => r.monster ? _snack(t) : _piles(t)),
  );

  Widget _thing(SortThing x, double size, {Color? tint}) {
    final pic = x.picture;
    return CustomPaint(
      painter: PillowPainter(tint ?? DreamColors.pillows[0]),
      child: SizedBox(
        width: size,
        height: size * (pic != null ? .95 : .7),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pic != null) Illustration(picture: pic, width: size * .55, height: size * .45, radius: 12, padding: 2),
                  if (x.label.isNotEmpty) Text(x.label, style: dreamLetter(pic != null ? 22 : 34, LikhoColors.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------ two or more piles
  Widget _piles(double t) {
    final s = widget.state;
    final cur = _current;
    final hintBin = s.hint && cur != null ? r.items[cur].bin : null;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final bins = r.bins.length;
        final pileW = math.min(130.0, (w - 16 * (bins + 1)) / bins);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: _StarCount(found: s.found.length, of: r.count, light: false),
              ),
            ),
            // the thing to sort, floating
            if (cur != null)
              Positioned(
                key: ValueKey('${r.id}-item$cur'),
                top: h * .14 + math.sin(t * 2) * 5,
                left: 0,
                right: 0,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(_shakeItem == cur ? _shake(_shakeAt == null ? null : t - _shakeAt!) : 0, 0),
                    child: Transform.rotate(angle: math.sin(t * 1.4) * .05, child: _thing(r.items[cur], math.min(150, w * .42))),
                  ),
                ),
              ),
            // the piles
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var b = 0; b < bins; b++)
                    GestureDetector(
                      key: ValueKey('${r.id}-bin$b'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: s.correct || cur == null ? null : (_) => _drop(cur, b),
                      child: _pile(b, pileW, t, hint: hintBin == b),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pile(int b, double w, double t, {required bool hint}) {
    final s = widget.state;
    final sorted = [
      for (var i = 0; i < r.items.length; i++)
        if (s.found.contains(i) && r.items[i].bin == b) i,
    ];
    final bin = r.bins[b];
    final color = DreamColors.pillows[(b + 1) % DreamColors.pillows.length];
    final base = w * .78;
    Widget pile = SizedBox(
      width: w,
      height: base + 12 + 4 * 10.0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // the pillows sorted onto this pile, stacked on top of it
          for (final (k, _) in sorted.indexed)
            Positioned(
              bottom: base - 10 + math.min(k, 3) * 10.0,
              child: Transform.rotate(
                angle: (k.isEven ? 1 : -1) * .07,
                child: SizedBox(
                  width: w * .72,
                  height: 24,
                  child: CustomPaint(painter: PillowPainter(DreamColors.pillows[k % DreamColors.pillows.length])),
                ),
              ),
            ),
          // the big pillow at the bottom carries the sign
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: base,
            child: CustomPaint(
              painter: PillowPainter(color),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bin.picture != null) Illustration(picture: bin.picture!, width: w * .5, height: w * .36, radius: 10, padding: 2),
                        if (bin.label.isNotEmpty) Text(bin.label, style: dreamLetter(bin.picture != null ? 22 : 40, LikhoColors.ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (hint) {
      pile = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: -6, top: -6, right: -6, bottom: -6, child: CustomPaint(painter: RoundRing(LikhoColors.hint, 10 * dreamPulse(t)))),
          pile,
        ],
      );
    }
    return pile;
  }

  // ------------------------------------------------ one bin: midnight snack
  Widget _snack(double t) {
    final s = widget.state;
    final n = r.items.length;
    final hintAt = s.hint ? [for (var i = 0; i < n; i++) i].where((i) => r.items[i].bin == 0 && !s.found.contains(i)).firstOrNull : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.restaurant_rounded, size: 22, fill: 1, color: StageSky.meterFrom),
                const SizedBox(width: 6),
                Text(
                  'Midnight snack!',
                  style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: StageSky.meterFrom),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _StarCount(found: s.found.length, of: r.count, light: false),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final cols = n <= 4 ? 2 : 3;
                final rows = (n / cols).ceil();
                final size = math.min((box.maxWidth - 12 * (cols - 1)) / cols, (box.maxHeight - 12 * (rows - 1)) / rows / .9);
                return Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < n; i++)
                        SizedBox(key: ValueKey('${r.id}-item$i'), width: size, height: size * .9, child: _snackItem(i, size, t, hintAt == i)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _snackItem(int i, double size, double t, bool hint) {
    final s = widget.state;
    final eaten = s.found.contains(i);
    final age = _tapAt[i] == null ? null : t - _tapAt[i]!;
    if (eaten && (age == null || age > .5)) return const SizedBox.shrink();
    var dy = math.sin(t * 1.7 + i) * 3, scale = 1.0, opacity = 1.0;
    if (eaten && age != null) {
      final f = Curves.easeIn.transform(age / .5);
      dy -= f * 300;
      scale = 1 - .6 * f;
      opacity = 1 - f;
    }
    Widget body = _thing(r.items[i], size, tint: DreamColors.pillows[i % DreamColors.pillows.length]);
    if (hint) {
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: -6, top: -6, right: -6, bottom: -6, child: CustomPaint(painter: RoundRing(LikhoColors.hint, 10 * dreamPulse(t)))),
          body,
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: s.correct || eaten ? null : (_) => _drop(i, 0),
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(_shakeItem == i ? _shake(_shakeAt == null ? null : t - _shakeAt!) : 0, dy),
          child: Transform.scale(
            scale: scale,
            child: FittedBox(child: body),
          ),
        ),
      ),
    );
  }
}

// ================================================================== sleep notes

/// Boss "fix" rounds: the boss wrote in its sleep, on a dreamy note. Some
/// letters are backwards or upside down; tap each to turn it the right way.
/// Tapping one that was right is a mistake. After a mistake one still to
/// fix pulses.
class SleepNotesView extends StatelessWidget {
  const SleepNotesView({super.key, required this.state, required this.round, required this.onTap, required this.time});
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
    return DreamField(
      night: true,
      time: time,
      correct: state.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Zzz... ',
                    style: LikhoFonts.title(size: 18, weight: FontWeight.w800, color: StageSky.zzz),
                  ),
                  Text(
                    'Fix the sleepy notes!',
                    style: LikhoFonts.body(size: 15, weight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _StarCount(found: state.found.length, of: round.count),
            const SizedBox(height: 10),
            Expanded(
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
                            key: ValueKey('${round.id}-$i'),
                            size: words ? size : Size.square(math.min(size.width, size.height)),
                            child: _Note(
                              item: round.items[i],
                              fixed: state.found.contains(i),
                              wrong: state.wrongOptions.contains(i),
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
          ],
        ),
      ),
    );
  }
}

class _Note extends StatefulWidget {
  const _Note({required this.item, required this.fixed, required this.wrong, required this.hint, required this.time, required this.onTap});
  final FixItem item;
  final bool fixed, wrong, hint;
  final ValueNotifier<double> time;
  final VoidCallback? onTap;

  @override
  State<_Note> createState() => _NoteState();
}

class _NoteState extends State<_Note> with TickerProviderStateMixin {
  /// 1 = shown wrong, 0 = turned the right way.
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: widget.fixed ? 0 : 1);
  double? _tapAt;

  @override
  void didUpdateWidget(_Note old) {
    super.didUpdateWidget(old);
    if (widget.fixed && !old.fixed) _turn.animateTo(0, curve: const Cubic(.34, 1.56, .64, 1));
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  Widget _glyph(String s, double size, Color color, double t) {
    final text = Text(
      s,
      style: LikhoFonts.letter(size: size, color: color).copyWith(height: 1),
    );
    if (t == 0 || widget.item.wrong == null) return text;
    final k = math.cos(t * math.pi);
    final m = widget.item.wrong == FixWrong.mirror ? Matrix4.diagonal3Values(k, 1, 1) : Matrix4.diagonal3Values(1, k, 1);
    return Transform(alignment: Alignment.center, transform: m, child: text);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final fixed = widget.fixed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null || fixed || widget.wrong
          ? null
          : () {
              _tapAt = widget.time.value;
              widget.onTap!();
            },
      child: ValueListenableBuilder<double>(
        valueListenable: widget.time,
        builder: (context, t, _) {
          Widget note = LayoutBuilder(
            builder: (context, box) {
              final len = item.text.length;
              final size = math.min(box.maxHeight * .62, box.maxWidth * 1.3 / math.max(1, len));
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: fixed ? LikhoColors.primary : (widget.wrong ? Colors.white.withValues(alpha: .45) : const Color(0xFFF4F0FF)),
                  border: Border.all(color: fixed ? LikhoColors.primaryDeep : Colors.white, width: 3, strokeAlign: BorderSide.strokeAlignInside),
                  boxShadow: const [BoxShadow(color: DreamColors.moonEdge, offset: Offset(0, 4))],
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
                              final k = _turn.value;
                              if (item.at == null) return _glyph(item.text, size, LikhoColors.ink, k);
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [for (var i = 0; i < len; i++) _glyph(item.text[i], size, LikhoColors.ink, i == item.at ? k : 0)],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (fixed) const Positioned(right: 4, top: 4, child: Icon(Symbols.star_rounded, size: 20, fill: 1, color: Colors.white)),
                  ],
                ),
              );
            },
          );
          if (widget.hint) {
            note = Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(left: -6, top: -6, right: -6, bottom: -6, child: CustomPaint(painter: RoundRing(LikhoColors.hint, 10 * dreamPulse(t)))),
                Positioned.fill(child: note),
              ],
            );
          }
          final age = _tapAt == null ? null : t - _tapAt!;
          return Transform.translate(offset: Offset(widget.wrong ? _shake(age) : 0, fixed ? 0 : math.sin(t * 1.5 + item.text.hashCode % 7) * 2), child: note);
        },
      ),
    );
  }
}
