import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/illustration.dart';
import 'pick_round_view.dart';

/// "dots" rounds (connect the dots): letters in dots around a hidden
/// picture. Tap them in order (A, B, C …): each joins the line from the one
/// before. A dot out of order wiggles and counts a mistake; after one the
/// next dot glows. The last dot closes the shape: it fills with colour and
/// the picture pops up in it.
class ConnectRoundView extends StatefulWidget {
  const ConnectRoundView({super.key, required this.state, required this.round, required this.onTap, required this.time});
  final SessionState state;
  final ConnectRound round;
  final ValueChanged<int> onTap;
  final ValueNotifier<double> time;

  @override
  State<ConnectRoundView> createState() => _ConnectRoundViewState();
}

class _ConnectRoundViewState extends State<ConnectRoundView> with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  static const _dot = 40.0;

  bool get _done => widget.state.found.length >= widget.round.labels.length;

  @override
  void initState() {
    super.initState();
    if (_done) _reveal.value = 1;
  }

  @override
  void didUpdateWidget(ConnectRoundView old) {
    super.didUpdateWidget(old);
    if (_done && old.state.found.length < widget.round.labels.length) _reveal.forward(from: 0);
    if (widget.state.feedback == RoundFeedback.wrong && old.state.feedback != RoundFeedback.wrong) _wiggle.forward(from: 0);
  }

  @override
  void dispose() {
    _reveal.dispose();
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final r = widget.round;
    return SoftField(
      correct: s.correct,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, box) {
            final side = math.min(box.maxWidth, box.maxHeight);
            final inner = side - _dot; // dots stay inside
            Offset at(int i) => Offset(_dot / 2 + r.points[i].dx * inner, _dot / 2 + r.points[i].dy * inner);
            final hintAt = s.hint && !_done ? s.found.length : null;
            final wrongAt = s.feedback == RoundFeedback.wrong ? s.picked : null;
            final pic = r.picture;
            final c = r.points.fold(Offset.zero, (a, p) => a + p) / r.points.length.toDouble();
            final picSide = inner * .42;
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _reveal,
                        builder: (context, _) => CustomPaint(
                          painter: _Lines(points: [for (var i = 0; i < r.points.length; i++) at(i)], joined: s.found.length, fill: _reveal.value),
                        ),
                      ),
                    ),
                    if (pic != null)
                      Positioned(
                        left: _dot / 2 + c.dx * inner - picSide / 2,
                        top: _dot / 2 + c.dy * inner - picSide / 2,
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _reveal,
                            builder: (context, child) {
                              final k = const Cubic(.34, 1.56, .64, 1).transform(((_reveal.value - .35) / .65).clamp(0.0, 1.0));
                              return Opacity(opacity: k.clamp(0.0, 1.0), child: Transform.scale(scale: .4 + .6 * k, child: child));
                            },
                            child: Illustration(picture: pic, width: picSide, height: picSide, radius: 16),
                          ),
                        ),
                      ),
                    for (var i = 0; i < r.labels.length; i++)
                      Positioned(
                        left: at(i).dx - _dot / 2,
                        top: at(i).dy - _dot / 2,
                        child: _Dot(
                          key: ValueKey('${r.id}-d$i'),
                          label: r.labels[i],
                          joined: s.found.contains(i),
                          done: _done,
                          hint: hintAt == i,
                          wrong: wrongAt == i,
                          wiggle: _wiggle,
                          time: widget.time,
                          onTap: s.correct || _done ? null : () => widget.onTap(i),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.label, required this.joined, required this.done, required this.hint, required this.wrong, required this.wiggle, required this.time, required this.onTap});
  final String label;
  final bool joined, done, hint, wrong;
  final Animation<double> wiggle;
  final ValueNotifier<double> time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = _ConnectRoundViewState._dot;
    final color = done ? LikhoColors.success : (joined ? LikhoColors.primary : (wrong ? GameColors.hintPale : LikhoColors.surface));
    Widget dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: done ? GameColors.successDeep : (joined ? LikhoColors.primaryDeep : (wrong ? LikhoColors.hint : GameColors.ink14)), width: 3),
        boxShadow: const [BoxShadow(color: GameColors.ink10, offset: Offset(0, 3))],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(label, style: LikhoFonts.letter(size: 22, color: joined || done ? LikhoColors.surface : LikhoColors.ink).copyWith(height: 1)),
        ),
      ),
    );
    if (hint) {
      dot = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: time,
            builder: (context, t, _) {
              final k = const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t % 1.0) - 1).abs());
              return Container(
                width: size + 22 * k,
                height: size + 22 * k,
                decoration: BoxDecoration(shape: BoxShape.circle, color: GameColors.glowYellowSoft.withValues(alpha: 1 - .5 * k)),
              );
            },
          ),
          dot,
        ],
      );
    }
    if (wrong) {
      dot = AnimatedBuilder(
        animation: wiggle,
        child: dot,
        builder: (context, child) {
          const keys = [0.0, -14.0, 12.0, -6.0, 0.0];
          final v = wiggle.value;
          final q = (v * 4).floor().clamp(0, 3);
          final deg = keys[q] + (keys[q + 1] - keys[q]) * (v * 4 - q);
          return Transform.rotate(angle: deg * math.pi / 180, child: child);
        },
      );
    }
    // a big finger target around the small dot
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(dimension: size, child: OverflowBox(maxWidth: size + 30, maxHeight: size + 30, child: Center(child: dot))),
    );
  }
}

/// The line through the joined dots; when all are joined it closes and the
/// shape fills ([fill] 0..1).
class _Lines extends CustomPainter {
  const _Lines({required this.points, required this.joined, required this.fill});
  final List<Offset> points;
  final int joined;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final done = joined >= points.length;
    final path = Path();
    for (var i = 0; i < math.min(joined, points.length); i++) {
      i == 0 ? path.moveTo(points[i].dx, points[i].dy) : path.lineTo(points[i].dx, points[i].dy);
    }
    if (done) {
      path.close();
      if (fill > 0) canvas.drawPath(path, Paint()..color = GameColors.dotsFill.withValues(alpha: GameColors.dotsFill.a * fill.clamp(0, 1)));
    }
    if (joined > 1 || done) {
      canvas.drawPath(
        path,
        Paint()
          ..color = done ? LikhoColors.success : LikhoColors.secondary
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_Lines old) => old.joined != joined || old.fill != fill || old.points != points;
}
