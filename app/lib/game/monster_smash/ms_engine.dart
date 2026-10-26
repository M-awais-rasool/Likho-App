import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart';

import '../monster_defense/md_questions.dart';
import 'ms_towers.dart';

export 'ms_towers.dart' show MsMaterial, MsShape, MsSize;

/// Monster Smash, the game itself (no drawing): like Angry Birds. Pencil
/// stands on a little hill with a big slingshot; on the right, Monster
/// Defense's silly monsters sit on towers of wood, ice and stone blocks,
/// some of them with letters. Pencil asks for a letter ("Find B!"); the
/// child pulls the ball back and lets go, and real physics (Box2D, through
/// forge2d) does the rest: the ball flies, the B block bursts, the tower
/// wobbles and falls, and the monsters tumbling down turn into friends.
///
/// A game is three towers (a meadow, a beach, snowy hills), each bigger
/// than the last. There is no losing: a ball that hits the wrong letter
/// says its name, Pencil shows the right block after a few misses, and an
/// empty basket fills up again (fewer stars).
///
/// World units are metres, x right from the screen's left edge (16 m), y up
/// from the ground. [tick] moves time on; [grab], [drag] and [release] are
/// the child's finger (in world units); [drain] hands out what happened.

/// What Pencil asks: the [letter] on a block, his words and their recording,
/// a picture for a first-sound question.
@immutable
class MsAsk {
  const MsAsk({required this.letter, required this.say, required this.audio, this.picture});
  final String letter, say, audio;
  final String? picture;

  static String _voice(String id) => 'assets/voice/$id.m4a';

  factory MsAsk.capital(String l) => MsAsk(letter: l.toUpperCase(), say: 'Find ${l.toUpperCase()}!', audio: _voice('md_find_${l.toLowerCase()}'));
  factory MsAsk.small(String l) => MsAsk(letter: l.toLowerCase(), say: 'Find small ${l.toLowerCase()}!', audio: _voice('md_small_${l.toLowerCase()}'));
  factory MsAsk.first(String word) => MsAsk(
    letter: word[0],
    say: '${word[0].toUpperCase()}${word.substring(1)}! Which letter does it start with?',
    audio: _voice('md_first_$word'),
    picture: MdWords.picture(word),
  );

  /// The letter's name, said when the ball hits it ("B!").
  String get nameAudio => _voice('sr_letter_${letter.toLowerCase()}');

  @override
  String toString() => 'MsAsk($letter)';
}

/// The letters a tower carries and what Pencil asks about them.
abstract class MsAsks {
  /// [letters] different letters for the blocks and [asks] questions about
  /// some of them.
  (List<String>, List<MsAsk>) tower(int letters, int asks);
}

/// Fixed letters (tests, the preview): capitals, the first ones asked.
class MsLetterList implements MsAsks {
  MsLetterList(this.letters);
  final String letters;
  int _at = 0;

  @override
  (List<String>, List<MsAsk>) tower(int letters, int asks) {
    final shown = [for (var i = 0; i < letters; i++) this.letters[(_at + i) % this.letters.length]];
    _at += letters;
    return (shown, [for (final l in shown.take(asks)) MsAsk.capital(l)]);
  }
}

/// The questions for a child: Monster Defense's (capitals, small letters,
/// first sounds; the newest skill most often, look-alike letters beside
/// the answer), more of them about the same tower's letters.
class MsChildAsks implements MsAsks {
  MsChildAsks(MdKnowledge k, this.words, {math.Random? random})
    : _rnd = random ?? math.Random(),
      _q = MdQuestions(
        MdKnowledge(capitals: k.capitals, smalls: k.smalls, firstSound: k.firstSound),
        words,
        random: random,
      );

  final MdWords words;
  final math.Random _rnd;
  final MdQuestions _q;

