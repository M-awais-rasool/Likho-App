import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens.dart';
import 'ms_camera.dart';
import 'ms_layer_lines.dart';
import 'ms_scene.dart';

/// Monster Smash's meadow, in layers: the painted sky (its clouds drift),
/// the sun, far hills with a windmill whose sails turn, near hills with
/// trees, the grass the game stands on, butterflies, birds now and then,
/// and big grass in front. The painted layers are Gemini's
/// (`design/games/monster-smash/layers/`); they do not join at their ends,
/// so every other picture is drawn mirrored. Each layer has a depth (0 the
/// sky, 1 the ground): with the camera ([MsCamera.transformLayer]) and the
/// walk between rooms ([scroll], base pixels) the far ones move less, which
/// gives the scene its depth. Until the pictures are ready, plain colours.
class MsBackdropPainter extends CustomPainter {
  MsBackdropPainter({required this.view, required this.camera, required this.time, this.scroll = 0});
  final MsView view;
  final MsCamera camera;
  final double time, scroll;

  @override
  void paint(Canvas canvas, Size size) {
    final w = view.screen.width, h = view.screen.height, g = view.groundY;
    final sky = MsSprites.of(MsArt.meadowSky);
    final far = MsSprites.of(MsArt.meadowFar);
    final near = MsSprites.of(MsArt.meadowNear);
    final ground = MsSprites.of(MsArt.meadowGround);

    // the sky does not move; its clouds drift
    if (sky == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, g), const [MeadowColors.skyTop, MeadowColors.skyLow, MeadowColors.haze], const [0, .7, 1]),
      );
    } else {
      _strip(canvas, sky, msMeadowSky, top: 0, height: h, shift: time * 6, w: w);
    }
    _layer(canvas, .03, () => _sun(canvas, Offset(w * .83, h * .17), h * .075));
    _layer(canvas, .12, () => _birds(canvas, w, h));

    // far hills: their tops a quarter of the screen over the ground
    if (far != null) {
      _layer(canvas, .25, () {
        final height = h * .42, top = g - h * .24 - msMeadowFar.line * height;
        _strip(
          canvas,
          far,
          msMeadowFar,
          top: top,
          height: height,
          shift: scroll * .25,
          w: w,
          over: (x, width) => _windmill(canvas, Offset(x + msMeadowMill.dx * width, top + msMeadowMill.dy * height), msMeadowMillSize * height),
        );
      });
    }
    // near hills, their tops just over the ground
    if (near != null) {
      _layer(canvas, .5, () {
        final height = h * .42;
        _strip(canvas, near, msMeadowNear, top: g - h * .12 - msMeadowNear.line * height, height: height, shift: scroll * .5, w: w);
      });
    }
    _layer(canvas, .9, () => _butterflies(canvas, w, g));
    // the grass the game stands on, its top a little over the ground line
    // (things stand in the grass, not on its edge)
    _layer(canvas, 1, () {
      if (ground == null) {
        canvas.drawRect(Rect.fromLTRB(-w, g - h * .015, w * 2, g + h * .06), Paint()..color = MeadowColors.grass);
        canvas.drawRect(Rect.fromLTRB(-w, g + h * .06, w * 2, h * 2), Paint()..color = MeadowColors.earth);
      } else {
        final height = h * .4;
        _strip(canvas, ground, msMeadowGround, top: g - h * .015 - msMeadowGround.line * height, height: height, shift: scroll, w: w);
      }
    });
    _layer(canvas, 1.12, () {
      _repeat(canvas, w * 1.4, scroll * 1.12, w, () {
        for (final t in _front(w, h)) {
          _tuft(canvas, t, MeadowColors.grassLine);
        }
      });
    });
  }

  // ------------------------------------------------------------ helpers

  void _layer(Canvas canvas, double depth, void Function() draw) {
    canvas.save();
    camera.transformLayer(canvas, depth);
    draw();
    canvas.restore();
  }

  static double _wrap(double x, double w) => ((x % w) + w) % w;

  /// Draws a layer [wrap] wide shifted left by [shift], as often as the
  /// screen ([w]) needs.
  static void _repeat(Canvas canvas, double wrap, double shift, double w, void Function() draw) {
    var x = -_wrap(shift, wrap);
    while (x < w * 1.2) {
      canvas.save();
      canvas.translate(x, 0);
      draw();
      canvas.restore();
      x += wrap;
    }
  }

  static final _picture = Paint()..filterQuality = FilterQuality.medium;

  /// Picture [image] across the screen ([w]), [height] tall from [top],
  /// shifted left by [shift]: every other one mirrored, so the ends always
  /// meet. [over] draws on each one (its left and width, as if unmirrored).
  static void _strip(
    Canvas canvas,
    ui.Image image,
    MsLayerLine layer, {
    required double top,
    required double height,
    required double shift,
    required double w,
    void Function(double x, double width)? over,
  }) {
    final width = height * layer.aspect;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    var x = -_wrap(shift, width * 2);
    for (var k = 0; x < w * 1.2; k++, x += width) {
      if (x + width < -w * .2) continue;
      final mirrored = k.isOdd;
      canvas.save();
      if (mirrored) {
        canvas.translate(x * 2 + width, 0);
        canvas.scale(-1, 1);
      }
      // a hair wider: no hairline between two
      canvas.drawImageRect(image, src, Rect.fromLTWH(x - .3, top, width + .6, height), _picture);
      over?.call(x, width);
      canvas.restore();
    }
  }

  static Paint _line(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  void _sun(Canvas canvas, Offset at, double r) {
    canvas.drawCircle(at, r * 2.6, Paint()..shader = ui.Gradient.radial(at, r * 2.6, const [MeadowColors.sunGlow, Color(0x00FFF3C4)]));
    final rays = Paint()..color = MeadowColors.sunGlow;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(time * .08);
    for (var k = 0; k < 12; k++) {
      final a = k * math.pi / 6;
      final p = Path()
        ..moveTo(math.cos(a - .09) * r * 1.25, math.sin(a - .09) * r * 1.25)
        ..lineTo(math.cos(a) * r * (1.9 + .15 * math.sin(time * 2 + k)), math.sin(a) * r * (1.9 + .15 * math.sin(time * 2 + k)))
        ..lineTo(math.cos(a + .09) * r * 1.25, math.sin(a + .09) * r * 1.25)
        ..close();
      canvas.drawPath(p, rays);
    }
    canvas.restore();
    canvas.drawCircle(at, r, Paint()..color = MeadowColors.sun);
    canvas.drawCircle(at + Offset(-r * .3, -r * .3), r * .35, Paint()..color = const Color(0x66FFFFFF));
  }

  /// The far hills' windmill, its foot at [at], [size] up to its roof top,
  /// as it is in the picture: a cream tower, a red roof, slim brown lattice
  /// sails (the roof shows between them) that turn.
  void _windmill(Canvas canvas, Offset at, double size) {
    final s = size;
    final line = _line(MeadowColors.millLine, math.max(.7, s * .03));
    final tower = Path()
      ..moveTo(at.dx - s * .24, at.dy)
      ..lineTo(at.dx - s * .18, at.dy - s * .6)
      ..lineTo(at.dx + s * .18, at.dy - s * .6)
      ..lineTo(at.dx + s * .24, at.dy)
      ..close();
    canvas.drawPath(tower, Paint()..color = MeadowColors.mill);
    canvas.drawPath(tower, line);
    final door = RRect.fromLTRBAndCorners(
      at.dx - s * .065,
      at.dy - s * .16,
      at.dx + s * .065,
      at.dy,
      topLeft: Radius.circular(s * .065),
      topRight: Radius.circular(s * .065),
    );
    canvas.drawRRect(door, Paint()..color = MeadowColors.millWood);
    final roof = Path()
      ..moveTo(at.dx - s * .3, at.dy - s * .56)
      ..lineTo(at.dx, at.dy - s)
      ..lineTo(at.dx + s * .3, at.dy - s * .56)
      ..close();
    canvas.drawPath(roof, Paint()..color = MeadowColors.millRoof);
    canvas.drawPath(roof, line);
    final hub = at - Offset(0, s * .7);
    canvas.save();
    canvas.translate(hub.dx, hub.dy);
    canvas.rotate(math.pi / 4 + time * .9);
    final wood = Paint()
      ..color = MeadowColors.millWood
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .035
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      // the arm, and a lattice sail on one side of it
      canvas.drawLine(Offset.zero, Offset(s * .5, 0), wood);
      final sail = Rect.fromLTRB(s * .14, -s * .11, s * .5, -s * .01);
      canvas.drawRect(sail, Paint()..color = MeadowColors.millSail);
      canvas.drawRect(sail, wood);
      for (var i = 1; i < 3; i++) {
        final x = sail.left + sail.width * i / 3;
        canvas.drawLine(Offset(x, sail.top), Offset(x, sail.bottom), wood);
      }
      canvas.rotate(math.pi / 2);
    }
    canvas.restore();
    canvas.drawCircle(hub, s * .05, Paint()..color = MeadowColors.millLine);
  }

  void _tuft(Canvas canvas, _Tuft t, Color color) {
    final sway = math.sin(time * 2.1 + t.seed) * .18;
    final paint = Paint()..color = color;
    for (var k = 0; k < t.blades; k++) {
      final a = -math.pi / 2 + (k - (t.blades - 1) / 2) * .32 + sway;
      final len = t.size * (.75 + .25 * math.cos(k * 1.7 + t.seed));
      final tip = t.at + Offset(math.cos(a) * len, math.sin(a) * len);
      final side = Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) * t.size * .13;
      final p = Path()
        ..moveTo(t.at.dx - side.dx, t.at.dy - side.dy)
        ..quadraticBezierTo((t.at.dx + tip.dx) / 2 - side.dx * .6, (t.at.dy + tip.dy) / 2, tip.dx, tip.dy)
        ..quadraticBezierTo((t.at.dx + tip.dx) / 2 + side.dx * .6, (t.at.dy + tip.dy) / 2, t.at.dx + side.dx, t.at.dy + side.dy)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  /// Big grass in front, below the ground line (the same every frame).
  static List<_Tuft> _front(double w, double h) {
    final r = math.Random(7), wrap = w * 1.4;
    return [
      for (var k = 0; k < 5; k++)
        _Tuft(Offset(wrap * (k + r.nextDouble() * .5) / 5, h + 6), h * (.07 + r.nextDouble() * .05), 4 + r.nextInt(3), r.nextDouble() * 6),
    ];
  }

  void _butterflies(Canvas canvas, double w, double g) {
    for (var k = 0; k < 3; k++) {
      final t = time * (.35 + k * .07) + k * 2.1;
      final x = _wrap(w * (.25 + k * .3) + t * 40, w * 1.3) - w * .1;
      final y = g - view.screen.height * (.18 + .06 * k) + math.sin(t * 2.3) * 18 + math.sin(t * 5.1) * 6;
      final flap = math.sin(time * 16 + k).abs();
      final c = MeadowColors.butterflies[k % MeadowColors.butterflies.length];
      final s = view.screen.height * .018;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(t * 2.3) * .3);
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.scale(side * (.25 + .75 * flap), 1);
        canvas.drawOval(Rect.fromLTWH(0, -s, s * 1.3, s * 1.1), Paint()..color = c);
        canvas.drawOval(Rect.fromLTWH(0, 0, s, s * .9), Paint()..color = c.withValues(alpha: .85));
        canvas.restore();
      }
      canvas.drawLine(Offset(0, -s * .9), Offset(0, s * .8), _line(MeadowColors.bird, s * .28));
      canvas.restore();
    }
  }

  void _birds(Canvas canvas, double w, double h) {
    // a pair crossing far away every 16 s
    final t = time % 16;
    if (t > 9) return;
    final x = -40 + t / 9 * (w + 80);
    final y = h * .2 + math.sin(t * .8) * 10;
    final flap = math.sin(time * 9) * 5;
    final paint = _line(MeadowColors.bird, 2);
    for (final (dx, dy) in [(0.0, 0.0), (-28.0, 10.0)]) {
      final o = Offset(x + dx, y + dy);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - 9, o.dy - flap)
          ..quadraticBezierTo(o.dx - 4, o.dy - 4, o.dx, o.dy)
          ..quadraticBezierTo(o.dx + 4, o.dy - 4, o.dx + 9, o.dy - flap),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MsBackdropPainter old) => true;
}

class _Tuft {
  _Tuft(this.at, this.size, this.blades, this.seed);
  final Offset at;
  final double size, seed;
  final int blades;
}
