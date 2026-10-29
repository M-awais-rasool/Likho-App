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
import '../../../game/letter_slice/ls_engine.dart';
import '../../../game/monster_defense/md_questions.dart';
import '../../../game/speech/prompt_voice.dart';
import '../../../mascot/mascot.dart';
import '../../gameplay/widgets/game_buttons.dart';
import '../game_ui.dart';
import '../monster_defense/md_effects.dart';
import 'ls_lines.dart';
import 'ls_painter.dart';
import 'ls_scene.dart';

/// Letter Slice: like Fruit Ninja. Fruits with happy faces fly up the
/// wooden board, each wearing a letter; Pencil asks for one (or a word to
/// spell) and the child swipes through the fruits with it. They split in
/// two and their juice splashes the board; a wrong letter only bounces
/// off. A golden star fruit gives points, an ice berry slows time, a
/// banana starts a fruit party. One round, then the score. See [LsGame].
class LetterSliceScreen extends ConsumerStatefulWidget {
  const LetterSliceScreen({super.key, required this.onDone, this.tasks, this.random});
  final VoidCallback onDone;

  /// Tests: fixed tasks and dice.
  final LsTasks? tasks;
  final math.Random? random;

  @override
  ConsumerState<LetterSliceScreen> createState() => _LetterSliceScreenState();
}

/// A word popping up on the board ("+10", "Combo x3!", "-2 s").
class _Pop {
  _Pop(this.text, this.at, this.born, {this.color = MonsterColors.score, this.size = 30});
  final String text;
  final Offset at;
  final double born, size;
  final Color color;
}

