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
import '../../../game/monster_smash/ms_engine.dart';
import '../../../game/speech/prompt_voice.dart';
import '../../../mascot/mascot.dart';
import '../../gameplay/widgets/game_buttons.dart';
import '../game_ui.dart';
import '../monster_defense/md_effects.dart';
import 'ms_lines.dart';
import 'ms_painter.dart';
import 'ms_scene.dart';

/// Monster Smash: played sideways, like Angry Birds. Pencil stands on a
/// little hill with a big slingshot; on the right Monster Defense's silly
/// monsters sit on towers of wood, ice and stone, some blocks with letters.
/// Pencil asks for a letter, the child drags the ball back (dots show where
/// it will go) and lets go: the block bursts, the tower falls and the
/// monsters tumbling down turn into friends. Three towers make a game. See
/// [MsGame] for the rules.
class MonsterSmashScreen extends ConsumerStatefulWidget {
  const MonsterSmashScreen({super.key, required this.onDone, this.asks, this.seed});
  final VoidCallback onDone;

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

class _MonsterSmashScreenState extends ConsumerState<MonsterSmashScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  late final math.Random _rnd = math.Random(widget.seed);
  late final AppFeedback _fb = ref.read(feedbackProvider);
  late final PromptVoice _voice = ref.read(promptVoiceProvider);
  late final bool _voiceOn = ref.read(voiceOnProvider);
  final _voiceOf = MascotController();

  MsGame? _game;
  MsAsks? _asks;

  /// The game (tests play it).
  @visibleForTesting
  MsGame? get debugGame => _game;
  Duration? _last;
  double _clock = 0;
  bool _started = false, _paused = false, _showResult = false, _record = false;
  late bool _firstPlay;
  int _best = 0;

  // what Pencil says
  String? _caption;
  int _talkId = 0, _askId = 0, _great = 0;
  Future<void> _speaking = Future<void>.value();
  Completer<void>? _shown;
  Timer? _captionTimer;
  final _timers = <Timer>[];
  bool _pullHinted = false;

  // effects
  final _bits = <MdBit>[];
  final _pops = <_Pop>[];
  double _shake = 0, _shownScore = 0, _clearedAt = -9, _wrongAt = -9;

  MsView? _view;
  EdgeInsets _pad = EdgeInsets.zero;

