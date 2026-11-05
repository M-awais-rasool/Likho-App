import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

import '../../../design/tokens.dart';
import '../../../game/monster_smash/ms_engine.dart';
import 'ms_camera.dart';
import 'ms_crystal_art.dart';
import 'ms_heroes.dart';
import 'ms_monsters.dart';
import 'ms_scene.dart';

/// A hero to draw: where (world), how big (world radius), how it looks.
class MsHeroSprite {
  const MsHeroSprite(this.hero, this.at, this.radius, this.look);
  final MsHero hero;
  final Vector2 at;
  final double radius;
  final MsHeroLook look;
}

/// Paints the world as the camera sees it: the hill with the heroes waiting
/// in line, the slingshot with the hero in its leather pouch, the blocks
/// with their letters and cracks, the monsters, the heroes in the air with
/// their trails, and the aiming dots while the child pulls. [shift] slides
/// the whole room sideways (walking to the next room).
class MsWorldPainter extends CustomPainter {
  MsWorldPainter({
    required this.view,
    required this.camera,
    required this.game,
    required this.lives,
    required this.line,
    required this.sling,
    required this.flying,
    required this.time,
    this.shift = 0,
    this.popIn = true,
  });
  final MsView view;
  final MsCamera camera;
  final MsGame game;
  final MsMonsterLives lives;

  /// The heroes waiting, the one in the slingshot (null: the band is
  /// empty), and those flying or resting where they stopped.
  final List<MsHeroSprite> line, flying;
  final MsHeroSprite? sling;

  /// Sideways (base pixels), and whether a room's blocks pop in as it is
  /// built (the first room; the next ones walk in).
  final double shift;
  final bool popIn;

  /// The screen's clock (glows, arrows); the monsters use the game's.
  final double time;

  static final _letters = <String, TextPainter>{};

  /// The launcher's height and centre in world metres.
  static const slingHeight = 1.7;
  static double get slingX => MsGame.rest.x;

  double get _ppm => view.ppm;

