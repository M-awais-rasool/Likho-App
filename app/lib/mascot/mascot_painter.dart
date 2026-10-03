import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../design/tokens.dart';
import 'mascot_controller.dart';
import 'mascot_pose.dart';
import 'rig/part_library.dart';
import 'rig/pencil_rig.dart';
import 'rig/svg_part.dart';

/// Draws the cut-out rig. Layer order (back to front):
/// shadow, cape, legs, arms, body, cone, eraser+band, cheeks, eyes, brows,
/// mouth, front accessories, hands, effects.
///
/// Arms are drawn behind the body and hands in front: on the master the arms
/// come out from behind the body, so this is what keeps the idle pose exact.
class MascotPainter extends CustomPainter {
  MascotPainter({required this.controller, required this.parts, this.shadow = true}) : super(repaint: controller);

  final MascotController controller;
  final MascotParts parts;

  /// Draws the ground shadow under the feet (the app icon brings its own).
  final bool shadow;

  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _soft = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

  /// Anchor height of each accessory: where it rides on the bending body.
  static const Map<String, double> _accessoryAnchorY = {
    MascotAccessory.cap: 110,
    MascotAccessory.wizardHat: 100,
    MascotAccessory.partyHat: 97,
    MascotAccessory.crown: 100,
    MascotAccessory.bow: 104,
    MascotAccessory.headphones: 200,
    MascotAccessory.roundGlasses: 293,
    MascotAccessory.starGlasses: 293,
    MascotAccessory.scarf: 402,
    MascotAccessory.cape: 238,
  };
  static const Set<String> _hats = {
    MascotAccessory.cap,
    MascotAccessory.wizardHat,
    MascotAccessory.partyHat,
    MascotAccessory.crown,
    MascotAccessory.bow,
    MascotAccessory.headphones,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;
    final p = c.pose;
    final sw = c.swatch;
    final acc = c.accessory;

    canvas.save();
    canvas.scale(size.height / PencilRig.artboard.height);
    if (shadow) _shadow(canvas, p);

    // whole body: translate, then rotate/squash around the feet
    final f = PencilRig.feet;
    canvas.translate(p.x + f.dx, p.y + f.dy);
    canvas.rotate(p.rotation);
    canvas.scale(p.scaleX, p.scaleY);
    canvas.translate(-f.dx, -f.dy);

    if (acc == MascotAccessory.cape) _accessory(canvas, acc!, p);
    _leg(canvas, 'leg_left', PencilRig.hipLeft, p.legLeft, p.lean, sw);
    _leg(canvas, 'leg_right', PencilRig.hipRight, -p.legRight, p.lean, sw);
    final armL = _armGeometry(-1, PencilRig.armLeft, p.armLeft, p.lean);
    final armR = _armGeometry(1, PencilRig.armRight, p.armRight, p.lean);
    if (!p.armLeft.front) _arm(canvas, armL, sw);
    if (!p.armRight.front) _arm(canvas, armR, sw);

    _torso(canvas, 'body', p.lean, 0, sw);
    _torso(canvas, 'cone', p.lean, 0, sw);
    // the cap covers the eraser completely (reference: design/mascot/4cnmtm…jpeg)
    if (acc != MascotAccessory.cap) _torso(canvas, 'eraser', p.lean, p.eraserDrop, sw);

    _bent(canvas, p.lean, PencilRig.faceCentre, () {
      canvas.save();
      canvas.translate(0, p.faceOffset);
      _cheeks(canvas, p);
      _eye(canvas, PencilRig.eyeLeft, -1, p, sw);
      _eye(canvas, PencilRig.eyeRight, 1, p, sw);
      _brow(canvas, 'brow_left', PencilRig.browLeft, -1, p, sw);
      _brow(canvas, 'brow_right', PencilRig.browRight, 1, p, sw);
      _mouth(canvas, p, sw);
      canvas.restore();
    });

    if (p.armLeft.front) _arm(canvas, armL, sw, from: 0.14);
    if (p.armRight.front) _arm(canvas, armR, sw, from: 0.14);
    if (acc != null && acc != MascotAccessory.cape) _accessory(canvas, acc, p);
    _hand(canvas, armL, p.armLeft, sw);
    _hand(canvas, armR, p.armRight, sw);
    _effects(canvas, p, c.time);
    canvas.restore();
  }

