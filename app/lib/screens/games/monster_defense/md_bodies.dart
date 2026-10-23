import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../design/tokens.dart';
import '../../../game/monster_defense/md_engine.dart';
import 'md_effects.dart';
import 'md_scene.dart';

/// The monsters, painted bending like soft cartoon bodies: each pose picture
/// is laid on a small mesh that squashes and stretches from the feet, sways
/// at the top, lifts one foot then the other, ripples a ghost's hem and
/// leans into the way it walks ([MdMotion]). One picture moves smoothly, so
/// a walk never flickers between two drawings.

/// The pose pictures, decoded once for painting on the mesh.
abstract final class MdSprites {
  static final Map<String, ui.Image> _images = {};
  static final Set<String> _loading = {};

  static ui.Image? of(String asset) => _images[asset];

  static List<String> get assets => [
    for (final k in [MdKind.gloop, MdKind.fuzz, MdKind.bonk, MdKind.boo])
      for (final p in MdArt.poses) MdArt.pose(k, p),
  ];

  /// Starts decoding every pose (a monster whose picture is not ready yet
  /// is skipped for that frame).
  static void load([ImageConfiguration config = ImageConfiguration.empty]) {
    for (final a in assets) {
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

  static bool get ready => assets.every(_images.containsKey);
}

/// How a monster's body is bent this frame.
class MdMotion {
  MdMotion(this.pose);

  /// The pose picture.
  String pose;

  /// Moves the whole body (px): a hop, a float, a fall.
  double dx = 0, dy = 0;

  /// Squash (< 1) and stretch (> 1) from the feet; [sx] widens the middle.
  double sx = 1, sy = 1;

  /// The top leans this much of the height sideways (the feet stay).
  double sway = 0;

  /// Turns the body about its feet (radians).
  double rot = 0;

  /// How far the left and right foot are lifted (0..1).
  double stepL = 0, stepR = 0;

  /// A ghost's wavy hem (fraction of the height).
  double hem = 0;

  /// A quick pop when the pose changes.
  double punch = 1;

  bool frozen = false;

  /// A white flash when Pencil's magic hits (0..1).
  double flash = 0;
}

/// One monster to paint: its box (feet on the ground), how it bends, how
/// see-through it is.
typedef MdBody = ({MdMonster m, Rect rect, Offset feet, double alpha, MdMotion motion});

/// Paints every monster (far ones first): shadows, bent bodies, Big Bonk's
/// crown.
class MdBodiesPainter extends CustomPainter {
  MdBodiesPainter({required this.bodies, required this.time});
  final List<MdBody> bodies;
  final double time;

  static const _cols = 6, _rows = 9;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bodies) {
      _shadow(canvas, b);
    }
    for (final b in bodies) {
      final img = MdSprites.of(b.motion.pose);
      if (img == null || b.alpha <= 0) continue;
      _body(canvas, img, b);
      if (b.m.kind == MdKind.boss && b.m.mood != MdMood.friendly) _crown(canvas, b);
    }
  }

  void _shadow(Canvas canvas, MdBody b) {
    if (b.alpha <= 0) return;
    final mo = b.motion;
    final air = (b.feet.dy - (b.rect.bottom + mo.dy)) / b.rect.height; // how high it is off the ground
    final w = b.rect.width * .6 * (1 - (air * .6).clamp(0.0, .5)) * (mo.sx * .5 + .5);
    canvas.drawOval(
      Rect.fromCenter(center: b.feet + Offset(mo.dx, -b.rect.height * .01), width: w, height: w * .2),
      Paint()..color = MonsterColors.shadow.withValues(alpha: MonsterColors.shadow.a * b.alpha * (1 - (air * 1.2).clamp(0.0, .7))),
    );
  }

