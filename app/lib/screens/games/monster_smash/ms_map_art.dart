import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// Art used only by the level map; the game keeps its own scenery.
abstract final class SmashMapArt {
  static const sky = 'assets/games/smash/map_crystal_sky.webp';
  static const guide = 'assets/games/smash/map_rubby_aviator.webp';
}

/// A continuous raised ribbon, with small floating crystal islands at
/// each stop. Everything shares the buttons' coordinates at every size.
class SmashMapPathPainter extends CustomPainter {
  const SmashMapPathPainter(this.spots, {required this.reached});

  final List<Offset> spots;
  final int reached;

  Path _leg(int i) {
    final a = spots[i], b = spots[i + 1];
    final bend = (b.dx - a.dx) * .52;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + bend, a.dy, b.dx - bend, b.dy, b.dx, b.dy);
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width;

  @override
  void paint(Canvas canvas, Size size) {
    final route = Path();
    for (var i = 0; i < spots.length - 1; i++) {
      route.addPath(_leg(i), Offset.zero);
    }
    canvas.drawPath(route.shift(const Offset(0, 7)), _stroke(SmashMapColors.shadow, 26));
    canvas.drawPath(route, _stroke(SmashMapColors.lilacEdge, 24));
    canvas.drawPath(route.shift(const Offset(0, -2)), _stroke(SmashMapColors.cream, 20));
    canvas.drawPath(route, _stroke(SmashMapColors.lilac, 12));
    for (var i = 0; i < spots.length - 1; i++) {
      final leg = _leg(i);
      if (i < reached) {
        canvas.drawPath(leg, _stroke(SmashMapColors.goldEdge, 24));
        canvas.drawPath(leg.shift(const Offset(0, -2)), _stroke(SmashMapColors.goldLight, 20));
        canvas.drawPath(leg, _stroke(SmashMapColors.gold, 12));
      }
      final metric = leg.computeMetrics().first;
      for (var d = 58.0; d < metric.length - 48; d += 20) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length - 48)), _stroke(SmashMapColors.cream, 3));
      }
    }
    for (var i = 0; i < spots.length; i++) {
      _island(canvas, spots[i], current: i == reached);
    }
  }

  void _island(Canvas c, Offset p, {required bool current}) {
    c.save();
    c.translate(p.dx, p.dy + 30);
    final paint = Paint();
    c.drawOval(Rect.fromCenter(center: const Offset(0, 44), width: 102, height: 14), paint..color = SmashMapColors.shadow.withValues(alpha: .09));
    final rock = Path()
      ..moveTo(-61, 0)
      ..lineTo(-45, 30)
      ..lineTo(-15, 34)
      ..lineTo(7, 44)
      ..lineTo(31, 32)
      ..lineTo(54, 22)
      ..lineTo(62, 0)
      ..close();
    c.drawPath(rock, paint..color = SmashMapColors.islandLeft);
    c.drawPath(
      Path()
        ..moveTo(-12, 4)
        ..lineTo(7, 44)
        ..lineTo(31, 32)
        ..lineTo(54, 22)
        ..lineTo(62, 0)
        ..close(),
      paint..color = SmashMapColors.islandRight,
    );
    c.drawPath(
      Path()
        ..moveTo(-45, 30)
        ..lineTo(-12, 4)
        ..lineTo(-15, 34)
        ..lineTo(7, 44)
        ..close(),
      paint..color = SmashMapColors.islandDark,
    );
    c.drawOval(const Rect.fromLTWH(-63, -17, 126, 35), paint..color = SmashMapColors.lilacEdge);
    c.drawOval(const Rect.fromLTWH(-63, -21, 126, 34), paint..color = current ? SmashMapColors.goldLight : SmashMapColors.islandTop);
    _crystal(c, const Offset(-47, -8), 20);
    _crystal(c, const Offset(-55, -3), 12);
    _crystal(c, const Offset(48, -5), 15);
    c.restore();
  }

  void _crystal(Canvas c, Offset p, double h) {
    final shape = Path()
      ..moveTo(p.dx, p.dy - h)
      ..lineTo(p.dx + h * .25, p.dy - h * .65)
      ..lineTo(p.dx + h * .22, p.dy)
      ..lineTo(p.dx - h * .22, p.dy)
      ..lineTo(p.dx - h * .3, p.dy - h * .6)
      ..close();
    c.drawPath(shape, Paint()..color = SmashMapColors.teal);
    c.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - h)
        ..lineTo(p.dx + h * .25, p.dy - h * .65)
        ..lineTo(p.dx + h * .22, p.dy)
        ..lineTo(p.dx, p.dy - 2)
        ..close(),
      Paint()..color = SmashMapColors.mint,
    );
  }

  @override
  bool shouldRepaint(covariant SmashMapPathPainter old) => !listEquals(old.spots, spots) || old.reached != reached;
}

/// Small, slow glints repaint independently of the map's widgets.
class SmashMapGlints extends CustomPainter {
  SmashMapGlints(this.time) : super(repaint: time);
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 16; i++) {
      final x = ((i * .173 + .07) % 1) * size.width;
      final y = (.22 + ((i * .137) % .55)) * size.height;
      final shimmer = (math.sin(time.value * 1.5 + i * 2.3) + 1) / 2;
      final r = 1.5 + shimmer * 2.5;
      final star = Path()
        ..moveTo(x, y - r * 1.8)
        ..quadraticBezierTo(x + .5, y - .5, x + r, y)
        ..quadraticBezierTo(x + .5, y + .5, x, y + r * 1.8)
        ..quadraticBezierTo(x - .5, y + .5, x - r, y)
        ..quadraticBezierTo(x - .5, y - .5, x, y - r * 1.8);
      canvas.drawPath(star, Paint()..color = SmashMapColors.cream.withValues(alpha: .3 + shimmer * .5));
    }
  }

  @override
  bool shouldRepaint(covariant SmashMapGlints old) => old.time != time;
}
