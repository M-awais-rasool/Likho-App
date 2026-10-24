import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../monster_defense/md_questions.dart';

/// Letter Slice, the game itself (no drawing): like Fruit Ninja's arcade
/// round. Fruits with happy faces fly up from the bottom of the board, each
/// wearing a letter. Pencil asks for one ("Slice B!", or a word to spell
/// letter by letter) and the child swipes through the fruits with it: they
/// split and splash. A fruit with another letter only bounces off (and
/// costs two seconds when the letter is not in the task at all, so wild
/// swiping does not pay). Now and then a golden star fruit (points), an
/// ice berry (slow motion) or a banana (a fruit party: fruits with the
/// letter pour in from the sides) flies up. The round lasts [roundTime]
/// seconds; there is no losing.
///
/// World units: the board is 10 wide and [height] tall, y up from the
/// bottom. [tick] moves time on; [bladeDown], [bladeMove] and [bladeUp]
/// are the child's finger; [drain] hands out what happened.

/// What the child slices: a letter a few times, or a word's letters in
/// order (with its picture).
@immutable
class LsTask {
  const LsTask({required this.letters, required this.say, required this.audio, this.word, this.picture, this.done, this.doneAudio});

  /// The letters to slice, in order ("BBB", "cat").
  final String letters;
  final String? word;

  /// What Pencil says (his bubble), its recording, the picture.
  final String say, audio;
  final String? picture;

  /// What he says when it is done ("Cat! C, A, T!"), and its recording.
  final String? done, doneAudio;

  static String _voice(String id) => 'assets/voice/$id.m4a';

  factory LsTask.letter(String l, {int times = 3}) {
    final small = l == l.toLowerCase();
    return LsTask(letters: l * times, say: small ? 'Slice small $l!' : 'Slice $l!', audio: _voice(small ? 'ls_slice_small_$l' : 'ls_slice_${l.toLowerCase()}'));
  }

  /// A picture: slice the letter it starts with.
  factory LsTask.first(String word, {int times = 2}) => LsTask(
    letters: word[0] * times,
    say: '${word[0].toUpperCase()}${word.substring(1)}! Which letter does it start with?',
    audio: _voice('md_first_$word'),
    picture: MdWords.picture(word),
  );

  factory LsTask.spell(String word) => LsTask(
    letters: word,
    word: word,
    say: 'Spell $word!',
    audio: _voice('sr_spell_$word'),
    picture: MdWords.picture(word),
    done: '${word[0].toUpperCase()}${word.substring(1)}! ${word.toUpperCase().split('').join(', ')}!',
    doneAudio: _voice('sr_word_$word'),
  );

  bool get spelling => word != null;

  @override
  String toString() => 'LsTask($letters)';
}

/// Where the tasks come from: task [done] (0, 1, 2 …) after [done]
/// finished ones.
abstract class LsTasks {
  LsTask next(int done);
}

/// Fixed tasks, over and over (tests, the preview).
class LsList implements LsTasks {
  LsList(this.tasks);
  final List<LsTask> tasks;

  @override
  LsTask next(int done) => tasks[done % tasks.length];
}

/// The tasks for a child: what they learned (Monster Defense's
/// knowledge), the newest skill half the time: capitals, small letters,
/// pictures' first letters, short words to spell.
class LsChildTasks implements LsTasks {
  LsChildTasks(this.knowledge, this.words, {math.Random? random}) : _rnd = random ?? math.Random();
  final MdKnowledge knowledge;
  final MdWords words;
  final math.Random _rnd;
  final List<String> _recent = [];

