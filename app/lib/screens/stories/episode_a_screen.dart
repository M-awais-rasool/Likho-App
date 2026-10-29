import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../data/models/course_models.dart';
import '../../data/story.dart';
import '../../design/tokens.dart';
import '../../feedback/app_feedback.dart';
import '../../feedback/pencil_lines.dart';
import '../../game/level_session.dart';
import '../../game/speech/prompt_voice.dart';
import '../../mascot/mascot.dart';
import '../gameplay/rounds/write_round_view.dart';
import '../gameplay/widgets/game_bits.dart';
import '../gameplay/widgets/game_buttons.dart';
import 'story_art.dart';

/// The parts of story A, in order (a test or the preview can start at one).
enum StepA { house, garden, pick, find, market, sign, tags, customer, end }

/// Story A, "Dada's Apple Garden":
///
/// 1. house: Ayan knocks: Dada needs help
/// 2. garden: the rain washed Dada's shop sign away, the market opens soon
/// 3. pick: tap the five red apples on the tree into the basket (counted)
/// 4. find: things that start with A (an airplane, an ant, an apple), not
///    the bird, the flower or the sun
/// 5. market: Dada's stall, its sign empty
/// 6. sign: write A on the sign (close up), it stays on the sign
/// 7. tags: A on the apple baskets' tags: traced, dots, by yourself
/// 8. customer: Aunty wants three apples (counted), she pays
/// 9. end: Dada gives a golden apple; stars
///
/// Every line is said by its speaker and shown in the bubble word for word.
class EpisodeAScreen extends ConsumerStatefulWidget {
  const EpisodeAScreen({super.key, required this.onDone, this.startAt = StepA.house});
  final VoidCallback onDone;
  final StepA startAt;

  static const id = 'a';

  @override
  ConsumerState<EpisodeAScreen> createState() => _EpisodeAScreenState();
}

/// The script stopped (the screen closed).
class _Stop implements Exception {}

/// Where people stand: x (0..1 of the picture), feet y.
typedef _Spot = (double x, double y);

class _EpisodeAScreenState extends ConsumerState<EpisodeAScreen> with SingleTickerProviderStateMixin {
  static const ep = EpisodeAScreen.id;

  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  final _pencil = MascotController();
  final _voiceOf = MascotController(); // speaks for the others (never shown)
  late final PromptVoice _voice = ref.read(promptVoiceProvider);
  late final bool _voiceOn = ref.read(voiceOnProvider);
  late final AppFeedback _fb = ref.read(feedbackProvider);
  StoryEpisode? _story;
  bool _alive = true;
  final _timers = <Timer>[];

  StepA _step = StepA.house;
  String _place = 'house';
  int _mistakes = 0, _burst = 0;

  // who is where: id -> (spot, pose); off screen when missing
  final _cast = <String, (_Spot, String)>{};
  _Spot _pencilAt = (.62, .93);

  // what is being said
  String? _caption, _speaker;
  bool _talking = false;
  int _talkId = 0;

  // pick: the apples on the tree (0 on the tree, 1 falling, 2 in the basket)
  final _apples = List.filled(5, 0);
  TapGate<void>? _gate;

  // find
  final _found = <String>{};
  final _wrong = <String, int>{};

  // writing (the sign, then three tags)
  WritePadController? _pad;
  String? _closeUp; // 'sign' or 'tag' while writing close up
  bool _written = false;
  List<List<Offset>>? _signInk;
  Size _signPad = Size.zero;
  final _tagInk = <List<List<Offset>>>[];
  Size _tagPad = Size.zero;
  bool _baskets = false;

  // customer
  int _given = 0;
  final _givenFlying = <int>{};

  // end
  bool _golden = false, _finished = false;

