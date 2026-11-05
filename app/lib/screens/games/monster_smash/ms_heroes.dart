import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../game/monster_smash/ms_engine.dart';
import 'ms_crystal_art.dart';
import 'ms_scene.dart';

/// The hero's pose this frame in the Crystal Sky atlas.
enum MsFace {
  /// Waiting: a calm smile.
  idle,

  /// In the slingshot: eyebrows down, looking at the towers.
  ready,

  /// Pulled back hard: the same determined look.
  effort,

  /// Flying: stretched out, yelling.
  yell,

  /// Using the power: Rubby squashed for the boing, Inky wobbling, Crayo
  /// dashing like an arrow.
  power,

  /// After a crash: dizzy eyes, tongue out, rolling.
  bonked,

  /// A letter found, the room cleared: laughing.
  happy,
}

/// How a hero looks this frame (on top of where it is).
@immutable
class MsHeroLook {
  const MsHeroLook({this.face = MsFace.idle, this.squash = 0, this.along = 0, this.turn = 0, this.hop = 0, this.scale = 1, this.opacity = 1});

  final MsFace face;

  /// Stretched (> 0) or squashed (< 0) along [along] (radians, screen).
  final double squash, along;

  /// The picture's turn (radians, screen).
  final double turn;

  /// Up, in hero radii (a hop), and size (popping in), fading out.
  final double hop, scale, opacity;
}

/// Renders the Stationery Squad with one body scale per character and a
/// measured pivot for each pose. Transparent atlas padding never affects size.
abstract final class MsHeroArt {
  static int _pose(MsFace f) => switch (f) {
    MsFace.idle => 0,
    MsFace.ready || MsFace.effort => 1,
    MsFace.yell => 2,
    MsFace.power => 3,
    MsFace.bonked => 4,
    MsFace.happy => 5,
  };

  /// Flight art already points right; only the round heroes bank slightly up.
  static double tilt(MsHero h, MsFace f) => h == MsHero.crayo ? 0 : -.18;

  static double foot(MsHero h, [MsFace f = MsFace.idle]) {
    final pose = _pose(f);
    return (MsCrystalArt.heroBounds(h, pose).bottom - MsCrystalArt.pivot(h, pose).dy) / MsCrystalArt.sourceRadius(h);
  }

  static void paint(Canvas c, MsHero h, Offset at, double radius, MsHeroLook look) {
    if (look.opacity <= 0 || look.scale <= 0) return;
    final image = MsSprites.of(MsArt.heroAtlas(h.name));
    if (image == null) return;
    final pose = _pose(look.face);
    final src = MsCrystalArt.heroBounds(h, pose);
    final pivot = MsCrystalArt.pivot(h, pose);
    final scale = radius * look.scale / MsCrystalArt.sourceRadius(h);
    c.save();
    c.translate(at.dx, at.dy - look.hop * radius);
    // Gentle deformation retains the silhouette and expression at small sizes.
    final s = 1 + look.squash.clamp(-.28, .3);
    c.rotate(look.along);
    c.scale(s, 1 / s);
    c.rotate(look.turn - look.along);
    _draw(c, image, src, Rect.fromLTWH((src.left - pivot.dx) * scale, (src.top - pivot.dy) * scale, src.width * scale, src.height * scale), look.opacity);
    c.restore();
  }

  static void _draw(Canvas c, ui.Image image, Rect src, Rect dst, double opacity) => c.drawImageRect(
    image,
    src,
    dst,
    Paint()
      ..filterQuality = FilterQuality.high
      ..color = Color.fromRGBO(255, 255, 255, opacity),
  );

  static void portrait(Canvas c, MsHero h, Size size, {double t = 0, MsFace face = MsFace.idle, bool bottom = false}) {
    final image = MsSprites.of(MsArt.heroAtlas(h.name));
    if (image == null) return;
    final src = MsCrystalArt.heroBounds(h, _pose(face));
    final scale = math.min(size.width / src.width, size.height / src.height) * .92;
    final breath = math.sin(t * 2.6 + h.index * 1.9) * .012;
    final w = src.width * scale * (1 + breath), height = src.height * scale * (1 - breath);
    final y = bottom ? size.height - height : (size.height - height) / 2;
    _draw(c, image, src, Rect.fromLTWH((size.width - w) / 2, y, w, height), 1);
  }
}
