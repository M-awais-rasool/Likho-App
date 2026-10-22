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
import '../../../game/monster_defense/md_engine.dart';
import '../../../game/monster_defense/md_questions.dart';
import '../../../game/speech/prompt_voice.dart';
import '../../../mascot/mascot.dart';
import '../../gameplay/widgets/game_buttons.dart';
import 'md_effects.dart';
import 'md_lines.dart';
import 'md_scene.dart';

/// Monster Defense: the silly monsters come down the path from the cave;
/// Pencil (in his wizard hat, by the garden gate) asks for a letter or a
/// word, and the child taps the monster carrying it: his magic flies, the
/// monster is caught in a bubble, floats up, pops and waves as a friend. A
/// wrong tap makes it roar and jump closer; one at the gate costs a heart.
/// Three waves, then Big Bonk (choices in his balloons). Answers in a row
/// earn Freeze and Double magic. See [MdGame] for the rules.
class MonsterDefenseScreen extends ConsumerStatefulWidget {
  const MonsterDefenseScreen({super.key, required this.onDone, this.random, this.questions});
  final VoidCallback onDone;

  /// Tests: fixed dice and questions.
  final math.Random? random;
  final MdQuestionSource? questions;

  @override
  ConsumerState<MonsterDefenseScreen> createState() => _MonsterDefenseScreenState();
}

/// Where a monster is drawn this frame.
class _Box {
  const _Box(this.feet, this.rect, this.alpha);
  final Offset feet; // on the ground (shadow)
  final Rect rect; // the picture
  final double alpha;
}

