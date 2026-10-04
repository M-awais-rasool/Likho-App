import 'dart:math' as math;
import 'dart:ui';

import '../../design/tokens.dart';

/// Layout of the world map, ported from the prototype (mapGeom / mapVals).
/// The map is one tall canvas: world 1 at the bottom, the last world at the
/// top. Each world is a block of 900 px with up to 6 levels 128 px apart;
/// a world with more levels (added in the admin panel) gets a taller block.
/// [levelsPerWorld] says how many map levels each world has, in order
/// (levels are numbered 1, 2, 3… world after world).
class MapGeometry {
  MapGeometry(this.width, {List<int> levelsPerWorld = const [6, 6, 6, 6, 6, 6], List<int>? decoKinds})
      : contentWidth = math.min(width, 520),
        offsetX = (width - math.min(width, 520)) / 2,
        levelsPerWorld = List.unmodifiable(levelsPerWorld),
        decoKinds = List.unmodifiable(decoKinds ?? [for (var w = 0; w < levelsPerWorld.length; w++) w % _kinds.length]) {
    var y = 0.0;
    for (final k in levelsPerWorld) {
      _blockStart.add(y);
      y += blockOf(k);
    }
    _blocksHeight = y;
    for (var w = 0; w < levelsPerWorld.length; w++) {
      for (var li = 0; li < levelsPerWorld[w]; li++) {
        _place.add((w, li));
      }
    }
  }

  final double width;
  final double contentWidth;
  final double offsetX;
  final List<int> levelsPerWorld;

  /// Decoration set per world (index into the six worlds' kinds), so a new
  /// world looks like the world whose theme it borrows.
  final List<int> decoKinds;

  static const double block = 900; // one world of up to 6 levels
  static const double top = 190;
  static const double bottom = 150;
  static const _xs = [.32, .64, .74, .46, .26, .52];

  final List<double> _blockStart = []; // from the bottom
  late final double _blocksHeight;
  final List<(int, int)> _place = []; // level n-1 -> (world, index in world)

  /// Height of a world's block with [levels] levels.
  static double blockOf(int levels) => math.max(block, 110 + (levels - 1) * 128 + 12 + 138);

  int get worlds => levelsPerWorld.length;
  int get levels => _place.length;

  /// The whole canvas (5740 for six worlds of six levels).
  double get height => top + _blocksHeight + bottom;

  /// Bottom edge of world [w]'s block.
  double worldBottom(int w) => height - bottom - _blockStart[w];

  /// Centre of level [n] (1..levels).
  Offset node(int n) {
    final (w, li) = _place[n - 1];
    final x = offsetX + contentWidth * (w.isOdd ? 1 - _xs[li % 6] : _xs[li % 6]);
    final last = li == levelsPerWorld[w] - 1; // the boss: 12 px higher
    final y = worldBottom(w) - 110 - li * 128 - (last ? 12 : 0);
    return Offset(x, y);
  }

  /// Vertical extent of world [w]'s background section.
  (double top, double height) section(int w) {
    final yb = worldBottom(w);
    final t = w == worlds - 1 ? 0.0 : yb - blockOf(levelsPerWorld[w]);
    return (t, yb - t + (w == 0 ? bottom : 0));
  }

  /// "M x1 y1 C prev.x prev.y-70, x y+70, x y" through every node.
  Path path() {
    final p = Path();
    if (levels == 0) return p;
    final a = node(1);
    p.moveTo(a.dx, a.dy);
    for (var n = 2; n <= levels; n++) {
      final q = node(n), pq = node(n - 1);
      p.cubicTo(pq.dx, pq.dy - 70, q.dx, q.dy + 70, q.dx, q.dy);
    }
    return p;
  }

  /// Scroll offset (from the top) that puts level [n] at 55 % of the view.
  double scrollFor(int n, double viewport) =>
      (node(n.clamp(1, math.max(levels, 1))).dy - viewport * .55).clamp(0.0, math.max(0.0, height - viewport));

  /// Decorations: 12 per 900 px of world, placed by the prototype's seeded
  /// generator.
  List<MapDeco> decorations() {
    var seed = 11;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    final out = <MapDeco>[];
    for (var i = 0; i < worlds; i++) {
      final yb = worldBottom(i);
      final h = blockOf(levelsPerWorld[i]);
      final count = (12 * h / block).round();
      final kinds = _kinds[decoKinds[i] % _kinds.length];
      for (var k = 0; k < count; k++) {
        final kind = kinds[k % 3];
        final left = k.isEven;
        final x = left ? rnd() * (offsetX + contentWidth * .14) : width - rnd() * (offsetX + contentWidth * .14) - kind.w;
        final y = yb - h + 40 + k * (h - 80) / count + rnd() * 30;
        final delay = double.parse((rnd() * -6).toStringAsFixed(1));
        out.add(MapDeco(world: i, kind: kind, rect: Rect.fromLTWH(x, y, kind.w, kind.h), phase: -delay));
      }
    }
    return out;
  }