  /// Where the ball above the screen is shown (under the top bar).
  static const _markY = 96.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    camera.transform(canvas);
    canvas.translate(shift, 0);
    _hill(canvas);
    for (final h in line.reversed) {
      _hero(canvas, h);
    }
    final tips = _sling(canvas);
    final s = sling;
    final pull = game.pull;
    if (s == null) {
      // an empty band hangs between the fork's tips, the pouch in the middle
      _emptyBand(canvas, tips.$1, tips.$2);
    } else {
      // both strands to the leather pouch cupping the hero's back, the
      // hero on top (a long crayon never gets a strand across it)
      final at = view.of(s.at);
      final d = pull == null || pull.length < 1e-3 ? const Offset(1, 0) : Offset(-pull.x, pull.y) / pull.length;
      _band(canvas, tips.$1, at - d * (s.radius * _ppm * .6));
      _band(canvas, tips.$2, at - d * (s.radius * _ppm * .6), front: true);
      _pouch(canvas, at, d, s.radius * _ppm);
      _hero(canvas, s);
    }
    for (final b in game.blocks) {
      if (!b.gone) _block(canvas, b);
    }
    for (final m in game.monsters) {
      _monster(canvas, m);
    }
    _trails(canvas);
    for (final h in flying) {
      _hero(canvas, h);
    }
    if (pull != null && pull.length > MsGame.minPull * .6) _aim(canvas, pull);
    canvas.restore();
    _offscreen(canvas);
  }

  void _hero(Canvas canvas, MsHeroSprite h) => MsHeroArt.paint(canvas, h.hero, view.of(h.at), h.radius * _ppm, h.look);

  /// How far the build of a tower has come for thing [i] (0 hidden, 1 in).
  double _pop(int i) {
    if (game.phase != MsPhase.build || !popIn) return 1;
    final t = ((game.phaseTime - .15 - i * .05) / .4).clamp(0.0, 1.0);
    return Curves.elasticOut.transform(t);
  }

  // ------------------------------------------------------------ the launch platform

  void _hill(Canvas canvas) {
    final a = view.at(MsGame.hillX - MsGame.hillHalfTop, MsGame.hillTop);
    final b = view.at(MsGame.hillX + MsGame.hillHalfTop, MsGame.hillTop);
    final left = view.at(MsGame.hillX - MsGame.hillHalfFoot, 0);
    final right = view.at(MsGame.hillX + MsGame.hillHalfFoot, 0);
    final side = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(side, Paint()..shader = ui.Gradient.linear(a, right, const [Color(0xFFD5BCEE), Color(0xFF8571C1)]));
    for (var i = 0; i < 5; i++) {
      final x = left.dx + (right.dx - left.dx) * i / 5;
      canvas.drawPath(
        Path()
          ..moveTo(x, left.dy)
          ..lineTo(x + _ppm * .7, a.dy + 8)
          ..lineTo(x + _ppm * .95, left.dy)
          ..close(),
        Paint()..color = const Color(0x2876DAD7),
      );
    }
    final cap = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx + _ppm * .15, b.dy + 10)
      ..lineTo(a.dx - _ppm * .15, a.dy + 10)
      ..close();
    canvas.drawPath(cap, Paint()..shader = ui.Gradient.linear(a, a + const Offset(0, 10), const [Color(0xFFFFF5DC), Color(0xFFE7CD9F)]));
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 2,
    );
    // A turquoise crystal in the platform face.
    final gem = Offset((a.dx + b.dx) / 2, a.dy + _ppm * .45);
    final r = _ppm * .18;
    canvas.drawPath(
      Path()
        ..moveTo(gem.dx, gem.dy - r)
        ..lineTo(gem.dx + r, gem.dy)
        ..lineTo(gem.dx, gem.dy + r)
        ..lineTo(gem.dx - r, gem.dy)
        ..close(),
      Paint()..shader = ui.Gradient.linear(gem - Offset(r, r), gem + Offset(r, r), const [Color(0xFFD2FFFF), Color(0xFF55C8C9)]),
    );
  }

  /// The launcher is drawn around the same fork tips used by the elastic.
  (Offset, Offset) _sling(Canvas canvas) {
    final at = view.of(MsGame.rest);
    final a = at + Offset(-.55 * _ppm, 0), b = at + Offset(.55 * _ppm, 0);
    final join = at + Offset(0, .85 * _ppm), foot = at + Offset(0, 1.44 * _ppm);
    final fork = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(a.dx, join.dy - .2 * _ppm, join.dx, join.dy)
      ..quadraticBezierTo(b.dx, join.dy - .2 * _ppm, b.dx, b.dy);
    final stem = Path()
      ..moveTo(join.dx, join.dy - .1 * _ppm)
      ..lineTo(foot.dx, foot.dy);
    final bounds = Rect.fromPoints(a - Offset(.12 * _ppm, .1 * _ppm), foot + Offset(.6 * _ppm, .12 * _ppm));
    for (final path in [stem, fork]) {
      canvas.drawPath(
        path.shift(const Offset(0, 3)),
        Paint()
          ..color = const Color(0x60594A80)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = .27 * _ppm,
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, const [Color(0xFFFFE5A3), Color(0xFFBE824D)])
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = .23 * _ppm,
      );
      canvas.drawPath(
        path.shift(Offset(-.035 * _ppm, -1)),
        Paint()
          ..color = const Color(0x99FFF5D8)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = .055 * _ppm,
      );
    }
    for (final p in [a, b]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: .28 * _ppm, height: .18 * _ppm), Radius.circular(.06 * _ppm)),
        Paint()..shader = ui.Gradient.linear(p - Offset(0, 6), p + Offset(0, 6), const [Color(0xFFA6EFEB), Color(0xFF438FAD)]),
      );
    }
    canvas.drawCircle(join + Offset(0, .1 * _ppm), .13 * _ppm, Paint()..color = const Color(0xFF5EBFCE));
    canvas.drawCircle(join + Offset(-.03 * _ppm, .07 * _ppm), .05 * _ppm, Paint()..color = const Color(0xFFDBFFFF));
    return (a, b);
  }

  /// A strand of the rubber band from the fork's [tip] to the ball at [ball].
  void _band(Canvas canvas, Offset tip, Offset ball, {bool front = false}) {
    final stretch = ((ball - view.of(MsGame.rest)).distance / (MsGame.maxPull * _ppm)).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = front ? SmashColors.band : SmashColors.bandBack
      ..strokeWidth = (.15 - .06 * stretch) * _ppm
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tip, ball, paint);
  }

  /// The leather pouch behind the ball ([dir]: where it flies, on the
  /// screen).
  void _pouch(Canvas canvas, Offset ball, Offset dir, double r) {
    canvas.save();
    canvas.translate(ball.dx - dir.dx * r * .75, ball.dy - dir.dy * r * .75);
    canvas.rotate(math.atan2(dir.dy, dir.dx));
    final cup = Rect.fromCenter(center: Offset.zero, width: r * .8, height: r * 1.6);
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
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: mid, width: .34 * _ppm, height: .16 * _ppm), Radius.circular(.08 * _ppm)), Paint()..color = SmashColors.pouch);
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
    _material(canvas, b.shape, b.material, rect);
    if (b.damage > .25) _cracks(canvas, b, rect);
    if (b.letter != null) {
      final tp = _letter(b.letter!, b.material, rect.height * .7);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 - rect.height * .02));
    }
    canvas.restore();
    if (game.hintBlock == b.id) _arrow(canvas, c - Offset(0, rect.height * .5 + 18 * _ppm / 58));
  }

  /// Bevelled materials share the exact shapes of their physics fixtures.
  void _material(Canvas canvas, MsShape shape, MsMaterial material, Rect rect) {
    final colors = switch (material) {
      MsMaterial.wood => const [Color(0xFFFFD99B), Color(0xFFE0A258), Color(0xFFB87940)],
      MsMaterial.ice => const [Color(0xFFE2FFFF), Color(0xFF7DD9E5), Color(0xFF409EBB)],
      MsMaterial.stone => const [Color(0xFFE9DDF6), Color(0xFFB19BCD), Color(0xFF82749F)],
    };
    final radius = math.min(rect.shortestSide * .14, 8.0);
    final path = Path();
    if (shape == MsShape.disc) {
      path.addOval(rect);
    } else if (shape == MsShape.triangle) {
      path
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.center.dx, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..close();
    } else {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }
    canvas.drawPath(path.shift(const Offset(0, 2)), Paint()..color = const Color(0x50524378));
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, colors, const [0, .5, 1]));
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.last
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.save();
    canvas.clipPath(path);
    if (shape == MsShape.square || shape == MsShape.plank) {
      final inset = rect.deflate(3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inset, Radius.circular(math.max(1, radius - 2))),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        rect.topLeft + const Offset(6, 3),
        rect.topRight + const Offset(-6, 3),
        Paint()
          ..color = const Color(0xBBFFFFFF)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    if (material == MsMaterial.ice) {
      canvas.drawPath(
        Path()
          ..moveTo(rect.left + rect.width * .12, rect.bottom)
          ..lineTo(rect.left + rect.width * .48, rect.top)
          ..lineTo(rect.left + rect.width * .64, rect.top)
          ..lineTo(rect.left + rect.width * .28, rect.bottom)
          ..close(),
        Paint()..color = const Color(0x44FFFFFF),
      );
    } else if (material == MsMaterial.wood) {
      for (var i = 0; i < 2; i++) {
        final y = rect.top + rect.height * (.24 + i * .5);
        canvas.drawPath(
          Path()
            ..moveTo(rect.left + 5, y)
            ..cubicTo(rect.center.dx, y - 3, rect.center.dx, y + 3, rect.right - 5, y),
          Paint()
            ..color = const Color(0x22A26338)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close(),
        Paint()..color = const Color(0x1073549E),
      );
    }
    canvas.restore();
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
    final image = MsSprites.of(MsArt.crystalMonsters);
    if (image == null) return;
    final src = MsCrystalArt.monster(m.kind, look.pose);
    final scale = _ppm * 1.08 / src.height;
    final width = src.width * scale, height = src.height * scale;
    final c = view.of(m.position);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-m.angle);
    // its feet on the body's bottom; hops on top
    canvas.translate(0, (MsSize.monster - look.hop) * _ppm);
    canvas.rotate(look.turn);
    canvas.scale(pop * look.scaleX, pop * look.scaleY);
    final dst = Rect.fromLTWH(-width / 2, -height, width, height);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.high);
    if (look.dizzy > 0) _dizzy(canvas, look.dizzy, -height * .95);
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

  // ------------------------------------------------------------ the heroes in the air

  void _trails(Canvas canvas) {
    for (final s in game.shots) {
      final n = s.trail.length;
      for (var i = 0; i < n - 1; i++) {
        final k = (i + 1) / n;
        canvas.drawCircle(view.of(s.trail[i]), (2 + 5 * k) * _ppm / 58 * (s.drop ? .7 : 1), Paint()..color = SmashColors.trail.withValues(alpha: .15 + .45 * k));
      }
    }
  }

  /// A hero above the screen: a little one on the top edge shows where.
  void _offscreen(Canvas canvas) {
    final s = game.shot;
    if (s == null || s.gone) return;
    final at = camera.apply(view.of(s.body.position) + Offset(shift, 0));
    if (at.dy > -s.radius * _ppm) return;
    final x = at.dx.clamp(20.0, view.screen.width - 20);
    final far = (-at.dy / view.screen.height).clamp(0.0, 1.0);
    canvas.drawCircle(Offset(x, _markY), 20 - 6 * far, Paint()..color = MonsterColors.panel);
    MsHeroArt.paint(canvas, s.hero, Offset(x, _markY), 13 - 4 * far, const MsHeroLook(face: MsFace.yell));
    final up = Path()
      ..moveTo(x, _markY - 34)
      ..lineTo(x - 8, _markY - 24)
      ..lineTo(x + 8, _markY - 24)
      ..close();
    canvas.drawPath(up, Paint()..color = MonsterColors.panel);
  }

  /// Where the hero will go: dots along its path, smaller further on.
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
