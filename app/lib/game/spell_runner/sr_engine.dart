import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../monster_defense/md_questions.dart';

/// Spell Runner, the game itself (no drawing): Pencil rides his skateboard
/// down an endless road with three lanes. Rows of letter bubbles come
/// towards him; the child moves him into the lane with the letter the word
/// needs next (c, then a, then t), and jumps over puddles, logs and rocks.
/// Every bubble ahead always shows the letter needed now, so a missed one
/// simply comes again.
///
/// Like Subway Surfers the run never ends by itself: the further he goes,
/// the longer the words (3 letters, then 4, 5, 6), the faster the road and
/// the more things in the way. Each bump costs one of his three hearts
/// (hearts lie on the road now and then); the third ends the run. World
/// units: z is the distance ahead of Pencil along the road; [SrGame.dist] is
/// how far he has come.

/// What the child spells: a word (with its picture), or a hunt for one
/// letter a few times (before reading).
@immutable
class SrTask {
  const SrTask({required this.letters, required this.say, required this.audio, this.word, this.picture, this.done, this.doneAudio});

  /// The letters to catch, in order ("cat", or "BBB" for a hunt).
  final String letters;

  /// The word, for a spelling task (null for a hunt).
  final String? word;

  /// What Pencil says (his bubble), its recording, the picture.
  final String say, audio;
  final String? picture;

  /// What he says when it is done ("Cat! C, A, T!"), and its recording.
  final String? done, doneAudio;

  bool get hunt => word == null;

  static String _voice(String id) => 'assets/voice/$id.m4a';

  factory SrTask.spell(String word) => SrTask(
    letters: word,
    word: word,
    say: 'Spell $word!',
    audio: _voice('sr_spell_$word'),
    picture: MdWords.picture(word),
    done: '${word[0].toUpperCase()}${word.substring(1)}! ${word.toUpperCase().split('').join(', ')}!',
    doneAudio: _voice('sr_word_$word'),
  );

  factory SrTask.hunt(String letter, {required bool small, int times = 3}) => SrTask(
    letters: letter * times,
    say: small ? 'Catch small $letter!' : 'Catch $letter!',
    audio: _voice(small ? 'sr_catch_small_$letter' : 'sr_catch_${letter.toLowerCase()}'),
  );
}

/// Where the tasks come from, endlessly: task [done] (0, 1, 2 …) is asked
/// after [done] finished ones.
abstract class SrTasks {
  SrTask next(int done);

  /// How hard task [done] is (0 easiest), for the road's speed and bumps.
  int stage(int done);

  /// The tasks for a child: words to spell once they read, else small
  /// letters to catch, else capitals.
  static SrTasks forChild(MdKnowledge k, MdWords words, math.Random r) {
    if (k.words) return SrSpelling(words, r);
    if (k.smalls.length >= 3) return SrHunting(k.smalls, small: true, random: r);
    return SrHunting(k.capitals, small: false, random: r);
  }
}

/// Fixed tasks, over and over (tests, the preview).
class SrList implements SrTasks {
  SrList(this.tasks);
  final List<SrTask> tasks;

  @override
  SrTask next(int done) => tasks[done % tasks.length];

  @override
  int stage(int done) => done ~/ 3;
}

/// Words to spell, longer as the run goes on: 3 letters for the first
/// [three] words, then 4, then 5, then 5 and 6. A word is not asked again
/// soon.
class SrSpelling implements SrTasks {
  SrSpelling(MdWords words, this._rnd) : _all = {...words.read, ...words.long}.toList();

  final math.Random _rnd;
  final List<String> _all;
  final List<String> _recent = [];

  static const three = 4, four = 9, five = 15;

  /// The words' length for task [done].
  int length(int done) => done < three ? 3 : (done < four ? 4 : (done < five ? 5 : 5 + _rnd.nextInt(2)));

  @override
  int stage(int done) => done < three ? 0 : (done < four ? 1 : (done < five ? 2 : 3 + (done - five) ~/ 6));

  @override
  SrTask next(int done) {
    final n = length(done);
    var pool = _all.where((w) => w.length == n && !_recent.contains(w)).toList();
    if (pool.isEmpty) pool = _all.where((w) => w.length == n).toList();
    final w = pool[_rnd.nextInt(pool.length)];
    _recent.add(w);
    if (_recent.length > 12) _recent.removeAt(0);
    return SrTask.spell(w);
  }
}

