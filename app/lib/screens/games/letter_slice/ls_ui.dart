import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../design/tokens.dart';
import '../../../game/letter_slice/ls_engine.dart';
import '../../gameplay/widgets/game_buttons.dart';
import 'ls_art.dart';
import 'ls_theme.dart';

class LsAction extends StatelessWidget {
  const LsAction({super.key, required this.label, required this.icon, required this.onTap, this.secondary = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool secondary;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: PushButton(
      onTap: onTap,
      color: secondary ? LsTheme.mint : LsTheme.coral,
      edgeColor: secondary ? LsTheme.line : LsTheme.coralDeep,
      edge: secondary ? 2 : 5,
      height: 58,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      innerHighlight: !secondary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25, fill: 1, color: secondary ? LsTheme.ink : Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LikhoFonts.title(size: 21, weight: FontWeight.w800, color: secondary ? LsTheme.ink : Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LsIconButton extends StatelessWidget {
  const LsIconButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: label,
      child: PushButton(
        onTap: onTap,
        color: LsTheme.cream,
        width: 50,
        height: 50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        edgeColor: LsTheme.line,
        edge: 3,
        child: Icon(icon, color: LsTheme.ink, size: 26, fill: 1),
      ),
    ),
  );
}

class LsMenu extends StatelessWidget {
  const LsMenu({super.key, required this.children, this.shade = true});
  final List<Widget> children;
  final bool shade;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360 || MediaQuery.sizeOf(context).height < 740;
    return ColoredBox(
      color: shade ? LsTheme.ink.withValues(alpha: .24) : Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 22, vertical: compact ? 12 : 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: EdgeInsets.all(compact ? 18 : 24),
              decoration: LsTheme.panel(radius: 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

class LsStartCard extends StatelessWidget {
  const LsStartCard({super.key, required this.hint, required this.best, required this.onPlay, required this.onBack});
  final String hint;
  final int best;
  final VoidCallback onPlay, onBack;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360 || MediaQuery.sizeOf(context).height < 740;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 64),
          child: LsMenu(
            shade: false,
            children: [
              if (!compact) ...[
                Text(
                  'A LITTLE FRUIT. A LOT OF FUN.',
                  textAlign: TextAlign.center,
                  style: LikhoFonts.body(size: 11, weight: FontWeight.w900, color: LsTheme.teal).copyWith(letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                height: compact ? 90 : 158,
                child: const FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(width: 300, height: 158, child: _FruitBunch()),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Letter Slice',
                  style: LikhoFonts.title(size: compact ? 34 : 38, weight: FontWeight.w800, color: LsTheme.ink),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: LikhoFonts.body(size: compact ? 13 : 15, weight: FontWeight.w700, color: LsTheme.muted, height: 1.4),
              ),
              SizedBox(height: compact ? 14 : 22),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Powerup(art: 'star', label: '+50 points'),
                  _Powerup(art: 'berry', label: 'Slow time'),
                  _Powerup(art: 'banana', label: 'Fruit party'),
                ],
              ),
              SizedBox(height: compact ? 18 : 24),
              LsAction(key: const ValueKey('ls-play'), label: 'Let’s play!', icon: Symbols.play_arrow_rounded, onTap: onPlay),
              if (best > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Your best: $best',
                  style: LikhoFonts.body(size: 14, weight: FontWeight.w800, color: LsTheme.muted),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 10,
          left: MediaQuery.paddingOf(context).left + 16,
          child: LsIconButton(key: const ValueKey('ls-back'), icon: Symbols.arrow_back_rounded, label: 'Back to games', onTap: onBack),
        ),
      ],
    );
  }
}

class _FruitBunch extends StatelessWidget {
  const _FruitBunch();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Container(
              width: 180,
              height: 138,
              decoration: const BoxDecoration(color: LsTheme.mint, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: w / 2 - 132,
            top: 42,
            child: const LsFruitPicture(art: 'orange', letter: 'A', size: 100, angle: -.2),
          ),
          Positioned(
            left: w / 2 + 31,
            top: 34,
            child: const LsFruitPicture(art: 'plum', letter: 'C', size: 102, angle: .2),
          ),
          Positioned(
            left: w / 2 - 63,
            top: 4,
            child: const LsFruitPicture(letter: 'B', size: 126, angle: -.08),
          ),
          Positioned(
            left: w / 2 - 96,
            top: 12,
            child: const Icon(Symbols.auto_awesome_rounded, color: LsTheme.gold, size: 22, fill: 1),
          ),
          Positioned(
            left: w / 2 + 81,
            top: 4,
            child: const Icon(Symbols.auto_awesome_rounded, color: LsTheme.coral, size: 16, fill: 1),
          ),
        ],
      );
    },
  );
}

class _Powerup extends StatelessWidget {
  const _Powerup({required this.art, required this.label});
  final String art, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          LsFruitPicture(art: art, size: 40),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: LikhoFonts.body(size: 11, weight: FontWeight.w800, color: LsTheme.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class LsPauseCard extends StatelessWidget {
  const LsPauseCard({super.key, required this.onResume, required this.onExit});
  final VoidCallback onResume, onExit;
  @override
  Widget build(BuildContext context) => LsMenu(
    children: [
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(color: LsTheme.mint, borderRadius: BorderRadius.circular(26)),
        child: const Icon(Symbols.pause_rounded, color: LsTheme.teal, size: 42, fill: 1),
      ),
      const SizedBox(height: 20),
      Text(
        'Paused',
        style: LikhoFonts.title(size: 34, weight: FontWeight.w800, color: LsTheme.ink),
      ),
      const SizedBox(height: 6),
      Text('Your fruit can wait.', style: LikhoFonts.body(size: 16, color: LsTheme.muted)),
      const SizedBox(height: 26),
      LsAction(key: const ValueKey('ls-resume'), label: 'Keep playing', icon: Symbols.play_arrow_rounded, onTap: onResume),
      const SizedBox(height: 14),
      LsAction(key: const ValueKey('ls-exit'), label: 'Back to games', icon: Symbols.grid_view_rounded, onTap: onExit, secondary: true),
    ],
  );
}

class LsResultCard extends StatelessWidget {
  const LsResultCard({super.key, required this.game, required this.record, required this.onAgain, required this.onDone});
  final LsGame game;
  final bool record;
  final VoidCallback onAgain, onDone;
  @override
  Widget build(BuildContext context) => LsMenu(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == 1 ? 18 : 0),
              child: Icon(Symbols.star_rounded, size: i == 1 ? 70 : 54, fill: 1, color: i < game.stars ? LsTheme.gold : LsTheme.line),
            ),
        ],
      ),
      Text(
        'Great slicing!',
        textAlign: TextAlign.center,
        style: LikhoFonts.title(size: 32, weight: FontWeight.w800, color: LsTheme.ink),
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: LsTheme.mint, borderRadius: BorderRadius.circular(22)),
        child: Column(
          children: [
            Text(
              record ? 'NEW PERSONAL BEST' : 'YOUR SCORE',
              style: LikhoFonts.body(size: 11, weight: FontWeight.w900, color: LsTheme.teal).copyWith(letterSpacing: 1.5),
            ),
            Text(
              '${game.score}',
              style: LikhoFonts.title(size: 54, weight: FontWeight.w800, color: LsTheme.ink),
            ),
            Text(
              '${game.sliced} ${game.sliced == 1 ? 'fruit' : 'fruits'} sliced · ${game.done} tasks done',
              textAlign: TextAlign.center,
              style: LikhoFonts.body(size: 13, weight: FontWeight.w700, color: LsTheme.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      LsAction(key: const ValueKey('ls-again'), label: 'Play again', icon: Symbols.replay_rounded, onTap: onAgain),
      const SizedBox(height: 14),
      LsAction(key: const ValueKey('ls-done'), label: 'Back to games', icon: Symbols.grid_view_rounded, onTap: onDone, secondary: true),
    ],
  );
}

class LsTaskCard extends StatelessWidget {
  const LsTaskCard({super.key, required this.task, required this.got, required this.onTap});
  final LsTask task;
  final int got;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final n = task.letters.length;
    final picture = task.picture;
    return Semantics(
      button: true,
      label: 'Hear the challenge again',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: const ValueKey('ls-task'),
          padding: const EdgeInsets.all(14),
          decoration: LsTheme.panel(),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: LsTheme.mint, borderRadius: BorderRadius.circular(19)),
                child: picture != null
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(picture, fit: BoxFit.contain),
                      )
                    : Text(task.letters[0], style: LikhoFonts.letter(size: 46, color: LsTheme.ink).copyWith(height: 1.1)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.spelling
                          ? 'SPELL THE WORD'
                          : picture != null
                          ? 'FIRST SOUND'
                          : 'SLICE THIS LETTER',
                      style: LikhoFonts.body(size: 10, weight: FontWeight.w900, color: LsTheme.muted).copyWith(letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    if (task.spelling)
                      Row(
                        children: [
                          for (var i = 0; i < n; i++)
                            Expanded(
                              child: Container(
                                height: 37,
                                margin: const EdgeInsets.only(right: 4),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: i < got ? LsTheme.teal : LsTheme.mint,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: i == got ? LsTheme.teal : Colors.transparent, width: 2),
                                ),
                                child: Text(
                                  task.letters[i],
                                  style: LikhoFonts.letter(size: 23, color: i < got ? Colors.white : LsTheme.ink).copyWith(height: 1),
                                ),
                              ),
                            ),
                        ],
                      )
                    else ...[
                      Text(
                        picture != null ? 'What does it start with?' : 'Find ${task.letters[0]} on the fruit',
                        style: LikhoFonts.body(size: 14, weight: FontWeight.w800, color: LsTheme.ink),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < n.clamp(0, 5); i++)
                            Container(
                              width: 18,
                              height: 8,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(color: i < got ? LsTheme.teal : LsTheme.line, borderRadius: BorderRadius.circular(4)),
                            ),
                          const SizedBox(width: 3),
                          Text(
                            '$got/$n',
                            style: LikhoFonts.body(size: 11, weight: FontWeight.w900, color: LsTheme.muted),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Symbols.volume_up_rounded, color: LsTheme.teal, size: 23, fill: 1),
            ],
          ),
        ),
      ),
    );
  }
}
