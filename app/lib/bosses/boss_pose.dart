import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// What a world boss is doing.
enum BossMood {
  /// Fast asleep: slow breathing, closed eyes, a snore bubble and "z z z".
  asleep,

  /// Asleep, but every few seconds it opens a sleepy eye, peeks around
  /// ("is someone coming?") and drifts off again: the boss of the world the
  /// child is in.
  dozing,

  /// Waking up (once, [BossMotion.wakeSeconds]): eyelids flutter, a big
  /// yawn and stretch, eyes pop open, a happy hop.
  waking,

  /// Awake and idle: blinks, looks around, breathes, waves now and then.
  awake,

  /// Woken by the child: hops to the beat, arms up, laughing.
  dance,
}

enum BossEyes { open, closed, happy, wow }

enum BossMouth { snore, smile, grin, laugh, wow, yawn }

/// One frame of a boss. Every design reads the same channels, so one
/// timeline animates all fourteen bosses.
class BossPose {
  const BossPose({
    this.squash = 0,
    this.lift = 0,
    this.tilt = 0,
    this.head = 0,
    this.eyes = BossEyes.open,
    this.lid = 0,
    this.look = Offset.zero,
    this.mouth = BossMouth.smile,
    this.open = 0,
    this.swing = 0,
    this.raise = 0,
    this.flap = 0,
    this.brow = 0,
    this.zzz = 0,
    this.breath = 0,
  });

  /// > 0 wider and shorter, < 0 taller; the feet stay on the ground.
  final double squash;

  /// Hop height in art units (the art is 120 x 100).
  final double lift;

  /// Lean in radians, around the feet.
  final double tilt;

  /// Head droop / nod in radians (heads that are a separate part).
  final double head;

  final BossEyes eyes;

  /// Eyelid for [BossEyes.open]: 0 open, 1 shut.
  final double lid;

  /// Where the pupils look, -1..1.
  final Offset look;

  final BossMouth mouth;

  /// Mouth opening 0..1 (snore, laugh, wow and yawn).
  final double open;

  /// Arms, tail, ears and antennae side to side, -1..1.
  final double swing;

  /// Arms up, 0..1 (stretch, cheer).
  final double raise;

  /// Wings, fins and claws, 0..1 (fast).
  final double flap;

  /// Eyebrows: -1 sleepy .. 1 surprised.
  final double brow;

  /// How much the sleep effects show (z z z, snore bubble), 0..1.
  final double zzz;

  /// Breathing in, 0..1 (snore bubble, the frog's throat).
  final double breath;

  static double _l(double a, double b, double t) => a + (b - a) * t;

  static BossPose lerp(BossPose a, BossPose b, double t) => BossPose(
        squash: _l(a.squash, b.squash, t),
        lift: _l(a.lift, b.lift, t),
        tilt: _l(a.tilt, b.tilt, t),
        head: _l(a.head, b.head, t),
        eyes: t < .5 ? a.eyes : b.eyes,
        lid: _l(a.lid, b.lid, t),
        look: Offset.lerp(a.look, b.look, t)!,
        mouth: t < .5 ? a.mouth : b.mouth,
        open: _l(a.open, b.open, t),
        swing: _l(a.swing, b.swing, t),
        raise: _l(a.raise, b.raise, t),
        flap: _l(a.flap, b.flap, t),
        brow: _l(a.brow, b.brow, t),
        zzz: _l(a.zzz, b.zzz, t),
        breath: _l(a.breath, b.breath, t),
      );
}

/// Pure timelines: mood + seconds -> pose. [seed] (the boss index) shifts
/// blinks and glances so two bosses on one screen never move in step.
abstract final class BossMotion {
  static const double wakeSeconds = 2.0;

  static BossPose sample(BossMood mood, double t, {int seed = 0}) => switch (mood) {
        BossMood.asleep => asleep(t, seed),
        BossMood.dozing => dozing(t, seed),
        BossMood.waking => waking(t, seed),
        BossMood.awake => awake(t, seed),
        BossMood.dance => dance(t, seed),
      };