  @override
  LsTask next(int done) {
    final skills = knowledge.skills;
    final skill = skills.length == 1 || _rnd.nextBool() ? skills.last : skills[_rnd.nextInt(skills.length - 1)];
    String pick(List<String> pool) {
      final fresh = pool.where((p) => !_recent.contains(p)).toList();
      final from = fresh.isEmpty ? pool : fresh;
      final p = from[_rnd.nextInt(from.length)];
      _recent.add(p);
      if (_recent.length > 4) _recent.removeAt(0);
      return p;
    }

    switch (skill) {
      case MdSkill.capitals:
        return LsTask.letter(pick(knowledge.capitals));
      case MdSkill.smalls:
        return LsTask.letter(pick(knowledge.smalls));
      case MdSkill.firstSound:
        final known = words.first.where((w) => knowledge.smalls.contains(w[0])).toList();
        return LsTask.first(pick(known.length >= 4 ? known : words.first));
      case MdSkill.words:
        return LsTask.spell(pick(words.read.where((w) => w.length <= 4).toList()));
    }
  }
}

enum LsKind { fruit, star, berry, banana }

/// A fruit in the air.
class LsFruit {
  LsFruit({
    required this.id,
    required this.art,
    required this.kind,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.r,
    this.letter,
  });
  final int id;

  /// Its picture's name (apple, orange …).
  final String art;
  final LsKind kind;

  /// Its letter (fruits only).
  final String? letter;
  double x, y, vx, vy, angle = 0, spin;
  final double r;

  /// Sliced (gone, its halves fly), or bounced off the blade (wrong).
  bool cut = false, bounced = false;

  /// When it flew up (for its little pop as it appears).
  double born = 0;
}

enum LsPhase { ready, countdown, playing, over, done }

enum LsEventKind { countdown, go, task, cut, wrong, combo, word, star, freeze, frenzy, swish, hurry, tick, timeUp, done }

class LsEvent {
  const LsEvent(this.kind, {this.fruit, this.value = 0, this.text = '', this.angle = 0});
  final LsEventKind kind;
  final LsFruit? fruit;

  /// The points, the combo's size, seconds lost …
  final double value;
  final String text;

  /// The blade's direction when it cut (radians).
  final double angle;

  @override
  String toString() => 'LsEvent(${kind.name} $text ${value.toStringAsFixed(0)})';
}

class LsGame {
  LsGame({required this.tasks, this.height = 21, this.roundTime = 75, math.Random? random}) : _rnd = random ?? math.Random();

  final LsTasks tasks;

  /// The board's height (its width is 10): the screen's shape.
  double height;
  final double roundTime;
  final math.Random _rnd;

  static const width = 10.0;
  static const countdownTime = 3.0;

  /// The fruits' size (radius) and the arts.
  static const radius = .95;
  static const fruits = ['apple', 'orange', 'watermelon', 'lemon', 'plum', 'kiwi', 'peach'];

  /// A fruit flies up and comes down in about this long.
  static const flight = 2.7;

  /// How fast the blade must move to cut (board units a second).
  static const cutSpeed = 4.0;

  LsPhase phase = LsPhase.ready;
  double time = 0, phaseTime = 0;

  /// Seconds left in the round.
  double left = 0;

  final List<LsFruit> flying = [];
  int _ids = 0;

  /// The task now and the one before (for the card after a word), how
  /// many of its letters are sliced.
  LsTask? current, previous;
  int got = 0, done = 0;

  int score = 0, sliced = 0, wrong = 0, bestCombo = 0;

  /// Slow motion and the fruit party: until when.
  double slowUntil = -9, frenzyUntil = -9;

  /// When Pencil cheered or said oops last (his poses).
  double cheerAt = -9, oopsAt = -9;

  /// The child's needed fruits that fell unsliced in a row: they glow.
  int dropped = 0;

  final List<LsEvent> _events = [];
  double _nextThrow = 0, _nextFrenzy = 0;
  bool _berryDone = false, _bananaDone = false, _hurried = false;
  int _lastTick = 0, _count = 3;

  // the blade
  double? _bx, _by, _bt;
  int _strokeCuts = 0;

  List<LsEvent> drain() {
    final out = List<LsEvent>.of(_events);
    _events.clear();
    return out;
  }

  /// The letter to slice now.
  String? get need => current == null || got >= current!.letters.length ? null : current!.letters[got];

