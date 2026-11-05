import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
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
import '../../../game/monster_smash/ms_engine.dart';
import '../../../game/speech/prompt_voice.dart';
import '../../../mascot/mascot.dart';
import '../../gameplay/widgets/game_buttons.dart';
import '../game_ui.dart';
import '../monster_defense/md_effects.dart';
import 'ms_crystal_backdrop.dart';
import 'ms_camera.dart';
import 'ms_heroes.dart';
import 'ms_lines.dart';
import 'ms_monsters.dart';
import 'ms_painter.dart';
import 'ms_scene.dart';
import 'ms_start_card.dart';
import 'ms_ui.dart';

/// Monster Smash: played sideways, like Angry Birds 2. A level of one to
/// three rooms in a crystal sky that moves with the camera; the Stationery Squad
/// (Rubby, Inky, Crayo) waits in line beside the slingshot, and the cards
/// at the bottom pick who goes next. On the right the silly
/// monsters sit on towers of wood, ice and stone, some blocks with letters.
/// Pencil's voice asks for a letter, the child drags the hero back (dots
/// show where it will go) and lets go, taps while it flies for its power;
/// the block bursts, the tower falls and the monsters tumbling down turn
/// into friends. See [MsGame] for the rules.
class MonsterSmashScreen extends ConsumerStatefulWidget {
  const MonsterSmashScreen({super.key, required this.onDone, this.level, this.world = 'Letter Land', this.onNext, this.ownOrientation = true, this.asks, this.seed});

  /// Back to the levels (or the games).
  final VoidCallback onDone;

  /// The level; null plays the old three rooms (tests, the preview).
  final MsLevel? level;
  final String world;

  /// The next level (the result's big button); null for the last.
  final VoidCallback? onNext;

  /// Turns the screen sideways itself and back on the way out (not when
  /// the levels screen around it already did).
  final bool ownOrientation;

  /// Tests: fixed letters and dice.
  final MsAsks? asks;
  final int? seed;

  @override
  ConsumerState<MonsterSmashScreen> createState() => _MonsterSmashScreenState();
}

/// A word popping out of the world ("POW!", the letter that was hit).
class _Pop {
  _Pop(this.text, this.at, this.born, {this.color = SmashColors.pow, this.edge = SmashColors.powEdge, this.size = 44});
  final String text;
  final Offset at;
  final double born, size;
  final Color color, edge;
}

/// A hero resting a moment where it stopped, before it vanishes in a puff.
class _Rest {
  _Rest(this.hero, this.at, this.radius, this.born);
  final MsHero hero;
  final Vector2 at;
  final double radius, born;
}

