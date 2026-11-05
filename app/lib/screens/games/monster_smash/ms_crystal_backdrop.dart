import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'ms_camera.dart';
import 'ms_scene.dart';

/// The level map's Crystal Sky continues into the arena. Decorative layers
/// move in parallax; the floor follows the exact physics ground/camera.
class MsCrystalBackdropPainter extends CustomPainter {
  MsCrystalBackdropPainter({required this.view, required this.camera, required this.time, this.scroll = 0});
  final MsView view;
  final MsCamera camera;
  final double time, scroll;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, g = view.groundY;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFB7A6EF));
    final sky = MsSprites.of(MsArt.crystalSky);
    canvas.save();
    camera.transformLayer(canvas, .12);
    if (sky != null) {
      final width = math.max(w, h * sky.width / sky.height);
      final x = -(scroll * .12) % (width * 2);
      for (var k = -2; k <= 2; k++) {
        final left = x + k * width;
        canvas.save();
        if (k.isOdd) {
          canvas.translate(left * 2 + width, 0);
          canvas.scale(-1, 1);
        }
        paintImage(canvas: canvas, rect: Rect.fromLTWH(left - .5, 0, width + 1, h), image: sky, fit: BoxFit.cover, filterQuality: FilterQuality.high);
        canvas.restore();
      }
    }
    canvas.restore();
    // Airy haze separates the letter towers from the distant islands.
    canvas.drawRect(Offset.zero & size, Paint()..shader = ui.Gradient.linear(Offset(0, h * .2), Offset(0, g), const [Color(0x00FFFFFF), Color(0x40F9F2FF)]));
    for (var k = 0; k < 16; k++) {
      final x = (k * 173.0 + time * (3 + k % 3)) % (w + 40) - 20;
      final y = h * (.19 + (k % 6) * .095) + math.sin(time * .8 + k) * 7;
      final a = .12 + .28 * math.pow(math.sin(time * .65 + k), 2);
      canvas.drawCircle(Offset(x, y), k.isEven ? 1.7 : 1.1, Paint()..color = const Color(0xFFFFF7D4).withValues(alpha: a));
    }
    canvas.save();
    camera.transformLayer(canvas, 1);
    // A wide floating platform. Its upper surface is exactly y=0 in physics.
    final rect = Rect.fromLTRB(-w, g, w * 2, h * 1.5);
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(Offset(0, g), Offset(0, h * 1.1), const [Color(0xFFAB97DE), Color(0xFF7D6BC0), Color(0xFF605899)], const [0, .45, 1]),
    );
    canvas.drawRect(Rect.fromLTRB(-w, g, w * 2, g + 13), Paint()..shader = ui.Gradient.linear(Offset(0, g), Offset(0, g + 13), const [Color(0xFFFFF6DD), Color(0xFFE3C796)]));
    canvas.drawLine(
      Offset(-w, g + 14),
      Offset(w * 2, g + 14),
      Paint()
        ..color = const Color(0xFF8770B1)
        ..strokeWidth = 3,
    );
    final step = view.ppm * 1.25;
    for (var k = -2; k < w / step + 3; k++) {
      final x = k * step - scroll % step;
      final bottom = g + view.ppm * (1.25 + .28 * math.sin(k * 2.1));
      canvas.drawPath(
        Path()
          ..moveTo(x, g + 16)
          ..lineTo(x + step, g + 16)
          ..lineTo(x + step * .55, bottom)
          ..close(),
        Paint()..color = k.isEven ? const Color(0x337AE4E1) : const Color(0x33F9D8FF),
      );
      canvas.drawLine(
        Offset(x, g + 1),
        Offset(x, g + 11),
        Paint()
          ..color = const Color(0x40A8886A)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MsCrystalBackdropPainter oldDelegate) => true;
}
