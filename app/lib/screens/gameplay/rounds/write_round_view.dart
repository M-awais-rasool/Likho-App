import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../feedback/app_feedback.dart';
import '../../../game/level_session.dart';
import '../../../game/writing/stroke_guide.dart';
import '../../../game/writing/trace_lane.dart';
import '../../../game/writing/writing_judge.dart';
import '../widgets/game_buttons.dart';
import 'pick_round_view.dart';

/// Something the pad tells the screen (mascot, sounds, lane flash).
enum PadEvent {
  /// The finger slid off the stroke being written.
  leftPath,

  /// The finger went down away from the start of the stroke.
  wrongStart,

  /// A stroke was finished; the next one is shown.
  strokeDone,

  /// The last stroke was finished: the letter is written.
  letterDone,
}

/// Holds the child's strokes for one writing round (one letter of a spelled
/// word); shared by the pad and the eraser / "Done" bar.
///
/// A letter with a guide is written step by step ([StrokeGuide]): the
/// current stroke shows where to start and which way to go, ink is only
/// drawn while the finger follows it, and the next stroke comes once it is
/// finished. Pads without a guide (sentences) take any ink.
class WritePadController extends ChangeNotifier {
  WritePadController({required this.round, required this.guides, this.letter = 0});

  final WriteRound round;

  /// The letter's strokes in guide space (100 x 100, baseline 70), in
  /// writing order; empty = no guide.
  final List<Path> guides;

  /// Which letter of a spelled word this pad is for.
  final int letter;

  final List<List<Offset>> strokes = [];
  Size padSize = Size.zero;
  bool penUsed = false; // the follower shows after the first touch
  Offset? pen;

  /// Pad clock times of the last slip off the stroke / touch away from its
  /// start (the lane or the start marker flashes), or null.
  double? leftLaneAt, wrongStartAt;

  final _listeners = <ValueChanged<PadEvent>>[];

  void addEventListener(ValueChanged<PadEvent> l) => _listeners.add(l);
  void removeEventListener(ValueChanged<PadEvent> l) => _listeners.remove(l);

  void _emit(PadEvent e) {
    for (final l in [..._listeners]) {
      l(e);
    }
  }

  bool _drawing = false; // the finger is down and following the stroke
  bool _misplaced = false; // went down away from the start: no ink until lifted
  TraceLane? _lane;
  StrokeGuide? _guide;
  Size _laneSize = Size.zero;

  /// Where ink may go on this pad (every stroke of the letter), or null
  /// when anywhere is fine.
  TraceLane? get lane {
    _layout();
    return _lane;
  }

  /// The step-by-step guide, or null when the pad has none.
  StrokeGuide? get guide {
    _layout();
    return _guide;
  }

  void _layout() {
    if (guides.isEmpty || padSize.isEmpty || (_lane != null && _laneSize == padSize)) return;
    final before = _laneSize, old = _guide;
    _lane = PadGeometry(padSize).lane(guides);
    _guide = StrokeGuide(_lane!)..stroke = old?.stroke ?? 0;
    if (old != null && !before.isEmpty) {
      // the pad changed size: the ink moves with the letter
      final from = PadGeometry(before), to = PadGeometry(padSize);
      for (final s in strokes) {
        for (var i = 0; i < s.length; i++) {
          s[i] = to.toPad(from.toGuide(s[i]));
        }
      }
      _drawing = false;
    }
    _laneSize = padSize;
  }

  void start(Offset p) {
    final g = guide;
    if (g == null) {
      _begin(p);
      return;
    }
    _drawing = false;
    if (g.done) return;
    if (!g.canStart(p)) {
      _misplaced = true;
      _emit(PadEvent.wrongStart);
      return;
    }
    _begin(p);
    _follow(g, p, p);
  }

  void _begin(Offset p) {
    strokes.add([p]);
    _drawing = true;
    pen = p;
    penUsed = true;
    notifyListeners();
  }