  // ------------------------------------------------------------------ colours
  Color _role(PartShape s, BodySwatch sw) => switch (s.role) {
        'body' => sw.base,
        'body-light' => sw.light,
        'body-dark' => sw.dark,
        'body-line' => sw.line,
        'eraser' => MascotColors.eraser,
        'eraser-shade' => MascotColors.eraserShade,
        'eraser-line' => MascotColors.eraserLine,
        'band' => MascotColors.band,
        'band-hi' => MascotColors.bandHighlight,
        'band-shade' => MascotColors.bandShade,
        'band-line' => MascotColors.bandLine,
        'cone' => MascotColors.cone,
        'cone-light' => MascotColors.coneLight,
        'cone-dark' => MascotColors.coneDark,
        'cone-line' => MascotColors.coneLine,
        'graphite' => MascotColors.graphite,
        'brow' => MascotColors.brow,
        'cheek' => MascotColors.cheek,
        'mouth' => MascotColors.mouth,
        'mouth-teeth' => MascotColors.mouthTeeth,
        'tongue' => MascotColors.tongue,
        'tongue-line' => MascotColors.tongueLine,
        'fx' => MascotColors.effects,
        _ => s.fill, // accessories keep their own art colours
      };

  void _draw(Canvas canvas, String part, BodySwatch sw, [double opacity = 1]) {
    for (final s in parts[part]) {
      final col = _role(s, sw);
      _paint.color = opacity >= 1 ? col : col.withValues(alpha: col.a * opacity);
      canvas.drawPath(s.path, _paint);
    }
  }

  // ------------------------------------------------------------------ bend
  /// Runs [draw] with the canvas following the body bend at [anchor] (rigid).
  void _bent(Canvas canvas, double lean, Offset anchor, void Function() draw) {
    if (lean.abs() < 0.05) {
      draw();
      return;
    }
    canvas.save();
    canvas.translate(anchor.dx + PencilRig.bendDx(lean, anchor.dy), anchor.dy);
    canvas.rotate(PencilRig.bendAngle(lean, anchor.dy));
    canvas.translate(-anchor.dx, -anchor.dy);
    draw();
    canvas.restore();
  }

  /// Torso parts are warped point by point so the body can curve.
  void _torso(Canvas canvas, String part, double lean, double drop, BodySwatch sw) {
    if (lean.abs() < 0.05) {
      if (drop != 0) {
        canvas.save();
        canvas.translate(0, drop);
      }
      _draw(canvas, part, sw);
      if (drop != 0) canvas.restore();
      return;
    }
    Offset warp(Offset q) {
      final y = q.dy + drop;
      return Offset(q.dx + PencilRig.bendDx(lean, y), y);
    }

    for (final s in parts[part]) {
      _paint.color = _role(s, sw);
      canvas.drawPath(s.warped(warp), _paint);
    }
  }