  /// The tower's background (the last one stays for the result).
  MsBackground get _bg {
    final g = _game;
    final t = g == null ? 0 : (g.tower.clamp(0, g.towers - 1));
    return MsBackground.all[t % MsBackground.all.length];
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _voice;
    _voiceOn;
    _firstPlay = (ref.read(myGamesProvider)[GameIds.smash]?.plays ?? 0) == 0;
    _fb.prepare(Sfx.monsterSmash);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final b in MsBackground.all) {
      precacheImage(AssetImage(b.asset), context);
    }
    MsSprites.load(createLocalImageConfiguration(context));
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
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
    _voiceOf.dispose();
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
      _game = MsGame(asks: asks!, seed: widget.seed);
    });
    if (_firstPlay) _say(MsLines.intro, hold: true);
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
      for (final b in _bits) {
        b.step(dt);
      }
      _bits.removeWhere((b) => b.done);
      _pops.removeWhere((p) => _clock - p.born > 1.2);
      _shake *= math.exp(-dt * 9);
      _shownScore += (g.score - _shownScore) * math.min(1, dt * 8);
      if ((g.score - _shownScore).abs() < .5) _shownScore = g.score.toDouble();
    }
    _frame.value++;
  }

  /// The first shot of a game: if the child waits, Pencil says how.
  void _hintPull(MsGame g) {
    if (_pullHinted || g.shots > 0 || g.phase != MsPhase.aim || g.pull != null || g.phaseTime < 7) return;
    _pullHinted = true;
    _say(MsLines.pullHint);
  }

  // ------------------------------------------------------------ what happened

  void _on(MsEvent e, MsGame g) {
    final v = _view;
    Offset at() => v == null ? Offset.zero : v.at(e.x, e.y);
    switch (e.kind) {
      case MsEventKind.build:
        _fb.whoosh();
        if (e.value > 0) _say(MsLines.tower);
      case MsEventKind.ask:
        _ask(e.ask!);
      case MsEventKind.grab:
        _fb.stretch();
      case MsEventKind.launch:
        _fb.launch();
      case MsEventKind.hit:
        _fb.pow();
        _shake = 9;
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
        _wrongAt = _clock;
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
        _fb.friend();
        _bits
          ..addAll(MdBit.burst(at(), _rnd, n: 10, speed: 150, colors: const [MonsterColors.gem, MonsterColors.magicCore, MonsterColors.spark]))
          ..add(MdBit.score(at() - const Offset(0, 30), e.value.round()));
      case MsEventKind.splash:
        _fb.splash();
        _shake = math.max(_shake, 6);
        _bits.addAll(MdBit.burst(at(), _rnd, n: 22, speed: 300, colors: SmashColors.water));
      case MsEventKind.ballGone:
        _bits.addAll(MdBit.dust(at(), 30, _rnd, n: 3));
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
      case MsEventKind.cleared:
        _fb.levelComplete();
        _clearedAt = _clock;
        if (v != null) _bits.addAll(MdBit.confetti(v.screen.width, _rnd, n: 50));
        _say(MsLines.cleared);
      case MsEventKind.done:
        _fb.smashMusic(false);
        final child = ref.read(familyProvider).active.id;
        _record = ref.read(gameProgressProvider.notifier).record(child, GameIds.smash, score: g.score, stars: g.stars);
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
    _speaking = _voiceOn ? _voice.speak(line, _voiceOf, after: MascotState.idle).then((_) {}) : (hold ? Future<void>.value() : shown.future);
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
      _game = MsGame(asks: asks, seed: widget.seed == null ? null : widget.seed! + 1);
      _started = false;
      _showResult = false;
      _record = false;
      _bits.clear();
      _pops.clear();
      _shownScore = 0;
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

  void _repeatAsk() {
    final a = _game?.ask;
    if (a == null || _paused) return;
    _fb.tap();
    _voice.stop();
    _say(Prompt(text: a.say, audio: a.audio));
  }

  void _panStart(DragStartDetails d) {
    final g = _game, v = _view;
    if (g == null || v == null || _paused || !_started) return;
    g.grab(v.world(d.localPosition));
  }

  void _panUpdate(DragUpdateDetails d) {
    final g = _game, v = _view;
    if (g == null || v == null || _paused) return;
    g.drag(v.world(d.localPosition));
  }

  void _panEnd([DragEndDetails? _]) => _game?.release();

  // ------------------------------------------------------------ build

  MsPencil _pencil(MsGame g) {
    final t = g.time;
    if (g.phase == MsPhase.cleared || g.phase == MsPhase.done || t - g.cheerAt < 1.6) {
      final since = g.phase == MsPhase.cleared || g.phase == MsPhase.done ? g.phaseTime : t - g.cheerAt;
      return MsPencil(pose: 'cheer', hop: (math.sin(since * 9).abs() * .22) * math.exp(-since * .6));
    }
    if (g.pull != null) {
      final k = (g.pull!.length / MsGame.maxPull).clamp(0.0, 1.0);
      return MsPencil(pose: 'pull', lean: -.05 * k, squash: 1 - .04 * k);
    }
    if (t - g.throwAt < .55) return const MsPencil(pose: 'throw');
    if (t - g.oopsAt < 1.4 || _clock - _wrongAt < 1.4) return const MsPencil(pose: 'oops');
    if (_caption != null && g.phase == MsPhase.aim) return const MsPencil(pose: 'point');
    return MsPencil(pose: 'stand', squash: 1 + .012 * math.sin(_clock * 2.4));
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    _pad = pad;
    _best = ref.watch(myGamesProvider)[GameIds.smash]?.best ?? 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: LikhoColors.clear),
      child: Material(
        color: LikhoColors.background,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final g = _game;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _panStart,
                    onPanUpdate: _panUpdate,
                    onPanEnd: _panEnd,
                    onPanCancel: _panEnd,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _frame,
                      builder: (context, _, _) {
                        final bg = _bg;
                        final view = _view = (_view != null && _view!.screen == size && _view!.bg == bg) ? _view! : MsView(size, bg);
                        return _scene(view, g);
                      },
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
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _overlays(g)),
                    ),
                  ),
                  if (!_started)
                    Positioned.fill(
                      child: GameStartCard(
                        id: 'ms',
                        title: 'Monster Smash',
                        cover: MsArt.cover,
                        hint: _firstPlay ? MsLines.intro.text : 'Smash the letter towers!',
                        best: _best,
                        onPlay: _play,
                        onBack: _exit,
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _speech(g)),
                    ),
                  ),
                  if (_paused)
                    Positioned.fill(
                      child: GamePauseCard(id: 'ms', picture: MsArt.pencil('oops'), onResume: _resume, onExit: _exit),
                    ),
                  if (_showResult)
                    Positioned.fill(
                      child: GameResultCard(
                        id: 'ms',
                        picture: MsArt.pencil('cheer'),
                        title: 'All smashed!',
                        star: MsArt.star,
                        stars: g.stars,
                        score: g.score,
                        detail: '${g.found} letters · ${g.friends} new friends',
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

  Widget _scene(MsView view, MsGame? g) {
    final shake = Offset(math.sin(_clock * 61) * _shake, math.cos(_clock * 47) * _shake * .6);
    return ClipRect(
      child: Transform.translate(
        offset: shake,
        child: Stack(
          children: [
            Positioned(
              left: view.origin.dx,
              top: view.origin.dy,
              width: view.imageSize.width,
              height: view.imageSize.height,
              child: Image.asset(view.bg.asset, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium),
            ),
            if (g != null && g.phase != MsPhase.ready)
              Positioned.fill(
                child: CustomPaint(
                  painter: MsWorldPainter(view: view, game: g, pencil: _pencil(g), time: _clock),
                ),
              ),
            if (g != null && g.phase == MsPhase.ready)
              Positioned.fill(
                child: CustomPaint(
                  painter: MsWorldPainter(
                    view: view,
                    game: g,
                    pencil: const MsPencil(pose: 'stand'),
                    time: _clock,
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: MdEffectsPainter(bits: _bits, beams: const [], bubbles: const [], time: _clock),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ the top bar

  Widget _hud(MsGame g) => SizedBox(
    height: 64,
    child: Stack(
      children: [
        Row(
          children: [
            PushButton(
              key: const ValueKey('ms-pause'),
              onTap: _started ? _pause : _exit,
              color: MonsterColors.panel,
              width: 46,
              height: 46,
              shape: const CircleBorder(),
              shadows: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 3), blurRadius: 6)],
              child: Icon(_started ? Symbols.pause_rounded : Symbols.arrow_back_rounded, size: 26, weight: 700, fill: 1, color: LikhoColors.ink),
            ),
            const SizedBox(width: 8),
            if (_started && !g.over) ...[
              GamePill(
                child: Row(
                  key: const ValueKey('ms-towers'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var k = 0; k < g.towers; k++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: Icon(
                          Symbols.castle_rounded,
                          size: 22,
                          fill: 1,
                          color: k < g.tower || (k == g.tower && g.phase == MsPhase.cleared)
                              ? LikhoColors.success
                              : (k == g.tower ? MonsterColors.ribbon : GameColors.ink15),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GamePill(
                child: Row(
                  key: const ValueKey('ms-balls'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in g.balls.take(6))
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: Image.asset(MsArt.ball(b), width: 24, height: 24)),
                    if (g.balls.isEmpty) const SizedBox(width: 24),
                  ],
                ),
              ),
            ],
            const Spacer(),
            GamePill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(MsArt.star, width: 24, height: 24),
                  const SizedBox(width: 5),
                  Text(
                    '${_shownScore.round()}',
                    key: const ValueKey('ms-score'),
                    style: LikhoFonts.title(size: 20, weight: FontWeight.w800).copyWith(height: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_started && g.ask != null && g.phase != MsPhase.build)
          Align(
            alignment: Alignment.topCenter,
            child: _AskCard(ask: g.ask!, clock: _clock, onTap: _repeatAsk),
          ),
      ],
    ),
  );

  // ------------------------------------------------------------ over the world

  Widget _overlays(MsGame g) {
    final v = _view;
    final kids = <Widget>[];
    // the words popping out of the towers
    for (final p in _pops) {
      final t = _clock - p.born;
      final pop = Curves.elasticOut.transform((t / .5).clamp(0.0, 1.0));
      kids.add(
        Positioned(
          left: p.at.dx - 100,
          top: p.at.dy - 60 - t * 40,
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
    // the tower's number as it comes, "Tower down!" when it falls
    String? banner;
    var since = 0.0;
    if (g.phase == MsPhase.build && _started) {
      banner = 'Tower ${g.tower + 1}';
      since = g.phaseTime;
    } else if (_clock - _clearedAt < 2.4) {
      banner = 'Tower down!';
      since = _clock - _clearedAt;
    }
    if (banner != null) {
      final pop = Curves.elasticOut.transform((since / .6).clamp(0.0, 1.0));
      kids.add(
        Align(
          alignment: const Alignment(.1, -.45),
          child: Opacity(
            opacity: (1 - (since - (banner == 'Tower down!' ? 2.0 : 1.0)) / .3).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .3 + .7 * pop,
              child: Container(
                key: const ValueKey('ms-banner'),
                padding: const EdgeInsets.fromLTRB(26, 6, 26, 10),
                decoration: BoxDecoration(
                  color: banner == 'Tower down!' ? LikhoColors.success : MonsterColors.ribbon,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: banner == 'Tower down!' ? GameColors.successDeep : MonsterColors.ribbonDeep, offset: const Offset(0, 6))],
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
    if (v != null && g.phase == MsPhase.aim && g.shots == 0 && g.pull == null && g.phaseTime > 2.5 && _started && !_paused) {
      final t = ((g.phaseTime - 2.5) % 2.0) / 1.4;
      final k = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
      final from = v.of(MsGame.rest);
      final to = v.at(MsGame.rest.x - 1.2, MsGame.rest.y - .7);
      final p = Offset.lerp(from, to, k)!;
      kids.add(
        Positioned(
          left: p.dx - 6,
          top: p.dy - 4,
          child: Opacity(
            opacity: t > 1 ? 0 : 1,
            child: const Icon(
              Symbols.touch_app_rounded,
              key: ValueKey('ms-finger'),
              size: 54,
              fill: 1,
              color: MonsterColors.panel,
              shadows: [Shadow(color: MonsterColors.panelShadow, blurRadius: 8)],
            ),
          ),
        ),
      );
    }
    return Stack(children: kids);
  }

  /// What Pencil says, in a bubble over him.
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
              decoration: BoxDecoration(
                color: MonsterColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 4), blurRadius: 10)],
              ),
              child: Text(
                c,
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
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          color: MonsterColors.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 5), blurRadius: 12)],
        ),
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
                decoration: BoxDecoration(color: MonsterColors.ribbon, borderRadius: BorderRadius.circular(16)),
                child: Text(ask.letter, style: LikhoFonts.letter(size: 38, color: LikhoColors.surface).copyWith(height: 1)),
              ),
            const SizedBox(width: 6),
            Icon(Symbols.volume_up_rounded, size: 26, fill: 1, color: MonsterColors.ribbon.withValues(alpha: .7 + .3 * math.sin(clock * 3).abs())),
          ],
        ),
      ),
    ),
  );
}