  /// The finger moved to [p]; false when nothing was drawn (off the stroke).
  bool extend(Offset p) {
    final g = guide;
    if (g == null) {
      if (strokes.isEmpty) return false;
      strokes.last.add(p);
    } else if (!_drawing) {
      // back on the stroke, or at the start of the next one
      if (_misplaced || g.done || !g.canStart(p)) return false;
      _begin(p);
      _follow(g, p, p);
      return true;
    } else if (!_follow(g, strokes.last.last, p)) {
      return false;
    }
    pen = p;
    penUsed = true;
    notifyListeners();
    return true;
  }

  /// Follows [a] -> [b] on the guide; false when the finger left the stroke.
  bool _follow(StrokeGuide g, Offset a, Offset b) {
    switch (g.move(a, b)) {
      case Follow.on:
        if (a != b) strokes.last.add(b);
        return true;
      case Follow.off:
        _drawing = false;
        _emit(PadEvent.leftPath);
        return false;
      case Follow.completed:
        if (a != b) strokes.last.add(b);
        _drawing = false;
        notifyListeners();
        _emit(g.done ? PadEvent.letterDone : PadEvent.strokeDone);
        return true;
    }
  }

  /// Finger lifted.
  void end() => _drawing = _misplaced = false;

  /// The eraser: the ink goes and the letter starts again from stroke 1.
  void erase() {
    strokes.clear();
    _drawing = false;
    penUsed = false;
    _guide?.reset();
    notifyListeners();
  }

  WritingVerdict judge() => WritingJudge.judge(round, strokes, guide);

  /// The glyph written on this pad: the round's guide, else its target
  /// letter (free writing, the missing letter), or letter [letter] of a
  /// spelled word. Null for sentences and letters without strokes.
  static String? guideKey(WriteRound round, Map<String, List<String>> glyphs, {int letter = 0}) {
    if (round.sentence || round.story) return null;
    final String? key;
    if (round.mode == WriteMode.spell) {
      final w = round.word ?? round.target ?? '';
      key = letter < w.length ? w[letter] : null;
    } else {
      key = round.guide ?? ((round.target?.length ?? 0) == 1 ? round.target : null);
    }
    return key != null && glyphs.containsKey(key) ? key : null;
  }

  /// The strokes of [guideKey] (guide space), one path per stroke.
  static List<Path> guidesFor(WriteRound round, Map<String, List<String>> glyphs, {int letter = 0}) {
    final key = guideKey(round, glyphs, letter: letter);
    if (key == null) return const [];
    return [
      for (final d in glyphs[key]!)
        for (final m in parseSvgPathData(d).computeMetrics()) m.extractPath(0, m.length),
    ];
  }

  static List<String> rawGuides(WriteRound round, Map<String, List<String>> glyphs, {int letter = 0}) {
    final key = guideKey(round, glyphs, letter: letter);
    return key == null ? const [] : glyphs[key]!;
  }
}

/// The writing pad (prototype write area): ruled paper, or [paper] (the
/// wooden sign of a story).
class WritePad extends StatefulWidget {
  const WritePad({
    super.key,
    required this.controller,
    required this.correct,
    this.hint = false,
    required this.round,
    required this.glyphs,
    required this.time,
    required this.onPen,
    this.paper = LikhoColors.surface,
    this.radius = LikhoRadius.writingPad,
  });

  final WritePadController controller;

  /// The writing was accepted (no more ink; it glows).
  final bool correct;

  /// After a mistake: show where to start.
  final bool hint;
  final WriteRound round;

  /// What the pad is drawn on.
  final Color paper;
  final double radius;
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

  /// Flash writing: pad clock time the letter hides (it shows until then).
  late final double _flashUntil = widget.round.mode == WriteMode.flash ? widget.time.value + GameTiming.flash.inMilliseconds / 1000 : 0;