class _LetterSliceScreenState extends ConsumerState<LetterSliceScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  late final math.Random _rnd = widget.random ?? math.Random();
  late final AppFeedback _fb = ref.read(feedbackProvider);
  late final PromptVoice _voice = ref.read(promptVoiceProvider);
  late final bool _voiceOn = ref.read(voiceOnProvider);
  final _voiceOf = MascotController();

  LsGame? _game;
  LsTasks? _tasks;

  /// The game (tests play it).
  @visibleForTesting
  LsGame? get debugGame => _game;

  /// Where the board is (tests swipe with it).
  @visibleForTesting
  LsView? get debugView => _view;
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
  double _oopsSaid = -9;

  // effects
  final _bits = <MdBit>[];
  final _halves = <LsHalf>[];
  final _splats = <LsSplat>[];
  final _pops = <_Pop>[];
  final _trail = LsTrail();
  double _shake = 0, _shownScore = 0, _wordAt = -9, _frenzyAt = -9, _freezeAt = -9, _lostAt = -9;
  String _wordShown = '';
  double _swishAt = -9;
  int? _pointer;
  Duration? _moveStamp;

  LsView? _view;
  EdgeInsets _pad = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _voice;
    _voiceOn;
    _firstPlay = (ref.read(myGamesProvider)[GameIds.slice]?.plays ?? 0) == 0;
    _fb.prepare(Sfx.letterSlice);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(LsArt.board), context);
    LsSprites.load(createLocalImageConfiguration(context));
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
    _fb.sliceMusic(false);
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
      tasks = LsChildTasks(MdKnowledge.of(course, done), words, random: _rnd);
    }
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _game = LsGame(tasks: tasks!, random: _rnd);
    });
    if (_firstPlay) _say(LsLines.intro, hold: true);
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
      final k = g.slow ? .4 : 1.0;
      for (final b in _bits) {
        b.step(dt * k);
      }
      _bits.removeWhere((b) => b.done);
      final grav = (_view?.scale ?? 39) * g.gravity;
      for (final h in _halves) {
        h.step(dt * k, grav);
      }
      _halves.removeWhere((h) => h.age > 1.4);
      _splats.removeWhere((s) => _clock - s.born > 4);
      _pops.removeWhere((p) => _clock - p.born > 1.1);
      _shake *= math.exp(-dt * 10);
      _shownScore += (g.score - _shownScore) * math.min(1, dt * 8);
      if ((g.score - _shownScore).abs() < .5) _shownScore = g.score.toDouble();
    }
    _trail.forget(_clock);
    _frame.value++;
  }

  // ------------------------------------------------------------ what happened

  void _on(LsEvent e, LsGame g) {
    final v = _view;
    Offset at() => v == null || e.fruit == null ? Offset.zero : v.at(e.fruit!.x, e.fruit!.y);
    switch (e.kind) {
      case LsEventKind.countdown:
        _fb.countdown();
        _say(LsLines.count[(e.value - 1).round().clamp(0, 2)]);
      case LsEventKind.go:
        _fb.countdown(go: true);
        _fb.sliceMusic(true);
        _say(LsLines.go);
      case LsEventKind.task:
        _ask(g.current!);
      case LsEventKind.swish:
        if (_clock - _swishAt > .18) {
          _swishAt = _clock;
          _fb.swish(e.value);
        }
      case LsEventKind.cut:
        _fb.sliceFruit();
        _split(e, at());
        _pops.add(_Pop('+${e.value.round()}', at() - const Offset(0, 30), _clock));
        if (g.got > 0) _say(LsLines.letter(e.text));
      case LsEventKind.wrong:
        _fb.clonk();
        _shake = 5;
        _bits.addAll(MdBit.burst(at(), _rnd, n: 8, speed: 120, colors: const [MonsterColors.heartOff, MonsterColors.bubbleTint]));
        if (e.value > 0) {
          _lostAt = _clock;
          _pops.add(_Pop('-${e.value.round()} s', at() - const Offset(0, 40), _clock, color: SliceColors.clock, size: 34));
        }
        if (_clock - _oopsSaid > 3) {
          _oopsSaid = _clock;
          _say(LsLines.letter(e.text));
          _after(700, () => _say(LsLines.oops));
          final t = g.current;
          if (t != null) _after(700, () => _ask(t));
        }
      case LsEventKind.combo:
        _fb.combo();
        final c = v == null ? Offset.zero : Offset(v.screen.width / 2, v.screen.height * .42);
        _pops.add(_Pop('Combo x${e.value.round()}!  ${e.text}', c, _clock, color: SliceColors.stickerEdge, size: 40));
        _say(LsLines.combo);
      case LsEventKind.word:
        _fb.boost();
        _wordAt = _clock;
        final done = g.previous;
        _wordShown = e.text.toUpperCase();
        if (v != null) _bits.addAll(MdBit.confetti(v.screen.width, _rnd, n: 30));
        if (done?.done != null) {
          _say(Prompt(text: done!.done!, audio: done.doneAudio));
        } else {
          _say(LsLines.great[_great++ % LsLines.great.length]);
        }
      case LsEventKind.star:
        _fb.reward();
        _split(e, at());
        _bits.addAll(MdBit.burst(at(), _rnd, n: 16, speed: 240));
        _pops.add(_Pop('+50', at() - const Offset(0, 30), _clock, size: 40));
        _say(LsLines.star);
      case LsEventKind.freeze:
        _fb.slowMotion();
        _freezeAt = _clock;
        _split(e, at());
        _say(LsLines.freeze);
      case LsEventKind.frenzy:
        _fb.frenzy();
        _frenzyAt = _clock;
        _split(e, at());
        _say(LsLines.frenzy);
      case LsEventKind.hurry:
        _say(LsLines.hurry);
      case LsEventKind.tick:
        _fb.countdown();
      case LsEventKind.timeUp:
        _fb.sliceMusic(false);
        _fb.levelComplete();
        _say(LsLines.timeUp);
      case LsEventKind.done:
        final child = ref.read(familyProvider).active.id;
        _record = ref.read(gameProgressProvider.notifier).record(child, GameIds.slice, score: g.score, stars: g.stars);
        if (_record) _after(1200, () => _say(LsLines.record));
        _after(300, () => setState(() => _showResult = true));
    }
  }

  /// A fruit cut by the blade: two halves fly apart along the cut, juice
  /// sprays and stains the board.
  void _split(LsEvent e, Offset at) {
    final f = e.fruit!, v = _view;
    if (v == null) return;
    final size = f.r * v.scale * 2;
    // the blade's direction on the screen (the board's y runs up)
    final a = -e.angle;
    final normal = Offset(-math.sin(a), math.cos(a));
    final along = Offset(math.cos(a), math.sin(a));
    final fruitV = Offset(f.vx, -f.vy) * v.scale * .5;
    for (final upper in [true, false]) {
      final out = normal * (upper ? -1.0 : 1.0);
      _halves.add(
        LsHalf(
          art: f.art,
          at: at + out * size * .08,
          v: fruitV + out * (90 + _rnd.nextDouble() * 60) + along * 60,
          angle: a,
          spin: (upper ? -1 : 1) * (2 + _rnd.nextDouble() * 2),
          upper: upper,
          size: size,
        ),
      );
    }
    final juice = LsArt.juice[f.art] ?? MonsterColors.spark;
    _bits.addAll(MdBit.burst(at, _rnd, n: 16, speed: 260, colors: [juice, juice, MonsterColors.magicCore]));
    _splats.add(LsSplat(at + along * size * .3, juice, size * .9, _clock, _rnd.nextInt(1 << 20)));
    _shake = math.max(_shake, 3);
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

  /// Pencil asks for [task] once he has finished what he is saying.
  Future<void> _ask(LsTask task) async {
    final id = ++_askId;
    final said = Completer<void>();
    _after(4000, () => said.isCompleted ? null : said.complete());
    _speaking.whenComplete(() => said.isCompleted ? null : said.complete());
    await said.future;
    if (!mounted || id != _askId || _game?.current != task || _paused) return;
    _say(Prompt(text: task.say, audio: task.audio));
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
    g.start();
  }

  void _again() {
    final tasks = _tasks;
    if (tasks == null) return;
    _fb.press();
    setState(() {
      _game = LsGame(tasks: tasks, random: _rnd, height: _view?.height ?? 21);
      _started = false;
      _showResult = false;
      _record = false;
      _bits.clear();
      _halves.clear();
      _splats.clear();
      _pops.clear();
      _shownScore = 0;
    });
    _play();
  }

  void _pause() {
    final g = _game;
    if (_paused || g == null || !_started || g.over) return;
    g.bladeUp();
    setState(() => _paused = true);
    _voice.stop();
    _fb.sliceMusic(false);
  }

  void _resume() {
    _fb.press();
    setState(() => _paused = false);
    _last = null;
    final g = _game;
    if (g != null && g.phase == LsPhase.playing) {
      _fb.sliceMusic(true);
      if (g.current != null) _ask(g.current!);
    }
  }

  void _exit() {
    _fb.back();
    _voice.stop();
    _fb.sliceMusic(false);
    widget.onDone();
  }

  void _repeatAsk() {
    final t = _game?.current;
    if (t == null || _paused) return;
    _fb.tap();
    _voice.stop();
    _say(Prompt(text: t.say, audio: t.audio));
  }

  void _down(PointerDownEvent e) {
    final g = _game, v = _view;
    if (g == null || v == null || _paused || !_started || _pointer != null) return;
    _pointer = e.pointer;
    _moveStamp = e.timeStamp;
    final (x, y) = v.board(e.localPosition);
    g.bladeDown(x, y);
    _trail.add(e.localPosition, _clock);
  }

  void _move(PointerMoveEvent e) {
    final g = _game, v = _view;
    if (g == null || v == null || e.pointer != _pointer || _paused) return;
    final (x, y) = v.board(e.localPosition);
    // how long the finger took: the events' own times (frames bunch them)
    final last = _moveStamp;
    _moveStamp = e.timeStamp;
    final dt = last == null ? null : (e.timeStamp - last).inMicroseconds / 1e6;
    g.bladeMove(x, y, dt: dt != null && dt > 0 ? dt : null);
    _trail.add(e.localPosition, _clock);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _game?.bladeUp();
  }

  // ------------------------------------------------------------ build

  LsPencil _pencil(LsGame g) {
    final t = g.time;
    if (g.phase == LsPhase.over || g.phase == LsPhase.done || t - g.cheerAt < .9 || _clock - _wordAt < 1.3) {
      final since = math.min(t - g.cheerAt, _clock - _wordAt);
      return LsPencil('cheer', hop: math.sin(since.clamp(0, 10) * 10).abs() * 12);
    }
    if (t - g.oopsAt < 1.2) return const LsPencil('oops');
    if (_caption != null) return const LsPencil('point');
    return const LsPencil('stand');
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    _pad = pad;
    _best = ref.watch(myGamesProvider)[GameIds.slice]?.best ?? 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LikhoSystemBars.light,
      child: Material(
        color: LikhoColors.background,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final view = _view = (_view != null && _view!.screen == size) ? _view! : LsView(size);
            final g = _game;
            g?.height = view.height;
            return Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _down,
                    onPointerMove: _move,
                    onPointerUp: _up,
                    onPointerCancel: _up,
                    child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, _) => _scene(view, g)),
                  ),
                ),
                if (g != null) ...[
                  Positioned(
                    top: pad.top + 8,
                    left: 12,
                    right: 12,
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
                        id: 'ls',
                        title: 'Letter Slice',
                        cover: LsArt.cover,
                        hint: _firstPlay ? LsLines.intro.text : 'Slice the letters!',
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
                      child: GamePauseCard(id: 'ls', picture: LsArt.pencil('oops'), onResume: _resume, onExit: _exit),
                    ),
                  if (_showResult)
                    Positioned.fill(
                      child: GameResultCard(
                        id: 'ls',
                        picture: LsArt.pencil('cheer'),
                        title: 'Great slicing!',
                        star: LsArt.star,
                        stars: g.stars,
                        score: g.score,
                        detail: '${g.sliced} ${g.sliced == 1 ? 'fruit' : 'fruits'} · ${g.done} done',
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

  Widget _scene(LsView view, LsGame? g) {
    final shake = Offset(math.sin(_clock * 61) * _shake, math.cos(_clock * 47) * _shake * .6);
    final freezing = g != null && g.slow;
    return ClipRect(
      child: Transform.translate(
        offset: shake,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(LsArt.board, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.medium),
            ),
            if (g != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: LsPainter(view: view, game: g, halves: _halves, splats: _splats, trail: _trail, pencil: _pencil(g), time: _clock),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: MdEffectsPainter(bits: _bits, beams: const [], bubbles: const [], time: _clock),
              ),
            ),
            if (freezing)
              const Positioned.fill(
                child: IgnorePointer(child: ColoredBox(color: SliceColors.freeze)),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ the top bar

  Widget _hud(LsGame g) {
    final left = g.left.ceil();
    final hurry = g.phase == LsPhase.playing && g.left <= 10;
    final lost = _clock - _lostAt < .6;
    return Column(
      children: [
        Row(
          children: [
            PushButton(
              key: const ValueKey('ls-pause'),
              onTap: _started ? _pause : _exit,
              color: MonsterColors.panel,
              width: 46,
              height: 46,
              shape: const CircleBorder(),
              shadows: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 3), blurRadius: 6)],
              child: Icon(_started ? Symbols.pause_rounded : Symbols.arrow_back_rounded, size: 26, weight: 700, fill: 1, color: LikhoColors.ink),
            ),
            const SizedBox(width: 8),
            if (_started)
              Transform.scale(
                scale: hurry ? 1 + .08 * math.sin(_clock * 10).abs() : (lost ? 1.12 : 1),
                child: GamePill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.timer_rounded, size: 22, weight: 700, fill: 1, color: hurry || lost ? SliceColors.clock : LikhoColors.ink),
                      const SizedBox(width: 3),
                      Text(
                        '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                        key: const ValueKey('ls-time'),
                        style: LikhoFonts.title(
                          size: 18,
                          weight: FontWeight.w800,
                          color: hurry || lost ? SliceColors.clock : LikhoColors.ink,
                        ).copyWith(height: 1),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            GamePill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(LsArt.star, width: 24, height: 24),
                  const SizedBox(width: 5),
                  Text(
                    '${_shownScore.round()}',
                    key: const ValueKey('ls-score'),
                    style: LikhoFonts.title(size: 20, weight: FontWeight.w800).copyWith(height: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_started && g.current != null && g.phase == LsPhase.playing) _TaskCard(task: g.current!, got: g.got, clock: _clock, onTap: _repeatAsk),
      ],
    );
  }

  // ------------------------------------------------------------ over the board

  Widget _overlays(LsGame g) {
    final kids = <Widget>[];
    // 3, 2, 1, Go!
    if (g.phase == LsPhase.countdown || (g.phase == LsPhase.playing && g.phaseTime < .7)) {
      final going = g.phase == LsPhase.playing;
      final t = going ? g.phaseTime : g.phaseTime % 1;
      final n = going ? 'GO!' : '${3 - g.phaseTime.floor()}';
      final pop = Curves.elasticOut.transform((t / .5).clamp(0.0, 1.0));
      kids.add(
        Align(
          alignment: const Alignment(0, -.1),
          child: Opacity(
            opacity: (1 - (t - .55) / .45).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .4 + .8 * pop,
              child: Text(
                n,
                style: LikhoFonts.title(size: 96, weight: FontWeight.w800, color: going ? LikhoColors.success : MonsterColors.ribbon).copyWith(
                  shadows: const [Shadow(color: MonsterColors.panelShadow, offset: Offset(0, 6), blurRadius: 12)],
                ),
              ),
            ),
          ),
        ),
      );
    }
    // banners: the word, the fruit party, slow motion, time up
    void banner(String text, double since, Color color, Color edge, {double life = 1.4}) {
      if (since < 0 || since > life) return;
      final pop = Curves.elasticOut.transform((since / .6).clamp(0.0, 1.0));
      kids.add(
        Align(
          alignment: const Alignment(0, -.3),
          child: Opacity(
            opacity: (1 - (since - (life - .4)) / .4).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .3 + .7 * pop,
              child: Container(
                key: ValueKey('ls-banner-$text'),
                padding: const EdgeInsets.fromLTRB(26, 6, 26, 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 6))],
                ),
                child: Text(
                  text,
                  style: LikhoFonts.title(size: 36, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1.1),
                ),
              ),
            ),
          ),
        ),
      );
    }

    banner('$_wordShown!', _clock - _wordAt, LikhoColors.success, GameColors.successDeep);
    banner('Fruit party!', _clock - _frenzyAt, MonsterColors.bossRibbon, MonsterColors.bossRibbonDeep, life: 1.8);
    banner('Slow motion!', _clock - _freezeAt, MonsterColors.gemBlue, MonsterColors.ribbonDeep, life: 1.8);
    if (g.phase == LsPhase.over || g.phase == LsPhase.done && !_showResult) {
      banner("Time's up!", g.phase == LsPhase.over ? g.phaseTime : 1, MonsterColors.ribbon, MonsterColors.ribbonDeep, life: 9);
    }
    // points and combos rising from the board
    for (final p in _pops) {
      final t = _clock - p.born;
      final pop = Curves.elasticOut.transform((t / .4).clamp(0.0, 1.0));
      kids.add(
        Positioned(
          left: p.at.dx - 150,
          top: p.at.dy - 30 - t * 50,
          width: 300,
          height: 60,
          child: Opacity(
            opacity: (1 - (t - .7) / .4).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .4 + .6 * pop,
              child: Center(
                child: Text(
                  p.text,
                  style: LikhoFonts.title(size: p.size, weight: FontWeight.w800, color: p.color).copyWith(
                    height: 1,
                    shadows: const [
                      Shadow(color: MonsterColors.scoreEdge, offset: Offset(2, 2)),
                      Shadow(color: MonsterColors.scoreEdge, offset: Offset(-2, 2)),
                      Shadow(color: MonsterColors.scoreEdge, offset: Offset(2, -2)),
                      Shadow(color: MonsterColors.scoreEdge, offset: Offset(-2, -2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // before the first swipe: a finger shows how
    final v = _view;
    if (v != null && _started && !_paused && g.phase == LsPhase.playing && g.sliced == 0 && g.wrong == 0 && g.phaseTime > 2) {
      final t = (g.phaseTime % 1.6) / 1.1;
      final k = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
      final from = Offset(v.screen.width * .25, v.screen.height * .62), to = Offset(v.screen.width * .75, v.screen.height * .5);
      final p = Offset.lerp(from, to, k)!;
      kids.add(
        Positioned(
          left: p.dx - 10,
          top: p.dy - 6,
          child: Opacity(
            opacity: t > 1 ? 0 : 1,
            child: const Icon(
              Symbols.swipe_right_rounded,
              key: ValueKey('ls-finger'),
              size: 56,
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

  /// What Pencil says, in a bubble near him.
  Widget _speech(LsGame g) {
    final c = _caption;
    if (c == null || _showResult || _paused || !_started) return const SizedBox.shrink();
    return Stack(
      children: [
        Positioned(
          left: 16,
          right: 60,
          bottom: (_view?.screen.height ?? 800) * .16 + _pad.bottom + 12,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              key: const ValueKey('ls-caption'),
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

/// What to slice: the letter (or picture, or word with its boxes), and how
/// many are done. A tap says it again.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.got, required this.clock, required this.onTap});
  final LsTask task;
  final int got;
  final double clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = task.letters.length;
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(task),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(scale: .6 + .4 * v, child: child),
        child: Container(
          key: const ValueKey('ls-task'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: MonsterColors.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 5), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.picture != null)
                Image.asset(task.picture!, width: 52, height: 52, fit: BoxFit.contain)
              else
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: MonsterColors.ribbon, borderRadius: BorderRadius.circular(16)),
                  child: Text(task.letters[0], style: LikhoFonts.letter(size: 38, color: LikhoColors.surface).copyWith(height: 1)),
                ),
              const SizedBox(width: 10),
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                if (task.spelling)
                  Container(
                    width: 38,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < got ? LikhoColors.success : MonsterColors.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: i == got
                            ? MonsterColors.ribbon.withValues(alpha: .5 + .5 * math.sin(clock * 6).abs())
                            : (i < got ? GameColors.successDeep : GameColors.ink15),
                        width: i == got ? 3 : 2,
                      ),
                    ),
                    child: i < got ? Text(task.letters[i], style: LikhoFonts.letter(size: 28, color: LikhoColors.surface).copyWith(height: 1)) : null,
                  )
                else
                  Icon(Symbols.nutrition_rounded, size: 26, fill: i < got ? 1 : 0, color: i < got ? LikhoColors.success : GameColors.ink15),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