/// Letters to catch (before reading): a new letter each time, caught three
/// times, four once the child is going well; the road gets faster.
class SrHunting implements SrTasks {
  SrHunting(List<String> letters, {required this.small, math.Random? random}) : _letters = letters.isEmpty ? MdKnowledge.starters : letters, _rnd = random ?? math.Random();

  final List<String> _letters;
  final bool small;
  final math.Random _rnd;
  String? _last;

  @override
  int stage(int done) => done ~/ 3;

  @override
  SrTask next(int done) {
    final pool = _letters.where((l) => l != _last).toList();
    final l = pool.isEmpty ? _letters.first : pool[_rnd.nextInt(pool.length)];
    _last = l;
    return SrTask.hunt(small ? l.toLowerCase() : l.toUpperCase(), small: small, times: done < 6 ? 3 : 4);
  }
}

enum SrKind { letter, coin, heart, puddle, log, rock, hay, cone, banana, ramp, bar, banner, branch, cart, bench, flowerbox, magnet, shield, spring, double }

extension SrKindX on SrKind {
  /// Things in the way: a bump unless he jumps (or, under a high one,
  /// slides).
  bool get obstacle => switch (this) {
    SrKind.puddle || SrKind.log || SrKind.rock || SrKind.hay || SrKind.cone || SrKind.banana => true,
    SrKind.bar || SrKind.banner || SrKind.branch || SrKind.cart || SrKind.bench || SrKind.flowerbox => true,
    _ => false,
  };

  /// A high thing: he slides under it (jumping into it is a bump, unless
  /// the spring shoes take him over it).
  bool get high => this == SrKind.bar || this == SrKind.banner || this == SrKind.branch;

  /// A thing that fills its lane: he goes around it (only the spring shoes
  /// take him over it).
  bool get blocker => this == SrKind.cart;

  /// A power-up to pick up: it works for a while ([SrGame.powerTime]).
  bool get power => switch (this) {
    SrKind.magnet || SrKind.shield || SrKind.spring || SrKind.double => true,
    _ => false,
  };

  /// Slippery things make him skid instead of bump.
  bool get slippery => this == SrKind.puddle || this == SrKind.banana;
}

class SrThing {
  SrThing({required this.id, required this.kind, required this.lane, required this.z, this.label = '', this.row = -1});
  final int id;
  final SrKind kind;

  /// -1 left, 0 middle, 1 right.
  final int lane;

  /// Where on the road (world units from the start).
  final double z;

  /// A bubble's letter (it changes when the word needs another).
  String label;

  /// The bubble row it belongs to (-1 for other things).
  final int row;

  /// Taken (a bubble, coin or heart), cleared (jumped), bumped.
  bool taken = false, cleared = false, bumped = false;

  /// Seconds since its letter last changed (the app pops it).
  double relabeled = 99;
}

enum SrPhase { ready, countdown, running, over, done }

enum SrEventKind { countdown, go, task, letter, wrong, word, longer, coin, heart, jump, land, ramp, bump, skid, cleared, crash, done, move, slide, power, powerEnd, shielded, zone }

class SrEvent {
  const SrEvent(this.kind, {this.thing, this.value = 0, this.text = ''});
  final SrEventKind kind;
  final SrThing? thing;
  final int value;
  final String text;

  @override
  String toString() => 'SrEvent(${kind.name} $value $text)';
}

class SrGame {
  SrGame({required this.tasks, math.Random? random}) : _rnd = random ?? math.Random();

  final SrTasks tasks;
  final math.Random _rnd;

  // the road
  static const view = 72.0; // how far ahead things are placed
  static const hitBand = .9; // how near (z) a thing touches Pencil

  // speeds (world units a second): faster each stage
  static const startSpeed = 8.5, topSpeed = 14.5, perStage = 1.1;

  // a jump
  static const jumpTime = .78, rampTime = 1.25;

  // a slide (as long at any speed, like a jump)
  static const slideTime = .8;

  /// How long each power-up works (the shield also ends at its bump).
  static const powerTime = {SrKind.magnet: 9.0, SrKind.shield: 14.0, SrKind.spring: 9.0, SrKind.double: 10.0};

  /// A new part of the road (its trees, its light) every this many metres.
  static const zoneMetres = 500;

  // timings
  static const countdownTime = 3.2, overTime = 2.2, safeTime = 1.8;

