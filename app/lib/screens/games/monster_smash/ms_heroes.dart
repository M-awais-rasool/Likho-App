import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../bosses/boss_kit.dart' show Cel, Face, Shade, rrect, strokePath, shine;
import '../../../bosses/boss_pose.dart';
import '../../../design/tokens.dart';
import '../../../game/monster_smash/ms_engine.dart';

/// The hero's face this frame.
enum MsFace {
  /// Waiting: smiles, blinks, looks around.
  idle,

  /// In the slingshot: a determined look at the towers.
  ready,

  /// Pulled back hard: squinting, teeth gritted.
  effort,

  /// Flying: big eyes, yelling.
  yell,

  /// Using the power: eyes wide, mouth open.
  power,

  /// A letter found, the room cleared: laughing.
  happy,
}

/// How a hero looks this frame (on top of where it is).
@immutable
class MsHeroLook {
  const MsHeroLook({
    this.face = MsFace.idle,
    this.squash = 0,
    this.along = 0,
    this.turn = 0,
    this.lid = 0,
    this.look = Offset.zero,
    this.hop = 0,
    this.scale = 1,
    this.opacity = 1,
  });

  final MsFace face;

  /// Stretched (> 0) or squashed (< 0) along [along] (radians, screen).
  final double squash, along;

  /// The body's turn (radians); the face stays upright.
  final double turn;

  /// Eyelid 0..1 (blinks), where the eyes look (-1..1).
  final double lid;
  final Offset look;

  /// Up, in hero radii (a hop), and size (popping in), fading out.
  final double hop, scale, opacity;
}

/// Draws the Stationery Squad in Pencil's style (flat colour, a light band
/// on the top left, a darker band on the bottom right, a darker outline of
/// the same hue). The art is drawn for a radius of 20 units; the face is
/// always upright, the body turns and squashes.
abstract final class MsHeroArt {
  static const _unit = 20.0;

  static Shade _shade(List<Color> c) => Shade(c[0], c[1], c[2], c[3]);

  // ---------------------------------------------------------------- bodies

  static final Cel _rubby = Cel(rrect(-23, -19, 23, 19, 10), _shade(HeroColors.rubby), line: 1.8);
  static final Cel _rubbySleeve = Cel(rrect(-24, -20.5, -6, 20.5, 6), _shade(HeroColors.rubbySleeve), line: 1.8);

  static final Cel _inky = Cel(
    Path()
      ..moveTo(0, -27)
      ..cubicTo(6, -16, 19, -6, 19, 6)
      ..arcToPoint(const Offset(-19, 6), radius: const Radius.circular(19))
      ..cubicTo(-19, -6, -6, -16, 0, -27)
      ..close(),
    _shade(HeroColors.inky),
    line: 1.8,
  );

  static final Cel _crayoBody = Cel(rrect(-25, -11.5, 12, 11.5, 4), _shade(HeroColors.crayo), line: 1.8);
  static final Cel _crayoTip = Cel(
    Path()
      ..moveTo(11, -10.5)
      ..quadraticBezierTo(22, -6, 28, -.5)
      ..quadraticBezierTo(29, 0, 28, .5)
      ..quadraticBezierTo(22, 6, 11, 10.5)
      ..close(),
    _shade(HeroColors.crayo),
    line: 1.8,
  );
  static final Cel _crayoWrap = Cel(
    Path()
      ..moveTo(-17, -12.5)
      ..lineTo(3, -12.5)
      ..lineTo(.5, -9)
      ..lineTo(3, -5)
      ..lineTo(.5, -1)
      ..lineTo(3, 3)
      ..lineTo(.5, 7)
      ..lineTo(3, 12.5)
      ..lineTo(-17, 12.5)
      ..close(),
    _shade(HeroColors.crayoWrap),
    line: 1.6,
  );

  static Face _face(MsHero h) => Face(
    lid: (h == MsHero.inky ? HeroColors.inky : (h == MsHero.crayo ? HeroColors.crayoWrap : HeroColors.rubby))[0],
    rim: HeroColors.rim,
    r: h == MsHero.crayo ? 5.3 : 5.6,
    brows: false,
  );

  /// Where the face sits (art units, before the body turns).
  static Offset _faceAt(MsHero h) => switch (h) {
    MsHero.rubby => const Offset(5, -1),
    MsHero.inky => const Offset(0, 6),
    MsHero.crayo => const Offset(-7, 0),
  };

  static double _gap(MsHero h) => switch (h) {
    MsHero.rubby => 15,
    MsHero.inky => 15,
    MsHero.crayo => 12.5,
  };

  // ---------------------------------------------------------------- drawing

