import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import 'ls_theme.dart';

/// Resolution-independent fruit. Letters stay upright and occupy the fruit's
/// centre, rather than competing with a face or a small sticker.
abstract final class LsFruitArt {
  static final _letters = <String, TextPainter>{};

  static (Color, Color) colors(String art) => switch (art) {
    'apple' => (const Color(0xFFFF8D76), const Color(0xFFE44650)),
    'orange' => (const Color(0xFFFFCD62), const Color(0xFFF39029)),
    'watermelon' => (const Color(0xFF84D59B), const Color(0xFF219675)),
    'lemon' => (const Color(0xFFFFE884), const Color(0xFFE9B93A)),
    'plum' => (const Color(0xFFBC9CED), const Color(0xFF8157C0)),
    'kiwi' => (const Color(0xFFB9DA75), const Color(0xFF709C38)),
    'peach' => (const Color(0xFFFFBA8A), const Color(0xFFEE7B78)),
    'berry' => (const Color(0xFF9CE9F6), const Color(0xFF43A5D4)),
    _ => (const Color(0xFFFFE78A), const Color(0xFFF5B536)),
  };

  static Path _shape(String art) {
    if (art == 'star') {
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + math.pi * i / 5;
        final r = i.isEven ? 1.0 : .53;
        final x = math.cos(a) * r, y = math.sin(a) * r;
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      return p..close();
    }
    if (art == 'banana') {
      return Path()
        ..moveTo(-.85, -.65)
        ..cubicTo(-.65, .5, .35, .64, .87, -.45)
        ..cubicTo(.8, .92, -.55, 1.15, -.94, -.33)
        ..close();
    }
    if (art == 'apple' || art == 'peach') {
      return Path()
        ..moveTo(0, -.7)
        ..cubicTo(-.7, -1.1, -1.14, -.48, -.88, .23)
        ..cubicTo(-.7, .92, -.25, 1.01, 0, .84)
        ..cubicTo(.35, 1.02, .79, .77, .91, .14)
        ..cubicTo(1.12, -.65, .59, -1.03, 0, -.7)
        ..close();
    }
    return Path()..addOval(Rect.fromCenter(center: Offset.zero, width: art == 'lemon' ? 2.08 : 1.9, height: art == 'plum' ? 2 : 1.86));
  }

  static void draw(Canvas canvas, {required String art, required double radius, String? letter, double angle = 0, bool cut = false}) {
    final (light, dark) = colors(art);
    canvas.save();
    canvas.scale(radius);
    canvas.save();
    canvas.rotate(angle);
    final shape = _shape(art);
    canvas.drawShadow(shape, const Color(0x55174D48), 5 / radius, false);
    canvas.drawPath(shape.shift(const Offset(0, .065)), Paint()..color = Color.lerp(dark, LsTheme.ink, .2)!);
    canvas.drawPath(shape, Paint()..shader = ui.Gradient.linear(const Offset(-.6, -.9), const Offset(.6, .95), [light, dark]));
    if (cut) {
      canvas.save();
      canvas.scale(.83);
      canvas.drawPath(shape, Paint()..color = art == 'watermelon' ? const Color(0xFFFF7C83) : const Color(0xFFFFEDBD));
      for (var i = 0; i < 7; i++) {
        final a = i * math.pi * 2 / 7;
        canvas.drawOval(Rect.fromCenter(center: Offset(math.cos(a), math.sin(a)) * .58, width: .06, height: .12), Paint()..color = dark);
      }
      canvas.restore();
    } else {
      if (art == 'watermelon') {
        canvas.save();
        canvas.clipPath(shape);
        for (final x in [-.65, -.32, .32, .65]) {
          canvas.drawPath(
            Path()
              ..moveTo(x, -1)
              ..quadraticBezierTo(x * 1.6, 0, x, 1),
            Paint()
              ..color = const Color(0x302B7D61)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .1,
          );
        }
        canvas.restore();
      }
      // Broad, soft specular highlight; tiny pores on citrus skins.
      canvas.drawPath(
        Path()
          ..moveTo(-.66, -.15)
          ..quadraticBezierTo(-.68, -.57, -.34, -.62),
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = .105,
      );
      if (art == 'orange' || art == 'lemon') {
        for (final p in [const Offset(.64, .16), const Offset(.53, .48), const Offset(.34, .63)]) {
          canvas.drawCircle(p, .026, Paint()..color = const Color(0x65FFFFFF));
        }
      }
      if (['apple', 'orange', 'plum', 'peach'].contains(art)) {
        canvas.drawPath(
          Path()
            ..moveTo(0, -.74)
            ..quadraticBezierTo(-.02, -.98, .1, -1.12),
          Paint()
            ..color = const Color(0xFF796349)
            ..strokeWidth = .075
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(.03, -.88)
            ..quadraticBezierTo(.14, -1.25, .53, -1.05)
            ..quadraticBezierTo(.38, -.72, .03, -.88),
          Paint()..color = const Color(0xFF348B64),
        );
        canvas.drawLine(
          const Offset(.08, -.9),
          const Offset(.4, -1.03),
          Paint()
            ..color = const Color(0xFF91CB86)
            ..strokeWidth = .025
            ..strokeCap = StrokeCap.round,
        );
      }
      if (art == 'berry') {
        final paint = Paint()
          ..color = const Color(0xDDFFFFFF)
          ..strokeWidth = .07
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          final d = Offset(math.cos(a), math.sin(a)) * .48;
          canvas.drawLine(-d, d, paint);
        }
      }
    }
    canvas.restore();
    if (letter != null && !cut) {
      // Fixed design-space text keeps the cache bounded while fruit scales.
      final darkLetter = art == 'lemon' || art == 'kiwi';
      final key = '$letter/$darkLetter';
      final tp = _letters.putIfAbsent(
        key,
        () => TextPainter(
          text: TextSpan(
            text: letter,
            style: LikhoFonts.letter(size: 64, color: darkLetter ? LsTheme.ink : LsTheme.cream).copyWith(
              height: 1,
              shadows: darkLetter ? null : const [Shadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 1)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      canvas.scale(1 / 48);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 + 1));
    }
    canvas.restore();
  }
}

class LsFruitPicture extends StatelessWidget {
  const LsFruitPicture({super.key, this.art = 'apple', this.letter, this.size = 88, this.angle = 0});
  final String art;
  final String? letter;
  final double size, angle;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _FruitPicturePainter(art, letter, angle)),
  );
}

