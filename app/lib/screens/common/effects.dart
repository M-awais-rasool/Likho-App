import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';

/// One-shot sparkle burst: little four-point stars and dots fly out from the
/// centre, spin and fade (a landed star, a new sticker, the splash line).
/// Paints outside its [size] box; nothing while "Reduce motion" is on.
class SparkleBurst extends ConsumerWidget {
  const SparkleBurst({super.key, this.size = 140, this.delay = 0, this.count = 10, this.seconds = .75, this.colors = GameColors.sparks, this.seed = 1});

  final double size, delay, seconds;
  final int count, seed;
  final List<Color> colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(reduceMotionProvider)) return SizedBox.square(dimension: size);
    final r = math.Random(seed);
    final bits = [
      for (var i = 0; i < count; i++)
        _Bit(
          angle: 2 * math.pi * i / count + (r.nextDouble() - .5) * .5,
          dist: .55 + r.nextDouble() * .45,
          size: 5 + r.nextDouble() * 7,
          star: i.isEven,
          color: colors[i % colors.length],
          spin: (r.nextDouble() - .5) * 4,
        ),
    ];
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: Entrance(
          delay: Duration(milliseconds: (delay * 1000).round()),
          duration: Duration(milliseconds: (seconds * 1000).round()),
          child: const SizedBox.expand(),
          builder: (context, t, child) => t <= 0 || t >= 1 ? child : CustomPaint(painter: _BurstPainter(bits, t)),
        ),
      ),
    );
  }
}

class _Bit {
  const _Bit({required this.angle, required this.dist, required this.size, required this.star, required this.color, required this.spin});
  final double angle, dist, size, spin;
  final bool star;
  final Color color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.bits, this.t);
  final List<_Bit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final out = Curves.easeOutCubic.transform(t);
    final grow = t < .25 ? t / .25 : 1 - Curves.easeIn.transform((t - .25) / .75);
    final p = Paint();
    for (final b in bits) {
      final pos = c + Offset(math.cos(b.angle), math.sin(b.angle)) * (size.width / 2 * b.dist * out);
      final s = b.size * (.4 + .6 * grow);
      p.color = b.color.withValues(alpha: (1 - t * t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(b.spin * t);
      if (b.star) {
        // four-point sparkle
        final path = Path()
          ..moveTo(0, -s)
          ..quadraticBezierTo(0, 0, s, 0)
          ..quadraticBezierTo(0, 0, 0, s)
          ..quadraticBezierTo(0, 0, -s, 0)
          ..quadraticBezierTo(0, 0, 0, -s)
          ..close();
        canvas.drawPath(path, p);
      } else {
        canvas.drawCircle(Offset.zero, s * .32, p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// Soft rotating light rays behind a perfect score. Fades in after [delay].
class Sunburst extends ConsumerWidget {
  const Sunburst({super.key, this.size = 320, this.delay = 0, this.rays = 12, this.color = CompleteColors.glow});
  final double size, delay;
  final int rays;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final painter = Loop(
      seconds: 24,
      child: const SizedBox.expand(),
      builder: (context, t, child) => CustomPaint(painter: _RaysPainter(rays, t * 2 * math.pi, color)),
    );
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: FadeIn(delay: delay, seconds: .8, child: painter),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.rays, this.angle, this.color);
  final int rays;
  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)], stops: const [.15, 1]).createShader(Rect.fromCircle(center: c, radius: r));
    final path = Path();
    final half = math.pi / rays / 2;
    for (var i = 0; i < rays; i++) {
      final a = angle + 2 * math.pi * i / rays;
      path
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - half), c.dy + r * math.sin(a - half))
        ..lineTo(c.dx + r * math.cos(a + half), c.dy + r * math.sin(a + half))
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.angle != angle;
}