  @override
  (List<String>, List<MsAsk>) tower(int letters, int asks) {
    final q = _q.next(letters);
    final small = q.skill != MdSkill.capitals;
    final shown = [for (final c in q.choices) small ? c.toLowerCase() : c.toUpperCase()];
    final answer = small ? q.answer.toLowerCase() : q.answer.toUpperCase();
    MsAsk ask(String l) {
      switch (q.skill) {
        case MdSkill.capitals:
          return MsAsk.capital(l);
        case MdSkill.firstSound:
          // c and k sound the same at the start: a picture only when the
          // blocks do not show both
          final both = shown.contains('c') && shown.contains('k') && (l == 'c' || l == 'k');
          final pics = words.first.where((w) => w[0] == l).toList();
          if (!both && pics.isNotEmpty) return MsAsk.first(pics[_rnd.nextInt(pics.length)]);
          return MsAsk.small(l);
        default:
          return MsAsk.small(l);
      }
    }

    final first = q.skill == MdSkill.firstSound && q.picture != null ? MsAsk(letter: answer, say: q.say, audio: q.audio, picture: q.picture) : ask(answer);
    final rest = shown.where((l) => l != answer).toList()..shuffle(_rnd);
    return (shown, [first, for (final l in rest.take(asks - 1)) ask(l)]);
  }
}

enum MsBall { eraser, water, star }

/// A block in the world.
class MsBlock {
  MsBlock(this.id, this.shape, this.material, this.body, {this.letter}) : health = _health[material]!;
  final int id;
  final MsShape shape;
  final MsMaterial material;
  final Body body;

  /// Its letter (letter blocks never break; the right one bursts).
  final String? letter;
  double health;
  bool gone = false, cracked = false;

  static const _health = {MsMaterial.wood: 3.2, MsMaterial.ice: 1.7, MsMaterial.stone: 12.0};

  /// How broken it looks (0 whole, 1 nearly gone).
  double get damage => 1 - health / _health[material]!;

  Vector2 get position => body.position;
  double get angle => body.angle;
}

/// A monster sitting on a tower.
class MsMonster {
  MsMonster(this.id, this.kind, this.body) : startY = body.position.y;
  final int id;

  /// gloop, fuzz, bonk or boo (Monster Defense's art).
  final String kind;
  final Body body;
  final double startY;

  /// A friend now (knocked down or hit hard).
  bool friend = false;

  /// When something near it moved hard last (it looks surprised).
  double startled = -9;

  /// When it became a friend.
  double friendAt = 0;

  /// When it last hopped back onto its feet.
  double upAt = -9;

  Vector2 get position => body.position;
  double get angle => body.angle;
}

/// The ball in the air.
class MsShot {
  MsShot(this.kind, this.body);
  final MsBall kind;
  final Body body;
  double time = 0, still = 0;

  /// Its trail, for drawing (newest last).
  final List<Vector2> trail = [];

  /// The letter blocks it touched (the first wrong one is said).
  final Set<int> touched = {};
  bool wrongSaid = false, hitTarget = false;

  /// A water balloon bursts where it first touches something.
  Vector2? burstAt;
  bool gone = false;

  double get radius => MsGame.ballRadius[kind]!;
}

enum MsPhase { ready, build, aim, flying, settle, cleared, done }

enum MsEventKind { build, ask, grab, launch, hit, wrong, knock, crack, smash, friend, splash, ballGone, miss, hint, refill, cleared, done }

class MsEvent {
  const MsEvent(this.kind, {this.x = 0, this.y = 0, this.material, this.value = 0, this.text = '', this.ask});
  final MsEventKind kind;
  final double x, y;
  final MsMaterial? material;

  /// How hard (knock, smash), the score added, the tower number …
  final double value;
  final String text;
  final MsAsk? ask;

  @override
  String toString() => 'MsEvent(${kind.name} $text ${value.toStringAsFixed(1)})';
}

class MsGame {
  MsGame({required this.asks, this.towers = 3, int? seed}) : _rnd = math.Random(seed);

  final MsAsks asks;

  /// How many towers a game has.
  final int towers;
  final math.Random _rnd;

  static const width = 16.0, gravity = 10.0;

  /// Where the ball sits in the slingshot, and the hill's flat top.
  static final rest = Vector2(2.9, 2.2);
  static const hillTop = .78, hillX = 2.9;

