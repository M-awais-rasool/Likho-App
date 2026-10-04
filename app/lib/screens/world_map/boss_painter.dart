import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../design/tokens.dart';

/// The six world bosses (prototype Boss component, viewBox 120 x 100):
/// snail, fish, bear, robot-bus, cloud, moon. Asleep they breathe and
/// float "z z"; awake they smile.
class BossPainter extends CustomPainter {
  BossPainter({required this.world, required this.awake, required this.time, this.dance = false}) : super(repaint: time);

  final int world;

  /// Which of the six boss drawings a world's boss id is (world ids from
  /// the course; a new world in the admin panel picks one of these).
  static int indexOf(String bossId) => switch (bossId) {
        'snail' => 0,
        'fish' => 1,
        'bear' => 2,
        'robotBus' => 3,
        'cloud' => 4,
        'moon' => 5,
        _ => 0,
      };
  final bool awake;
  final bool dance; // bDance: rock and hop (woken in gameplay)
  final ValueListenable<double> time; // seconds

  static const _faces = [(24.0, 58.0, .8), (40.0, 50.0, 1.0), (60.0, 50.0, 1.1), (60.0, 43.0, 1.0), (62.0, 60.0, 1.0), (60.0, 52.0, 1.2)];

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.save();
    canvas.scale(size.width / 120, size.height / 100);
    final fill = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    fill.color = BossColors.shadow;
    canvas.drawOval(Rect.fromCenter(center: const Offset(60, 96), width: 88, height: 8), fill);

