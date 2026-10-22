import 'dart:math' as math;

import 'md_questions.dart';

/// Monster Defense, the game itself (no drawing): silly monsters walk down
/// the path from the cave to Pencil's garden gate carrying letters or words.
/// Pencil asks a question; tapping the monster with the answer catches it in
/// a magic bubble (the others in its group run back to the cave), a wrong
/// tap makes that monster roar and jump closer. A monster that reaches the
/// gate costs a heart; three hearts lost ends the game.
///
/// Waves: three of monster groups, then Big Bonk, the boss, who carries no
/// letters: the choices float above him in balloons and he needs three
/// catches. Stone Bonks need two catches (the first cracks their bubble and
/// Pencil asks again), fluffy Fuzz runs fast, Boo the ghost drifts from side
/// to side.
///
/// [tick] moves time on, [tap] / [tapBalloon] are the child's taps, [drain]
/// gives what happened since the last call (sounds, lines, effects).

enum MdKind { gloop, fuzz, bonk, boo, boss }

/// What a monster is doing.
enum MdMood {
  /// on its way to the gate (the only time it moves forward)
  walking,

  /// a wrong tap, or it reached the gate: a silly roar
  roaring,

  /// the bubble broke (a Bonk's first catch, every boss catch): dizzy
  cracked,

  /// in Pencil's bubble, floating up
  trapped,

  /// the bubble popped: a friend now, waving, then gone
  friendly,

  /// running back to the cave
  fleeing,
  gone,
}

enum MdPhase { ready, banner, playing, bossIntro, won, lost }

enum MdEventKind { banner, bossIntro, question, spawn, hit, crack, trapped, popped, miss, hint, hurry, gate, power, freeze, potion, bossHit, won, lost }

class MdEvent {
  const MdEvent(this.kind, {this.monster, this.value = 0});
  final MdEventKind kind;
  final int? monster;

  /// banner: the wave (0-based); hit: points; power: 0 freeze, 1 potion.
  final int value;

  @override
  String toString() => 'MdEvent(${kind.name}${monster == null ? '' : ' #$monster'} $value)';
}

enum MdTap { ignored, right, cracked, wrong }

class MdMonster {
  MdMonster({required this.id, required this.kind, required this.label, required this.u, required this.lane, required this.speed, this.hp = 1});
  final int id;
  final MdKind kind;

  /// The letter or word it carries ('' for the boss).
  String label;

  /// How far along the path: 0 the cave, 1 the gate (below 0: still inside).
  double u;

  /// Across the path: -1 left edge .. 1 right edge.
  double lane;
  final double speed;
  int hp;

  MdMood mood = MdMood.walking;

  /// Seconds in [mood], and since it came out.
  double moodTime = 0, age = 0;

  bool get tappable => mood == MdMood.walking || mood == MdMood.roaring;
  bool get alive => mood != MdMood.gone;
  bool get out => u >= 0;

  /// Boo drifts from side to side.
  double get drift => kind == MdKind.boo ? .55 * math.sin(age * 1.9 + id) : 0;
}

/// One wave: its groups, each a list of monsters walking together.
class MdWave {
  const MdWave(this.groups, {required this.seconds});
  final List<List<MdKind>> groups;

  /// How long a monster at speed 1 takes from the cave to the gate.
  final double seconds;
}

class MdGame {
  MdGame({required this.questions, math.Random? random, List<MdWave>? waves, this.bossHp = 3, this.bossSeconds = 34}) : _rnd = random ?? math.Random(), waves = waves ?? standardWaves;

  final MdQuestionSource questions;
  final math.Random _rnd;
  final List<MdWave> waves;
  final int bossHp;
  final double bossSeconds;

  static const standardWaves = [
    MdWave([
      [MdKind.gloop, MdKind.gloop],
      [MdKind.gloop, MdKind.fuzz],
      [MdKind.fuzz, MdKind.gloop],
    ], seconds: 20),
    MdWave([
      [MdKind.gloop, MdKind.fuzz, MdKind.gloop],
      [MdKind.boo, MdKind.gloop],
      [MdKind.fuzz, MdKind.boo, MdKind.gloop],
    ], seconds: 17),
    MdWave([
      [MdKind.bonk, MdKind.gloop],
      [MdKind.fuzz, MdKind.boo, MdKind.gloop],
      [MdKind.bonk, MdKind.fuzz, MdKind.boo],
      [MdKind.gloop, MdKind.fuzz, MdKind.bonk],
    ], seconds: 15),
  ];