  /// How far the ball can be pulled back, and how fast a full pull sends it.
  static const maxPull = 1.6, minPull = .3, maxSpeed = 15.5;
  static const ballRadius = {MsBall.eraser: .27, MsBall.water: .29, MsBall.star: .31};

  static const _step = 1 / 60;
  static const _hillBit = 0x0002;
  static const _monsterKinds = ['gloop', 'fuzz', 'bonk', 'boo'];

  late World world;
  late Body ground;

  MsPhase phase = MsPhase.ready;
  double time = 0, phaseTime = 0;

  /// The tower being smashed (0, 1, 2 …).
  int tower = -1;

  final List<MsBlock> blocks = [];
  final List<MsMonster> monsters = [];
  MsShot? shot;

  /// The balls left for this tower (the next one first).
  final List<MsBall> balls = [];

  /// What Pencil asks about this tower, and which one now.
  List<MsAsk> towerAsks = [];
  int askAt = 0;
  MsAsk? get ask => askAt < towerAsks.length ? towerAsks[askAt] : null;

  /// Shots without hitting the asked letter (resets with each letter).
  int misses = 0;

  /// The ball's pull while the child drags (null: not dragging).
  Vector2? pull;
  Vector2? _grab;

  int score = 0, shots = 0, found = 0, friends = 0, refills = 0;

  /// The asked letters this game, and shots that found nothing.
  int asked = 0, wasted = 0;

  /// When Pencil cheered / said oops / threw last (for his poses).
  double cheerAt = -9, oopsAt = -9, throwAt = -9;

  /// The block the hint points at (after misses), and when it burst.
  int? hintBlock;

  final List<MsEvent> _events = [];
  double _acc = 0, _quiet = 0;
  bool _live = false; // contacts count (not while a tower settles unseen)
  final List<(Body, Body, double)> _impacts = [];
  final List<(Body, Body)> _touches = [];
  final Map<MsMaterial, double> _lastKnock = {};

  List<MsEvent> drain() {
    final out = List<MsEvent>.of(_events);
    _events.clear();
    return out;
  }

  /// 3 stars for at most 2 wasted shots, 2 for at most 6.
  int get stars => wasted <= 2 && refills == 0 ? 3 : (wasted <= 6 ? 2 : 1);

  bool get over => phase == MsPhase.done;

  /// The ball in the slingshot (where it is drawn while aiming).
  Vector2 get ballInSling => pull == null ? rest.clone() : rest + pull!;

  MsBlock? blockOf(Body b) => b.userData is MsBlock ? b.userData as MsBlock : null;

  // ---------------------------------------------------------------- setup

  void start() {
    tower = -1;
    score = shots = found = friends = refills = asked = wasted = 0;
    _nextTower();
  }

  void _newWorld() {
    world = World(Vector2(0, -gravity));
    world.setContactListener(_Contacts(this));
    ground = world.createBody(BodyDef(userData: 'ground'));
    ground.createFixture(FixtureDef(EdgeShape()..set(Vector2(-4, 0), Vector2(width + 4, 0)), friction: .8));
    // walls just off the screen keep everything in sight
    for (final x in [-.6, width + .4]) {
      ground.createFixture(FixtureDef(PolygonShape()..setAsBox(.2, 20, Vector2(x, 20), 0), friction: .3));
    }
    // the hill under Pencil and the slingshot
    // (the ball passes through it: a ball pulled down starts inside it)
    final hill = world.createBody(BodyDef(userData: 'hill'));
    hill.createFixture(
      FixtureDef(
        PolygonShape()..set([Vector2(hillX - 1.75, 0), Vector2(hillX + 1.75, 0), Vector2(hillX + 1.05, hillTop), Vector2(hillX - 1.05, hillTop)]),
        friction: .8,
        filter: Filter()..categoryBits = _hillBit,
      ),
    );
  }

