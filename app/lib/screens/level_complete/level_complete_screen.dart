import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../data/models/course_models.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../../feedback/app_feedback.dart';
import '../../feedback/game_feedback.dart';
import '../../feedback/sfx.dart';
import '../common/clock.dart';
import '../common/effects.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';
import '../gameplay/widgets/illustration.dart';

/// 13 Level complete (3 stars / 1 star / "Boss woken"), from the prototype.
///
/// Timeline (s): title pops at .2; each earned star drops in at .45 + .7 i
/// with a yellow flash; "+N" pops at 2.4; with 3 stars confetti falls from
/// 2.2. Pencil cheers, says "wow" for 3 stars, dances, then rests. On a boss
/// level the woken boss pops in at 1 s and dances with him.
class LevelCompleteScreen extends ConsumerStatefulWidget {
  const LevelCompleteScreen({super.key, required this.level, required this.outcome, required this.onAgain, required this.onNext});

  final CourseLevel level;
  final LevelOutcome outcome;
  final VoidCallback onAgain, onNext;

  static String titleFor(int stars) => stars == 3 ? 'Zabardast!' : (stars == 2 ? 'Bohat khoob!' : 'Shabash!');

  @override
  ConsumerState<LevelCompleteScreen> createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends ConsumerState<LevelCompleteScreen> {
  MascotState _expr = MascotState.happy;
  int _replay = 0;
  final List<Timer> _timers = [];

  int get _stars => widget.outcome.stars;

  @override
  void initState() {
    super.initState();
    ref.read(feedbackProvider).prepare([
      Sfx.completeTada, Sfx.star(1), Sfx.star(2), Sfx.star(3), Sfx.coin, //
      if (_stars == 3) ...[Sfx.confetti, Sfx.perfect],
      if (widget.level.isBoss) Sfx.bossWake,
    ]);
    final st = _stars;
    _at(400 + st * 700, st == 3 ? MascotState.wow : MascotState.happy);
    _at(1400 + st * 700, MascotState.dance);
    _at(3400 + st * 700, MascotState.idle);
  }

  void _at(int ms, MascotState s) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) {
        setState(() {
          _expr = s;
          _replay++;
        });
      }
    }),
  );

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseProvider).value;
    final world = course?.worldOf(widget.level);
    final theme = LikhoWorlds.byId(world?.themeId ?? 'letterLand');
    final reduce = ref.watch(reduceMotionProvider);
    final fg = theme.dark ? LikhoColors.surface : LikhoColors.ink;
    final o = widget.outcome;
    final last = widget.level.number == 36;
    return StatusBar(
      light: theme.dark,
      child: Material(
        color: theme.bg,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CssRadialBackground(center: Offset(.5, .3), colors: [CompleteColors.glow, GameColors.white00], stops: [0, .6]),
            ),
            for (var i = 0; i < _stars; i++)
              Positioned.fill(
                child: IgnorePointer(child: _Flash(delay: .7 + i * .7)),
              ),
            if (_stars == 3 && !reduce)
              Positioned.fill(
                child: IgnorePointer(child: _Confetti(seed: o.level * 31 + 7)),
              ),
            // sound + haptics, beat by beat with the animation
            FeedbackCue(at: 0, play: (f) => f.levelComplete()),
            for (var i = 0; i < _stars; i++)
              FeedbackCue(
                at: .75 + i * .7,
                play: (f) => f.star(i + 1, perfect: i == 2),
              ),
            if (widget.level.isBoss) FeedbackCue(at: 1, play: (f) => f.bossWake()),
            if (_stars == 3) FeedbackCue(at: 2.2, play: (f) => f.confetti()),
            FeedbackCue(at: 2.4, play: (f) => f.coin()),
            if (_stars == 3) FeedbackCue(at: 1.4 + 3 * .7, play: (f) => f.perfect()),
            MaxWidth(
              width: 460,
              child: ScrollFill(
                padding: EdgeInsets.fromLTRB(24, frameTop(context, 78), 24, 40),
                child: Column(
                  children: [
                    Text(
                      widget.level.name.toUpperCase(),
                      style: LikhoFonts.title(size: 16, color: theme.accent).copyWith(letterSpacing: 16 * .06, height: 1.6), // CSS line-height: normal
                    ),
                    const SizedBox(height: 4),
                    BigPop(
                      delay: .2,
                      seconds: .5,
                      child: Text(
                        LevelCompleteScreen.titleFor(_stars),
                        style: LikhoFonts.title(size: 40, weight: FontWeight.w800, color: fg),
                      ),
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      height: 130,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // light rays behind a perfect score, once the third star is in
                          if (_stars == 3) const OverflowBox(maxWidth: 360, maxHeight: 360, child: Sunburst(size: 360, delay: 2.2)),
                          // scales down on phones narrower than the three slots
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomCenter,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (var i = 0; i < 3; i++) ...[
                                  if (i > 0) const SizedBox(width: 14),
                                  _StarSlot(big: i == 1, filled: i < _stars, delay: .45 + i * .7),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    PopIn(delay: 2.4, child: _GainPill(gain: o.gain)),
                    if (o.level == 35) ...[const SizedBox(height: 16), RiseIn(delay: 2.6, seconds: .4, child: _StoryCard(choices: o.choices))],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.level.isBoss) ...[
                          PopIn(
                            delay: 1,
                            seconds: .5,
                            child: BossFigure(world: (world?.order ?? 1) - 1, dance: _expr == MascotState.dance),
                          ),
                          const SizedBox(width: 6),
                        ],
                        PencilFigure(width: 150, height: 212, state: _expr, replay: _replay),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        CircleIconButton(
                          icon: Symbols.replay_rounded,
                          onTap: widget.onAgain,
                          size: 80,
                          iconSize: 38,
                          iconColor: LikhoColors.secondary,
                          shadow: GameColors.ink10,
                          shadowY: 6,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: BigButton(
                            label: last ? 'Certificate' : 'Aage chalo',
                            iconAfter: Symbols.arrow_forward_rounded,
                            iconSize: 30,
                            onTap: widget.onNext,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round slot for one star; an earned star drops into it (starDrop .55 s).
class _StarSlot extends StatelessWidget {
  const _StarSlot({required this.big, required this.filled, required this.delay});
  final bool big, filled;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final size = big ? 112.0 : 92.0;
    final fs = big ? 96.0 : 78.0;
    final landed = delay + .3; // the star touches down at 55 % of its .55 s drop
    return Transform.translate(
      offset: Offset(0, big ? -26 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(color: CompleteColors.starSlot, shape: BoxShape.circle),
            child: CustomPaint(
              painter: const _InsetBlur(),
              child: Center(
                child: OverflowBox(
                  maxWidth: fs,
                  maxHeight: fs,
                  child: filled
                      ? Entrance(
                          delay: Duration(milliseconds: (delay * 1000).round()),
                          duration: const Duration(milliseconds: 550),
                          builder: (context, t, child) {
                            if (t <= 0) return const SizedBox.shrink();
                            final y = keyframes(t, const [(0, -320), (.55, 14), (.75, -8), (1, 0)], dropEase);
                            final sx = keyframes(t, const [(0, .4), (.55, 1.18), (.75, .95), (1, 1)], dropEase);
                            final sy = keyframes(t, const [(0, .4), (.55, .86), (.75, 1.05), (1, 1)], dropEase);
                            final r = keyframes(t, const [(0, -120), (.55, 8), (.75, 0), (1, 0)], dropEase);
                            return Opacity(
                              opacity: (t / .55).clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, y),
                                child: Transform.rotate(
                                  angle: r * math.pi / 180,
                                  child: Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(sx, sy, 1), child: child),
                                ),
                              ),
                            );
                          },
                          child: SymbolIcon(
                            Symbols.star_rounded,
                            size: fs,
                            fill: true,
                            color: LikhoColors.primary,
                            shadows: const [
                              Shadow(color: LikhoColors.primaryDeep, offset: Offset(0, 5)),
                              Shadow(color: CompleteColors.starGlow, blurRadius: 30),
                            ],
                          ),
                        )
                      : SymbolIcon(Symbols.star_rounded, size: fs, fill: true, color: CompleteColors.starEmpty),
                ),
              ),
            ),
          ),
          if (filled) SparkleBurst(size: size * 1.9, delay: landed, count: big ? 12 : 9, seed: size.round()),
        ],
      ),
    );
  }
}

/// inset 0 4px 10px rgba(43,45,66,.1)
class _InsetBlur extends CustomPainter {
  const _InsetBlur();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final circle = Path()..addOval(r);
    canvas.save();
    canvas.clipPath(circle);
    final hole = Path.combine(PathOperation.difference, Path()..addRect(r.inflate(30)), Path()..addOval(r.shift(const Offset(0, 4))));
    canvas.drawPath(
      hole,
      Paint()
        ..color = CompleteColors.starSlotShade
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetBlur old) => false;
}

class _GainPill extends StatelessWidget {
  const _GainPill({required this.gain});
  final int gain;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: LikhoColors.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 4))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SymbolIcon(Symbols.star_rounded, size: 24, fill: true, color: LikhoColors.primary),
        const SizedBox(width: 6),
        Text('+$gain', style: LikhoFonts.title(size: 20, weight: FontWeight.w800)),
      ],
    ),
  );
}

