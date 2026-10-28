import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../game/monster_smash/ms_engine.dart';
import 'ms_hero_frames.dart';
import 'ms_scene.dart';

/// The hero's pose this frame (a picture of the Gemini sheet each).
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

/// Draws the Stationery Squad from their pose pictures (cut by
/// tools/games/cut_smash_heroes.py): the ball the physics moves is the
/// picture's middle, its radius the hero's size in the picture.
abstract final class MsHeroArt {
  static String _pose(MsFace f) => switch (f) {
    MsFace.idle => 'idle',
    MsFace.ready || MsFace.effort => 'aim',
    MsFace.yell => 'fly',
    MsFace.power => 'power',
    MsFace.bonked => 'bonked',
    MsFace.happy => 'happy',
  };

  static MsHeroFrame _frame(MsHero h, MsFace f) => msHeroFrames['${h.name}_${_pose(f)}']!;

  /// Which way pose [f]'s picture of [h] points (radians, screen): a flying
  /// hero turns by its flight's angle less this.
  static double tilt(MsHero h, MsFace f) => _frame(h, f).tilt;

  /// How far below its middle [h] stands, in its radii.
  static double foot(MsHero h, [MsFace f = MsFace.idle]) => _frame(h, f).foot;

  /// Hero [h] centred at [at] (screen), [radius] screen pixels.
  static void paint(Canvas c, MsHero h, Offset at, double radius, MsHeroLook look) {
    if (look.opacity <= 0 || look.scale <= 0) return;
    final img = MsSprites.of(MsArt.hero(h.name, _pose(look.face)));
    if (img == null) return;
    final f = _frame(h, look.face);
    final r = radius * look.scale;
    c.save();
    c.translate(at.dx, at.dy - look.hop * radius);
    // squash and stretch along a direction
    final s = 1 + look.squash.clamp(-.45, .6);
    c.rotate(look.along);
    c.scale(s, 1 / s);
    c.rotate(look.turn - look.along);
    _draw(c, img, Rect.fromLTWH(-f.middle.dx * r, -f.middle.dy * r, f.size.width * r, f.size.height * r), look.opacity);
    c.restore();
  }

  static void _draw(Canvas c, ui.Image img, Rect to, double opacity) {
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      to,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }

  /// A hero card's picture: [h] standing in a [size] box, a little breath;
  /// [bottom]: the feet on the box's bottom edge (else the picture is in
  /// the middle).
  static void portrait(Canvas c, MsHero h, Size size, {double t = 0, MsFace face = MsFace.idle, bool bottom = false}) {
    final img = MsSprites.of(MsArt.hero(h.name, _pose(face)));
    if (img == null) return;
    final f = _frame(h, face);
    final r = math.min(size.width / f.size.width, size.height / f.size.height) * .8;
    final breath = math.sin(t * 2.6 + h.index * 1.9) * .025;
    final w = f.size.width * r * (1 + breath), ht = f.size.height * r * (1 - breath);
    final foot = bottom ? size.height * .98 : size.height / 2 + f.size.height * r / 2;
    _draw(c, img, Rect.fromLTWH(size.width / 2 - w / 2, foot - ht, w, ht), 1);
  }
}