class _FruitPicturePainter extends CustomPainter {
  const _FruitPicturePainter(this.art, this.letter, this.angle);
  final String art;
  final String? letter;
  final double angle;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height * .55);
    LsFruitArt.draw(canvas, art: art, letter: letter, radius: size.width * .4, angle: angle);
  }

  @override
  bool shouldRepaint(_FruitPicturePainter old) => old.art != art || old.letter != letter || old.angle != angle;
}

/// Quiet, airy orchard scenery; all contrast belongs to the flying fruit.
class LsOrchardPainter extends CustomPainter {
  const LsOrchardPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), const [Color(0xFFF7FBEE), Color(0xFFE4F4EB), Color(0xFFCAEADF)], const [0, .5, 1]),
    );
    canvas.drawCircle(
      Offset(size.width * .92, size.height * .32),
      size.width * .31,
      Paint()..shader = ui.Gradient.radial(Offset(size.width * .92, size.height * .32), size.width * .31, const [Color(0x70FFF6CF), Color(0x00FFF6CF)]),
    );
    final rnd = math.Random(24);
    for (var i = 0; i < 24; i++) {
      final p = Offset(rnd.nextDouble() * size.width, size.height * (.28 + rnd.nextDouble() * .65));
      final r = 1.5 + rnd.nextDouble() * 2;
      canvas.drawCircle(p, r, Paint()..color = const Color(0x65FFFFFF));
    }
    // Layered orchard banks stay at the edges of the play field.
    final h = size.height, w = size.width;
    canvas.drawPath(
      Path()
        ..moveTo(0, h - 64)
        ..quadraticBezierTo(w * .2, h - 110, w * .52, h - 35)
        ..quadraticBezierTo(w * .8, h + 3, w, h - 76)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFFB8DDCD),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h - 25)
        ..quadraticBezierTo(w * .45, h - 75, w, h - 21)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF9DCDBB),
    );
    for (final right in [false, true]) {
      canvas.save();
      canvas.translate(right ? w + 10 : -10, h - 55);
      canvas.scale(right ? -1 : 1, 1);
      final stem = Paint()
        ..color = const Color(0xFF7CB7A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawPath(
        Path()
          ..moveTo(0, 45)
          ..quadraticBezierTo(42, -10, 28, -91),
        stem,
      );
      for (var i = 0; i < 4; i++) {
        final y = -i * 22.0;
        canvas.drawPath(
          Path()
            ..moveTo(27, y)
            ..quadraticBezierTo(62, y - 32, 57, y - 9)
            ..quadraticBezierTo(47, y + 4, 27, y),
          Paint()..color = const Color(0xFF8DC3AA),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(LsOrchardPainter old) => false;
}