  bool get slow => time < slowUntil;
  bool get frenzy => time < frenzyUntil;
  bool get over => phase == LsPhase.done;

  /// 3 stars for 8 tasks, 2 for 4.
  int get stars => done >= 8 ? 3 : (done >= 4 ? 2 : 1);

  /// Gravity: a throw [flight] long reaches about 70% of the board.
  double get gravity => 8 * height * .7 / (flight * flight);

  void start() {
    phase = LsPhase.countdown;
    phaseTime = 0;
    left = roundTime;
    _events.add(const LsEvent(LsEventKind.countdown, value: 3));
  }

  // ---------------------------------------------------------------- time

  void tick(double dt) {
    if (phase == LsPhase.ready || phase == LsPhase.done) return;
    time += dt;
    phaseTime += dt;
    switch (phase) {
      case LsPhase.countdown:
        final n = 3 - phaseTime.floor();
        if (phaseTime >= countdownTime) {
          phase = LsPhase.playing;
          phaseTime = 0;
          _events.add(const LsEvent(LsEventKind.go));
          _nextTask();
          _nextThrow = time + .6;
        } else if (n != _count) {
          _count = n;
          _events.add(LsEvent(LsEventKind.countdown, value: n.toDouble()));
        }
      case LsPhase.playing:
        left = math.max(0, left - dt);
        _clock();
        if (left <= 0) {
          phase = LsPhase.over;
          phaseTime = 0;
          _events.add(const LsEvent(LsEventKind.timeUp));
        } else {
          _throws();
        }
        _fly(dt);
      case LsPhase.over:
        _fly(dt);
        if (phaseTime > 2.2 && flying.every((f) => f.y < -f.r || f.cut)) {
          phase = LsPhase.done;
          _events.add(LsEvent(LsEventKind.done, value: score.toDouble()));
        }
      default:
    }
  }

  void _clock() {
    if (left <= 10 && !_hurried) {
      _hurried = true;
      _events.add(const LsEvent(LsEventKind.hurry));
    }
    final s = left.ceil();
    if (left <= 5 && s >= 1 && s != _lastTick) {
      _lastTick = s;
      _events.add(LsEvent(LsEventKind.tick, value: s.toDouble()));
    }
  }

  /// How far into the round (0 at the start, 1 at the end).
  double get _progress => (1 - left / roundTime).clamp(0.0, 1.0);

  void _throws() {
    if (frenzy) {
      if (time >= _nextFrenzy) {
        _nextFrenzy = time + .28;
        _side();
      }
      return;
    }
    if (time < _nextThrow) return;
    final p = _progress;
    _nextThrow = time + (1.9 - .8 * p) * (.85 + _rnd.nextDouble() * .3);
    final n = 1 + _rnd.nextInt(2 + (p * 3).floor()); // 1-2 at first, up to 4-5
    final specials = <LsKind>[];
    if (!_berryDone && p > .3 && _rnd.nextDouble() < .35) {
      _berryDone = true;
      specials.add(LsKind.berry);
    } else if (!_bananaDone && p > .5 && _rnd.nextDouble() < .35) {
      _bananaDone = true;
      specials.add(LsKind.banana);
    } else if (p > .1 && _rnd.nextDouble() < .12) {
      specials.add(LsKind.star);
    }
    final labels = _labels(n);
    final xs = _spread(n + specials.length);
    for (var i = 0; i < labels.length; i++) {
      _launch(xs[i], letter: labels[i]);
    }
    for (var i = 0; i < specials.length; i++) {
      _launch(xs[labels.length + i], kind: specials[i]);
    }
  }

  /// [n] letters for a throw: the needed one at least once (twice in a
  /// big throw), the rest look-alikes and other letters.
  List<String> _labels(int n) {
    final want = need;
    if (want == null) return [for (var i = 0; i < n; i++) _other(null)];
    final out = <String>[want];
    if (n >= 4 || n >= 2 && _rnd.nextDouble() < .25) out.add(want);
    while (out.length < n) {
      out.add(_other(want));
    }
    return out..shuffle(_rnd);
  }