  /// The wake-up, then [after] (awake or dance); blends over the last 0.2 s.
  static BossPose wakeThen(BossMood after, double sinceWoke, double clock, {int seed = 0}) {
    if (sinceWoke >= wakeSeconds) return sample(after, clock, seed: seed);
    final w = waking(sinceWoke, seed);
    final k = (sinceWoke - (wakeSeconds - .2)) / .2;
    return k <= 0 ? w : BossPose.lerp(w, sample(after, clock, seed: seed), _ease(k));
  }

  // ---------------------------------------------------------------- asleep
  static BossPose asleep(double t, int seed) {
    final k = _ease(_tri((t + seed * .37) / 3.2)); // breathing in, 3.2 s
    return BossPose(
      squash: .035 * k - .01,
      head: .05 + .04 * k,
      eyes: BossEyes.closed,
      lid: 1,
      mouth: BossMouth.snore,
      open: .3 + .7 * k,
      swing: .12 * math.sin((t + seed) * 2 * math.pi / 6.4),
      flap: .12 * k,
      brow: -.5,
      zzz: 1,
      breath: k,
    );
  }

  // ---------------------------------------------------------------- dozing
  static const double _dozePeriod = 6.5, _peek = 1.8;

  static BossPose dozing(double t, int seed) {
    final base = asleep(t, seed);
    final p = ((t + seed * 1.1) % _dozePeriod) - (_dozePeriod - _peek);
    if (p < 0) return base;
    final k = _ease(math.sin(p / _peek * math.pi) * 1.4); // in, hold, out
    final look = Offset(math.sin(p * 2.2) * .8, .15);
    return BossPose.lerp(
      base,
      BossPose(eyes: BossEyes.open, lid: .45, look: look, mouth: BossMouth.smile, brow: .35, squash: -.02, head: 0, swing: .1),
      k,
    );
  }

  // ---------------------------------------------------------------- poked
  /// Seconds a poke reaction lasts (see [poked]).
  static const double pokeSeconds = 2.3;

  /// A tap (or a won round) startles the boss: a sleeping one flutters its
  /// eyes, yawns and stares "wow", then nods off again; an awake one does a
  /// little dance. [base] is the pose it returns to.
  static BossPose poked(BossPose base, double since, {required bool sleeping, int seed = 0}) {
    if (since < 0 || since >= pokeSeconds) return base;
    final react = sleeping ? waking(math.min(since, 1.5), seed) : dance(since, seed);
    final inK = sleeping ? 1.0 : _ease(since / .15);
    final outK = _ease((pokeSeconds - since) / .5);
    return BossPose.lerp(base, react, math.min(inK, outK));
  }

  // ---------------------------------------------------------------- waking
  static BossPose waking(double t, int seed) {
    if (t < .6) {
      // eyelids flutter: shut, half, shut, more, nearly shut
      const keys = [1.0, .5, 1.0, .3, .85];
      final f = t / .6 * (keys.length - 1);
      final i = f.floor().clamp(0, keys.length - 2);
      final lid = _l(keys[i], keys[i + 1], _ease(f - i));
      return BossPose(eyes: BossEyes.open, lid: lid, mouth: BossMouth.snore, open: .3, brow: -.3, head: .05 * (1 - t / .6), zzz: 1 - t / .6);
    }
    if (t < 1.3) {
      // a big yawn and stretch
      final p = (t - .6) / .7;
      final k = math.sin(p * math.pi);
      return BossPose(
        squash: -.09 * k,
        tilt: .05 * math.sin(p * 2 * math.pi),
        eyes: k > .35 ? BossEyes.closed : BossEyes.open,
        lid: .85,
        mouth: BossMouth.yawn,
        open: k,
        raise: k,
        swing: .3 * math.sin(p * 2 * math.pi),
        brow: -.2,
      );
    }
    if (t < 1.55) {
      // eyes pop open
      final p = (t - 1.3) / .25;
      return BossPose(squash: .07 * (1 - p), eyes: BossEyes.wow, mouth: BossMouth.wow, open: .7, brow: 1, raise: .2 * (1 - p));
    }
    // a happy hop
    final p = ((t - 1.55) / .45).clamp(0.0, 1.0);
    final air = math.sin(p * math.pi);
    return BossPose(
      lift: 12 * air,
      squash: p < .12 ? .06 * (1 - p / .12) : -.05 * air,
      eyes: BossEyes.happy,
      mouth: BossMouth.laugh,
      open: .6 + .4 * air,
      raise: .9 * air,
      flap: .5 + .5 * math.sin(t * 2 * math.pi / .2),
      brow: .7,
    );
  }