  bool get _flashing => widget.time.value < _flashUntil;

  @override
  void initState() {
    super.initState();
    widget.controller.addEventListener(_onPad);
  }

  @override
  void didUpdateWidget(WritePad old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeEventListener(_onPad);
      widget.controller.addEventListener(_onPad);
      _pointer = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeEventListener(_onPad);
    _sparkClock.dispose();
    super.dispose();
  }

  void _onPad(PadEvent e) {
    final c = widget.controller;
    switch (e) {
      case PadEvent.leftPath:
        c.leftLaneAt = widget.time.value;
        AppFeedback.of(context).offPath();
      case PadEvent.wrongStart:
        c.wrongStartAt = widget.time.value;
        AppFeedback.of(context).offPath();
      case PadEvent.strokeDone:
        AppFeedback.of(context).step(c.guide?.stroke ?? 1);
      case PadEvent.letterDone:
        break; // the round's "correct" celebrates it
    }
  }

  double get _now => _sparkClock.lastElapsedDuration == null ? 0 : _sparkClock.lastElapsedDuration!.inMicroseconds / 1e6;

  void _down(PointerDownEvent e) {
    if (widget.correct || _pointer != null || _flashing) return;
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
    if (widget.correct || e.pointer != _pointer) return;
    widget.onPen(e.position);
    if (!widget.controller.extend(e.localPosition)) return; // outside the lane: no ink, no sparks
    if (_rnd.nextDouble() < .35) {
      _sparks.add(_Spark(e.localPosition, GameColors.sparks[_rnd.nextInt(4)], (_rnd.nextDouble() - .5) * 40, -10 - _rnd.nextDouble() * 30, _now));
      _sparks.removeWhere((s) => _now - s.born > .6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = WritePadController.rawGuides(widget.round, widget.glyphs, letter: widget.controller.letter);
    final noGuide = widget.controller.guides.isEmpty;
    final freeHint = widget.round.mode == WriteMode.free && widget.round.sentence && !widget.correct
        ? 'Write: ${widget.round.target ?? 'your own story'}'
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: const [
          BoxShadow(color: GameColors.ink06, offset: Offset(0, 8)),
          BoxShadow(color: GameColors.ink10, offset: Offset(0, 16), blurRadius: 40),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
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
                    child: ColoredBox(color: widget.paper),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GuidePainter(
                          mode: widget.round.mode,
                          guides: widget.controller.guides,
                          raw: raw,
                          hint: widget.hint,
                          time: widget.time,
                          controller: widget.controller,
                          flashUntil: _flashUntil,
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
                  if (widget.hint && noGuide) Positioned(left: 24, top: 24, child: _StartHere(time: widget.time)),
                  if (widget.round.mode == WriteMode.flash) Positioned.fill(child: _FlashCover(text: widget.round.target ?? '', word: noGuide, until: _flashUntil, time: widget.time)),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _InkPainter(controller: widget.controller, correct: widget.correct),
                      ),
                    ),
                  ),
                  if (!noGuide)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _StepPainter(
                              controller: widget.controller,
                              hint: widget.hint,
                              time: widget.time,
                              memory: widget.round.mode == WriteMode.flash,
                              flashUntil: _flashUntil,
                            ),
                          ),
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
                  if (widget.correct) const Positioned.fill(child: CorrectGlow(inner: true)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ruled lines, the letter's lane and guide, and the step-by-step marks:
/// finished strokes turn green, the current one shows its start (a pulsing
/// numbered dot) and its direction (chevrons marching to its end).
class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.mode,
    required this.guides,
    required this.raw,
    required this.hint,
    required this.time,
    required this.controller,
    this.flashUntil = 0,
  }) : super(repaint: guides.isNotEmpty ? Listenable.merge([time, controller]) : (hint ? time : null));

  final WriteMode mode;
  final List<Path> guides;
  final List<String> raw;
  final bool hint;
  final ValueNotifier<double> time;
  final WritePadController controller;

