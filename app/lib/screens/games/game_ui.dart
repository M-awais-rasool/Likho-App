import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/tokens.dart';
import '../gameplay/widgets/game_buttons.dart';

/// The pieces every game shares: its start card (picture, best score,
/// Play), pause and result cards over the dimmed game, the white pills of
/// the top bar and the big buttons. [id] prefixes the keys ('md', 'sr').

/// A white rounded box in the top bar.
class GamePill extends StatelessWidget {
  const GamePill({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: MonsterColors.panel,
      borderRadius: BorderRadius.circular(21),
      boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 3), blurRadius: 6)],
    ),
    child: Align(widthFactor: 1, child: child),
  );
}

/// A card over the dimmed game ([width] wide).
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.child, this.alignment = Alignment.center, this.width = 330});
  final Widget child;
  final Alignment alignment;
  final double width;

  /// A game played sideways (Monster Smash): the cards lie their parts
  /// side by side.
  static bool wide(BuildContext context) => MediaQuery.sizeOf(context).aspectRatio > 1.3;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MonsterColors.veil,
    child: SafeArea(
      child: Align(
        alignment: alignment,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .8, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: width,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: MonsterColors.card,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 10), blurRadius: 24)],
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// A big button: green ([main]) or white.
Widget gameButton({required Key key, required String label, required IconData icon, required VoidCallback onTap, bool main = true}) => PushButton(
  key: key,
  onTap: onTap,
  color: main ? LikhoColors.success : MonsterColors.panel,
  edgeColor: main ? GameColors.successDeep : GameColors.ink15,
  edge: 5,
  height: 58,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  innerHighlight: main,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 28, fill: 1, weight: 700, color: main ? LikhoColors.surface : LikhoColors.ink),
      const SizedBox(width: 6),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: LikhoFonts.title(size: 22, weight: FontWeight.w800, color: main ? LikhoColors.surface : LikhoColors.ink),
          ),
        ),
      ),
    ],
  ),
);

/// Before a game: its picture, the child's best score (or [hint]), Play.
class GameStartCard extends StatelessWidget {
  const GameStartCard({super.key, required this.id, required this.title, required this.cover, required this.hint, required this.best, required this.onPlay, required this.onBack});
  final String id, title, cover, hint;
  final int best;
  final VoidCallback onPlay, onBack;

  @override
  Widget build(BuildContext context) {
    final wide = GameCard.wide(context);
    final words = [
      Text(title, style: LikhoFonts.title(size: 30, weight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(best > 0 ? 'Your best: $best' : hint, textAlign: TextAlign.center, style: LikhoFonts.body(size: 16, weight: FontWeight.w800, color: StoryColors.name)),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: gameButton(key: ValueKey('$id-play'), label: 'Play', icon: Symbols.play_arrow_rounded, onTap: onPlay),
      ),
    ];
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.asset(cover, width: wide ? 210 : 260, height: wide ? 190 : 200, fit: BoxFit.cover, alignment: const Alignment(0, -.1)),
    );
    return Stack(
      children: [
        GameCard(
          // high, so Pencil can introduce the game below it
          alignment: wide ? Alignment.center : const Alignment(0, -.55),
          width: wide ? 560 : 330,
          child: wide
              ? Row(
                  children: [
                    picture,
                    const SizedBox(width: 18),
                    Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: words)),
                  ],
                )
              : Column(mainAxisSize: MainAxisSize.min, children: [picture, const SizedBox(height: 12), ...words]),
        ),
        Positioned(
          left: 12 + (wide ? MediaQuery.paddingOf(context).left : 0),
          top: MediaQuery.paddingOf(context).top + 8,
          child: PushButton(
            key: ValueKey('$id-back'),
            onTap: onBack,
            color: MonsterColors.panel,
            width: 46,
            height: 46,
            shape: const CircleBorder(),
            child: const Icon(Symbols.arrow_back_rounded, size: 26, weight: 700, color: LikhoColors.ink),
          ),
        ),
      ],
    );
  }
}

/// Paused: [picture], Keep playing, Stop.
class GamePauseCard extends StatelessWidget {
  const GamePauseCard({super.key, required this.id, required this.picture, required this.onResume, required this.onExit});
  final String id, picture;
  final VoidCallback onResume, onExit;

