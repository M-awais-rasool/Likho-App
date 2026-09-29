import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../feedback/app_feedback.dart';
import '../../../game/level_session.dart';
import '../../../game/writing/trace_lane.dart';
import '../../../game/writing/writing_judge.dart';
import '../widgets/game_buttons.dart';
import 'pick_round_view.dart';

/// Holds the child's strokes for one writing round; shared by the pad and
/// the eraser / "Ho gaya" bar.
///
/// Tracing rounds (trace, dots) have a lane around the letter: ink is only
/// drawn inside it. Leaving the lane ends the stroke; coming back starts a
/// new one.
class WritePadController extends ChangeNotifier {
  WritePadController({required this.round, required this.guides});

  final WriteRound round;

  /// Guide strokes in guide space (100 x 100, baseline 70); empty = no guide.
  final List<Path> guides;

  final List<List<Offset>> strokes = [];
  Size padSize = Size.zero;
  bool penUsed = false; // the follower shows after the first touch
  Offset? pen;

  /// Called when the finger leaves the lane (or touches down outside it).
  VoidCallback? onLeaveLane;

  /// Pad clock time of the last time the finger left the lane (the lane
  /// flashes), or null.
  double? leftLaneAt;

  bool _drawing = false; // the finger is down and inside the lane
  TraceLane? _lane;
  Size _laneSize = Size.zero;

  /// Where ink may go on this pad, or null when anywhere is fine.
  TraceLane? get lane {
    if (guides.isEmpty || padSize.isEmpty) return null;
    if (_lane == null || _laneSize != padSize) {
      _lane = PadGeometry(padSize).lane(guides);
      _laneSize = padSize;
    }
    return _lane;
  }

  void start(Offset p) {
    final l = lane;
    if (l != null && !l.contains(p)) {
      _drawing = false;
      onLeaveLane?.call();
      return;
    }
    strokes.add([p]);
    _drawing = true;
    pen = p;
    penUsed = true;
    notifyListeners();
  }

  /// The finger moved to [p]; false when nothing was drawn (outside the
  /// lane).
  bool extend(Offset p) {
    final l = lane;
    if (l == null) {
      if (strokes.isEmpty) return false;
      strokes.last.add(p);
    } else if (_drawing && l.containsMove(strokes.last.last, p)) {
      strokes.last.add(p);
    } else {
      if (_drawing) onLeaveLane?.call();
      _drawing = l.contains(p);
      if (!_drawing) return false;
      strokes.add([p]); // back in the lane: a new stroke
    }
    pen = p;
    penUsed = true;
    notifyListeners();
    return true;
  }

  /// Finger lifted.
  void end() => _drawing = false;

  void erase() {
    strokes.clear();
    _drawing = false;
    penUsed = false;
    notifyListeners();
  }

  WritingVerdict judge() => WritingJudge.judge(round, strokes, lane);

  /// Guide paths for [round] from the course's glyph table.
  static List<Path> guidesFor(WriteRound round, Map<String, List<String>> glyphs) {
    final key = round.guide;
    if (key == null || (round.mode != WriteMode.trace && round.mode != WriteMode.dots)) return const [];
    return [for (final d in glyphs[key] ?? const <String>[]) parseSvgPathData(d)];
  }

  static List<String> rawGuides(WriteRound round, Map<String, List<String>> glyphs) {
    final key = round.guide;
    return key == null ? const [] : glyphs[key] ?? const [];
  }
}

/// The writing pad (prototype write area). Pad styles: paper (default),
/// track (train), road (car), sand.
class WritePad extends StatefulWidget {
  const WritePad({
    super.key,
    required this.controller,
    required this.state,
    required this.round,
    required this.glyphs,
    required this.time,
    required this.onPen,
  });

  final WritePadController controller;
  final SessionState state;
  final WriteRound round;
  final Map<String, List<String>> glyphs;
  final ValueNotifier<double> time;

  /// Global pen position (the mascot's eyes follow it).
  final ValueChanged<Offset> onPen;

  @override
  State<WritePad> createState() => _WritePadState();
}

class _WritePadState extends State<WritePad> with SingleTickerProviderStateMixin {
  final _sparks = <_Spark>[];
  final _rnd = math.Random();
  late final AnimationController _sparkClock = AnimationController(vsync: this, duration: const Duration(days: 1))..forward();
  int? _pointer; // the finger that writes (a second finger or palm is ignored)

  @override
  void initState() {
    super.initState();
    widget.controller.onLeaveLane = _leftLane;
  }

