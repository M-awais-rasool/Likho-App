import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../boss_battle/battle_state.dart';
import '../boss_battle/boss_more_rounds.dart';
import '../boss_battle/boss_overlays.dart';
import '../boss_battle/boss_rounds.dart';
import '../boss_battle/boss_stage.dart';
import '../world_map/boss_painter.dart';
import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../design/tokens.dart';
import '../../feedback/app_feedback.dart';
import '../../feedback/pencil_lines.dart';
import '../../game/coach.dart';
import '../../game/level_resume.dart';
import '../../game/level_session.dart';
import '../../game/speech/prompt_voice.dart';
import '../../game/writing/stroke_guide.dart';
import '../../mascot/mascot.dart';
import 'rounds/beats_round_view.dart';
import 'rounds/connect_round_view.dart';
import 'rounds/fix_round_view.dart';
import 'rounds/hunt_round_view.dart';
import 'rounds/match_round_view.dart';
import 'rounds/order_round_view.dart';
import 'rounds/pick_round_view.dart';
import 'rounds/pop_round_view.dart';
import 'rounds/sort_round_view.dart';
import 'rounds/sounds_round_view.dart';
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

  // ---- coaching: Pencil says what to do, step by step
  late final bool _voiceOn = ref.read(pencilVoiceProvider); // his recorded coach lines
  int _talkId = 0; // a new line (or a stop) drops the lines still queued
  Future<void> _talk = Future.value();
  String? _stepKey; // the step being coached
  final _taught = <String>{}; // "how to play" lines said in this level
  Timer? _idle; // nudges the child after a quiet while
  int _nudges = 0, _nudge = 0; // nudges in this step; the bubble's wiggle
  double _padLineAt = -10;
  String? _caption; // what Pencil says (or said last): his bubble shows it
  String? _captionStep; // the step he said it in
  bool _talking = false; // a line is being said now

  // ---- boss battle (boss levels only)
  BossBattle? _battle;
  final _rootKey = GlobalKey();
  final _bossKey = GlobalKey();
  final _shots = <Shot>[];
  double? _introAt; // clock time the boss intro began; null when it is over
  int _roundStartMistakes = 0;
  SessionState? _finishedState; // the won level, held back for the finale
  int _alarmTaps = 0;
  double? _alarmTapAt, _alarmRangAt, _kidTapAt;
  static const _alarmNeeded = 8;
  late final AppFeedback _fb = ref.read(feedbackProvider);

  CourseLevel get level => widget.level;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
    _mascot.setBodyColor(ref.read(progressProvider).color.key);
    _voice; // resolve while mounted (ref is not usable in dispose)
    _voiceOn;
    final back = _resume();
    _view = ref.read(levelSessionProvider(level));
    _fb; // resolve while mounted
    if (level.isBoss) {
      _battle = BossBattle(rounds: _view.roundCount, hits: _view.round);
      _roundStartMistakes = _view.mistakes;
      _introAt = 0;
      _later(Duration(milliseconds: (BossIntro.stampAt * 1000).round()), _fb.bossStamp);
      _later(Duration(milliseconds: (BossIntro.drumAt * 1000).round()), _fb.bossDrum);
      _later(Duration(milliseconds: (BossIntro.seconds * 1000).round()), _endIntro);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRound();
      if (back) _say('Welcome back!', const Duration(milliseconds: 1600));
    });
  }

  /// The boss intro is over (or skipped): the first round begins.
  void _endIntro() {
    if (_introAt == null) return;
    setState(() => _introAt = null);
    _startRound();
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
    _idle?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _pad?.dispose();
    _voice.stop();
    _mascot.dispose();
    _battle?.dispose();
    super.dispose();
  }

  Map<String, List<String>> get _glyphs => ref.read(courseProvider).value?.glyphs ?? const {};

  bool get _writing => _view.current is WriteRound;

  MascotState get _resting => _writing ? MascotState.watching : MascotState.idle;

  // ------------------------------------------------------------ round life

  void _startRound() {
    if (!mounted) return;
    final r = _view.current;
    setState(() => _setPad(r is WriteRound ? r : null));
    // the pad lays its guide out in the next frame: then its first step shows
    if (_guided) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    _lookAtArea();
    _stepKey = _coach?.key;
    _nudges = 0;
    _speakThenTeach(r.prompt);
    _restartIdle();
  }

  /// Says the round's prompt, then (the first time this game comes up in
  /// the level, or when [always]) how to play it, once the prompt was said
  /// to its end.
  Future<void> _speakThenTeach(Prompt prompt, {bool always = false}) async {
    final round = _view.round;
    final whole = await _speak(prompt);
    if (!whole || !mounted || _view.round != round || _view.correct) return;
    final line = _howLine;
    if (line != null && (_taught.add(line) || always)) _sayLine(line, queue: true);
  }

  /// The line that says how to play this round now.
  String? get _howLine => _coach?.line ?? (_guided ? CoachLines.trace : null);

  /// The writing pad shows guide strokes (Pencil explains each one).
  bool get _guided => _pad?.guides.isNotEmpty ?? false;

  // ------------------------------------------------------------ coaching

  /// What Pencil tells the child to do now (see [coachStep]).
  CoachStep? get _coach => coachStep(_view, boss: _battle != null, guided: _guided);

  /// Pencil says [prompt], and his bubble shows the same words while he
  /// does (and after, until the child moves on). It cuts what he is saying,
  /// unless [queue]: then it waits for it. A line still waiting is dropped
  /// by the next line that cuts in, and by [_hush]. True when it was said to
  /// its end.
  Future<bool> _speak(Prompt prompt, {bool queue = false}) {
    if (!queue) _talkId++;
    final id = _talkId, step = _stepKey;
    final next = (queue ? _talk : Future<bool>.value(true)).then((_) async {
      if (!mounted || id != _talkId) return false;
      setState(() {
        _caption = _captionOf(prompt);
        _captionStep = step;
        _talking = true;
      });
      final said = _voice.speak(prompt, _mascot, after: _resting);
      // the voice off (tests): the line counts as said after a moment
      final whole = _voiceOn ? await said : await _wait(const Duration(milliseconds: 1200)).then((_) => true);
      if (!mounted || id != _talkId) return false;
      setState(() => _talking = false);
      _restartIdle(); // quiet time counts from when he stops
      return whole;
    });
    return _talk = next.catchError((_) => false);
  }

  /// What the bubble shows for [prompt]: what Pencil says, as written
  /// ({c|kʌ} -> c). A reading passage already on the card is not shown
  /// again: only the question after it.
  String _captionOf(Prompt prompt) {
    final words = prompt.spoken.trim();
    final card = _view.current.card?.text?.trim();
    if (card != null && card.length > 20 && words.startsWith(card) && words.length > card.length) {
      return words.substring(card.length).trim();
    }
    return words;
  }

  /// One of Pencil's recorded coach lines (silent where they are off).
  Future<bool> _sayLine(String asset, {bool queue = false}) =>
      _voiceOn ? _speak(CoachLines.prompt(asset), queue: queue) : Future<bool>.value(false);

  /// Pencil stops talking at once; nothing queued is said.
  void _hush() {
    _talkId++;
    _voice.stop();
    if (_talking && mounted) setState(() => _talking = false);
  }

  /// A pose for what just happened; never while Pencil talks (it would cut
  /// his line).
  void _react(MascotState state) {
    if (!_talking) _mascot.play(state);
  }

  /// A new step: its line is said when it asks for it. Quiet time starts
  /// again.
  void _checkStep() {
    final c = _coach;
    if (c?.key == _stepKey) return;
    _stepKey = c?.key;
    _nudges = 0;
    final line = c?.line;
    if (c != null && c.sayNow && line != null) _sayLine(line, queue: true);
    _restartIdle();
  }

  void _restartIdle() {
    _idle?.cancel();
    if (_done || _introAt != null) return;
    _idle = Timer(const Duration(seconds: 8), _nudgeNow);
  }

  /// The child has done nothing for a while: Pencil says the step again
  /// (twice at most) and his bubble pops.
  void _nudgeNow() {
    if (!mounted || _done || _view.correct || _nudges >= 2) return;
    if (_talking) {
      _restartIdle();
      return;
    }
    _nudges++;
    setState(() => _nudge++);
    final line = _coach?.line ?? _howLine;
    if (line != null && _voiceOn) {
      _sayLine(line);
    } else {
      _speak(_view.current.prompt);
    }
    _restartIdle();
  }

  /// Waits [d]; never completes when the screen closes first.
  Future<void> _wait(Duration d) {
    final c = Completer<void>();
    _later(d, c.complete);
    return c.future;
  }

  /// A writing slip (wrong start, off the path): Pencil says it too, at
  /// most every few seconds, and never over another line.
  void _padLine(String asset) {
    if (_time.value - _padLineAt < 4 || _talking) return;
    _padLineAt = _time.value;
    _sayLine(asset);
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
    _restartIdle();
    switch (e) {
      case PadEvent.strokeDone:
        _react(MascotState.happy);
        _bubbleTimer?.cancel();
        setState(() => _bubble = null); // the next stroke's instruction shows
        _later(const Duration(milliseconds: 600), () {
          if (!ref.read(levelSessionProvider(level)).correct) _react(MascotState.watching);
        });
      case PadEvent.letterDone:
        final pad = _pad;
        setState(() {});
        _later(const Duration(milliseconds: 250), () {
          if (pad == _pad) ref.read(levelSessionProvider(level).notifier).submitWriting(pad!.judge());
        });
      case PadEvent.wrongStart:
        _say('Start at the blue dot!', const Duration(milliseconds: 1500));
        _padLine(CoachLines.startDot);
      case PadEvent.leftPath:
        // off right after the start: most likely the wrong way
        final early = (_pad?.guide?.progress ?? 1) < .35;
        _say(early ? 'Follow the arrow!' : 'Stay on the line!', const Duration(milliseconds: 1300));
        _padLine(early ? CoachLines.followArrow : CoachLines.stayOnLine);
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

  /// The bubble: what Pencil is saying, word for word; else a passing
  /// remark, the instruction for the stroke being written, what he said
  /// last (until the child moves on), or what to do now (the coach step).
  (String, int?)? get _speech {
    final caption = _caption;
    if (_talking && caption != null) return (caption, null);
    if (_bubble != null) return (_bubble!, null);
    if (_view.correct) return null;
    final g = _pad?.guide;
    if (g != null && !g.done) return (stepText(g.shapeOf(g.stroke)), g.stroke + 1);
    if (caption != null && _captionStep == _stepKey) return (caption, null);
    final c = _coach;
    return c == null ? null : (c.text, null);
  }

  /// The replay button: the prompt again, then how to play.
  void _replay() {
    _bubbleTimer?.cancel();
    setState(() => _bubble = null);
    _speakThenTeach(_view.current.prompt, always: true);
    _restartIdle();
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
      _hush(); // nothing of the last round is heard over the next one
      _idle?.cancel();
      _caption = null;
      _roundStartMistakes = next.mistakes;
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
        if (_view.isHalfway && _battle == null) _halfway();
      });
      return;
    }
    setState(() => _view = next);
    if (next.feedback != prev.feedback) {
      switch (next.feedback) {
        case RoundFeedback.correct:
          _burst++;
          _hush();
          _idle?.cancel();
          _mascot.play(MascotState.happy);
          _say(_praise[next.round % 4], const Duration(milliseconds: 1350));
          HapticFeedback.lightImpact();
          if (_battle != null) _attack(next, clean: next.mistakes == _roundStartMistakes);
        case RoundFeedback.wrong:
          final battle = _battle;
          if (battle != null) {
            battle.missed(_time.value);
            _fb.bossSnore();
          }
          _shake.forward(from: 0);
          _react(MascotState.encourage);
          _say('Try again!', const Duration(milliseconds: 1300));
        case RoundFeedback.none:
          if (prev.feedback == RoundFeedback.wrong) _react(_resting);
      }
    }
    if (next.spellFilled > prev.spellFilled && !next.correct) {
      final r = next.current;
      if (r is WriteRound && next.spellFilled < (r.word ?? r.target ?? '').length) _setPad(r, letter: next.spellFilled);
      _react(MascotState.happy);
      _say('Wow!', const Duration(milliseconds: 700));
      _later(const Duration(milliseconds: 700), () {
        if (!ref.read(levelSessionProvider(level)).correct) _react(MascotState.watching);
      });
    }
    // a sound, a word or a hint the round asks Pencil to say
    final line = next.saying;
    if (line != null && next.said != prev.said && !next.correct) _speak(line);
    if (!next.correct) _checkStep();
    if (next.finished && !_done) {
      _done = true;
      if (child != null) ref.read(levelResumeProvider.notifier).clear(child, level);
      if (_battle != null) {
        _startFinale(next);
      } else {
        widget.onFinished(LevelResult(level: level, stars: next.stars, mistakes: next.mistakes));
      }
    }
  }

  // ------------------------------------------------------------ boss battle

  /// A won round in a boss battle: a wake-up shot flies from the play area
  /// to the boss and lands a hit (a combo hit after three clean rounds).
  void _attack(SessionState s, {required bool clean}) {
    final battle = _battle!;
    battle.won(clean: clean);
    if (battle.combo >= 2) _later(const Duration(milliseconds: 120), _fb.bossCombo);
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final area = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    final boss = _bossKey.currentContext?.findRenderObject() as RenderBox?;
    final big = battle.combo >= 3;
    void land() {
      if (battle.hit(_time.value, big: big)) {
        _fb.bossPhase();
        _mascot.play(MascotState.happy);
        _say(battle.phase == 1 ? "It's waking up!" : 'Almost there!', const Duration(milliseconds: 1500));
      }
      _fb.bossHit(big: big);
      if (big) _burst++;
    }

    if (root == null || area == null || boss == null) {
      _later(const Duration(milliseconds: 500), () => setState(land));
      return;
    }
    final r = s.current;
    final kind = switch (r) {
      PickRound() || SortRound() => ShotKind.pillow,
      PopRound() => ShotKind.bubble,
      OrderRound() => ShotKind.bell,
      WriteRound() => ShotKind.letter,
      BeatsRound() => ShotKind.wave,
      TruthRound() => ShotKind.sun,
      _ => battle.hits.isEven ? ShotKind.star : ShotKind.bell,
    };
    final text = r is WriteRound ? (r.target ?? r.word ?? '') : '';
    final from = root.globalToLocal(area.localToGlobal(Offset(area.size.width / 2, r is PickRound ? 20 : area.size.height * .4)));
    final to = root.globalToLocal(boss.localToGlobal(boss.size.center(Offset.zero)));
    final shot = Shot(from: from, to: to, start: _time.value, kind: kind, big: big, label: text.length <= 3 ? text : text.substring(0, 1));
    setState(() => _shots.add(shot));
    _later(Duration(milliseconds: (Shot.seconds * 1000).round()), () {
      setState(() {
        _shots.remove(shot);
        land();
      });
    });
  }

  /// All rounds won: the alarm clock comes out. The child rings it (or it
  /// rings itself when nobody taps), then the boss wakes up.
  void _startFinale(SessionState s) {
    _hush();
    _idle?.cancel();
    setState(() => _finishedState = s);
    _mascot.play(MascotState.happy);
    _say('Ring the alarm!', const Duration(milliseconds: 2200));
    _autoRing(_time.value);
  }

  /// Rings the alarm for the child after a few quiet seconds.
  void _autoRing(double since) {
    _later(const Duration(milliseconds: 900), () {
      if (_alarmRangAt != null) return;
      final last = _kidTapAt ?? since;
      if (_time.value - last > 4.5) _ringAlarm(auto: true);
      _autoRing(since);
    });
  }

  void _ringAlarm({bool auto = false}) {
    if (_alarmRangAt != null || _finishedState == null) return;
    final now = _time.value;
    if (!auto) _kidTapAt = now;
    _fb.alarmRing();
    _battle?.poke(now);
    setState(() {
      _alarmTaps++;
      _alarmTapAt = now;
    });
    if (_alarmTaps < _alarmNeeded) return;
    // ring ring: the boss is awake!
    setState(() => _alarmRangAt = now);
    _battle?.wake(now + .15);
    _burst++;
    _later(const Duration(milliseconds: 150), _fb.bossWake);
    _later(const Duration(milliseconds: 400), () => _mascot.play(MascotState.dance));
    final s = _finishedState!;
    _later(const Duration(milliseconds: 3600), () => widget.onFinished(LevelResult(level: level, stars: s.stars, mistakes: s.mistakes)));
  }

  /// Halfway through a long level: Pencil cheers and confetti flies.
  void _halfway() {
    _burst++;
    _react(MascotState.happy);
    _say('Halfway there!', const Duration(milliseconds: 1600));
    _later(const Duration(milliseconds: 900), () => _react(_resting));
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    ref.listen(levelSessionProvider(level), _onSession);
    // any touch: the child is busy, Pencil waits before nudging
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restartIdle(),
      onPointerUp: (_) => _restartIdle(),
      child: _screen(context),
    );
  }

  Widget _screen(BuildContext context) {
    final course = ref.watch(courseProvider).value;
    final world = course?.worldOf(level);
    final theme = LikhoWorlds.byId(world?.themeId ?? 'letterLand');
    final s = _view;
    final pad = MediaQuery.paddingOf(context);
    final write = s.current is WriteRound ? s.current as WriteRound : null;
    final hasBoxes = write != null && (write.mode == WriteMode.missing || write.mode == WriteMode.spell);
    final battle = _battle;
    if (battle != null) return _bossBuild(battle, world, theme, s, write, hasBoxes);

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
                              height: 64,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: switch (_speech) {
                                  (final text, final step) => SpeechBubble(text: text, step: step, nudge: _nudge),
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

  /// A boss level: the boss arena. The sleep meter on top, the stage with
  /// Pencil facing the boss, the prompt, then the round as a boss game. Wake-up
  /// shots fly over everything; the intro covers the screen at the start and
  /// the alarm finale covers the play area at the end.
  Widget _bossBuild(BossBattle battle, CourseWorld? world, WorldTheme theme, SessionState s, WriteRound? write, bool hasBoxes) {
    final pad = MediaQuery.paddingOf(context);
    final bossIndex = BossPainter.indexOf(world?.bossId ?? '');
    final bossName = world?.bossName ?? 'The boss';
    final stageH = (MediaQuery.sizeOf(context).height * .23).clamp(150.0, 200.0);
    final finale = _finishedState != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (theme.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: LikhoColors.clear),
      child: Material(
        color: theme.bg,
        child: Stack(
          key: _rootKey,
          children: [
            Positioned(left: -60, bottom: -60, width: 220, height: 220, child: _SoftCircle(color: theme.soft, opacity: .7)),
            Padding(
              padding: EdgeInsets.fromLTRB(20, pad.top + 7, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        HomeButton(onTap: widget.onExit),
                        const SizedBox(width: 12),
                        Expanded(child: SleepMeter(battle: battle, bossName: bossName, dark: theme.dark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: stageH,
                    child: ListenableBuilder(
                      listenable: battle,
                      builder: (context, _) => BossStage(
                        battle: battle,
                        theme: theme,
                        boss: bossIndex,
                        time: _time,
                        pencilKey: _mascotKey,
                        bossKey: _bossKey,
                        pencil: OverflowBox(maxWidth: 100, maxHeight: 120, child: PencilMascot(controller: _mascot, size: 104)),
                        bubble: switch (_speech) {
                          (final text, final step) => SpeechBubble(text: text, step: step, nudge: _nudge),
                          null => null,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (finale)
                    const FinalMoveCard()
                  else
                    Row(
                      children: [
                        Expanded(child: PromptCardView(key: ValueKey(s.current.id), card: s.current.card)),
                        const SizedBox(width: 12),
                        ReplayButton(onTap: _replay),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (hasBoxes) ...[LetterBoxes(round: write!, spellFilled: s.spellFilled, correct: s.correct), const SizedBox(height: 12)],
                  Expanded(
                    child: Stack(
                      children: [
                        // the round starts after the intro (pillows and bubbles start moving on build)
                        Positioned.fill(child: _introAt == null && !finale ? _animatedArea(s, boss: theme) : const SizedBox.shrink()),
                        if (finale)
                          Positioned.fill(
                            child: AlarmFinale(
                              time: _time,
                              taps: _alarmTaps,
                              needed: _alarmNeeded,
                              lastTapAt: _alarmTapAt,
                              rangAt: _alarmRangAt,
                              bossName: bossName,
                              onTap: _ringAlarm,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (write != null && !finale) ...[
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
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _time,
                  builder: (context, t, _) => CustomPaint(painter: ShotPainter(shots: _shots, t: t)),
                ),
              ),
            ),
            if (_introAt != null)
              Positioned.fill(
                child: BossIntro(time: _time, start: _introAt!, boss: bossIndex, bossName: bossName, theme: theme, onSkip: _endIntro),
              ),
          ],
        ),
      ),
    );
  }

  /// Play area with the round flip (rotateX from the top edge) and the
  /// wrong-answer shake; confetti bursts from its centre. In a boss battle
  /// ([boss]: the world's theme) rounds play as boss games.
  Widget _animatedArea(SessionState s, {WorldTheme? boss}) {
    final area = KeyedSubtree(
      key: _areaKey,
      child: _RoundArea(
        state: s,
        pad: _pad,
        glyphs: _glyphs,
        time: _time,
        onPen: (p) {
          _mascot.lookAt(p);
          _idle?.cancel(); // writing: not quiet
        },
        boss: boss,
      ),
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
  const _RoundArea({
    required this.state,
    required this.pad,
    required this.glyphs,
    required this.time,
    required this.onPen,
    this.boss,
  });
  final SessionState state;
  final WritePadController? pad;
  final Map<String, List<String>> glyphs;
  final ValueNotifier<double> time;
  final ValueChanged<Offset> onPen;

  /// The world's theme in a boss battle: rounds play as boss games.
  final WorldTheme? boss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(levelSessionProvider(state.level).notifier);
    final theme = boss;
    if (theme != null) {
      final r = state.current;
      switch (r) {
        case PickRound() when PillowFightView.fits(r):
          return PillowFightView(key: ValueKey(r.id), state: state, round: r, onPick: session.pick, time: time);
        case PopRound():
          return SnoreBubblesView(key: ValueKey(r.id), state: state, round: r, onPop: session.popBubble, time: time);
        case SoundsRound() || BeatsRound() || ConnectRound():
          // the new games on paper in the magic frame, like writing
          return MagicFrame(
            theme: theme,
            time: time,
            child: ColoredBox(color: LikhoColors.background, child: _plain(session)),
          );
        case TruthRound():
          return SunMoonView(key: ValueKey(r.id), state: state, round: r, onAnswer: session.answerTruth, time: time);
        case HuntRound():
          return DreamHuntView(key: ValueKey(r.id), state: state, round: r, onTap: session.tapCell, time: time);
        case MatchRound():
          return DreamCardsView(key: ValueKey(r.id), state: state, round: r, onFlip: session.flipCard);
        case OrderRound():
          return WakeWordView(key: ValueKey(r.id), state: state, round: r, onTile: session.placeTile, time: time);
        case SortRound():
          return PillowPilesView(key: ValueKey(r.id), state: state, round: r, onSort: session.sortItem, time: time);
        case FixRound():
          return SleepNotesView(key: ValueKey(r.id), state: state, round: r, onTap: session.fixItem, time: time);
        case WriteRound():
          final p = pad;
          if (p != null) {
            return MagicFrame(
              theme: theme,
              time: time,
              child: WritePad(key: ValueKey(r.id), controller: p, state: state, round: r, glyphs: glyphs, time: time, onPen: onPen),
            );
          }
        default:
          break;
      }
    }
    return _plain(session);
  }

  /// The round's own view.
  Widget _plain(LevelSession session) {
    return switch (state.current) {
      final PickRound r => PickRoundView(key: ValueKey(r.id), state: state, round: r, onPick: session.pick, time: time),
      final OrderRound r => OrderRoundView(key: ValueKey(r.id), state: state, round: r, onTile: session.placeTile, time: time),
      final WriteRound r =>
        pad == null
            ? const SizedBox.shrink()
            : WritePad(key: ValueKey(r.id), controller: pad!, state: state, round: r, glyphs: glyphs, time: time, onPen: onPen),
      final SoundsRound r => SoundsRoundView(
        key: ValueKey(r.id),
        state: state,
        round: r,
        onSound: session.tapSound,
        onBlend: session.blendWord,
        onChoice: session.pickChoice,
        time: time,
      ),
      final BeatsRound r => BeatsRoundView(
        key: ValueKey(r.id),
        state: state,
        round: r,
        onDrum: session.tapDrum,
        onDone: session.checkBeats,
        onAgain: session.clearBeats,
        time: time,
      ),
      final ConnectRound r => ConnectRoundView(key: ValueKey(r.id), state: state, round: r, onTap: session.tapDot, time: time),
      final HuntRound r => HuntRoundView(key: ValueKey(r.id), state: state, round: r, onTap: session.tapCell, time: time),
      final FixRound r => FixRoundView(key: ValueKey(r.id), state: state, round: r, onTap: session.fixItem, time: time),
      final SortRound r => SortRoundView(key: ValueKey(r.id), state: state, round: r, onSort: session.sortItem, time: time),
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