  void _nextTower() {
    tower++;
    if (tower >= towers) {
      _set(MsPhase.done);
      _events.add(MsEvent(MsEventKind.done, value: score.toDouble()));
      return;
    }
    _newWorld();
    blocks.clear();
    monsters.clear();
    shot = null;
    pull = null;
    hintBlock = null;
    misses = 0;
    final plan = MsTowers.forRound(tower, _rnd);
    final letters = [3, 4, 5][math.min(tower, 2)];
    final count = [2, 3, 3][math.min(tower, 2)];
    final (shown, list) = asks.tower(math.min(letters, plan.letterSpots), count);
    towerAsks = [...list];
    askAt = 0;
    // the letters go on random letter spots
    final spots = [
      for (var i = 0; i < plan.pieces.length; i++)
        if (plan.pieces[i].letter) i,
    ]..shuffle(_rnd);
    final letterAt = {for (var k = 0; k < shown.length; k++) spots[k]: shown[k]};
    for (var i = 0; i < plan.pieces.length; i++) {
      _addBlock(plan.pieces[i], letterAt[i]);
    }
    final kinds = [..._monsterKinds]..shuffle(_rnd);
    for (var i = 0; i < plan.monsters.length; i++) {
      _addMonster(plan.monsters[i], kinds[i % kinds.length]);
    }
    balls
      ..clear()
      ..addAll(_ballsFor(tower, list.length));
    // let the tower settle unseen, so it stands still when it appears
    _live = false;
    for (var i = 0; i < 120; i++) {
      world.stepDt(_step);
    }
    _impacts.clear();
    _touches.clear();
    _live = true;
    _set(MsPhase.build);
    _events.add(MsEvent(MsEventKind.build, value: tower.toDouble()));
  }

  /// Two spare balls; the beach brings water balloons, the snow star balls.
  List<MsBall> _ballsFor(int t, int asks) {
    final n = asks + 2;
    return [
      for (var i = 0; i < n; i++)
        switch (t % 3) {
          1 when i.isOdd => MsBall.water,
          2 when i % 3 == 1 => MsBall.star,
          2 when i % 3 == 2 => MsBall.water,
          _ => MsBall.eraser,
        },
    ];
  }

  void _addBlock(MsPiece p, String? letter) {
    final body = world.createBody(BodyDef(type: BodyType.dynamic, position: Vector2(p.x, p.y), angularDamping: .1));
    final shape = switch (p.shape) {
      MsShape.square => PolygonShape()..setAsBoxXY(MsSize.square / 2, MsSize.square / 2),
      MsShape.plank => PolygonShape()..setAsBoxXY(MsSize.plankW / 2, MsSize.plankH / 2),
      MsShape.triangle =>
        PolygonShape()..set([Vector2(-MsSize.triW / 2, -MsSize.triH / 2), Vector2(MsSize.triW / 2, -MsSize.triH / 2), Vector2(0, MsSize.triH / 2)]),
      MsShape.disc => CircleShape()..radius = MsSize.disc,
    };
    final (density, friction) = switch (p.material) {
      MsMaterial.wood => (1.0, .7),
      MsMaterial.ice => (.8, .25),
      MsMaterial.stone => (2.4, .8),
    };
    body.createFixture(FixtureDef(shape, density: density, friction: friction, restitution: .05));
    final b = MsBlock(blocks.length, p.shape, p.material, body, letter: letter);
    body.userData = b;
    blocks.add(b);
  }

  void _addMonster(MsSpot s, String kind) {
    final body = world.createBody(BodyDef(type: BodyType.dynamic, position: Vector2(s.x, s.y), angularDamping: .8));
    const h = MsSize.monster, c = MsSize.monster * .6;
    body.createFixture(
      FixtureDef(
        PolygonShape()..set([Vector2(-c, -h), Vector2(c, -h), Vector2(h, -c), Vector2(h, c), Vector2(c, h), Vector2(-c, h), Vector2(-h, c), Vector2(-h, -c)]),
        density: .7,
        friction: .7,
        restitution: .15,
      ),
    );
    final m = MsMonster(monsters.length, kind, body);
    body.userData = m;
    monsters.add(m);
  }

  void _set(MsPhase p) {
    phase = p;
    phaseTime = 0;
  }

  // ---------------------------------------------------------------- the finger