  /// Hearts at the start (and at most).
  static const hearts0 = 3;

  /// World units to a metre shown on the screen.
  static const metre = .5;

  SrPhase phase = SrPhase.ready;
  double phaseTime = 0;

  double dist = 0, speed = 0;

  /// The lane he is in (-1..1, moving smoothly) and the one he is going to.
  double lane = 0;
  int targetLane = 0;

  /// Seconds into a jump (null on the ground), and how long it lasts.
  double? jumpAt;
  double jumpLen = jumpTime;

  /// Seconds left of a stumble (slow, wobbling), of a boost, and of being
  /// safe after a bump (he blinks, nothing bumps him).
  double stumble = 0, boost = 0, safe = 0;

  /// Seconds since a word was finished (he cheers).
  double cheer = 99;

  int hearts = hearts0;

  /// Tasks finished, and the letters caught of the one now.
  int done = 0, got = 0;
  int score = 0, coins = 0, wrong = 0, bumps = 0, combo = 0, bestCombo = 0;

  /// The task being spelled, and the one finished last.
  SrTask? current, previous;

  final List<SrThing> things = [];
  int _ids = 0, _rows = 0;
  double _cursor = 0; // the road is laid up to here
  double _scored = 0; // metres already counted in the score
  final List<SrEvent> _events = [];

  /// How hard the road is now (see SrTasks.stage).
  int get stage => tasks.stage(done);

  /// How far he has come, in metres.
  int get metres => (dist * metre).floor();

  /// The letter needed now.
  String? get need {
    final t = current;
    return t == null || got >= t.letters.length ? null : t.letters[got];
  }

  /// How high he is in a jump (0 on the ground, 1 at the top).
  double get air {
    final j = jumpAt;
    if (j == null) return 0;
    return math.sin(math.pi * (j / jumpLen).clamp(0.0, 1.0)) * (_ramped ? 1.35 : 1) * (has(SrKind.spring) ? 1.6 : 1);
  }

  bool get airborne => air > .2;

  /// Seconds into a slide (null when not sliding), and how long it lasts.
  double? slideAt;
  double slideLen = slideTime;

  bool get sliding => slideAt != null;

  /// The power-ups working now, and the seconds each has left.
  final Map<SrKind, double> powers = {};

  bool has(SrKind power) => (powers[power] ?? 0) > 0;

  /// Which part of the road he is in (0, 1, 2, … every [zoneMetres]).
  int get zone => metres ~/ zoneMetres;
  int _zone = 0;

  /// Points, twice as many with the 2x power-up.
  void _add(int points) => score += has(SrKind.double) ? points * 2 : points;

  /// Stars for a run: one, two after 6 tasks, three after 14.
  int get stars => done >= 14 ? 3 : (done >= 6 ? 2 : 1);

  List<SrEvent> drain() {
    final out = List<SrEvent>.of(_events);
    _events.clear();
    return out;
  }

  void _emit(SrEventKind k, {SrThing? thing, int value = 0, String text = ''}) => _events.add(SrEvent(k, thing: thing, value: value, text: text));

  void _setPhase(SrPhase p) {
    phase = p;
    phaseTime = 0;
  }

  // ------------------------------------------------------------ the child

  /// Starts the countdown (after Pencil's introduction).
  void start() {
    if (phase != SrPhase.ready) return;
    current = tasks.next(0);
    _cursor = 18;
    _lastCount = 3;
    _lay();
    _setPhase(SrPhase.countdown);
    _emit(SrEventKind.countdown, value: 3);
  }

  /// One lane left (-1) or right (1).
  void move(int dir) => moveTo(targetLane + dir);

  /// Into lane [l] (-1..1).
  void moveTo(int l) {
    if (phase != SrPhase.running && phase != SrPhase.countdown) return;
    final to = l.clamp(-1, 1);
    if (to == targetLane) return;
    targetLane = to;
    _emit(SrEventKind.move, value: to);
  }

  /// A jump covers the same stretch of road at any speed (quicker when he
  /// is fast). Pressed just before landing, it jumps again on landing.
  void jump({bool ramp = false}) {
    if (phase != SrPhase.running) return;
    slideAt = null; // up from a slide
    final j = jumpAt;
    if (j != null && !ramp) {
      if (jumpLen - j < .3) _queued = true;
      return;
    }
    final quick = math.min(1.0, startSpeed / math.max(speed, 1));
    jumpAt = 0;
    jumpLen = (ramp ? rampTime : jumpTime) * math.max(.62, quick) * (has(SrKind.spring) ? 1.35 : 1);
    _ramped = ramp;
    _emit(ramp ? SrEventKind.ramp : SrEventKind.jump);
  }