  static const hearts0 = 3;
  static const bannerTime = 2.2, bossIntroTime = 3.2, gapTime = 1.1;
  static const freezeTime = 4.5;

  /// A monster is close (the music gets tense) past [danger]; Pencil says
  /// "Hurry!" past [hurryAt].
  static const danger = .62, hurryAt = .74;

  MdPhase phase = MdPhase.ready;
  double _phaseTime = 0;

  /// Seconds in [phase].
  double get phaseTime => _phaseTime;

  /// The wave being played (waves.length = the boss).
  int wave = 0;
  int _group = 0; // the next group of the wave

  int hearts = hearts0;
  int score = 0;
  int combo = 0, bestCombo = 0;
  int caught = 0, misses = 0;

  /// Power-ups waiting to be used.
  int freezes = 0, potions = 0;

  /// Seconds the monsters stay frozen.
  double frozen = 0;

  /// Right answers left with double points.
  int doubled = 0;

  final List<MdMonster> monsters = [];
  int _ids = 0;

  /// The question being asked, and the monsters it is asked about.
  MdQuestion? question;
  List<MdMonster> _active = [];
  int _questionMisses = 0;
  bool _hurried = false;

  /// After two misses the right monster (or balloon) glows.
  bool hint = false;

  double _wait = 0; // until the next group comes
  double _end = 0; // until the game is won / lost
  MdPhase? _ending;

  final List<MdEvent> _events = [];

  bool get isBoss => wave >= waves.length;
  MdMonster? get boss => monsters.where((m) => m.kind == MdKind.boss && m.alive).firstOrNull;

  /// Stars for the game: one per heart left (at least one for winning).
  int get stars => phase == MdPhase.won ? math.max(1, hearts) : 0;

  /// The monster closest to the gate among those asked about (0 when none).
  double get closest => _active.where((m) => m.mood == MdMood.walking).fold(0.0, (a, m) => math.max(a, m.u));
  bool get inDanger => phase == MdPhase.playing && frozen <= 0 && closest > danger;

  /// The boss's balloons: the choices while he is being asked about.
  List<String> get balloons => isBoss && boss != null && boss!.mood != MdMood.trapped && boss!.mood != MdMood.friendly ? (question?.choices ?? const []) : const [];

  List<MdEvent> drain() {
    final out = List<MdEvent>.of(_events);
    _events.clear();
    return out;
  }

  void _emit(MdEventKind k, {int? monster, int value = 0}) => _events.add(MdEvent(k, monster: monster, value: value));

  void _setPhase(MdPhase p) {
    phase = p;
    _phaseTime = 0;
  }

  // ------------------------------------------------------------ flow

  /// Starts the first wave (after Pencil's introduction).
  void start() {
    if (phase != MdPhase.ready) return;
    _banner();
  }

  void _banner() {
    if (isBoss) {
      _setPhase(MdPhase.bossIntro);
      _emit(MdEventKind.bossIntro);
    } else {
      _setPhase(MdPhase.banner);
      _emit(MdEventKind.banner, value: wave);
    }
  }

  void tick(double dt) {
    if (dt <= 0) return;
    dt = math.min(dt, .1); // a long frame (the app was away) never jumps
    _phaseTime += dt;
    for (final m in monsters) {
      m.age += dt;
      m.moodTime += dt;
    }
    switch (phase) {
      case MdPhase.ready || MdPhase.won || MdPhase.lost:
        _settle(dt);
        return;
      case MdPhase.banner:
        _settle(dt);
        if (_phaseTime >= bannerTime) {
          _setPhase(MdPhase.playing);
          _group = 0;
          _wait = 0;
        }
        return;
      case MdPhase.bossIntro:
        _settle(dt);
        if (_phaseTime >= bossIntroTime) {
          _setPhase(MdPhase.playing);
          _spawnBoss();
        }
        return;
      case MdPhase.playing:
        _play(dt);
    }
  }