  @override
  void didUpdateWidget(WritePad old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.onLeaveLane = null;
      widget.controller.onLeaveLane = _leftLane;
    }
  }

  @override
  void dispose() {
    if (widget.controller.onLeaveLane == _leftLane) widget.controller.onLeaveLane = null;
    _sparkClock.dispose();
    super.dispose();
  }

  void _leftLane() {
    widget.controller.leftLaneAt = widget.time.value;
    AppFeedback.of(context).offPath();
  }

  double get _now => _sparkClock.lastElapsedDuration == null ? 0 : _sparkClock.lastElapsedDuration!.inMicroseconds / 1e6;

  void _down(PointerDownEvent e) {
    if (widget.state.correct || _pointer != null) return;
    _pointer = e.pointer;
    widget.controller.start(e.localPosition);
    widget.onPen(e.position);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    widget.controller.end();
  }

  void _move(PointerMoveEvent e) {
    if (widget.state.correct || e.pointer != _pointer) return;
    widget.onPen(e.position);
    if (!widget.controller.extend(e.localPosition)) return; // outside the lane: no ink, no sparks
    if (_rnd.nextDouble() < .35) {
      _sparks.add(_Spark(e.localPosition, GameColors.sparks[_rnd.nextInt(4)], (_rnd.nextDouble() - .5) * 40, -10 - _rnd.nextDouble() * 30, _now));
      _sparks.removeWhere((s) => _now - s.born > .6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.state.level.presentation.pad ?? 'paper';
    final sand = pad == 'sand';
    final raw = WritePadController.rawGuides(widget.round, widget.glyphs);
    final noGuide = widget.controller.guides.isEmpty;
    final freeHint = widget.round.mode == WriteMode.free && widget.round.sentence && !widget.state.correct
        ? 'Likho: ${widget.round.target ?? 'apni kahani'}'
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LikhoRadius.writingPad),
        boxShadow: const [
          BoxShadow(color: GameColors.ink06, offset: Offset(0, 8)),
          BoxShadow(color: GameColors.ink10, offset: Offset(0, 16), blurRadius: 40),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LikhoRadius.writingPad),
        child: LayoutBuilder(
          builder: (context, box) {
            widget.controller.padSize = box.biggest;
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _PadBackground(sand: sand)),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GuidePainter(
                          mode: widget.round.mode,
                          pad: pad,
                          guides: widget.controller.guides,
                          raw: raw,
                          hint: widget.state.hint,
                          time: widget.time,
                          controller: widget.controller,
                        ),
                      ),
                    ),
                  ),
                  if (freeHint != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: IgnorePointer(
                        child: Text(
                          freeHint,
                          textAlign: TextAlign.center,
                          style: LikhoFonts.parent(size: 15, weight: FontWeight.w700, color: GameColors.ink35),
                        ),
                      ),
                    ),
                  if (widget.state.hint && noGuide) Positioned(left: 24, top: 24, child: _StartHere(time: widget.time)),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _InkPainter(controller: widget.controller, correct: widget.state.correct, sand: sand),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _sparkClock,
                        builder: (context, _) => CustomPaint(painter: _SparkPainter(_sparks, _now)),
                      ),
                    ),
                  ),
                  if (pad == 'track' || pad == 'road')
                    _Follower(controller: widget.controller, icon: pad == 'track' ? Symbols.train_rounded : Symbols.directions_car_rounded),
                  if (widget.state.correct) const Positioned.fill(child: CorrectGlow(inner: true)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PadBackground extends CustomPainter {
  const _PadBackground({required this.sand});
  final bool sand;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = sand ? GameColors.sand : LikhoColors.surface);
    if (!sand) return;
    // radial-gradient(grain 1px, transparent 1.5px) 0 0 / 9px 9px
    final dot = Paint()..color = GameColors.sandGrain;
    for (var y = 0.0; y < size.height; y += 9) {
      for (var x = 0.0; x < size.width; x += 9) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_PadBackground old) => old.sand != sand;
}

