import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../design/tokens.dart';
import '../../../game/monster_smash/ms_engine.dart';
import '../game_ui.dart';
import 'ms_heroes.dart';
import 'ms_scene.dart';

/// Before a level, over the dimmed meadow: a ribbon with the level, a
/// little sky stage with the heroes on a grassy hill (the new hero alone,
/// big, with a NEW badge), the world and its towers, the best stars, and a
/// Play button that breathes.
class MsStartCard extends StatelessWidget {
  const MsStartCard({
    super.key,
    required this.title,
    required this.world,
    required this.heroes,
    required this.time,
    required this.onPlay,
    required this.onBack,
    this.newHero,
    this.meet,
    this.stars,
    this.best = 0,
    this.towers = 0,
  });

  final String title, world;
  final List<MsHero> heroes;
  final MsHero? newHero;

  /// What the new hero does (said by Pencil too).
  final String? meet;

  /// The level's best stars (null: no levels, the best score instead).
  final int? stars;
  final int best, towers;

  /// The screen's clock (the heroes bob, Play breathes).
  final double time;
  final VoidCallback onPlay, onBack;

  static const _stageW = 236.0, _stageH = 214.0, _ribbonH = 58.0;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MonsterColors.veil,
    child: SafeArea(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .8, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: SizedBox(
            width: 590,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: _ribbonH / 2),
                  padding: const EdgeInsets.fromLTRB(14, 40, 18, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [SmashColors.cardTop, SmashColors.cardBottom],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: SmashColors.cardRim, width: 3),
                    boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 12), blurRadius: 28)],
                  ),
                  child: Row(
                    children: [
                      _stage(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: SizedBox(height: _stageH, child: _side()),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(child: _Ribbon(title: title)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  // ------------------------------------------------------------ the stage

  Widget _stage() {
    final shown = newHero != null ? [newHero!] : heroes.toSet().toList();
    final (w, h) = switch (shown.length) {
      1 => (150.0, 150.0),
      2 => (100.0, 120.0),
      _ => (74.0, 104.0),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: _stageW,
        height: _stageH,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _StagePainter(time))),
            Positioned(
              left: 0,
              right: 0,
              bottom: _stageH * .2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    SizedBox(
                      width: w,
                      height: h,
                      child: CustomPaint(painter: _HeroPainter(shown[i], time, i)),
                    ),
                ],
              ),
            ),
            if (newHero != null) Positioned(left: 12, top: 12, child: _NewBadge(time: time)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ the words

  Widget _side() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          children: [
            _Tag(icon: Symbols.flag_rounded, text: world),
            if (towers > 0) ...[const SizedBox(width: 8), _Tag(icon: Symbols.castle_rounded, text: towers == 1 ? '1 tower' : '$towers towers')],
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (stars != null)
        _Stars(stars!)
      else
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              const Icon(Symbols.trophy_rounded, size: 30, fill: 1, color: MonsterColors.gold),
              const SizedBox(width: 6),
              Text(best > 0 ? 'Best: $best' : 'Smash them all!', style: LikhoFonts.title(size: 24, weight: FontWeight.w800)),
            ],
          ),
        ),
      const Spacer(),
      Text(
        meet ?? 'Hit the letter Pencil asks for!',
        key: meet == null ? null : const ValueKey('ms-meet'),
        textAlign: TextAlign.center,
        maxLines: 2,
        style: LikhoFonts.body(size: 16, weight: FontWeight.w800, color: StoryColors.name, height: 1.25),
      ),
      const Spacer(),
      Row(
        children: [
          SizedBox(
            width: 58,
            child: gameButton(key: const ValueKey('ms-back'), label: '', icon: Symbols.arrow_back_rounded, onTap: onBack, main: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Transform.scale(
              scale: 1 + .035 * math.sin(time * 4.2),
              child: gameButton(key: const ValueKey('ms-play'), label: 'Play', icon: Symbols.play_arrow_rounded, onTap: onPlay),
            ),
          ),
        ],
      ),
    ],
  );
}

/// The level on a violet ribbon with folded tails.
class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RibbonPainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(56, 13, 56, 15),
      child: Text(
        title,
        style: LikhoFonts.title(size: 30, weight: FontWeight.w800, color: MonsterColors.ribbonInk).copyWith(
          height: 1,
          shadows: const [Shadow(color: MonsterColors.ribbonDeep, offset: Offset(0, 3))],
        ),
      ),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const tail = 30.0, drop = 10.0, inset = 22.0;
    final deep = Paint()..color = MonsterColors.ribbonDeep;
    // the tails behind, each with a V cut, and the fold where they tuck in
    for (final side in [-1.0, 1.0]) {
      final x = side < 0 ? 0.0 : w;
      final tailPath = Path()
        ..moveTo(x - side * inset, drop)
        ..lineTo(x + side * tail * .6, drop)
        ..lineTo(x + side * (tail * .6 - 12), drop + (h - drop) / 2)
        ..lineTo(x + side * tail * .6, h + drop)
        ..lineTo(x - side * inset, h + drop)
        ..close();
      canvas.drawPath(tailPath, deep);
      final fold = Path()
        ..moveTo(x - side * inset, h)
        ..lineTo(x - side * inset, h + drop)
        ..lineTo(x - side * (inset + 12), h)
        ..close();
      canvas.drawPath(fold, Paint()..color = const Color(0xFF3F2A9E));
    }
    // the band, a little arched
    final band = RRect.fromRectAndRadius(Rect.fromLTRB(inset - 12, 0, w - inset + 12, h), const Radius.circular(10));
    canvas.drawRRect(band.shift(const Offset(0, 4)), Paint()..color = MonsterColors.panelShadow);
    canvas.drawRRect(band, Paint()..color = MonsterColors.ribbon);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(inset - 4, 5, w - inset + 4, 12), const Radius.circular(4)),
      Paint()..color = const Color(0x33FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A soft violet pill: the world, the towers.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: SmashColors.tag, borderRadius: BorderRadius.circular(16)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, fill: 1, color: SmashColors.tagInk),
        const SizedBox(width: 5),
        Text(
          text,
          style: LikhoFonts.body(size: 15, weight: FontWeight.w800, color: SmashColors.tagInk),
        ),
      ],
    ),
  );
}

