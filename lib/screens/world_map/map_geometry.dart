import 'dart:math' as math;
import 'dart:ui';

import '../../design/tokens.dart';

/// Layout of the world map, ported from the prototype (mapGeom / mapVals).
/// The map is one tall canvas: world 1 at the bottom, world 6 at the top.
class MapGeometry {
  MapGeometry(this.width)
      : contentWidth = math.min(width, 520),
        offsetX = (width - math.min(width, 520)) / 2;

  final double width;
  final double contentWidth;
  final double offsetX;

  static const double block = 900; // one world
  static const double top = 190;
  static const double bottom = 150;
  static const double height = top + 6 * block + bottom; // 5740
  static const _xs = [.32, .64, .74, .46, .26, .52];

  /// Bottom edge of world [w]'s block.
  double worldBottom(int w) => height - bottom - w * block;

  /// Centre of level [n] (1..36).
  Offset node(int n) {
    final w = (n - 1) ~/ 6, li = (n - 1) % 6;
    final x = offsetX + contentWidth * (w.isOdd ? 1 - _xs[li] : _xs[li]);
    final y = worldBottom(w) - 110 - li * 128 - (li == 5 ? 12 : 0);
    return Offset(x, y);
  }

  /// Vertical extent of world [w]'s background section.
  (double top, double height) section(int w) {
    final yb = worldBottom(w);
    final t = w == 5 ? 0.0 : yb - block;
    return (t, yb - t + (w == 0 ? bottom : 0));
  }

  /// "M x1 y1 C prev.x prev.y-70, x y+70, x y" through all 36 nodes.
  Path path() {
    final p = Path();
    final a = node(1);
    p.moveTo(a.dx, a.dy);
    for (var n = 2; n <= 36; n++) {
      final q = node(n), pq = node(n - 1);
      p.cubicTo(pq.dx, pq.dy - 70, q.dx, q.dy + 70, q.dx, q.dy);
    }
    return p;
  }

  /// Scroll offset (from the top) that puts level [n] at 55 % of the view.
  double scrollFor(int n, double viewport) => (node(n).dy - viewport * .55).clamp(0.0, math.max(0.0, height - viewport));

  /// Decorations: 12 per world, placed by the prototype's seeded generator.
  List<MapDeco> decorations() {
    var seed = 11;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    final out = <MapDeco>[];
    for (var i = 0; i < 6; i++) {
      final yb = worldBottom(i);
      for (var k = 0; k < 12; k++) {
        final kind = _kinds[i][k % 3];
        final left = k.isEven;
        final x = left ? rnd() * (offsetX + contentWidth * .14) : width - rnd() * (offsetX + contentWidth * .14) - kind.w;
        final y = yb - block + 40 + k * (block - 80) / 12 + rnd() * 30;
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
