import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../feedback/app_feedback.dart';
import '../widgets/game_buttons.dart';

/// A presentation for the first capital-A lesson, not the placement warm-up.
bool isAppleGarden(CourseLevel level) => !level.placement && !level.isBoss && level.id == 'level-01' && level.intro.text == 'A' && level.intro.word == 'apple';

abstract final class GardenStyle {
  static const ink = Color(0xFF304A35);
  static const muted = Color(0xFF687658);
  static const cream = Color(0xFFFFFBEF);
  static const green = Color(0xFF578237);
  static const pale = Color(0xFFEBF1D7);
  static const red = Color(0xFFE8674E);
  static const line = Color(0xFFDFE5C9);

  static BoxDecoration panel({double radius = 30}) => BoxDecoration(
    color: cream,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white, width: 3),
    boxShadow: const [BoxShadow(color: Color(0x23384924), blurRadius: 22, offset: Offset(0, 8))],
  );
}

class GardenProp extends StatelessWidget {
  const GardenProp(this.name, {super.key, this.size, this.word = false});
  final String name;
  final double? size;
  final bool word;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/${word ? 'games/words' : 'stories/a'}/$name.webp',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
  );
}

class GardenBackdrop extends StatelessWidget {
  const GardenBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFB9E9ED),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/stories/a/bg_garden.webp', fit: BoxFit.cover, alignment: Alignment.topCenter, excludeFromSemantics: true),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xA6F6FFF7), Color(0x00F6FFF7), Color(0x33638336)],
                stops: [0, .45, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class GardenIconButton extends StatelessWidget {
  const GardenIconButton({super.key, required this.icon, required this.label, required this.onTap});
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
        color: GardenStyle.cream,
        edgeColor: GardenStyle.line,
        edge: 3,
        width: 48,
        height: 48,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        onTap: () {
          AppFeedback.of(context).tap();
          onTap();
        },
        child: Icon(icon, color: GardenStyle.ink, size: 25),
      ),
    ),
  );
}

class GardenAction extends StatelessWidget {
  const GardenAction({super.key, required this.label, required this.onTap, this.secondary = false});
  final String label;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: PushButton(
      color: secondary ? GardenStyle.pale : GardenStyle.green,
      edgeColor: secondary ? GardenStyle.line : const Color(0xFF385923),
      edge: 4,
      height: 56,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      onTap: () {
        AppFeedback.of(context).press();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: secondary ? GardenStyle.ink : Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Icon(secondary ? Symbols.replay_rounded : Symbols.arrow_forward_rounded, color: secondary ? GardenStyle.ink : Colors.white, size: 23),
          ],
        ),
      ),
    ),
  );
}

/// Actual earned apples accumulate in the basket. No reward is lost on errors.
class GardenBasket extends StatelessWidget {
  const GardenBasket({super.key, required this.apples, this.size = 100});
  final int apples;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$apples apples collected',
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(child: GardenProp(apples >= 8 ? 'basket_full' : 'basket')),
          if (apples < 8)
            for (var i = 0; i < apples; i++)
              Positioned(
                left: size * (.19 + (i % 4) * .15),
                top: size * (.41 - (i ~/ 4) * .13),
                child: GardenProp('apple', size: size * .26),
              ),
        ],
      ),
    ),
  );
}

/// A small, lively orchard. The tree grows fruit as each handwriting stroke is
/// completed; a won task sends an apple into the persistent harvest basket.
class GardenOrchard extends ConsumerWidget {
  const GardenOrchard({super.key, required this.time, required this.earned, required this.total, this.growth = 0, this.celebrate = false});
  final ValueNotifier<double> time;
  final int earned, total;
  final double growth;
  final bool celebrate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = ref.watch(reduceMotionProvider) || MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final treeW = math.min(w * .64, h * 1.3);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              bottom: 1,
              width: treeW,
              height: h,
              child: Image.asset('assets/games/runner/apple_tree.webp', fit: BoxFit.contain, excludeFromSemantics: true),
            ),
            for (var i = 0; i < 3; i++)
              Positioned(
                right: treeW * (.18 + i * .2),
                top: h * (.13 + (i % 2) * .17),
                child: AnimatedScale(
                  scale: growth >= (i + 1) / 3 ? 1 : .45,
                  duration: Duration(milliseconds: reduce ? 0 : 450),
                  curve: Curves.elasticOut,
                  child: GardenProp('apple', size: h * .19),
                ),
              ),
            Positioned(
              right: treeW * .42,
              bottom: -3,
              child: GardenBasket(apples: earned, size: h * .55),
            ),
            Positioned(
              right: 3,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: GardenStyle.cream, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  '$earned / $total',
                  style: LikhoFonts.body(size: 13, weight: FontWeight.w900, color: GardenStyle.ink),
                ),
              ),
            ),
            if (celebrate && !reduce)
              TweenAnimationBuilder<double>(
                key: ValueKey(earned),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1050),
                builder: (context, t, _) => Positioned(
                  right: treeW * (.25 + .2 * t),
                  top: h * (.15 + .54 * t) - math.sin(t * math.pi) * 28,
                  child: Opacity(
                    opacity: t > .85 ? (1 - t) / .15 : 1,
                    child: Transform.rotate(
                      angle: t * .7,
                      child: GardenProp('apple', size: h * .23),
                    ),
                  ),
                ),
              ),
            if (!reduce)
              ValueListenableBuilder<double>(
                valueListenable: time,
                child: const GardenProp('bird', size: 27),
                builder: (context, t, bird) => Positioned(right: w * .3 + math.sin(t * .55) * 19, top: 3 + math.sin(t * 1.2) * 4, child: bird!),
              ),
          ],
        );
      },
    );
  }
}
