import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../design/tokens.dart';
import 'map_geometry.dart';

/// Art direction stays local to the map; lesson screens keep their colours.
class JourneyPalette {
  const JourneyPalette(this.ground, this.leaf, this.light, this.water);
  final Color ground, leaf, light, water;

  factory JourneyPalette.of(WorldTheme t) => switch (t.scene) {
    WorldScene.meadow => const JourneyPalette(Color(0xFFCCDEA8), Color(0xFF4C845C), Color(0xFF9BC66D), Color(0xFF68B9B7)),
    WorldScene.jungle => const JourneyPalette(Color(0xFFBCD598), Color(0xFF34775A), Color(0xFF86B756), Color(0xFF55A59D)),
    WorldScene.forest => const JourneyPalette(Color(0xFFE7C69C), Color(0xFFBE663D), Color(0xFFF5BB57), Color(0xFF6DA9A1)),
    WorldScene.garden => const JourneyPalette(Color(0xFFE8D7C2), Color(0xFFB66D8C), Color(0xFFF2B4BE), Color(0xFF86BDB5)),
    WorldScene.castle => const JourneyPalette(Color(0xFFD8CBE5), Color(0xFF8666A8), Color(0xFFC2A6DD), Color(0xFF8CADD0)),
    WorldScene.town => const JourneyPalette(Color(0xFFD0D9CF), Color(0xFF518C78), Color(0xFFA9C17B), Color(0xFF7DAEC5)),
    WorldScene.mountain => const JourneyPalette(Color(0xFFCCC9DF), Color(0xFF777D9E), Color(0xFFB3B0D0), Color(0xFF8BAAC5)),
    WorldScene.beach || WorldScene.island => const JourneyPalette(Color(0xFFF1D8AB), Color(0xFF4B997B), Color(0xFFA6CE7C), Color(0xFF5CBDBE)),
    WorldScene.cove || WorldScene.river => const JourneyPalette(Color(0xFFBEDCD1), Color(0xFF458C79), Color(0xFF9ECBA2), Color(0xFF61ADB6)),
    WorldScene.sky => const JourneyPalette(Color(0xFFD3E5EB), Color(0xFF80ABBC), Color(0xFFC5DFDC), Color(0xFF83BBD4)),
    WorldScene.frost => const JourneyPalette(Color(0xFF344E70), Color(0xFF446D83), Color(0xFFB2D5DD), Color(0xFF6BA6BD)),
    WorldScene.space => const JourneyPalette(Color(0xFF30354F), Color(0xFF645A92), Color(0xFFB0A0DB), Color(0xFF727DAF)),
  };
}

/// Adjacent sections share exactly the same colour at their boundary.
/// The environment transforms across 400 logical pixels, without a cut.
class JourneyGroundPainter extends CustomPainter {
  JourneyGroundPainter({required this.theme, this.above, this.below});
  final WorldTheme theme;
  final WorldTheme? above, below;

  @override
  void paint(Canvas c, Size s) {
    final base = JourneyPalette.of(theme).ground;
    final upper = above == null ? base : Color.lerp(base, JourneyPalette.of(above!).ground, .5)!;
    final lower = below == null ? base : Color.lerp(base, JourneyPalette.of(below!).ground, .5)!;
    final fade = math.min(200 / s.height, .45);
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [upper, base, base, lower],
          stops: [0, fade, 1 - fade, 1],
        ).createShader(Offset.zero & s),
    );
    // Consistent directional light; no horizontal seam at section edges.
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0x22FFFADE), const Color(0x00FFFADE), const Color(0x183D4F48)],
          stops: const [0, .52, 1],
        ).createShader(Offset.zero & s),
    );
  }

  @override
  bool shouldRepaint(JourneyGroundPainter old) => theme != old.theme || above != old.above || below != old.below;
}

