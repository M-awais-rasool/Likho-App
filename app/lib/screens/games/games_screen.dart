import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/app_controls.dart';
import '../../data/games.dart';
import '../../design/tokens.dart';
import '../gameplay/widgets/game_buttons.dart';
import 'monster_defense/md_scene.dart';
import 'letter_slice/ls_scene.dart';
import 'monster_smash/ms_scene.dart';
import 'spell_runner/sr_scene.dart';

/// Games (the map's button): each game as a big card (its picture, the
/// child's best score and stars, Play); more games to come below.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key, this.onBack, required this.onOpen});

  /// Null: a tab of the bottom bar (no back button).
  final VoidCallback? onBack;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myGamesProvider);
    final comingSoon = ref.watch(appControlsProvider.select((c) => c.comingSoon));
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: LikhoColors.clear),
      child: Material(
        color: LikhoColors.background,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(onBack == null ? 22 : 16, pad.top + 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    if (onBack != null) ...[
                      PushButton(
                        onTap: onBack,
                        color: StoryColors.panel,
                        width: 52,
                        height: 52,
                        shape: const CircleBorder(),
                        shadows: const [BoxShadow(color: StoryColors.panelShadow, offset: Offset(0, 4), blurRadius: 8)],
                        child: const Icon(Symbols.arrow_back_rounded, size: 28, weight: 700, color: LikhoColors.ink),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Text('Games', style: LikhoFonts.title(size: 30, weight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
            for (final (id, title, cover, hint) in [
              (GameIds.monsters, 'Monster Defense', MdArt.cover, 'Letters and words'),
              (GameIds.runner, 'Spell Runner', SrArt.cover, 'Spell on a skateboard'),
              (GameIds.smash, 'Monster Smash', MsArt.cover, 'Smash the letter towers'),
              (GameIds.slice, 'Letter Slice', LsArt.cover, 'Slice the letter fruits'),
            ])
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _GameCard(id: id, title: title, cover: cover, hint: hint, record: mine[id] ?? const GameRecord(), onTap: () => onOpen(id)),
                ),
              ),
            if (comingSoon) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'COMING SOON',
                    style: LikhoFonts.body(size: 13, weight: FontWeight.w800, color: StoryColors.name).copyWith(letterSpacing: 1.5),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, pad.bottom + 24),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    for (final icon in [Symbols.extension_rounded, Symbols.rocket_launch_rounded, Symbols.directions_run_rounded, Symbols.castle_rounded])
                      Container(
                        decoration: BoxDecoration(color: StoryColors.locked, borderRadius: BorderRadius.circular(22)),
                        child: Stack(
                          children: [
                            Center(child: Icon(icon, size: 44, fill: 1, color: StoryColors.lockedInk)),
                            const Positioned(right: 10, top: 10, child: Icon(Symbols.lock_rounded, size: 20, fill: 1, color: StoryColors.lockedInk)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 24)),
          ],
        ),
      ),
    );
  }
}

/// A game's card: its cover, the title, the best score and stars, Play.
class _GameCard extends StatelessWidget {
  const _GameCard({required this.id, required this.title, required this.cover, required this.hint, required this.record, required this.onTap});
  final String id, title, cover, hint;
  final GameRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('game-$id'),
    onTap: onTap,
    child: Container(
      height: 360,
      decoration: BoxDecoration(
        color: StoryColors.panel,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: StoryColors.panelShadow, offset: Offset(0, 8), blurRadius: 20)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.asset(cover, fit: BoxFit.cover, alignment: const Alignment(0, -.15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LikhoFonts.title(size: 22, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      record.plays > 0
                          ? Row(
                              children: [
                                for (var k = 1; k <= 3; k++) Icon(Symbols.star_rounded, size: 20, fill: 1, color: record.stars >= k ? LikhoColors.primary : MapColors.starOff),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Best ${record.best}',
                                    overflow: TextOverflow.ellipsis,
                                    style: LikhoFonts.body(size: 14, weight: FontWeight.w800, color: StoryColors.name),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              hint,
                              style: LikhoFonts.body(size: 14, weight: FontWeight.w700, color: StoryColors.name),
                            ),
                    ],
                  ),
                ),
                PushButton(
                  onTap: onTap,
                  color: LikhoColors.success,
                  edgeColor: GameColors.successDeep,
                  edge: 5,
                  width: 108,
                  height: 52,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  innerHighlight: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.play_arrow_rounded, size: 26, fill: 1, color: LikhoColors.surface),
                      Text(
                        record.plays > 0 ? 'Again' : 'Play',
                        style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: LikhoColors.surface),
                      ),
                    ],
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