  Timer? _nudge;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
    _voice;
    _voiceOn;
    _fb;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // decode the art now: poses swap without a blink
    for (final who in ['ayan', 'dada', 'aunty', 'ant']) {
      for (final pose in _poses[who]!) {
        precacheImage(AssetImage(StoryArt.pose(ep, who, pose)), context);
      }
    }
    for (final p in ['house', 'garden', 'market']) {
      precacheImage(AssetImage(StoryArt.bg(ep, p)), context);
    }
  }

  static const _poses = {
    'ayan': ['idle', 'talk', 'wave', 'happy', 'point', 'thumbs', 'surprised', 'basket'],
    'dada': ['idle', 'talk', 'worried', 'happy', 'point', 'thumbs', 'give', 'wave'],
    'aunty': ['idle', 'talk', 'think', 'happy', 'pay', 'apples', 'surprised', 'wave'],
    'ant': ['idle', 'wave', 'happy', 'surprised'],
  };

  @override
  void dispose() {
    _alive = false;
    _gate?.open(null);
    _nudge?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _ticker.dispose();
    _time.dispose();
    _voice.stop();
    _pad?.dispose();
    _pencil.dispose();
    _voiceOf.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ script tools

  void _ok() {
    if (!_alive || !mounted) throw _Stop();
  }

  Future<void> _wait(int ms) {
    final c = Completer<void>();
    _timers.removeWhere((t) => !t.isActive);
    _timers.add(Timer(Duration(milliseconds: ms), c.complete));
    return c.future.then((_) => _ok());
  }

  void _set(VoidCallback f) {
    _ok();
    setState(f);
  }

  /// [id]'s line, said by its speaker (Pencil with his mouth moving; the
  /// others bob); the bubble shows its words. [pose]: the speaker's pose
  /// while talking (back to [after], or idle, when done).
  Future<void> _say(String id, {String? pose, String? after}) async {
    _ok();
    final line = _story!.line(id);
    final talk = ++_talkId;
    final who = line.who;
    _set(() {
      _caption = line.shown;
      _speaker = who;
      _talking = true;
      if (who != 'pencil' && _cast.containsKey(who)) _cast[who] = (_cast[who]!.$1, pose ?? (who == 'ant' ? 'wave' : 'talk'));
    });
    final said = _voice.speak(line.prompt, who == 'pencil' ? _pencil : _voiceOf, after: MascotState.idle);
    if (_voiceOn) {
      await said;
    } else {
      await _wait(1200); // the voice off (tests)
    }
    _ok();
    if (talk != _talkId) return;
    _set(() {
      _talking = false;
      if (who != 'pencil' && _cast.containsKey(who)) _cast[who] = (_cast[who]!.$1, after ?? 'idle');
    });
    await _wait(350);
  }

  void _pose(String who, String pose) => _set(() {
    if (_cast.containsKey(who)) _cast[who] = (_cast[who]!.$1, pose);
  });

  void _put(String who, _Spot at, [String pose = 'idle']) => _set(() => _cast[who] = (at, pose));

  void _leave(String who) => _set(() => _cast.remove(who));

  Future<void> _goTo(String place) async {
    _set(() => _place = place);
    await _wait(650);
  }

  /// Says [line] again if the child waits a while (twice at most).
  void _nudgeWith(String line) {
    _nudge?.cancel();
    var times = 0;
    void arm() {
      _nudge = Timer(const Duration(seconds: 10), () {
        if (!_alive || _talking || times >= 2) return;
        times++;
        _say(line).catchError((_) {});
        arm();
      });
    }

    arm();
  }

  void _stopNudge() => _nudge?.cancel();

  // ------------------------------------------------------------ the story

  Future<void> _start() async {
    try {
      _story = await ref.read(storyProvider(ep).future);
      _ok();
      final from = widget.startAt;
      for (final s in StepA.values.skip(from.index)) {
        _set(() => _step = s);
        await switch (s) {
          StepA.house => _house(),
          StepA.garden => _garden(),
          StepA.pick => _pick(),
          StepA.find => _find(),
          StepA.market => _market(),
          StepA.sign => _sign(),
          StepA.tags => _tags(),
          StepA.customer => _customer(),
          StepA.end => _end(),
        };
      }
    } on _Stop {
      // the screen closed
    }
  }

  Future<void> _house() async {
    _set(() {
      _place = 'house';
      _pencilAt = (.68, .91);
    });
    _pencil.play(MascotState.idle);
    await _wait(600);
    _put('ayan', (1.35, .91), 'wave');
    await _wait(60);
    _put('ayan', (.3, .91), 'wave');
    _fb.whoosh();
    await _wait(700);
    await _say('knock', pose: 'talk', after: 'point');
    _pencil.play(MascotState.wave);
    await _say('go');
    _leave('ayan');
    _set(() => _pencilAt = (1.4, .91));
    await _wait(500);
  }

  Future<void> _garden() async {
    _set(() => _cast.clear());
    await _goTo('garden');
    _set(() => _pencilAt = (.17, .91));
    _put('ayan', (.47, .91));
    _put('dada', (.8, .91), 'worried');
    await _wait(500);
    await _say('worried', pose: 'worried', after: 'worried');
    _pencil.play(MascotState.encourage);
    await _say('help');
    _pose('dada', 'idle');
    await _say('pick', pose: 'point', after: 'idle');
  }

  Future<void> _pick() async {
    _set(() {
      _place = 'garden';
      // Ayan holds the basket out: the apples fall into it
      _cast
        ..['ayan'] = ((.47, .91), 'basket')
        ..['dada'] = ((.8, .91), 'idle');
      _pencilAt = (.17, .91);
    });
    _nudgeWith('nudge_pick');
    var count = 0;
    while (count < 5) {
      final gate = _gate = TapGate<void>();
      await gate.future;
      _ok();
      count = _apples.where((a) => a > 0).length;
      _nudgeWith('nudge_pick');
      unawaited(_say('n$count').catchError((_) {}));
    }
    _stopNudge();
    await _wait(1500);
    _pencil.play(MascotState.happy);
    _set(() => _burst++);
    await _say('full', pose: 'basket', after: 'basket');
    await _say('sound');
  }

  void _tapApple(int i) {
    if (_step != StepA.pick || _apples[i] != 0) return;
    setState(() => _apples[i] = 1);
    _fb.pop();
    HapticFeedback.lightImpact();
    Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _apples[i] = 2);
      _fb.step(_apples.where((a) => a == 2).length);
    });
    _gate?.open(null);
  }

  static const _targets = {'airplane', 'ant', 'apple'};

  Future<void> _find() async {
    _set(() {
      _place = 'garden';
      // Dada packs apples; the little ant sits on a leaf on the path
      _cast
        ..remove('dada')
        ..['ayan'] = ((.55, .91), 'basket')
        ..['ant'] = ((.2, .735), 'idle');
      _pencilAt = (.82, .91);
    });
    await _say('find');
    _nudgeWith('nudge_find');
    while (_found.length < _targets.length) {
      final gate = _gate = TapGate<void>();
      await gate.future;
      _ok();
    }
    _stopNudge();
    await _wait(400);
    _put('dada', (1.4, .91), 'happy');
    await _wait(60);
    _put('dada', (.85, .91), 'happy');
    _set(() => _burst++);
    await _wait(700);
    await _say('found', pose: 'happy', after: 'point');
  }

  Future<void> _tapFind(String what) async {
    if (_step != StepA.find || _found.contains(what) || _talking) return;
    if (_targets.contains(what)) {
      setState(() => _found.add(what));
      _fb.correct();
      HapticFeedback.lightImpact();
      if (what == 'ant') _pose('ant', 'happy');
      try {
        await _say(what, pose: what == 'ant' ? 'wave' : null, after: what == 'ant' ? 'happy' : null);
      } on _Stop {
        return;
      }
      _gate?.open(null);
    } else {
      setState(() {
        _wrong[what] = (_wrong[what] ?? 0) + 1;
        _mistakes++;
      });
      _fb.nope();
      _say(what).catchError((_) {});
    }
  }

  Future<void> _market() async {
    _set(() {
      _cast.clear();
      _found.clear();
    });
    await _goTo('market');
    _set(() => _pencilAt = (.17, .91));
    _put('ayan', (.4, .91), 'basket');
    _put('dada', (.82, .91), 'worried');
    await _wait(400);
    await _say('shop', pose: 'point', after: 'worried');
    await _say('sign');
  }

  Future<void> _sign() async {
    _set(() {
      _place = 'market';
      _cast
        ..['ayan'] = ((.4, .91), 'basket')
        ..['dada'] = ((.82, .91), 'idle');
      _pencilAt = (.17, .91);
    });
    await _write('sign', WriteMode.trace);
    _set(() => _signInk = [for (final s in _pad!.strokes) [...s]]);
    _signPad = _pad!.padSize;
    _pose('dada', 'happy');
    _set(() => _burst++);
    await _say('signed', pose: 'happy', after: 'thumbs');
  }

  Future<void> _tags() async {
    _set(() {
      _place = 'market';
      _baskets = true;
      _cast
        ..['ayan'] = ((.4, .91), 'idle')
        ..['dada'] = ((.82, .91), 'idle');
      _pencilAt = (.17, .91);
    });
    await _say('tags', pose: 'point');
    for (final (i, mode) in [WriteMode.trace, WriteMode.dots, WriteMode.free].indexed) {
      await _say(['trace', 'dots', 'free'][i]);
      await _write('tag', mode);
      _set(() => _tagInk.add([for (final s in _pad!.strokes) [...s]]));
      _tagPad = _pad!.padSize;
      _fb.step(i + 1);
    }
    _pose('ayan', 'happy');
    _set(() => _burst++);
    await _say('tagged', pose: 'happy', after: 'thumbs');
  }

  /// Writes A close up on [what] ('sign' or 'tag') in [mode]; returns when
  /// it is written (a rejected try is a mistake, and the pad clears).
  Future<void> _write(String what, WriteMode mode) async {
    final glyphs = ref.read(courseProvider).value?.glyphs ?? const {};
    final round = WriteRound(id: 'story-a-$what-${mode.name}', prompt: const Prompt(text: 'A'), mode: mode, target: 'A', guide: 'A');
    final old = _pad;
    final gate = _gate = TapGate<void>();
    final pad = WritePadController(round: round, guides: WritePadController.guidesFor(round, glyphs));
    pad.addEventListener((e) {
      if (!mounted) return;
      switch (e) {
        case PadEvent.strokeDone:
          setState(() {});
        case PadEvent.letterDone:
          if (pad.judge() == WritingVerdict.accepted) {
            setState(() => _written = true);
            _fb.correct();
            gate.open(null);
          } else {
            setState(() => _mistakes++);
            _fb.wrong();
            Timer(const Duration(milliseconds: 400), () {
              if (mounted) setState(pad.erase);
            });
          }
        case PadEvent.wrongStart || PadEvent.leftPath:
          break;
      }
    });
    _set(() {
      _pad = pad;
      _written = false;
      _closeUp = what;
    });
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    // the pad lays its guide out in the next frame: then its first step shows
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    await gate.future;
    _ok();
    _set(() => _burst++);
    await _wait(900);
    _set(() => _closeUp = null);
    await _wait(400);
  }

  Future<void> _customer() async {
    _set(() {
      _place = 'market';
      _baskets = true;
      _cast
        ..['ayan'] = ((.4, .91), 'idle')
        ..['dada'] = ((.9, .91), 'idle');
      _pencilAt = (.13, .91);
    });
    _set(() => _cast.remove('ayan'));
    _put('aunty', (1.4, .91));
    await _wait(60);
    _put('aunty', (.47, .91));
    _fb.whoosh();
    await _wait(800);
    await _say('hello', pose: 'talk');
    await _say('give');
    _nudgeWith('nudge_give');
    while (_given < 3) {
      final gate = _gate = TapGate<void>();
      await gate.future;
      _ok();
      _nudgeWith('nudge_give');
      unawaited(_say('a$_given').catchError((_) {}));
    }
    _stopNudge();
    await _wait(1500);
    _pose('aunty', 'apples');
    await _wait(700);
    _fb.coin();
    await _say('thanks', pose: 'pay', after: 'happy');
    _put('aunty', (1.4, .91), 'wave');
    await _wait(600);
    _leave('aunty');
  }

  void _tapGive(int i) {
    if (_step != StepA.customer || _given >= 3 || _givenFlying.contains(i) || _caption == _story?.line('hello').shown && _talking) return;
    setState(() {
      _givenFlying.add(i);
      _given++;
    });
    _fb.pop();
    HapticFeedback.lightImpact();
    _gate?.open(null);
  }

  Future<void> _end() async {
    _set(() {
      _place = 'market';
      _baskets = true;
      _cast
        ..remove('aunty')
        ..['ayan'] = ((.42, .91), 'happy')
        ..['dada'] = ((.78, .91), 'give');
      _pencilAt = (.17, .91);
    });
    await _say('saved', pose: 'give', after: 'give');
    _set(() => _golden = true);
    _fb.reward();
    await _wait(1200);
    final stars = storyStars(_mistakes);
    final child = ref.read(familyProvider).active.id;
    ref.read(storyProgressProvider.notifier).record(child, ep, stars);
    _set(() {
      _finished = true;
      _burst++;
    });
    _fb.levelComplete();
    _pencil.play(MascotState.dance);
    await _say('bye');
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LikhoSystemBars.dark,
      child: Material(
        color: LikhoColors.background,
        child: ConfettiBurst(
          trigger: _burst,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              final f = BgFrame(size);
              final personH = size.height * .27;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(child: StoryBackground(asset: StoryArt.bg(ep, _place))),
                  if (_place == 'market') ..._marketThings(f),
                  if (_place == 'garden') ..._gardenThings(f),
                  ..._people(f, size, personH),
                  if (_place == 'garden' && _step == StepA.pick) ..._fallingApples(f, size, personH),
                  if (_place == 'market' && _step == StepA.customer) ..._givenApples(f, size),
                  Positioned(left: 16, right: 16, top: pad.top + 8, child: _TopBar(step: _step, onClose: widget.onDone)),
                  if (_closeUp != null) Positioned.fill(child: _closeUpView(f, size)),
                  if (_caption != null && !_finished)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: pad.top + 70,
                      // words only: taps go through to what is under it
                      child: IgnorePointer(
                        child: StoryBubble(
                          name: _speaker == null ? null : _story?.names[_speaker],
                          text: _stepText?.$1 ?? _caption!,
                          step: _stepText?.$2,
                          tailX: _tailX(f, size),
                        ),
                      ),
                    ),
                  if (_golden && !_finished) Positioned.fill(child: _GoldenApple(time: _time)),
                  if (_finished) Positioned.fill(child: _Reward(stars: storyStars(_mistakes), onDone: widget.onDone, onAgain: _again)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _again() => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => EpisodeAScreen(onDone: widget.onDone)));

  /// The stroke being written, while nothing is said.
  (String, int)? get _stepText {
    final g = _pad?.guide;
    if (_closeUp == null || _talking || g == null || g.done || _written) return null;
    return (g.shapeOf(g.stroke).instruction, g.stroke + 1);
  }

  /// The bubble's tail points at the one speaking.
  double _tailX(BgFrame f, Size size) {
    final x = switch (_speaker) {
      'pencil' => _pencilAt.$1 * size.width,
      final w? when _cast.containsKey(w) => _cast[w]!.$1.$1 * size.width,
      _ => size.width / 2,
    };
    return ((x - 16) / (size.width - 32)).clamp(.08, .92);
  }

  /// Where a person's feet go: [x] across the screen (0..1; someone
  /// walking in or out is past the edge, everyone else stays fully on
  /// screen), [y] on the picture's ground.
  Offset _feet(BgFrame f, Size size, double x, double y, double width) {
    final px = x * size.width;
    final inside = x >= 0 && x <= 1;
    return Offset(inside ? px.clamp(width / 2 + 4, size.width - width / 2 - 4) : px, f.at(0, y).dy);
  }

  List<Widget> _people(BgFrame f, Size size, double h) {
    const d = Duration(milliseconds: 700);
    const curve = Curves.easeOutCubic;
    final out = <Widget>[];
    // back to front by how low their feet are
    final order = _cast.entries.toList()..sort((a, b) => a.value.$1.$2.compareTo(b.value.$1.$2));
    for (final MapEntry(key: who, value: ((x, y), pose)) in order) {
      final ant = who == 'ant';
      final ph = ant ? h * .38 : (who == 'dada' ? h * 1.04 : h);
      final pw = ph * (who == 'dada' ? .83 : (who == 'aunty' ? .63 : (ant ? .6 : .69)));
      final feet = ant ? f.at(x, y) : _feet(f, size, x, y, pw);
      out.add(AnimatedPositioned(
        key: ValueKey('person-$who'),
        duration: d,
        curve: curve,
        left: feet.dx - pw / 2,
        top: feet.dy - ph,
        width: pw,
        height: ph,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: ant && _step == StepA.find ? () => _tapFind('ant') : null,
          child: _Found(
            found: ant && _found.contains('ant'),
            child: StoryPerson(episode: ep, who: who, pose: pose, time: _time, talking: _talking && _speaker == who, flip: ant),
          ),
        ),
      ));
    }
    // Pencil: the mascot himself
    final ph = h * .95;
    final feet = _feet(f, size, _pencilAt.$1, _pencilAt.$2, ph * .72);
    out.add(AnimatedPositioned(
      key: const ValueKey('pencil'),
      duration: d,
      curve: curve,
      left: feet.dx - ph * .36,
      top: feet.dy - ph,
      width: ph * .72,
      height: ph,
      child: IgnorePointer(child: OverflowBox(maxWidth: ph, maxHeight: ph, child: PencilMascot(controller: _pencil, size: ph))),
    ));
    return out;
  }

  // garden: apples on the tree and the basket (pick), things to find (find)
  static const _appleSpots = [(.52, .3), (.68, .2), (.86, .27), (.62, .41), (.82, .42)];

  List<Widget> _gardenThings(BgFrame f) {
    final w = f.size.width;
    final out = <Widget>[];
    // the picture's own airplane sits under the bubble: a cloud hides it,
    // and the real one flies lower (it is one of the A things to find)
    final hide = f.at(.25, .125);
    out.add(Positioned(left: hide.dx - w * .2, top: hide.dy - w * .1, width: w * .4, height: w * .2, child: const IgnorePointer(child: StoryProp(episode: ep, name: 'cloud'))));
    if (_step == StepA.pick || _step == StepA.garden) {
      for (var i = 0; i < 5; i++) {
        if (_apples[i] != 0) continue;
        final c = f.at(_appleSpots[i].$1, _appleSpots[i].$2);
        final side = w * .1;
        out.add(Positioned(
          key: ValueKey('apple-$i'),
          left: c.dx - side / 2,
          top: c.dy - side / 2,
          width: side,
          height: side,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _tapApple(i),
            child: ValueListenableBuilder<double>(
              valueListenable: _time,
              child: const StoryProp(episode: ep, name: 'apple_leaf'),
              // apples sway a little, and glow while waiting to be picked
              builder: (context, t, child) => Transform.rotate(angle: math.sin(t * 2 + i) * .08, child: child),
            ),
          ),
        ));
      }
    }
    if (_step == StepA.find) {
      Widget thing(String id, double x, double y, double side) {
        final c = f.at(x, y);
        final s = w * side;
        return Positioned(
          key: ValueKey('find-$id'),
          left: c.dx - s / 2,
          top: c.dy - s / 2,
          width: s,
          height: s,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _tapFind(id),
            child: _Wobble(
              times: _wrong[id] ?? 0,
              child: _Found(found: _found.contains(id), child: StoryProp(episode: ep, name: id)),
            ),
          ),
        );
      }

      // the ant's leaf (the ant stands on it, see _people)
      final leaf = f.at(.2, .745);
      out
        ..add(Positioned(left: leaf.dx - w * .09, top: leaf.dy - w * .07, width: w * .18, height: w * .12, child: const IgnorePointer(child: StoryProp(episode: ep, name: 'leaf'))))
        ..add(thing('sun', .22, .38, .16))
        ..add(_airplane(f))
        ..add(thing('bird', .55, .575, .13))
        ..add(thing('apple', .32, .86, .1))
        ..add(thing('flower', .18, .925, .1));
    }
    return out;
  }

  /// The airplane, flying slowly back and forth across the sky.
  Widget _airplane(BgFrame f) {
    final w = f.size.width;
    final side = w * .28;
    return ValueListenableBuilder<double>(
      key: const ValueKey('find-airplane-sky'),
      valueListenable: _time,
      builder: (context, t, child) {
        final k = (math.sin(t * .35) + 1) / 2; // 0..1..0
        final c = f.at(.2 + k * .35, .27 + math.sin(t * 1.3) * .006);
        return Positioned(left: c.dx - side / 2, top: c.dy - side * .3, width: side, height: side * .6, child: child!);
      },
      child: GestureDetector(
        key: const ValueKey('find-airplane'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tapFind('airplane'),
        child: _Found(found: _found.contains('airplane'), child: const StoryProp(episode: ep, name: 'airplane')),
      ),
    );
  }

  /// Apples falling from the tree into the basket.
  List<Widget> _fallingApples(BgFrame f, Size size, double h) {
    final w = f.size.width;
    final out = <Widget>[];
    // into Ayan's basket (he holds it at his belly)
    final ayan = _cast['ayan']?.$1 ?? (.47, .91);
    final b = _feet(f, size, ayan.$1, ayan.$2, h * .69) - Offset(0, h * .2);
    // five apple slots, filled as they land
    final got = _apples.where((a) => a == 2).length;
    out.add(Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.paddingOf(context).top + 168,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: StoryColors.panel, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: StoryColors.panelShadow, offset: Offset(0, 4), blurRadius: 8)]),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: i < got ? 1 : .25,
                      child: const SizedBox(width: 30, height: 30, child: StoryProp(episode: ep, name: 'apple')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      if (_apples[i] != 1) continue;
      final side = w * .1;
      final from = f.at(_appleSpots[i].$1, _appleSpots[i].$2);
      out.add(TweenAnimationBuilder<double>(
        key: ValueKey('fall-$i'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeIn,
        builder: (context, t, child) {
          final p = Offset.lerp(from, b, t)! + Offset(0, -math.sin(t * math.pi) * 30);
          return Positioned(left: p.dx - side / 2, top: p.dy - side / 2, width: side, height: side, child: child!);
        },
        child: const StoryProp(episode: ep, name: 'apple_leaf'),
      ));
    }
    return out;
  }

  // market: the sign with the child's A, the baskets with tags
  static const _signBox = (.348, .412, .652, .474);
  static const _boardCut = (.357, .417, .644, .469); // the board alone, inside its edge
  static const _basketSpots = [.32, .5, .68];
  static const _counterY = .607;

  List<Widget> _marketThings(BgFrame f) {
    final out = <Widget>[];
    final ink = _signInk;
    if (ink != null) {
      final r = f.rect(_signBox.$1, _signBox.$2, _signBox.$3, _signBox.$4);
      out.add(Positioned.fromRect(
        rect: r,
        child: IgnorePointer(child: CustomPaint(painter: _InkOnPainter(strokes: ink, pad: _signPad, color: StoryColors.ink))),
      ));
    }
    if (_baskets) {
      final w = f.size.width;
      for (var i = 0; i < 3; i++) {
        final c = f.at(_basketSpots[i], _counterY);
        final side = w * .2;
        out.add(Positioned(
          key: ValueKey('basket-$i'),
          left: c.dx - side / 2,
          top: c.dy - side * .92,
          width: side,
          height: side,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: StoryProp(episode: ep, name: 'basket_full')),
              // its tag, with the child's A once written
              Positioned(
                left: side * .32,
                bottom: -side * .08,
                width: side * .36,
                height: side * .3,
                child: CustomPaint(
                  painter: _TagPainter(),
                  child: i < _tagInk.length
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(side * .08, side * .07, side * .04, side * .03),
                          child: CustomPaint(painter: _InkOnPainter(strokes: _tagInk[i], pad: _tagPad, color: StoryColors.ink, width: 2.2)),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ));
      }
    }
    return out;
  }

  /// Aunty's apples: three on the middle basket to tap; each flies to her.
  List<Widget> _givenApples(BgFrame f, Size size) {
    final w = f.size.width;
    final out = <Widget>[];
    final basket = f.at(_basketSpots[1], _counterY - .045);
    final aunty = _cast['aunty'];
    final to = aunty == null ? basket : f.at(aunty.$1.$1 + .05, aunty.$1.$2 - .12);
    for (var i = 0; i < 3; i++) {
      final side = w * .085;
      final from = basket + Offset((i - 1) * side * .9, -side * .4);
      final flying = _givenFlying.contains(i);
      out.add(TweenAnimationBuilder<double>(
        key: ValueKey('give-$i-$flying'),
        tween: Tween(begin: 0, end: flying ? 1 : 0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        builder: (context, t, child) {
          final p = Offset.lerp(from, to, t)! + Offset(0, -math.sin(t * math.pi) * 60);
          return Positioned(
            left: p.dx - side / 2,
            top: p.dy - side / 2,
            width: side,
            height: side,
            child: Opacity(opacity: flying ? (1 - (t - .85) / .15).clamp(0.0, 1.0) : 1, child: child),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tapGive(i),
          child: ValueListenableBuilder<double>(
            valueListenable: _time,
            child: const StoryProp(episode: ep, name: 'apple'),
            builder: (context, t, child) => Transform.scale(scale: flying ? 1 : 1 + math.sin(t * 5 + i).abs() * .08, child: child),
          ),
        ),
      ));
    }
    return out;
  }

  /// Writing close up: the market sign (cut from the picture, stretched
  /// without bending its corners) or a paper tag, the pad on it.
  Widget _closeUpView(BgFrame f, Size size) {
    final pad = _pad;
    if (pad == null) return const SizedBox();
    final side = math.min(size.width * .72, size.height * .4);
    final glyphs = ref.read(courseProvider).value?.glyphs ?? const {};
    final writing = WritePad(
      controller: pad,
      correct: _written,
      hint: _mistakes > 0,
      round: pad.round,
      glyphs: glyphs,
      time: _time,
      onPen: _pencil.lookAt,
      paper: LikhoColors.clear,
      radius: 18,
    );
    final board = _closeUp == 'sign'
        ? ArtImage(
            asset: StoryArt.bg(ep, 'market'),
            builder: (context, image) {
              if (image == null) return const SizedBox();
              final sx = image.width / StoryArt.bgSize.width;
              final src = Rect.fromLTRB(_boardCut.$1 * StoryArt.bgSize.width * sx, _boardCut.$2 * StoryArt.bgSize.height * sx, _boardCut.$3 * StoryArt.bgSize.width * sx, _boardCut.$4 * StoryArt.bgSize.height * sx);
              return CustomPaint(painter: NineSlicePainter(image: image, src: src, inset: src.height * .32));
            },
          )
        : CustomPaint(painter: _TagPainter(big: true));
    return ColoredBox(
      color: StoryColors.veil,
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('close-${pad.round.id}'),
          tween: Tween(begin: .6, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: const Cubic(.34, 1.4, .64, 1),
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: SizedBox(
            width: side * 1.3,
            height: side * 1.12,
            child: Stack(
              children: [
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(26), child: board)),
                Positioned(left: side * .15, top: side * .1, width: side, height: side * .92, child: writing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ parts

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, required this.onClose});
  final StepA step;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      PushButton(
        onTap: onClose,
        color: StoryColors.panel,
        width: 50,
        height: 50,
        shape: const CircleBorder(),
        shadows: const [BoxShadow(color: StoryColors.panelShadow, offset: Offset(0, 4), blurRadius: 8)],
        child: const Icon(Symbols.close_rounded, size: 28, weight: 700, color: LikhoColors.ink),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: StoryColors.panel, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: StoryColors.panelShadow, offset: Offset(0, 4), blurRadius: 8)]),
        child: Row(
          children: [
            for (final s in StepA.values)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: s == step ? 20 : 9,
                height: 9,
                decoration: BoxDecoration(
                  color: s.index < step.index ? StoryColors.found : (s == step ? LikhoColors.primary : LikhoColors.inkFaint),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
          ],
        ),
      ),
      const Spacer(),
      Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: LikhoColors.success, shape: BoxShape.circle, border: Border.all(color: StoryColors.panel, width: 3)),
        child: Text('A', style: LikhoFonts.letter(size: 26, color: LikhoColors.surface).copyWith(height: 1)),
      ),
    ],
  );
}