class _MonsterSmashScreenState extends ConsumerState<MonsterSmashScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  late final math.Random _rnd = math.Random(widget.seed);
  late final AppFeedback _fb = ref.read(feedbackProvider);
  late final PromptVoice _voice = ref.read(promptVoiceProvider);
  late final bool _voiceOn = ref.read(voiceOnProvider);
  // Pencil's voice (he is not in this game: his words ask the letters)
  final _mascot = MascotController();
  late final _lives = MsMonsterLives(random: _rnd);
  late final MsLevel _level = widget.level ?? MsLevels.classic();

  MsGame? _game;
  MsAsks? _asks;

  /// The game (tests play it).
  @visibleForTesting
  MsGame? get debugGame => _game;
  Duration? _last;
  double _clock = 0;
  bool _started = false, _paused = false, _showResult = false, _record = false;
  int _best = 0, _levelStars = 0;

  // what Pencil says
  String? _caption;
  int _talkId = 0, _askId = 0, _great = 0;
  Future<void> _speaking = Future<void>.value();
  Completer<void>? _shown;
  Timer? _captionTimer;
  final _timers = <Timer>[];
  bool _pullHinted = false, _tapHinted = false;
  int _stretch = 0;

  // the heroes: the next one hopping into the slingshot, the line
  // cheering, the ones resting where they stopped
  bool _ballIn = false;
  double _ballInAt = -9, _cheerAt = -9, _bonusAt = -9;
  final _rests = <_Rest>[];
  double _bonkAt = -9;

  // effects
  final _bits = <MdBit>[];
  final _pops = <_Pop>[];
  double _shake = 0, _shownScore = 0, _clearedAt = -9;

  MsView? _view;
  MsCamera? _cam;
  EdgeInsets _pad = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    if (widget.ownOrientation) SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _voice;
    _voiceOn;
    _fb.prepare(Sfx.monsterSmash);
    _mascot.speakingListenable.addListener(_duck);
    _load();
  }

  /// The music goes quiet while Pencil talks.
  void _duck() => _fb.smashMusicQuiet(_mascot.speakingListenable.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MsSprites.load(createLocalImageConfiguration(context));
  }

  @override
  void dispose() {
    if (widget.ownOrientation) SystemChrome.setPreferredOrientations(const []);
    WidgetsBinding.instance.removeObserver(this);
    _captionTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _endCaption();
    _ticker.dispose();
    _frame.dispose();
    _voice.stop();
    _fb.smashMusic(false);
    _mascot.speakingListenable.removeListener(_duck);
    _mascot.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  Future<void> _load() async {
    var asks = widget.asks;
    if (asks == null) {
      final words = await MdWords.load();
      if (!mounted) return;
      final course = ref.read(courseProvider).value;
      final done = ref.read(progressProvider).levelStars.keys;
      asks = MsChildAsks(MdKnowledge.of(course, done), words, random: _rnd);
    }
    if (!mounted) return;
    setState(() {
      _asks = asks;
      _game = MsGame(asks: asks!, level: _level, seed: widget.seed);
    });
    final hero = _level.newHero;
    if (hero != null) _say(MsLines.meet(hero), hold: true);
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
      _hintPull(g);
      _hintTap(g);
      // the next hero hops into the slingshot
      final ready = g.phase == MsPhase.aim && g.heroes.isNotEmpty;
      if (ready && !_ballIn) _hop();
      _ballIn = ready;
      _lives.update(dt, g, giggle: _fb.giggle, eek: _fb.eek);
      _stretched(g);
      for (final b in _bits) {
        b.step(dt);
      }
      _bits.removeWhere((b) => b.done);
      _pops.removeWhere((p) => _clock - p.born > 1.2);
      _rests.removeWhere((r) => _clock - r.born > .6);
      _shake *= math.exp(-dt * 9);
      _shownScore += (g.score - _shownScore) * math.min(1, dt * 8);
      if ((g.score - _shownScore).abs() < .5) _shownScore = g.score.toDouble();
      final v = _view, cam = _cam;
      if (v != null && cam != null) _steer(g, v, cam, dt);
    }
    _mascot.advance(now);
    _frame.value++;
  }

  void _hop() {
    _fb.heroHop();
    _ballInAt = _clock;
  }

  /// The camera: the towers first, then the whole room; it follows the
  /// hero in the air, and comes back once things settle.
  void _steer(MsGame g, MsView v, MsCamera cam, double dt) {
    switch (g.phase) {
      case MsPhase.build when g.room == 0:
        if (g.phaseTime < 1.0) {
          cam.look(v.at(12.4, 2.6), 1.35);
        } else {
          cam.wide();
        }
      case MsPhase.flying:
        final s = g.shot;
        if (s != null && !s.gone) cam.look(v.of(s.body.position) + Offset(v.ppm * 2.2, 0), 1.28);
      case MsPhase.settle:
        if (g.phaseTime > .5) cam.wide();
      default:
        cam.wide();
    }
    cam.step(dt);
  }

  /// The band creaks tighter as the child pulls further.
  void _stretched(MsGame g) {
    final p = g.pull;
    if (p == null) {
      _stretch = 0;
      return;
    }
    final k = p.length / MsGame.maxPull;
    final level = k > .9 ? 3 : (k > .55 ? 2 : (k > .12 ? 1 : 0));
    if (level > _stretch) _fb.stretch(level);
    _stretch = level;
  }

  /// The first shot of a game: if the child waits, Pencil says how.
  void _hintPull(MsGame g) {
    if (_pullHinted || g.flings > 0 || g.phase != MsPhase.aim || g.pull != null || g.phaseTime < 7) return;
    _pullHinted = true;
    _say(MsLines.pullHint);
  }

  /// The level's new hero flies for the first time: "Tap now!".
  void _hintTap(MsGame g) {
    final s = g.shot;
    if (_tapHinted || s == null || s.hero != _level.newHero || s.volley.powered || s.volley.time < .25) return;
    _tapHinted = true;
    _say(MsLines.tap);
  }

  // ------------------------------------------------------------ what happened

  void _on(MsEvent e, MsGame g) {
    final v = _view;
    Offset at() => v == null ? Offset.zero : v.at(e.x, e.y);
    switch (e.kind) {
      case MsEventKind.build:
        _fb.whoosh();
        if (e.value == 0 && v != null) _cam?.snap(v.at(12.4, 2.6), 1.35);
      case MsEventKind.ask:
        _ask(e.ask!);
      case MsEventKind.grab:
        break;
      case MsEventKind.pick:
        _hop();
      case MsEventKind.launch:
        _fb.launch();
        _after(60, _fb.heroFlung);
      case MsEventKind.power:
        _fb.heroPower(e.text);
        _shake = math.max(_shake, 4);
        _bits.addAll(
          MdBit.burst(
            at(),
            _rnd,
            n: 14,
            speed: 220,
            colors: switch (e.text) {
              'inky' => const [HeroColors.lid, Color(0xFF4C7BEA), Color(0xFF7DA2F2)],
              'crayo' => const [Color(0xFFFF9A3C), Color(0xFFFFE07A), HeroColors.lid],
              _ => const [Color(0xFFFF8DAA), HeroColors.lid, Color(0xFFFFB3C6)],
            },
          ),
        );
      case MsEventKind.hit:
        _fb.pow();
        _shake = 9;
        _cheerAt = _clock;
        _pops.add(_Pop('${e.text}!', at(), _clock, color: LikhoColors.success, edge: GameColors.successDeep, size: 56));
        _bits
          ..addAll(MdBit.burst(at(), _rnd, n: 18, speed: 260))
          ..addAll(_splinters(at(), e.material!, 12))
          ..add(MdBit.score(at() - const Offset(0, 40), e.value.round()));
        final ask = e.ask!;
        _say(MsLines.letter(ask.letter, ask.nameAudio));
        final line = MsLines.great[_great++ % MsLines.great.length];
        _after(850, () => _say(line));
      case MsEventKind.wrong:
        _fb.nope();
        _pops.add(_Pop(e.text, at(), _clock, color: MonsterColors.panel, edge: GameColors.ink60, size: 40));
        _bits.addAll(MdBit.burst(at(), _rnd, n: 8, speed: 120, colors: const [MonsterColors.heartOff, MonsterColors.bubbleTint]));
        final a = g.ask;
        _say(MsLines.letter(e.text, MsAsk.capital(e.text).nameAudio));
        _after(800, () => _say(MsLines.oops));
        if (a != null) _after(800, () => _ask(a));
      case MsEventKind.knock:
        _fb.knock(e.material!.name, e.value);
      case MsEventKind.crack:
        _bits.addAll(MdBit.dust(at(), 30, _rnd, n: 3));
      case MsEventKind.smash:
        _fb.smash(e.material!.name);
        _shake = math.max(_shake, 5);
        _bits
          ..addAll(_splinters(at(), e.material!, 10))
          ..addAll(MdBit.dust(at(), 46, _rnd, n: 4))
          ..add(MdBit.score(at(), e.value.round()));
      case MsEventKind.friend:
        // a bonk (dizzy stars), then a happy spring as it turns friendly
        if (_clock - _bonkAt > .2) {
          _bonkAt = _clock;
          _fb.bonk();
          _after(1000, _fb.friend);
        }
        _bits
          ..addAll(MdBit.burst(at(), _rnd, n: 10, speed: 150, colors: const [MonsterColors.gem, MonsterColors.magicCore, MonsterColors.spark]))
          ..add(MdBit.score(at() - const Offset(0, 30), e.value.round()));
      case MsEventKind.ballGone:
        final hero = MsHero.values.byName(e.text);
        final s = g.shots.where((s) => s.restAt != null && s.restAt!.x == e.x && s.restAt!.y == e.y).firstOrNull;
        _rests.add(_Rest(hero, Vector2(e.x, e.y), s?.radius ?? MsGame.heroRadius[hero]!, _clock));
        _after(450, () {
          _fb.poof();
          _bits.addAll(MdBit.dust(at(), 40, _rnd, n: 5));
        });
      case MsEventKind.miss:
        if (g.misses.isOdd) _say(MsLines.miss);
        final a = g.ask;
        if (a != null) _ask(a);
      case MsEventKind.hint:
        _say(MsLines.hint);
        final a = g.ask;
        if (a != null) _ask(a);
      case MsEventKind.refill:
        _fb.reward();
        _say(MsLines.refill);
      case MsEventKind.bonus:
        _fb.bonusHero();
        _bonusAt = _clock;
      case MsEventKind.cleared:
        _fb.levelComplete();
        _clearedAt = _clock;
        _cheerAt = _clock;
        if (v != null) _bits.addAll(MdBit.confetti(v.screen.width, _rnd, n: 50));
        _say(MsLines.cleared);
      case MsEventKind.done:
        _fb.smashMusic(false);
        final child = ref.read(familyProvider).active.id;
        _record = ref.read(gameProgressProvider.notifier).record(child, GameIds.smash, score: g.score, stars: g.stars, level: widget.level?.number);
        _after(2200, () => _say(_record ? MsLines.record : MsLines.done));
        _after(1400, () => setState(() => _showResult = true));
    }
  }

  /// Bits of a block flying off: wood chips, ice shards, stone crumbs.
  List<MdBit> _splinters(Offset c, MsMaterial m, int n) {
    final colors = SmashColors.splinters[m.name]!;
    return [
      for (var k = 0; k < n; k++)
        () {
          final a = -math.pi * (.1 + .8 * _rnd.nextDouble());
          final s = 160 + _rnd.nextDouble() * 260;
          return MdBit(
            at: c + Offset((_rnd.nextDouble() - .5) * 30, (_rnd.nextDouble() - .5) * 30),
            v: Offset(math.cos(a) * s, math.sin(a) * s),
            life: .7 + _rnd.nextDouble() * .5,
            color: colors[k % colors.length],
            size: 8 + _rnd.nextDouble() * 8,
            kind: MdBitKind.confetti,
            gravity: 900,
            spin: (_rnd.nextDouble() - .5) * 20,
          );
        }(),
    ];
  }

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
    _speaking = _voiceOn ? _voice.speak(line, _mascot, after: MascotState.idle).then((_) {}) : (hold ? Future<void>.value() : shown.future);
  }

  void _endCaption() {
    final s = _shown;
    if (s != null && !s.isCompleted) s.complete();
  }

  /// Pencil asks [ask] once he has finished what he is saying.
  Future<void> _ask(MsAsk ask) async {
    final id = ++_askId;
    final said = Completer<void>();
    _after(4000, () => said.isCompleted ? null : said.complete());
    _speaking.whenComplete(() => said.isCompleted ? null : said.complete());
    await said.future;
    if (!mounted || id != _askId || _game?.ask != ask || _paused) return;
    _say(Prompt(text: ask.say, audio: ask.audio));
  }

  // ------------------------------------------------------------ the child

  void _play() {
    final g = _game;
    if (g == null || _started) return;
    _fb.levelStart();
    _voice.stop();
    _speaking = Future<void>.value();
    setState(() {
      _started = true;
      _caption = null;
    });
    _fb.smashMusic(true);
    g.start();
  }

  void _again() {
    final asks = _asks;
    if (asks == null) return;
    _fb.press();
    setState(() {
      _game = MsGame(asks: asks, level: _level, seed: widget.seed == null ? null : widget.seed! + 1);
      _started = false;
      _showResult = false;
      _record = false;
      _bits.clear();
      _pops.clear();
      _rests.clear();
      _shownScore = 0;
      _tapHinted = false;
    });
    _play();
  }

  void _pause() {
    final g = _game;
    if (_paused || g == null || !_started || g.over) return;
    g.release();
    setState(() => _paused = true);
    _voice.stop();
    _fb.smashMusic(false);
  }

  void _resume() {
    _fb.press();
    setState(() => _paused = false);
    _last = null;
    final g = _game;
    if (g != null && !g.over) {
      _fb.smashMusic(true);
      if (g.ask != null) _ask(g.ask!);
    }
  }

  void _exit() {
    _fb.back();
    _voice.stop();
    _fb.smashMusic(false);
    widget.onDone();
  }

  void _next() {
    _fb.press();
    _voice.stop();
    _fb.smashMusic(false);
    widget.onNext?.call();
  }

  void _repeatAsk() {
    final a = _game?.ask;
    if (a == null || _paused) return;
    _fb.tap();
    _voice.stop();
    _say(Prompt(text: a.say, audio: a.audio));
  }

  void _pick(int i) {
    final g = _game;
    if (g == null || _paused || !_started) return;
    if (g.pick(i)) _fb.select();
  }

  /// A tap anywhere while a hero flies: its power.
  void _tap(PointerDownEvent _) {
    final g = _game;
    if (g == null || _paused || g.phase != MsPhase.flying) return;
    g.power();
  }

  Vector2? _world(Offset local) {
    final v = _view, cam = _cam;
    if (v == null || cam == null) return null;
    return v.world(cam.unapply(local));
  }

  void _panStart(DragStartDetails d) {
    final g = _game, p = _world(d.localPosition);
    if (g == null || p == null || _paused || !_started) return;
    g.grab(p);
  }

  void _panUpdate(DragUpdateDetails d) {
    final g = _game, p = _world(d.localPosition);
    if (g == null || p == null || _paused) return;
    g.drag(p);
  }

  void _panEnd([DragEndDetails? _]) => _game?.release();

  // ------------------------------------------------------------ the heroes

  /// Where the heroes wait on the hill, right to left from the slingshot.
  static Vector2 _slot(int i, MsHero h) {
    return Vector2(2.15 - i * .58, MsGame.hillTop + MsHeroArt.foot(h) * MsGame.heroRadius[h]!);
  }

  static const _jump = .42;

  /// The heroes waiting, the one in the slingshot and the ones in the air
  /// (and the one hopping into the slingshot).
  (List<MsHeroSprite>, MsHeroSprite?, List<MsHeroSprite>) _sprites(MsGame g) {
    final t = _clock;
    final aim = g.phase == MsPhase.aim && g.heroes.isNotEmpty;
    final jt = aim ? ((_clock - _ballInAt) / _jump).clamp(0.0, 1.0) : 1.0;
    final jumping = aim && jt < 1;
    final waiting = aim ? g.heroes.sublist(1) : g.heroes;
    final cheer = _clock - _cheerAt < 1.4;
    final line = <MsHeroSprite>[];
    for (var i = 0; i < waiting.length && i < 3; i++) {
      final h = waiting[i];
      final to = _slot(i, h);
      final at = jumping ? Vector2(_slot(i + 1, h).x + (to.x - _slot(i + 1, h).x) * Curves.easeOut.transform(jt), to.y) : to;
      final p = (t * .55 + i * .37) % 1.0;
      var hop = p < .1 ? math.sin(p / .1 * math.pi) * .5 : 0.0;
      if (cheer) hop = math.max(hop, (math.sin((t - _cheerAt) * 9 + i).abs()) * .8 * (1 - (t - _cheerAt) / 1.4));
      if (jumping) hop = math.max(hop, math.sin(jt * math.pi) * .4);
      line.add(
        MsHeroSprite(h, at, MsGame.heroRadius[h]!, MsHeroLook(face: cheer ? MsFace.happy : MsFace.idle, hop: hop, squash: math.sin(t * 2.6 + i * 1.9) * .03, along: math.pi / 2)),
      );
    }
    MsHeroSprite? sling;
    final flying = <MsHeroSprite>[];
    if (aim) {
      final h = g.heroes.first;
      final r = MsGame.heroRadius[h]!;
      final rest = g.ballInSling;
      if (jumping) {
        // the hop from the line into the pouch
        final from = _slot(0, h);
        final e = Curves.easeInOut.transform(jt);
        final at = Vector2(from.x + (rest.x - from.x) * e, from.y + (rest.y - from.y) * e + math.sin(jt * math.pi) * .9);
        flying.add(MsHeroSprite(h, at, r, MsHeroLook(face: MsFace.happy, squash: .15 * math.sin(jt * math.pi), along: -math.pi / 2)));
      } else {
        final pull = g.pull;
        final k = pull == null ? 0.0 : (pull.length / MsGame.maxPull).clamp(0.0, 1.0);
        final dir = pull == null || pull.length < 1e-3 ? const Offset(1, 0) : Offset(-pull.x, pull.y) / pull.length;
        final settle = (_clock - _ballInAt - _jump).clamp(0.0, .3) / .3;
        sling = MsHeroSprite(
          h,
          rest,
          r,
          MsHeroLook(
            face: k > .45 ? MsFace.effort : MsFace.ready,
            squash: .14 * k - .2 * (1 - Curves.elasticOut.transform(settle)) * (1 - settle),
            along: math.atan2(dir.dy, dir.dx),
            turn: math.atan2(dir.dy, dir.dx) * .5 * k,
          ),
        );
      }
    }
    for (final s in g.shots) {
      if (s.gone) continue;
      final v = s.body.linearVelocity;
      final angle = math.atan2(-v.y, v.x);
      final hit = math.max(0.0, 1 - (g.time - s.hitAt) / .25);
      final power = s.volley.powered && g.time - s.volley.poweredAt < .6;
      // flying: the stretched picture along the flight; after a crash:
      // dizzy, rolling with the ball; the power: Crayo dashes along it,
      // Rubby and Inky stay upright
      final face = power ? MsFace.power : (s.hitAt >= 0 ? MsFace.bonked : MsFace.yell);
      flying.add(
        MsHeroSprite(
          s.hero,
          s.body.position,
          s.radius,
          MsHeroLook(
            face: face,
            squash: hit > 0 ? -.35 * s.hitHard * hit : (face == MsFace.yell ? (v.length * .008).clamp(0.0, .12) : 0),
            along: angle,
            turn: switch (face) {
              MsFace.yell => angle - MsHeroArt.tilt(s.hero, face),
              MsFace.power when s.hero == MsHero.crayo => angle - MsHeroArt.tilt(s.hero, face),
              MsFace.bonked => -s.body.angle,
              _ => 0,
            },
          ),
        ),
      );
    }
    for (final r in _rests) {
      final k = ((_clock - r.born) / .6).clamp(0.0, 1.0);
      flying.add(MsHeroSprite(r.hero, r.at, r.radius, MsHeroLook(face: MsFace.happy, scale: 1 - .5 * Curves.easeIn.transform(k), opacity: 1 - Curves.easeIn.transform(k))));
    }
    return (line, sling, flying);
  }

  /// The room sliding out (cleared) and the next sliding in (built), and
  /// how far the meadow has walked (base pixels).
  (double, double) _slide(MsGame g, double w) {
    const ease = Curves.easeInOutCubic;
    if (g.phase == MsPhase.cleared && g.phaseTime > 1.9 && g.room < g.rooms - 1) {
      final p = ease.transform(((g.phaseTime - 1.9) / 1.1).clamp(0.0, 1.0));
      return (-w * p, g.room * 2 * w + w * p);
    }
    if (g.phase == MsPhase.build && g.room > 0) {
      final p = ease.transform((g.phaseTime / 1.1).clamp(0.0, 1.0));
      return (w * (1 - p), (g.room - 1) * 2 * w + w + w * p);
    }
    return (0, math.max(0, g.room) * 2 * w);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    _pad = pad;
    final record = ref.watch(myGamesProvider)[GameIds.smash];
    _best = record?.best ?? 0;
    _levelStars = record?.levels[_level.number] ?? 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LikhoSystemBars.dark,
      child: Material(
        color: const Color(0xFFB7A6EF),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final g = _game;
            final view = _view = (_view != null && _view!.screen == size) ? _view! : MsView(size, MsBackground.meadow);
            final cam = _cam ??= MsCamera(size);
            cam.screen = size;
            return Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: _tap,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _panStart,
                      onPanUpdate: _panUpdate,
                      onPanEnd: _panEnd,
                      onPanCancel: _panEnd,
                      child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _scene(view, cam, g)),
                    ),
                  ),
                ),
                if (g != null) ...[
                  Positioned(
                    top: pad.top + 8,
                    left: 12 + pad.left,
                    right: 12 + pad.right,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _hud(g)),
                  ),
                  if (_started && !g.over)
                    Positioned(
                      left: 10 + pad.left,
                      bottom: 8 + pad.bottom,
                      child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _cards(g)),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _overlays(g, cam)),
                    ),
                  ),
                  if (!_started) Positioned.fill(child: _startCard()),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _speech(g)),
                    ),
                  ),
                  if (_paused)
                    Positioned.fill(
                      child: MsPauseCard(hero: g.heroes.isEmpty ? MsHero.rubby : g.heroes.first, onResume: _resume, onExit: _exit),
                    ),
                  if (_showResult) Positioned.fill(child: _resultCard(g)),
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

  Widget _scene(MsView view, MsCamera cam, MsGame? g) {
    final shake = Offset(math.sin(_clock * 61) * _shake, math.cos(_clock * 47) * _shake * .6);
    final (shift, scroll) = g == null ? (0.0, 0.0) : _slide(g, view.screen.width);
    final heroes = g == null || g.phase == MsPhase.ready ? null : _sprites(g);
    return ClipRect(
      child: Transform.translate(
        offset: shake,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: MsCrystalBackdropPainter(view: view, camera: cam, time: _clock, scroll: scroll),
              ),
            ),
            if (g != null && heroes != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: MsWorldPainter(
                    view: view,
                    camera: cam,
                    game: g,
                    lives: _lives,
                    line: heroes.$1,
                    sling: heroes.$2,
                    flying: heroes.$3,
                    time: _clock,
                    shift: shift,
                    popIn: g.room == 0,
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _CameraPainter(cam, MdEffectsPainter(bits: _bits, beams: const [], bubbles: const [], time: _clock)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ the top bar

  Widget _hud(MsGame g) => SizedBox(
    height: 66,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Semantics(
                label: _started ? 'Pause game' : 'Back to levels',
                button: true,
                child: PushButton(
                  key: const ValueKey('ms-pause'),
                  onTap: _started ? _pause : _exit,
                  color: MsPalette.cream,
                  edgeColor: const Color(0xFFBDA4DC),
                  edge: 3,
                  width: 46,
                  height: 46,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                    side: const BorderSide(color: Color(0xFFE5D9F5), width: 2),
                  ),
                  shadows: const [BoxShadow(color: MsPalette.shadow, offset: Offset(0, 4), blurRadius: 10)],
                  child: Icon(_started ? Symbols.pause_rounded : Symbols.arrow_back_rounded, size: 25, weight: 700, fill: 1, color: MsPalette.ink),
                ),
              ),
              const SizedBox(width: 8),
              if (_started && !g.over)
                Flexible(
                  child: MsPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        key: const ValueKey('ms-towers'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.level == null ? 'TOWERS' : 'LEVEL ${_level.number}',
                            style: LikhoFonts.body(size: 10, weight: FontWeight.w800, color: MsPalette.ink, height: 1),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var k = 0; k < g.rooms; k++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    k < g.room || (k == g.room && g.phase == MsPhase.cleared) ? Symbols.check_circle_rounded : Symbols.castle_rounded,
                                    size: 18,
                                    fill: 1,
                                    color: k < g.room || (k == g.room && g.phase == MsPhase.cleared) ? MsPalette.teal : (k == g.room ? MsPalette.violet : const Color(0xFFD2C5E5)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_started && g.ask != null && g.phase != MsPhase.build) _AskCard(ask: g.ask!, clock: _clock, onTap: _repeatAsk),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_started && !g.over) ...[Flexible(child: _meter(g)), const SizedBox(width: 8)],
              MsPanel(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(MsArt.star, width: 25, height: 25),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_shownScore.round()}',
                          key: const ValueKey('ms-score'),
                          style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: MsPalette.ink).copyWith(height: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// The Smash meter: smashing fills it; full, a bonus hero.
  Widget _meter(MsGame g) {
    final flash = (_clock - _bonusAt) < 1.2;
    return MsPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          key: const ValueKey('ms-meter'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.bolt_rounded, size: 24, fill: 1, color: flash ? MsPalette.gold : MsPalette.teal),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SMASH',
                  style: LikhoFonts.body(size: 9, weight: FontWeight.w800, color: MsPalette.ink, height: 1),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 68,
                  height: 9,
                  decoration: BoxDecoration(color: MsPalette.lilac, borderRadius: BorderRadius.circular(5)),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: flash ? 1 : g.meter.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: flash ? const [MsPalette.gold, Color(0xFFF1A855)] : const [Color(0xFF99E6D8), MsPalette.teal]),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The first hero is in the slingshot; tapping another sends it next.
  Widget _cards(MsGame g) {
    final can = g.phase == MsPhase.aim && g.pull == null;
    final shown = g.heroes.take(5).toList();
    return Row(
      key: const ValueKey('ms-cards'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('${shown[i].name}-$i-${g.heroes.length}'),
              tween: Tween(begin: i == shown.length - 1 && _clock - _bonusAt < 1 ? 0 : 1, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: MsHeroCard(key: ValueKey('ms-card-$i'), hero: shown[i], selected: i == 0, available: can, time: _clock, onTap: () => _pick(i)),
            ),
          ),
        if (g.heroes.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MsPanel(
              child: Text(
                '+${g.heroes.length - shown.length}',
                style: LikhoFonts.title(size: 16, weight: FontWeight.w800, color: MsPalette.ink),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------ over the world

  Widget _overlays(MsGame g, MsCamera cam) {
    final v = _view;
    final kids = <Widget>[];
    // the words popping out of the towers
    for (final p in _pops) {
      final t = _clock - p.born;
      final pop = Curves.elasticOut.transform((t / .5).clamp(0.0, 1.0));
      final at = cam.apply(p.at);
      kids.add(
        Positioned(
          left: at.dx - 100,
          top: at.dy - 60 - t * 40,
          width: 200,
          height: 80,
          child: Opacity(
            opacity: (1 - (t - .8) / .4).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .3 + .7 * pop,
              child: Center(
                child: Text(
                  p.text,
                  style: LikhoFonts.letter(size: p.size, color: p.color).copyWith(
                    height: 1,
                    shadows: [
                      for (final o in const [Offset(2, 2), Offset(-2, 2), Offset(2, -2), Offset(-2, -2), Offset(0, 4)]) Shadow(color: p.edge, offset: o),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // the level's number as it starts, "Tower down!" when a room falls
    String? banner;
    var since = 0.0;
    if (g.phase == MsPhase.build && _started && g.room == 0) {
      banner = widget.level == null ? 'Tower 1' : 'Level ${_level.number}';
      since = g.phaseTime;
    } else if (_clock - _clearedAt < 2.4) {
      banner = 'Tower down!';
      since = _clock - _clearedAt;
    }
    if (banner != null) {
      final pop = Curves.elasticOut.transform((since / .6).clamp(0.0, 1.0));
      final down = banner == 'Tower down!';
      kids.add(
        Align(
          alignment: const Alignment(.1, -.45),
          child: Opacity(
            opacity: (1 - (since - (down ? 2.0 : 1.0)) / .3).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .3 + .7 * pop,
              child: Container(
                key: const ValueKey('ms-banner'),
                padding: const EdgeInsets.fromLTRB(26, 6, 26, 10),
                decoration: BoxDecoration(
                  color: down ? LikhoColors.success : MonsterColors.ribbon,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: down ? GameColors.successDeep : MonsterColors.ribbonDeep, offset: const Offset(0, 6))],
                ),
                child: Text(
                  banner,
                  style: LikhoFonts.title(size: 34, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1.1),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // before the first shot: a finger shows the pull
    if (v != null && g.phase == MsPhase.aim && g.flings == 0 && g.pull == null && g.phaseTime > 2.5 && _started && !_paused) {
      final t = ((g.phaseTime - 2.5) % 2.0) / 1.4;
      final k = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
      final from = cam.apply(v.of(MsGame.rest));
      final to = cam.apply(v.at(MsGame.rest.x - 1.2, MsGame.rest.y - .7));
      kids.add(_finger(Offset.lerp(from, to, k)!, visible: t <= 1));
    }
    // a new hero in the air: a finger taps
    final s = g.shot;
    if (v != null && s != null && !s.gone && s.hero == _level.newHero && !s.volley.powered && s.volley.time > .2) {
      final at = cam.apply(v.of(s.body.position)) + const Offset(30, 24);
      final tap = (s.volley.time * 3) % 1.0;
      kids.add(_finger(at + Offset(0, -10 * math.sin(tap * math.pi)), visible: true, label: 'Tap!'));
    }
    return Stack(children: kids);
  }

  Widget _finger(Offset p, {required bool visible, String? label}) => Positioned(
    left: p.dx - 6,
    top: p.dy - 4,
    child: Opacity(
      opacity: visible ? 1 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.touch_app_rounded,
            key: ValueKey('ms-finger'),
            size: 54,
            fill: 1,
            color: MonsterColors.panel,
            shadows: [Shadow(color: MonsterColors.panelShadow, blurRadius: 8)],
          ),
          if (label != null)
            Text(
              label,
              style: LikhoFonts.title(
                size: 22,
                weight: FontWeight.w800,
                color: MonsterColors.panel,
              ).copyWith(height: 1, shadows: const [Shadow(color: MonsterColors.panelShadow, blurRadius: 6)]),
            ),
        ],
      ),
    ),
  );

  /// What Pencil says, in a bubble under the top bar.
  Widget _speech(MsGame g) {
    final c = _caption;
    if (c == null || _showResult || _paused || !_started) return const SizedBox.shrink();
    return Stack(
      children: [
        Positioned(
          left: 12 + _pad.left,
          top: _pad.top + 8 + 64,
          width: 300,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              key: const ValueKey('ms-caption'),
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
              decoration: MsPalette.panel(radius: 18),
              child: Text(
                c,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: LikhoFonts.title(size: c.length > 50 ? 15 : 18, weight: FontWeight.w800, color: MsPalette.ink).copyWith(height: 1.15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ cards

  /// Before the level: its number, the hero met in it (or the line), Play.
  Widget _startCard() {
    final hero = _level.newHero;
    final levels = widget.level != null;
    return MsStartCard(
      key: const ValueKey('ms-start'),
      title: levels ? 'Level ${_level.number}' : 'Monster Smash',
      world: widget.world,
      heroes: _level.heroes,
      newHero: hero,
      meet: hero == null ? null : MsLines.meet(hero).text,
      stars: levels ? _levelStars : null,
      best: _best,
      towers: _level.rooms.length,
      time: _clock,
      onPlay: _play,
      onBack: _exit,
    );
  }

  Widget _resultCard(MsGame g) => GameResultCard(
    id: 'ms',
    picture: MsArt.star,
    pictureWidget: SizedBox(
      height: 100,
      width: 220,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [for (final h in MsHero.values) SizedBox(width: 72, height: 100, child: CustomPaint(painter: _PortraitPainter(h, _clock, happy: true)))],
      ),
    ),
    title: widget.level == null ? 'All smashed!' : 'Level ${_level.number} done!',
    star: MsArt.star,
    stars: g.stars,
    score: g.score,
    detail: '${g.found} letters · ${g.friends} new friends',
    record: _record,
    onAgain: _again,
    onDone: _exit,
    onNext: widget.onNext == null ? null : _next,
    doneLabel: widget.level == null ? 'Map' : 'Levels',
    doneIcon: widget.level == null ? Symbols.map_rounded : Symbols.apps_rounded,
  );
}

/// Draws [inner] as the camera sees it.
class _CameraPainter extends CustomPainter {
  _CameraPainter(this.camera, this.inner);
  final MsCamera camera;
  final CustomPainter inner;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    camera.transform(canvas);
    inner.paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

/// A hero's portrait (cards, the level's start).
class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.hero, this.time, {this.happy = false});
  final MsHero hero;
  final double time;
  final bool happy;

  @override
  void paint(Canvas canvas, Size size) {
    if (happy) canvas.translate(0, -math.sin(time * 6 + hero.index).abs() * size.height * .08);
    MsHeroArt.portrait(canvas, hero, size, t: time, face: happy ? MsFace.happy : MsFace.idle);
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter old) => true;
}

/// What to hit: the letter, big (or the picture whose first letter it is).
/// A tap says it again.
class _AskCard extends StatelessWidget {
  const _AskCard({required this.ask, required this.clock, required this.onTap});
  final MsAsk ask;
  final double clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: TweenAnimationBuilder<double>(
      key: ValueKey(ask),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: .6 + .4 * v, child: child),
      child: Container(
        key: const ValueKey('ms-ask'),
        padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
        decoration: MsPalette.panel(radius: 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ask.picture != null)
              Image.asset(ask.picture!, width: 52, height: 52, fit: BoxFit.contain)
            else
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFAD8CE9), Color(0xFF7853BC)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x255B3594), offset: Offset(0, 3), blurRadius: 4)],
                ),
                child: Text(ask.letter, style: LikhoFonts.letter(size: 38, color: LikhoColors.surface).copyWith(height: 1)),
              ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FIND',
                  style: LikhoFonts.body(size: 10, weight: FontWeight.w800, color: MsPalette.ink, height: 1),
                ),
                const SizedBox(height: 3),
                Icon(Symbols.volume_up_rounded, size: 23, fill: 1, color: MsPalette.violet.withValues(alpha: .7 + .3 * math.sin(clock * 3).abs())),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
