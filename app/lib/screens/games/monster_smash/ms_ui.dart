import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../design/tokens.dart';
import '../../../game/monster_smash/ms_engine.dart';
import '../game_ui.dart';
import 'ms_heroes.dart';

abstract final class MsPalette {
  static const ink = Color(0xFF4E4075);
  static const violet = Color(0xFF8560CB);
  static const lilac = Color(0xFFE7DDF7);
  static const cream = Color(0xFFFFFBF0);
  static const teal = Color(0xFF4CAFAF);
  static const gold = Color(0xFFFFD477);
  static const shadow = Color(0x30594791);
  static const veil = Color(0x7852457C);

  static BoxDecoration panel({double radius = 18, bool selected = false}) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: selected ? const [Color(0xFFFFF5D6), Color(0xFFFFE5A9)] : const [Color(0xFFFFFEF8), Color(0xFFF5EFFC)],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: selected ? gold : const Color(0xFFE4D7F5), width: 2),
    boxShadow: [BoxShadow(color: selected ? const Color(0x657B5B9C) : shadow, offset: const Offset(0, 4), blurRadius: 10)],
  );
}

class MsPanel extends StatelessWidget {
  const MsPanel({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(padding: padding, decoration: MsPalette.panel(), child: child);
}

/// Named, generously cropped portraits make the next hero easy to recognise.
class MsHeroCard extends StatelessWidget {
  const MsHeroCard({super.key, required this.hero, required this.selected, required this.available, required this.time, required this.onTap});
  final MsHero hero;
  final bool selected, available;
  final double time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = switch (hero) {
      MsHero.rubby => 'Rubby',
      MsHero.inky => 'Inky',
      MsHero.crayo => 'Crayo',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$name${selected ? ", ready to launch" : ", choose hero"}',
      child: GestureDetector(
        onTap: available ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 66 : 58,
          height: selected ? 80 : 72,
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 4),
          decoration: MsPalette.panel(radius: 17, selected: selected),
          child: Column(
            children: [
              Expanded(
                child: SizedBox.expand(child: CustomPaint(painter: MsHeroPortrait(hero, time))),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  style: LikhoFonts.body(size: 11, weight: FontWeight.w800, color: MsPalette.ink, height: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MsHeroPortrait extends CustomPainter {
  MsHeroPortrait(this.hero, this.time, {this.face = MsFace.idle});
  final MsHero hero;
  final double time;
  final MsFace face;

  @override
  void paint(Canvas canvas, Size size) => MsHeroArt.portrait(canvas, hero, size, t: time, face: face);

  @override
  bool shouldRepaint(covariant MsHeroPortrait old) => old.hero != hero || old.time != time || old.face != face;
}

class MsPauseCard extends StatelessWidget {
  const MsPauseCard({super.key, required this.hero, required this.onResume, required this.onExit});
  final MsHero hero;
  final VoidCallback onResume, onExit;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MsPalette.veil,
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(24),
              decoration: MsPalette.panel(radius: 30),
              child: Row(
                children: [
                  SizedBox(
                    width: 128,
                    height: 168,
                    child: CustomPaint(painter: MsHeroPortrait(hero, 0, face: MsFace.happy)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Paused',
                          textAlign: TextAlign.center,
                          style: LikhoFonts.title(size: 25, weight: FontWeight.w800, color: MsPalette.ink),
                        ),
                        const SizedBox(height: 18),
                        gameButton(key: const ValueKey('ms-resume'), label: 'Keep playing', icon: Symbols.play_arrow_rounded, onTap: onResume),
                        const SizedBox(height: 12),
                        gameButton(key: const ValueKey('ms-exit'), label: 'Levels', icon: Symbols.apps_rounded, onTap: onExit, main: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