class _MonsterDefenseScreenState extends ConsumerState<MonsterDefenseScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  late final math.Random _rnd = widget.random ?? math.Random();
  late final AppFeedback _fb = ref.read(feedbackProvider);
  late final PromptVoice _voice = ref.read(promptVoiceProvider);
  late final bool _voiceOn = ref.read(voiceOnProvider);
  final _pencil = MascotController();

  MdGame? _game;
  MdQuestionSource? _questions;
  Duration? _last;
  double _clock = 0;

  bool _started = false, _paused = false, _showResult = false, _record = false;
  late bool _firstPlay;

  // what Pencil says (a reaction; the question card shows otherwise)
  String? _caption;
  int _talkId = 0, _askId = 0;
  Future<void> _speaking = Future<void>.value();
  Completer<void>? _shown; // the voice off: done when a caption's time is up
  Timer? _captionTimer, _resultTimer;
  final _timers = <Timer>[];
  int _best = 0;
  int _great = 0, _oops = 0;
  double _questionAt = 0;

  // effects
  final _bits = <MdBit>[];
  final _beams = <MdBeam>[];
  double _shake = 0, _frost = 0, _danger = 0, _calmFor = 0, _shownScore = 0;
  bool _tense = false;
  double _lastSpawn = -1;

  double? _balloonTop; // eased to [_balloonTarget]

  // layout of the last build
  MdFrame _mf = const MdFrame(Size(390, 844));
  EdgeInsets _pad = EdgeInsets.zero;
  double _pencilH = 130;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _voice;
    _voiceOn;
    _pencil
      ..setBodyColor(ref.read(progressProvider).color.key)
      ..wear(MascotAccessory.wizardHat);
    _firstPlay = (ref.read(myGamesProvider)[GameIds.monsters]?.plays ?? 0) == 0;
    _fb.prepare(Sfx.monsterDefense);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final a in MdArt.all) {
      precacheImage(AssetImage(a), context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captionTimer?.cancel();
    _resultTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _ticker.dispose();
    _frame.dispose();
    _voice.stop();
    _fb.stopMusic();
    _pencil.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  /// The questions: what this child has learned.
  Future<void> _load() async {
    var q = widget.questions;
    if (q == null) {
      final words = await MdWords.load();
      if (!mounted) return;
      final course = ref.read(courseProvider).value;
      final done = ref.read(progressProvider).levelStars.keys;
      q = MdQuestions(MdKnowledge.of(course, done), words, random: _rnd);
    }
    if (!mounted) return;
    setState(() {
      _questions = q;
      _game = MdGame(questions: q!, random: _rnd);
    });
    // a first game: Pencil tells what to do
    if (_firstPlay) _say(MdLines.intro, hold: true);
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
      for (final b in _bits) {
        b.step(dt);
      }
      _bits.removeWhere((b) => b.done);
      for (final b in _beams) {
        b.age += dt;
      }
      _beams.removeWhere((b) => b.done);
      _shake *= math.exp(-dt * 9);
      _frost += ((g.frozen > 0 ? 1 : 0) - _frost) * math.min(1, dt * 5);
      final close = g.inDanger;
      _danger += ((close ? .65 + .35 * math.sin(_clock * 7) : 0) - _danger) * math.min(1, dt * 6);
      _shownScore += (g.score - _shownScore) * math.min(1, dt * 8);
      if (g.balloons.isNotEmpty) {
        final to = _balloonTarget(g);
        _balloonTop = _balloonTop == null ? to : _balloonTop! + (to - _balloonTop!) * math.min(1, dt * 2.5);
      } else {
        _balloonTop = null;
      }
      if ((g.score - _shownScore).abs() < .5) _shownScore = g.score.toDouble();
      // the music follows the danger (back to calm after a little while)
      if (g.phase == MdPhase.playing || g.phase == MdPhase.banner || g.phase == MdPhase.bossIntro) {
        _calmFor = close ? 0 : _calmFor + dt;
        final tense = close || (_tense && _calmFor < 1.5);
        if (tense != _tense) {
          _tense = tense;
          _fb.music(tense: tense);
        }
      }
    }
    _frame.value++;
  }

  // ------------------------------------------------------------ what happened

  void _on(MdEvent e, MdGame g) {
    final m = e.monster == null ? null : g.monsters.where((m) => m.id == e.monster).firstOrNull;
    switch (e.kind) {
      case MdEventKind.banner:
        _fb.wave();
        _say(e.value == 0 ? MdLines.go : MdLines.wave);
      case MdEventKind.bossIntro:
        _fb.bigBoss();
        _shake = 10;
        _say(MdLines.boss);
      case MdEventKind.question:
        final q = g.question!;
        _questionAt = _clock;
        if (q.picture != null) precacheImage(AssetImage(q.picture!), context);
        _ask(q);
      case MdEventKind.spawn:
        if (m?.kind == MdKind.boss) {
          _after(450, () {
            _fb.bossStamp();
            _shake = 12;
          });
        } else if (_clock - _lastSpawn > .6) {
          _fb.monsterOut();
        }
        _lastSpawn = _clock;
      case MdEventKind.trapped:
      case MdEventKind.hit:
        if (m == null) return;
        _zap(m);
        final box = _box(m);
        _bits.add(MdBit.score(box.rect.topCenter + const Offset(0, -10), e.value));
        _pencil.play(MascotState.happy);
        if (e.kind == MdEventKind.trapped) {
          _after(320, _fb.bubble);
          if (g.phase == MdPhase.playing && g.question == null && !g.isBoss) _say(MdLines.great[_great++ % MdLines.great.length]);
        }
      case MdEventKind.crack:
        if (m == null) return;
        _zap(m);
        _after(300, () {
          _fb.crack();
          _shake = 5;
        });
        _say(MdLines.crack);
      case MdEventKind.popped:
        if (m == null) return;
        _fb.bubblePop();
        final box = _box(m, popped: true);
        _bits.addAll(MdBit.burst(box.rect.center, _rnd, n: m.kind == MdKind.boss ? 26 : 16));
      case MdEventKind.miss:
        _fb.roar();
        _fb.wrong();
        _shake = 4;
        _pencil.play(MascotState.encourage);
        _say(MdLines.oops[_oops++ % MdLines.oops.length]);
        // then the question again (the child may have forgotten it)
        if (g.question != null) _ask(g.question!);
      case MdEventKind.hint:
        break; // the right one glows
      case MdEventKind.hurry:
        _fb.hurry();
        _say(MdLines.hurry);
      case MdEventKind.gate:
        _fb.gate();
        _fb.roar();
        _shake = 14;
        _pencil.play(MascotState.wow);
        _say(MdLines.gate);
      case MdEventKind.power:
        _fb.powerUp();
        _say(MdLines.power);
      case MdEventKind.freeze:
        _fb.freeze();
        _say(MdLines.freeze);
      case MdEventKind.potion:
        _fb.potion();
        _say(MdLines.potion);
      case MdEventKind.bossHit:
        _after(300, () {
          _fb.bossHit(big: true);
          _shake = 8;
        });
        _say(MdLines.bossHit);
      case MdEventKind.won:
        _end(g, won: true);
      case MdEventKind.lost:
        _end(g, won: false);
    }
  }

  /// Runs [f] in [ms] (unless the screen closed first).
  void _after(int ms, VoidCallback f) {
    _timers.removeWhere((t) => !t.isActive);
    _timers.add(
      Timer(Duration(milliseconds: ms), () {
        if (mounted) f();
      }),
    );
  }

  void _zap(MdMonster m) {
    _fb.zap();
    _beams.add(MdBeam(_hand, _box(m).rect.center));
  }

  /// Where Pencil's magic comes from (his raised hand).
  Offset get _hand {
    final w = PencilMascot.widthFor(_pencilH);
    return Offset(6 + w * .82, _mf.screen.height - _pad.bottom - 2 - _pencilH * .66);
  }

  void _end(MdGame g, {required bool won}) {
    _fb.stopMusic();
    final child = ref.read(familyProvider).active.id;
    _record = ref.read(gameProgressProvider.notifier).record(child, GameIds.monsters, score: g.score, stars: g.stars);
    if (won) {
      _fb.levelComplete();
      _fb.confetti();
      _bits.addAll(MdBit.confetti(_mf.screen.width, _rnd));
      _pencil.play(MascotState.dance);
      _say(_record ? MdLines.record : MdLines.win);
    } else {
      _fb.gameLost();
      _pencil.play(MascotState.encourage);
      _say(MdLines.lose);
    }
    _resultTimer = Timer(Duration(milliseconds: won ? 1600 : 900), () {
      if (mounted) setState(() => _showResult = true);
    });
  }

  // ------------------------------------------------------------ Pencil talks

  /// Pencil says [line] now (cutting what he was saying); his bubble shows
  /// its words for a moment ([hold]: until the game starts), then the
  /// question card again.
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
    _speaking = _voiceOn ? _voice.speak(line, _pencil, after: MascotState.idle).then((_) {}) : (hold ? Future<void>.value() : shown.future);
  }

  void _endCaption() {
    final s = _shown;
    if (s != null && !s.isCompleted) s.complete();
  }

  /// Pencil asks [q] once he has finished what he is saying ([now]: at
  /// once); the bubble shows the question card.
  Future<void> _ask(MdQuestion q, {bool now = false}) async {
    final ask = ++_askId;
    if (!now) {
      // what he is saying, but never long (a line that does not end)
      final said = Completer<void>();
      _after(4000, () => said.isCompleted ? null : said.complete());
      _speaking.whenComplete(() => said.isCompleted ? null : said.complete());
      await said.future;
    }
    if (!mounted || ask != _askId || _game?.question != q || _paused) return;
    _talkId++;
    _captionTimer?.cancel();
    _endCaption();
    setState(() => _caption = null);
    _speaking = _voiceOn
        ? _voice
              .speak(
                Prompt(text: q.say, audio: q.audio),
                _pencil,
                after: MascotState.idle,
              )
              .then((_) {})
        : Future<void>.value();
  }

  // ------------------------------------------------------------ the child

  void _play() {
    final g = _game;
    if (g == null || _started) return;
    _fb.levelStart();
    setState(() => _started = true);
    _voice.stop();
    _caption = null;
    _tense = false;
    _fb.music();
    g.start();
  }

  void _again() {
    final q = _questions;
    if (q == null) return;
    _fb.press();
    _resultTimer?.cancel();
    setState(() {
      _game = MdGame(questions: q, random: _rnd);
      _started = false;
      _showResult = false;
      _record = false;
      _caption = null;
      _bits.clear();
      _beams.clear();
      _shownScore = 0;
    });
    _pencil.play(MascotState.idle);
    _play();
  }

  void _pause() {
    final g = _game;
    if (_paused || g == null || !_started || g.phase == MdPhase.won || g.phase == MdPhase.lost) return;
    setState(() => _paused = true);
    _voice.stop();
    _fb.stopMusic();
  }

  void _resume() {
    _fb.press();
    setState(() => _paused = false);
    _last = null;
    _fb.music(tense: _tense);
    final q = _game?.question;
    if (q != null) _ask(q, now: true);
  }

  void _exit() {
    _fb.back();
    _voice.stop();
    _fb.stopMusic();
    widget.onDone();
  }

  void _replay() {
    final q = _game?.question;
    if (q == null) return;
    _fb.tap();
    _ask(q, now: true);
  }

  void _tapScene(TapDownDetails d) {
    final g = _game;
    if (g == null || _paused || g.phase != MdPhase.playing) return;
    final p = d.localPosition;
    if (g.isBoss) {
      final rects = _balloonRects(g);
      for (var i = 0; i < rects.length; i++) {
        if (rects[i].inflate(10).contains(p)) {
          g.tapBalloon(i);
          return;
        }
      }
      return;
    }
    MdMonster? best;
    var bestY = -1.0;
    for (final m in g.monsters) {
      if (!m.tappable || !m.out) continue;
      final b = _box(m);
      var r = b.rect.expandToInclude(Rect.fromCenter(center: b.rect.topCenter, width: 60, height: 50));
      if (r.width < 76 || r.height < 76) r = Rect.fromCenter(center: r.center, width: math.max(76, r.width), height: math.max(76, r.height));
      if (r.contains(p) && b.feet.dy > bestY) {
        best = m;
        bestY = b.feet.dy;
      }
    }
    if (best != null) g.tap(best.id);
  }

  // ------------------------------------------------------------ geometry

  static double _kindScale(MdKind k) => switch (k) {
    MdKind.gloop => .95,
    MdKind.fuzz => .92,
    MdKind.bonk => 1.06,
    MdKind.boo => .95,
    MdKind.boss => 2.0,
  };

  /// How high a caught monster floats (fraction of the screen's height).
  static double _riseOf(MdMonster m, {bool popped = false}) {
    final boss = m.kind == MdKind.boss;
    final top = boss ? .14 : .2;
    if (popped) return top;
    final t = m.moodTime;
    switch (m.mood) {
      case MdMood.trapped:
        final from = boss ? .9 : .55, len = boss ? 1.6 : 1.3;
        return t < from ? 0 : top * Curves.easeOutCubic.transform(((t - from) / len).clamp(0.0, 1.0));
      case MdMood.friendly:
        // falls back down, then waves
        return t < .45 ? top * (1 - Curves.easeInQuad.transform(t / .45)) : 0;
      default:
        return 0;
    }
  }

  _Box _box(MdMonster m, {bool popped = false}) {
    final f = MdPath.shared.feet(m.u.clamp(0.0, 1.0), m.lane + m.drift);
    final depth = MdPath.depth(f.dy);
    final h = _mf.monsterHeight * depth * _kindScale(m.kind);
    final ps = MdArt.poseSize(m.kind);
    final w = h * ps.width / ps.height;
    final feet = _mf.at(f);
    // a caught monster floats up, but its bubble stays under the top bar
    final rise = math.min(_riseOf(m, popped: popped) * _mf.screen.height, math.max(0.0, feet.dy - h * 1.2 - _pad.top - 70));
    var alpha = 1.0;
    if (m.u < 0) {
      alpha = 0;
    } else if (m.mood == MdMood.walking && m.u < .04) {
      alpha = m.u / .04;
    }
    if (m.mood == MdMood.fleeing) alpha = math.min(alpha, 1 - m.moodTime / 1.4);
    if (m.mood == MdMood.friendly && m.moodTime > 1.15) alpha = 1 - (m.moodTime - 1.15) / .45;
    return _Box(feet, Rect.fromLTWH(feet.dx - w / 2, feet.dy - h - rise, w, h), alpha.clamp(0.0, 1.0));
  }

  /// The boss's balloons (his choices), above his head but under the top bar.
  List<Rect> _balloonRects(MdGame g) {
    final b = g.boss, n = g.balloons.length;
    if (b == null || n == 0) return const [];
    final w = math.min(88.0, (_mf.screen.width - 40) / 3.6), h = w * 1.22;
    final gap = w * .3;
    final total = n * w + (n - 1) * gap;
    final top = _balloonTop ?? _balloonTarget(g);
    final left = (_mf.screen.width - total) / 2;
    return [for (var i = 0; i < n; i++) Rect.fromLTWH(left + i * (w + gap), top + math.sin(_clock * 1.6 + i * 1.7) * 5 + (i == 1 ? -h * .12 : 0), w, h)];
  }

  /// Where the balloons float: in the middle while Big Bonk is far up the
  /// path, under the top bar once he comes closer (never over him).
  double _balloonTarget(MdGame g) {
    final b = g.boss;
    final high = _pad.top + 74;
    if (b == null) return high;
    final box = _box(b);
    return box.feet.dy > _mf.screen.height * .5 ? high : math.max(box.feet.dy + 24, _mf.screen.height * .42);
  }

  /// The picture of [m] this frame, and how it moves.
  (String, Matrix4) _pose(MdMonster m, double h, bool frozen) {
    var pose = 'walk_a';
    var dx = 0.0, dy = 0.0, sx = 1.0, sy = 1.0, rot = 0.0;
    final t = m.moodTime;
    switch (m.mood) {
      case MdMood.walking:
        if (frozen) break;
        final a = m.age;
        switch (m.kind) {
          case MdKind.gloop:
            final ph = a / .52 * 2 * math.pi;
            pose = math.sin(ph) >= 0 ? 'walk_a' : 'walk_b';
            sy = 1 + .05 * math.sin(2 * ph);
            sx = 1 - .035 * math.sin(2 * ph);
          case MdKind.fuzz:
            final ph = a / .44 * math.pi;
            final up = math.sin(ph).abs();
            pose = up > .45 ? 'walk_b' : 'walk_a';
            dy = -up * h * .16;
            sy = up < .15 ? .92 : 1.0;
            sx = up < .15 ? 1.06 : 1.0;
          case MdKind.bonk || MdKind.boss:
            final ph = a / (m.kind == MdKind.boss ? .8 : .64) * 2 * math.pi;
            pose = math.sin(ph) >= 0 ? 'walk_a' : 'walk_b';
            dy = -math.sin(ph).abs() * h * .025;
            rot = math.sin(ph) * .03;
            if (m.kind == MdKind.boss && a < .55) {
              // Big Bonk jumps down from the cave and lands with a thump
              final f = 1 - a / .55;
              pose = 'roar';
              dy = -f * f * h * 1.6;
              sy = a > .45 ? .9 : 1;
              sx = a > .45 ? 1.08 : 1;
            }
          case MdKind.boo:
            pose = math.cos(a * 1.9 + m.id) < 0 ? 'walk_a' : 'walk_b';
            dy = math.sin(a * 3) * h * .05 - h * .06;
            rot = math.cos(a * 1.9 + m.id) * .08;
        }
      case MdMood.roaring:
        pose = 'roar';
        dx = math.sin(t * 50) * 3 * (1 - t / .7).clamp(0.0, 1.0);
        sx = sy = 1 + .06 * math.sin(math.min(1, t / .15) * math.pi / 2);
      case MdMood.cracked:
        pose = 'bonked';
        rot = math.sin(t * 13) * .14 * (1 - t).clamp(0.0, 1.0);
      case MdMood.trapped:
        pose = 'surprised';
        rot = math.sin(t * 5) * .05;
      case MdMood.friendly:
        pose = 'friendly';
        if (t > .45) dy = -math.sin((t - .45) * 9).abs() * h * .05;
      case MdMood.fleeing:
        pose = 'surprised';
        dy = -math.sin(t * 14).abs() * h * .05;
      case MdMood.gone:
        break;
    }
    final m4 = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..rotateZ(rot)
      ..scaleByDouble(sx, sy, 1, 1);
    return (MdArt.pose(m.kind, pose), m4);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    _pad = pad;
    _best = ref.watch(myGamesProvider)[GameIds.monsters]?.best ?? 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: LikhoColors.clear),
      child: Material(
        color: LikhoColors.background,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            _mf = MdFrame(size);
            _pencilH = (size.height * .16).clamp(96.0, 170.0);
            final g = _game;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _tapScene,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _scene(size)),
                  ),
                ),
                if (g != null) ...[
                  Positioned(
                    top: pad.top + 8,
                    left: 12,
                    right: 12,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _hud(g)),
                  ),
                  Positioned(
                    right: 12,
                    bottom: pad.bottom + 14,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _powers(g)),
                  ),
                  // before and after the game, Pencil and his bubble stay over the card's veil
                  if (!_started) Positioned.fill(child: _StartCard(best: _best, onPlay: _play, onBack: _exit)),
                  if (_started && _showResult)
                    Positioned.fill(
                      child: _ResultCard(won: g.phase == MdPhase.won, stars: g.stars, score: g.score, record: _record, onAgain: _again, onDone: _exit),
                    ),
                ],
                Positioned(
                  left: 2,
                  bottom: pad.bottom + 2,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (context, _, child) => DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [if ((g?.doubled ?? 0) > 0) BoxShadow(color: MonsterColors.magicGlow, blurRadius: 30 + 8 * math.sin(_clock * 5), spreadRadius: 4)],
                      ),
                      child: child,
                    ),
                    child: IgnorePointer(
                      child: PencilMascot(controller: _pencil, size: _pencilH),
                    ),
                  ),
                ),
                if (g != null) ...[
                  Positioned(
                    left: 8,
                    bottom: pad.bottom + _pencilH * .97 + 4,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _frame,
                      builder: (context, _, _) => _QuestionBubble(
                        key: const ValueKey('md-bubble'),
                        question: _started ? g.question : null,
                        caption: _caption,
                        maxWidth: math.min(152, size.width * .4),
                        onReplay: _replay,
                      ),
                    ),
                  ),
                  if (_started) Positioned.fill(child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _overlay(g, size))),
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

  Widget _scene(Size size) {
    final g = _game;
    final o = _mf.origin, bg = _mf.size;
    final shake = Offset(math.sin(_clock * 61) * _shake, math.cos(_clock * 47) * _shake * .6);
    final sunset = g != null && (g.wave >= 2 || g.isBoss);
    final kids = <Widget>[
      Positioned(
        left: o.dx,
        top: o.dy,
        width: bg.width,
        height: bg.height,
        child: Image.asset(MdArt.day, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium),
      ),
      Positioned(
        left: o.dx,
        top: o.dy,
        width: bg.width,
        height: bg.height,
        child: AnimatedOpacity(
          opacity: sunset ? 1 : 0,
          duration: const Duration(milliseconds: 1600),
          child: Image.asset(MdArt.sunset, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium),
        ),
      ),
    ];
    final bubbles = <(Offset, double, double, int)>[];
    if (g != null) {
      final frozen = g.frozen > 0;
      final shown = [
        for (final m in g.monsters)
          if (m.u >= 0 || m.mood == MdMood.fleeing) (m, _box(m)),
      ]..sort((a, b) => a.$2.feet.dy.compareTo(b.$2.feet.dy));
      final target = g.question?.answer;
      final pointAt = _firstPlay && g.caught == 0 && g.misses == 0 && _clock - _questionAt > 3.5 && !g.isBoss;
      final signs = <Widget>[]; // over every monster, so a nearer one never hides a sign
      for (final (m, b) in shown) {
        if (b.alpha <= 0) continue;
        final h = b.rect.height;
        final rise = b.feet.dy - b.rect.bottom;
        // shadow
        kids.add(
          Positioned(
            left: b.feet.dx - b.rect.width * .32,
            top: b.feet.dy - h * .05,
            width: b.rect.width * .64,
            height: h * .1,
            child: Opacity(
              opacity: b.alpha * (1 - (rise / (_mf.screen.height * .2)).clamp(0.0, .8)),
              child: const DecoratedBox(
                decoration: BoxDecoration(color: MonsterColors.shadow, borderRadius: BorderRadius.all(Radius.elliptical(100, 30))),
              ),
            ),
          ),
        );
        final (pose, m4) = _pose(m, h, frozen);
        Widget body = Image.asset(pose, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium);
        if (frozen && m.mood == MdMood.walking) body = ColorFiltered(colorFilter: const ColorFilter.mode(MonsterColors.ice, BlendMode.srcATop), child: body);
        kids.add(
          Positioned.fromRect(
            rect: b.rect,
            child: Opacity(
              opacity: b.alpha * (m.kind == MdKind.boo ? .94 : 1),
              child: Transform(transform: m4, alignment: Alignment.bottomCenter, child: body),
            ),
          ),
        );
        if (m.kind == MdKind.boss && m.mood != MdMood.friendly) {
          // his crown (it falls off when he is caught)
          final cw = b.rect.width * .42;
          kids.add(
            Positioned(
              left: b.rect.center.dx - cw / 2 + b.rect.width * .03,
              top: b.rect.top - cw * .42,
              width: cw,
              height: cw * .72,
              child: Transform.rotate(
                angle: -.12 + (m.mood == MdMood.cracked ? math.sin(m.moodTime * 13) * .2 : 0),
                child: const CustomPaint(painter: MdCrownPainter()),
              ),
            ),
          );
        }
        if (m.mood == MdMood.trapped) {
          final formed = ((m.moodTime - MdBeam.fly) / .3).clamp(0.0, 1.0);
          bubbles.add((b.rect.center, math.max(b.rect.width, b.rect.height) * .64, formed, m.id));
        }
        // the sign with its letter or word
        final signed = m.kind != MdKind.boss && (m.mood == MdMood.walking || m.mood == MdMood.roaring || m.mood == MdMood.cracked) && m.label.isNotEmpty;
        if (signed) {
          final glow = g.hint && m.label == target ? .6 + .4 * math.sin(_clock * 8) : 0.0;
          final s = (.5 + .55 * MdPath.depth((b.feet.dy - _mf.origin.dy) / _mf.size.height)).clamp(.55, 1.1);
          signs.add(
            Positioned(
              left: b.rect.center.dx,
              // over its head, but never under the top bar
              top: math.max(b.rect.top + (m.kind == MdKind.fuzz ? -h * .06 : 0), _pad.top + 66 + 44 * s),
              child: FractionalTranslation(
                translation: const Offset(-.5, -1),
                child: Opacity(
                  opacity: b.alpha,
                  child: _Sign(key: ValueKey('md-sign-${m.label}'), label: m.label, scale: s, glow: glow),
                ),
              ),
            ),
          );
          if (pointAt && m.label == target && m.mood == MdMood.walking && m.u > .12) {
            signs.add(
              Positioned(
                left: b.rect.center.dx + 6,
                top: b.rect.top - 10 + math.sin(_clock * 6).abs() * 10,
                child: const IgnorePointer(
                  child: Icon(
                    Symbols.touch_app_rounded,
                    size: 46,
                    fill: 1,
                    color: LikhoColors.surface,
                    shadows: [Shadow(color: MonsterColors.panelShadow, blurRadius: 8)],
                  ),
                ),
              ),
            );
          }
        }
      }
      kids.addAll(signs);
      // Big Bonk's balloons
      final boss = g.boss;
      final rects = _balloonRects(g);
      for (var i = 0; i < rects.length && boss != null; i++) {
        final r = rects[i];
        final bossBox = _box(boss);
        final glow = g.hint && g.balloons[i] == target ? .6 + .4 * math.sin(_clock * 8) : 0.0;
        final label = g.balloons[i];
        kids.add(
          Positioned.fromRect(
            key: ValueKey('md-balloon-$label'),
            rect: r,
            child: CustomPaint(
              painter: MdBalloonPainter(
                color: MonsterColors.balloons[i % 3],
                edge: MonsterColors.balloonEdge[i % 3],
                // strings down to his hands while the balloons are over him
                string: r.bottom < bossBox.rect.top ? bossBox.rect.topCenter + Offset((i - 1) * bossBox.rect.width * .2, bossBox.rect.height * .12) - r.topLeft : null,
                glow: glow,
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: r.height * .14),
                child: Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        label,
                        style: LikhoFonts.letter(size: label.length > 1 ? 26 : 38, color: LikhoColors.surface).copyWith(
                          height: 1,
                          shadows: const [Shadow(color: MonsterColors.panelShadow, offset: Offset(0, 2))],
                        ),
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
    kids
      ..add(
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: MdEffectsPainter(bits: _bits, beams: _beams, bubbles: bubbles, time: _clock),
            ),
          ),
        ),
      )
      ..add(
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: MdFrostPainter(_frost))),
        ),
      )
      ..add(
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: MdDangerPainter(_danger))),
        ),
      );
    return ClipRect(
      child: Transform.translate(
        offset: shake,
        child: Stack(clipBehavior: Clip.none, children: kids),
      ),
    );
  }

  Widget _hud(MdGame g) {
    final waves = g.waves.length;
    return Row(
      children: [
        PushButton(
          key: const ValueKey('md-pause'),
          onTap: _started ? _pause : _exit,
          color: MonsterColors.panel,
          width: 46,
          height: 46,
          shape: const CircleBorder(),
          shadows: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 3), blurRadius: 6)],
          child: Icon(_started ? Symbols.pause_rounded : Symbols.arrow_back_rounded, size: 26, weight: 700, fill: 1, color: LikhoColors.ink),
        ),
        const SizedBox(width: 8),
        _Pill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var k = 0; k < MdGame.hearts0; k++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AnimatedScale(
                    scale: k < g.hearts ? 1 : .78,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Opacity(opacity: k < g.hearts ? 1 : .28, child: Image.asset(MdArt.prop('heart'), width: 26, height: 24)),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Flexible(
          flex: 6,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var w = 0; w <= waves; w++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: w == waves
                          ? Icon(Symbols.crown_rounded, size: 20, fill: 1, color: g.wave >= waves ? MonsterColors.bossRibbon : GameColors.ink35)
                          : AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: w == g.wave ? 18 : 10,
                              height: 10,
                              decoration: BoxDecoration(color: w < g.wave ? LikhoColors.success : (w == g.wave ? MonsterColors.ribbon : GameColors.ink15), borderRadius: BorderRadius.circular(5)),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        _Pill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(MdArt.prop('star'), width: 24, height: 24),
              const SizedBox(width: 5),
              Text(
                '${_shownScore.round()}',
                key: const ValueKey('md-score'),
                style: LikhoFonts.title(size: 20, weight: FontWeight.w800).copyWith(height: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _powers(MdGame g) {
    final playing = g.phase == MdPhase.playing && !_paused;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (g.potions > 0 || g.doubled > 0)
          _PowerButton(key: const ValueKey('md-potion'), asset: MdArt.prop('potion'), count: g.potions, active: g.doubled > 0, time: _clock, onTap: playing ? () => g.usePotion() : null),
        if ((g.potions > 0 || g.doubled > 0) && (g.freezes > 0 || g.frozen > 0)) const SizedBox(height: 10),
        if (g.freezes > 0 || g.frozen > 0)
          _PowerButton(key: const ValueKey('md-freeze'), asset: MdArt.prop('ice'), count: g.freezes, active: g.frozen > 0, time: _clock, onTap: playing ? () => g.useFreeze() : null),
      ],
    );
  }

  Widget _overlay(MdGame g, Size size) {
    if (_paused) return _PauseCard(onResume: _resume, onExit: _exit);
    if (_showResult) return const SizedBox.shrink();
    if (g.phase == MdPhase.banner) {
      return IgnorePointer(
        child: _Banner(title: 'Wave ${g.wave + 1}', sub: g.wave == 0 ? 'Get ready!' : 'Here they come!', t: g.phaseTime, total: MdGame.bannerTime),
      );
    }
    if (g.phase == MdPhase.bossIntro) return IgnorePointer(child: _BossIntro(t: g.phaseTime, clock: _clock));
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------- pieces

/// The sign over a monster's head: its letter or word.
class _Sign extends StatelessWidget {
  const _Sign({super.key, required this.label, required this.scale, required this.glow});
  final String label;
  final double scale, glow;

  @override
  Widget build(BuildContext context) {
    final s = scale * (1 + .12 * glow);
    return Container(
      padding: EdgeInsets.fromLTRB(11 * s, 1 * s, 11 * s, 3 * s),
      margin: EdgeInsets.only(bottom: 4 * s),
      decoration: BoxDecoration(
        color: MonsterColors.sign,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: glow > 0 ? MonsterColors.gold : MonsterColors.signEdge, width: 2.6 * s),
        boxShadow: [
          const BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 3), blurRadius: 4),
          if (glow > 0) BoxShadow(color: MonsterColors.hintGlow.withValues(alpha: glow), blurRadius: 18, spreadRadius: 3),
        ],
      ),
      child: Text(
        label,
        style: LikhoFonts.letter(size: (label.length > 1 ? 24 : 32) * s, color: MonsterColors.signInk).copyWith(height: 1.15),
      ),
    );
  }
}