  bool _queued = false, _ramped = false;

  /// The jump now came off a ramp (a big one).
  bool get ramped => _ramped;

  /// Down flat on the board, under high things. In the air, he drops to
  /// the road at once and slides.
  void slide() {
    if (phase != SrPhase.running) return;
    if (jumpAt != null) {
      jumpAt = null;
      _queued = false;
      _emit(SrEventKind.land);
    }
    final quick = math.min(1.0, startSpeed / math.max(speed, 1));
    slideAt = 0;
    slideLen = slideTime * math.max(.7, quick);
    _emit(SrEventKind.slide);
  }

  // ------------------------------------------------------------ time

  void tick(double dt) {
    if (dt <= 0) return;
    dt = math.min(dt, .1);
    phaseTime += dt;
    cheer += dt;
    for (final t in things) {
      t.relabeled += dt;
    }
    switch (phase) {
      case SrPhase.ready || SrPhase.done:
        return;
      case SrPhase.countdown:
        _steer(dt);
        final left = 3 - phaseTime.floor();
        if (left < _lastCount && left >= 1) _emit(SrEventKind.countdown, value: left);
        _lastCount = left;
        if (phaseTime >= countdownTime) {
          _setPhase(SrPhase.running);
          speed = startSpeed * .7;
          _emit(SrEventKind.go);
          _emit(SrEventKind.task);
        }
      case SrPhase.running:
        _run(dt);
      case SrPhase.over:
        // he tumbles and rolls to a stop
        speed = math.max(0, speed - dt * speed * 2.2);
        dist += speed * dt;
        _air(dt);
        if (phaseTime >= overTime) {
          _setPhase(SrPhase.done);
          _emit(SrEventKind.done);
        }
    }
  }

  int _lastCount = 3;

  void _steer(double dt) {
    final d = targetLane - lane;
    lane += d.sign * math.min(d.abs(), dt * 7);
  }

  void _air(double dt) {
    final j = jumpAt;
    if (j == null) return;
    jumpAt = j + dt;
    if (jumpAt! >= jumpLen) {
      jumpAt = null;
      _emit(SrEventKind.land);
      if (_queued) {
        _queued = false;
        jump();
      }
    }
  }

  void _slide(double dt) {
    final s = slideAt;
    if (s == null) return;
    slideAt = s + dt;
    if (slideAt! >= slideLen) slideAt = null;
  }

  void _run(double dt) {
    // speed: up each stage, slowed by a stumble, pushed by a boost
    final target = math.min(topSpeed, startSpeed + stage * perStage) * (stumble > 0 ? .45 : 1) * (boost > 0 ? 1.4 : 1);
    speed += (target - speed) * math.min(1, dt * (stumble > 0 ? 6 : 1.6));
    stumble = math.max(0, stumble - dt);
    boost = math.max(0, boost - dt);
    safe = math.max(0, safe - dt);
    for (final k in powers.keys.toList()) {
      powers[k] = powers[k]! - dt;
      if (powers[k]! <= 0) {
        powers.remove(k);
        _emit(SrEventKind.powerEnd, text: k.name);
      }
    }
    dist += speed * dt;
    if (zone != _zone) {
      _zone = zone;
      _emit(SrEventKind.zone, value: zone);
    }
    // a point a metre
    final m = dist * metre;
    if (m - _scored >= 1) {
      _add((m - _scored).floor());
      _scored += (m - _scored).floor();
    }
    _steer(dt);
    _air(dt);
    _slide(dt);
    _lay();
    _touch();
    things.removeWhere((t) => t.z < dist - 8);
  }

  // ------------------------------------------------------------ the road

  /// Letter rows come closer together as the stages go on.
  double get _rowGap => math.max(17.0, 23.0 - stage * 1.2);

