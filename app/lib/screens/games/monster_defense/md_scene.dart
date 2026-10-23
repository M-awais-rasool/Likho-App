import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../game/monster_defense/md_engine.dart';
import 'md_art_boxes.dart';

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

  /// Where the monster is in pose picture [asset] (fractions; see
  /// tools/games/cut_art.py).
  static Rect box(String asset) => mdArtBoxes[asset.split('/').last.replaceAll('.webp', '')] ?? const Rect.fromLTRB(0, 0, 1, 1);

  /// A pose's frame [rect] moved so the monster in it stands on the frame's
  /// bottom middle (the poses of a sheet sit at different spots of it).
  static Rect placed(String asset, Rect rect) {
    final b = box(asset);
    return rect.shift(Offset((.5 - b.center.dx) * rect.width, (1 - b.bottom) * rect.height));
  }

  /// The monster itself, in its placed frame.
  static Rect content(String asset, Rect rect) {
    final b = box(asset), p = placed(asset, rect);
    return Rect.fromLTRB(p.left + b.left * p.width, p.top + b.top * p.height, p.left + b.right * p.width, p.top + b.bottom * p.height);
  }

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

  // the middle of the sand (each point the deepest spot of the sand near
  // a hand-placed one, measured from the picture)
  static const _points = [
    Offset(.734, .300), Offset(.683, .323), Offset(.623, .332), Offset(.542, .346), Offset(.481, .360), //
    Offset(.431, .380), Offset(.419, .395), Offset(.483, .418), Offset(.620, .438), Offset(.703, .474),
    Offset(.680, .496), Offset(.600, .516), Offset(.465, .535), Offset(.369, .554), Offset(.316, .581),
    Offset(.303, .595), Offset(.380, .628), Offset(.520, .650), Offset(.620, .674), Offset(.671, .699),
    Offset(.695, .722), Offset(.660, .753), Offset(.557, .778), Offset(.507, .823), Offset(.499, .845),
  ];

  /// The cave's mouth and the gate (where the path ends).
  static const cave = Offset(.734, .292), gate = Offset(.499, .845);

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
  /// 0.52 at the cave (still big enough to see a face), 1 at the gate.
  static double depth(double fy) => (.52 + .48 * ((fy - cave.dy) / (gate.dy - cave.dy))).clamp(.5, 1.1);

  /// The way the path goes at [u] (picture pixels, unit length).
  Offset direction(double u) => _at(u).$2;

  /// Where a monster's feet are (picture fractions): [u] along the path,
  /// [lane] across it (-1..1), before the cave just inside its mouth.
  Offset feet(double u, double lane) {
    final (p, dir) = _at(u);
    final fy = p.dy / MdArt.bgSize.height;
    // half the path's width there
    // half the sand's width there (monsters keep their feet on it)
    final half = (.016 + .07 * ((fy - cave.dy) / (gate.dy - cave.dy)).clamp(0.0, 1.0)) * MdArt.bgSize.width;
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