    canvas.save();
    if (dance) {
      // bDance .55 s: rotate -8 -> 0 (up 10) -> 8 -> 0 (up 10), around (60,95)
      final p = (t / .55) % 1.0;
      final q = (p * 4).floor(), f = Curves.easeInOut.transform(p * 4 - q);
      const rots = [-8.0, 0.0, 8.0, 0.0, -8.0];
      const ups = [0.0, -10.0, 0.0, -10.0, 0.0];
      canvas.translate(60, 95 + ups[q] + (ups[q + 1] - ups[q]) * f);
      canvas.rotate((rots[q] + (rots[q + 1] - rots[q]) * f) * 3.14159265 / 180);
      canvas.translate(-60, -95);
    } else if (!awake) {
      // bSleep 3.2 s: scale(1,1) -> (1.03,.97) -> (1,1) around (60,95)
      final k = Curves.easeInOut.transform(1 - (2 * ((t / 3.2) % 1.0) - 1).abs());
      canvas.translate(60, 95);
      canvas.scale(1 + .03 * k, 1 - .03 * k);
      canvas.translate(-60, -95);
    }
    _body(canvas, fill, stroke);
    final (fx, fy, fs) = _faces[world];
    canvas.translate(fx, fy);
    canvas.scale(fs);
    fill.color = BossColors.cheek;
    canvas.drawCircle(const Offset(-14, 7), 4, fill);
    canvas.drawCircle(const Offset(14, 7), 4, fill);
    fill.color = BossColors.face;
    stroke
      ..color = BossColors.face
      ..strokeWidth = 2.6;
    if (awake) {
      canvas.drawCircle(const Offset(-7, 0), 4.2, fill);
      canvas.drawCircle(const Offset(7, 0), 4.2, fill);
      fill.color = BossColors.cloudBody;
      canvas.drawCircle(const Offset(-5.6, -1.5), 1.4, fill);
      canvas.drawCircle(const Offset(8.4, -1.5), 1.4, fill);
      canvas.drawPath(Path()..moveTo(-6, 8)..quadraticBezierTo(0, 15, 6, 8), stroke);
    } else {
      canvas.drawPath(Path()..moveTo(-12, 0)..quadraticBezierTo(-7, 4.5, -2, 0), stroke);
      canvas.drawPath(Path()..moveTo(2, 0)..quadraticBezierTo(7, 4.5, 12, 0), stroke);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 10), width: 4.8, height: 6), fill);
    }
    canvas.restore();

    if (!awake) {
      final zc = world == 5 ? BossColors.zzzSpace : BossColors.zzz;
      _z(canvas, const Offset(96, 22), 14, ((t / 2.6) % 1.0), zc);
      _z(canvas, const Offset(104, 10), 10, (((t - 1.2) / 2.6) % 1.0), zc);
    }
    canvas.restore();
  }

  /// bZ 2.6 s ease-out: fade in (30 %), drift (12, -22), scale .6 -> 1.1.
  void _z(Canvas canvas, Offset at, double size, double p, Color c) {
    if (p < 0) p += 1;
    final e = Curves.easeOut.transform(p);
    final a = p < .3 ? p / .3 : 1 - (p - .3) / .7;
    final tp = TextPainter(
      text: TextSpan(text: 'z', style: LikhoFonts.title(size: size, weight: FontWeight.w700, color: c.withValues(alpha: a.clamp(0.0, 1.0)))),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx + 12 * e, at.dy - 22 * e);
    canvas.scale(.6 + .5 * e);
    // SVG text y is the baseline
    tp.paint(canvas, Offset(0, -tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
    canvas.restore();
  }

  void _body(Canvas canvas, Paint fill, Paint stroke) {
    switch (world) {
      case 0: // snail
        fill.color = BossColors.snailBody;
        canvas.drawRRect(RRect.fromLTRBR(8, 66, 112, 90, const Radius.circular(12)), fill);
        canvas.drawCircle(const Offset(24, 58), 17, fill);
        stroke
          ..color = BossColors.snailStalk
          ..strokeWidth = 3;
        canvas.drawLine(const Offset(16, 44), const Offset(12, 30), stroke);
        canvas.drawLine(const Offset(30, 43), const Offset(33, 29), stroke);
        fill.color = BossColors.snailStalk;
        canvas.drawCircle(const Offset(12, 29), 3.5, fill);
        canvas.drawCircle(const Offset(33, 28), 3.5, fill);
        fill.color = BossColors.snailShell;
        canvas.drawCircle(const Offset(72, 50), 33, fill);
        stroke
          ..color = BossColors.snailShellLine
          ..strokeWidth = 2.5;
        canvas.drawCircle(const Offset(72, 50), 33, stroke);
        stroke.strokeWidth = 3;
        canvas.drawCircle(const Offset(74, 52), 21, stroke);
        canvas.drawCircle(const Offset(77, 54), 9, stroke);
      case 1: // fish
        fill.color = BossColors.fishFin;
        canvas.drawPath(Path()..addPolygon(const [Offset(92, 52), Offset(116, 32), Offset(116, 72)], true), fill);
        fill.color = BossColors.fishBody;
        canvas.drawOval(Rect.fromCenter(center: const Offset(56, 54), width: 88, height: 60), fill);
        fill.color = BossColors.fishFin;
        canvas.drawPath(Path()..moveTo(50, 26)..quadraticBezierTo(66, 12, 78, 28)..close(), fill);
        stroke
          ..color = BossColors.fishFin
          ..strokeWidth = 3;
        canvas.drawPath(Path()..moveTo(64, 40)..quadraticBezierTo(72, 54, 64, 68), stroke);
        fill.color = BossColors.shine;
        canvas.drawOval(Rect.fromCenter(center: const Offset(42, 44), width: 20, height: 12), fill);
      case 2: // bear
        fill.color = BossColors.bearEar;
        canvas.drawCircle(const Offset(30, 22), 13, fill);
        canvas.drawCircle(const Offset(90, 22), 13, fill);
        fill.color = BossColors.bearEarInner;
        canvas.drawCircle(const Offset(30, 22), 6, fill);
        canvas.drawCircle(const Offset(90, 22), 6, fill);
        fill.color = BossColors.bearBody;
        canvas.drawOval(Rect.fromCenter(center: const Offset(60, 56), width: 84, height: 76), fill);
        fill.color = BossColors.bearMuzzle;
        canvas.drawOval(Rect.fromCenter(center: const Offset(60, 68), width: 34, height: 24), fill);
        fill.color = BossColors.bearNose;
        canvas.drawOval(Rect.fromCenter(center: const Offset(60, 62), width: 12, height: 8), fill);
      case 3: // robot-bus
        final light = awake ? BossColors.busLightOn : BossColors.busLightOff;
        stroke
          ..color = BossColors.busDark
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.butt;
        canvas.drawLine(const Offset(60, 20), const Offset(60, 8), stroke);
        stroke.strokeCap = StrokeCap.round;
        fill.color = light;
        canvas.drawCircle(const Offset(60, 7), 4, fill);
        final body = RRect.fromLTRBR(6, 20, 114, 82, const Radius.circular(16));
        fill.color = LikhoColors.primary;
        canvas.drawRRect(body, fill);
        stroke
          ..color = LikhoColors.primaryDeep
          ..strokeWidth = 2.5;
        canvas.drawRRect(body, stroke);
        fill.color = BossColors.busWindow;
        canvas.drawRRect(RRect.fromLTRBR(14, 28, 106, 58, const Radius.circular(10)), fill);
        fill.color = LikhoColors.primaryDeep.withValues(alpha: .5);
        canvas.drawRect(const Rect.fromLTWH(6, 64, 108, 6), fill);
        fill.color = light;
        canvas.drawCircle(const Offset(106, 72), 5, fill);
        canvas.drawCircle(const Offset(14, 72), 5, fill);
        fill.color = BossColors.busDark;
        canvas.drawCircle(const Offset(32, 84), 11, fill);
        canvas.drawCircle(const Offset(88, 84), 11, fill);
        fill.color = BossColors.busLightOff;
        canvas.drawCircle(const Offset(32, 84), 4, fill);
        canvas.drawCircle(const Offset(88, 84), 4, fill);
      case 4: // cloud
        fill.color = BossColors.cloudBody;
        canvas.drawCircle(const Offset(36, 60), 24, fill);
        canvas.drawCircle(const Offset(62, 44), 31, fill);
        canvas.drawCircle(const Offset(90, 60), 22, fill);
        canvas.drawRRect(RRect.fromLTRBR(18, 56, 106, 86, const Radius.circular(15)), fill);
        stroke
          ..color = BossColors.cloudLine
          ..strokeWidth = 3;
        canvas.drawPath(Path()..moveTo(22, 80)..quadraticBezierTo(60, 92, 102, 80), stroke);
      default: // moon
        fill.color = BossColors.moon;
        canvas.drawCircle(const Offset(60, 50), 42, fill);
        fill.color = BossColors.moonCrater;
        canvas.drawCircle(const Offset(84, 34), 7, fill);
        canvas.drawCircle(const Offset(90, 62), 5, fill);
        canvas.drawCircle(const Offset(34, 30), 4, fill);
        fill.color = BossColors.moonShine;
        canvas.drawOval(Rect.fromCenter(center: const Offset(44, 32), width: 20, height: 12), fill);
    }
  }

  @override
  bool shouldRepaint(BossPainter old) => old.world != world || old.awake != awake || old.dance != dance;
}