  /// The child puts a finger down at [p]: anywhere on the left part of the
  /// screen takes hold of the ball.
  bool grab(Vector2 p) {
    if (phase != MsPhase.aim || balls.isEmpty || p.x > width * .45) return false;
    _grab = p.clone();
    pull = Vector2.zero();
    _events.add(const MsEvent(MsEventKind.grab));
    return true;
  }

  /// The finger moved to [p]: the ball follows it, up to [maxPull] back.
  void drag(Vector2 p) {
    if (_grab == null || pull == null) return;
    final d = p - _grab!;
    if (d.length > maxPull) d.scale(maxPull / d.length);
    pull = d;
  }

  /// The finger lets go: the ball flies (or goes back, for a tiny pull).
  void release() {
    final p = pull;
    _grab = null;
    pull = null;
    if (p == null || phase != MsPhase.aim) return;
    if (p.length < minPull) return;
    launch(p);
  }

  /// The ball's speed for a pull [p] (opposite to it).
  static Vector2 velocity(Vector2 p) => p * (-maxSpeed / maxPull);

  /// Sends the next ball off with pull [p] (the finger, or a test).
  void launch(Vector2 p) {
    if (phase != MsPhase.aim || balls.isEmpty) return;
    final kind = balls.removeAt(0);
    final r = ballRadius[kind]!;
    final body = world.createBody(BodyDef(type: BodyType.dynamic, position: rest + p, bullet: true, linearVelocity: velocity(p), angularDamping: .3));
    final (density, bounce) = switch (kind) {
      MsBall.eraser => (2.6, .4),
      MsBall.water => (2.0, .05),
      MsBall.star => (5.0, .2),
    };
    body.createFixture(
      FixtureDef(CircleShape()..radius = r, density: density, friction: .6, restitution: bounce, filter: Filter()..maskBits = 0xFFFF & ~_hillBit),
    );
    final s = MsShot(kind, body);
    body.userData = s;
    shot = s;
    shots++;
    throwAt = time;
    _set(MsPhase.flying);
    _events.add(MsEvent(MsEventKind.launch, value: p.length / maxPull, text: kind.name));
  }

  /// Where a ball pulled by [p] would go (no blocks in the way): one dot
  /// every [every] seconds while it is on the screen.
  static List<Vector2> path(Vector2 p, {int dots = 18, double every = .07}) {
    final v = velocity(p);
    final o = rest + p;
    final out = <Vector2>[];
    for (var i = 1; i <= dots; i++) {
      final t = i * every;
      final q = Vector2(o.x + v.x * t, o.y + v.y * t - gravity * t * t / 2);
      if (q.y < 0 || q.x > width) break;
      out.add(q);
    }
    return out;
  }

  /// A pull that sends the ball through [target]: the flattest clear path
  /// ([high]: the highest; [clear]: none when every path is blocked), for
  /// the bot in tests and to choose letters the ball can reach.
  Vector2? solve(Vector2 target, {bool high = false, Set<int> ignore = const {}, bool clear = false}) {
    final angles = [for (var a = -10; a <= 80; a++) a * math.pi / 180];
    if (high) angles.setAll(0, angles.reversed.toList());
    Vector2? any;
    for (final a in angles) {
      final dir = Vector2(math.cos(a), math.sin(a));
      // the ball starts where it was pulled to, which depends on the pull
      var p = Vector2.zero();
      var ok = false;
      for (var k = 0; k < 4; k++) {
        final o = rest + p;
        final dx = target.x - o.x, dy = target.y - o.y;
        final den = 2 * math.pow(math.cos(a), 2) * (dx * math.tan(a) - dy);
        if (den <= 0) break;
        final v = math.sqrt(gravity * dx * dx / den);
        if (v > maxSpeed * .98) break;
        p = dir * (-v * maxPull / maxSpeed);
        ok = true;
      }
      if (!ok) continue;
      any ??= p;
      if (_clear(p, target, ignore)) return p;
    }
    return clear ? null : any;
  }

  /// Whether the ball can fly to block [b] without touching another.
  bool reachable(MsBlock b) => solve(b.position, ignore: {b.id}, clear: true) != null;

