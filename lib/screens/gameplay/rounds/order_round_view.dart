import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/illustration.dart';
import 'pick_round_view.dart';

/// "order" rounds: tap the tiles in the right order to fill the slots.
/// Slot styles: wagon (train, default), plank (bridge), stripe (rainbow),
/// panel (story strip).
class OrderRoundView extends StatelessWidget {
  const OrderRoundView({super.key, required this.state, required this.round, required this.onTile, required this.time});
  final SessionState state;
  final OrderRound round;
  final ValueChanged<int> onTile;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final slot = state.level.presentation.slot ?? 'wagon';
    final placed = state.placed.length;
    final slots = switch (slot) {
      'plank' => _Bridge(round: round, placed: placed, deer: state.correct),
      'stripe' => _Rainbow(round: round, placed: placed),
      'panel' => _Panels(round: round, placed: placed),
      _ => _Train(round: round, placed: placed, leave: state.correct),
    };
    final order = state.tiles;
    return SoftField(
      correct: state.correct,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LikhoRadius.writingPad),
        child: FillOrClip(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                slots,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < order.length; i++)
                        _Tile(
                          key: ValueKey('${round.id}-t$i'),
                          text: round.tiles[order[i]],
                          used: state.placed.contains(i),
                          hint: state.hint && order[i] == placed,
                          wide: slot == 'panel',
                          time: time,
                          wrong: () => order[i] != placed,
                          onTap: () => onTile(i),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    super.key,
    required this.text,
    required this.used,
    required this.hint,
    required this.wide,
    required this.time,
    required this.wrong,
    required this.onTap,
  });
  final String text;
  final bool used, hint, wide;
  final ValueNotifier<double> time;
  final bool Function() wrong;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  bool _down = false;

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedScale(
      scale: _down ? .9 : 1,
      duration: const Duration(milliseconds: 200),
      curve: const Cubic(.34, 1.56, .64, 1),
      child: Container(
        constraints: BoxConstraints(minWidth: widget.wide ? 96 : (widget.text.length > 2 ? 0 : 72)),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: LikhoColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: GameColors.ink10, offset: Offset(0, 6))],
        ),
        child: Center(widthFactor: 1, child: Text(widget.text, style: LikhoFonts.letter(size: 32).copyWith(height: 1))),
      ),
    );
    return AnimatedOpacity(
      opacity: widget.used ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: widget.used,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: () {
            if (widget.wrong()) _wiggle.forward(from: 0);
            widget.onTap();
          },
          child: AnimatedBuilder(
            animation: _wiggle,
            builder: (context, child) {
              if (!_wiggle.isAnimating) return child!;
              const keys = [0.0, -10.0, 8.0, 0.0];
              final v = _wiggle.value, q = (v * 3).floor().clamp(0, 2);
              return Transform.rotate(angle: (keys[q] + (keys[q + 1] - keys[q]) * (v * 3 - q)) * math.pi / 180, child: child);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                tile,
                if (widget.hint)
                  Positioned(
                    left: -6,
                    top: -6,
                    right: -6,
                    bottom: -6,
                    child: ValueListenableBuilder<double>(
                      valueListenable: widget.time,
                      builder: (context, t, _) {
                        final k = 1 - (2 * (t % 1.0) - 1).abs();
                        return IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: LikhoColors.hint, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: LikhoColors.primary.withValues(alpha: .35 * k),
                                  spreadRadius: 16 * k,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ train

class _Train extends StatelessWidget {
  const _Train({required this.round, required this.placed, required this.leave});
  final OrderRound round;
  final int placed;
  final bool leave;

  @override
  Widget build(BuildContext context) {
    final wheel = Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(color: GameColors.trainDark, shape: BoxShape.circle),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          // the train pulls away 420 px when the round is won
          tween: Tween(end: leave ? 420 : 0),
          duration: const Duration(milliseconds: 1100),
          curve: const Cubic(.6, 0, .4, 1),
          builder: (context, dx, child) => Transform.translate(offset: Offset(dx, 0), child: child),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 62,
                height: 72,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 8,
                      top: 0,
                      width: 14,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(color: GameColors.trainDark, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 18,
                      width: 62,
                      height: 46,
                      child: CustomPaint(
                        painter: _InsetBox(
                          LikhoColors.hint,
                          const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(22),
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 30,
                      top: 24,
                      width: 22,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(color: GameColors.window, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      bottom: -4,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: const BoxDecoration(color: GameColors.trainDark, shape: BoxShape.circle),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: -4,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: const BoxDecoration(color: GameColors.trainDark, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < round.tiles.length; i++) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 62,
                  height: 72,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 10,
                        width: 62,
                        height: 54,
                        child: CustomPaint(
                          painter: _InsetBox(GameColors.wagonColors[i % 4].withValues(alpha: .95), BorderRadius.circular(12)),
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 38,
                              decoration: BoxDecoration(
                                color: LikhoColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: i < placed ? GameColors.wagonColors[i % 4] : GameColors.ink08,
                                  width: 3,
                                  strokeAlign: BorderSide.strokeAlignInside,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                i < placed ? round.tiles[i] : '',
                                style: LikhoFonts.letter(size: 30).copyWith(fontWeight: FontWeight.w700, height: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(left: 6, bottom: -4, child: wheel),
                      Positioned(right: 6, bottom: -4, child: wheel),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) => SizedBox(
            width: box.maxWidth * 1.1,
            height: 10,
            child: CustomPaint(painter: _RailPainter()),
          ),
        ),
      ],
    );
  }
}

/// Filled rounded box with the prototype's "inset 0 -6px 0 rgba(0,0,0,.12)" bottom band.
class _InsetBox extends CustomPainter {
  const _InsetBox(this.color, this.radius);
  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()..addRRect(radius.toRRect(Offset.zero & size));
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(Path.combine(PathOperation.difference, p, p.shift(const Offset(0, -6))), Paint()..color = GameColors.black12);
  }

  @override
  bool shouldRepaint(_InsetBox old) => old.color != color;
}

class _RailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sleeper = Paint()..color = GameColors.sleeper;
    for (var x = 0.0; x < size.width; x += 20) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 8, size.height), sleeper);
    }
    canvas.drawRect(Rect.fromLTWH(0, 3, size.width, 3), Paint()..color = GameColors.rail);
  }

  @override
  bool shouldRepaint(_RailPainter old) => false;
}

// ------------------------------------------------------------------ bridge

class _Bridge extends StatelessWidget {
  const _Bridge({required this.round, required this.placed, required this.deer});
  final OrderRound round;
  final int placed;
  final bool deer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // width:100% of the field
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -20,
            right: -20,
            top: 70,
            height: 60,
            child: Opacity(
              opacity: .9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [GameColors.riverTop, GameColors.riverBottom],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -10,
            top: 36,
            width: 54,
            height: 60,
            child: Container(
              decoration: const BoxDecoration(
                color: GameColors.bank,
                borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: 36,
            width: 54,
            height: 60,
            child: Container(
              decoration: const BoxDecoration(
                color: GameColors.bank,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < round.tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 68,
                    height: 62,
                    decoration: BoxDecoration(
                      color: i < placed ? GameColors.wagonColors[i % 4] : GameColors.ink08,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GameColors.plankEdge, width: 3, strokeAlign: BorderSide.strokeAlignInside),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      i < placed ? round.tiles[i] : '',
                      style: LikhoFonts.letter(size: 34, color: LikhoColors.surface).copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1,
                        shadows: const [Shadow(color: GameColors.black20, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (deer)
            Positioned(
              left: 10,
              top: 4,
              width: 40,
              height: 40,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 2),
                duration: const Duration(milliseconds: 1800),
                builder: (context, t, child) {
                  final k = const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t % 1.0) - 1).abs());
                  return Transform.translate(offset: Offset(16 * k, 0), child: child);
                },
                child: CustomPaint(painter: _DeerPainter()),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()..addOval(Offset.zero & size);
    canvas.drawPath(p, Paint()..color = GameColors.deer);
    canvas.drawPath(Path.combine(PathOperation.difference, p, p.shift(const Offset(-4, -4))), Paint()..color = GameColors.black12);
  }

  @override
  bool shouldRepaint(_DeerPainter old) => false;
}

// ------------------------------------------------------------------ rainbow

class _Rainbow extends StatelessWidget {
  const _Rainbow({required this.round, required this.placed});
  final OrderRound round;
  final int placed;

  @override
  Widget build(BuildContext context) {
    Color arc(int i) => i < placed ? GameColors.wagonColors[i % 4] : GameColors.ink08;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 260,
          height: 130,
          child: Stack(
            children: [
              for (var i = 0; i < round.tiles.length; i++)
                Positioned(
                  left: i * 20.0,
                  top: i * 20.0,
                  width: 260 - i * 40.0,
                  height: 130 - i * 20.0,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: arc(i)),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, c, _) => CustomPaint(painter: _ArcPainter(c!)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < round.tiles.length; i++)
              Container(
                constraints: const BoxConstraints(minWidth: 64),
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: LikhoColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: arc(i), width: 3, strokeAlign: BorderSide.strokeAlignInside),
                ),
                child: Center(widthFactor: 1, child: Text(i < placed ? round.tiles[i] : '', style: LikhoFonts.letter(size: 26).copyWith(height: 1))),
              ),
          ],
        ),
      ],
    );
  }
}

/// border: 18px solid; border-bottom: none; border-radius 200 200 0 0.
class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndCorners(Offset.zero & size, topLeft: const Radius.circular(200), topRight: const Radius.circular(200)).scaleRadii();
    final inner = RRect.fromRectAndCorners(
      Rect.fromLTRB(18, 18, size.width - 18, size.height + 1),
      topLeft: const Radius.circular(182),
      topRight: const Radius.circular(182),
    ).scaleRadii();
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRRect(outer), Path()..addRRect(inner)), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

// ------------------------------------------------------------------ story panels

class _Panels extends StatelessWidget {
  const _Panels({required this.round, required this.placed});
  final OrderRound round;
  final int placed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: LikhoColors.ink, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < round.tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Container(
              width: 92,
              height: 104,
              decoration: BoxDecoration(color: GameColors.paperNote, borderRadius: BorderRadius.circular(10)),
              child: Stack(
                children: [
                  Positioned(
                    left: 6,
                    top: 4,
                    child: Text(
                      '${i + 1}',
                      style: LikhoFonts.title(size: 14, weight: FontWeight.w800, color: GameColors.panelNumber),
                    ),
                  ),
                  if (i < placed)
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, t, child) => Transform.scale(scale: t < .7 ? 1.1 * t / .7 : 1.1 - .1 * (t - .7) / .3, child: child),
                        child: Illustration(
                          picture: Picture(key: round.tiles[i].replaceAll(' ', '_'), label: round.tiles[i]),
                          width: 70,
                          height: 56,
                          radius: 10,
                          padding: 4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