  void _play(double dt) {
    if (frozen > 0) frozen = math.max(0, frozen - dt);
    _settle(dt);
    // walking
    for (final m in monsters) {
      if (m.mood != MdMood.walking || frozen > 0) continue;
      final seconds = m.kind == MdKind.boss ? bossSeconds * (m.hp == 1 ? .75 : 1) : waves[math.min(wave, waves.length - 1)].seconds;
      // faster near the gate (it is nearer to us): u' = k (1 + u), so
      // 0..1 takes [seconds] at speed 1
      final k = math.ln2 / seconds;
      final before = m.u;
      // out of the cave at a steady pace, then down the path
      m.u += m.u < 0 ? dt * .07 : dt * m.speed * k * (1 + m.u);
      if (before < 0 && m.u >= 0) _emit(MdEventKind.spawn, monster: m.id);
    }
    // close to the gate
    if (!_hurried && closest > hurryAt) {
      _hurried = true;
      _emit(MdEventKind.hurry);
    }
    // at the gate
    final at = _active.where((m) => m.mood == MdMood.walking && m.u >= 1).firstOrNull;
    if (at != null) _gate(at);
    // the next group, the next wave, the end
    if (_ending != null) {
      _end -= dt;
      if (_end <= 0) _finish();
      return;
    }
    if (isBoss) return;
    if (question == null) {
      _wait -= dt;
      if (_wait > 0) return;
      final groups = waves[wave].groups;
      if (_group < groups.length) {
        _spawnGroup(groups[_group++]);
      } else if (monsters.every((m) => !m.alive)) {
        wave++;
        _banner();
      }
    }
  }

  /// Moods that end on their own.
  void _settle(double dt) {
    for (final m in monsters) {
      switch (m.mood) {
        case MdMood.roaring when m.moodTime > .7:
          _mood(m, m.u >= 1 ? MdMood.fleeing : MdMood.walking);
        case MdMood.cracked when m.moodTime > (m.kind == MdKind.boss ? 1.3 : 1.0):
          _mood(m, MdMood.walking);
        case MdMood.trapped when m.moodTime > (m.kind == MdKind.boss ? 2.6 : 1.9):
          _mood(m, MdMood.friendly);
          _emit(MdEventKind.popped, monster: m.id);
        case MdMood.friendly when m.moodTime > 1.6:
          _mood(m, MdMood.gone);
        case MdMood.fleeing:
          m.u -= dt * .32;
          if (m.moodTime > 1.4) _mood(m, MdMood.gone);
        default:
          break;
      }
    }
    monsters.removeWhere((m) => m.mood == MdMood.gone);
  }

  void _mood(MdMonster m, MdMood mood) {
    m.mood = mood;
    m.moodTime = 0;
  }

  void _spawnGroup(List<MdKind> kinds) {
    final q = questions.next(kinds.length);
    final lanes = kinds.length == 2 ? [-.6, .6] : [-.8, 0.0, .8];
    lanes.shuffle(_rnd);
    final group = <MdMonster>[];
    for (var i = 0; i < kinds.length; i++) {
      final kind = kinds[i];
      group.add(
        MdMonster(
          id: ++_ids,
          kind: kind,
          label: q.choices[i],
          // one after another out of the cave (apart, so their signs are)
          u: -.02 - i * .085,
          lane: lanes[i],
          speed: switch (kind) {
            MdKind.fuzz => 1.3,
            MdKind.bonk => .8,
            MdKind.boo => 1.08,
            _ => 1.0,
          },
          hp: kind == MdKind.bonk ? 2 : 1,
        ),
      );
    }
    monsters.addAll(group);
    _active = group;
    _ask(q);
  }

  /// Where Big Bonk lands (he jumps down out of the cave), and how far back
  /// a catch knocks him: never so far up that he looks small.
  static const bossFrom = .22, bossBack = .15;

  void _spawnBoss() {
    final b = MdMonster(id: ++_ids, kind: MdKind.boss, label: '', u: bossFrom, lane: 0, speed: 1, hp: bossHp);
    monsters.add(b);
    _emit(MdEventKind.spawn, monster: b.id);
    _active = [b];
    _ask(questions.next(3));
  }

  void _ask(MdQuestion q) {
    question = q;
    _questionMisses = 0;
    hint = false;
    _hurried = false;
    _emit(MdEventKind.question);
  }

  /// Pencil asks again about the same monsters (after a cracked bubble).
  void _askAgain() {
    final walking = _active.where((m) => m.alive && m.mood != MdMood.fleeing).toList();
    final q = questions.next(isBoss ? 3 : walking.length);
    if (!isBoss) {
      for (var i = 0; i < walking.length; i++) {
        walking[i].label = q.choices[i];
      }
    }
    _ask(q);
  }

  void _resolved() {
    question = null;
    _active = [];
    _wait = gapTime;
  }

  // ------------------------------------------------------------ taps

