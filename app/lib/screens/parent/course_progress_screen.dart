import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../data/models/course_models.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import 'parent_widgets.dart';

/// 20 Course progress, from the prototype: every world and level with its
/// stars and a progress bar (stars / 3).
class CourseProgressScreen extends ConsumerWidget {
  const CourseProgressScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider).value;
    final r = ref.watch(familyProvider.select((f) => f.record));
    return ParentPage(
      children: [
        ParentHeader(icon: Symbols.arrow_back_rounded, onTap: onBack, title: 'Course progress'),
        if (course != null)
          for (final w in course.worlds) _WorldCard(world: w, levels: course.levelsOf(w), record: r),
      ],
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.world, required this.levels, required this.record});
  final CourseWorld world;
  final List<CourseLevel> levels;
  final ChildRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = LikhoWorlds.byId(world.themeId);
    final done = levels.where((l) => record.isDone(l.number)).length;
    return ParentCard(
      padding: EdgeInsets.zero,
      radius: 22,
      soft: false,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: UiColors.chip)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(world.name, style: LikhoFonts.parent(size: 16, weight: FontWeight.w800)),
                      Text(
                        world.skill,
                        style: LikhoFonts.parent(size: 12, weight: FontWeight.w600, color: LikhoColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$done/${levels.length}',
                  style: LikhoFonts.parent(size: 13, weight: FontWeight.w800, color: LikhoColors.inkMuted),
                ),
              ],
            ),
          ),
          for (final l in levels) _LevelRow(level: l, stars: record.levelStars[l.number], color: theme.accent),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level, required this.stars, required this.color});
  final CourseLevel level;
  final int? stars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final st = stars ?? 0;
    final pct = st / 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ParentColors.rowLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LikhoFonts.parent(size: 14, weight: FontWeight.w700),
                ),
                Text(
                  level.skill,
                  style: LikhoFonts.parent(size: 12, weight: FontWeight.w600, color: UiColors.inkLabel),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          for (var j = 1; j <= 3; j++) SymbolIcon(Symbols.star_rounded, size: 16, fill: true, color: st >= j ? LikhoColors.primary : ParentColors.starOff),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    color: UiColors.chip,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stars == null ? '—' : '${(pct * 100).round()}%',
                  style: LikhoFonts.parent(size: 11, weight: FontWeight.w700, color: UiColors.inkLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