/// Three stars, the middle one bigger and higher; the ones not won yet are
/// pale.
class _Stars extends StatelessWidget {
  const _Stars(this.won);
  final int won;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 1 ? 10 : 0, left: 3, right: 3),
            child: _star(i < won, i == 1 ? 50 : 40),
          ),
      ],
    ),
  );

  Widget _star(bool on, double size) {
    final img = Image.asset(MsArt.star, width: size, height: size);
    return on ? img : ColorFiltered(colorFilter: const ColorFilter.mode(SmashColors.starOff, BlendMode.srcIn), child: img);
  }
}

/// A pink NEW sticker that wiggles.
class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.time});
  final double time;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.18 + .06 * math.sin(time * 5),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: SmashColors.newBadge,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MonsterColors.ribbonInk, width: 2.5),
        boxShadow: const [BoxShadow(color: SmashColors.newBadgeDeep, offset: Offset(0, 3))],
      ),
      child: Text(
        'NEW!',
        style: LikhoFonts.title(size: 18, weight: FontWeight.w800, color: MonsterColors.ribbonInk).copyWith(height: 1.1),
      ),
    ),
  );
}

/// The stage: a soft sky, the sun's glow, two drifting clouds, a far hill
/// and the grassy hill the heroes stand on.
class _StagePainter extends CustomPainter {
  _StagePainter(this.time);
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SmashColors.stageTop, SmashColors.stageBottom],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      Offset(w * .82, h * .16),
      w * .32,
      Paint()
        ..shader = RadialGradient(colors: const [SmashColors.stageSun, Color(0x00FFF3B0)])
            .createShader(Rect.fromCircle(center: Offset(w * .82, h * .16), radius: w * .32)),
    );
    _cloud(canvas, Offset((w * .22 + time * 6) % (w + 80) - 40, h * .2), 1);
    _cloud(canvas, Offset((w * .7 + time * 4) % (w + 80) - 40, h * .36), .7);
    final far = Path()
      ..moveTo(0, h * .7)
      ..quadraticBezierTo(w * .3, h * .5, w * .62, h * .66)
      ..quadraticBezierTo(w * .85, h * .56, w, h * .62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = SmashColors.hillTop.withValues(alpha: .7));
    // a soft light on the heroes
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * .62), width: w * .9, height: h * .62),
      Paint()
        ..shader = RadialGradient(colors: const [SmashColors.stageSpot, Color(0x00FFFFFF)])
            .createShader(Rect.fromCenter(center: Offset(w / 2, h * .62), width: w * .9, height: h * .62)),
    );
    final top = h * .78;
    final hill = Path()
      ..moveTo(0, top + 10)
      ..quadraticBezierTo(w / 2, top - 16, w, top + 10)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      hill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SmashColors.hillTop, SmashColors.hill],
        ).createShader(Rect.fromLTRB(0, top - 16, w, h)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, top + 10)
        ..quadraticBezierTo(w / 2, top - 16, w, top + 10),
      Paint()
        ..color = SmashColors.hillDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // a few flowers in the grass
    final rnd = math.Random(4);
    for (var i = 0; i < 7; i++) {
      final x = w * (.06 + i * .145) + rnd.nextDouble() * 8;
      final y = h * .9 + rnd.nextDouble() * h * .06;
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = i.isEven ? MonsterColors.ribbonInk : MonsterColors.gem);
      canvas.drawCircle(Offset(x, y), 1.2, Paint()..color = MonsterColors.gold);
    }
  }

  void _cloud(Canvas canvas, Offset at, double k) {
    final p = Paint()..color = SmashColors.stageCloud;
    for (final (dx, dy, r) in [(-14.0, 3.0, 10.0), (0.0, -3.0, 14.0), (15.0, 2.0, 11.0), (2.0, 6.0, 11.0)]) {
      canvas.drawCircle(at + Offset(dx, dy) * k, r * k, p);
    }
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) => old.time != time;
}

/// A hero standing on the stage's hill: a soft shadow, a gentle bob.
class _HeroPainter extends CustomPainter {
  _HeroPainter(this.hero, this.time, this.i);
  final MsHero hero;
  final double time;
  final int i;

  @override
  void paint(Canvas canvas, Size size) {
    final hop = math.max(0.0, math.sin(time * 3.4 + i * 1.3)) * size.height * .05;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width / 2, size.height * .97), width: size.width * (.62 - hop / size.height), height: size.height * .07),
      Paint()..color = MonsterColors.shadow,
    );
    canvas.translate(0, -hop);
    MsHeroArt.portrait(canvas, hero, size, t: time, bottom: true);
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) => old.time != time;
}