  /// The child tapped monster [id].
  MdTap tap(int id) {
    final q = question;
    if (phase != MdPhase.playing || q == null || isBoss) return MdTap.ignored;
    final m = _active.where((m) => m.id == id).firstOrNull;
    if (m == null || !m.tappable || !m.out) return MdTap.ignored;
    if (m.label != q.answer) return _wrong(m);
    if (m.hp > 1) {
      m.hp--;
      _mood(m, MdMood.cracked);
      m.u = math.max(0, m.u - .06);
      _points(50);
      _emit(MdEventKind.crack, monster: m.id);
      _askAgain();
      return MdTap.cracked;
    }
    _mood(m, MdMood.trapped);
    caught++;
    _right(m);
    for (final o in _active) {
      if (o != m && o.alive && o.mood != MdMood.trapped) _mood(o, MdMood.fleeing);
    }
    _resolved();
    return MdTap.right;
  }

  /// The child tapped the boss's balloon [i].
  MdTap tapBalloon(int i) {
    final q = question, b = boss;
    if (phase != MdPhase.playing || q == null || !isBoss || b == null || i < 0 || i >= q.choices.length) return MdTap.ignored;
    if (!(b.mood == MdMood.walking || b.mood == MdMood.roaring)) return MdTap.ignored;
    if (q.choices[i] != q.answer) return _wrong(b);
    b.hp--;
    caught++;
    if (b.hp <= 0) {
      _mood(b, MdMood.trapped);
      _right(b, base: 200);
      question = null;
      _ending = MdPhase.won;
      _end = 4.4; // the bubble floats and pops, the boss waves
      return MdTap.right;
    }
    _right(b, base: 200);
    _mood(b, MdMood.cracked);
    b.u = math.max(bossBack, b.u - .16);
    _emit(MdEventKind.bossHit, monster: b.id, value: b.hp);
    _askAgain();
    return MdTap.cracked;
  }

  void _right(MdMonster m, {int base = 100}) {
    combo++;
    bestCombo = math.max(bestCombo, combo);
    final speedBonus = (100 * (1 - m.u.clamp(0.0, 1.0))).round();
    final comboBonus = math.min(100, 25 * (combo - 1));
    final points = _points(base + speedBonus + comboBonus);
    _emit(m.mood == MdMood.trapped ? MdEventKind.trapped : MdEventKind.hit, monster: m.id, value: points);
    // power-ups for answers in a row
    if (combo == 3 || combo == 8) {
      freezes = math.min(2, freezes + 1);
      _emit(MdEventKind.power, value: 0);
    } else if (combo == 5 || combo == 11) {
      potions = math.min(2, potions + 1);
      _emit(MdEventKind.power, value: 1);
    }
  }

  int _points(int p) {
    if (doubled > 0) {
      doubled--;
      p *= 2;
    }
    score += p;
    return p;
  }

  MdTap _wrong(MdMonster m) {
    misses++;
    combo = 0;
    _questionMisses++;
    if (question != null && _questionMisses == 1) questions.missed(question!);
    _mood(m, MdMood.roaring);
    // it jumps closer (not past the gate: reaching it is the walk's job)
    m.u = math.min(.97, m.u + (m.kind == MdKind.boss ? .05 : .06));
    _emit(MdEventKind.miss, monster: m.id);
    if (_questionMisses >= 2 && !hint) {
      hint = true;
      _emit(MdEventKind.hint);
    }
    return MdTap.wrong;
  }

  void _gate(MdMonster m) {
    hearts--;
    combo = 0;
    _emit(MdEventKind.gate, monster: m.id, value: hearts);
    if (question != null) questions.missed(question!);
    if (m.kind == MdKind.boss) {
      // he trips over the fence and is pushed back up the path
      _mood(m, MdMood.roaring);
      m.u = .42;
      _hurried = false;
    } else {
      m.u = 1;
      _mood(m, MdMood.roaring);
      for (final o in _active) {
        if (o != m && o.alive) _mood(o, MdMood.fleeing);
      }
      _resolved();
      _wait = gapTime + .6;
    }
    if (hearts <= 0) {
      question = null;
      _ending = MdPhase.lost;
      _end = 1.6;
    }
  }

  void _finish() {
    final p = _ending!;
    _ending = null;
    if (p == MdPhase.won) score += hearts * 250;
    _setPhase(p);
    _emit(p == MdPhase.won ? MdEventKind.won : MdEventKind.lost);
  }

  // ------------------------------------------------------------ power-ups

  /// Freeze: every monster stops for a while.
  bool useFreeze() {
    if (freezes <= 0 || phase != MdPhase.playing || frozen > 0) return false;
    freezes--;
    frozen = freezeTime;
    _emit(MdEventKind.freeze);
    return true;
  }

  /// Double magic: the next three right answers count double.
  bool usePotion() {
    if (potions <= 0 || phase != MdPhase.playing || doubled > 0) return false;
    potions--;
    doubled = 3;
    _emit(MdEventKind.potion);
    return true;
  }
}
