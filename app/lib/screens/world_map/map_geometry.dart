import 'dart:math' as math;
import 'dart:ui';

/// Shared layout for the trail, scenery, level targets and camera.
/// The map is one tall canvas: world 1 at the bottom, the last world at the
/// top. Generous spacing leaves room for Pencil and the raised level tiles;
/// a world with more levels (added in the admin panel) gets a taller block.
/// [levelsPerWorld] says how many map levels each world has, in order
/// (levels are numbered 1, 2, 3… world after world).
class MapGeometry {
  MapGeometry(this.width, {List<int> levelsPerWorld = const [6, 6, 6, 6, 6, 6]})
    : contentWidth = math.min(width, 520),
      offsetX = (width - math.min(width, 520)) / 2,
      levelsPerWorld = List.unmodifiable(levelsPerWorld) {
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

  static const double block = 1200;
  static const double levelSpacing = 172;
  static const double top = 190;
  static const double bottom = 180;
  static const _xs = [.40, .57, .63, .49, .35, .45];

  final List<double> _blockStart = []; // from the bottom
  late final double _blocksHeight;
  final List<(int, int)> _place = []; // level n-1 -> (world, index in world)

  /// Height of a world's block with [levels] levels.
  static double blockOf(int levels) => math.max(block, 156 + (levels - 1) * levelSpacing + 12 + 172);

  int get worlds => levelsPerWorld.length;

  /// Number of the first level of world [w].
  int firstLevel(int w) => levelsPerWorld.take(w).fold(0, (a, b) => a + b) + 1;

  int get levels => _place.length;

  /// The full extent of the scrollable landscape.
  double get height => top + _blocksHeight + bottom;

  /// Bottom edge of world [w]'s block.
  double worldBottom(int w) => height - bottom - _blockStart[w];

  /// Centre of level [n] (1..levels).
  Offset node(int n) {
    final (w, li) = _place[n - 1];
    final x = offsetX + contentWidth * (w.isOdd ? 1 - _xs[li % 6] : _xs[li % 6]);
    final last = li == levelsPerWorld[w] - 1; // the boss: 12 px higher
    final y = worldBottom(w) - 156 - li * levelSpacing - (last ? 12 : 0);
    return Offset(x, y);
  }

  /// Vertical extent of world [w]'s background section.
  (double top, double height) section(int w) {
    final yb = worldBottom(w);
    final t = w == worlds - 1 ? 0.0 : yb - blockOf(levelsPerWorld[w]);
    return (t, yb - t + (w == 0 ? bottom : 0));
  }

  // Owned by the geometry, so course edits at the same width cannot reuse
  // a stale route. No static cache retaining whole courses.
  late final Path _path = _makePath();

  Path path() => _path;

  Path _makePath() {
    final p = Path();
    if (levels == 0) return p;
    final a = node(1);
    p.moveTo(a.dx, a.dy + 150);
    p.lineTo(a.dx, a.dy);
    for (var n = 2; n <= levels; n++) {
      final q = node(n), pq = node(n - 1);
      final bend = (pq.dy - q.dy) * .5;
      p.cubicTo(pq.dx, pq.dy - bend, q.dx, q.dy + bend, q.dx, q.dy);
    }
    final last = node(levels);
    p.lineTo(last.dx, last.dy - 130);
    return p;
  }

  /// Centre of the trail near [y], for keeping planting off the paving.
  double trailXAt(double y) {
    if (levels == 0) return width / 2;
    if (y >= node(1).dy) return node(1).dx;
    for (var n = 2; n <= levels; n++) {
      final upper = node(n), lower = node(n - 1);
      if (y < upper.dy) continue;
      final fraction = (lower.dy - y) / (lower.dy - upper.dy);
      var lo = 0.0, hi = 1.0;
      for (var k = 0; k < 10; k++) {
        final t = (lo + hi) / 2;
        final curveY = 1.5 * t - 1.5 * t * t + t * t * t;
        if (curveY < fraction) {
          lo = t;
        } else {
          hi = t;
        }
      }
      final t = (lo + hi) / 2;
      return lower.dx + (upper.dx - lower.dx) * (3 * t * t - 2 * t * t * t);
    }
    return node(levels).dx;
  }

  /// The world under a point in the scrollable canvas.
  int worldAt(double y) {
    for (var w = 0; w < worlds - 1; w++) {
      if (y >= section(w).$1) return w;
    }
    return math.max(0, worlds - 1);
  }

  /// Scroll offset (from the top) that puts level [n] at 55 % of the view.
  double scrollFor(int n, double viewport, {double? focusY}) =>
      levels == 0 ? 0 : (node(n.clamp(1, levels)).dy - (focusY ?? viewport * .55)).clamp(0.0, math.max(0.0, height - viewport));
}
