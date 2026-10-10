import 'package:flutter/material.dart';

import '../design/likho_widgets.dart';
import '../design/tokens.dart';
import '../screens/common/clock.dart';
import '../screens/world_map/boss_painter.dart';

/// QA gallery of the fourteen world bosses, each on its world's colours.
/// Tap a boss: asleep -> wakes up (yawn, stretch, hop) -> dances -> asleep.
class BossPlayground extends StatefulWidget {
  const BossPlayground({super.key, this.onBack});
  final VoidCallback? onBack;

  /// Boss and world theme, in course order.
  static const worlds = [
    ('snail', 'letterLand'), ('monkey', 'actionJungle'), ('crab', 'blendBeach'), ('bear', 'phonicsForest'), //
    ('turtle', 'questionIsland'), ('ladybug', 'sightGarden'), ('dragon', 'alphabetCastle'), ('goat', 'soundMountain'),
    ('robotBus', 'wordTown'), ('cloud', 'sentenceSky'), ('fish', 'smallLetterCove'), ('frog', 'readingRiver'),
    ('penguin', 'frostyBay'), ('moon', 'storySpace'),
  ];

  @override
  State<BossPlayground> createState() => _BossPlaygroundState();
}

enum _Mood { asleep, awake, dance }

class _BossPlaygroundState extends State<BossPlayground> {
  final _moods = List.filled(BossPlayground.worlds.length, _Mood.asleep);

  void _all(_Mood m) => setState(() => _moods.fillRange(0, _moods.length, m));

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LikhoColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(LikhoSpace.s2),
              child: Wrap(
                spacing: LikhoSpace.s1,
                runSpacing: LikhoSpace.s1,
                children: [
                  if (widget.onBack != null) LikhoButton(label: 'Back', onTap: widget.onBack),
                  LikhoButton(label: 'Asleep', onTap: () => _all(_Mood.asleep)),
                  LikhoButton(label: 'Wake up', onTap: () => _all(_Mood.awake)),
                  LikhoButton(label: 'Dance', onTap: () => _all(_Mood.dance)),
                ],
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(LikhoSpace.s2),
                mainAxisSpacing: LikhoSpace.s1,
                crossAxisSpacing: LikhoSpace.s1,
                childAspectRatio: 1.1,
                children: [
                  for (final (i, (boss, theme)) in BossPlayground.worlds.indexed)
                    GestureDetector(
                      onTap: () => setState(() => _moods[i] = _Mood.values[(_moods[i].index + 1) % _Mood.values.length]),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: LikhoWorlds.byId(theme).bg, borderRadius: BorderRadius.circular(LikhoRadius.card)),
                        child: Center(
                          child: BossFigure(
                            world: BossPainter.indexOf(boss),
                            awake: _moods[i] != _Mood.asleep,
                            dance: _moods[i] == _Mood.dance,
                            width: 150,
                            height: 125,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