  // ------------------------------------------------------------------ shadow
  void _shadow(Canvas canvas, MascotPose p) {
    final h = (-p.y / 70).clamp(0.0, 1.0);
    final c = PencilRig.shadowCentre;
    final r = PencilRig.shadowRadii;
    _soft.color = MascotColors.shadow.withValues(alpha: 1 - 0.45 * h);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx + p.x, c.dy), width: 2 * r.width * (1 - 0.25 * h), height: 2 * r.height * (1 - 0.2 * h)),
      _soft,
    );
  }

  // ------------------------------------------------------------------ legs
  void _leg(Canvas canvas, String part, Offset hip, double angle, double lean, BodySwatch sw) {
    _bent(canvas, lean, hip, () {
      if (angle == 0) {
        _draw(canvas, part, sw);
        return;
      }
      canvas.save();
      canvas.translate(hip.dx, hip.dy);
      canvas.rotate(angle);
      canvas.translate(-hip.dx, -hip.dy);
      _draw(canvas, part, sw);
      canvas.restore();
    });
  }

  // ------------------------------------------------------------------ arms
  _ArmGeo _armGeometry(int side, ArmRest rest, ArmPose ap, double lean) {
    // side: -1 = screen-left arm, +1 = screen-right arm
    final sign = side < 0 ? 1.0 : -1.0; // + raise = outward/up for both arms
    final s0 = rest.shoulder;
    final s = Offset(s0.dx + PencilRig.bendDx(lean, s0.dy), s0.dy);
    final d0 = rest.wrist - s0;
    final len0 = d0.distance;
    final ang0 = math.atan2(d0.dy, d0.dx);
    final cl = _rot(rest.control - s0, -ang0);
    final ang = ang0 + sign * ap.raise + PencilRig.bendAngle(lean, s0.dy);
    final c = s + _rot(Offset(cl.dx * ap.reach, cl.dy + sign * ap.bend), ang);
    final w = s + _rot(Offset(len0 * ap.reach, 0), ang);
    final t = w - c;
    final r = ((ap.raise - PencilRig.armStraightFrom) / (PencilRig.armStraightAt - PencilRig.armStraightFrom)).clamp(0.0, 1.0);
    return _ArmGeo(side, s, c, w, math.atan2(t.dy, t.dx), r * r * (3 - 2 * r));
  }

  void _arm(Canvas canvas, _ArmGeo g, BodySwatch sw, {double from = 0}) {
    const n = 22;
    final outer = g.side < 0 ? 1.0 : -1.0;
    final pts = List<Offset>.generate(n + 1, (i) => _bez(g, i / n));
    final nrm = List<Offset>.generate(n + 1, (i) {
      final d = _dbez(g, i / n);
      final l = d.distance == 0 ? 1.0 : d.distance;
      return Offset(-d.dy / l, d.dx / l) * outer; // points to the outer edge
    });
    // A raised back arm's underside (inner offsets) runs straight into the
    // body from the end of the shoulder flare (see PencilRig.armFlareEnd).
    final j = (PencilRig.armFlareEnd * n).round();
    final run = <double>[0]; // arc length
    for (var i = 1; i <= n; i++) {
      run.add(run.last + (pts[i] - pts[i - 1]).distance);
    }
    final dj = _dbez(g, j / n);
    final along = dj / (dj.distance == 0 ? 1.0 : dj.distance);
    final straight = from > 0 ? 0.0 : g.lift; // front arms keep their round root
    Offset at(int i, double Function(double hw) f) {
      final p = pts[i] + nrm[i] * f(PencilRig.armHalfWidthAt(i / n));
      final o = f(PencilRig.armHalfWidthAt(j / n));
      if (i >= j || straight == 0 || o >= 0) return p;
      return Offset.lerp(p, pts[j] + nrm[j] * o - along * (run[j] - run[i]), straight)!;
    }

    Path band(double Function(double hw) a, double Function(double hw) b, double start) {
      final path = Path();
      final back = <Offset>[];
      var first = true;
      for (var i = 0; i <= n; i++) {
        final s = i / n;
        if (s < math.max(start, from)) continue;
        final pa = at(i, a);
        back.add(at(i, b));
        if (first) {
          path.moveTo(pa.dx, pa.dy);
          first = false;
        } else {
          path.lineTo(pa.dx, pa.dy);
        }
      }
      for (final q in back.reversed) {
        path.lineTo(q.dx, q.dy);
      }
      return path..close();
    }

    const line = PencilRig.armLine;
    // round caps; the shoulder cap only for front arms (a back arm's root is
    // hidden inside the body, and a cap there would poke past the outline)
    final root = _bez(g, from);
    final h0 = PencilRig.armHalfWidthAt(from), h1 = PencilRig.armHalfWidthAt(1);
    _paint.color = sw.line;
    canvas.drawPath(band((h) => h, (h) => -h, 0), _paint);
    if (from > 0) canvas.drawCircle(root, h0, _paint);
    canvas.drawCircle(g.w, h1, _paint);
    _paint.color = sw.base;
    canvas.drawPath(band((h) => h - line, (h) => -(h - line), 0), _paint);
    if (from > 0) canvas.drawCircle(root, h0 - line, _paint);
    canvas.drawCircle(g.w, h1 - line, _paint);
    _paint.color = sw.light;
    canvas.drawPath(band((h) => h - line, (h) => h - line - PencilRig.armLightWidth, PencilRig.armLightFrom), _paint);
    _paint.color = sw.dark;
    canvas.drawPath(band((h) => -(h - line), (h) => -(h - line - PencilRig.armDarkWidth), PencilRig.armDarkFrom), _paint);
  }

  Offset _bez(_ArmGeo g, double t) {
    final u = 1 - t;
    return g.s * (u * u) + g.c * (2 * u * t) + g.w * (t * t);
  }

  Offset _dbez(_ArmGeo g, double t) => (g.c - g.s) * (2 * (1 - t)) + (g.w - g.c) * (2 * t);

  // ------------------------------------------------------------------ hands
  void _hand(Canvas canvas, _ArmGeo g, ArmPose ap, BodySwatch sw) {
    final sign = g.side < 0 ? 1.0 : -1.0;
    canvas.save();
    canvas.translate(g.w.dx, g.w.dy);
    canvas.rotate(g.tangent + sign * ap.handTurn);
    if (ap.hand == HandShape.rest) {
      // traced per side on the master
      final rest = g.side < 0 ? PencilRig.armLeft : PencilRig.armRight;
      canvas.rotate(-math.atan2(rest.tangent.dy, rest.tangent.dx));
      canvas.translate(-rest.wrist.dx, -rest.wrist.dy);
      _draw(canvas, g.side < 0 ? 'hand_rest_left' : 'hand_rest_right', sw);
    } else {
      // pose hands are drawn for the right side; the left side is mirrored
      final rest = PencilRig.armRight;
      if (g.side < 0) canvas.scale(1, -1);
      canvas.rotate(-math.atan2(rest.tangent.dy, rest.tangent.dx));
      canvas.translate(-rest.wrist.dx, -rest.wrist.dy);
      _draw(canvas, ap.hand.part, sw);
    }
    canvas.restore();
  }

  // ------------------------------------------------------------------ face
  void _cheeks(Canvas canvas, MascotPose p) {
    final shapes = parts['cheeks'];
    final grow = 1 + 0.14 * p.blush;
    for (var i = 0; i < shapes.length; i++) {
      final centre = i == 0 ? PencilRig.cheekLeft : PencilRig.cheekRight;
      _soft.color = MascotColors.cheek;
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.scale(grow);
      canvas.translate(-centre.dx, -centre.dy);
      canvas.drawPath(shapes[i].path, _soft);
      canvas.restore();
    }
  }

  void _eye(Canvas canvas, EyeRest e, int side, MascotPose p, BodySwatch sw) {
    final s = p.eyeScale;
    final centre = e.white;
    if (p.eyes == EyeStyle.happy) {
      final w = 26.0 * s;
      final arc = Path()
        ..moveTo(centre.dx - w, centre.dy + 8)
        ..quadraticBezierTo(centre.dx, centre.dy - 30 * s, centre.dx + w, centre.dy + 8);
      _line
        ..color = MascotColors.happyEye
        ..strokeWidth = 7.5;
      canvas.drawPath(arc, _line);
      return;
    }
    final wow = p.eyes == EyeStyle.wow;
    final whiteR = PencilRig.eyeWhiteR * s;
    _paint.color = MascotColors.eyeRim;
    canvas.drawCircle(centre + e.rimOffset * s, PencilRig.rimR * s, _paint);
    _paint.color = MascotColors.eyeWhite;
    canvas.drawCircle(centre, whiteR, _paint);

    final pr = PencilRig.pupilR * s * (wow ? 0.86 : 1);
    var off = e.pupilOffset * s + controller.look * PencilRig.pupilTravel * s;
    final maxOff = whiteR - pr - 0.5;
    if (off.distance > maxOff) off = off / off.distance * maxOff;
    final pc = centre + off;
    _paint.color = MascotColors.pupil;
    canvas.drawCircle(pc, pr, _paint);
    _paint.color = MascotColors.eyeWhite;
    canvas.drawCircle(pc + PencilRig.highlightOffset * (pr / PencilRig.pupilR), PencilRig.highlightR * s * (wow ? 1.15 : 1), _paint);
    if (wow) canvas.drawCircle(pc + Offset(8, 8) * s, 3.2 * s, _paint);

    final lid = math.max(p.lid, controller.blink).clamp(0.0, 1.0);
    if (lid <= 0.001) return;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: whiteR + 0.6)));
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(side * p.lidTilt); // droops the outer corner
    final r = whiteR + 1;
    final edge = -r + lid * 2 * r;
    _paint.color = sw.lid;
    canvas.drawRect(Rect.fromLTRB(-r - 8, -r - 8, r + 8, edge), _paint);
    _line
      ..color = MascotColors.eyeRim
      ..strokeWidth = PencilRig.lidLine;
    canvas.drawLine(Offset(-r - 8, edge), Offset(r + 8, edge), _line);
    canvas.restore();
    if (lid > 0.85) {
      // fully closed: lash crescent along the bottom of the eye
      _line
        ..color = MascotColors.eyeRim.withValues(alpha: ((lid - 0.85) / 0.15).clamp(0.0, 1.0))
        ..strokeWidth = PencilRig.lidLine;
      canvas.drawArc(Rect.fromCircle(center: centre, radius: whiteR - 2), math.pi * 0.15, math.pi * 0.7, false, _line);
    }
  }

  void _brow(Canvas canvas, String part, Offset pivot, int side, MascotPose p, BodySwatch sw) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy + p.browY);
    canvas.rotate(side * p.browTilt);
    canvas.translate(-pivot.dx, -pivot.dy);
    _draw(canvas, part, sw);
    canvas.restore();
  }

  void _mouth(Canvas canvas, MascotPose p, BodySwatch sw) {
    final m = PencilRig.mouthCentre;
    if (p.mouthScale == 1) {
      _draw(canvas, p.mouth.part, sw);
      return;
    }
    canvas.save();
    canvas.translate(m.dx, m.dy);
    canvas.scale(p.mouthScale);
    canvas.translate(-m.dx, -m.dy);
    _draw(canvas, p.mouth.part, sw);
    canvas.restore();
  }

  // ------------------------------------------------------------------ accessories
  void _accessory(Canvas canvas, String id, MascotPose p) {
    final y = _accessoryAnchorY[id] ?? 200;
    _bent(canvas, p.lean, Offset(250, y), () {
      canvas.save();
      if (_hats.contains(id)) canvas.translate(0, p.eraserDrop);
      if (id == MascotAccessory.roundGlasses || id == MascotAccessory.starGlasses) canvas.translate(0, p.faceOffset);
      _draw(canvas, 'acc_$id', BodySwatch.yellow);
      canvas.restore();
    });
  }

  // ------------------------------------------------------------------ effects
  void _effects(Canvas canvas, MascotPose p, double time) {
    if (p.zzz > 0.01) {
      for (var i = 0; i < 3; i++) {
        final ph = (time / 2.4 + i / 3) % 1.0;
        final a = p.zzz * (ph < 0.3 ? ph / 0.3 : 1 - (ph - 0.3) / 0.7);
        final c = PencilRig.zzz[i];
        canvas.save();
        canvas.translate(c.dx + 22 * ph, c.dy - 34 * ph);
        canvas.scale(0.7 + 0.45 * ph);
        canvas.translate(-c.dx, -c.dy);
        _draw(canvas, 'fx_z${i + 1}', BodySwatch.yellow, a.clamp(0.0, 1.0));
        canvas.restore();
      }
    }
    if (p.surprise > 0.01) {
      _line
        ..color = MascotColors.effects.withValues(alpha: p.surprise.clamp(0.0, 1.0))
        ..strokeWidth = 5;
      for (final (origin, dir) in [(PencilRig.bandLeftEnd, -1.0), (PencilRig.bandRightEnd, 1.0)]) {
        for (final a in [-0.55, 0.0, 0.55]) {
          final v = Offset(math.cos(a) * dir, math.sin(a));
          final r0 = 14.0, r1 = 14 + 22 * (0.6 + 0.4 * p.surprise);
          canvas.drawLine(origin + v * r0, origin + v * r1, _line);
        }
      }
    }
    if (p.motionLines > 0.01) {
      final flick = 0.6 + 0.4 * math.sin(time * 18).abs();
      _line
        ..color = MascotColors.effects.withValues(alpha: (p.motionLines * flick).clamp(0.0, 1.0))
        ..strokeWidth = 4.5;
      canvas.drawArc(Rect.fromCircle(center: const Offset(120, 360), radius: 72), math.pi * 0.86, math.pi * 0.2, false, _line);
      canvas.drawArc(Rect.fromCircle(center: const Offset(120, 360), radius: 88), math.pi * 0.9, math.pi * 0.14, false, _line);
      canvas.drawArc(Rect.fromCircle(center: const Offset(380, 540), radius: 60), -math.pi * 0.2, math.pi * 0.22, false, _line);
      canvas.drawArc(Rect.fromCircle(center: const Offset(380, 540), radius: 76), -math.pi * 0.16, math.pi * 0.16, false, _line);
    }
  }

  static Offset _rot(Offset v, double a) {
    final c = math.cos(a), s = math.sin(a);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  @override
  bool shouldRepaint(MascotPainter old) => old.controller != controller || old.parts != parts;
}

class _ArmGeo {
  _ArmGeo(this.side, this.s, this.c, this.w, this.tangent, this.lift);
  final int side;
  final Offset s, c, w;
  final double tangent;

  /// 0 hanging .. 1 raised (eased): how straight the underside runs.
  final double lift;
}
