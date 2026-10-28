import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart';

import '../monster_defense/md_questions.dart';
import 'ms_levels.dart';
import 'ms_towers.dart';

export 'ms_levels.dart' show MsHero, MsLevel, MsLevels, MsRoom;
export 'ms_towers.dart' show MsMaterial, MsShape, MsSize;

/// Monster Smash, the game itself (no drawing): like Angry Birds 2. A big
/// slingshot stands on a little hill, the Stationery Squad (Rubby, Inky,
/// Crayo) waits in line beside it; on the right, Monster Defense's silly
/// monsters sit on towers of wood, ice and stone blocks, some with letters.
/// Pencil's voice asks for a letter ("Find B!"); the child pulls the hero
/// back and lets go (and taps while it flies for its power), and real
/// physics (Box2D, through forge2d) does the rest: the B block bursts, the
/// tower wobbles and falls, and the monsters tumbling down turn into
/// friends.
///
/// A level ([MsLevel]) is one to three rooms, played with one line of
/// heroes; the child may pick which hero goes next. Smashing fills the
/// Smash meter, and a full meter brings a bonus hero. There is no losing: a
/// wrong letter is said, the right block is shown after a few misses, and
/// an empty line fills up again (fewer stars).
///
/// World units are metres, x right from the screen's left edge (16 m), y up
/// from the ground. [tick] moves time on; [grab], [drag] and [release] are
/// the child's finger (in world units), [power] a tap; [drain] hands out
/// what happened.

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

/// One fling: the hero, and Inky's drops once he split. One letter a fling.
class MsVolley {
  MsVolley(this.hero);
  final MsHero hero;
  double time = 0;

  /// The letter blocks it touched (the first wrong one is said).
  final Set<int> touched = {};
  bool wrongSaid = false, hitTarget = false;

  /// The tap's power was used (once a fling), and when.
  bool powered = false;
  double poweredAt = -9;
}

/// A hero (or one of Inky's drops) in the air.
class MsShot {
  MsShot(this.hero, this.body, this.volley, {required this.radius, this.drop = false});
  final MsHero hero;
  final Body body;
  final MsVolley volley;
  final double radius;

  /// One of Inky's three drops.
  final bool drop;
  double still = 0;

  /// Its trail, for drawing (newest last).
  final List<Vector2> trail = [];

  /// Crayo after his dash: wood and ice he touches break.
  bool pierce = false;
  bool gone = false;

  /// Where it stopped (the screen shows the hero resting there a moment).
  Vector2? restAt;

  /// When it last bumped into something, and how hard (0..1): it squashes.
  double hitAt = -9, hitHard = 0;
}

enum MsPhase { ready, build, aim, flying, settle, cleared, done }