  bool _clear(Vector2 p, Vector2 target, Set<int> ignore) {
    final v = velocity(p);
    final o = rest + p;
    for (var t = 0.0; t < 3; t += .01) {
      final q = Vector2(o.x + v.x * t, o.y + v.y * t - gravity * t * t / 2);
      if (q.distanceTo(target) < .45) return true;
      if (q.y < 0) return false;
      for (final b in blocks) {
        if (b.gone || ignore.contains(b.id)) continue;
        if (_inside(b, q, .3)) return false;
      }
      for (final m in monsters) {
        if (m.position.distanceTo(q) < MsSize.monster + .3) return false;
      }
    }
    return false;
  }

  /// Whether [q] is within [margin] of block [b] (its box).
  static bool _inside(MsBlock b, Vector2 q, double margin) {
    if (b.shape == MsShape.disc) return b.position.distanceTo(q) < MsSize.disc + margin;
    final (hw, hh) = switch (b.shape) {
      MsShape.plank => (MsSize.plankW / 2, MsSize.plankH / 2),
      MsShape.triangle => (MsSize.triW / 2, MsSize.triH / 2),
      _ => (MsSize.square / 2, MsSize.square / 2),
    };
    final d = q - b.position;
    final c = math.cos(-b.angle), s = math.sin(-b.angle);
    final x = d.x * c - d.y * s, y = d.x * s + d.y * c;
    return x.abs() < hw + margin && y.abs() < hh + margin;
  }

  /// The block with the letter asked now.
  MsBlock? get target {
    final a = ask;
    if (a == null) return null;
    for (final b in blocks) {
      if (!b.gone && b.letter == a.letter) return b;
    }
    return null;
  }

  // ---------------------------------------------------------------- time

  void tick(double dt) {
    if (phase == MsPhase.ready || phase == MsPhase.done) return;
    time += dt;
    phaseTime += dt;
    switch (phase) {
      case MsPhase.build:
        if (phaseTime > 1.3) {
          _set(MsPhase.aim);
          _ask();
        }
        return;
      case MsPhase.aim:
      case MsPhase.flying:
      case MsPhase.settle:
      case MsPhase.cleared:
        _acc += math.min(dt, .1);
        while (_acc >= _step) {
          _acc -= _step;
          world.stepDt(_step);
          _afterStep();
        }
        _rules(dt);
      default:
    }
  }

  void _ask() {
    // a letter buried in the rubble waits: one the ball can reach first
    final t = target;
    if (t != null && !reachable(t)) {
      for (var k = askAt + 1; k < towerAsks.length; k++) {
        final o = blocks.where((b) => !b.gone && b.letter == towerAsks[k].letter).firstOrNull;
        if (o != null && reachable(o)) {
          towerAsks.insert(askAt, towerAsks.removeAt(k));
          break;
        }
      }
    }
    final a = ask;
    if (a == null) return;
    asked++;
    misses = 0;
    hintBlock = null;
    _events.add(MsEvent(MsEventKind.ask, ask: a, text: a.letter));
  }

  void _rules(double dt) {
    _standUp();
    switch (phase) {
      case MsPhase.flying:
        final s = shot!;
        s.time += dt;
        if (!s.gone) {
          final b = s.body;
          s.trail.add(b.position.clone());
          if (s.trail.length > 14) s.trail.removeAt(0);
          s.still = b.linearVelocity.length < .35 ? s.still + dt : 0;
          final out = b.position.x > width + 1 || b.position.x < -1 || b.position.y < -2;
          if (out || s.still > .6 || s.time > 7) _ballGone(s);
        }
        if (s.gone) _set(MsPhase.settle);
      case MsPhase.settle:
        _quiet = _moving() ? 0 : _quiet + dt;
        if (_quiet > .45 || phaseTime > 3.2) _afterShot();
      case MsPhase.cleared:
        if (phaseTime > 3.0) _nextTower();
      default:
    }
  }

  /// A monster lying on its side or head, gone still, hops back onto its
  /// feet (a monster upside down for good looks broken).
  void _standUp() {
    for (final m in monsters) {
      final b = m.body;
      final a = math.atan2(math.sin(b.angle), math.cos(b.angle));
      if (a.abs() < .6 || time - m.upAt < 1.2 || b.linearVelocity.length > .3 || b.angularVelocity.abs() > .6) continue;
      m.upAt = time;
      b.linearVelocity = Vector2(0, 3.2);
      b.angularVelocity = -a * 1.9;
    }
  }