  /// A letter that is not [want]: a look-alike half the time.
  String _other(String? want) {
    final upper = want == null || want == want.toUpperCase();
    final alphabet = MdQuestions.alphabet;
    if (want != null && _rnd.nextBool()) {
      final like = (upper ? MdQuestions.likeCaps[want] : MdQuestions.likeSmalls[want]) ?? '';
      if (like.isNotEmpty) return like[_rnd.nextInt(like.length)];
    }
    // not a letter the word still needs (it would only confuse)
    final rest = current?.letters.substring(math.min(got, current!.letters.length)) ?? '';
    while (true) {
      final l = alphabet[_rnd.nextInt(alphabet.length)];
      final c = upper ? l.toUpperCase() : l;
      if (c != want && !rest.contains(c)) return c;
    }
  }

  /// Where [n] fruits start across the bottom: spread out, not all in a
  /// line.
  List<double> _spread(int n) {
    final xs = [for (var i = 0; i < n; i++) 1.4 + (width - 2.8) * (i + .2 + _rnd.nextDouble() * .6) / n];
    return xs..shuffle(_rnd);
  }

  void _launch(double x, {String? letter, LsKind kind = LsKind.fruit}) {
    final apex = height * (.5 + _rnd.nextDouble() * .3);
    final g = gravity;
    final vy = math.sqrt(2 * g * apex);
    final t = 2 * vy / g;
    // it lands somewhere on the board, leaning to the middle
    final land = (width / 2 + (x - width / 2) * -.4 + (_rnd.nextDouble() - .5) * 3).clamp(1.0, width - 1);
    final f = LsFruit(
      id: _ids++,
      art: switch (kind) {
        LsKind.star => 'star',
        LsKind.berry => 'berry',
        LsKind.banana => 'banana',
        LsKind.fruit => fruits[_rnd.nextInt(fruits.length)],
      },
      kind: kind,
      letter: letter,
      x: x,
      y: -radius,
      vx: (land - x) / t,
      vy: vy,
      spin: (_rnd.nextDouble() - .5) * 3,
      r: radius * (kind == LsKind.fruit ? 1 : .85),
    )..born = time;
    flying.add(f);
  }

  /// The fruit party: fruits with the needed letter from the sides.
  void _side() {
    final left = _rnd.nextBool();
    final y = height * (.15 + _rnd.nextDouble() * .3);
    final f = LsFruit(
      id: _ids++,
      art: fruits[_rnd.nextInt(fruits.length)],
      kind: LsKind.fruit,
      letter: need ?? _other(null),
      x: left ? -radius : width + radius,
      y: y,
      vx: (left ? 1 : -1) * (4.5 + _rnd.nextDouble() * 2),
      vy: math.sqrt(2 * gravity * height * .35) * (.8 + _rnd.nextDouble() * .3),
      spin: (_rnd.nextDouble() - .5) * 4,
      r: radius,
    )..born = time;
    flying.add(f);
  }

  void _fly(double dt) {
    final k = slow ? .4 : 1.0;
    final d = dt * k;
    for (final f in flying) {
      f.vy -= gravity * d;
      f.x += f.vx * d;
      f.y += f.vy * d;
      f.angle += f.spin * d;
    }
    flying.removeWhere((f) {
      final gone = f.cut || f.y < -f.r * 2 && f.vy < 0 || f.x < -f.r * 3 || f.x > width + f.r * 3;
      if (gone && !f.cut && f.letter != null && f.letter == need && !f.bounced) dropped++;
      return gone;
    });
  }

  // ---------------------------------------------------------------- tasks

  void _nextTask() {
    previous = current;
    current = tasks.next(done);
    got = 0;
    dropped = 0;
    _events.add(LsEvent(LsEventKind.task, text: current!.letters));
  }

  // ---------------------------------------------------------------- the blade

  /// The finger touches the board at ([x], [y]).
  void bladeDown(double x, double y) {
    _bx = x;
    _by = y;
    _bt = time;
    _strokeCuts = 0;
  }