enum MsEventKind { build, ask, grab, pick, launch, power, hit, wrong, knock, crack, smash, friend, ballGone, miss, hint, refill, bonus, cleared, done }

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
  MsGame({required this.asks, required this.level, int? seed}) : _rnd = math.Random(seed);

  final MsAsks asks;
  final MsLevel level;
  final math.Random _rnd;

  /// How many rooms the level has.
  int get rooms => level.rooms.length;

  static const width = 16.0, gravity = 10.0;

  /// Where the hero sits in the slingshot, and the hill's flat top: wide
  /// enough for the heroes waiting in line left of the slingshot.
  static final rest = Vector2(2.9, 2.2);
  static const hillTop = .78, hillX = 2.6;
  static const hillHalfTop = 1.7, hillHalfFoot = 2.4;

  /// How far the hero can be pulled back, and how fast a full pull sends it.
  static const maxPull = 1.6, minPull = .3, maxSpeed = 15.5;
  static const heroRadius = {MsHero.rubby: .24, MsHero.inky: .22, MsHero.crayo: .22};
  static const dropRadius = .15;

  /// The Smash meter's points to fill (a bonus hero).
  static const meterPoints = 320;

  static const _step = 1 / 60;
  static const _hillBit = 0x0002;
  static const _monsterKinds = ['gloop', 'fuzz', 'bonk', 'boo'];

  late World world;
  late Body ground;

  MsPhase phase = MsPhase.ready;
  double time = 0, phaseTime = 0;

  /// The room being smashed (0, 1, 2 …).
  int room = -1;

  final List<MsBlock> blocks = [];
  final List<MsMonster> monsters = [];

  /// What is in the air: the hero, or Inky's drops.
  final List<MsShot> shots = [];

  /// The hero flung last (the middle drop once Inky split), while it flies.
  MsShot? get shot => shots.isEmpty ? null : shots.first;

  /// The heroes in line (the next one first), for the whole level.
  final List<MsHero> heroes = [];

  /// The Smash meter, 0..1: smashing fills it, full brings a bonus hero.
  double meter = 0;
  int bonuses = 0;

  /// What Pencil asks about this room, and which one now.
  List<MsAsk> towerAsks = [];
  int askAt = 0;
  MsAsk? get ask => askAt < towerAsks.length ? towerAsks[askAt] : null;

  /// Shots without hitting the asked letter (resets with each letter).
  int misses = 0;

  /// The ball's pull while the child drags (null: not dragging).
  Vector2? pull;
  Vector2? _grab;

  int score = 0, flings = 0, found = 0, friends = 0, refills = 0;

  /// The asked letters this game, and shots that found nothing.
  int asked = 0, wasted = 0;

  /// When a letter was found / a shot missed / a hero was flung last.
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

  /// 3 stars for at most one wasted shot a room and no refill, 2 for a few
  /// more, else 1.
  int get stars => wasted <= rooms && refills == 0 ? 3 : (wasted <= 2 * rooms + 2 ? 2 : 1);

  bool get over => phase == MsPhase.done;

  /// The hero in the slingshot (where it is drawn while aiming).
  Vector2 get ballInSling => pull == null ? rest.clone() : rest + pull!;

  MsBlock? blockOf(Body b) => b.userData is MsBlock ? b.userData as MsBlock : null;

  // ---------------------------------------------------------------- setup

  void start() {
    room = -1;
    score = flings = found = friends = refills = asked = wasted = bonuses = 0;
    meter = 0;
    heroes
      ..clear()
      ..addAll(level.heroes);
    _nextRoom();
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
    // the hill under the slingshot and the waiting heroes
    // (a hero passes through it: one pulled down starts inside it)
    final hill = world.createBody(BodyDef(userData: 'hill'));
    hill.createFixture(
      FixtureDef(
        PolygonShape()..set([Vector2(hillX - hillHalfFoot, 0), Vector2(hillX + hillHalfFoot, 0), Vector2(hillX + hillHalfTop, hillTop), Vector2(hillX - hillHalfTop, hillTop)]),
        friction: .8,
        filter: Filter()..categoryBits = _hillBit,
      ),
    );
  }

  void _nextRoom() {
    room++;
    if (room >= rooms) {
      // the heroes still in line are a bonus
      score += heroes.length * 100;
      _set(MsPhase.done);
      _events.add(MsEvent(MsEventKind.done, value: score.toDouble()));
      return;
    }
    _newWorld();
    blocks.clear();
    monsters.clear();
    shots.clear();
    pull = null;
    hintBlock = null;
    misses = 0;
    final r = level.rooms[room];
    final plan = r.build(_rnd);
    final (shown, list) = asks.tower(math.min(r.letters, plan.letterSpots), math.min(r.asks, math.min(r.letters, plan.letterSpots)));
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
    // let the tower settle unseen, so it stands still when it appears
    _live = false;
    for (var i = 0; i < 120; i++) {
      world.stepDt(_step);
    }
    _impacts.clear();
    _touches.clear();
    _live = true;
    _set(MsPhase.build);
    _events.add(MsEvent(MsEventKind.build, value: room.toDouble()));
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
  /// screen takes hold of the hero.
  bool grab(Vector2 p) {
    if (phase != MsPhase.aim || heroes.isEmpty || p.x > width * .45) return false;
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

  /// The child picks hero [i] of the line to go next (a card): it jumps
  /// into the slingshot, the one there steps back.
  bool pick(int i) {
    if (phase != MsPhase.aim || pull != null || i <= 0 || i >= heroes.length) return false;
    heroes.insert(0, heroes.removeAt(i));
    _events.add(MsEvent(MsEventKind.pick, text: heroes.first.name, value: i.toDouble()));
    return true;
  }

  /// The hero's speed for a pull [p] (opposite to it).
  static Vector2 velocity(Vector2 p) => p * (-maxSpeed / maxPull);

  /// Flings the next hero with pull [p] (the finger, or a test).
  void launch(Vector2 p) {
    if (phase != MsPhase.aim || heroes.isEmpty) return;
    final hero = heroes.removeAt(0);
    final v = MsVolley(hero);
    shots
      ..clear()
      ..add(_shoot(hero, v, rest + p, velocity(p), heroRadius[hero]!));
    flings++;
    throwAt = time;
    _set(MsPhase.flying);
    _events.add(MsEvent(MsEventKind.launch, value: p.length / maxPull, text: hero.name));
  }

  MsShot _shoot(MsHero hero, MsVolley v, Vector2 at, Vector2 speed, double r, {bool drop = false}) {
    final body = world.createBody(BodyDef(type: BodyType.dynamic, position: at, bullet: true, linearVelocity: speed, angularDamping: .3));
    final (density, bounce) = switch (hero) {
      MsHero.rubby => (4.06, .4),
      MsHero.inky => (drop ? 3.46 : 3.56, .15),
      MsHero.crayo => (4.19, .2),
    };
    body.createFixture(
      FixtureDef(CircleShape()..radius = r, density: density, friction: .6, restitution: bounce, filter: Filter()..maskBits = 0xFFFF & ~_hillBit),
    );
    final s = MsShot(hero, body, v, radius: r, drop: drop);
    body.userData = s;
    return s;
  }

  /// A tap while the hero flies: its power, once a fling.
  ///  * Rubby: a big "boing" that pushes everything in front of him.
  ///  * Inky: splits into three drops, fanning out.
  ///  * Crayo: zooms straight on, fast, breaking through wood and ice.
  bool power() {
    final s = shot;
    if (phase != MsPhase.flying || s == null || s.gone || s.volley.powered) return false;
    final v = s.volley;
    v.powered = true;
    v.poweredAt = time;
    final at = s.body.position.clone();
    final speed = s.body.linearVelocity.clone();
    switch (s.hero) {
      case MsHero.rubby:
        final dir = speed.length < .1 ? Vector2(1, 0) : speed.normalized();
        _boing(at, dir);
      case MsHero.inky:
        final drops = [
          for (final a in [.22, 0.0, -.22])
            _shoot(MsHero.inky, v, at + (Vector2(-speed.y, speed.x)..normalize()) * (a * 1.6), _turn(speed, a) * 1.05, dropRadius, drop: true),
        ];
        world.destroyBody(s.body);
        shots
          ..clear()
          ..add(drops[1])
          ..add(drops[0])
          ..add(drops[2]);
      case MsHero.crayo:
        final dir = speed.length < .1 ? Vector2(1, 0) : speed.normalized();
        s.body.linearVelocity = dir * math.max(17.0, speed.length * 1.9);
        s.body.gravityScale = Vector2.all(.25);
        s.pierce = true;
    }
    _events.add(MsEvent(MsEventKind.power, x: at.x, y: at.y, text: s.hero.name));
    return true;
  }

  static Vector2 _turn(Vector2 v, double a) {
    final c = math.cos(a), s = math.sin(a);
    return Vector2(v.x * c - v.y * s, v.x * s + v.y * c);
  }

  /// Rubby's boing: everything within reach in front of him is pushed away
  /// (and the blocks take a knock).
  void _boing(Vector2 at, Vector2 dir) {
    const reach = 2.6;
    for (final o in world.bodies) {
      if (o.bodyType != BodyType.dynamic || o.userData is MsShot) continue;
      final d = o.position - at;
      final dist = d.length;
      if (dist > reach || d.dot(dir) < -.4) continue;
      final k = 1 - dist / reach;
      final push = (dist < .05 ? dir.clone() : (d.normalized()..add(dir)..normalize()))..scale(o.mass * 5.5 * k);
      o.applyLinearImpulse(push);
      final block = blockOf(o);
      if (block != null && block.letter == null) block.health -= 1.6 * k;
      if (o.userData case final MsMonster m when !m.friend) m.startled = time;
    }
  }

  /// Where a hero pulled by [p] would go (no blocks in the way): one dot
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
          _refill();
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
        final v = shot?.volley;
        if (v != null) v.time += dt;
        for (final s in shots) {
          if (s.gone) continue;
          final b = s.body;
          s.trail.add(b.position.clone());
          if (s.trail.length > 14) s.trail.removeAt(0);
          s.still = b.linearVelocity.length < .35 ? s.still + dt : 0;
          final out = b.position.x > width + 1 || b.position.x < -1 || b.position.y < -2;
          if (out || s.still > .6 || (v?.time ?? 0) > 7) _shotGone(s);
        }
        if (shots.every((s) => s.gone)) _set(MsPhase.settle);
      case MsPhase.settle:
        _quiet = _moving() ? 0 : _quiet + dt;
        if (_quiet > .45 || phaseTime > 3.2) _afterShot();
      case MsPhase.cleared:
        if (phaseTime > 3.0) _nextRoom();
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

  void _shotGone(MsShot s) {
    if (s.gone) return;
    s.gone = true;
    s.restAt = s.body.position.clone();
    _events.add(MsEvent(MsEventKind.ballGone, x: s.body.position.x, y: s.body.position.y, text: s.hero.name));
    world.destroyBody(s.body);
  }

  void _afterShot() {
    final v = shot?.volley;
    shots.clear();
    var next = v != null && v.hitTarget;
    if (v != null && !next) {
      misses++;
      wasted++;
      if (!v.wrongSaid) _events.add(const MsEvent(MsEventKind.miss));
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
      _set(MsPhase.cleared);
      _events.add(MsEvent(MsEventKind.cleared, value: room.toDouble()));
      return;
    }
    if (next) _ask();
    _refill();
    _set(MsPhase.aim);
  }

  /// An empty line fills up again (fewer stars): there is no losing.
  void _refill() {
    if (heroes.isNotEmpty) return;
    refills++;
    heroes.addAll([MsHero.rubby, MsHero.rubby]);
    _events.add(const MsEvent(MsEventKind.refill));
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
    for (final b in blocks) {
      if (!b.gone && b.health <= 0) _smash(b);
    }
  }

  /// [a] began touching [b].
  void _touch(Body a, Body b) {
    final s = a.userData;
    if (s is MsMonster && !s.friend && b.userData == 'ground' && s.startY > .6) _befriend(s);
    if (s is! MsShot || s.gone) return;
    final block = blockOf(b);
    // one letter a fling: the next one is asked first
    final v = s.volley;
    if (block == null || block.letter == null || block.gone || v.hitTarget) return;
    v.touched.add(block.id);
    if (block.letter == ask?.letter) {
      v.hitTarget = true;
      _found(block);
    } else if (!v.wrongSaid) {
      v.wrongSaid = true;
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
    if (o is MsShot) {
      o.hitAt = time;
      o.hitHard = math.min(1, j / 6);
    }
    final fromHero = s is MsShot;
    final hit = j * (fromHero ? (s.hero == MsHero.crayo ? 2.2 : 1.6) : 1.0);
    if (o is MsBlock && !o.gone) {
      if (j > 1.2) _knock(o.material, o.position, j);
      if (o.letter != null) return;
      // Crayo's dash goes through wood and ice
      if (s is MsShot && s.pierce && o.material != MsMaterial.stone) {
        o.health = 0;
        return;
      }
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
    _fill(points);
  }

  /// Smashing fills the Smash meter; full, a bonus hero joins the line.
  void _fill(int points) {
    if (phase == MsPhase.cleared || phase == MsPhase.done) return;
    meter += points / meterPoints;
    if (meter < 1) return;
    meter -= 1;
    bonuses++;
    final hero = level.heroes.contains(MsHero.crayo) && bonuses.isEven ? MsHero.crayo : MsHero.rubby;
    heroes.add(hero);
    _events.add(MsEvent(MsEventKind.bonus, text: hero.name));
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
    _fill(points * 2);
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