  bool _moving() {
    for (final b in world.bodies) {
      if (b.bodyType != BodyType.dynamic || !b.isAwake) continue;
      if (b.linearVelocity.length > .25 || b.angularVelocity.abs() > .5) return true;
    }
    return false;
  }

  void _ballGone(MsShot s) {
    if (s.gone) return;
    s.gone = true;
    _events.add(MsEvent(MsEventKind.ballGone, x: s.body.position.x, y: s.body.position.y, text: s.kind.name));
    world.destroyBody(s.body);
  }

  void _afterShot() {
    final s = shot;
    shot = null;
    var next = s != null && s.hitTarget;
    if (s != null && !next) {
      misses++;
      wasted++;
      if (!s.wrongSaid) _events.add(const MsEvent(MsEventKind.miss));
      oopsAt = time;
      final t = target;
      if (t != null && misses >= 5) {
        // Pencil helps: the block bursts by itself
        _found(t, helped: true);
        next = true;
      } else if (t != null && misses >= 2 && hintBlock != t.id) {
        hintBlock = t.id;
        _events.add(MsEvent(MsEventKind.hint, x: t.position.x, y: t.position.y, text: t.letter!));
      }
    }
    if (ask == null) {
      // every letter found: the monsters still up jump down and are friends
      for (final m in monsters) {
        if (m.friend) continue;
        _befriend(m, points: 20);
        m.body.applyLinearImpulse(Vector2(0, m.body.mass * 3.5));
      }
      final bonus = balls.length * 100;
      score += bonus;
      _set(MsPhase.cleared);
      _events.add(MsEvent(MsEventKind.cleared, value: bonus.toDouble()));
      return;
    }
    if (next) _ask();
    if (balls.isEmpty) {
      refills++;
      balls.addAll([MsBall.eraser, MsBall.eraser, MsBall.eraser]);
      _events.add(const MsEvent(MsEventKind.refill));
    }
    _set(MsPhase.aim);
  }

  // ---------------------------------------------------------------- contacts

  void _afterStep() {
    if (!_live) return;
    for (final (a, b) in _touches) {
      _touch(a, b);
      _touch(b, a);
    }
    _touches.clear();
    for (final (a, b, j) in _impacts) {
      _impact(a, b, j);
      _impact(b, a, j);
    }
    _impacts.clear();
    final s = shot;
    if (s != null && s.burstAt != null && !s.gone) _splash(s);
    for (final b in blocks) {
      if (!b.gone && b.health <= 0) _smash(b);
    }
  }

  /// [a] began touching [b].
  void _touch(Body a, Body b) {
    final s = a.userData;
    if (s is MsMonster && !s.friend && b.userData == 'ground' && s.startY > .6) _befriend(s);
    if (s is! MsShot || s.gone) return;
    if (s.kind == MsBall.water && s.burstAt == null && b.userData != 'hill') s.burstAt = s.body.position.clone();
    final block = blockOf(b);
    // one letter a shot: the next one is asked first
    if (block == null || block.letter == null || block.gone || s.hitTarget) return;
    s.touched.add(block.id);
    if (block.letter == ask?.letter) {
      s.hitTarget = true;
      _found(block);
    } else if (!s.wrongSaid) {
      s.wrongSaid = true;
      _events.add(MsEvent(MsEventKind.wrong, x: block.position.x, y: block.position.y, text: block.letter!, ask: ask));
    }
  }

