import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

import '../../../design/tokens.dart';
import '../../../game/monster_smash/ms_engine.dart';
import 'ms_monsters.dart';
import 'ms_scene.dart';

/// Paints the world: the hill, the slingshot with the ball in its leather
/// pouch, the blocks with their letters and cracks, the monsters, the ball
/// and its trail, and the aiming dots while the child pulls.
class MsWorldPainter extends CustomPainter {
  MsWorldPainter({required this.view, required this.game, required this.lives, required this.ballIn, required this.time});
  final MsView view;
  final MsGame game;
  final MsMonsterLives lives;

  /// How far the next ball has dropped into the pouch (0 just now, 1 in).
  final double ballIn;

  /// The screen's clock (glows, arrows); the monsters use the game's.
  final double time;

  static final _letters = <String, TextPainter>{};

  /// The slingshot: its height, the middle of its stick, the tips of its
  /// fork (measured from the picture).
  static const slingHeight = 1.7;
  static double get slingX => MsGame.rest.x;
  static const _tipX = .41, _tipY = .06;

  double get _ppm => view.ppm;

  /// Where the ball above the screen is shown (under the top bar).
  static const _markY = 96.0;

  @override
  void paint(Canvas canvas, Size size) {
    _hill(canvas);
    final sling = _sling(canvas);
    final loaded = game.phase == MsPhase.aim && game.balls.isNotEmpty;
    final ball = loaded ? view.of(game.ballInSling) : null;
    if (ball == null) {
      // an empty band hangs between the fork's tips, the pouch in the middle
      _emptyBand(canvas, sling.$1, sling.$2);
    } else {
      // the back strand, the leather pouch cupping the ball's back, the ball
      // (dropping in with a little bounce), the front strand
      final pull = game.pull;
      final d = pull == null || pull.length < 1e-3 ? const Offset(1, 0) : Offset(-pull.x, pull.y) / pull.length;
      _band(canvas, sling.$1, ball);
      _pouch(canvas, ball, d);
      final drop = 1 - Curves.easeOutBack.transform(ballIn);
      _ball(canvas, game.balls.first, ball - Offset(0, drop * .9 * _ppm), 0, .6 + .4 * Curves.easeOut.transform(ballIn));
      _band(canvas, sling.$2, ball, front: true);
    }
    for (final b in game.blocks) {
      if (!b.gone) _block(canvas, b);
    }
    for (final m in game.monsters) {
      _monster(canvas, m);
    }
    _shot(canvas);
    if (game.pull != null && game.pull!.length > MsGame.minPull * .6) _aim(canvas, game.pull!);
  }

  /// How far the build of a tower has come for thing [i] (0 hidden, 1 in).
  double _pop(int i) {
    if (game.phase != MsPhase.build) return 1;
    final t = ((game.phaseTime - .15 - i * .05) / .4).clamp(0.0, 1.0);
    return Curves.elasticOut.transform(t);
  }