  /// Flash writing: when the letter hides (pad clock seconds).
  final double flashUntil;

  /// How long the lane / start marker flashes after a slip (seconds).
  static const laneFlash = .45;

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
    if (guides.isEmpty) return;

    final g = controller.guide;
    final current = g?.stroke ?? 0;
    final t = time.value;
    double flashOf(double? at) => at == null ? 0.0 : (1 - (t - at) / laneFlash).clamp(0.0, 1.0);

    canvas.save();
    geo.apply(canvas);
    if (mode == WriteMode.flash) {
      // the letter shows in ink, then fades away (the last .4 s)
      final shown = ((flashUntil - t) / .4).clamp(0.0, 1.0);
      if (shown > 0) {
        final ink = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 7
          ..color = LikhoColors.ink.withValues(alpha: shown);
        for (final path in guides) {
          canvas.drawPath(path, ink);
        }
        canvas.restore();
        return;
      }
    }
    // from memory: no lane to see unless the finger slips or after a mistake
    final memory = mode == WriteMode.flash && !hint;
    // the lane: where ink may go; finished strokes are green, the current
    // one flashes when the finger slips off it
    const base = GameColors.lanePaper;
    final flash = flashOf(controller.leftLaneAt);
    for (final (i, path) in guides.indexed) {
      if (memory && i >= current && flash == 0) continue;
      final lane = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = WritingJudge.laneWidth
        ..color = i < current
            ? GameColors.laneDone
            : i == current
            ? Color.lerp(memory ? LikhoColors.clear : base, LikhoColors.hint.withValues(alpha: .35), flash)!
            : (memory ? LikhoColors.clear : base);
      canvas.drawPath(path, lane);
    }
    if (mode == WriteMode.trace) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 7
        ..color = GameColors.guidePaper;
      for (final path in guides) {
        canvas.drawPath(path, stroke);
      }
    } else if (current < guides.length && !memory) {
      // writing without a traced letter: a dashed line shows the stroke's path
      canvas.drawPath(
        _dashed(guides[current], 2.2, 2.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.2
          ..color = GameColors.guideDashed,
      );
    }
    if (mode == WriteMode.dots) {
      final pts = <Offset>[];
      for (final d in raw) {
        for (final m in _points.allMatches(d)) {
          final q = Offset(double.parse(m[1]!), double.parse(m[2]!));
          if (!pts.contains(q)) pts.add(q);
        }
      }
      for (final q in pts) {
        canvas.drawCircle(q, 2.6, Paint()..color = LikhoColors.ink);
      }
    }
    canvas.restore();
  }

  static Path _dashed(Path p, double on, double off) => dashPath(p, dashArray: CircularIntervalList<double>([on, off]));

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.mode != mode || old.guides != guides || old.hint != hint || old.controller != controller || old.flashUntil != flashUntil;
}

/// The step-by-step marks, drawn over the ink: where the current stroke
/// starts or carries on (a pulsing numbered dot that jumps when the finger
/// went down elsewhere), which way it goes (arrows marching to its end, a
/// ring at the end) and, after a mistake, a finger running along it.
class _StepPainter extends CustomPainter {
  _StepPainter({required this.controller, required this.hint, required this.time, this.memory = false, this.flashUntil = 0})
    : super(repaint: Listenable.merge([time, controller]));

  final WritePadController controller;
  final bool hint;
  final ValueNotifier<double> time;

  /// Flash writing: only where to start shows (no arrows), until a mistake;
  /// nothing while the letter shows.
  final bool memory;
  final double flashUntil;