  /// The finger moved to ([x], [y]): what it went through is sliced (when
  /// it moves fast enough: a swipe, not a press).
  void bladeMove(double x, double y, {double? dt}) {
    final px = _bx, py = _by, pt = _bt;
    _bx = x;
    _by = y;
    _bt = time;
    if (px == null || py == null || pt == null || phase != LsPhase.playing && phase != LsPhase.over) return;
    final len = math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
    final took = dt ?? math.max(time - pt, 1 / 120);
    if (len < 1e-6 || len / took < cutSpeed) return;
    if (len > .5) _events.add(LsEvent(LsEventKind.swish, value: math.min(1, len / took / 30)));
    final angle = math.atan2(y - py, x - px);
    for (final f in [...flying]) {
      if (f.cut || f.bounced) continue;
      if (_segmentHits(px, py, x, y, f.x, f.y, f.r * .92)) _slice(f, angle);
    }
  }

  /// The finger lifts: the stroke's combo is counted.
  void bladeUp() {
    if (_strokeCuts >= 3) {
      final bonus = 10 * _strokeCuts;
      score += bonus;
      bestCombo = math.max(bestCombo, _strokeCuts);
      _events.add(LsEvent(LsEventKind.combo, value: _strokeCuts.toDouble(), text: '+$bonus'));
    }
    _bx = _by = _bt = null;
    _strokeCuts = 0;
  }

  static bool _segmentHits(double ax, double ay, double bx, double by, double cx, double cy, double r) {
    final dx = bx - ax, dy = by - ay;
    final l2 = dx * dx + dy * dy;
    final t = l2 == 0 ? 0.0 : (((cx - ax) * dx + (cy - ay) * dy) / l2).clamp(0.0, 1.0);
    final px = ax + dx * t - cx, py = ay + dy * t - cy;
    return px * px + py * py <= r * r;
  }

  void _slice(LsFruit f, double angle) {
    switch (f.kind) {
      case LsKind.star:
        f.cut = true;
        score += 50;
        cheerAt = time;
        _events.add(LsEvent(LsEventKind.star, fruit: f, value: 50, angle: angle));
        return;
      case LsKind.berry:
        f.cut = true;
        slowUntil = time + 4;
        _events.add(LsEvent(LsEventKind.freeze, fruit: f, angle: angle));
        return;
      case LsKind.banana:
        f.cut = true;
        frenzyUntil = time + 3.5;
        _nextFrenzy = time;
        _events.add(LsEvent(LsEventKind.frenzy, fruit: f, angle: angle));
        return;
      case LsKind.fruit:
        break;
    }
    final want = need;
    if (want != null && f.letter == want) {
      f.cut = true;
      got++;
      sliced++;
      dropped = 0;
      _strokeCuts++;
      final points = 10;
      score += points;
      cheerAt = time;
      _events.add(LsEvent(LsEventKind.cut, fruit: f, value: points.toDouble(), text: f.letter!, angle: angle));
      if (got >= current!.letters.length) {
        final bonus = 10 * current!.letters.length;
        score += bonus;
        done++;
        _events.add(LsEvent(LsEventKind.word, value: bonus.toDouble(), text: current!.word ?? current!.letters[0]));
        _nextTask();
      }
    } else {
      // the wrong letter: it bounces off the blade
      f.bounced = true;
      wrong++;
      oopsAt = time;
      _strokeCuts = 0;
      f.vx += math.cos(angle) * 3;
      f.vy = math.max(f.vy, 0) + 3;
      f.spin = (f.spin.sign == 0 ? 1 : f.spin.sign) * 9;
      // a letter not in the task at all costs two seconds
      final lose = current != null && !current!.letters.contains(f.letter!) ? 2.0 : 0.0;
      if (phase == LsPhase.playing) left = math.max(0, left - lose);
      _events.add(LsEvent(LsEventKind.wrong, fruit: f, value: lose, text: f.letter!, angle: angle));
    }
  }
}
