import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/course_providers.dart';
import '../../../data/family.dart';
import '../../../data/games.dart';
import '../../../data/models/course_models.dart';
import '../../../data/progress.dart';
import '../../../design/tokens.dart';
import '../../../feedback/app_feedback.dart';
import '../../../feedback/pencil_lines.dart';
import '../../../feedback/sfx.dart';
import '../../../game/monster_defense/md_questions.dart';
import '../../../game/speech/prompt_voice.dart';
import '../../../game/spell_runner/sr_engine.dart';
import '../../../mascot/mascot.dart';
import '../../gameplay/widgets/game_buttons.dart';
import '../game_ui.dart';
import '../monster_defense/md_effects.dart';
import 'sr_lines.dart';
import 'sr_painter.dart';
import 'sr_scene.dart';

/// Spell Runner: Pencil rides his skateboard down a country road (seen from
/// behind). The picture and the word's empty boxes are at the top; rows of
/// letter bubbles come down the three lanes and the child swipes (or taps a
/// side) to catch the next letter, and swipes up (or taps Jump) to hop over
/// puddles, logs and rocks. A whole word: Pencil says it and spells it, a
/// boost, and the next word (longer as he goes). It never ends by itself:
/// three bumps end the run, and the distance is the record to beat. See
/// [SrGame] for the rules.
class SpellRunnerScreen extends ConsumerStatefulWidget {
  const SpellRunnerScreen({super.key, required this.onDone, this.random, this.tasks});
  final VoidCallback onDone;

  /// Tests: fixed dice and tasks.
  final math.Random? random;
  final SrTasks? tasks;

  @override
  ConsumerState<SpellRunnerScreen> createState() => _SpellRunnerScreenState();
}

/// A caught letter flying up into its box.
class _Flight {
  _Flight(this.letter, this.from, this.slot);
  final String letter;
  final Offset from;
  final int slot;
  double t = 0;
  static const time = .55;
}