  @override
  void paint(Canvas canvas, Size size) {
    final g = controller.guide;
    final t = time.value;
    double flashOf(double? at) => at == null ? 0.0 : (1 - (t - at) / _GuidePainter.laneFlash).clamp(0.0, 1.0);

    if (g == null || g.done || t < flashUntil) return;
    final pts = g.points;
    final h = g.lane.halfWidth;

    if (memory && !hint) {
      _start(canvas, g, h, t, flashOf);
      return;
    }

    // direction: arrows marching from the written part to the end
    _arrows(canvas, pts, from: g.reached, spacing: h * 1.2, size: h * .42, shift: (t * h * 1.1) % (h * 1.2));
    // the end of the stroke: a hollow ring
    canvas.drawCircle(
      pts.last,
      h * .32,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = GameColors.stepArrow,
    );

    if (hint) {
      // hintDraw 1.4 s: a finger dot runs along the stroke, leaving a trail
      final p = Curves.easeInOut.transform((t / 1.4) % 1.0);
      final k = (math.min(1.0, p / .7) * (pts.length - 1)).round();
      final alpha = p < .7 ? 1.0 : 1 - (p - .7) / .3;
      final trail = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i <= k; i++) {
        trail.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = h * .42
          ..color = LikhoColors.hint.withValues(alpha: alpha),
      );
      canvas.drawCircle(pts[k], h * .36, Paint()..color = LikhoColors.hint.withValues(alpha: alpha));
    }

    _start(canvas, g, h, t, flashOf);
  }

  /// Where to start (or carry on): a pulsing numbered dot; it jumps when
  /// the finger went down somewhere else.
  void _start(Canvas canvas, StrokeGuide g, double h, double t, double Function(double?) flashOf) {
    final at = g.resumeAt!;
    final pulse = Curves.easeOut.transform((t / 1.4) % 1.0);
    final nudge = flashOf(controller.wrongStartAt);
    final r = h * .5 * (1 + .35 * math.sin(nudge * math.pi));
    canvas.drawCircle(at, r * (1 + .9 * pulse), Paint()..color = LikhoColors.primary.withValues(alpha: .65 * (1 - pulse)));
    canvas.drawCircle(at, r, Paint()..color = Color.lerp(LikhoColors.secondary, LikhoColors.hint, nudge)!);
    if (g.reached == 0) _text(canvas, '${g.stroke + 1}', at, r * 1.15, LikhoColors.surface);
  }

  /// Arrowheads along [pts] from point [from] on, every [spacing] px.
  void _arrows(Canvas canvas, List<Offset> pts, {required int from, required double spacing, required double size, required double shift}) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = GameColors.stepArrow;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size * .3
      ..color = GameColors.stepArrow;
    var run = 0.0, next = spacing * .8 + shift;
    for (var i = from + 1; i < pts.length; i++) {
      final seg = pts[i] - pts[i - 1];
      final len = seg.distance;
      if (len == 0) continue;
      while (run + len >= next) {
        final q = pts[i - 1] + seg * ((next - run) / len);
        // stop before the end ring
        if ((pts.last - q).distance < size * 1.4) return;
        final dir = seg / len;
        final tip = q + dir * size * .5, back = q - dir * size * .5, side = Offset(-dir.dy, dir.dx) * size * .62;
        final head = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(back.dx + side.dx, back.dy + side.dy)
          ..lineTo(back.dx - side.dx, back.dy - side.dy)
          ..close();
        canvas
          ..drawPath(head, paint)
          ..drawPath(head, edge); // rounds the corners
        next += spacing;
      }
      run += len;
    }
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

  @override
  bool shouldRepaint(_StepPainter old) => old.controller != controller || old.hint != hint || old.memory != memory || old.flashUntil != flashUntil;
}

class _InkPainter extends CustomPainter {
  _InkPainter({required this.controller, required this.correct}) : super(repaint: controller);
  final WritePadController controller;
  final bool correct;

