import 'dart:math' as math;

import '../../../game/monster_smash/ms_engine.dart';
import '../game_spring.dart';

/// One monster's life on top of the physics.
class MsLife {
  MsLife(this.nextTaunt);

  /// Squash (-) and stretch (+), soft.
  final squash = Spring(0, stiffness: 260, damping: 9);

  /// 0..1: scared (the ball comes).
  double fear = 0;
  double vy = 0, tauntAt = -9, nextTaunt;
  bool friend = false, squeaked = false;
}

/// How Monster Smash's monsters move on top of the physics: they stretch as
/// they fall and squash when they land, look scared when the ball comes,
/// giggle at Pencil now and then (a cheeky hop),
/// see dizzy stars when knocked and hop happily once they are friends.
/// Times are the game's ([MsGame.time]).
class MsMonsterLives {
  MsMonsterLives({math.Random? random}) : _rnd = random ?? math.Random();
  final math.Random _rnd;

  // the tower's monsters and their lives, side by side (plain lists: a map
  // keyed by monster with closures crashed the iOS release build)
  final List<MsMonster> _monsters = [];
  final List<MsLife> _lives = [];

  /// How long a taunt lasts, and the dizzy stars after a knock.
  static const tauntTime = .7, dizzyTime = 1.0;

  MsLife of(MsMonster m) {
    final i = _monsters.indexOf(m);
    return i < 0 ? MsLife(9) : _lives[i];
  }

  /// Moves them on; calls [giggle] when one taunts and [eek] when one sees
  /// the ball coming (one sound at a time).
  void update(double dt, MsGame g, {required void Function() giggle, required void Function() eek}) {
    final t = g.time;
    final monsters = g.monsters;
    // a new tower: new monsters, new lives (the old ones kept by monster)
    var same = monsters.length == _monsters.length;
    for (var i = 0; same && i < monsters.length; i++) {
      same = identical(monsters[i], _monsters[i]);
    }
    if (!same) {
      final lives = <MsLife>[];
      for (final m in monsters) {
        final i = _monsters.indexOf(m);
        lives.add(i < 0 ? MsLife(t + 2 + _rnd.nextDouble() * 4) : _lives[i]);
      }
      _monsters
        ..clear()
        ..addAll(monsters);
      _lives
        ..clear()
        ..addAll(lives);
    }
    final shot = g.shot;
    final flying = shot != null && !shot.gone && g.phase == MsPhase.flying;
    final ballAt = shot?.body.position, ballV = shot?.body.linearVelocity;
    final pulled = g.pull;
    var giggled = false, squeaked = false;
    for (var k = 0; k < monsters.length; k++) {
      final m = monsters[k];
      final life = _lives[k];

      // a fall stretches it, a landing squashes it
      final vy = m.body.linearVelocity.y;
      final dv = vy - life.vy;
      if (life.vy < -1.5 && dv > 1.5) life.squash.kick(-math.min(7.0, dv * 1.3));
      life.vy = vy;
      life.squash.target = (-vy * .03).clamp(0.0, .22);

      // turning into a friend: a happy stretch up
      if (m.friend && !life.friend) {
        life.friend = true;
        life.squash.kick(5);
      }
      life.squash.step(dt);

      // scared: the ball coming near
      var scared = 0.0;
      if (!m.friend && flying && ballAt != null && ballV != null) {
        final d = m.position - ballAt;
        if (d.dot(ballV) > 0 && d.length < 4.5) scared = 1;
      }
      life.fear += (scared - life.fear) * math.min(1, dt * 8);
      if (life.fear > .6 && flying && !life.squeaked) {
        life.squeaked = true;
        if (!squeaked) eek();
        squeaked = true;
      }
      if (!flying) life.squeaked = false;

      // a cheeky giggle and hop while the child is choosing
      if (!m.friend && g.phase == MsPhase.aim && pulled == null && t >= life.nextTaunt) {
        life.tauntAt = t;
        life.nextTaunt = t + 4 + _rnd.nextDouble() * 5;
        if (!giggled) giggle();
        giggled = true;
      }
    }
  }
}

/// How a monster looks this frame.
class MsMonsterLook {
  const MsMonsterLook({required this.pose, this.hop = 0, this.turn = 0, this.scaleX = 1, this.scaleY = 1, this.dizzy = 0});

  /// Its picture (idle, surprised, roar, bonked, friendly).
  final String pose;

  /// Up (metres), a lean (radians).
  final double hop, turn;
  final double scaleX, scaleY;

  /// The dizzy stars' time (0: none).
  final double dizzy;

  static MsMonsterLook of(MsMonster m, MsLife life, double t) {
    final s = life.squash.value;
    final seed = m.id * 1.7;
    if (m.friend) {
      final since = t - m.friendAt;
      if (since < MsMonsterLives.dizzyTime) {
        final wobble = math.sin(since * 14) * (1 - since / MsMonsterLives.dizzyTime);
        return MsMonsterLook(pose: 'bonked', turn: .22 * wobble, scaleX: 1 - .5 * s, scaleY: 1 + s, dizzy: since);
      }
      // happy hops, each a little squash on landing
      final h = math.sin((t + seed) * 5.5);
      final hop = math.max(0.0, h) * .2;
      final land = math.max(0.0, -h) * .08;
      return MsMonsterLook(pose: 'friendly', hop: hop, turn: .1 * math.sin((t + seed) * 2.75), scaleX: 1 + land - .5 * s, scaleY: 1 - land + s);
    }
    final breathe = .025 * math.sin(t * 3 + seed);
    final taunt = t - life.tauntAt;
    if (taunt < MsMonsterLives.tauntTime && life.fear < .3) {
      final k = taunt / MsMonsterLives.tauntTime;
      final hop = math.sin(math.pi * math.min(1.0, k * 1.6)).clamp(0.0, 1.0) * .22;
      return MsMonsterLook(pose: 'roar', hop: hop, turn: .1 * math.sin(taunt * 18) * (1 - k), scaleX: 1 - .5 * s - .5 * breathe, scaleY: 1 + s + breathe);
    }
    return MsMonsterLook(
      pose: life.fear > .4 || t - m.startled < 1.3 ? 'surprised' : 'idle',
      scaleX: 1 - .5 * s - .5 * breathe + .04 * life.fear,
      scaleY: 1 + s + breathe - .06 * life.fear,
    );
  }
}
