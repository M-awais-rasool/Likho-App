import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';

/// The tags on a game's or a story's card: "NEW" (the team tagged it and
/// the child has not played it yet) and the Likho Plus lock (Plus-only,
/// tapping opens the paywall).

/// "NEW" with a star: an orange pill that breathes and gives a little
/// wiggle now and then (it keeps still with Reduce motion on).
class NewTag extends StatelessWidget {
  const NewTag({super.key});

  @override
  Widget build(BuildContext context) => Loop(
    seconds: 2.4,
    builder: (context, t, child) {
      final breathe = 1 + .05 * math.sin(t * math.pi * 2);
      final wiggle = t < .18 ? math.sin(t / .18 * math.pi * 3) * .09 : 0.0;
      return Transform.rotate(
        angle: -.06 + wiggle,
        child: Transform.scale(scale: breathe, child: child),
      );
    },
    child: Container(
      key: const ValueKey('new-tag'),
      padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
      decoration: BoxDecoration(
        color: LikhoColors.hint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LikhoColors.surface, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x40FF8A5B), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.star_rounded, size: 18, fill: 1, color: LikhoColors.primary),
          const SizedBox(width: 3),
          Text(
            'NEW',
            style: LikhoFonts.title(size: 15, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
          ),
        ],
      ),
    ),
  );
}

/// Likho Plus only: a lock with "Plus" on a white pill.
class PlusTag extends StatelessWidget {
  const PlusTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('plus-tag'),
    padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
    decoration: BoxDecoration(
      color: LikhoColors.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x332B2D42), blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Symbols.lock_rounded, size: 17, fill: 1, color: MonsterColors.ribbon),
        const SizedBox(width: 3),
        Text(
          'Plus',
          style: LikhoFonts.title(size: 15, weight: FontWeight.w800, color: MonsterColors.ribbon).copyWith(height: 1),
        ),
      ],
    ),
  );
}