/// Ruled lines, guide strokes, stroke-start badges, dots and the hint stroke.
class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.mode,
    required this.pad,
    required this.guides,
    required this.raw,
    required this.hint,
    required this.time,
    required this.controller,
  }) : super(repaint: (hint || guides.isNotEmpty) ? time : null);

  final WriteMode mode;
  final String pad;
  final List<Path> guides;
  final List<String> raw;
  final bool hint;
  final ValueNotifier<double> time;
  final WritePadController controller;

  /// How long the lane flashes after the finger slips out (seconds).
  static const laneFlash = .45;

  /// OPEN QUESTION: the prototype's code puts stroke numbers in the start
  /// badges and next to connect-the-dots points, but its template wraps them
  /// in an HTML `<span>` inside SVG `<text>`, which browsers do not draw, so the
  /// reference screens show plain dots. We match the reference; set true to
  /// show the numbers.
  static const showStrokeNumbers = false;

  static final _move = RegExp(r'M\s*([\d.]+)\s+([\d.]+)');
  static final _points = RegExp(r'[ML]\s*([\d.]+)\s+([\d.]+)');

  @override
  void paint(Canvas canvas, Size size) {
    final geo = PadGeometry(size);
    // ruled lines across the whole pad (non-scaling strokes)
    void line(double gy, Color c, double w, [List<double>? dash]) {
      final y = geo.toPad(Offset(0, gy)).dy;
      final p = Paint()
        ..color = c
        ..strokeWidth = w;
      if (dash == null) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      } else {
        for (var x = 0.0; x < size.width; x += dash[0] + dash[1]) {
          canvas.drawLine(Offset(x, y), Offset(math.min(size.width, x + dash[0]), y), p);
        }
      }
    }

    line(20, GameColors.lineTop, 2);
    line(45, GameColors.lineTop, 2, [8, 8]);
    line(70, GameColors.lineBase, 2.5);
    line(90, GameColors.lineDesc, 2, [3, 7]);

    canvas.save();
    geo.apply(canvas);
    final t = time.value;
    if (guides.isNotEmpty) {
      // the lane: where ink may go; it flashes when the finger slips out
      final left = controller.leftLaneAt;
      final flash = left == null ? 0.0 : (1 - (t - left) / laneFlash).clamp(0.0, 1.0);
      final base = switch (pad) {
        'track' => GameColors.laneTrack,
        'road' => GameColors.laneRoad,
        'sand' => GameColors.laneSand,
        _ => GameColors.lanePaper,
      };
      final lane = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = WritingJudge.laneWidth
        ..color = Color.lerp(base, LikhoColors.hint.withValues(alpha: .35), flash)!;
      for (final g in guides) {
        canvas.drawPath(g, lane);
      }
    }
    if (mode == WriteMode.trace && guides.isNotEmpty) {
      final color = switch (pad) {
        'track' => GameColors.guideTrack,
        'road' => GameColors.guideRoad,
        'sand' => GameColors.sandGuide,
        _ => GameColors.guidePaper,
      };
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = pad == 'road' ? 8 : 7
        ..color = color;
      for (final g in guides) {
        canvas.drawPath(pad == 'track' ? _dashed(g, 1.3, 2.4) : g, stroke);
      }
      if (pad == 'road' || pad == 'track') {
        final mid = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = pad == 'road' ? .7 : .8
          ..color = pad == 'road' ? LikhoColors.surface : GameColors.trackRail;
        for (final g in guides) {
          canvas.drawPath(pad == 'road' ? _dashed(g, 2.5, 2.5) : g, mid);
        }
      }
      // pulsing start of the first stroke
      final starts = [for (final d in raw) _move.firstMatch(d)].whereType<RegExpMatch>().map((m) => Offset(double.parse(m[1]!), double.parse(m[2]!))).toList();
      if (starts.isNotEmpty) {
        final p = Curves.easeOut.transform((t / 1.4) % 1.0);
        canvas.drawCircle(starts.first, 4.5 * (1 + .75 * p), Paint()..color = LikhoColors.primary.withValues(alpha: .6 * (1 - p)));
      }
      for (final (i, s) in starts.indexed) {
        canvas.drawCircle(s, 3.4, Paint()..color = LikhoColors.secondary);
        if (showStrokeNumbers) _text(canvas, '${i + 1}', s, 4, LikhoColors.surface);
      }
    }
    if (mode == WriteMode.dots) {
      final pts = <Offset>[];
      for (final d in raw) {
        for (final m in _points.allMatches(d)) {
          final q = Offset(double.parse(m[1]!), double.parse(m[2]!));
          if (!pts.contains(q)) pts.add(q);
        }
      }
      for (final (i, q) in pts.indexed) {
        canvas.drawCircle(q, 2.6, Paint()..color = LikhoColors.ink);
        if (showStrokeNumbers) _text(canvas, '${i + 1}', q + const Offset(-4.2, -3.6), 3.6, LikhoColors.secondary);
      }
    }
    if (hint && guides.isNotEmpty) {
      // hintDraw 1.4 s: draws the first stroke, holds, fades
      final p = Curves.easeInOut.transform((t / 1.4) % 1.0);
      final m = guides.first.computeMetrics().firstOrNull;
      if (m != null) {
        final part = m.extractPath(0, m.length * math.min(1, p / .7));
        canvas.drawPath(
          part,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 3.2
            ..color = LikhoColors.hint.withValues(alpha: p < .7 ? 1 : 1 - (p - .7) / .3),
        );
      }
    }
    canvas.restore();
  }

  void _text(Canvas canvas, String s, Offset centre, double size, Color c) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: LikhoFonts.title(size: size, weight: FontWeight.w800, color: c).copyWith(height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  static Path _dashed(Path p, double on, double off) => dashPath(p, dashArray: CircularIntervalList<double>([on, off]));

  @override
  bool shouldRepaint(_GuidePainter old) => old.mode != mode || old.pad != pad || old.guides != guides || old.hint != hint;
}