/// A green ring and a tick on something found.
class _Found extends StatelessWidget {
  const _Found({required this.found, required this.child});
  final bool found;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(child: child),
      if (found) ...[
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: const Cubic(.34, 1.56, .64, 1),
              builder: (context, v, _) => Transform.scale(
                scale: v,
                child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: StoryColors.glow, border: Border.all(color: StoryColors.found, width: 4))),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: StoryColors.found, shape: BoxShape.circle, border: Border.all(color: StoryColors.panel, width: 3)),
            child: const Icon(Symbols.check_rounded, size: 18, weight: 800, color: StoryColors.panel),
          ),
        ),
      ],
    ],
  );
}

/// Shakes once each time [times] goes up (a wrong tap).
class _Wobble extends StatelessWidget {
  const _Wobble({required this.times, required this.child});
  final int times;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(times),
    tween: Tween(begin: times == 0 ? 1 : 0, end: 1),
    duration: const Duration(milliseconds: 420),
    builder: (context, v, child) => Transform.translate(offset: Offset(math.sin(v * math.pi * 5) * (1 - v) * 10, 0), child: child),
    child: child,
  );
}

/// The child's strokes (pad coordinates) painted into this box, keeping
/// the letter's shape.
class _InkOnPainter extends CustomPainter {
  const _InkOnPainter({required this.strokes, required this.pad, required this.color, this.width = 5});
  final List<List<Offset>> strokes;
  final Size pad;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (pad.isEmpty) return;
    final s = math.min(size.width / pad.width, size.height / pad.height) * .95;
    final o = Offset((size.width - pad.width * s) / 2, (size.height - pad.height * s) / 2);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final st in strokes) {
      if (st.length < 2) continue;
      final path = Path()..moveTo(o.dx + st.first.dx * s, o.dy + st.first.dy * s);
      for (final q in st.skip(1)) {
        path.lineTo(o.dx + q.dx * s, o.dy + q.dy * s);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_InkOnPainter old) => old.strokes != strokes || old.pad != pad;
}