/// Static, seeded landscape in its own repaint boundary. Vegetation is
/// arranged outside the trail corridor; foreground details have contact
/// shadows, extruded planters and a consistent light from the upper left.
class JourneySceneryPainter extends CustomPainter {
  JourneySceneryPainter({required this.theme, required this.geometry, required this.world, required this.sectionTop});
  final WorldTheme theme;
  final MapGeometry geometry;
  final int world;
  final double sectionTop;

  final Paint _paint = Paint()..isAntiAlias = true;
  Color _mix(Color a, Color b, double n) => Color.lerp(a, b, n)!;
  void _oval(Canvas c, Rect r, Color color) => c.drawOval(
    r,
    _paint
      ..shader = null
      ..color = color,
  );
  void _line(Canvas c, Offset a, Offset b, Color color, double width) => c.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  void _round(Canvas c, Rect r, double radius, Color color) => c.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(radius)),
    _paint
      ..shader = null
      ..color = color,
  );

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.clipRect(Offset.zero & s);
    final p = JourneyPalette.of(theme);
    final rng = math.Random(1741 + world * 97);
    final w = s.width;
    // Pebbles, grass and little flower clusters break up the ground plane.
    for (var i = 0; i < s.height / 4; i++) {
      final x = rng.nextDouble() * w, y = 90 + rng.nextDouble() * (s.height - 180);
      if ((x - geometry.trailXAt(y + sectionTop)).abs() < 51) continue;
      final edge = math.min(1.0, math.min(y, s.height - y) / 180);
      final col = (i % 4 == 0 ? p.light : p.leaf).withValues(alpha: .20 * edge);
      if (i % 3 == 0) {
        _line(c, Offset(x - 2, y), Offset(x - 3, y - 4), col, 1.3);
        _line(c, Offset(x, y), Offset(x + 1, y - 5), col, 1.3);
      } else {
        _oval(c, Rect.fromCenter(center: Offset(x, y), width: 2 + rng.nextDouble() * 3, height: 2), col);
      }
    }

    final first = geometry.firstLevel(world);
    final count = geometry.levelsPerWorld[world];
    for (var i = count - 1; i >= 0; i--) {
      final n = geometry.node(first + i) - Offset(0, sectionTop);
      // The larger landmark occupies the wider side of each bend.
      final left = n.dx > w * .5;
      final side = left ? 1.0 : -1.0;
      final x = left ? geometry.offsetX + 26 : w - geometry.offsetX - 26;
      final farX = left ? w - geometry.offsetX - 16 : geometry.offsetX + 16;
      final y = n.dy + 14;
      final room = left ? n.dx - x : x - n.dx;
      final scale = (room / 175).clamp(.68, 1.06);
      c.save();
      c.translate(x, y);
      c.scale(scale);
      // Broad planting bed with a warm stone retaining edge.
      _oval(c, const Rect.fromLTWH(-93, -45, 190, 106), const Color(0x1C30482E));
      _oval(c, const Rect.fromLTWH(-94, -52, 182, 96), _mix(p.ground, const Color(0xFF887656), .28));
      _oval(c, const Rect.fromLTWH(-94, -59, 182, 96), _mix(p.ground, const Color(0xFFFFF1CD), .42));
      _oval(c, const Rect.fromLTWH(-88, -58, 170, 86), _mix(p.ground, p.leaf, .28));

      if (i % 5 == 1 && theme.scene != WorldScene.space) {
        _pond(c, side * 8, -10, p);
        _bush(c, -side * 49, -30, .65, p);
        _flowers(c, side * 52, 22, p, rng);
      } else if (i % 5 == 3 && (theme.scene == WorldScene.town || theme.scene == WorldScene.castle || theme.scene == WorldScene.meadow)) {
        _house(c, 0, -10, p, theme.scene == WorldScene.castle);
        _bush(c, side * 46, 9, .7, p);
      } else if (theme.scene == WorldScene.space) {
        _planet(c, 0, -36, p, i);
        _crystals(c, side * 49, 4, p);
      } else {
        _bush(c, -side * 44, -22, .85, p);
        _tree(c, 0, 0, 1.0, p, i);
        _bush(c, side * 43, 18, .72, p);
        _flowers(c, side * 27, 30, p, rng);
      }
      c.restore();
      // Smaller plants on the narrow bank frame the route without hiding it.
      _bush(c, farX, y - 52, .68, p);
      _tree(c, farX + (left ? 18 : -18), y + 35, .65, p, i + 1);
      if (i.isEven && w >= 350) {
        _lamp(c, n.dx + (left ? -1 : 1) * 69, y + 57, p);
      }
      // A few flat stepping stones and flowers near the path shoulder.
      for (var k = 0; k < 3; k++) {
        final dx = n.dx + (left ? -1 : 1) * (57 + k * 9);
        _oval(c, Rect.fromCenter(center: Offset(dx, y + 43 + k * 6), width: 10, height: 5), _mix(p.ground, const Color(0xFFFFF4D8), .55));
      }
    }
    c.restore();
  }

  void _bush(Canvas c, double x, double y, double scale, JourneyPalette p) {
    c.save();
    c.translate(x, y);
    c.scale(scale);
    _oval(c, const Rect.fromLTWH(-38, -5, 80, 25), const Color(0x2332442A));
    for (var i = 0; i < 5; i++) {
      final dx = (i - 2) * 14.0, dy = i.isEven ? -12.0 : -20.0;
      final r = Rect.fromCircle(center: Offset(dx, dy), radius: 20);
      c.drawOval(r, Paint()..shader = RadialGradient(center: const Alignment(-.5, -.6), colors: [p.light, p.leaf]).createShader(r));
      _oval(c, Rect.fromLTWH(dx - 8, dy - 10, 9, 4), const Color(0x337BE398));
      _oval(c, Rect.fromLTWH(dx + 4, dy - 3, 5, 3), const Color(0x40FFF2B8));
    }
    c.restore();
  }

  void _tree(Canvas c, double x, double y, double scale, JourneyPalette p, int seed) {
    c.save();
    c.translate(x, y);
    c.scale(scale);
    _oval(c, const Rect.fromLTWH(-35, -7, 98, 30), const Color(0x2432442A));
    _oval(c, const Rect.fromLTWH(-18, -4, 46, 12), const Color(0x2632442A));
    final trunk = Path()
      ..moveTo(-8, 2)
      ..quadraticBezierTo(-3, -31, -7, -66)
      ..lineTo(9, -66)
      ..quadraticBezierTo(3, -25, 13, 3)
      ..close();
    c.drawPath(
      trunk,
      Paint()..shader = const LinearGradient(colors: [Color(0xFFB18B62), Color(0xFF725D4D)]).createShader(const Rect.fromLTWH(-8, -66, 21, 69)),
    );
    _line(c, const Offset(0, -23), const Offset(-23, -53), const Color(0xFF80674E), 6);
    _line(c, const Offset(5, -31), const Offset(24, -61), const Color(0xFF80674E), 5);
    if (theme.scene == WorldScene.frost || theme.scene == WorldScene.mountain) {
      for (var i = 0; i < 3; i++) {
        final y = -36.0 - i * 23, span = 45.0 - i * 9;
        final bough = Path()
          ..moveTo(-span, y)
          ..quadraticBezierTo(-span * .4, y - 31, 0, y - 56)
          ..quadraticBezierTo(span * .4, y - 30, span, y)
          ..quadraticBezierTo(0, y + 13, -span, y)
          ..close();
        c.drawPath(
          bough,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.light, p.leaf],
            ).createShader(Rect.fromLTRB(-span, y - 56, span, y + 13)),
        );
      }
    } else if (theme.scene == WorldScene.beach || theme.scene == WorldScene.island) {
      for (var i = 0; i < 6; i++) {
        c.save();
        c.translate(0, -77);
        c.rotate(i * math.pi / 3);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(25, -31, 60, 6)
          ..quadraticBezierTo(28, -5, 0, 0);
        c.drawPath(leaf, Paint()..shader = LinearGradient(colors: [p.light, p.leaf]).createShader(const Rect.fromLTWH(0, -25, 60, 35)));
        c.restore();
      }
    } else {
      final rng = math.Random(seed + world * 81);
      const lobes = [(-28.0, -62.0, 28.0), (28.0, -65.0, 30.0), (0.0, -56.0, 34.0), (-20.0, -86.0, 29.0), (20.0, -90.0, 30.0), (0.0, -106.0, 28.0)];
      for (final (dx, dy, radius) in lobes) {
        final r = Rect.fromCircle(center: Offset(dx, dy), radius: radius);
        c.drawCircle(Offset(dx + 2, dy + 3), radius, Paint()..color = _mix(p.leaf, const Color(0xFF304D46), .18));
        c.drawOval(
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.45, -.55),
              colors: [_mix(p.light, const Color(0xFFFFE5A3), .12), p.leaf],
              radius: .9,
            ).createShader(r),
        );
        for (var k = 0; k < 9; k++) {
          final a = rng.nextDouble() * math.pi * 2, d = rng.nextDouble() * radius * .75;
          _oval(
            c,
            Rect.fromCenter(center: Offset(dx + math.cos(a) * d, dy + math.sin(a) * d), width: 5 + rng.nextDouble() * 5, height: 3.5),
            p.light.withValues(alpha: .50),
          );
        }
      }
    }
    c.restore();
  }

  void _flowers(Canvas c, double x, double y, JourneyPalette p, math.Random rng) {
    for (var i = 0; i < 7; i++) {
      final dx = x + rng.nextDouble() * 27 - 14, dy = y + rng.nextDouble() * 15 - 8;
      _line(c, Offset(dx, dy + 4), Offset(dx, dy - 3), p.leaf, 1.3);
      for (var k = 0; k < 5; k++) {
        final a = k * math.pi * 2 / 5;
        c.drawCircle(
          Offset(dx + math.cos(a) * 2.5, dy - 3 + math.sin(a) * 2.5),
          2.2,
          Paint()..color = i.isEven ? const Color(0xFFFFF6DD) : const Color(0xFFFFD277),
        );
      }
      c.drawCircle(Offset(dx, dy - 3), 1.6, Paint()..color = const Color(0xFFD6A342));
    }
  }

  void _pond(Canvas c, double x, double y, JourneyPalette p) {
    c.save();
    c.translate(x, y);
    const r = Rect.fromLTWH(-68, -43, 136, 81);
    _oval(c, r.shift(const Offset(0, 5)), const Color(0xFF9B9573));
    _oval(c, r, const Color(0xFFEFE2BC));
    final water = r.deflate(7);
    c.drawOval(
      water,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_mix(p.water, const Color(0xFF234D68), .22), p.water],
        ).createShader(water),
    );
    for (var i = 0; i < 4; i++) {
      _oval(c, Rect.fromLTWH(-36 + i * 18, -19 + (i % 2) * 25, 18, 3), const Color(0x40EFFFEF));
    }
    for (final pos in [const Offset(-34, 8), const Offset(33, -5), const Offset(22, 20)]) {
      c.drawArc(Rect.fromCenter(center: pos, width: 19, height: 10), .2, math.pi * 1.8, true, Paint()..color = p.light);
    }
    // Tiny duck and its reflection.
    _oval(c, const Rect.fromLTWH(-12, 3, 27, 7), const Color(0x2589E3D5));
    _oval(c, const Rect.fromLTWH(-10, -4, 21, 12), const Color(0xFFFFF4D7));
    c.drawCircle(const Offset(6, -6), 5, Paint()..color = const Color(0xFFFFF8E9));
    _line(c, const Offset(10, -6), const Offset(14, -5), const Color(0xFFEEB352), 3);
    c.drawCircle(const Offset(7, -7), .8, Paint()..color = const Color(0xFF3D4B46));
    c.restore();
  }

  void _house(Canvas c, double x, double y, JourneyPalette p, bool castle) {
    c.save();
    c.translate(x, y);
    _oval(c, const Rect.fromLTWH(-46, 7, 108, 27), const Color(0x2434422D));
    _round(c, const Rect.fromLTWH(-38, -61, 75, 79), 4, const Color(0xFFF6E3BF));
    _round(c, const Rect.fromLTWH(22, -61, 18, 79), 3, const Color(0xFFCFB594));
    final roof = Path()
      ..moveTo(-47, -57)
      ..lineTo(-5, -99)
      ..lineTo(47, -57)
      ..close();
    c.drawPath(roof, Paint()..color = castle ? p.leaf : const Color(0xFFAD715D));
    _line(c, const Offset(-47, -57), const Offset(-5, -99), const Color(0xFFF3C792), 3);
    _round(c, const Rect.fromLTWH(-10, -17, 18, 35), 8, const Color(0xFF977453));
    for (final dx in [-25.0, 16.0]) {
      _round(c, Rect.fromLTWH(dx, -47, 14, 19), 4, const Color(0xFF638F95));
      _line(c, Offset(dx + 7, -45), Offset(dx + 7, -30), const Color(0xFFFFEAC0), 2);
      _line(c, Offset(dx + 2, -38), Offset(dx + 12, -38), const Color(0xFFFFEAC0), 2);
    }
    if (castle) {
      _line(c, const Offset(-5, -97), const Offset(-5, -122), const Color(0xFF806A59), 2);
      c.drawPath(
        Path()
          ..moveTo(-4, -122)
          ..lineTo(17, -116)
          ..lineTo(-4, -108)
          ..close(),
        Paint()..color = const Color(0xFFFFD576),
      );
    }
    c.restore();
  }

  void _lamp(Canvas c, double x, double y, JourneyPalette p) {
    const metal = Color(0xFF506359);
    _oval(c, Rect.fromLTWH(x - 5, y - 2, 25, 9), const Color(0x23324531));
    _round(c, Rect.fromLTWH(x - 5, y - 5, 10, 7), 3, metal);
    _line(c, Offset(x, y - 5), Offset(x, y - 44), metal, 3);
    final halo = Rect.fromCircle(center: Offset(x, y - 50), radius: 23);
    c.drawOval(halo, Paint()..shader = const RadialGradient(colors: [Color(0x50FFE6A0), Color(0x00FFE6A0)]).createShader(halo));
    _round(c, Rect.fromLTWH(x - 7, y - 58, 14, 19), 4, metal);
    _round(c, Rect.fromLTWH(x - 4, y - 55, 8, 12), 2, const Color(0xFFFFE7AA));
    c.drawPath(
      Path()
        ..moveTo(x - 10, y - 58)
        ..lineTo(x, y - 66)
        ..lineTo(x + 10, y - 58)
        ..close(),
      Paint()..color = metal,
    );
    _line(c, Offset(x, y - 65), Offset(x, y - 69), metal, 2);
  }

  void _planet(Canvas c, double x, double y, JourneyPalette p, int seed) {
    final r = Rect.fromCircle(center: Offset(x, y), radius: 38);
    c.drawOval(r, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.5), colors: [p.light, p.leaf]).createShader(r));
    c.save();
    c.translate(x, y);
    c.rotate(-.35);
    c.drawOval(
      const Rect.fromLTWH(-58, -12, 116, 24),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xA1E5CDA8),
    );
    c.restore();
    _oval(c, Rect.fromLTWH(x - 21, y - 18, 14, 9), p.leaf.withValues(alpha: .3));
  }

  void _crystals(Canvas c, double x, double y, JourneyPalette p) {
    for (var i = 0; i < 3; i++) {
      final dx = x + i * 9, h = 17.0 + (i % 2) * 12;
      c.drawPath(
        Path()
          ..moveTo(dx, y)
          ..lineTo(dx - 4, y - h)
          ..lineTo(dx + 2, y - h - 7)
          ..lineTo(dx + 9, y - h)
          ..lineTo(dx + 7, y)
          ..close(),
        Paint()..color = i.isEven ? p.light : p.leaf,
      );
    }
  }

  @override
  bool shouldRepaint(JourneySceneryPainter old) => theme != old.theme || geometry != old.geometry || world != old.world || sectionTop != old.sectionTop;
}

