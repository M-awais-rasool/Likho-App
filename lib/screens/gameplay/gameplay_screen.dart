import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/course_providers.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../design/tokens.dart';
import '../../dev/reference_overlay.dart';
import '../../game/level_session.dart';
import '../../game/speech/prompt_voice.dart';
import '../../mascot/mascot.dart';
import 'rounds/order_round_view.dart';
import 'rounds/pick_round_view.dart';
import 'rounds/speak_round_view.dart';
import 'rounds/write_round_view.dart';
import 'widgets/game_bits.dart';
import 'widgets/game_buttons.dart';

/// Result handed back when the last round is won.
class LevelResult {
  const LevelResult({required this.level, required this.stars, required this.mistakes});
  final CourseLevel level;
  final int stars, mistakes;
}

/// 12 Gameplay, from export/Likho-Prototype.html (390 x 844). One screen for
/// every level: the round type decides what the play area shows (see
/// [_RoundArea]); everything else — header, mascot, prompt, feedback — is shared.
class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key, required this.level, required this.onExit, required this.onFinished});

  final CourseLevel level;
  final VoidCallback onExit;
  final ValueChanged<LevelResult> onFinished;

  /// Overlay reference for this level's first round (dev builds).
  static String referenceFor(CourseLevel l) => 'assets/reference/levels/level_${l.number.toString().padLeft(2, '0')}.png';

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen> with TickerProviderStateMixin {
  static const _praise = ['Wah!', 'Shabash!', 'Zabardast!', 'Kamaal!'];

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
  int _burst = 0;
  bool _done = false;

  CourseLevel get level => widget.level;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
    _mascot.setBodyColor(ref.read(progressProvider).color.key);
    _voice; // resolve while mounted (ref is not usable in dispose)
    _view = ref.read(levelSessionProvider(level));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRound());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _flip.dispose();
    _shake.dispose();
    _bubbleTimer?.cancel();
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
    _pad?.dispose();
    _pad = r is WriteRound ? WritePadController(round: r, guides: WritePadController.guidesFor(r, _glyphs)) : null;
    final say = r.prompt.text;
    _say(say.length <= 14 ? say : 'Suno!', const Duration(milliseconds: 1600));
    _lookAtArea();
    _voice.speak(r.prompt, _mascot, after: _resting);
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
          _say('Phir se!', const Duration(milliseconds: 1300));
        case RoundFeedback.none:
          if (prev.feedback == RoundFeedback.wrong) _mascot.play(_resting);
      }
    }
    if (next.spellFilled > prev.spellFilled && !next.correct) {
      // a spelled letter was accepted: clear the pad for the next one
      _pad?.erase();
      _mascot.play(MascotState.happy);
      _say('Wah!', const Duration(milliseconds: 700));
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && !ref.read(levelSessionProvider(level)).correct) _mascot.play(MascotState.watching);
      });
    }
    if (next.listening && !prev.listening) {
      _mascot.play(MascotState.watching);
      _say('Bolo!', GameTiming.listening);
    }
    if (next.finished && !_done) {
      _done = true;
      widget.onFinished(LevelResult(level: level, stars: next.stars, mistakes: next.mistakes));
    }
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
      child: ReferenceOverlay(
        asset: GameplayScreen.referenceFor(level),
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
                    Row(
                      children: [
                        SizedBox(
                          key: _mascotKey,
                          width: 78,
                          height: 110,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: OverflowBox(maxWidth: 90, child: PencilMascot(controller: _mascot, size: 110)),
                              ),
                              if (_bubble != null)
                                Positioned(
                                  left: 78 * .58,
                                  top: -14,
                                  child: SpeechBubble(text: _bubble!),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PromptCardView(key: ValueKey(s.current.id), card: s.current.card),
                        ),
                        const SizedBox(width: 12),
                        ReplayButton(onTap: _replay),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (level.isBoss) ...[
                            BossStrip(
                              world: (world?.order ?? 1) - 1,
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
                              onErase: () => _pad?.erase(),
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