  /// Where a point of the picture lands, (u, v) from its top left (0..1).
  static Offset bend(Rect r, MdMotion mo, double u, double v, double time) {
    final h = r.height, cx = r.center.dx, bottom = r.bottom;
    var x = r.left + u * r.width, y = r.top + v * h;
    // squash and stretch from the feet; fatter in the middle when squashed
    y = bottom - (bottom - y) * mo.sy;
    x = cx + (x - cx) * (1 + (mo.sx - 1) * math.sin(math.pi * v));
    // the top sways, the feet stay
    x += mo.sway * h * math.pow(1 - v, 1.6);
    // a lifted foot: the bottom band on its side comes up
    if (v > .7) {
      final k = (v - .7) / .3;
      final left = ((.58 - u) / .38).clamp(0.0, 1.0), right = ((u - .42) / .38).clamp(0.0, 1.0);
      y -= h * .085 * k * (mo.stepL * left + mo.stepR * right);
    }
    // a ghost's hem waves
    if (mo.hem > 0 && v > .62) {
      final k = (v - .62) / .38;
      x += math.sin(u * 7 + time * 8) * mo.hem * h * k;
      y += math.cos(u * 9 + time * 10) * mo.hem * .5 * h * k;
    }
    // turn about the feet, pop, then move
    final px = cx, py = bottom;
    var ox = x - px, oy = y - py;
    if (mo.rot != 0) {
      final c = math.cos(mo.rot), s = math.sin(mo.rot);
      final rx = ox * c - oy * s, ry = ox * s + oy * c;
      ox = rx;
      oy = ry;
    }
    return Offset(px + ox * mo.punch + mo.dx, py + oy * mo.punch + mo.dy);
  }

  void _body(Canvas canvas, ui.Image img, MdBody b) {
    final mo = b.motion, r = MdArt.placed(mo.pose, b.rect);
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final pos = Float32List((_cols + 1) * (_rows + 1) * 2), tex = Float32List((_cols + 1) * (_rows + 1) * 2);
    var k = 0;
    for (var j = 0; j <= _rows; j++) {
      for (var i = 0; i <= _cols; i++) {
        final u = i / _cols, v = j / _rows;
        final p = bend(r, mo, u, v, time);
        pos[k] = p.dx;
        pos[k + 1] = p.dy;
        tex[k] = u * iw;
        tex[k + 1] = v * ih;
        k += 2;
      }
    }
    final idx = Uint16List(_cols * _rows * 6);
    k = 0;
    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        final a = j * (_cols + 1) + i, c = a + _cols + 1;
        idx.setAll(k, [a, a + 1, c, a + 1, c + 1, c]);
        k += 6;
      }
    }
    final paint = Paint()
      ..shader = ImageShader(img, TileMode.clamp, TileMode.clamp, Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]), filterQuality: FilterQuality.medium)
      ..filterQuality = FilterQuality.medium;
    if (mo.frozen) paint.colorFilter = const ColorFilter.mode(MonsterColors.ice, BlendMode.srcATop);
    if (mo.flash > 0) paint.colorFilter = ColorFilter.mode(MonsterColors.magicCore.withValues(alpha: .8 * mo.flash.clamp(0.0, 1.0)), BlendMode.srcATop);
    final layer = b.alpha < .99;
    if (layer) canvas.saveLayer(r.inflate(r.height), Paint()..color = Color.fromRGBO(0, 0, 0, b.alpha));
    canvas.drawVertices(ui.Vertices.raw(VertexMode.triangles, pos, textureCoordinates: tex, indices: idx), BlendMode.modulate, paint);
    if (layer) canvas.restore();
  }

  void _crown(Canvas canvas, MdBody b) {
    final mo = b.motion, r = MdArt.content(mo.pose, b.rect);
    final frame = MdArt.placed(mo.pose, b.rect);
    // the top of the head, bent with the body
    Offset at(double y) => bend(frame, mo, (r.center.dx - frame.left) / frame.width, (y - frame.top) / frame.height, time);
    final top = at(r.top + r.height * .08);
    final below = at(r.top + r.height * .35);
    final tilt = math.atan2(top.dx - below.dx, below.dy - top.dy);
    final w = r.width * .42 * mo.punch;
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(tilt - .12 + (b.m.mood == MdMood.cracked ? math.sin(b.m.moodTime * 13) * .2 : 0));
    canvas.translate(-w / 2, -w * .6);
    if (b.alpha < .99) canvas.saveLayer(Offset.zero & Size(w, w * .72), Paint()..color = Color.fromRGBO(0, 0, 0, b.alpha));
    const MdCrownPainter().paint(canvas, Size(w, w * .72));
    if (b.alpha < .99) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(MdBodiesPainter old) => true;
}