  /// The asked letter's block was hit: it bursts.
  void _found(MsBlock b, {bool helped = false}) {
    final points = helped ? 20 : (misses == 0 ? 150 : 100);
    score += points;
    found++;
    cheerAt = time;
    _events.add(MsEvent(MsEventKind.hit, x: b.position.x, y: b.position.y, material: b.material, value: points.toDouble(), text: b.letter!, ask: ask));
    _remove(b);
    // its neighbours get a push, so the tower really feels it
    for (final o in world.bodies) {
      if (o.bodyType != BodyType.dynamic || o.userData is MsShot) continue;
      final d = o.position - b.position;
      final dist = d.length;
      if (dist < .05 || dist > 1.6) continue;
      o.applyLinearImpulse(d.normalized()..scale(o.mass * 1.6 * (1 - dist / 1.6)));
    }
    for (final m in monsters) {
      if (m.position.distanceTo(b.position) < 3) m.startled = time;
    }
    askAt++;
  }

  void _remove(MsBlock b) {
    if (b.gone) return;
    b.gone = true;
    if (hintBlock == b.id) hintBlock = null;
    world.destroyBody(b.body);
  }

  /// [a] was pushed by [b] with impulse [j].
  void _impact(Body a, Body b, double j) {
    final o = a.userData;
    final s = b.userData;
    final fromBall = s is MsShot;
    final hit = j * (fromBall ? (s.kind == MsBall.star ? 3.0 : 1.6) : 1.0);
    if (o is MsBlock && !o.gone) {
      if (j > 1.2) _knock(o.material, o.position, j);
      if (o.letter != null) return;
      if (hit > 1.0) {
        o.health -= hit - 1.0;
        if (!o.cracked && o.damage > .4 && o.health > 0) {
          o.cracked = true;
          _events.add(MsEvent(MsEventKind.crack, x: o.position.x, y: o.position.y, material: o.material));
        }
      }
    } else if (o is MsMonster && !o.friend) {
      if (hit > .5) o.startled = time;
      if (hit > 1.4) _befriend(o);
    }
  }

  void _knock(MsMaterial m, Vector2 at, double j) {
    if (time - (_lastKnock[m] ?? -1) < .08) return;
    _lastKnock[m] = time;
    _events.add(MsEvent(MsEventKind.knock, x: at.x, y: at.y, material: m, value: math.min(1, j / 8)));
  }

  void _befriend(MsMonster m, {int points = 50}) {
    m.friend = true;
    m.friendAt = time;
    friends++;
    score += points;
    _events.add(MsEvent(MsEventKind.friend, x: m.position.x, y: m.position.y, text: m.kind, value: points.toDouble()));
  }

  void _smash(MsBlock b) {
    final points = switch (b.material) {
      MsMaterial.wood => 10,
      MsMaterial.ice => 10,
      MsMaterial.stone => 25,
    };
    score += points;
    _events.add(MsEvent(MsEventKind.smash, x: b.position.x, y: b.position.y, material: b.material, value: points.toDouble(), text: b.shape.name));
    _remove(b);
  }

  /// A water balloon bursts: a splash that pushes everything near away.
  void _splash(MsShot s) {
    final at = s.burstAt!;
    _events.add(MsEvent(MsEventKind.splash, x: at.x, y: at.y));
    const reach = 2.0;
    for (final o in world.bodies) {
      if (o.bodyType != BodyType.dynamic || o == s.body) continue;
      final d = o.position - at;
      final dist = d.length;
      if (dist > reach) continue;
      final k = 1 - dist / reach;
      o.applyLinearImpulse((dist < .05 ? Vector2(1, .3) : d.normalized())..scale(o.mass * 4.5 * k));
      final block = blockOf(o);
      if (block != null && block.letter == null) block.health -= 1.4 * k;
      if (o.userData case final MsMonster m when !m.friend) m.startled = time;
    }
    s.gone = true;
    world.destroyBody(s.body);
    if (phase == MsPhase.flying) _set(MsPhase.settle);
  }
}

class _Contacts extends ContactListener {
  _Contacts(this.game);
  final MsGame game;

  @override
  void beginContact(Contact contact) => game._touches.add((contact.fixtureA.body, contact.fixtureB.body));

  @override
  void postSolve(Contact contact, ContactImpulse impulse) {
    var j = 0.0;
    for (var i = 0; i < contact.manifold.pointCount; i++) {
      j += impulse.normalImpulses[i];
    }
    if (j > .5) game._impacts.add((contact.fixtureA.body, contact.fixtureB.body, j));
  }
}