  @override
  void paint(Canvas canvas, Size size) {
    final g = controller.guide;
    final paths = g != null ? _written(g) : [for (final st in controller.strokes) if (st.isNotEmpty) _smooth(st)];
    final width = g != null ? math.max(10.0, g.lane.halfWidth * .62) : 14.0;
    if (correct) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = GameColors.successInk
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      for (final p in paths) {
        canvas.drawPath(p, glow);
      }
    }
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = correct ? LikhoColors.success : LikhoColors.ink;
    for (final p in paths) {
      canvas.drawPath(p, ink);
    }
  }

  /// The finished strokes, and the current one up to where the finger is.
  static List<Path> _written(StrokeGuide g) => [
    for (var i = 0; i < math.min(g.stroke + 1, g.count); i++)
      if (i < g.stroke || g.reached > 0) _smooth(g.lane.strokes[i].sublist(0, (i < g.stroke ? g.lane.strokes[i].length - 1 : g.reached) + 1)),
  ];

  static Path _smooth(List<Offset> st) {
    final p = Path()..moveTo(st.first.dx, st.first.dy);
    for (var i = 1; i < st.length - 1; i++) {
      final mid = (st[i] + st[i + 1]) / 2;
      p.quadraticBezierTo(st[i].dx, st[i].dy, mid.dx, mid.dy);
    }
    return p..lineTo(st.last.dx, st.last.dy + .01);
  }

  // a new pad (the next letter of a word) starts clean
  @override
  bool shouldRepaint(_InkPainter old) => old.controller != controller || old.correct != correct;
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
/// "Start here" with a bobbing arrow, after a mistake on a
/// pad without guides.
/// Flash writing: "Look!" with a shrinking bar while the letter shows; a
/// word without letter guides shows here in big type. Gone once it hides.
class _FlashCover extends StatelessWidget {
  const _FlashCover({required this.text, required this.word, required this.until, required this.time});
  final String text;
  final bool word;
  final double until;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, _) {
        final left = until - t;
        if (left <= 0) return const SizedBox.shrink();
        final total = GameTiming.flash.inMilliseconds / 1000;
        final shown = (left / .4).clamp(0.0, 1.0);
        return Stack(
          children: [
            if (word)
              Center(
                child: Opacity(
                  opacity: shown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: LikhoFonts.letter(size: 72).copyWith(height: 1))),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 14,
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.visibility_rounded, size: 22, fill: 1, color: LikhoColors.secondary),
                      const SizedBox(width: 6),
                      Text('Look!', style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: LikhoColors.secondary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 120,
                    height: 8,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: GameColors.ink08, borderRadius: BorderRadius.circular(4)),
                    child: FractionallySizedBox(
                      widthFactor: (left / total).clamp(0.0, 1.0),
                      child: Container(decoration: BoxDecoration(color: LikhoColors.secondary, borderRadius: BorderRadius.circular(4))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

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
            'Start here',
            style: LikhoFonts.title(size: 16, weight: FontWeight.w800, color: LikhoColors.hint),
          ),
        ],
      ),
    );
  }
}

/// Eraser + "Done" under the pad.
class WriteBar extends StatelessWidget {
  const WriteBar({super.key, required this.onErase, required this.onDone});
  final VoidCallback onErase, onDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PushButton(
            onTap: onErase,
            color: LikhoColors.surface,
            width: 62,
            height: 62,
            shape: const CircleBorder(),
            shadows: const [BoxShadow(color: GameColors.ink10, offset: Offset(0, 6))],
            child: const Icon(Symbols.ink_eraser_rounded, size: 32, fill: 1, opticalSize: 32, color: GameColors.eraser),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: PushButton(
                onTap: onDone,
                color: LikhoColors.success,
                edgeColor: GameColors.successDeep,
                edge: 6,
                height: 66,
                pressScale: .96,
                innerHighlight: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.check_rounded, size: 32, fill: 1, weight: 700, opticalSize: 32, color: LikhoColors.surface),
                    const SizedBox(width: 10),
                    Text('Done', style: LikhoFonts.title(size: 21, color: LikhoColors.surface).copyWith(height: 1)),
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