class _SpellRunnerScreenState extends ConsumerState<SpellRunnerScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  late final math.Random _rnd = widget.random ?? math.Random();
  late final AppFeedback _fb = ref.read(feedbackProvider);
  late final PromptVoice _voice = ref.read(promptVoiceProvider);
  late final bool _voiceOn = ref.read(voiceOnProvider);
  final _voiceOf = MascotController(); // Pencil's voice (he is seen from behind)

  SrGame? _game;
  SrTasks? _tasks;

  /// The game (tests play it).
  @visibleForTesting
  SrGame? get debugGame => _game;
  Duration? _last;
  double _clock = 0;
  bool _started = false, _paused = false, _showResult = false, _record = false;
  late bool _firstPlay;
  late SrBackground _bg;
  int _best = 0;

  // what Pencil says
  String? _caption;
  int _talkId = 0, _askId = 0, _great = 0;
  Future<void> _speaking = Future<void>.value();
  Completer<void>? _shown;
  Timer? _captionTimer, _resultTimer;
  final _timers = <Timer>[];
  double _oopsAt = -9;
  int _bumpTalks = 0;
  bool _jumpHinted = false, _jumped = false, _slideHinted = false, _slid = false;

  /// A high bar has come on the road: the Slide button shows from now on.
  bool _bars = false;

  // Gloop chases him for a while after a bump (and catches him at the end)
  double _chaseAt = -99, _gloopLane = 0;

  // a new part of the road (its name on a banner), a new best score
  double _zoneAt = -9, _bestAt = -9;
  int _zoneShown = 0;
  bool _bestShown = false;

  // effects
  final _bits = <MdBit>[];
  final _flights = <_Flight>[];
  final _scenery = <SrScenery>[];
  double _sceneryCursor = -4;
  double _shake = 0, _landAt = -9, _wordAt = -9, _longerAt = -9, _heartAt = -9, _heartLostAt = -9, _shownScore = 0;
  String _wordShown = '';
  String? _hint;

  // Pencil glides across the lanes on a spring (the rules move him at a
  // steady pace); the camera follows him a little
  double _viewLane = 0, _laneVel = 0, _jumpAt = -9;
  final _cam = _Camera();

  // a swipe moves him as soon as the finger has gone far enough
  Offset _pan = Offset.zero;
  bool _swiped = false;

  // layout of the last build
  SrRoad? _road;
  EdgeInsets _pad = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _voice;
    _voiceOn;
    final plays = ref.read(myGamesProvider)[GameIds.runner]?.plays ?? 0;
    _firstPlay = plays == 0;
    _bg = plays.isOdd ? SrBackground.sunset : SrBackground.day;
    _fb.prepare(Sfx.spellRunner);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final a in SrArt.all) {
      precacheImage(AssetImage(a), context);
    }
    SrSprites.load(createLocalImageConfiguration(context));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captionTimer?.cancel();
    _resultTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _endCaption();
    _ticker.dispose();
    _frame.dispose();
    _voice.stop();
    _fb.riding(false);
    _voiceOf.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  Future<void> _load() async {
    var tasks = widget.tasks;
    if (tasks == null) {
      final words = await MdWords.load();
      if (!mounted) return;
      final course = ref.read(courseProvider).value;
      final done = ref.read(progressProvider).levelStars.keys;
      tasks = SrTasks.forChild(MdKnowledge.of(course, done), words, _rnd);
    }
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _game = SrGame(tasks: tasks!, random: _rnd);
    });
    if (_firstPlay) _say(SrLines.intro, hold: true);
  }

  // ------------------------------------------------------------ the clock

  void _onTick(Duration now) {
    final dt = _last == null ? 0.0 : math.min(.1, (now - _last!).inMicroseconds / 1e6);
    _last = now;
    _clock += dt;
    final g = _game;
    if (g != null && !_paused) {
      g.tick(dt);
      for (final e in g.drain()) {
        _on(e, g);
      }
      _layScenery(g);
      _hintJump(g);
      _hintSlide(g);
      if (!_bestShown && _best > 0 && g.score > _best && g.phase == SrPhase.running) {
        _bestShown = true;
        _bestAt = _clock;
        _fb.reward();
      }
      for (final b in _bits) {
        b.step(dt);
      }
      _bits.removeWhere((b) => b.done);
      for (final f in _flights) {
        f.t += dt;
      }
      _flights.removeWhere((f) => f.t >= _Flight.time);
      _glide(g, dt);
      _shake *= math.exp(-dt * 10);
      _shownScore += (g.score - _shownScore) * math.min(1, dt * 8);
      if ((g.score - _shownScore).abs() < .5) _shownScore = g.score.toDouble();
    }
    _frame.value++;
  }

  /// A bump: Gloop comes after him (giggling, if it was not already), or
  /// stays on his tail a little longer.
  void _chased() {
    if (_clock - _chaseAt > 7.5) {
      _chaseAt = _clock;
      _gloopLane = _viewLane + (_viewLane >= 0 ? -1.6 : 1.6);
      _fb.giggle();
    } else {
      _chaseAt = math.max(_chaseAt, _clock - .6);
    }
  }

  /// Gloop after him: up from behind, hopping along a little off his lane,
  /// then falling back; at the end of the run, it reaches out and gets him.
  SrChase? _chase(SrGame g) {
    final over = g.phase == SrPhase.over || g.phase == SrPhase.done;
    final t = _clock - _chaseAt;
    if (!over && t > 7.5) return null;
    final rise = over ? 1.0 : (t < .6 ? Curves.easeOut.transform(t / .6) : (t < 6 ? 1.0 : 1 - Curves.easeIn.transform((t - 6) / 1.5)));
    final p = (_clock % .42) / .42;
    final reach = over && g.phaseTime > .35;
    return SrChase(
      pose: SrArt.gloop(reach ? 'reach' : (p < .55 ? 'hop' : 'land')),
      lane: _gloopLane,
      rise: rise,
      hop: reach ? 0 : (p < .55 ? math.sin(p / .55 * math.pi) : 0),
      near: over ? (g.phaseTime / .8).clamp(0.0, 1.0) : 0,
    );
  }

  /// Pencil's lane on a spring towards the rules' lane, and the camera:
  /// a little after him across the lanes, leaning into a turn, closer as
  /// the board speeds up.
  void _glide(SrGame g, double dt) {
    final steps = math.max(1, (dt / .008).ceil());
    final h = dt / steps;
    const w = 24.0;
    for (var i = 0; i < steps; i++) {
      _laneVel += (w * w * (g.lane - _viewLane) - 2 * w * _laneVel) * h;
      _viewLane += _laneVel * h;
    }
    // Gloop hops along a little off his lane (into it at the end)
    final over = g.phase == SrPhase.over || g.phase == SrPhase.done;
    final want = over ? _viewLane : _viewLane + (_viewLane >= 0 ? -.85 : .85);
    _gloopLane += (want - _gloopLane) * math.min(1, dt * (over ? 4 : 2.5));
    final road = _road;
    if (road == null) return;
    final fast = g.boost > 0 ? 1.0 : ((g.speed - SrGame.startSpeed) / (SrGame.topSpeed - SrGame.startSpeed)).clamp(0.0, 1.0);
    _cam.vanish = road.vanish;
    _cam.x += (-_viewLane * road.laneWidth * .28 - _cam.x) * math.min(1, dt * 6);
    _cam.roll += ((-_laneVel * .01).clamp(-.03, .03) - _cam.roll) * math.min(1, dt * 8);
    _cam.zoom += (1.04 + .035 * fast - _cam.zoom) * math.min(1, dt * 2);
  }

  /// Trees, flowers and fences beside the road, a few steps apart.
  void _layScenery(SrGame g) {
    while (_sceneryCursor < g.dist + SrGame.view + 6) {
      _sceneryCursor += 1.8 + _rnd.nextDouble() * 2.2;
      final zone = SrZone.all[SrZone.at(_sceneryCursor * SrGame.metre)];
      for (final side in [-1.0, 1.0]) {
        if (_rnd.nextDouble() < .25) continue;
        final name = zone.roadside[_rnd.nextInt(zone.roadside.length)];
        final big = name == 'tree' || name == 'pine' || name == 'apple_tree';
        final low = name == 'flowers' || name == 'mushrooms' || name == 'fence';
        _scenery.add(
          SrScenery(
            asset: SrArt.pic(name),
            z: _sceneryCursor + _rnd.nextDouble(),
            side: side,
            out: (low ? .05 : .4) + _rnd.nextDouble() * (big ? 1.6 : .8),
            size: big ? 1.4 + _rnd.nextDouble() * .5 : (low ? .45 : .8 + _rnd.nextDouble() * .3),
            flip: _rnd.nextBool(),
          ),
        );
      }
    }
    _scenery.removeWhere((s) => s.z < g.dist - 4);
  }

  /// The first high bar in his lane before he ever slid: how to pass it.
  void _hintSlide(SrGame g) {
    if (!_bars && g.things.any((t) => t.kind.high)) _bars = true;
    if (_slideHinted || _slid || g.phase != SrPhase.running) return;
    final bar = g.things.where((t) => t.kind.high && t.lane == g.targetLane && t.z - g.dist < 10 && t.z - g.dist > 2).firstOrNull;
    if (bar == null) return;
    _slideHinted = true;
    _say(SrLines.slideHint);
  }

  /// The first game: Pencil tells how to jump when the first bump comes.
  void _hintJump(SrGame g) {
    if (!_firstPlay || _jumpHinted || _jumped || g.phase != SrPhase.running) return;
    final bump = g.things.where((t) => t.kind.obstacle && t.lane == g.targetLane && t.z - g.dist < 9 && t.z - g.dist > 2).firstOrNull;
    if (bump == null) return;
    _jumpHinted = true;
    _say(SrLines.jumpHint);
  }

  // ------------------------------------------------------------ what happened

  void _on(SrEvent e, SrGame g) {
    final road = _road;
    switch (e.kind) {
      case SrEventKind.countdown:
        _fb.countdown();
        _say(SrLines.count[(e.value - 1).clamp(0, 2)]);
      case SrEventKind.go:
        _fb.countdown(go: true);
        _fb.riding(true);
        _say(SrLines.go);
      case SrEventKind.task:
        _hint = null;
        _ask(g.current!);
      case SrEventKind.move:
        _fb.tap();
      case SrEventKind.letter:
        _hint = null;
        final t = e.thing!;
        _fb.correct(streak: math.min(5, g.combo), balloon: true);
        if (road != null) {
          final at = _bubbleCentre(road, g, t);
          _bits.addAll(MdBit.burst(at, _rnd, n: 12, speed: 180));
          _flights.add(_Flight(t.label, _cam.map(at), e.value));
          _popRow(road, g, t);
        }
        // the word's last letter: the word is said instead
        if (g.got > 0) _say(SrLines.letter(t.label));
      case SrEventKind.wrong:
        _fb.nope();
        _fb.pop();
        _hint = g.need;
        _shake = 4;
        if (road != null) {
          _bits.addAll(MdBit.burst(_bubbleCentre(road, g, e.thing!), _rnd, n: 10, speed: 140, colors: const [MonsterColors.heartOff, MonsterColors.bubbleTint]));
          _popRow(road, g, e.thing!);
        }
        if (_clock - _oopsAt > 4) {
          _oopsAt = _clock;
          _say(SrLines.oops);
          if (g.current != null) _ask(g.current!);
        }
      case SrEventKind.word:
        final done = g.previous!;
        _fb.boost();
        _wordAt = _clock;
        _wordShown = (done.word ?? done.letters[0]).toUpperCase();
        if (road != null) _bits.addAll(MdBit.confetti(road.screen.width, _rnd, n: 36));
        if (done.done != null) {
          _say(Prompt(text: done.done!, audio: done.doneAudio));
        } else {
          _say(SrLines.great[_great++ % SrLines.great.length]);
        }
      case SrEventKind.coin:
        _fb.coin();
        if (road != null) _bits.addAll(MdBit.burst(_pencilTop(road, g), _rnd, n: 5, speed: 90));
      case SrEventKind.jump:
        _jumped = true;
        _jumpAt = _clock;
        _fb.skateJump();
      case SrEventKind.ramp:
        _jumped = true;
        _jumpAt = _clock;
        _fb.skateJump();
        _fb.whoosh();
        if (road != null) _bits.add(MdBit.score(_pencilTop(road, g), 50));
      case SrEventKind.power:
        final k = e.thing!.kind;
        _fb.powerUp();
        _say(SrLines.power(k));
        if (road != null) _bits.addAll(MdBit.burst(_pencilTop(road, g), _rnd, n: 14, speed: 160, colors: [SrPowerArt.color(k), MonsterColors.magicCore]));
      case SrEventKind.powerEnd:
        break;
      case SrEventKind.shielded:
        _fb.bubblePop();
        _shake = 6;
        if (road != null) _bits.addAll(MdBit.burst(_pencilTop(road, g) + const Offset(0, 60), _rnd, n: 14, speed: 170, colors: const [RunnerColors.shield, MonsterColors.magicCore]));
      case SrEventKind.zone:
        _zoneShown = e.value;
        _zoneAt = _clock;
        _fb.milestone();
        _say(SrLines.zones[e.value % SrZone.all.length]);
      case SrEventKind.slide:
        _slid = true;
        _fb.whoosh();
        if (road != null) _bits.addAll(MdBit.dust(Offset(road.at(0, _viewLane).dx, road.player), road.laneWidth * .4, _rnd, n: 3));
      case SrEventKind.land:
        _fb.skateLand();
        _landAt = _clock;
        if (road != null) _bits.addAll(MdBit.dust(Offset(road.at(0, _viewLane).dx, road.player), road.laneWidth * .5, _rnd, n: 6));
      case SrEventKind.cleared:
        if (road != null) _bits.add(MdBit.score(_pencilTop(road, g), 25));
      case SrEventKind.bump:
        _chased();
        _heartLostAt = _clock;
        _fb.skateBump();
        _shake = 12;
        if (road != null) _bits.addAll(MdBit.burst(_pencilTop(road, g), _rnd, n: 8, speed: 120, colors: const [MonsterColors.spark]));
        final kind = e.thing?.kind;
        if (_bumpTalks++ < 2) _say(kind?.high == true ? SrLines.duck : (kind?.blocker == true ? SrLines.around : SrLines.bump));
      case SrEventKind.skid:
        _chased();
        _heartLostAt = _clock;
        e.thing?.kind == SrKind.puddle ? _fb.splash() : _fb.slip();
        _shake = 7;
        if (road != null) _bits.addAll(MdBit.dust(Offset(road.at(0, _viewLane).dx, road.player), road.laneWidth * .6, _rnd, n: 6));
      case SrEventKind.longer:
        // after the word's own banner
        _longerAt = _clock + 1.3;
        _after(1300, () => _say(SrLines.longer));
      case SrEventKind.heart:
        _fb.reward();
        _heartAt = _clock;
        _say(SrLines.heart);
        if (road != null) _bits.addAll(MdBit.burst(_pencilTop(road, g), _rnd, n: 12, speed: 150, colors: const [MonsterColors.gem, MonsterColors.magicCore]));
      case SrEventKind.crash:
        _fb.gameLost();
        _fb.riding(false);
        _shake = 16;
        _say(SrLines.crash);
      case SrEventKind.done:
        _fb.riding(false);
        final child = ref.read(familyProvider).active.id;
        _record = ref.read(gameProgressProvider.notifier).record(child, GameIds.runner, score: g.score, stars: g.stars);
        if (_record) _after(1200, () => _say(SrLines.record));
        _after(500, () => setState(() => _showResult = true));
    }
  }

  /// The other bubbles of [t]'s row pop too (softly).
  void _popRow(SrRoad road, SrGame g, SrThing t) {
    for (final o in g.things.where((o) => o.row == t.row && o != t)) {
      _bits.addAll(MdBit.burst(_bubbleCentre(road, g, o), _rnd, n: 6, speed: 90, colors: const [MonsterColors.bubbleTint, MonsterColors.magicCore]));
    }
  }

  Offset _bubbleCentre(SrRoad road, SrGame g, SrThing t) {
    final z = t.z - g.dist;
    final r = road.laneWidth * road.s(z) * .47;
    return road.at(z, t.lane.toDouble()) - Offset(0, r * 1.25);
  }

  Offset _pencilTop(SrRoad road, SrGame g) => Offset(road.at(0, _viewLane).dx, road.player - SrRoad.pencilHeight(road.screen) - g.air * road.screen.height * .14);

  void _after(int ms, VoidCallback f) {
    _timers.removeWhere((t) => !t.isActive);
    _timers.add(
      Timer(Duration(milliseconds: ms), () {
        if (mounted) f();
      }),
    );
  }

  // ------------------------------------------------------------ Pencil talks

  /// Pencil says [line] now; his bubble shows its words for a moment ([hold]:
  /// until the game starts).
  void _say(Prompt line, {bool hold = false}) {
    final talk = ++_talkId;
    _captionTimer?.cancel();
    _endCaption();
    final shown = _shown = Completer<void>();
    setState(() => _caption = line.text);
    if (!hold) {
      _captionTimer = Timer(Duration(milliseconds: 900 + line.text.length * 45), () {
        if (!shown.isCompleted) shown.complete();
        if (mounted && talk == _talkId) setState(() => _caption = null);
      });
    }
    _speaking = _voiceOn ? _voice.speak(line, _voiceOf, after: MascotState.idle).then((_) {}) : (hold ? Future<void>.value() : shown.future);
  }

  void _endCaption() {
    final s = _shown;
    if (s != null && !s.isCompleted) s.complete();
  }

  /// Pencil asks for [task] once he has finished what he is saying ([now]:
  /// at once).
  Future<void> _ask(SrTask task, {bool now = false}) async {
    final ask = ++_askId;
    if (!now) {
      final said = Completer<void>();
      _after(4000, () => said.isCompleted ? null : said.complete());
      _speaking.whenComplete(() => said.isCompleted ? null : said.complete());
      await said.future;
    }
    if (!mounted || ask != _askId || _game?.current != task || _paused) return;
    _say(Prompt(text: task.say, audio: task.audio));
  }

  // ------------------------------------------------------------ the child

  void _play() {
    final g = _game;
    if (g == null || _started) return;
    _fb.levelStart();
    _voice.stop();
    setState(() {
      _started = true;
      _caption = null;
    });
    g.start();
  }

  void _again() {
    final tasks = _tasks;
    if (tasks == null) return;
    _fb.press();
    _resultTimer?.cancel();
    setState(() {
      _game = SrGame(tasks: tasks, random: _rnd);
      _started = false;
      _showResult = false;
      _record = false;
      _bits.clear();
      _flights.clear();
      _scenery.clear();
      _sceneryCursor = -4;
      _shownScore = 0;
    });
    _play();
  }

  void _pause() {
    final g = _game;
    if (_paused || g == null || !_started || g.phase == SrPhase.done) return;
    setState(() => _paused = true);
    _voice.stop();
    _fb.riding(false);
  }

  void _resume() {
    _fb.press();
    setState(() => _paused = false);
    _last = null;
    final g = _game;
    if (g != null && g.phase == SrPhase.running) {
      _fb.riding(true);
      if (g.current != null) _ask(g.current!, now: true);
    }
  }

  void _exit() {
    _fb.back();
    _voice.stop();
    _fb.riding(false);
    widget.onDone();
  }

  void _jump() => _game?.jump();
  void _slide() => _game?.slide();

  void _panStart(DragStartDetails d) {
    _pan = Offset.zero;
    _swiped = false;
  }

  /// Far enough across (or up): he moves (or jumps) now, not when the
  /// finger lifts.
  void _panUpdate(DragUpdateDetails d) {
    final g = _game;
    if (g == null || _paused || _swiped) return;
    _pan += d.delta;
    const far = 22.0;
    if (_pan.dx.abs() > far && _pan.dx.abs() > _pan.dy.abs()) {
      _swiped = true;
      g.move(_pan.dx > 0 ? 1 : -1);
    } else if (_pan.dy.abs() > far && _pan.dy.abs() > _pan.dx.abs()) {
      _swiped = true;
      _pan.dy < 0 ? g.jump() : g.slide();
    }
  }

  void _panEnd(DragEndDetails d) {
    final g = _game;
    if (g == null || _paused || _swiped) return;
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 150) return;
    if (v.dy.abs() > v.dx.abs()) {
      v.dy < 0 ? g.jump() : g.slide();
    } else if (v.dx.abs() > v.dy.abs()) {
      g.move(v.dx > 0 ? 1 : -1);
    }
  }

  /// A tap beside Pencil moves him a lane that way; on him, he jumps.
  void _tap(TapUpDetails d) {
    final g = _game, road = _road;
    if (g == null || road == null || _paused) return;
    final x = d.localPosition.dx, me = _cam.map(road.at(0, _viewLane)).dx;
    if ((x - me).abs() < road.laneWidth * .45 && d.localPosition.dy > road.player - 260) {
      g.jump();
    } else {
      g.move(x > me ? 1 : -1);
    }
  }

  // ------------------------------------------------------------ build

  SrRider _rider(SrGame g) {
    var pose = 'ride';
    var lean = 0.0, shake = 0.0;
    final steer = _laneVel;
    final since = _clock - _landAt, up = _clock - _jumpAt;
    if (g.sliding) {
      pose = 'slide';
    } else if (g.air > 0) {
      // a crouch as he springs up, a trick off a ramp or on springs
      pose = up < .09 ? 'crouch' : (g.ramped || g.has(SrKind.spring) ? 'trick' : 'jump');
      lean = (steer * .04).clamp(-.15, .15);
    } else if (g.stumble > 0) {
      pose = 'stumble';
      shake = math.sin(_clock * 34) * 6 * (g.stumble / 1.1).clamp(0.0, 1.0);
      lean = math.sin(_clock * 17) * .06;
    } else if (g.phase == SrPhase.over || g.phase == SrPhase.done) {
      // the last bump: he tumbles
      pose = 'stumble';
      final k = (1 - g.phaseTime / 1.2).clamp(0.0, 1.0);
      shake = math.sin(_clock * 30) * 8 * k;
      lean = math.sin(_clock * 12) * .2 * k + .1 * (1 - k);
    } else if (since < .2) {
      pose = 'land';
    } else if (g.cheer < 1.1) {
      pose = 'cheer';
    } else if (steer.abs() > 1.2) {
      // the carve picture already leans: only a touch more
      pose = steer > 0 ? 'carve_right' : 'carve_left';
      lean = (steer * .012).clamp(-.07, .07);
    } else if (steer.abs() > .15) {
      // banking into the turn before the carve picture, and out of it after
      lean = (steer * .06).clamp(-.08, .08);
    } else {
      // riding: a kick on the road now and then (not while boosted), a
      // gentle sway
      final kick = g.phase == SrPhase.running && g.boost <= 0 && (_clock % 1.7) < .38;
      if (kick) pose = 'push';
      lean = math.sin(_clock * 2.2) * .025;
    }
    // stretched as he leaves the road, squashed a little as he lands (the
    // land picture does the rest)
    final squash = g.air > 0 && up < .3 ? 1 + .1 * (1 - up / .3) : (since < .3 ? 1 - .06 * math.exp(-since * 9) : 1.0);
    // just bumped: he blinks while nothing can bump him
    final blink = g.safe > 0 && g.phase == SrPhase.running && (_clock * 12).floor().isEven ? .35 : 1.0;
    return SrRider(pose: SrArt.rider(pose), lane: _viewLane, lean: lean, squash: squash, shake: shake, alpha: blink);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    _pad = pad;
    _best = ref.watch(myGamesProvider)[GameIds.runner]?.best ?? 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LikhoSystemBars.dark,
      child: Material(
        color: LikhoColors.background,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final road = _road = (_road != null && _road!.screen == size && _road!.bg == _bg) ? _road! : SrRoad(size, _bg, bottomInset: pad.bottom);
            final g = _game;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _panStart,
                    onPanUpdate: _panUpdate,
                    onPanEnd: _panEnd,
                    onTapUp: _tap,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _scene(road, g)),
                  ),
                ),
                if (g != null) ...[
                  Positioned(
                    top: pad.top + 8,
                    left: 12,
                    right: 12,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _hud(g, size)),
                  ),
                  Positioned(
                    right: 14,
                    bottom: pad.bottom + 18,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _jumpButton(g)),
                  ),
                  Positioned(
                    left: 14,
                    bottom: pad.bottom + 18,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _slideButton(g)),
                  ),
                  Positioned(
                    left: 18,
                    bottom: pad.bottom + 18 + 76 + 14,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _powerTimers(g)),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _overlays(g, road)),
                    ),
                  ),
                  if (!_started)
                    Positioned.fill(
                      child: GameStartCard(
                        id: 'sr',
                        title: 'Spell Runner',
                        cover: SrArt.cover,
                        hint: _firstPlay ? SrLines.intro.text : 'Catch the letters!',
                        best: _best,
                        onPlay: _play,
                        onBack: _exit,
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _speech(road, g)),
                    ),
                  ),
                  if (_paused)
                    Positioned.fill(
                      child: GamePauseCard(id: 'sr', picture: SrArt.rider('stumble'), onResume: _resume, onExit: _exit),
                    ),
                  if (_showResult)
                    Positioned.fill(
                      child: GameResultCard(
                        id: 'sr',
                        picture: SrArt.rider('cheer'),
                        title: 'Great run!',
                        star: SrArt.star,
                        stars: g.stars,
                        score: g.score,
                        detail: '${g.metres} m · ${g.done} ${g.done == 1 ? 'word' : 'words'}',
                        record: _record,
                        onAgain: _again,
                        onDone: _exit,
                      ),
                    ),
                ] else
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator(color: MonsterColors.magic)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _scene(SrRoad road, SrGame? g) {
    final shake = Offset(math.sin(_clock * 61) * _shake, math.cos(_clock * 47) * _shake * .6);
    return ClipRect(
      child: Transform(
        transform: _cam.matrix(shake),
        // the picture reaches past the screen: the camera moves over it
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: road.origin.dx,
              top: road.origin.dy,
              width: road.imageSize.width,
              height: road.imageSize.height,
              child: Image.asset(_bg.asset, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium),
            ),
            if (g != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: SrWorldPainter(road: road, game: g, scenery: _scenery, rider: _rider(g), chase: _chase(g), time: _clock, hint: _hint),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: MdEffectsPainter(bits: _bits, beams: const [], bubbles: const [], time: _clock),
              ),
            ),
            if (g != null) Positioned.fill(child: IgnorePointer(child: ColoredBox(color: _tint(g)))),
          ],
        ),
      ),
    );
  }

  /// The light of the part of the road he is in, blending into the next
  /// one over the last 30 metres before it.
  Color _tint(SrGame g) {
    final m = g.dist * SrGame.metre;
    final here = SrZone.all[SrZone.at(m)].tint, next = SrZone.all[SrZone.at(m + 30)].tint;
    final into = ((m % SrGame.zoneMetres) - (SrGame.zoneMetres - 30)) / 30;
    return Color.lerp(here, next, into.clamp(0.0, 1.0))!;
  }

  // ------------------------------------------------------------ the top bar

  static const _slot = 46.0, _gap = 6.0, _pic = 56.0;

  /// Where box [i] of the word card is (for the letters flying in).
  Offset _slotAt(int i, SrTask task, Size size) {
    final n = task.letters.length;
    final hasPic = task.picture != null || task.hunt;
    final w = (hasPic ? _pic + 10 : 0) + n * _slot + (n - 1) * _gap + 24;
    final left = (size.width - w) / 2 + 12 + (hasPic ? _pic + 10 : 0);
    return Offset(left + i * (_slot + _gap) + _slot / 2, _pad.top + 8 + 46 + 10 + 12 + (_slot + 10) / 2);
  }

  /// The word on the card: the one being spelled, or for a moment after it
  /// is done the finished one, all boxes filled.
  (SrTask?, int) _card(SrGame g) {
    final last = g.previous;
    if (_clock - _wordAt < 1.3 && last != null) return (last, last.letters.length);
    return (g.current, g.got);
  }

  Widget _hud(SrGame g, Size size) {
    final (task, filled) = _card(g);
    return Column(
      children: [
        Row(
          children: [
            PushButton(
              key: const ValueKey('sr-pause'),
              onTap: _started ? _pause : _exit,
              color: MonsterColors.panel,
              width: 46,
              height: 46,
              shape: const CircleBorder(),
              shadows: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 3), blurRadius: 6)],
              child: Icon(_started ? Symbols.pause_rounded : Symbols.arrow_back_rounded, size: 26, weight: 700, fill: 1, color: LikhoColors.ink),
            ),
            const SizedBox(width: 8),
            _Hearts(hearts: g.hearts, lostAt: _heartLostAt, gainedAt: _heartAt, clock: _clock),
            const Spacer(),
            Flexible(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: GamePill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.directions_run_rounded, size: 22, weight: 700, color: LikhoColors.ink),
                      const SizedBox(width: 3),
                      Text(
                        '${g.metres} m',
                        key: const ValueKey('sr-metres'),
                        style: LikhoFonts.title(size: 18, weight: FontWeight.w800).copyWith(height: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: GamePill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(SrArt.star, width: 24, height: 24),
                      const SizedBox(width: 5),
                      Text(
                        '${_shownScore.round()}',
                        key: const ValueKey('sr-score'),
                        style: LikhoFonts.title(size: 20, weight: FontWeight.w800).copyWith(height: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (task != null && _started) _WordCard(task: task, filled: filled, clock: _clock, flying: _flights.map((f) => f.slot).toSet()),
      ],
    );
  }

  Widget _jumpButton(SrGame g) {
    final ready = g.phase == SrPhase.running && g.air == 0;
    final pulse = _firstPlay && _jumpHinted && !_jumped ? 1 + .1 * math.sin(_clock * 10).abs() : 1.0;
    return Transform.scale(
      scale: pulse,
      child: Opacity(
        opacity: g.phase == SrPhase.running ? 1 : .5,
        child: PushButton(
          key: const ValueKey('sr-jump'),
          onTap: ready ? _jump : null,
          color: MonsterColors.ribbon,
          edgeColor: MonsterColors.ribbonDeep,
          edge: 5,
          width: 76,
          height: 76,
          shape: const CircleBorder(),
          shadows: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 4), blurRadius: 10)],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.keyboard_double_arrow_up_rounded, size: 34, weight: 700, color: LikhoColors.surface),
              Text(
                'Jump',
                style: LikhoFonts.title(size: 13, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The power-ups working now: each its picture in a ring that empties.
  Widget _powerTimers(SrGame g) {
    final on = [for (final k in const [SrKind.magnet, SrKind.shield, SrKind.spring, SrKind.double]) if (g.has(k)) k];
    return Column(
      key: const ValueKey('sr-powers'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in on)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              key: ValueKey('sr-power-${k.name}'),
              width: 52,
              height: 52,
              child: CustomPaint(painter: _PowerTimerPainter(k, (g.powers[k]! / SrGame.powerTime[k]!).clamp(0.0, 1.0), _clock)),
            ),
          ),
      ],
    );
  }

  /// Slide (down flat under high bars): it pops in when the first bar
  /// comes, and throbs while Pencil says how.
  Widget _slideButton(SrGame g) {
    if (!_bars) return const SizedBox.shrink();
    final ready = g.phase == SrPhase.running && !g.sliding;
    final pulse = _slideHinted && !_slid ? 1 + .1 * math.sin(_clock * 10).abs() : 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v * pulse, child: child),
      child: Opacity(
        opacity: g.phase == SrPhase.running ? 1 : .5,
        child: PushButton(
          key: const ValueKey('sr-slide'),
          onTap: ready ? _slide : null,
          color: RunnerColors.slide,
          edgeColor: RunnerColors.slideDeep,
          edge: 5,
          width: 76,
          height: 76,
          shape: const CircleBorder(),
          shadows: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 4), blurRadius: 10)],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.keyboard_double_arrow_down_rounded, size: 34, weight: 700, color: LikhoColors.surface),
              Text(
                'Slide',
                style: LikhoFonts.title(size: 13, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A ribbon with [text] at [at] of the screen's height: it pops in, stays
  /// and fades away over [life] seconds.
  Widget _banner(SrRoad road, String text, double t, double life, Color color, Color deep, double at, Key key) {
    final pop = Curves.elasticOut.transform((t / .6).clamp(0.0, 1.0));
    final fade = (1 - (t - (life - .4)) / .4).clamp(0.0, 1.0);
    return Positioned(
      left: 0,
      right: 0,
      top: road.screen.height * at,
      child: Center(
        child: Opacity(
          opacity: fade,
          child: Transform.scale(
            scale: .4 + .6 * pop,
            child: Container(
              key: key,
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: LikhoColors.surface, width: 3),
                boxShadow: [BoxShadow(color: deep, offset: const Offset(0, 5)), const BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 8), blurRadius: 14)],
              ),
              child: Text(text, style: LikhoFonts.title(size: 26, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1.1)),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ over the road

  Widget _overlays(SrGame g, SrRoad road) {
    final kids = <Widget>[];
    // 3, 2, 1, Go!
    if (g.phase == SrPhase.countdown || (g.phase == SrPhase.running && g.phaseTime < .7)) {
      final going = g.phase == SrPhase.running;
      final t = going ? g.phaseTime : g.phaseTime % 1;
      final n = going ? 'GO!' : '${3 - g.phaseTime.floor()}';
      final pop = Curves.elasticOut.transform((t / .5).clamp(0.0, 1.0));
      kids.add(
        Align(
          alignment: const Alignment(0, .05),
          child: Opacity(
            opacity: (1 - (t - .55) / .45).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .4 + .8 * pop,
              child: Text(
                n,
                style: LikhoFonts.title(size: 96, weight: FontWeight.w800, color: going ? LikhoColors.success : MonsterColors.ribbon).copyWith(
                  shadows: const [
                    Shadow(color: MonsterColors.panel, offset: Offset(0, 0), blurRadius: 0),
                    Shadow(color: MonsterColors.panelShadow, offset: Offset(0, 6), blurRadius: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    // the word, big, when it is spelled
    final since = _clock - _wordAt;
    if (since < 1.5) {
      final pop = Curves.elasticOut.transform((since / .6).clamp(0.0, 1.0));
      kids.add(
        Align(
          // in the sky, over nothing that is coming
          alignment: const Alignment(0, -.42),
          child: Opacity(
            opacity: (1 - (since - 1.1) / .4).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .3 + .7 * pop,
              child: Container(
                padding: const EdgeInsets.fromLTRB(30, 6, 30, 12),
                decoration: BoxDecoration(
                  color: LikhoColors.success,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: GameColors.successDeep, offset: Offset(0, 6)),
                    BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 12), blurRadius: 18),
                  ],
                ),
                child: Text('$_wordShown!', style: LikhoFonts.letter(size: 56, color: LikhoColors.surface).copyWith(height: 1.1)),
              ),
            ),
          ),
        ),
      );
    }
    // longer words from now on
    final level = _clock - _longerAt;
    if (level >= 0 && level < 1.8) {
      final pop = Curves.elasticOut.transform((level / .6).clamp(0.0, 1.0));
      kids.add(
        Align(
          alignment: const Alignment(0, -.42),
          child: Opacity(
            opacity: (1 - (level - 1.4) / .4).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .3 + .7 * pop,
              child: Container(
                key: const ValueKey('sr-longer'),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                decoration: BoxDecoration(
                  color: MonsterColors.ribbon,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [BoxShadow(color: MonsterColors.ribbonDeep, offset: Offset(0, 6))],
                ),
                child: Text(
                  'Longer words!',
                  style: LikhoFonts.title(size: 34, weight: FontWeight.w800, color: MonsterColors.ribbonInk).copyWith(height: 1.1),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // letters flying up into their boxes
    final (task, _) = _card(g);
    if (task != null) {
      for (final f in _flights) {
        final k = Curves.easeInOutCubic.transform((f.t / _Flight.time).clamp(0.0, 1.0));
        final to = _slotAt(f.slot, task, road.screen);
        final mid = Offset.lerp(f.from, to, .5)! - const Offset(0, 80);
        final p = f.from * ((1 - k) * (1 - k)) + mid * (2 * k * (1 - k)) + to * (k * k);
        kids.add(
          Positioned(
            left: p.dx - 30,
            top: p.dy - 30,
            width: 60,
            height: 60,
            child: Center(
              child: Transform.scale(
                scale: 1.4 - .4 * k,
                child: Text(
                  f.letter,
                  style: LikhoFonts.letter(size: 40, color: MonsterColors.ribbonDeep).copyWith(shadows: const [Shadow(color: MonsterColors.panel, blurRadius: 6)]),
                ),
              ),
            ),
          ),
        );
      }
    }
    // a new part of the road, a new best score: a banner pops up
    final zt = _clock - _zoneAt, bt = _clock - _bestAt;
    if (zt < 2.6) kids.add(_banner(road, SrZone.all[_zoneShown % SrZone.all.length].name, zt, 2.6, RunnerColors.banner, RunnerColors.bannerDeep, .33, const ValueKey('sr-zone')));
    if (bt < 2.2) kids.add(_banner(road, 'New best!', bt, 2.2, RunnerColors.double2x, MonsterColors.goldDeep, .42, const ValueKey('sr-best')));
    return Stack(children: kids);
  }

  /// What Pencil says, in a bubble over his head.
  Widget _speech(SrRoad road, SrGame? g) {
    final c = _caption;
    // before the game, the start card says it
    if (c == null || g == null || _showResult || _paused || !_started) return const SizedBox.shrink();
    // under the word card, where it hides nothing that comes
    final top = _pad.top + 8 + 46 + 10 + (_started ? _slot + 10 + 24 + 10 : 0);
    return Stack(
      children: [
        Positioned(
          left: 24,
          right: 24,
          top: top,
          height: 64,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              key: const ValueKey('sr-caption'),
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
              decoration: BoxDecoration(
                color: MonsterColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 4), blurRadius: 10)],
              ),
              child: Text(
                c,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: LikhoFonts.title(size: c.length > 50 ? 15 : 18, weight: FontWeight.w800).copyWith(height: 1.15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The word to spell: its picture and a box for each letter (caught ones
/// filled, the next one glowing); a hunt shows the letter and three dots.
class _WordCard extends StatelessWidget {
  const _WordCard({required this.task, required this.filled, required this.clock, required this.flying});
  final SrTask task;
  final int filled;
  final double clock;
  final Set<int> flying;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(task),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutBack,
    builder: (context, v, child) => Transform.scale(scale: .6 + .4 * v, child: child),
    child: Container(
      key: const ValueKey('sr-word'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MonsterColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 6), blurRadius: 14)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.picture != null) ...[
            Image.asset(task.picture!, width: _SpellRunnerScreenState._pic, height: _SpellRunnerScreenState._pic, fit: BoxFit.contain),
            const SizedBox(width: 10),
          ] else ...[
            Container(
              width: _SpellRunnerScreenState._pic,
              height: _SpellRunnerScreenState._pic,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: MonsterColors.ribbon, borderRadius: BorderRadius.circular(16)),
              child: Text(task.letters[0], style: LikhoFonts.letter(size: 40, color: LikhoColors.surface).copyWith(height: 1)),
            ),
            const SizedBox(width: 10),
          ],
          for (var i = 0; i < task.letters.length; i++) ...[if (i > 0) const SizedBox(width: _SpellRunnerScreenState._gap), _box(i)],
        ],
      ),
    ),
  );

  Widget _box(int i) {
    final done = i < filled && !flying.contains(i);
    final next = i == filled;
    final glow = next ? .5 + .5 * math.sin(clock * 6) : 0.0;
    return Container(
      key: ValueKey('sr-box-$i'),
      width: _SpellRunnerScreenState._slot,
      height: _SpellRunnerScreenState._slot + 10,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? LikhoColors.success : MonsterColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: next ? MonsterColors.ribbon.withValues(alpha: .5 + .5 * glow) : (done ? GameColors.successDeep : GameColors.ink15),
          width: next ? 3 : 2,
        ),
      ),
      child: done ? Text(task.letters[i], style: LikhoFonts.letter(size: 34, color: LikhoColors.surface).copyWith(height: 1)) : (task.hunt ? null : const SizedBox.shrink()),
    );
  }
}

/// Pencil's three hearts: a lost one shakes and fades, a new one pops in.
class _Hearts extends StatelessWidget {
  const _Hearts({required this.hearts, required this.lostAt, required this.gainedAt, required this.clock});
  final int hearts;
  final double lostAt, gainedAt, clock;

  @override
  Widget build(BuildContext context) {
    final lost = clock - lostAt, gained = clock - gainedAt;
    return GamePill(
      child: Row(
        key: const ValueKey('sr-hearts'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < SrGame.hearts0; k++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.translate(
                offset: Offset(k == hearts && lost < .5 ? math.sin(lost * 50) * 4 * (1 - lost / .5) : 0, 0),
                child: Transform.scale(
                  scale: k == hearts - 1 && gained < .4 ? 1 + .5 * math.sin(gained / .4 * math.pi) : (k < hearts ? 1 : .78),
                  child: Opacity(opacity: k < hearts ? 1 : .28, child: Image.asset(SrArt.heart, width: 24, height: 22)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The camera behind Pencil: a little after him across the lanes ([x]),
/// leaning into a turn ([roll]) and closer as he speeds up ([zoom]), all
/// around the road's vanishing point.
class _Camera {
  double x = 0, roll = 0, zoom = 1.04;
  Offset vanish = Offset.zero;

  /// Where a point of the world is on the screen (the lean left out: it is
  /// too small to miss a finger).
  Offset map(Offset p) => Offset(vanish.dx + (p.dx - vanish.dx) * zoom + x, vanish.dy + (p.dy - vanish.dy) * zoom);

  Matrix4 matrix(Offset shake) => Matrix4.identity()
    ..translateByDouble(vanish.dx + x + shake.dx, vanish.dy + shake.dy, 0, 1)
    ..rotateZ(roll)
    ..scaleByDouble(zoom, zoom, 1, 1)
    ..translateByDouble(-vanish.dx, -vanish.dy, 0, 1);
}

/// A power-up's timer: its picture in a white disc, a ring that empties
/// (it blinks near the end).
class _PowerTimerPainter extends CustomPainter {
  _PowerTimerPainter(this.kind, this.left, this.time);
  final SrKind kind;
  final double left, time;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final color = SrPowerArt.color(kind);
    final blink = left < .2 && (time * 6).floor().isEven ? .45 : 1.0;
    canvas.drawCircle(c + const Offset(0, 3), r - 1, Paint()..color = MonsterColors.panelShadow);
    canvas.drawCircle(c, r - 1, Paint()..color = MonsterColors.panel);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r - 5, ring..color = GameColors.ink15);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 5), -math.pi / 2, math.pi * 2 * left, false, ring..color = color.withValues(alpha: blink));
    SrPowerArt.icon(canvas, kind, c, r * .5, color.withValues(alpha: blink));
  }

  @override
  bool shouldRepaint(covariant _PowerTimerPainter old) => old.left != left || old.time != time;
}
