import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../design/tokens.dart';
import '../../../game/spell_runner/sr_engine.dart';
import 'sr_v2_boxes.dart';

/// Spell Runner's Sunshine Valley art and shared road perspective.
/// Atlas coordinates are measured in sr_atlas.dart; source prompts and art
/// provenance live in design/games/spell-runner-sunshine-valley.md.
abstract final class SrArt {
  static const dir = 'assets/games/runner';
  static const cover = '$dir/valley_cover.png';
  static const hero = '$dir/pencil_hero.png';
  static const moves = '$dir/pencil_moves.png';
  static const props = '$dir/valley_props.png';
  static const valley = '$dir/valley_day.png';
  static String pic(String name) => '$dir/$name.webp';

  /// Stable pose names used by the animation controller and atlas renderer.
  static String rider(String pose) => '$dir/rider_$pose.webp';
  static const poses = ['push', 'ride', 'carve_left', 'carve_right', 'crouch', 'jump', 'slide', 'trick', 'stumble', 'land', 'cheer'];
  static const riderBox = Rect.fromLTRB(0, 0, 1, srRiderFoot);

  /// Gloop chasing him, from behind.
  static String gloop(String pose) => '$dir/gloop_$pose.webp';
  static const gloopPoses = ['hop', 'land', 'reach'];

  static const roadside = ['tree', 'pine', 'bush', 'flowers', 'sunflower', 'fence', 'mushrooms', 'signpost', 'apple_tree', 'lamp'];

  static String thing(SrKind k) => k == SrKind.letter || k == SrKind.coin
      ? star
      : (k == SrKind.heart
            ? heart
            : pic(switch (k) {
                SrKind.puddle => 'puddle',
                SrKind.log => 'log',
                SrKind.rock => 'rock',
                SrKind.hay => 'hay',
                SrKind.cone => 'cone',
                SrKind.banana => 'banana',
                SrKind.ramp => 'ramp',
                SrKind.bar => 'barrier',
                SrKind.banner => 'banner',
                SrKind.branch => 'branch',
                SrKind.cart => 'cart',
                SrKind.bench => 'bench',
                SrKind.flowerbox => 'flowerbox',
                _ => 'star',
              }));

  /// How high the open space under high thing [k] is in its picture.
  static double gap(SrKind k) => srGaps[thing(k).split('/').last.replaceAll('.webp', '')] ?? .5;

  /// The coins are the stars of Monster Defense's things.
  static const star = 'assets/games/monsters/star.webp';
  static const heart = 'assets/games/monsters/heart.webp';

  static List<String> get all => [
    hero, moves, props, valley, SrBackground.day.asset,
    for (final p in gloopPoses) gloop(p),
    for (final k in SrKind.values)
      if (!k.power) thing(k), // the power-ups are drawn
    for (final r in roadside) pic(r),
    star,
  ];
}

/// A part of the road (a new one every [SrGame.zoneMetres]): its name, the
/// things beside it (some more often than others) and its light.
class SrZone {
  const SrZone(this.name, this.roadside, this.tint);
  final String name;
  final List<String> roadside;
  final Color tint;

  static const all = [
    SrZone('Apple Orchard', ['apple_tree', 'apple_tree', 'tree', 'bush', 'flowers'], RunnerColors.clear),
    SrZone('Sunflower Fields', ['sunflower', 'sunflower', 'tree', 'flowers', 'flowers', 'bush'], RunnerColors.fields),
    SrZone('Pine Forest', ['pine', 'pine', 'pine', 'flowers', 'bush', 'tree'], RunnerColors.forest),
    SrZone('Sunset Lane', ['tree', 'apple_tree', 'pine', 'flowers', 'bush'], RunnerColors.sunset),
  ];

  /// The part of the road at [metres].
  static int at(double metres) => (metres ~/ SrGame.zoneMetres) % all.length;
}

/// A road background: where its road meets the horizon (fractions of the
/// picture) and half the road's width at the picture's bottom (a fraction of
/// its width), measured from the pictures.
class SrBackground {
  const SrBackground(this.asset, {required this.vanish, required this.halfBottom});
  final String asset;
  final Offset vanish;
  final double halfBottom;

  static const day = SrBackground('assets/games/runner/valley_track.png', vanish: Offset(.5, .412), halfBottom: .55);
  // The same perspective is used throughout a run; zone lighting supplies
  // the time-of-day changes without moving the road under the rider.
  static const sunset = day;

  static const size = Size(941, 1672);
}

/// The road on the screen: a straight road from the horizon to the bottom,
/// seen in perspective. A thing [z] ahead of Pencil is drawn at
/// `s = d / (d + z)` of its size, on the line between the horizon and
/// Pencil's line ([player]).
class SrRoad {
  SrRoad(this.screen, this.bg, {required double bottomInset}) {
    final sc = math.max(screen.width / SrBackground.size.width, screen.height / SrBackground.size.height);
    scale = sc;
    imageSize = SrBackground.size * sc;
    // centred across; the bottom shows (a wide screen loses sky, not road)
    origin = Offset((screen.width - imageSize.width) / 2, screen.height - imageSize.height);
    vanish = origin + Offset(bg.vanish.dx * imageSize.width, bg.vanish.dy * imageSize.height);
    final roadBottom = origin.dy + imageSize.height;
    _halfPerY = bg.halfBottom * imageSize.width / (roadBottom - vanish.dy);
    // Pencil rides a little above the bottom, where the road is narrow
    // enough for all three lanes to fit on the screen
    player = math.min(origin.dy + imageSize.height * .8, screen.height - bottomInset - 90);
  }

  final Size screen;
  final SrBackground bg;
  late final double scale;
  late final Size imageSize;
  late final Offset origin, vanish;
  late final double player;
  late final double _halfPerY;

  /// Pencil's height on [screen].
  static double pencilHeight(Size screen) => (screen.height * .21).clamp(140.0, 240.0);

  /// How deep the view is: things this far ahead are half size.
  static const d = 8.0;

  /// Size factor of a thing [z] ahead (1 on Pencil's line).
  double s(double z) => d / (d + math.max(z, -d * .85));

  /// Screen height of the road at [z] ahead.
  double y(double z) => vanish.dy + (player - vanish.dy) * s(z);

  /// Half the road's width at screen height [y].
  double half(double y) => (y - vanish.dy) * _halfPerY;

  /// The distance between two lanes' middles on Pencil's line.
  double get laneWidth => half(player) * 2 / 3;

  /// Where on the screen a point [z] ahead is, [lane] across (-1..1 the
  /// lanes' middles; ±1.5 the road's edges).
  Offset at(double z, double lane) {
    final yy = y(z);
    return Offset(vanish.dx + lane * half(yy) * 2 / 3, yy);
  }
}

/// Pictures decoded once, for painting (a picture not ready yet is skipped
/// for that frame).
class SrSprites {
  static final Map<String, ui.Image> _images = {};
  static final Set<String> _loading = {};

  static ui.Image? of(String asset) => _images[asset];

  static void load([ImageConfiguration config = ImageConfiguration.empty]) {
    for (final a in SrArt.all) {
      if (_images.containsKey(a) || !_loading.add(a)) continue;
      final stream = AssetImage(a).resolve(config);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          _images[a] = info.image.clone();
          info.dispose();
          _loading.remove(a);
          stream.removeListener(listener);
        },
        onError: (_, _) {
          _loading.remove(a);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    }
  }
}