class _InkPainter extends CustomPainter {
  _InkPainter({required this.controller, required this.correct, required this.sand}) : super(repaint: controller);
  final WritePadController controller;
  final bool correct, sand;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 14
      ..color = correct ? LikhoColors.success : (sand ? GameColors.sandInk : LikhoColors.ink);
    final paths = <Path>[];
    for (final st in controller.strokes) {
      if (st.isEmpty) continue;
      final p = Path()..moveTo(st.first.dx, st.first.dy);
      for (var i = 1; i < st.length - 1; i++) {
        final mid = (st[i] + st[i + 1]) / 2;
        p.quadraticBezierTo(st[i].dx, st[i].dy, mid.dx, mid.dy);
      }
      p.lineTo(st.last.dx, st.last.dy + .01);
      paths.add(p);
    }
    if (correct) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 14
        ..color = GameColors.successInk
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      for (final p in paths) {
        canvas.drawPath(p, glow);
      }
    }
    for (final p in paths) {
      canvas.drawPath(p, ink);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => old.correct != correct || old.sand != sand;
}

class _Spark {
  _Spark(this.at, this.color, this.dx, this.dy, this.born);
  final Offset at;
  final Color color;
  final double dx, dy, born;
}

/// Little diamonds flying off the pen (600 ms, ease-out).
class _SparkPainter extends CustomPainter {
  _SparkPainter(this.sparks, this.now);
  final List<_Spark> sparks;
  final double now;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in sparks) {
      final p = ((now - s.born) / .6).clamp(0.0, 1.0);
      if (p >= 1) continue;
      final e = Curves.easeOut.transform(p);
      canvas.save();
      canvas.translate(s.at.dx - 4 + s.dx * e, s.at.dy - 4 + s.dy * e);
      canvas.rotate((45 + 155 * e) * math.pi / 180);
      canvas.scale(1 - e);
      paint.color = s.color.withValues(alpha: 1 - e);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -4, 8, 8), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}

/// Track / road pads: a train or car rides under the finger.
class _Follower extends StatelessWidget {
  const _Follower({required this.controller, required this.icon});
  final WritePadController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final p = controller.pen ?? Offset.zero;
        return Positioned(
          left: p.dx - 20,
          top: p.dy - 46,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: controller.penUsed ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: LikhoColors.hint,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: GameColors.hintDeep, offset: Offset(0, 4))],
                ),
                child: Icon(icon, size: 26, fill: 1, opticalSize: 26, color: LikhoColors.surface),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Yahan se shuru" (start here) with a bobbing arrow, after a mistake on a
/// pad without guides.
class _StartHere extends StatelessWidget {
  const _StartHere({required this.time});
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: time,
            builder: (context, t, child) {
              final k = Curves.easeInOut.transform(1 - (2 * (t % 1.0) - 1).abs());
              return Transform.translate(offset: Offset(0, 6 * k), child: child);
            },
            child: const Icon(Symbols.south_east_rounded, size: 30, opticalSize: 30, color: LikhoColors.hint),
          ),
          const SizedBox(width: 6),
          Text(
            'Yahan se shuru',
            style: LikhoFonts.title(size: 16, weight: FontWeight.w800, color: LikhoColors.hint),
          ),
        ],
      ),
    );
  }
}

/// Eraser + "Ho gaya" (done) under the pad.
class WriteBar extends StatelessWidget {
  const WriteBar({super.key, required this.onErase, required this.onDone});
  final VoidCallback onErase, onDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PushButton(
            onTap: onErase,
            color: LikhoColors.surface,
            width: 76,
            height: 76,
            shape: const CircleBorder(),
            shadows: const [BoxShadow(color: GameColors.ink10, offset: Offset(0, 6))],
            child: const Icon(Symbols.ink_eraser_rounded, size: 38, fill: 1, opticalSize: 38, color: GameColors.eraser),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: PushButton(
                onTap: onDone,
                color: LikhoColors.success,
                edgeColor: GameColors.successDeep,
                edge: 7,
                height: 84,
                pressScale: .96,
                innerHighlight: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.check_rounded, size: 40, fill: 1, weight: 700, opticalSize: 40, color: LikhoColors.surface),
                    const SizedBox(width: 10),
                    Text('Ho gaya', style: LikhoFonts.title(size: 24, color: LikhoColors.surface).copyWith(height: 1)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
