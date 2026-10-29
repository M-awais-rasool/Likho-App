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
import '../game_ui.dart';
import 'md_bodies.dart';
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
  const MonsterDefenseScreen({super.key, required this.onDone, this.random, this.questions, this.waves});
  final VoidCallback onDone;

  /// Tests: fixed dice and questions.
  final math.Random? random;
  final MdQuestionSource? questions;
  final List<MdWave>? waves;

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
  final _phases = <int, double>{}; // each monster's walk phase last frame (its steps)

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
    MdSprites.load(createLocalImageConfiguration(context));
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
      _game = MdGame(questions: q!, random: _rnd, waves: widget.waves);
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
      _dust(g);
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
        _bits.add(MdBit.score(_seen(m, box.rect, 'surprised').topCenter + const Offset(0, -10), e.value));
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
        _bits.addAll(MdBit.burst(_seen(m, box.rect, 'surprised').center, _rnd, n: m.kind == MdKind.boss ? 26 : 16));
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

  /// Puffs of sand where feet land: each step of Gloop and Bonk (Big
  /// Bonk's shake the ground), each landing of Fuzz.
  void _dust(MdGame g) {
    for (final m in g.monsters) {
      final was = _phases[m.id];
      final now = m.phase;
      _phases[m.id] = now;
      if (was == null || m.mood != MdMood.walking || g.frozen > 0 || m.u < .02 || m.kind == MdKind.boo) continue;
      final landed = switch (m.kind) {
        MdKind.fuzz => was > .8 && now < .2, // back on the ground
        _ => (was < .5 && now >= .5) || (was > .9 && now < .1),
      };
      if (!landed) continue;
      final b = _box(m);
      final big = m.kind == MdKind.boss || m.kind == MdKind.bonk;
      _bits.addAll(MdBit.dust(b.feet, b.rect.width * (m.kind == MdKind.boss ? .26 : (big ? .3 : .24)), _rnd, n: big ? 4 : 3));
      if (m.kind == MdKind.boss) _shake = math.max(_shake, 3);
    }
    _phases.removeWhere((id, _) => !g.monsters.any((m) => m.id == id));
  }

  /// Where the monster itself is in its pose's frame [rect] (see MdArt.content).
  Rect _seen(MdMonster m, Rect rect, [String pose = 'walk_a']) => MdArt.content(MdArt.pose(m.kind, pose), rect);

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
    _beams.add(MdBeam(_hand, _seen(m, _box(m).rect, 'surprised').center));
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
      _game = MdGame(questions: q, random: _rnd, waves: widget.waves);
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
      final body = _seen(m, b.rect);
      var r = body.expandToInclude(Rect.fromCenter(center: body.topCenter, width: 60, height: 50));
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
        final from = boss ? .9 : .5, len = boss ? 1.6 : .85;
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
    if (m.u < 0 && m.mood != MdMood.fleeing) {
      alpha = 0;
    } else if (m.outTime < .12) {
      alpha = m.outTime / .12; // it pops out of the dark cave
    }
    if (m.u < 0 && m.mood == MdMood.fleeing) alpha = 0;
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

  /// The picture of [m] this frame, and how its body bends (see
  /// [MdBodiesPainter]): a real walk for each monster, built from one
  /// drawing so it never flickers.
  MdMotion _motion(MdMonster m, double h, bool frozen) {
    final t = m.moodTime;
    final pose = switch (m.mood) {
      MdMood.walking => 'walk_a',
      MdMood.roaring => 'roar',
      MdMood.cracked => 'bonked',
      MdMood.trapped || MdMood.fleeing => 'surprised',
      MdMood.friendly => 'friendly',
      MdMood.gone => 'walk_a',
    };
    final mo = MdMotion(MdArt.pose(m.kind, pose))..frozen = frozen && m.mood == MdMood.walking;
    // a quick pop into a new pose
    if (m.mood != MdMood.walking && t < .16) mo.punch = 1 + .14 * math.sin(t / .16 * math.pi);
    switch (m.mood) {
      case MdMood.walking:
        if (frozen) break;
        _walk(m, h, mo);
      case MdMood.roaring:
        // up on its toes, shaking with the roar
        final k = math.exp(-t * 4);
        mo
          ..sy = 1 + .14 * k
          ..sx = 1 + .08 * k
          ..dx = math.sin(t * 46) * h * .025 * (1 - t / .7).clamp(0.0, 1.0)
          ..sway = math.sin(t * 23) * .04 * k;
      case MdMood.cracked:
        mo
          ..rot = math.sin(t * 13) * .16 * (1 - t).clamp(0.0, 1.0)
          ..sway = math.sin(t * 9) * .06 * (1 - t).clamp(0.0, 1.0)
          ..sy = 1 - .1 * math.exp(-t * 6);
      case MdMood.trapped:
        mo
          ..rot = math.sin(t * 5) * .06
          ..sx = 1 + .04 * math.sin(t * 7)
          ..sy = 1 - .04 * math.sin(t * 7)
          // the magic lands: a white flash and a squash
          ..flash = t > MdBeam.fly - .02 && t < MdBeam.fly + .16 ? 1 - (t - MdBeam.fly + .02) / .18 : 0;
        if (mo.flash > 0) mo.sy *= 1 - .12 * mo.flash;
      case MdMood.friendly:
        if (t > .45) {
          // landed: little happy hops
          final ph = (t - .45) * 8;
          mo
            ..dy = -math.sin(ph).abs() * h * .08
            ..sy = math.sin(ph).abs() < .2 ? .92 : 1.04
            ..sway = math.sin(ph * .5) * .05;
        } else {
          mo.sy = 1.08; // falling, stretched
        }
      case MdMood.fleeing:
        // running back to the cave, quick and scared
        final ph = t * 15;
        mo
          ..dy = -math.sin(ph).abs() * h * .09
          ..stepL = math.max(0, math.sin(ph))
          ..stepR = math.max(0, -math.sin(ph))
          ..rot = math.sin(ph) * .06;
      case MdMood.gone:
        break;
    }
    // out of the cave with a jump
    if (m.outTime < .5 && m.mood == MdMood.walking && m.kind != MdKind.boss) {
      final k = m.outTime / .5;
      mo
        ..dy += -math.sin(k * math.pi) * h * .45
        ..punch *= .7 + .3 * Curves.easeOutBack.transform(k);
    }
    return mo;
  }

  /// A walk: Gloop wobbles like jelly, Fuzz hops (crouch, jump, land), Bonk
  /// stomps heavily, Boo floats with a waving hem; each leans into the way
  /// the path goes.
  void _walk(MdMonster m, double h, MdMotion mo) {
    final p = m.phase, ph = 2 * math.pi * p;
    // lean into the way it walks on the screen (the path's direction)
    final dir = MdPath.shared.direction(m.u.clamp(0.0, 1.0));
    final lean = (dir.dx * .07).clamp(-.07, .07);
    switch (m.kind) {
      case MdKind.gloop:
        final step = math.sin(ph);
        mo
          ..stepL = math.max(0, step)
          ..stepR = math.max(0, -step)
          ..sy = 1 - .06 * math.cos(2 * ph) // squashed as a foot lands, tall mid-step
          ..sx = 1 + .07 * math.cos(2 * ph)
          ..dy = -h * .035 * step.abs()
          ..sway = lean + .05 * math.sin(ph - .7) // the jelly top lags behind
          ..rot = .045 * step;
      case MdKind.fuzz:
        if (p < Hop.ground) {
          // crouched, ready to jump (squashed), then landing
          final k = math.sin(p / Hop.ground * math.pi);
          mo
            ..sy = 1 - .17 * k
            ..sx = 1 + .14 * k;
        } else {
          final k = (p - Hop.ground) / (1 - Hop.ground);
          final up = math.sin(k * math.pi);
          mo.pose = MdArt.pose(m.kind, up > .35 ? 'walk_b' : 'walk_a');
          mo
            ..dy = -up * h * .22
            ..sy = 1 + .1 * math.cos(k * math.pi).clamp(0.0, 1.0)
            ..sx = 1 - .05 * math.cos(k * math.pi).clamp(0.0, 1.0)
            ..rot = lean * 1.5 * math.sin(k * 2 * math.pi);
        }
        mo.sway += lean;
      case MdKind.bonk || MdKind.boss:
        final step = math.sin(ph);
        mo
          ..stepL = math.max(0, step)
          ..stepR = math.max(0, -step)
          ..dy = -h * .02 * step.abs()
          ..rot = .07 * step // heavy side-to-side rock
          ..sy = 1 - .035 * math.cos(2 * ph)
          ..sx = 1 + .03 * math.cos(2 * ph)
          ..sway = lean * .6;
        if (m.kind == MdKind.boss && m.outTime < .6) {
          // Big Bonk jumps down from the cave and lands with a thump
          final f = 1 - m.outTime / .6;
          mo
            ..dy = -f * f * h * 1.4
            ..stepL = 0
            ..stepR = 0
            ..rot = 0
            ..sy = m.outTime > .5 ? .86 : 1.06;
          mo.pose = MdArt.pose(m.kind, 'roar');
        }
      case MdKind.boo:
        mo
          ..dy = -h * .1 + math.sin(m.walk * 2.6) * h * .05
          ..hem = .035
          ..sway = lean + .05 * math.sin(m.walk * 1.3)
          ..rot = math.cos(m.age * 1.9 + m.id) * .1;
        mo.pose = MdArt.pose(m.kind, math.cos(m.age * 1.9 + m.id) < 0 ? 'walk_a' : 'walk_b');
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    _pad = pad;
    _best = ref.watch(myGamesProvider)[GameIds.monsters]?.best ?? 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LikhoSystemBars.dark,
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
                  if (!_started) Positioned.fill(child: GameStartCard(id: 'md', title: 'Monster Defense', cover: MdArt.cover, hint: 'Catch the silly monsters!', best: _best, onPlay: _play, onBack: _exit)),
                  if (_started && _showResult)
                    Positioned.fill(
                      child: GameResultCard(
                        id: 'md',
                        picture: g.phase == MdPhase.won ? MdArt.prop('chest_open') : MdArt.pose(MdKind.gloop, 'friendly'),
                        title: g.phase == MdPhase.won ? 'You did it!' : 'Good try!',
                        star: MdArt.prop('star'),
                        stars: g.phase == MdPhase.won ? g.stars : null,
                        score: g.score,
                        record: _record,
                        onAgain: _again,
                        onDone: _exit,
                      ),
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
      final bodies = <MdBody>[];
      for (final (m, b) in shown) {
        if (b.alpha <= 0) continue;
        final h = b.rect.height;
        final motion = _motion(m, h, frozen);
        bodies.add((m: m, rect: b.rect, feet: b.feet, alpha: b.alpha * (m.kind == MdKind.boo ? .94 : 1), motion: motion));
        if (m.mood == MdMood.trapped) {
          final formed = ((m.moodTime - MdBeam.fly) / .3).clamp(0.0, 1.0);
          final body = _seen(m, b.rect, 'surprised');
          bubbles.add((body.center, math.max(body.width, body.height) * .68, formed, m.id));
        }
        // the sign with its letter or word
        final signed = m.kind != MdKind.boss && (m.mood == MdMood.walking || m.mood == MdMood.roaring || m.mood == MdMood.cracked) && m.label.isNotEmpty;
        if (signed) {
          final glow = g.hint && m.label == target ? .6 + .4 * math.sin(_clock * 8) : 0.0;
          // smaller far away, never bigger than the monster's head
          final s = (.3 + .55 * MdPath.depth((b.feet.dy - _mf.origin.dy) / _mf.size.height)).clamp(.55, .9);
          final mo = bodies.last.motion;
          final body = MdArt.content(mo.pose, b.rect);
          signs.add(
            Positioned(
              left: body.center.dx + mo.dx,
              // over its head, going up and down with it (less, so it stays
              // readable), but never under the top bar
              top: math.max(body.top - h * .02 + mo.dy * .6, _pad.top + 66 + 44 * s),
              child: FractionalTranslation(
                translation: const Offset(-.5, -1),
                child: Opacity(
                  opacity: b.alpha,
                  child: _Sign(key: ValueKey('md-sign-${m.label}'), label: m.label, scale: s, glow: glow),
                ),
              ),
            ),
          );
          if (pointAt && m.label == target && m.mood == MdMood.walking && m.u > .3) {
            // a finger beside its sign, tapping
            signs.add(
              Positioned(
                left: body.right - body.width * .15,
                top: body.top + body.height * .15 + math.sin(_clock * 6).abs() * 10,
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
      kids
        ..add(Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: MdBodiesPainter(bodies: bodies, time: _clock)))))
        ..addAll(signs);
      // Big Bonk's balloons
      final boss = g.boss;
      final rects = _balloonRects(g);
      for (var i = 0; i < rects.length && boss != null; i++) {
        final r = rects[i];
        final bossBody = _seen(boss, _box(boss).rect);
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
                string: r.bottom < bossBody.top ? bossBody.topCenter + Offset((i - 1) * bossBody.width * .25, bossBody.height * .2) - r.topLeft : null,
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
        GamePill(
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
            child: GamePill(
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
        GamePill(
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
    if (_paused) return GamePauseCard(id: 'md', picture: MdArt.pose(MdKind.boo, 'surprised'), onResume: _resume, onExit: _exit);
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
              GamePill(
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
                GamePill(
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





