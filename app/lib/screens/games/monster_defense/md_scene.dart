import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../game/monster_defense/md_engine.dart';

/// Monster Defense's pictures (`assets/games/monsters/`, cut from the Gemini
/// art by tools/games/cut_art.py) and where things are in the scene.
abstract final class MdArt {
  static const dir = 'assets/games/monsters';
  static const day = '$dir/bg_path_day.webp', sunset = '$dir/bg_path_sunset.webp';
  static const cover = '$dir/cover.webp';
  static String prop(String name) => '$dir/$name.webp';

  /// Every monster has the same poses (Big Bonk is Bonk, bigger).
  static const poses = ['walk_a', 'walk_b', 'roar', 'bonked', 'surprised', 'friendly'];

  static String art(MdKind k) => switch (k) {
    MdKind.gloop => 'gloop',
    MdKind.fuzz => 'fuzz',
    MdKind.bonk || MdKind.boss => 'bonk',
    MdKind.boo => 'boo',
  };

  static String pose(MdKind k, String pose) => '$dir/${art(k)}_$pose.webp';
  static String idle(MdKind k) => '$dir/${art(k)}_idle.webp';

  /// The pose pictures' size (all poses of a monster share it).
  static Size poseSize(MdKind k) => switch (k) {
    MdKind.gloop => const Size(410, 420),
    MdKind.fuzz => const Size(461, 420),
    MdKind.bonk || MdKind.boss => const Size(417, 420),
    MdKind.boo => const Size(439, 420),
  };

  /// The backgrounds' size (9:16).
  static const bgSize = Size(1080, 1935);

  /// Every picture the game shows (decoded before it starts).
  static List<String> get all => [
    day,
    sunset,
    for (final k in [MdKind.gloop, MdKind.fuzz, MdKind.bonk, MdKind.boo]) ...[for (final p in poses) pose(k, p)],
    for (final p in ['heart', 'star', 'ice', 'potion', 'chest', 'chest_open', 'trophy', 'wand']) prop(p),
  ];
}

/// The sandy path from the cave (u = 0) to the garden gate (u = 1), traced
/// from the background (fractions of its width and height): Catmull-Rom
/// through these points, measured so u is the distance along it.
@immutable
class MdPath {
  const MdPath._(this._pts, this._len);

  static const _points = [
    Offset(.735, .300), Offset(.700, .318), Offset(.627, .331), Offset(.555, .343), Offset(.498, .355), //
    Offset(.450, .369), Offset(.420, .388), Offset(.432, .405), Offset(.500, .420), Offset(.600, .437),
    Offset(.680, .458), Offset(.700, .478), Offset(.660, .497), Offset(.580, .513), Offset(.480, .531),
    Offset(.390, .550), Offset(.320, .570), Offset(.300, .590), Offset(.322, .608), Offset(.400, .627),
    Offset(.500, .645), Offset(.600, .666), Offset(.672, .688), Offset(.703, .710), Offset(.690, .738),
    Offset(.640, .765), Offset(.578, .790), Offset(.528, .812), Offset(.503, .838),
  ];

  /// The cave's mouth and the gate (where the path ends).
  static const cave = Offset(.735, .292), gate = Offset(.503, .838);

  static final MdPath shared = _build();

  final List<Offset> _pts; // samples, in picture pixels
  final List<double> _len; // distance from the start to each sample

  static MdPath _build() {
    final px = [for (final p in _points) Offset(p.dx * MdArt.bgSize.width, p.dy * MdArt.bgSize.height)];
    final pts = <Offset>[];
    for (var i = 0; i < px.length - 1; i++) {
      final p0 = px[math.max(0, i - 1)], p1 = px[i], p2 = px[i + 1], p3 = px[math.min(px.length - 1, i + 2)];
      for (var k = 0; k < 16; k++) {
        final t = k / 16, t2 = t * t, t3 = t2 * t;
        pts.add((p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * .5);
      }
    }
    pts.add(px.last);
    final len = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      len.add(len.last + (pts[i] - pts[i - 1]).distance);
    }
    return MdPath._(pts, len);
  }

  /// The point at [u] (0..1) in picture pixels, and the direction there.
  (Offset, Offset) _at(double u) {
    final d = u.clamp(0.0, 1.0) * _len.last;
    var lo = 0, hi = _len.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      _len[mid] <= d ? lo = mid : hi = mid;
    }
    final seg = _len[hi] - _len[lo];
    final t = seg == 0 ? 0.0 : (d - _len[lo]) / seg;
    final dir = _pts[hi] - _pts[lo];
    return (Offset.lerp(_pts[lo], _pts[hi], t)!, dir / math.max(dir.distance, 1e-6));
  }

  /// How big things are at picture height [fy] (far away is smaller):
  /// 0.32 at the cave, 1 at the gate.
  static double depth(double fy) => (.32 + .68 * ((fy - cave.dy) / (gate.dy - cave.dy))).clamp(.3, 1.15);

  /// Where a monster's feet are (picture fractions): [u] along the path,
  /// [lane] across it (-1..1), before the cave just inside its mouth.
  Offset feet(double u, double lane) {
    final (p, dir) = _at(u);
    final fy = p.dy / MdArt.bgSize.height;
    // half the path's width there
    // (wider than the sand far away, so monsters side by side keep apart)
    final half = (.045 + .045 * ((fy - cave.dy) / (gate.dy - cave.dy)).clamp(0.0, 1.0)) * MdArt.bgSize.width;
    final normal = Offset(-dir.dy, dir.dx);
    final at = p + normal * (lane * half);
    return Offset(at.dx / MdArt.bgSize.width, at.dy / MdArt.bgSize.height);
  }
}

/// Where the 9:16 background lands on the screen: it covers the screen and
/// always shows the cave and the gate (the top 17% of sky may be cut, then
/// the sides). [at] turns a picture point (fractions) into a screen point.
@immutable
class MdFrame {
  const MdFrame(this.screen);
  final Size screen;

  static const _skyCut = .17;

  double get scale => math.max(screen.width / MdArt.bgSize.width, screen.height / (MdArt.bgSize.height * (1 - _skyCut)));
  Size get size => MdArt.bgSize * scale;
  Offset get origin => Offset((screen.width - size.width) / 2, math.max(screen.height - size.height, -_skyCut * size.height));

  Offset at(Offset f) => origin + Offset(f.dx * size.width, f.dy * size.height);

  /// A monster's height on screen at depth 1 (the gate).
  double get monsterHeight => size.height * .118;

  @override
  bool operator ==(Object other) => other is MdFrame && other.screen == screen;
  @override
  int get hashCode => screen.hashCode;
}