/// My Story (level 35): the child's picks made into a sentence.
class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.choices});
  final Map<String, String> choices;

  @override
  Widget build(BuildContext context) {
    final who = choices['who'] ?? 'cat', what = choices['what'] ?? 'kite', where = choices['where'] ?? 'moon';
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GameColors.paperNote,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: GameColors.ink12, offset: Offset(0, 10), blurRadius: 30)],
      ),
      child: Row(
        children: [
          Illustration(
            picture: Picture(key: 'story-$who-$what-$where', label: '$who + $what on $where'),
            width: 92,
            height: 80,
            radius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MERI KAHANI',
                  style: LikhoFonts.body(size: 12, weight: FontWeight.w800, color: UiColors.inkHint).copyWith(letterSpacing: 12 * .06),
                ),
                const SizedBox(height: 4),
                Text('My $who can fly with a $what.', style: LikhoFonts.letter(size: 20).copyWith(height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// flash .5 s: a warm white wash, peaking at 45 % opacity.
class _Flash extends StatelessWidget {
  const _Flash({required this.delay});
  final double delay;

  @override
  Widget build(BuildContext context) => Entrance(
    delay: Duration(milliseconds: (delay * 1000).round()),
    duration: const Duration(milliseconds: 500),
    child: const ColoredBox(color: CompleteColors.flash),
    builder: (context, t, child) {
      final o = keyframes(t, const [(0, 0), (.3, .45), (1, 0)], Curves.easeOut);
      return o <= 0 ? const SizedBox.shrink() : Opacity(opacity: o, child: child);
    },
  );
}

/// 44 confetti pieces falling from the top (prototype completeVals: seeded
/// sizes, colours, speeds and delays).
class _Confetti extends StatefulWidget {
  const _Confetti({required this.seed});
  final int seed;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin, ClockMixin {
  late final List<_Piece> _pieces = () {
    var seed = widget.seed;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    return [
      for (var i = 0; i < 44; i++)
        _Piece(
          x: rnd(),
          w: 8 + rnd() * 8,
          h: 10 + rnd() * 10,
          round: rnd() > .5,
          color: GameColors.confetti[i % 5],
          dur: 2.2 + rnd() * 1.6,
          delay: 2.2 + rnd() * 1.4,
        ),
    ];
  }();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ConfettiPainter(_pieces, clock));
}

class _Piece {
  const _Piece({required this.x, required this.w, required this.h, required this.round, required this.color, required this.dur, required this.delay});
  final double x, w, h, dur, delay;
  final bool round;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.clock) : super(repaint: clock);
  final List<_Piece> pieces;
  final ValueNotifier<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final p = Paint();
    for (final c in pieces) {
      final k = ((t - c.delay) / c.dur).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final y = -30 + (-40 + 1000 * k);
      canvas.save();
      canvas.translate(size.width * c.x + c.w / 2, y + c.h / 2);
      canvas.rotate(760 * k * math.pi / 180);
      final r = Rect.fromCenter(center: Offset.zero, width: c.w, height: c.h);
      p.color = c.color;
      if (c.round) {
        canvas.drawOval(r, p);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
