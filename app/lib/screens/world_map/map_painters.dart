import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../design/tokens.dart';
import 'map_geometry.dart';

/// Section background: linear-gradient(to top, bg 0%, bg 78%, next.bg 100%).
class SectionBackgroundPainter extends CustomPainter {
  const SectionBackgroundPainter({required this.color, required this.next});
  final Color color, next;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, color, next],
          stops: const [0, .78, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(SectionBackgroundPainter old) => old.color != color || old.next != next;
}

/// The path through the levels: a wide soft band plus white dots
/// (stroke 26 at 55 % white, then stroke 8 dashed "1 20", round caps).
/// Painted per section, shifted by the section's top; dots are cached.
class MapPathPainter extends CustomPainter {
  MapPathPainter({required this.geometry, required this.sectionTop});
  final MapGeometry geometry;
  final double sectionTop;

  static final Map<double, (Path, List<(Offset, double)>)> _cache = {};

  (Path, List<(Offset, double)>) get _data => _cache.putIfAbsent(geometry.width, () {
        final path = geometry.path();
        final dots = <(Offset, double)>[];
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d <= m.length; d += 21) {
            final t = m.getTangentForOffset(d + .5);
            if (t != null) dots.add((t.position, t.angle));
          }
        }
        return (path, dots);
      });

  @override
  void paint(Canvas canvas, Size size) {
    final (path, dots) = _data;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -sectionTop);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..color = MapColors.pathBand,
    );
    // each dash is 1 px long with round caps: a 9 x 8 capsule along the path
    final dot = Paint()..color = MapColors.pathDots;
    final top = sectionTop - 10, bottom = sectionTop + size.height + 10;
    for (final (p, a) in dots) {
      if (p.dy < top || p.dy > bottom) continue;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(-a);
      canvas.drawRRect(RRect.fromLTRBR(-4.5, -4, 4.5, 4, const Radius.circular(4)), dot);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MapPathPainter old) => old.geometry.width != geometry.width || old.sectionTop != sectionTop;
}

/// Decorations of one world, animated from one shared clock (seconds).
class DecorationPainter extends CustomPainter {
  DecorationPainter({required this.decos, required this.sectionTop, required this.time}) : super(repaint: time);
  final List<MapDeco> decos;
  final double sectionTop;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final paint = Paint()..isAntiAlias = true;
    for (final d in decos) {
      final k = d.kind;
      final r = d.rect.shift(Offset(0, -sectionTop));
      // keyframes 0%,100% -> a; 50% -> b; ease-in-out per half (CSS)
      final p = k.seconds == 0 ? 0.0 : ((t + d.phase) / k.seconds) % 1.0;
      final half = Curves.easeInOut.transform(p < .5 ? p * 2 : 2 - p * 2);
      var opacity = .95;
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      switch (k.anim) {
        case DecoAnim.sway:
          canvas.rotate((-4 + 8 * half) * math.pi / 180);
        case DecoAnim.drift:
          canvas.translate(16 * half, 0);
        case DecoAnim.waveBob:
          canvas.translate(0, 6 * half);
        case DecoAnim.twinkle:
          opacity *= .25 + .75 * half;
          canvas.scale(.8 + .35 * half);
        case DecoAnim.none:
          break;
      }
      final local = Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height);
      final rr = k.radius.toRRect(local);
      if (k.ring > 0) {
        paint.color = MapColors.cloudWhite.withValues(alpha: opacity);
        canvas.drawRRect(rr.inflate(k.ring), paint);
      }
      paint.color = k.color.withValues(alpha: k.color.a * opacity);
      canvas.drawRRect(rr, paint);
      if (k.insetShade) {
        // inset -8px -8px 0: the part of the shape not covered by itself moved up-left
        final shade = Path.combine(PathOperation.difference, Path()..addRRect(rr), Path()..addRRect(rr.shift(const Offset(-8, -8))));
        paint.color = MapColors.planetShade.withValues(alpha: MapColors.planetShade.a * opacity);
        canvas.drawPath(shade, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DecorationPainter old) => old.decos != decos || old.sectionTop != sectionTop;
}

/// A level button: solid 6 px "3D" edge below, body, and the inset top
/// highlight (box-shadow 0 6px 0 deep, inset 0 3px 0 rgba(255,255,255,.35)).
class NodePainter extends CustomPainter {
  const NodePainter({required this.color, required this.deep});
  final Color color, deep;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()..isAntiAlias = true;
    paint.color = deep;
    canvas.drawCircle(c + const Offset(0, 6), r, paint);
    paint.color = color;
    canvas.drawCircle(c, r, paint);
    final body = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final shifted = Path()..addOval(Rect.fromCircle(center: c + const Offset(0, 3), radius: r));
    paint.color = MapColors.nodeInnerHighlight;
    canvas.drawPath(Path.combine(PathOperation.difference, body, shifted), paint);
  }

  @override
  bool shouldRepaint(NodePainter old) => old.color != color || old.deep != deep;
}

/// Current level: yellow ring growing 1 -> 1.75 while fading .6 -> 0 (1.6 s).
class PulsePainter extends CustomPainter {
  PulsePainter({required this.time}) : super(repaint: time);
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Curves.easeOut.transform((time.value / 1.6) % 1.0);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 * (1 + .75 * p),
      Paint()..color = LikhoColors.primary.withValues(alpha: .6 * (1 - p)),
    );
  }

  @override
  bool shouldRepaint(PulsePainter old) => false;
}