  /// Lays rows ahead: letter bubbles, with things in the way and lines of
  /// coins (or a heart) between them; more things, and in two lanes, as
  /// the stages go on.
  void _lay() {
    while (_cursor < dist + view) {
      final rowZ = _cursor;
      final row = _rows++;
      final gap = _rowGap;
      for (final l in [-1, 0, 1]) {
        things.add(SrThing(id: ++_ids, kind: SrKind.letter, lane: l, z: rowZ, row: row));
      }
      _label(row);
      final early = row < 2;
      final mid = rowZ + gap / 2;
      final busy = math.min(.92, .6 + stage * .08);
      if (!early && _rnd.nextDouble() < busy) {
        final kinds = [
          SrKind.puddle,
          SrKind.log,
          SrKind.rock,
          SrKind.hay,
          SrKind.cone,
          SrKind.banana,
          SrKind.bench,
          SrKind.flowerbox,
          if (stage >= 1) ...[SrKind.bar, SrKind.banner, SrKind.branch],
          if (stage >= 2) SrKind.cart,
        ];
        final lanes = [-1, 0, 1]..shuffle(_rnd);
        final two = row > 5 && _rnd.nextDouble() < math.min(.6, .2 + stage * .1);
        things.add(SrThing(id: ++_ids, kind: kinds[_rnd.nextInt(kinds.length)], lane: lanes[0], z: mid));
        if (two) things.add(SrThing(id: ++_ids, kind: kinds[_rnd.nextInt(kinds.length)], lane: lanes[1], z: mid));
        if (!two && _rnd.nextDouble() < .25) things.add(SrThing(id: ++_ids, kind: SrKind.ramp, lane: lanes[1], z: mid));
        // later on, a second bump before the next letters, in a lane the
        // first ones left free (never two in a row he cannot jump)
        if (stage >= 2 && !two && _rnd.nextDouble() < math.min(.5, stage * .1)) {
          things.add(SrThing(id: ++_ids, kind: kinds[_rnd.nextInt(kinds.length)], lane: lanes[2], z: rowZ + gap * .86));
        }
        _treats(lanes[2], rowZ + 3, 3);
        _maybePower(row, lanes[2], rowZ + gap * .62);
      } else {
        _treats(_rnd.nextInt(3) - 1, rowZ + 4, 4);
      }
      _cursor += gap;
    }
  }

  /// Now and then (after the first rows, never too close together) a
  /// power-up in a free lane.
  void _maybePower(int row, int lane, double z) {
    if (row < 5 || row - _powerRow < 4 || _rnd.nextDouble() > .22) return;
    _powerRow = row;
    const kinds = [SrKind.magnet, SrKind.shield, SrKind.spring, SrKind.double];
    things.add(SrThing(id: ++_ids, kind: kinds[_rnd.nextInt(kinds.length)], lane: lane, z: z));
  }

  int _powerRow = -9;

  /// A line of coins in [lane] from [z] (now and then a heart instead when
  /// he has lost one).
  void _treats(int lane, double z, int n) {
    if (hearts < hearts0 && _rnd.nextDouble() < .14) {
      things.add(SrThing(id: ++_ids, kind: SrKind.heart, lane: lane, z: z + 1.6));
      return;
    }
    for (var k = 0; k < n; k++) {
      things.add(SrThing(id: ++_ids, kind: SrKind.coin, lane: lane, z: z + k * 1.6));
    }
  }

  /// Puts the letter needed now in one lane of bubble row [row] and look-alike
  /// letters in the others.
  void _label(int row) {
    final n = need;
    final bubbles = things.where((t) => t.row == row && !t.taken).toList();
    if (n == null || bubbles.isEmpty) return;
    final right = bubbles[_rnd.nextInt(bubbles.length)];
    final used = {n.toLowerCase()};
    for (final b in bubbles) {
      final before = b.label;
      if (b == right) {
        b.label = n;
      } else {
        b.label = _lookAlike(n, used);
        used.add(b.label.toLowerCase());
      }
      if (before.isNotEmpty && before != b.label) b.relabeled = 0;
    }
  }

  /// A wrong letter that looks like [n] (or any other letter); look-alikes
  /// more often as the stages go on.
  String _lookAlike(String n, Set<String> used) {
    final upper = n == n.toUpperCase();
    final like = (upper ? MdQuestions.likeCaps[n] : MdQuestions.likeSmalls[n]) ?? '';
    final options = [
      ...like.split('').where((l) => l.isNotEmpty),
      ...MdQuestions.alphabet.split('').map((l) => upper ? l.toUpperCase() : l),
    ].where((l) => !used.contains(l.toLowerCase())).toList();
    final tricky = _rnd.nextDouble() < math.min(.85, .35 + stage * .12);
    return like.isNotEmpty && tricky ? options.first : options[_rnd.nextInt(options.length)];
  }