  void _image(Canvas canvas, String asset, Rect dst, {double alpha = 1}) {
    final img = MsSprites.of(asset);
    if (img == null) return;
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(0, 0, 0, alpha);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, paint);
  }

  /// [img]'s size on the screen for a height of [h] metres.
  Size _sized(ui.Image img, double h) => Size(h * _ppm * img.width / img.height, h * _ppm);

  // ------------------------------------------------------------ the slingshot's side

  void _hill(Canvas canvas) {
    final img = MsSprites.of(MsArt.hill);
    if (img == null) return;
    // its flat top (a fifth down the picture) on the hill's top
    const w = 4.0;
    final h = w * img.height / img.width;
    final top = view.at(MsGame.hillX - w / 2, MsGame.hillTop + h * .2);
    _image(canvas, MsArt.hill, Rect.fromLTWH(top.dx, top.dy, w * _ppm, h * _ppm));
  }

  /// Draws the slingshot; returns the tips of its fork (back, front).
  (Offset, Offset) _sling(Canvas canvas) {
    final img = MsSprites.of(MsArt.sling);
    final w = img == null ? slingHeight * .785 : slingHeight * img.width / img.height;
    final top = MsGame.rest.y + .1;
    final rect = Rect.fromLTWH((slingX - w / 2) * _ppm, view.at(0, top).dy, w * _ppm, slingHeight * _ppm);
    _image(canvas, MsArt.sling, rect);
    final tipY = rect.top + rect.height * _tipY;
    return (Offset(rect.center.dx - _tipX * rect.width, tipY), Offset(rect.center.dx + _tipX * rect.width, tipY));
  }

  /// A strand of the rubber band from the fork's [tip] to the ball at [ball].
  void _band(Canvas canvas, Offset tip, Offset ball, {bool front = false}) {
    final stretch = ((ball - view.of(MsGame.rest)).distance / (MsGame.maxPull * _ppm)).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = front ? SmashColors.band : SmashColors.bandBack
      ..strokeWidth = (.15 - .06 * stretch) * _ppm
      ..strokeCap = StrokeCap.round;
    // the back strand runs on behind the ball to the pouch (the ball covers
    // it); the front one stops at the ball's edge, never across its face
    final r = MsGame.ballRadius[MsBall.eraser]! * _ppm * .8;
    final dir = ball - tip;
    if (dir.distance < r) return;
    final end = ball + dir / dir.distance * (front ? -r : r);
    canvas.drawLine(tip, end, paint);
  }

  /// The leather pouch behind the ball ([dir]: where it flies, on the
  /// screen).
  void _pouch(Canvas canvas, Offset ball, Offset dir) {
    final r = MsGame.ballRadius[MsBall.eraser]! * _ppm;
    canvas.save();
    canvas.translate(ball.dx - dir.dx * r * .7, ball.dy - dir.dy * r * .7);
    canvas.rotate(math.atan2(dir.dy, dir.dx));
    final cup = Rect.fromCenter(center: Offset.zero, width: r * 1.1, height: r * 2.1);
    canvas.drawOval(cup, Paint()..color = SmashColors.pouch);
    canvas.drawOval(
      cup,
      Paint()
        ..color = SmashColors.bandBack
        ..style = PaintingStyle.stroke
        ..strokeWidth = .03 * _ppm,
    );
    canvas.restore();
  }

  /// The band with no ball: two strands sagging a little to the leather
  /// pouch between the tips.
  void _emptyBand(Canvas canvas, Offset a, Offset b) {
    final mid = Offset.lerp(a, b, .5)! + Offset(0, .1 * _ppm);
    final w = .15 * _ppm;
    final back = Paint()
      ..color = SmashColors.bandBack
      ..strokeWidth = w * .6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, mid, back);
    canvas.drawLine(mid, b, back..color = SmashColors.band);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: mid, width: .34 * _ppm, height: .16 * _ppm), Radius.circular(.08 * _ppm)),
      Paint()..color = SmashColors.pouch,
    );
  }

  // ------------------------------------------------------------ the towers

  void _block(Canvas canvas, MsBlock b) {
    final pop = _pop(b.id);
    if (pop <= 0) return;
    final (w, h) = switch (b.shape) {
      MsShape.square => (MsSize.square, MsSize.square),
      MsShape.plank => (MsSize.plankW, MsSize.plankH),
      MsShape.triangle => (MsSize.triW, MsSize.triH),
      MsShape.disc => (MsSize.disc * 2, MsSize.disc * 2),
    };
    final c = view.of(b.position);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-b.angle);
    canvas.scale(pop);
    // a little bigger than the body, for the art's outline
    final rect = Rect.fromCenter(center: Offset.zero, width: w * _ppm * 1.03, height: h * _ppm * 1.03);
    if (game.hintBlock == b.id) _glow(canvas, rect);
    _image(canvas, MsArt.block(b.shape, b.material), rect);
    if (b.damage > .25) _cracks(canvas, b, rect);
    if (b.letter != null) {
      final tp = _letter(b.letter!, b.material, rect.height * .7);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 - rect.height * .02));
    }
    canvas.restore();
    if (game.hintBlock == b.id) _arrow(canvas, c - Offset(0, rect.height * .5 + 18 * _ppm / 58));
  }

  TextPainter _letter(String l, MsMaterial m, double size) {
    final key = '$l ${m.name} ${size.round()}';
    return _letters.putIfAbsent(key, () {
      final ink = switch (m) {
        MsMaterial.wood => SmashColors.woodInk,
        MsMaterial.ice => SmashColors.iceInk,
        MsMaterial.stone => SmashColors.stoneInk,
      };
      return TextPainter(
        text: TextSpan(
          text: l,
          style: LikhoFonts.letter(size: size, color: ink).copyWith(height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Cracks across a block that took knocks, more of them the more broken.
  void _cracks(Canvas canvas, MsBlock b, Rect r) {
    final rnd = math.Random(b.id * 31 + 7);
    final n = b.damage > .6 ? 3 : 2;
    final paint = Paint()
      ..color = SmashColors.crack.withValues(alpha: (.4 + b.damage * .6).clamp(0.0, 1.0))
      ..strokeWidth = 2.2 * _ppm / 58
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (var k = 0; k < n; k++) {
      final path = Path();
      var p = Offset(r.left + r.width * (.2 + rnd.nextDouble() * .6), r.top + r.height * (.1 + rnd.nextDouble() * .3));
      path.moveTo(p.dx, p.dy);
      for (var s = 0; s < 4; s++) {
        p += Offset((rnd.nextDouble() - .5) * r.width * .3, r.height * (.12 + rnd.nextDouble() * .1));
        path.lineTo(p.dx.clamp(r.left + 3, r.right - 3), p.dy.clamp(r.top + 3, r.bottom - 3));
      }
      canvas.drawPath(path, paint);
    }
  }

  /// The block Pencil points at after misses: it glows.
  void _glow(Canvas canvas, Rect r) {
    final k = .5 + .5 * math.sin(time * 7);
    final glow = Paint()
      ..color = MonsterColors.hintGlow.withValues(alpha: .45 + .4 * k)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 6 * k);
    canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(8 + 4 * k), Radius.circular(r.shortestSide * .25)), glow);
  }

  /// A bouncing arrow over the hinted block.
  void _arrow(Canvas canvas, Offset tip) {
    final bob = math.sin(time * 6).abs() * 10;
    final s = 22 * _ppm / 58;
    final t = tip - Offset(0, bob);
    final path = Path()
      ..moveTo(t.dx, t.dy)
      ..lineTo(t.dx - s, t.dy - s)
      ..lineTo(t.dx - s * .4, t.dy - s)
      ..lineTo(t.dx - s * .4, t.dy - s * 2)
      ..lineTo(t.dx + s * .4, t.dy - s * 2)
      ..lineTo(t.dx + s * .4, t.dy - s)
      ..lineTo(t.dx + s, t.dy - s)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = MonsterColors.panelShadow);
    canvas.drawPath(path, Paint()..color = MonsterColors.gold);
    canvas.drawPath(
      path,
      Paint()
        ..color = MonsterColors.goldDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  // ------------------------------------------------------------ the monsters

  void _monster(Canvas canvas, MsMonster m) {
    final pop = _pop(game.blocks.length + m.id);
    if (pop <= 0) return;
    final look = MsMonsterLook.of(m, lives.of(m), game.time);
    final asset = MsArt.monster(m.kind, look.pose);
    final img = MsSprites.of(asset);
    if (img == null) return;
    final box = MsArt.monsterBox(asset);
    // the monster is a little taller than its body (ears, arms)
    const tall = 1.0;
    final s = _sized(img, tall / box.height);
    final c = view.of(m.position);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-m.angle);
    // its feet on the body's bottom; hops on top
    canvas.translate(0, (MsSize.monster - look.hop) * _ppm);
    canvas.rotate(look.turn);
    canvas.scale(pop * look.scaleX, pop * look.scaleY);
    final dst = Rect.fromLTWH(-box.center.dx * s.width, -box.bottom * s.height, s.width, s.height);
    _image(canvas, asset, dst);
    if (look.dizzy > 0) _dizzy(canvas, look.dizzy, -box.height * s.height * .95);
    canvas.restore();
  }

  /// Little stars going round a knocked monster's head.
  void _dizzy(Canvas canvas, double t, double top) {
    final fade = (1 - (t - .7) / .3).clamp(0.0, 1.0);
    final r = .32 * _ppm;
    for (var k = 0; k < 3; k++) {
      final a = t * 9 + k * 2 * math.pi / 3;
      final at = Offset(math.cos(a) * r, top + math.sin(a) * r * .32);
      final size = (.09 + .03 * math.sin(a)) * _ppm;
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? size : size * .45;
        final aa = -math.pi / 2 + i * math.pi / 5;
        final p = at + Offset(math.cos(aa) * rr, math.sin(aa) * rr);
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      star.close();
      canvas.drawPath(star, Paint()..color = MonsterColors.gold.withValues(alpha: fade));
      canvas.drawPath(
        star,
        Paint()
          ..color = MonsterColors.goldDeep.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  // ------------------------------------------------------------ the ball

  void _ball(Canvas canvas, MsBall kind, Offset at, double angle, double scale) {
    final r = MsGame.ballRadius[kind]! * _ppm * scale;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-angle);
    // the glow of the star ball is outside its circle
    final k = kind == MsBall.star ? 1.25 : 1.05;
    _image(canvas, MsArt.ball(kind), Rect.fromCenter(center: Offset.zero, width: r * 2 * k, height: r * 2 * k));
    canvas.restore();
  }

  void _shot(Canvas canvas) {
    final s = game.shot;
    if (s == null || s.gone) return;
    final n = s.trail.length;
    for (var i = 0; i < n - 1; i++) {
      final k = (i + 1) / n;
      canvas.drawCircle(view.of(s.trail[i]), (2 + 5 * k) * _ppm / 58, Paint()..color = SmashColors.trail.withValues(alpha: .15 + .45 * k));
    }
    final at = view.of(s.body.position);
    _ball(canvas, s.kind, at, s.body.angle, 1);
    // above the screen: a little ball on the top edge shows where it is
    if (at.dy < -MsGame.ballRadius[s.kind]! * _ppm) {
      final x = at.dx.clamp(20.0, view.screen.width - 20);
      final far = (-at.dy / view.screen.height).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x, _markY), 20 - 6 * far, Paint()..color = MonsterColors.panel);
      _ball(canvas, s.kind, Offset(x, _markY), s.body.angle, .55 - .2 * far);
      final up = Path()
        ..moveTo(x, _markY - 34)
        ..lineTo(x - 8, _markY - 24)
        ..lineTo(x + 8, _markY - 24)
        ..close();
      canvas.drawPath(up, Paint()..color = MonsterColors.panel);
    }
  }

  /// Where the ball will go: dots along its path, smaller further on.
  void _aim(Canvas canvas, Vector2 pull) {
    final dots = MsGame.path(pull);
    for (var i = 0; i < dots.length; i++) {
      final p = view.of(dots[i]);
      final r = (6.5 - i * .25).clamp(2.5, 7.0) * _ppm / 58;
      canvas.drawCircle(p + const Offset(0, 1.5), r, Paint()..color = MonsterColors.panelShadow);
      canvas.drawCircle(p, r, Paint()..color = SmashColors.aim);
    }
  }

  @override
  bool shouldRepaint(covariant MsWorldPainter old) => true;
}
