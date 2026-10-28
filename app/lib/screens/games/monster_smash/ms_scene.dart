import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

import '../../../game/monster_smash/ms_engine.dart';
import '../monster_defense/md_art_boxes.dart';
import 'ms_art_boxes.dart';

/// Monster Smash's pictures (`assets/games/smash/`, cut from the Gemini art
/// by tools/games/cut_smash_art.py; the monsters are Monster Defense's) and
/// where the world is on the screen.
abstract final class MsArt {
  static const dir = 'assets/games/smash';
  static const cover = '$dir/cover.webp';
  static String pic(String name) => '$dir/$name.webp';
  static String pencil(String pose) => '$dir/pencil_$pose.webp';

  /// A hero's pose picture (cut by tools/games/cut_smash_heroes.py).
  static String hero(String name, String pose) => '$dir/hero_${name}_$pose.webp';
  static const heroes = ['rubby', 'inky', 'crayo'];
  static const heroPoses = ['idle', 'aim', 'fly', 'power', 'bonked', 'happy'];

  static const poses = ['stand', 'ready', 'pull', 'throw', 'cheer', 'oops', 'point'];
  static const monsterPoses = ['idle', 'surprised', 'roar', 'bonked', 'friendly'];

  static String monster(String kind, String pose) => 'assets/games/monsters/${kind}_$pose.webp';

  /// A block's picture (triangles are wood or ice, discs stone).
  static String block(MsShape s, MsMaterial m) => switch (s) {
    MsShape.disc => pic('stone_disc'),
    MsShape.triangle => pic('${m == MsMaterial.ice ? 'ice' : 'wood'}_triangle'),
    _ => pic('${m.name}_${s.name}'),
  };

  static const sling = '$dir/sling.webp', hill = '$dir/hill.webp';

  /// Letter Land's background layers (cut by tools/games/cut_smash_layers.py).
  static const meadowSky = '$dir/meadow_sky.webp', meadowFar = '$dir/meadow_far.webp';
  static const meadowNear = '$dir/meadow_near.webp', meadowGround = '$dir/meadow_ground.webp';
  static const star = 'assets/games/monsters/star.webp';

  /// Where Pencil is in pose picture [asset], and where he stands in it
  /// (fractions).
  static Rect pencilBox(String asset) => msArtBoxes[_name(asset)] ?? const Rect.fromLTRB(0, 0, 1, 1);
  static Offset pencilFeet(String asset) => msPencilFeet[_name(asset)] ?? const Offset(.5, 1);

  /// Where a monster is in its pose picture (the idle picture is filled).
  static Rect monsterBox(String asset) => mdArtBoxes[_name(asset)] ?? const Rect.fromLTRB(0, 0, 1, 1);

  static String _name(String asset) => asset.split('/').last.replaceAll('.webp', '');

  /// What the world paints (Pencil is not in the game, only his voice).
  static List<String> get all => {
    for (final k in ['gloop', 'fuzz', 'bonk', 'boo'])
      for (final p in monsterPoses) monster(k, p),
    for (final s in MsShape.values)
      for (final m in MsMaterial.values) block(s, m),
    for (final h in heroes)
      for (final p in heroPoses) hero(h, p),
    sling,
    hill,
    star,
    meadowSky,
    meadowFar,
    meadowNear,
    meadowGround,
  }.toList();
}

/// A background: where its ground is (a fraction of the picture's height,
/// measured from the pictures).
class MsBackground {
  const MsBackground(this.asset, {required this.ground});
  final String asset;
  final double ground;

  static const meadow = MsBackground('assets/games/smash/bg_meadow.webp', ground: .853);
  static const beach = MsBackground('assets/games/smash/bg_beach.webp', ground: .80);
  static const snow = MsBackground('assets/games/smash/bg_snow.webp', ground: .846);
  static const all = [meadow, beach, snow];

  static const size = Size(1920, 1072);
}

/// The world on the screen: 16 m across the screen's width, the ground on
/// the background's ground line. The picture covers the screen, its bottom
/// showing (a wide phone loses sky).
class MsView {
  MsView(this.screen, this.bg) {
    final sc = math.max(screen.width / MsBackground.size.width, screen.height / MsBackground.size.height);
    imageSize = MsBackground.size * sc;
    origin = Offset((screen.width - imageSize.width) / 2, screen.height - imageSize.height);
    groundY = origin.dy + imageSize.height * bg.ground;
    ppm = screen.width / MsGame.width;
  }

  final Size screen;
  final MsBackground bg;
  late final Size imageSize;
  late final Offset origin;

  /// The ground's height on the screen, and pixels (dp) per metre.
  late final double groundY, ppm;

  Offset at(double x, double y) => Offset(x * ppm, groundY - y * ppm);
  Offset of(Vector2 v) => at(v.x, v.y);

  /// The world point under a finger at [p].
  Vector2 world(Offset p) => Vector2(p.dx / ppm, (groundY - p.dy) / ppm);
}

/// Pictures decoded once, for painting (a picture not ready yet is skipped
/// for that frame).
class MsSprites {
  static final Map<String, ui.Image> _images = {};
  static final Set<String> _loading = {};

  static ui.Image? of(String asset) => _images[asset];

  static void load([ImageConfiguration config = ImageConfiguration.empty]) {
    for (final a in MsArt.all) {
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
