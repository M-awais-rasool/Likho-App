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
        decoKinds = List.unmodifiable(decoKinds ?? [for (var w = 0; w < levelsPerWorld.length; w++) w % LikhoWorlds.all.length]) {
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

  /// Theme per world (index into [LikhoWorlds.all]): picks the world's
  /// decorations, so a new world looks like the world whose theme it borrows.
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

  /// Number of the first level of world [w].
  int firstLevel(int w) => levelsPerWorld.take(w).fold(0, (a, b) => a + b) + 1;

  /// Where the path crosses the bottom edge of world [w] (its cloud bank):
  /// halfway between the last level below and the world's first level.
  double crossingX(int w) {
    final first = firstLevel(w);
    if (first > levels) return width / 2;
    return w == 0 || first == 1 ? node(first).dx : (node(first - 1).dx + node(first).dx) / 2;
  }
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
  /// generator, three kinds per world (see [kindsFor]).
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
      final kinds = kindsFor(LikhoWorlds.all[decoKinds[i] % LikhoWorlds.all.length]);
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

  /// The three small animated decorations of a world, by its scenery.
  static List<DecoKind> kindsFor(WorldTheme t) {
    const white = MapColors.cloudWhite;
    final soft = t.soft, pop = t.pop, accent = t.accent;
    return switch (t.scene) {
      WorldScene.meadow => [
          DecoKind(78, 48, DecoMotif.bush, soft, accent, DecoAnim.sway, 6),
          DecoKind(22, 22, DecoMotif.flower, pop, white, DecoAnim.sway, 4),
          DecoKind(96, 34, DecoMotif.cloud, white, white, DecoAnim.drift, 8),
        ],
      WorldScene.castle => [
          DecoKind(34, 44, DecoMotif.pennant, accent, pop, DecoAnim.sway, 3),
          DecoKind(18, 18, DecoMotif.sparkle, pop, white, DecoAnim.twinkle, 3),
          DecoKind(96, 34, DecoMotif.cloud, white, white, DecoAnim.drift, 9),
        ],
      WorldScene.cove => [
          DecoKind(22, 22, DecoMotif.bubble, white, white, DecoAnim.waveBob, 4),
          DecoKind(30, 26, DecoMotif.shell, pop, white, DecoAnim.sway, 5),
          DecoKind(84, 16, DecoMotif.wave, white, white, DecoAnim.waveBob, 4),
        ],
      WorldScene.frost => [
          DecoKind(20, 20, DecoMotif.snowflake, white, white, DecoAnim.fall, 7),
          DecoKind(46, 62, DecoMotif.pine, const Color(0xFF2E6B7E), white, DecoAnim.none, 0),
          DecoKind(10, 10, DecoMotif.sparkle, pop, white, DecoAnim.twinkle, 3),
        ],
      WorldScene.forest => [
          DecoKind(62, 76, DecoMotif.tree, accent, const Color(0xFF9A6A44), DecoAnim.sway, 7),
          DecoKind(34, 32, DecoMotif.mushroom, pop, white, DecoAnim.none, 0),
          DecoKind(20, 14, DecoMotif.leaf, accent, pop, DecoAnim.fall, 6),
        ],
      WorldScene.town => [
          DecoKind(52, 56, DecoMotif.house, soft, accent, DecoAnim.none, 0),
          DecoKind(40, 54, DecoMotif.tree, const Color(0xFF7CC46A), const Color(0xFF9A6A44), DecoAnim.sway, 6),
          DecoKind(96, 34, DecoMotif.cloud, white, white, DecoAnim.drift, 8),
        ],
      WorldScene.mountain => [
          DecoKind(42, 58, DecoMotif.pine, const Color(0xFF6E8F7A), white, DecoAnim.sway, 8),
          DecoKind(56, 34, DecoMotif.rock, soft, accent, DecoAnim.none, 0),
          DecoKind(96, 34, DecoMotif.cloud, white, white, DecoAnim.drift, 9),
        ],
      WorldScene.beach => [
          DecoKind(30, 30, DecoMotif.beachBall, const Color(0xFFFF6B6B), pop, DecoAnim.sway, 5),
          DecoKind(30, 30, DecoMotif.starfish, const Color(0xFFFF8A5B), white, DecoAnim.sway, 6),
          DecoKind(84, 16, DecoMotif.wave, white, white, DecoAnim.waveBob, 4),
        ],
      WorldScene.garden => [
          DecoKind(26, 26, DecoMotif.flower, accent, const Color(0xFFFFE07A), DecoAnim.sway, 4),
          DecoKind(28, 22, DecoMotif.butterfly, pop, accent, DecoAnim.flap, 1.2),
          DecoKind(76, 46, DecoMotif.bush, pop, accent, DecoAnim.sway, 6),
        ],
      WorldScene.sky => [
          DecoKind(110, 40, DecoMotif.cloud, white, white, DecoAnim.drift, 9),
          DecoKind(30, 40, DecoMotif.kite, const Color(0xFFFF8A5B), pop, DecoAnim.sway, 4),
          DecoKind(26, 12, DecoMotif.bird, accent, white, DecoAnim.drift, 6),
        ],
      WorldScene.jungle => [
          DecoKind(84, 62, DecoMotif.fern, const Color(0xFF4E9A2E), accent, DecoAnim.sway, 6),
          DecoKind(24, 24, DecoMotif.flower, pop, const Color(0xFFFFE07A), DecoAnim.sway, 4),
          DecoKind(28, 22, DecoMotif.butterfly, const Color(0xFF3BA7E8), pop, DecoAnim.flap, 1),
        ],
      WorldScene.island => [
          DecoKind(56, 72, DecoMotif.palm, const Color(0xFF3FAE5A), const Color(0xFFB0794A), DecoAnim.sway, 7),
          DecoKind(30, 30, DecoMotif.starfish, accent, white, DecoAnim.sway, 6),
          DecoKind(84, 16, DecoMotif.wave, white, white, DecoAnim.waveBob, 4),
        ],
      WorldScene.river => [
          DecoKind(42, 26, DecoMotif.lilyPad, const Color(0xFF5CBF7A), const Color(0xFFFF9EC4), DecoAnim.sway, 6),
          DecoKind(26, 54, DecoMotif.reed, const Color(0xFF5E9E4A), const Color(0xFF9A6A44), DecoAnim.sway, 5),
          DecoKind(84, 16, DecoMotif.wave, white, white, DecoAnim.waveBob, 4),
        ],
      WorldScene.space => [
          DecoKind(12, 12, DecoMotif.sparkle, pop, white, DecoAnim.twinkle, 3),
          DecoKind(50, 50, DecoMotif.planet, accent, pop, DecoAnim.drift, 10),
          DecoKind(9, 9, DecoMotif.sparkle, white, white, DecoAnim.twinkle, 4),
        ],
    };
  }
}

enum DecoAnim { none, sway, drift, waveBob, twinkle, fall, flap }

/// What a decoration looks like (painted by paintMotif in map_painters.dart).
enum DecoMotif {
  bush, flower, cloud, pennant, sparkle, bubble, shell, wave, snowflake, pine, tree, mushroom, leaf, house, rock, //
  beachBall, starfish, butterfly, kite, bird, fern, palm, lilyPad, reed, planet,
}

class DecoKind {
  const DecoKind(this.w, this.h, this.motif, this.color, this.color2, this.anim, this.seconds);
  final double w, h;
  final DecoMotif motif;
  final Color color, color2;
  final DecoAnim anim;
  final double seconds; // animation length
}

class MapDeco {
  const MapDeco({required this.world, required this.kind, required this.rect, required this.phase});
  final int world;
  final DecoKind kind;
  final Rect rect;
  final double phase; // seconds already elapsed at t = 0 (negative CSS delay)
}