  static const _kinds = [
    [
      DecoKind(78, 48, DecoRadius.percent(50, 50, 40, 40), MapColors.bush, DecoAnim.sway, 6),
      DecoKind(14, 14, DecoRadius.percent(50, 50, 50, 50), MapColors.flower, DecoAnim.sway, 4, ring: 5),
      DecoKind(96, 30, DecoRadius.px(20, 20, 20, 20), MapColors.cloud, DecoAnim.drift, 8),
    ],
    [
      DecoKind(84, 14, DecoRadius.px(10, 10, 10, 10), MapColors.wave, DecoAnim.waveBob, 4),
      DecoKind(44, 30, DecoRadius.percent(50, 50, 50, 50), MapColors.sand, DecoAnim.none, 0),
      DecoKind(26, 22, DecoRadius.percent(50, 50, 40, 40), MapColors.shell, DecoAnim.sway, 5),
    ],
    [
      DecoKind(80, 80, DecoRadius.percent(50, 50, 50, 50), MapColors.treeLight, DecoAnim.sway, 7),
      DecoKind(56, 56, DecoRadius.percent(50, 50, 50, 50), MapColors.treeDark, DecoAnim.sway, 6),
      DecoKind(18, 11, DecoRadius.px(10, 0, 10, 0), MapColors.leaf, DecoAnim.drift, 5),
    ],
    [
      DecoKind(54, 46, DecoRadius.px(10, 10, 4, 4), MapColors.houseRed, DecoAnim.none, 0),
      DecoKind(46, 56, DecoRadius.px(10, 10, 4, 4), MapColors.houseBlue, DecoAnim.none, 0),
      DecoKind(96, 30, DecoRadius.px(20, 20, 20, 20), MapColors.cloud, DecoAnim.drift, 8),
    ],
    [
      DecoKind(110, 36, DecoRadius.px(22, 22, 22, 22), MapColors.cloudWhite, DecoAnim.drift, 9),
      // rotate(45deg) is overridden by the sway animation in the prototype, so it only sways
      DecoKind(28, 28, DecoRadius.px(5, 5, 5, 5), MapColors.kite, DecoAnim.sway, 4),
      DecoKind(70, 26, DecoRadius.px(16, 16, 16, 16), MapColors.cloudSoft, DecoAnim.drift, 7),
    ],
    [
      DecoKind(6, 6, DecoRadius.percent(50, 50, 50, 50), MapColors.starDot, DecoAnim.twinkle, 3),
      DecoKind(48, 48, DecoRadius.percent(50, 50, 50, 50), MapColors.planet, DecoAnim.drift, 10, insetShade: true),
      DecoKind(8, 8, DecoRadius.percent(50, 50, 50, 50), MapColors.cloudWhite, DecoAnim.twinkle, 4),
    ],
  ];
}

enum DecoAnim { none, sway, drift, waveBob, twinkle }

/// CSS border-radius: corners TL, TR, BR, BL, either in px or % of the size.
class DecoRadius {
  const DecoRadius.px(this.tl, this.tr, this.br, this.bl) : percent = false;
  const DecoRadius.percent(this.tl, this.tr, this.br, this.bl) : percent = true;
  final double tl, tr, br, bl;
  final bool percent;

  RRect toRRect(Rect r) {
    Radius c(double v) => percent ? Radius.elliptical(r.width * v / 100, r.height * v / 100) : Radius.circular(v);
    return RRect.fromRectAndCorners(r, topLeft: c(tl), topRight: c(tr), bottomRight: c(br), bottomLeft: c(bl)).scaleRadii();
  }
}

class DecoKind {
  const DecoKind(this.w, this.h, this.radius, this.color, this.anim, this.seconds, {this.ring = 0, this.insetShade = false});
  final double w, h;
  final DecoRadius radius;
  final Color color;
  final DecoAnim anim;
  final double seconds; // animation length
  final double ring; // box-shadow 0 0 0 <ring>px #fff
  final bool insetShade; // box-shadow inset -8px -8px 0 rgba(0,0,0,.18)
}

class MapDeco {
  const MapDeco({required this.world, required this.kind, required this.rect, required this.phase});
  final int world;
  final DecoKind kind;
  final Rect rect;
  final double phase; // seconds already elapsed at t = 0 (negative CSS delay)
}