/// A white rounded box in the top bar.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: MonsterColors.panel,
      borderRadius: BorderRadius.circular(21),
      boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 3), blurRadius: 6)],
    ),
    child: Align(widthFactor: 1, child: child),
  );
}

/// Pencil's bubble: the question (its letter or picture, what he says, a
/// button to hear it again), or what he is saying now.
class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({super.key, required this.question, required this.caption, required this.maxWidth, required this.onReplay});
  final MdQuestion? question;
  final String? caption;
  final double maxWidth;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final Widget content;
    if (caption != null) {
      content = Text(
        caption!,
        key: ValueKey(caption),
        style: LikhoFonts.title(size: caption!.length > 60 ? 15 : 18, weight: FontWeight.w800).copyWith(height: 1.2),
      );
    } else if (q != null) {
      content = Column(
        key: ValueKey(q),
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (q.picture != null)
                Image.asset(q.picture!, width: 74, height: 74, fit: BoxFit.contain)
              else
                Text(q.letter ?? '', style: LikhoFonts.letter(size: 60, color: MonsterColors.ribbonDeep).copyWith(height: 1.05)),
              if (q.skill == MdSkill.smalls) ...[
                const SizedBox(width: 4),
                const Icon(Symbols.arrow_forward_rounded, size: 22, weight: 700, color: GameColors.ink35),
                Text('?', style: LikhoFonts.letter(size: 40, color: GameColors.ink35).copyWith(height: 1.05)),
              ],
              if (q.skill == MdSkill.firstSound) Text(' ?', style: LikhoFonts.letter(size: 36, color: GameColors.ink35).copyWith(height: 1.05)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  q.say,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LikhoFonts.title(size: 15, weight: FontWeight.w800).copyWith(height: 1.15),
                ),
              ),
              const SizedBox(width: 6),
              PushButton(
                key: const ValueKey('md-replay'),
                onTap: onReplay,
                color: LikhoColors.secondary,
                edgeColor: GameColors.secondaryDeep,
                edge: 3,
                width: 34,
                height: 34,
                shape: const CircleBorder(),
                child: const Icon(Symbols.volume_up_rounded, size: 20, fill: 1, color: LikhoColors.surface),
              ),
            ],
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: CustomPaint(
        painter: const _Tail(),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
          decoration: BoxDecoration(
            color: MonsterColors.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 5), blurRadius: 12)],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: Tween(begin: .85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _Tail extends CustomPainter {
  const _Tail();

  @override
  void paint(Canvas canvas, Size size) {
    const x = 46.0;
    canvas.drawPath(
      Path()
        ..moveTo(x - 11, size.height - 12)
        ..lineTo(x + 11, size.height - 12)
        ..lineTo(x - 4, size.height)
        ..close(),
      Paint()..color = MonsterColors.card,
    );
  }

  @override
  bool shouldRepaint(_Tail old) => false;
}

/// A power-up waiting to be tapped (it wiggles), or working (it glows).
class _PowerButton extends StatelessWidget {
  const _PowerButton({super.key, required this.asset, required this.count, required this.active, required this.time, required this.onTap});
  final String asset;
  final int count;
  final bool active;
  final double time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: active ? 0 : math.sin(time * 6) * .08,
    child: PushButton(
      onTap: count > 0 && !active ? onTap : null,
      color: active ? MonsterColors.ribbon : MonsterColors.panel,
      edgeColor: active ? MonsterColors.ribbonDeep : GameColors.ink15,
      edge: 4,
      width: 66,
      height: 66,
      shape: const CircleBorder(),
      shadows: [BoxShadow(color: active ? MonsterColors.magicGlow : MonsterColors.panelShadow, blurRadius: active ? 18 : 8, offset: const Offset(0, 3))],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Image.asset(asset, width: 42, height: 42),
          if (count > 1)
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: LikhoColors.hint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LikhoColors.surface, width: 2),
                ),
                child: Text(
                  '$count',
                  style: LikhoFonts.title(size: 13, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1.1),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// "Wave 2": a ribbon that springs in and out.
class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.sub, required this.t, required this.total});
  final String title, sub;
  final double t, total;

  @override
  Widget build(BuildContext context) {
    final inV = Curves.elasticOut.transform((t / .7).clamp(0.0, 1.0));
    final out = ((t - (total - .35)) / .35).clamp(0.0, 1.0);
    return Center(
      child: Opacity(
        opacity: 1 - out,
        child: Transform.scale(
          scale: (.4 + .6 * inV) * (1 - .2 * out),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(34, 8, 34, 12),
                decoration: BoxDecoration(
                  color: MonsterColors.ribbon,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(color: MonsterColors.ribbonDeep, offset: Offset(0, 6)),
                    BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 10), blurRadius: 18),
                  ],
                ),
                child: Text(
                  title,
                  style: LikhoFonts.title(size: 44, weight: FontWeight.w800, color: MonsterColors.ribbonInk).copyWith(height: 1.1),
                ),
              ),
              const SizedBox(height: 12),
              _Pill(
                child: Text(sub, style: LikhoFonts.title(size: 20, weight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big Bonk arrives: his picture stomps in with his crown, and his name.
class _BossIntro extends StatelessWidget {
  const _BossIntro({required this.t, required this.clock});
  final double t, clock;

  @override
  Widget build(BuildContext context) {
    final inV = Curves.elasticOut.transform((t / .9).clamp(0.0, 1.0));
    final out = ((t - (MdGame.bossIntroTime - .4)) / .4).clamp(0.0, 1.0);
    final roar = (t * 2.6).floor().isOdd;
    return ColoredBox(
      color: MonsterColors.veil.withValues(alpha: MonsterColors.veil.a * .6 * (1 - out)),
      child: Align(
        alignment: const Alignment(0, -.4),
        child: Opacity(
          opacity: 1 - out,
          child: Transform.scale(
            scale: .3 + .7 * inV,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  height: 250,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(left: 0, right: 0, bottom: 0, height: 220, child: Image.asset(MdArt.pose(MdKind.boss, roar ? 'roar' : 'walk_a'), fit: BoxFit.contain)),
                      Positioned(
                        left: 76,
                        top: 0 + math.sin(clock * 9) * 3,
                        width: 82,
                        height: 60,
                        child: Transform.rotate(angle: -.12, child: const CustomPaint(painter: MdCrownPainter())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(30, 6, 30, 10),
                  decoration: BoxDecoration(
                    color: MonsterColors.bossRibbon,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: MonsterColors.bossRibbonDeep, offset: Offset(0, 6))],
                  ),
                  child: Text(
                    'Big Bonk!',
                    style: LikhoFonts.title(size: 40, weight: FontWeight.w800, color: MonsterColors.ribbonInk).copyWith(height: 1.1),
                  ),
                ),
                const SizedBox(height: 10),
                _Pill(
                  child: Text('Catch him 3 times!', style: LikhoFonts.title(size: 19, weight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card over the dimmed game.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.alignment = Alignment.center});
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MonsterColors.veil,
    child: SafeArea(
      child: Align(
        alignment: alignment,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .8, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 330,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: MonsterColors.card,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 10), blurRadius: 24)],
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Widget _bigButton({required Key key, required String label, required IconData icon, required VoidCallback onTap, bool main = true}) => PushButton(
  key: key,
  onTap: onTap,
  color: main ? LikhoColors.success : MonsterColors.panel,
  edgeColor: main ? GameColors.successDeep : GameColors.ink15,
  edge: 5,
  height: 58,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  innerHighlight: main,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 28, fill: 1, weight: 700, color: main ? LikhoColors.surface : LikhoColors.ink),
      const SizedBox(width: 6),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: LikhoFonts.title(size: 22, weight: FontWeight.w800, color: main ? LikhoColors.surface : LikhoColors.ink),
          ),
        ),
      ),
    ],
  ),
);

/// Before the game: its picture, the child's best score, Play.
class _StartCard extends StatelessWidget {
  const _StartCard({required this.best, required this.onPlay, required this.onBack});
  final int best;
  final VoidCallback onPlay, onBack;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      _Card(
        // high, so Pencil can introduce the game below it
        alignment: const Alignment(0, -.55),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(MdArt.cover, width: 260, height: 200, fit: BoxFit.cover, alignment: const Alignment(0, -.1)),
            ),
            const SizedBox(height: 12),
            Text('Monster Defense', style: LikhoFonts.title(size: 30, weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              best > 0 ? 'Your best: $best' : 'Catch the silly monsters!',
              style: LikhoFonts.body(size: 16, weight: FontWeight.w800, color: StoryColors.name),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _bigButton(key: const ValueKey('md-play'), label: 'Play', icon: Symbols.play_arrow_rounded, onTap: onPlay),
            ),
          ],
        ),
      ),
      Positioned(
        left: 12,
        top: MediaQuery.paddingOf(context).top + 8,
        child: PushButton(
          key: const ValueKey('md-back'),
          onTap: onBack,
          color: MonsterColors.panel,
          width: 46,
          height: 46,
          shape: const CircleBorder(),
          child: const Icon(Symbols.arrow_back_rounded, size: 26, weight: 700, color: LikhoColors.ink),
        ),
      ),
    ],
  );
}