/// A paper price tag with a hole and its string.
class _TagPainter extends CustomPainter {
  _TagPainter({this.big = false});
  final bool big;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final notch = w * .14;
    final tag = Path()
      ..moveTo(notch, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(notch, h)
      ..lineTo(0, h * .5)
      ..close();
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(big ? 24 : 4));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawPath(tag.shift(Offset(0, big ? 8 : 2)), Paint()..color = StoryColors.shadow);
    canvas.drawPath(tag, Paint()..color = StoryColors.tag);
    canvas.drawPath(tag, Paint()
      ..color = StoryColors.tagEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = big ? 6 : 1.6);
    canvas.drawCircle(Offset(notch * 1.15, h * .5), big ? 12 : 2.4, Paint()..color = StoryColors.tagEdge);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TagPainter old) => old.big != big;
}

/// Dada's golden apple, big and shining.
class _GoldenApple extends StatelessWidget {
  const _GoldenApple({required this.time});
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: const Cubic(.34, 1.56, .64, 1),
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: ValueListenableBuilder<double>(
          valueListenable: time,
          builder: (context, t, child) => Transform.rotate(angle: math.sin(t * 2) * .06, child: child),
          child: Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [StoryColors.glow, LikhoColors.clear])),
            padding: const EdgeInsets.all(36),
            // the apple, turned to gold
            child: const ColorFiltered(
              colorFilter: ColorFilter.matrix([
                .9, .5, 0, 0, 30, //
                .55, .55, 0, 0, 20,
                0, .1, .1, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: StoryProp(episode: 'a', name: 'apple_leaf'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The end: the golden apple won, the stars, play again or back.
class _Reward extends StatelessWidget {
  const _Reward({required this.stars, required this.onDone, required this.onAgain});
  final int stars;
  final VoidCallback onDone, onAgain;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: StoryColors.veil,
    child: Align(
      alignment: const Alignment(0, .25),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .7, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: const Cubic(.34, 1.56, .64, 1),
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 310,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          decoration: BoxDecoration(color: StoryColors.panel, borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: StoryColors.panelShadow, offset: Offset(0, 10), blurRadius: 24)]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('STORY DONE', style: LikhoFonts.body(size: 13, weight: FontWeight.w800, color: StoryColors.name).copyWith(letterSpacing: 1.6)),
              const SizedBox(
                width: 110,
                height: 110,
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix([
                    .9, .5, 0, 0, 30, //
                    .55, .55, 0, 0, 20,
                    0, .1, .1, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: StoryProp(episode: 'a', name: 'apple_leaf'),
                ),
              ),
              Text('You won a golden apple!', textAlign: TextAlign.center, style: LikhoFonts.title(size: 22, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = 1; k <= 3; k++)
                    Icon(Symbols.star_rounded, size: k == 2 ? 54 : 44, fill: 1, color: stars >= k ? LikhoColors.primary : MapColors.starOff),
                ],
              ),
              const SizedBox(height: 14),
              PushButton(
                onTap: onDone,
                color: LikhoColors.success,
                edgeColor: GameColors.successDeep,
                edge: 6,
                height: 58,
                width: 250,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                innerHighlight: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Done', style: LikhoFonts.title(size: 24, weight: FontWeight.w800, color: LikhoColors.surface)),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onAgain,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.replay_rounded, size: 20, weight: 700, color: LikhoColors.secondary),
                      const SizedBox(width: 4),
                      Text('Play again', style: LikhoFonts.title(size: 17, weight: FontWeight.w800, color: LikhoColors.secondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
