import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/app_controls.dart';
import '../../data/story.dart';
import '../../design/tokens.dart';
import '../gameplay/widgets/game_buttons.dart';
import 'story_art.dart';

/// Stories: one letter an episode. Story A is a big card (its garden, Ayan
/// and Dada ji, a Play button, its stars); the letters still to come wait
/// below. The App controls can hide an episode and the letters to come.
class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key, required this.onBack, required this.onOpen});
  final VoidCallback onBack;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stars = ref.watch(myStoryStarsProvider);
    final shown = ref.watch(shownEpisodesProvider);
    final comingSoon = ref.watch(appControlsProvider.select((c) => c.comingSoon));
    final pad = MediaQuery.paddingOf(context);
    const letters = 'BCDEFGHIJKLMNOPQRSTUVWXYZ';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: LikhoColors.clear),
      child: Material(
        color: LikhoColors.background,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, pad.top + 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
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
                    Expanded(child: Text('Stories', style: LikhoFonts.title(size: 30, weight: FontWeight.w800))),
                  ],
                ),
              ),
            ),
            if (shown.contains('a'))
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverToBoxAdapter(child: _StoryCard(stars: stars['a'] ?? 0, onTap: () => onOpen('a'))),
              ),
            if (comingSoon) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Text('COMING SOON', style: LikhoFonts.body(size: 13, weight: FontWeight.w800, color: StoryColors.name).copyWith(letterSpacing: 1.5)),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, pad.bottom + 24),
                sliver: SliverGrid.count(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (final l in letters.split(''))
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: StoryColors.locked, borderRadius: BorderRadius.circular(18)),
                        child: Text(l, style: LikhoFonts.letter(size: 30, color: StoryColors.lockedInk).copyWith(height: 1)),
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

/// Story A's card: the garden picture with Dada ji and Ayan in it, the
/// title, its stars, Play.
class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.stars, required this.onTap});
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('story-a'),
    onTap: onTap,
    child: Container(
      height: 340,
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(StoryArt.bg('a', 'garden'), fit: BoxFit.cover, alignment: const Alignment(0, .55)),
                Positioned(left: 30, bottom: 6, height: 150, width: 110, child: Image.asset(StoryArt.pose('a', 'ayan', 'wave'), fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
                Positioned(right: 24, bottom: 4, height: 165, width: 140, child: Image.asset(StoryArt.pose('a', 'dada', 'happy'), fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: LikhoColors.success, shape: BoxShape.circle, border: Border.all(color: StoryColors.panel, width: 3)),
                    child: Text('A', style: LikhoFonts.letter(size: 28, color: LikhoColors.surface).copyWith(height: 1)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Dada's Apple Garden", maxLines: 1, overflow: TextOverflow.ellipsis, style: LikhoFonts.title(size: 22, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      stars > 0
                          ? Row(children: [for (var k = 1; k <= 3; k++) Icon(Symbols.star_rounded, size: 22, fill: 1, color: stars >= k ? LikhoColors.primary : MapColors.starOff)])
                          : Text('A is for apple', style: LikhoFonts.body(size: 14, weight: FontWeight.w700, color: StoryColors.name)),
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
                      Text(stars > 0 ? 'Again' : 'Play', style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: LikhoColors.surface)),
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
