import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'map_geometry.dart';

/// A warm stone trail, with a planted shoulder, a recessed edge and
/// subtle paving joints. Samples belong to this geometry, never its width.
class MapPathPainter extends CustomPainter {
  MapPathPainter({required this.geometry, required this.sectionTop});
  final MapGeometry geometry;
  final double sectionTop;
  static final Expando<List<(Offset, double)>> _samples = Expando();

  List<(Offset, double)> get _joints => _samples[geometry] ??= [
    for (final metric in geometry.path().computeMetrics())
      for (var d = 24.0; d < metric.length; d += 39)
        if (metric.getTangentForOffset(d) case final tangent?) (tangent.position, tangent.angle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = geometry.path();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -sectionTop);
    final brush = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void stroke(Color color, double width, [Offset shift = Offset.zero]) {
      canvas.drawPath(
        shift == Offset.zero ? path : path.shift(shift),
        brush
          ..color = color
          ..strokeWidth = width,
      );
    }

    stroke(const Color(0x183D6644), 102, const Offset(3, 6));
    stroke(const Color(0x387D9D5D), 94);
    stroke(const Color(0xFFB7AA83), 79, const Offset(0, 4));
    stroke(const Color(0xFFFFF1CF), 78);
    stroke(const Color(0xFFE9D7AF), 69);
    stroke(const Color(0xFFF4E5C4), 58, const Offset(-2, -1));
    final joint = Paint()
      ..color = const Color(0x24A38A61)
      ..strokeWidth = 1.2;
    for (final (pos, angle) in _joints) {
      if (pos.dy < sectionTop - 40 || pos.dy > sectionTop + size.height + 40) continue;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      canvas.drawLine(const Offset(0, -29), const Offset(0, 29), joint);
      canvas.drawLine(
        const Offset(1, -28),
        const Offset(1, 28),
        Paint()
          ..color = const Color(0x55FFFFEC)
          ..strokeWidth = 1,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MapPathPainter old) => old.geometry != geometry || old.sectionTop != sectionTop;
}

/// Raised, softly bevelled stone tiles with a porcelain rim and grounded
/// shadows. The same silhouette is used for completed, current and locked.
class NodePainter extends CustomPainter {
  const NodePainter({required this.color, required this.deep});
  final Color color, deep;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final radius = Radius.circular(size.width * .34);
    final face = RRect.fromRectAndRadius(rect, radius);
    final base = RRect.fromRectAndRadius(rect.shift(const Offset(0, 7)), radius);
    canvas.drawRRect(
      base.shift(const Offset(2, 5)),
      Paint()
        ..color = const Color(0x263D4932)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(base.inflate(2), Paint()..color = const Color(0xFFFFFCED));
    canvas.drawRRect(base, Paint()..color = deep);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, const Color(0xFFFFFBE3), .28)!, color],
        ).createShader(rect),
    );
    canvas.drawRRect(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..color = const Color(0xFFFFFCED),
    );
    final shine = RRect.fromRectAndRadius(rect.deflate(4), Radius.circular(size.width * .28));
    canvas.drawRRect(
      shine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x9AFFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(NodePainter old) => old.color != color || old.deep != deep;
}

/// A restrained breathing halo keeps the active tile legible.
class PulsePainter extends CustomPainter {
  PulsePainter({required this.time}) : super(repaint: time);
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final breathe = .5 + .5 * math.sin(time.value * 1.8);
    final rect = (Offset.zero & size).inflate(3 + breathe * 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(32)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFF7CD).withValues(alpha: .35 + breathe * .3),
    );
  }

  @override
  bool shouldRepaint(PulsePainter old) => old.time != time;
}