  /// Hero [h] centred at [at] (screen), [radius] screen pixels.
  static void paint(Canvas c, MsHero h, Offset at, double radius, MsHeroLook look) {
    if (look.opacity <= 0 || look.scale <= 0) return;
    final k = radius / _unit * look.scale;
    c.save();
    c.translate(at.dx, at.dy - look.hop * radius);
    c.scale(k);
    if (look.opacity < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, look.opacity));
    // squash and stretch along a direction
    final s = 1 + look.squash.clamp(-.45, .6);
    c.save();
    c.rotate(look.along);
    c.scale(s, 1 / s);
    c.rotate(-look.along);
    c.save();
    c.rotate(look.turn);
    switch (h) {
      case MsHero.rubby:
        _rubby.paint(c);
        _rubbySleeve.paint(c);
        // the sleeve's white stripe and the rubbed-off corner
        c.drawRect(const Rect.fromLTRB(-24, -4, -6, 1), Paint()..color = const Color(0xCCFFFFFF));
        shine(c, 8, -12, 12, 5, alpha: .45);
      case MsHero.inky:
        _inky.paint(c);
        shine(c, -8, -2, 7, 11, alpha: .55);
        shine(c, -3, -14, 3, 5, alpha: .5);
      case MsHero.crayo:
        _crayoTip.paint(c);
        _crayoBody.paint(c);
        _crayoWrap.paint(c);
        final ink = Paint()
          ..color = HeroColors.crayo[3]
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke;
        c.drawLine(const Offset(-17, -8.5), const Offset(1, -8.5), ink);
        c.drawLine(const Offset(-17, 9), const Offset(1, 9), ink);
        shine(c, 17, -4, 6, 3, alpha: .5);
    }
    c.restore();
    // the face, upright, carried by the turn
    final f = _faceAt(h);
    final turned = Offset(f.dx * math.cos(look.turn) - f.dy * math.sin(look.turn), f.dx * math.sin(look.turn) + f.dy * math.cos(look.turn));
    final face = h == MsHero.crayo ? turned : f;
    _paintFace(c, h, face, look);
    c.restore();
    if (look.opacity < 1) c.restore();
    c.restore();
  }

  static void _paintFace(Canvas c, MsHero h, Offset at, MsHeroLook look) {
    final pose = BossPose(
      eyes: switch (look.face) {
        MsFace.happy => BossEyes.happy,
        MsFace.yell || MsFace.power => BossEyes.wow,
        _ => BossEyes.open,
      },
      lid: look.face == MsFace.effort ? math.max(.38, look.lid) : (look.face == MsFace.ready ? math.max(.18, look.lid) : look.lid),
      look: look.look,
      mouth: switch (look.face) {
        MsFace.idle => BossMouth.smile,
        MsFace.ready => BossMouth.smile,
        MsFace.effort => BossMouth.grin,
        MsFace.yell => BossMouth.laugh,
        MsFace.power => BossMouth.wow,
        MsFace.happy => BossMouth.laugh,
      },
      open: switch (look.face) {
        MsFace.yell => .9,
        MsFace.power => 1,
        MsFace.happy => .7,
        _ => 0,
      },
    );
    final face = _face(h);
    final gap = _gap(h);
    face.cheeks(c, at + Offset(-gap * .85, 5.5), at + Offset(gap * .85, 5.5));
    face.pair(c, pose, at, gap);
    face.mouth(c, pose, at + Offset(0, h == MsHero.crayo ? 6.5 : 8.5));
    // determined brows (ready, pulling): inner ends down; up when yelling
    final angry = switch (look.face) {
      MsFace.ready => .6,
      MsFace.effort => 1.0,
      MsFace.yell || MsFace.power => -.6,
      _ => 0.0,
    };
    if (angry != 0) {
      final r = face.r;
      for (final side in [-1.0, 1.0]) {
        final e = at + Offset(side * gap / 2, 0);
        final y = e.dy - 1.75 * r;
        strokePath(
          c,
          Path()
            ..moveTo(e.dx - side * .55 * r, y + angry * .45 * r)
            ..lineTo(e.dx + side * .65 * r, y - angry * .35 * r),
          HeroColors.rim,
          1.6,
        );
      }
    }
  }

  /// A hero card's picture: [h] in a [size] square, smiling.
  static void portrait(Canvas c, MsHero h, Size size, {double t = 0}) {
    final r = size.shortestSide * .3;
    final at = size.center(Offset.zero) + Offset(0, r * .08);
    paint(c, h, at, r, MsHeroLook(face: MsFace.idle, turn: h == MsHero.crayo ? -.5 : 0, lid: _blink(t, h.index * 1.3)));
  }

  /// A blink every few seconds (0 open .. 1 shut).
  static double _blink(double t, double seed) {
    final p = (t + seed) % 3.7;
    return p < .14 ? math.sin(p / .14 * math.pi) : 0;
  }

  static double blink(double t, double seed) => _blink(t, seed);

  /// A tiny drop (Inky split in three).
  static void drop(Canvas c, Offset at, double radius, MsHeroLook look) => paint(c, MsHero.inky, at, radius, look);
}