class _PauseCard extends StatelessWidget {
  const _PauseCard({required this.onResume, required this.onExit});
  final VoidCallback onResume, onExit;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(MdArt.pose(MdKind.boo, 'surprised'), height: 110),
        const SizedBox(height: 8),
        Text('Paused', style: LikhoFonts.title(size: 32, weight: FontWeight.w800)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _bigButton(key: const ValueKey('md-resume'), label: 'Keep playing', icon: Symbols.play_arrow_rounded, onTap: onResume),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _bigButton(key: const ValueKey('md-exit'), label: 'Stop', icon: Symbols.home_rounded, onTap: onExit, main: false),
        ),
      ],
    ),
  );
}

/// The end: won (the open chest, stars) or not this time (a friendly
/// monster); the score, a new best, Play again.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.won, required this.stars, required this.score, required this.record, required this.onAgain, required this.onDone});
  final bool won, record;
  final int stars, score;
  final VoidCallback onAgain, onDone;

  @override
  Widget build(BuildContext context) => _Card(
    // high, so Pencil's words show below it
    alignment: const Alignment(0, -.75),
    child: Column(
      key: const ValueKey('md-result'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(won ? MdArt.prop('chest_open') : MdArt.pose(MdKind.gloop, 'friendly'), height: 120),
        const SizedBox(height: 6),
        Text(won ? 'You did it!' : 'Good try!', style: LikhoFonts.title(size: 32, weight: FontWeight.w800)),
        if (won) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var k = 1; k <= 3; k++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 400 + k * 250),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: stars >= k ? 1 : .25,
                      child: Image.asset(MdArt.prop('star'), width: k == 2 ? 54 : 44),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '$score points',
          style: LikhoFonts.title(size: 22, weight: FontWeight.w800, color: StoryColors.name),
        ),
        if (record) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            decoration: BoxDecoration(color: MonsterColors.ribbon, borderRadius: BorderRadius.circular(14)),
            child: Text(
              'New best!',
              style: LikhoFonts.title(size: 18, weight: FontWeight.w800, color: MonsterColors.ribbonInk),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _bigButton(key: const ValueKey('md-again'), label: 'Play again', icon: Symbols.replay_rounded, onTap: onAgain),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _bigButton(key: const ValueKey('md-done'), label: 'Map', icon: Symbols.map_rounded, onTap: onDone, main: false),
        ),
      ],
    ),
  );
}