  /// Every row still ahead (not about to be reached) shows the letter needed
  /// now; rows a few steps away keep theirs so nothing changes under him.
  void _relabelAhead() {
    final rows = {for (final t in things) if (t.row >= 0 && t.z - dist > 5) t.row};
    for (final r in rows) {
      _label(r);
    }
  }

  // ------------------------------------------------------------ touching

  void _touch() {
    final mine = lane.round();
    for (final t in [...things]) {
      if (phase != SrPhase.running) return;
      if (t.taken || t.cleared || t.bumped) continue;
      final dz = t.z - dist;
      if (dz > hitBand || dz < -hitBand) continue;
      // in that lane (well into it when moving across)
      final here = (lane - t.lane).abs() < (t.kind.obstacle ? .35 : .5) && t.lane == mine;
      switch (t.kind) {
        case SrKind.letter:
          if (!here || t.label.isEmpty || airborne || need == null) continue;
          _letter(t);
        case SrKind.coin:
          // the magnet pulls in the coins of every lane
          if (!here && !(has(SrKind.magnet) && dz < .6)) continue;
          t.taken = true;
          coins++;
          _add(10);
          _emit(SrEventKind.coin, thing: t);
        case SrKind.heart:
          if (!here) continue;
          t.taken = true;
          hearts = math.min(hearts0, hearts + 1);
          _emit(SrEventKind.heart, thing: t, value: hearts);
        case SrKind.magnet || SrKind.shield || SrKind.spring || SrKind.double:
          if (!here) continue;
          t.taken = true;
          powers[t.kind] = powerTime[t.kind]!;
          _add(50);
          _emit(SrEventKind.power, thing: t, text: t.kind.name);
        case SrKind.ramp:
          if (!here || airborne) continue;
          t.cleared = true;
          _add(50);
          jump(ramp: true);
        default:
          // a bump only when he really reaches it (a jump just in time counts)
          if (!t.kind.obstacle || !here || dz > .4) continue;
          final over = airborne && has(SrKind.spring);
          if (t.kind.high ? sliding || over : (t.kind.blocker ? over : airborne)) {
            if (dz < 0) {
              t.cleared = true;
              _add(25);
              _emit(SrEventKind.cleared, thing: t);
            }
            continue;
          }
          if (safe > 0) continue; // just bumped: he rolls through
          if (has(SrKind.shield)) {
            // the shield takes the bump and breaks the thing
            powers.remove(SrKind.shield);
            t.cleared = true;
            safe = 1;
            _emit(SrEventKind.shielded, thing: t);
            continue;
          }
          t.bumped = true;
          bumps++;
          combo = 0;
          hearts--;
          stumble = t.kind.slippery ? .8 : 1.1;
          safe = safeTime;
          _emit(t.kind.slippery ? SrEventKind.skid : SrEventKind.bump, thing: t, value: hearts);
          if (hearts <= 0) {
            _setPhase(SrPhase.over);
            _emit(SrEventKind.crash);
          }
      }
    }
  }

  void _letter(SrThing t) {
    final row = things.where((o) => o.row == t.row);
    for (final o in row) {
      o.taken = true; // the others pop away
    }
    if (t.label != need) {
      wrong++;
      combo = 0;
      stumble = math.max(stumble, .35);
      _emit(SrEventKind.wrong, thing: t, text: t.label);
      return;
    }
    got++;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    _add(100 + 20 * math.min(5, combo - 1));
    _emit(SrEventKind.letter, thing: t, value: got - 1, text: t.label);
    final task0 = current!;
    if (got >= task0.letters.length) {
      // the task is done: a boost, the next one (maybe longer)
      final was = stage;
      cheer = 0;
      boost = 1.8;
      _add(100 + 50 * task0.letters.length);
      done++;
      previous = task0;
      _emit(SrEventKind.word, text: task0.word ?? task0.letters[0]);
      got = 0;
      current = tasks.next(done);
      if (stage > was && !task0.hunt && current!.letters.length > task0.letters.length) _emit(SrEventKind.longer, value: current!.letters.length);
      _emit(SrEventKind.task);
    }
    _relabelAhead();
  }
}
