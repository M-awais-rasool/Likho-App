import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../world_map/boss_painter.dart';
import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../design/tokens.dart';
import '../../game/level_resume.dart';
import '../../game/level_session.dart';
import '../../game/speech/prompt_voice.dart';
import '../../game/writing/stroke_guide.dart';
import '../../mascot/mascot.dart';
import 'rounds/fix_round_view.dart';
import 'rounds/hunt_round_view.dart';
import 'rounds/match_round_view.dart';
import 'rounds/order_round_view.dart';
import 'rounds/pick_round_view.dart';
import 'rounds/pop_round_view.dart';
import 'rounds/speak_round_view.dart';
import 'rounds/truth_round_view.dart';
import 'rounds/write_round_view.dart';
import 'widgets/game_bits.dart';
import 'widgets/game_buttons.dart';

/// Result handed back when the last round is won.
class LevelResult {
  const LevelResult({required this.level, required this.stars, required this.mistakes});
  final CourseLevel level;
  final int stars, mistakes;
}

class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key, required this.level, required this.onExit, required this.onFinished});

  final CourseLevel level;
  final VoidCallback onExit;
  final ValueChanged<LevelResult> onFinished;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen> with TickerProviderStateMixin {
  static const _praise = ['Wow!', 'Great job!', 'Awesome!', 'Amazing!'];

  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  late final AnimationController _flip = AnimationController(vsync: this);
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  final _mascot = MascotController();
  final _mascotKey = GlobalKey();
  final _areaKey = GlobalKey();

  late final PromptVoice _voice = ref.read(promptVoiceProvider);
  late SessionState _view; // what's on screen (lags the session during the round flip)
  bool _flipOut = true;
  WritePadController? _pad;
  String? _bubble;
  Timer? _bubbleTimer;
  final _timers = <Timer>[];
  int _burst = 0;
  bool _done = false;

  CourseLevel get level => widget.level;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
    _mascot.setBodyColor(ref.read(progressProvider).color.key);
    _voice; // resolve while mounted (ref is not usable in dispose)
    final back = _resume();
    _view = ref.read(levelSessionProvider(level));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRound();
      if (back) _say('Welcome back!', const Duration(milliseconds: 1600));
    });
  }

  /// The active child; null in the placement warm-up (never resumed).
  String? get _childId => level.placement ? null : ref.read(familyProvider).active.id;

  /// Goes on where the child left this level; true when it did.
  bool _resume() {
    final child = _childId;
    if (child == null) return false;
    final p = ref.read(levelResumeProvider.notifier).pointFor(child, level);
    if (p == null) return false;
    ref.read(levelSessionProvider(level).notifier).resumeAt(p.round, mistakes: p.mistakes, choices: p.choices);
    return ref.read(levelSessionProvider(level)).round == p.round;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _flip.dispose();
    _shake.dispose();
    _bubbleTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _pad?.dispose();
    _voice.stop();
    _mascot.dispose();
    super.dispose();
  }

  Map<String, List<String>> get _glyphs => ref.read(courseProvider).value?.glyphs ?? const {};

  bool get _writing => _view.current is WriteRound;

  MascotState get _resting => _writing ? MascotState.watching : MascotState.idle;

  // ------------------------------------------------------------ round life

  void _startRound() {
    if (!mounted) return;
    final r = _view.current;
    _setPad(r is WriteRound ? r : null);
    final say = r.prompt.text;
    _say(say.length <= 14 ? say : 'Listen!', const Duration(milliseconds: 1600));
    _lookAtArea();
    _voice.speak(r.prompt, _mascot, after: _resting);
  }

  /// Runs [f] after [d] unless the screen is gone by then.
  void _later(Duration d, VoidCallback f) {
    _timers.removeWhere((t) => !t.isActive);
    _timers.add(Timer(d, () {
      if (mounted) f();
    }));
  }

  /// A new writing pad for [r] (letter [letter] of a spelled word), or none.
  void _setPad(WriteRound? r, {int letter = 0}) {
    final old = _pad;
    old?.removeEventListener(_onPad);
    // the pad widget lets go of the old one when it rebuilds
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _pad = r == null ? null : (WritePadController(round: r, guides: WritePadController.guidesFor(r, _glyphs, letter: letter), letter: letter)..addEventListener(_onPad));
  }

  /// Step-by-step writing: Pencil says what to do next.
  void _onPad(PadEvent e) {
    if (!mounted) return;
    switch (e) {
      case PadEvent.strokeDone:
        _mascot.play(MascotState.happy);
        _bubbleTimer?.cancel();
        setState(() => _bubble = null); // the next stroke's instruction shows
        _later(const Duration(milliseconds: 600), () {
          if (!ref.read(levelSessionProvider(level)).correct) _mascot.play(MascotState.watching);
        });
      case PadEvent.letterDone:
        final pad = _pad;
        setState(() {});
        _later(const Duration(milliseconds: 250), () {
          if (pad == _pad) ref.read(levelSessionProvider(level).notifier).submitWriting(pad!.judge());
        });
      case PadEvent.wrongStart:
        _say('Start at the blue dot!', const Duration(milliseconds: 1500));
      case PadEvent.leftPath:
        // off right after the start: most likely the wrong way
        final early = (_pad?.guide?.progress ?? 1) < .35;
        _say(early ? 'Follow the arrow!' : 'Stay on the line!', const Duration(milliseconds: 1300));
    }
  }

  /// What to do with the stroke being written, as Pencil says it.
  static String stepText(StrokeShape s) => switch (s) {
    StrokeShape.dot => 'Add a dot',
    StrokeShape.down => 'Top to bottom',
    StrokeShape.up => 'Bottom to top',
    StrokeShape.right => 'Left to right',
    StrokeShape.left => 'Right to left',
    StrokeShape.slantDown => 'Slant down',
    StrokeShape.slantUp => 'Slant up',
    StrokeShape.curve => 'Curve around',
    StrokeShape.zigzag => 'Follow the arrow',
  };

  /// The bubble: a passing remark, else the instruction for the stroke
  /// being written.
  (String, int?)? get _speech {
    if (_bubble != null) return (_bubble!, null);
    final g = _pad?.guide;
    if (g == null || g.done || _view.correct) return null;
    return (stepText(g.shapeOf(g.stroke)), g.stroke + 1);
  }

  void _replay() {
    _bubbleTimer?.cancel();
    setState(() => _bubble = null);
    _voice.speak(_view.current.prompt, _mascot, after: _resting);
  }

  void _say(String? text, Duration d) {
    _bubbleTimer?.cancel();
    setState(() => _bubble = text);
    _bubbleTimer = Timer(d, () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  /// Non-writing rounds: Pencil looks down at the play area (lookY .2).
  void _lookAtArea() {
    if (_writing) return;
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    final m = _mascotKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || m == null) return;
    final c = m.localToGlobal(m.size.center(Offset.zero));
    _mascot.lookAt(c + const Offset(0, 60));
  }

  void _onSession(SessionState? prev, SessionState next) {
    if (prev == null) return;
    final child = _childId;
    if (child != null && next.round > prev.round && !next.finished) {
      ref.read(levelResumeProvider.notifier).save(child, level, round: next.round, mistakes: next.mistakes, choices: next.choices);
    }
    if (next.round != prev.round) {
      // flip the old round away, then flip the new one in (prototype next())
      _flipOut = true;
      _flip.duration = const Duration(milliseconds: 260);
      _flip.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _view = ref.read(levelSessionProvider(level));
          _flipOut = false;
        });
        _flip.duration = const Duration(milliseconds: 320);
        _flip.forward(from: 0);
        _startRound();
        if (_view.isHalfway) _halfway();
      });
      return;
    }
    setState(() => _view = next);
    if (next.feedback != prev.feedback) {
      switch (next.feedback) {
        case RoundFeedback.correct:
          _burst++;
          _voice.stop();
          _mascot.play(MascotState.happy);
          _say(_praise[next.round % 4], const Duration(milliseconds: 1350));
          HapticFeedback.lightImpact();
        case RoundFeedback.wrong:
          _shake.forward(from: 0);
          _mascot.play(MascotState.encourage);
          _say('Try again!', const Duration(milliseconds: 1300));
        case RoundFeedback.none:
          if (prev.feedback == RoundFeedback.wrong) _mascot.play(_resting);
      }
    }
    if (next.spellFilled > prev.spellFilled && !next.correct) {
      final r = next.current;
      if (r is WriteRound && next.spellFilled < (r.word ?? r.target ?? '').length) _setPad(r, letter: next.spellFilled);
      _mascot.play(MascotState.happy);
      _say('Wow!', const Duration(milliseconds: 700));
      _later(const Duration(milliseconds: 700), () {
        if (!ref.read(levelSessionProvider(level)).correct) _mascot.play(MascotState.watching);
      });
    }
    if (next.listening && !prev.listening) {
      _mascot.play(MascotState.watching);
      _say('Say it!', GameTiming.listening);
    }
    if (next.finished && !_done) {
      _done = true;
      if (child != null) ref.read(levelResumeProvider.notifier).clear(child, level);
      widget.onFinished(LevelResult(level: level, stars: next.stars, mistakes: next.mistakes));
    }
  }

  /// Halfway through a long level: Pencil cheers and confetti flies.
  void _halfway() {
    _burst++;
    _mascot.play(MascotState.happy);
    _say('Halfway there!', const Duration(milliseconds: 1600));
    _later(const Duration(milliseconds: 900), () => _mascot.play(_resting));
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    ref.listen(levelSessionProvider(level), _onSession);
    final course = ref.watch(courseProvider).value;
    final world = course?.worldOf(level);
    final theme = LikhoWorlds.byId(world?.themeId ?? 'letterLand');
    final s = _view;
    final pad = MediaQuery.paddingOf(context);
    final write = s.current is WriteRound ? s.current as WriteRound : null;
    final hasBoxes = write != null && (write.mode == WriteMode.missing || write.mode == WriteMode.spell);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (theme.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: LikhoColors.clear),
      child: Material(
        color: theme.bg,
        child: Stack(
          children: [
            Positioned(left: -60, bottom: -60, width: 220, height: 220, child: _SoftCircle(color: theme.soft, opacity: .7)),
            Positioned(right: -80, top: 120, width: 200, height: 200, child: _SoftCircle(color: theme.soft, opacity: .5)),
            Padding(
              // prototype: 54 px from the top of the 844 frame = 7 px under its status bar
              padding: EdgeInsets.fromLTRB(24, pad.top + 7, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 56,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        HomeButton(onTap: widget.onExit),
                        ProgressDots(count: s.roundCount, current: s.round, currentDone: s.correct, dark: theme.dark),
                        const SizedBox(width: 56),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Pencil on the left; what he says next to his face, the
                  // prompt card under it (the bubble never covers the card)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        key: _mascotKey,
                        width: 78,
                        height: 120,
                        child: OverflowBox(maxWidth: 90, child: PencilMascot(controller: _mascot, size: 110)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 36,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: switch (_speech) {
                                  (final text, final step) => SpeechBubble(text: text, step: step),
                                  null => const SizedBox.shrink(),
                                },
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: PromptCardView(key: ValueKey(s.current.id), card: s.current.card),
                                ),
                                const SizedBox(width: 12),
                                ReplayButton(onTap: _replay),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (level.isBoss) ...[
                          BossStrip(
                            world: BossPainter.indexOf(world?.bossId ?? ''),
                            rounds: s.roundCount,
                            done: s.round + (s.correct ? 1 : 0),
                            awake: s.correct && s.isLastRound,
                            time: _time,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (hasBoxes) ...[LetterBoxes(round: write, spellFilled: s.spellFilled, correct: s.correct), const SizedBox(height: 12)],
                        Expanded(child: _animatedArea(s)),
                        if (write != null) ...[
                          const SizedBox(height: 12),
                          WriteBar(
                            onErase: () => setState(() => _pad?.erase()),
                            onDone: () {
                              final p = _pad;
                              if (p != null) ref.read(levelSessionProvider(level).notifier).submitWriting(p.judge());
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Play area with the round flip (rotateX from the top edge) and the
  /// wrong-answer shake; confetti bursts from its centre.
  Widget _animatedArea(SessionState s) {
    final area = KeyedSubtree(
      key: _areaKey,
      child: _RoundArea(state: s, pad: _pad, glyphs: _glyphs, time: _time, onPen: _mascot.lookAt),
    );
    return ConfettiBurst(
      trigger: _burst,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flip, _shake]),
        child: area,
        builder: (context, child) {
          var w = child!;
          if (_shake.isAnimating) {
            const xs = [0.0, -6.0, 6.0, -6.0, 6.0, 0.0];
            final v = _shake.value * 5, q = v.floor().clamp(0, 4);
            w = Transform.translate(offset: Offset(xs[q] + (xs[q + 1] - xs[q]) * (v - q), 0), child: w);
          }
          if (_flip.isAnimating || (_flipOut && _flip.value == 1)) {
            final v = _flip.value;
            final angle = _flipOut ? -75 * Curves.easeIn.transform(v) : 70 * (1 - const Cubic(.2, .8, .3, 1).transform(v));
            final opacity = _flipOut ? 1 - v : v;
            w = Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 1 / 1000)
                  ..rotateX(angle * math.pi / 180),
                child: w,
              ),
            );
          }
          return w;
        },
      ),
    );
  }
}

/// Chooses the view for the round type. Sealed [Round] makes this switch
/// exhaustive: a new round type does not compile until it has a view here.
class _RoundArea extends ConsumerWidget {
  const _RoundArea({required this.state, required this.pad, required this.glyphs, required this.time, required this.onPen});
  final SessionState state;
  final WritePadController? pad;
  final Map<String, List<String>> glyphs;
  final ValueNotifier<double> time;
  final ValueChanged<Offset> onPen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(levelSessionProvider(state.level).notifier);
    return switch (state.current) {
      final PickRound r => PickRoundView(key: ValueKey(r.id), state: state, round: r, onPick: session.pick, time: time),
      final OrderRound r => OrderRoundView(key: ValueKey(r.id), state: state, round: r, onTile: session.placeTile, time: time),
      final WriteRound r =>
        pad == null
            ? const SizedBox.shrink()
            : WritePad(key: ValueKey(r.id), controller: pad!, state: state, round: r, glyphs: glyphs, time: time, onPen: onPen),
      SpeakRound() => SpeakRoundView(key: ValueKey(state.current.id), state: state, onMic: session.listen, time: time),
      final HuntRound r => HuntRoundView(key: ValueKey(r.id), state: state, round: r, onTap: session.tapCell, time: time),
      final FixRound r => FixRoundView(key: ValueKey(r.id), state: state, round: r, onTap: session.fixItem, time: time),
      final MatchRound r => MatchRoundView(key: ValueKey(r.id), state: state, round: r, onFlip: session.flipCard),
      final PopRound r => PopRoundView(key: ValueKey(r.id), state: state, round: r, onPop: session.popBubble, time: time),
      final TruthRound r => TruthRoundView(key: ValueKey(r.id), state: state, round: r, onAnswer: session.answerTruth, time: time),
      UnknownRound() => const SizedBox.shrink(),
    };
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.color, required this.opacity});
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}
