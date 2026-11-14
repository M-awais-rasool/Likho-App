import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../feedback/game_feedback.dart';
import 'garden_art.dart';

/// The same garden welcomes the child and holds the finished harvest.
class GardenJourney extends ConsumerWidget {
  const GardenJourney({super.key, required this.mascot, required this.onContinue, this.onAgain, this.stars = 0, this.apples = 0, this.gain = 0});
  final Widget mascot;
  final VoidCallback onContinue;
  final VoidCallback? onAgain;
  final int stars, apples, gain;

  bool get complete => onAgain != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = ref.watch(reduceMotionProvider) || MediaQuery.disableAnimationsOf(context);
    final compact = MediaQuery.sizeOf(context).height < 720 || MediaQuery.sizeOf(context).width < 360;
    return GardenBackdrop(
      child: Stack(
        children: [
          if (complete) ...[
            FeedbackCue(at: 0, play: (f) => f.levelComplete()),
            for (var i = 0; i < stars; i++) FeedbackCue(at: .4 + i * .35, play: (f) => f.star(i + 1)),
          ],
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 24, vertical: compact ? 12 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(color: GardenStyle.cream, borderRadius: BorderRadius.circular(24)),
                        child: Text(
                          complete ? 'LETTER A • COMPLETE' : (compact ? 'LETTER A • LET’S PLAY' : 'YOUR FIRST GARDEN ADVENTURE'),
                          style: LikhoFonts.body(size: 11, weight: FontWeight.w900, color: GardenStyle.green).copyWith(letterSpacing: 1.2),
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 16),
                      Text(
                        complete ? 'You grew it!' : 'Apple Garden',
                        textAlign: TextAlign.center,
                        style: LikhoFonts.title(size: compact ? 28 : 41, weight: FontWeight.w800, color: GardenStyle.ink).copyWith(height: 1.05),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        complete ? '$apples apples. One amazing A.' : 'Find it. Write it. Watch it grow.',
                        textAlign: TextAlign.center,
                        style: LikhoFonts.body(size: compact ? 13 : 16, weight: FontWeight.w700, color: GardenStyle.ink),
                      ),
                      SizedBox(height: compact ? 10 : 20),
                      SizedBox(
                        height: compact ? 120 : 225,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(left: 5, bottom: 0, width: compact ? 100 : 150, height: compact ? 120 : 210, child: FittedBox(child: SizedBox(width: 150, height: 210, child: mascot))),
                            Positioned(right: 6, bottom: 0, child: complete ? GardenBasket(apples: apples, size: compact ? 110 : 150) : GardenProp('basket', size: compact ? 100 : 130)),
                            if (!complete)
                              Positioned(
                                right: 30,
                                top: 0,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: reduce ? 1 : .6, end: 1),
                                  duration: Duration(milliseconds: reduce ? 0 : 650),
                                  curve: Curves.elasticOut,
                                  builder: (context, t, child) => Transform.scale(scale: t, child: child),
                                  child: SizedBox(
                                    width: compact ? 70 : 100,
                                    height: compact ? 78 : 110,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const GardenProp('apple', size: 110),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 16),
                                          child: Text('A', style: LikhoFonts.letter(size: compact ? 36 : 59, color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 20),
                      Container(
                        padding: EdgeInsets.all(compact ? 16 : 22),
                        decoration: GardenStyle.panel(),
                        child: Column(
                          children: [
                            if (complete) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 5),
                                      child: Icon(Symbols.star_rounded, fill: 1, size: compact ? 32 : 44, color: i < stars ? const Color(0xFFF1AD36) : GardenStyle.line),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'A is for apple!',
                                style: LikhoFonts.title(size: compact ? 20 : 25, weight: FontWeight.w800, color: GardenStyle.ink),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                gain > 0 ? '+$gain stars for your collection' : 'A lovely harvest. Well done!',
                                textAlign: TextAlign.center,
                                style: LikhoFonts.body(size: compact ? 12 : 14, weight: FontWeight.w700, color: GardenStyle.muted),
                              ),
                            ] else ...[
                              Text(
                                'A little help for Pencil',
                                style: LikhoFonts.title(size: compact ? 18 : 23, weight: FontWeight.w800, color: GardenStyle.ink),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Learn the letter A and collect an apple for every little task.',
                                textAlign: TextAlign.center,
                                style: LikhoFonts.body(size: compact ? 13 : 16, weight: FontWeight.w600, color: GardenStyle.muted, height: 1.4),
                              ),
                              if (!compact) const SizedBox(height: 15),
                              if (!compact) const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _Skill(icon: Symbols.search_rounded, text: 'Find'),
                                  _Skill(icon: Symbols.gesture_rounded, text: 'Write'),
                                  _Skill(icon: Symbols.nutrition_rounded, text: 'Collect'),
                                ],
                              ),
                            ],
                            SizedBox(height: compact ? 14 : 22),
                            GardenAction(
                              key: ValueKey(complete ? 'garden-next' : 'garden-start'),
                              label: complete ? 'Continue' : 'Let’s grow!',
                              onTap: onContinue,
                            ),
                            if (complete) ...[
                              const SizedBox(height: 14),
                              GardenAction(key: const ValueKey('garden-again'), label: 'Play A again', onTap: onAgain!, secondary: true),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Skill extends StatelessWidget {
  const _Skill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(11),
        decoration: const BoxDecoration(color: GardenStyle.pale, shape: BoxShape.circle),
        child: Icon(icon, color: GardenStyle.green, size: 25),
      ),
      const SizedBox(height: 5),
      Text(
        text,
        style: LikhoFonts.body(size: 13, weight: FontWeight.w800, color: GardenStyle.ink),
      ),
    ],
  );
}