  // ---------------------------------------------------------------- awake
  static BossPose awake(double t, int seed) {
    final bob = math.sin(t * 2 * math.pi / 2.4);
    // every 7 s a little wave hello (1.4 s)
    final w = ((t + seed * 1.7) % 7.0) - 5.0;
    final waving = w >= 0 && w < 1.4;
    final env = waving ? math.sin(w / 1.4 * math.pi) : 0.0;
    return BossPose(
      squash: .015 * bob,
      tilt: .025 * math.sin(t * 2 * math.pi / 4.8),
      lid: blink(t, seed),
      look: lookAround(t, seed),
      mouth: waving ? BossMouth.grin : BossMouth.smile,
      open: .7 * env,
      swing: waving ? env * math.sin(w * 2 * math.pi * 1.6) : .22 * math.sin(t * 2 * math.pi / 2.4),
      raise: .55 * env,
      flap: .25 + .2 * bob,
      brow: .25 * env,
    );
  }

  // ---------------------------------------------------------------- dance
  static BossPose dance(double t, int seed) {
    const beat = .55;
    final p = (t / beat) % 1.0;
    final n = (t / beat).floor();
    final air = math.sin(p * math.pi);
    final land = p < .14 ? 1 - p / .14 : 0.0;
    final side = n.isEven ? 1.0 : -1.0;
    return BossPose(
      squash: .09 * land - .05 * air,
      lift: 11 * air,
      tilt: side * .14 * air,
      eyes: n % 4 == 3 ? BossEyes.open : BossEyes.happy,
      look: Offset(side * .5, -.3),
      mouth: BossMouth.laugh,
      open: .55 + .45 * air,
      swing: math.sin(t * 2 * math.pi / (2 * beat)),
      raise: .55 + .45 * air,
      flap: .5 + .5 * math.sin(t * 2 * math.pi / .18),
      brow: .7,
    );
  }

  // ---------------------------------------------------------------- helpers
  /// Eyelid of a blink, 0..1: one blink every ~2–5 s, sometimes a double.
  static double blink(double t, int seed) {
    const period = 3.6;
    final off = seed * 1.3;
    final c = ((t + off) / period).floor();
    final start = c * period - off + .4 + _hash(c * 31 + seed) * 2.4;
    double one(double x) => x < 0 || x > .18 ? 0 : math.sin(x / .18 * math.pi);
    var b = one(t - start);
    if (_hash(c * 17 + seed) > .7) b = math.max(b, one(t - start - .28));
    return b;
  }

  /// Glances: holds a look for 2.6 s, then darts to the next.
  static Offset lookAround(double t, int seed) {
    const hold = 2.6;
    final x = (t + seed * .9) / hold;
    final c = x.floor();
    Offset at(int i) => i % 3 == 0 ? Offset.zero : Offset(_hash(i * 13 + seed) * 2 - 1, (_hash(i * 7 + seed) * 2 - 1) * .6);
    return Offset.lerp(at(c - 1), at(c), _ease((x - c) / .12))!;
  }

  static double _ease(double x) => Curves.easeInOut.transform(x.clamp(0.0, 1.0));
  static double _tri(double x) => 1 - (2 * (x % 1.0) - 1).abs();
  static double _l(double a, double b, double t) => a + (b - a) * t;

  static double _hash(int n) {
    var x = (n * 374761393 + 668265263) & 0x7fffffff;
    x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
    return (x % 10007) / 10007;
  }
}