/// A light animated layer, independent of the expensive static scenery.
/// Both halves of boundary mist use the same seed, position and clock.
class JourneyAtmospherePainter extends CustomPainter {
  JourneyAtmospherePainter({required this.theme, required this.world, required this.geometry, required this.sectionTop, required this.time})
    : super(repaint: time);
  final WorldTheme theme;
  final int world;
  final MapGeometry geometry;
  final double sectionTop;
  final ValueListenable<double> time;

  /// The haze over a world seam, as a unit circle the canvas places and
  /// stretches. Built once: a gradient shader per oval per frame was the
  /// map's biggest cost on a mid-range phone.
  static final Rect _unit = const Rect.fromLTWH(-.5, -.5, 1, 1);
  static final Paint _haze = Paint()..shader = const RadialGradient(colors: [Color(0x30F5F4DF), Color(0x00F5F4DF)]).createShader(_unit);

  /// A firefly's glow: rings instead of a gradient shader, for the same
  /// reason. Soft edges at this size, and nothing to build per frame.
  static const _ring = [(1.0, .26), (.66, .3), (.33, .36)];

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.clipRect(Offset.zero & s);
    final t = time.value;
    final rng = math.Random(81 + world * 17);
    final glow = Paint(), core = Paint(), wingL = Paint()..color = const Color(0xFFFFF4C9);
    final wingR = Paint()..color = theme.accent.withValues(alpha: .8);
    final body = Paint()
      ..color = const Color(0xFF7E7155)
      ..strokeWidth = 1;
    final radius = theme.dark ? 6.0 : 4.0;
    for (var i = 0; i < s.height / 90; i++) {
      final x = rng.nextDouble() * s.width;
      final y = 100 + rng.nextDouble() * (s.height - 200);
      final phase = rng.nextDouble() * math.pi * 2;
      final pos = Offset(x + math.sin(t * .28 + phase) * 10, y + math.cos(t * .35 + phase) * 7);
      final alpha = .2 + .25 * (.5 + .5 * math.sin(t * .8 + phase));
      if (i % 4 == 0 && !theme.dark) {
        c.save();
        c.translate(pos.dx, pos.dy);
        final wing = 2.5 + 2 * math.sin(t * 4 + phase).abs();
        c.drawOval(Rect.fromCenter(center: Offset(-wing / 2, 0), width: wing, height: 6), wingL);
        c.drawOval(Rect.fromCenter(center: Offset(wing / 2, 0), width: wing, height: 6), wingR);
        c.drawLine(const Offset(0, -2), const Offset(0, 2), body);
        c.restore();
      } else {
        for (final (scale, weight) in _ring) {
          c.drawCircle(pos, radius * scale, glow..color = const Color(0xFFFFF5D4).withValues(alpha: alpha * weight));
        }
        c.drawCircle(pos, 1.1, core..color = const Color(0xFFFFF7D5).withValues(alpha: alpha + .15));
      }
    }
    for (final boundary in [world, world + 1]) {
      if (boundary == 0 || boundary >= geometry.worlds) continue;
      final y = geometry.worldBottom(boundary) - sectionTop;
      for (var i = 0; i < 4; i++) {
        final dx = s.width * i / 3 + math.sin(t * .12 + i + boundary) * 18;
        final dy = y + math.sin(i * 2.1 + boundary) * 28;
        c.save();
        c.translate(dx, dy);
        c.scale(s.width * .85, 170);
        c.drawOval(_unit, _haze);
        c.restore();
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(JourneyAtmospherePainter old) =>
      theme != old.theme || geometry != old.geometry || world != old.world || sectionTop != old.sectionTop || time != old.time;
}