  @override
  Widget build(BuildContext context) => GameCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(picture, height: GameCard.wide(context) ? 80 : 110),
        const SizedBox(height: 8),
        Text('Paused', style: LikhoFonts.title(size: 32, weight: FontWeight.w800)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: gameButton(key: ValueKey('$id-resume'), label: 'Keep playing', icon: Symbols.play_arrow_rounded, onTap: onResume),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: gameButton(key: ValueKey('$id-exit'), label: 'Stop', icon: Symbols.home_rounded, onTap: onExit, main: false),
        ),
      ],
    ),
  );
}

/// The end: [picture], [title], the stars (none when [stars] is null), the
/// score, a new best, Play again, Map.
class GameResultCard extends StatelessWidget {
  const GameResultCard({
    super.key,
    required this.id,
    required this.picture,
    required this.title,
    required this.star,
    required this.stars,
    required this.score,
    required this.record,
    required this.onAgain,
    required this.onDone,
    this.detail,
    this.onNext,
    this.doneLabel = 'Map',
    this.doneIcon = Symbols.map_rounded,
    this.pictureWidget,
  });
  final String id, picture, title, star;

  /// A game with levels: the next level (the big button; Play again moves
  /// down), and where Done goes ("Levels").
  final VoidCallback? onNext;
  final String doneLabel;
  final IconData doneIcon;

  /// Drawn instead of [picture] (Monster Smash's heroes).
  final Widget? pictureWidget;

  /// A line under the score ("320 m · 12 words").
  final String? detail;
  final int? stars;
  final int score;
  final bool record;
  final VoidCallback onAgain, onDone;

  @override
  Widget build(BuildContext context) {
    final wide = GameCard.wide(context);
    final head = [
      pictureWidget ?? Image.asset(picture, height: wide ? 100 : 120),
      const SizedBox(height: 6),
      Text(title, textAlign: TextAlign.center, style: LikhoFonts.title(size: 32, weight: FontWeight.w800)),
      if (stars case final n?) ...[
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var k = 1; k <= 3; k++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + k * 250),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(opacity: n >= k ? 1 : .25, child: Image.asset(star, width: k == 2 ? 54 : 44)),
                ),
              ),
          ],
        ),
      ],
    ];
    final rest = [
      Text('$score points', style: LikhoFonts.title(size: 22, weight: FontWeight.w800, color: StoryColors.name)),
      if (detail case final d?) Text(d, key: ValueKey('$id-detail'), textAlign: TextAlign.center, style: LikhoFonts.body(size: 16, weight: FontWeight.w800, color: StoryColors.name)),
      if (record) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          decoration: BoxDecoration(color: MonsterColors.ribbon, borderRadius: BorderRadius.circular(14)),
          child: Text('New best!', style: LikhoFonts.title(size: 18, weight: FontWeight.w800, color: MonsterColors.ribbonInk)),
        ),
      ],
      const SizedBox(height: 16),
      if (onNext case final next?) ...[
        SizedBox(
          width: double.infinity,
          child: gameButton(key: ValueKey('$id-next'), label: 'Next level', icon: Symbols.arrow_forward_rounded, onTap: next),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: gameButton(key: ValueKey('$id-again'), label: 'Again', icon: Symbols.replay_rounded, onTap: onAgain, main: false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: gameButton(key: ValueKey('$id-done'), label: doneLabel, icon: doneIcon, onTap: onDone, main: false),
            ),
          ],
        ),
      ] else ...[
        SizedBox(
          width: double.infinity,
          child: gameButton(key: ValueKey('$id-again'), label: 'Play again', icon: Symbols.replay_rounded, onTap: onAgain),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: gameButton(key: ValueKey('$id-done'), label: doneLabel, icon: doneIcon, onTap: onDone, main: false),
        ),
      ],
    ];
    return GameCard(
      // high, so Pencil's words show below it
      alignment: wide ? Alignment.center : const Alignment(0, -.75),
      width: wide ? 560 : 330,
      child: wide
          ? Row(
              key: ValueKey('$id-result'),
              children: [
                Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: head)),
                const SizedBox(width: 18),
                Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: rest)),
              ],
            )
          : Column(
              key: ValueKey('$id-result'),
              mainAxisSize: MainAxisSize.min,
              children: [...head, const SizedBox(height: 8), ...rest],
            ),
    );
  }
}
