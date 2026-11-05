import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/games.dart';
import '../../../design/tokens.dart';
import '../../../feedback/app_feedback.dart';
import '../../../game/monster_smash/ms_engine.dart';
import '../../gameplay/widgets/game_buttons.dart';
import '../../likho_route.dart';
import 'monster_smash_screen.dart';
import 'ms_map_art.dart';

/// Letter Land's twelve levels on a floating crystal trail. The map follows
/// the next playable level when progress loads or the child finishes a game.
class SmashLevelsScreen extends ConsumerStatefulWidget {
  const SmashLevelsScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  static const world = 'Letter Land';

  @override
  ConsumerState<SmashLevelsScreen> createState() => _SmashLevelsScreenState();
}

class _SmashLevelsScreenState extends ConsumerState<SmashLevelsScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<double>(0);
  final _scroll = ScrollController();
  (int, Size, EdgeInsets)? _placement;
  bool _opening = false;
  List<MsLevel> get _levels => MsLevels.letterLand;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _ticker = createTicker((t) => _frame.value = t.inMicroseconds / 1e6);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context) && TickerMode.valuesOf(context).enabled;
    if (animate && !_ticker.isActive) _ticker.start();
    if (!animate && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _ticker.dispose();
    _frame.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(int i) async {
    if (_opening) return;
    final fb = AppFeedback.of(context)..press();
    final record = ref.read(myGamesProvider)[GameIds.smash] ?? const GameRecord();
    if (!record.opens(_levels[i].number)) {
      fb.nope();
      return;
    }
    _opening = true;
    await Navigator.of(context).push(_route(i));
    _opening = false;
  }

  LikhoRoute<void> _route(int i) => LikhoRoute<void>(
    builder: (c) => MonsterSmashScreen(
      key: ValueKey('ms-level-${_levels[i].number}'),
      level: _levels[i],
      world: SmashLevelsScreen.world,
      ownOrientation: false,
      onDone: () => Navigator.of(c).pop(),
      onNext: i + 1 < _levels.length ? () => Navigator.of(c).pushReplacement(_route(i + 1)) : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(myGamesProvider)[GameIds.smash] ?? const GameRecord();
    final pad = MediaQuery.paddingOf(context);
    final next = _levels.indexWhere((l) => record.opens(l.number) && (record.levels[l.number] ?? 0) == 0);
    final current = next < 0 ? _levels.length - 1 : next;
    final stars = _levels.fold(0, (sum, l) => sum + (record.levels[l.number] ?? 0));
    final completed = _levels.where((l) => (record.levels[l.number] ?? 0) > 0).length;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LikhoSystemBars.dark,
      child: Material(
        color: SmashMapColors.sky,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final compact = size.height - pad.vertical < 380;
            final spots = _spots(size, pad);
            final width = math.max(spots.last.dx + 180 + pad.right, size.width);
            _placeOn(current, spots, size, pad);
            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Image.asset(SmashMapArt.sky, fit: BoxFit.cover, alignment: const Alignment(0, .25), excludeFromSemantics: true),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [SmashMapColors.lilac, SmashMapColors.lilacClear, SmashMapColors.lilacClear],
                        stops: [0, .3, 1],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(child: CustomPaint(painter: SmashMapGlints(_frame))),
                  ),
                ),
                Positioned.fill(
                  child: SingleChildScrollView(
                    key: const ValueKey('ms-levels-map'),
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: width,
                      height: size.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(painter: SmashMapPathPainter(spots, reached: current)),
                            ),
                          ),
                          for (var chapter = 0; chapter < 3; chapter++)
                            Positioned(
                              left: spots[chapter * 4].dx + 80,
                              top: pad.top + (compact ? 80 : 94),
                              child: _ChapterLabel(chapter: chapter),
                            ),
                          for (var i = 0; i < _levels.length; i++)
                            Positioned(
                              left: spots[i].dx - 42,
                              top: spots[i].dy - 42,
                              child: _LevelStop(
                                key: ValueKey('ms-level-${_levels[i].number}'),
                                number: _levels[i].number,
                                stars: record.levels[_levels[i].number] ?? 0,
                                open: record.opens(_levels[i].number),
                                current: i == next,
                                guideHeight: (spots[i].dy - 42 - pad.top - 66).clamp(48.0, 118.0),
                                frame: _frame,
                                onTap: () => _open(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: pad.top + 12,
                  left: pad.left + 18,
                  right: pad.right + 18,
                  child: _MapHeader(
                    stars: stars,
                    total: _levels.length * 3,
                    onBack: () {
                      AppFeedback.of(context).back();
                      widget.onDone();
                    },
                  ),
                ),
                Positioned(
                  bottom: pad.bottom + 12,
                  left: pad.left + 22,
                  right: pad.right + 22,
                  child: _MapFooter(
                    completed: completed,
                    total: _levels.length,
                    current: _levels[current].number,
                    allDone: next < 0,
                    onPlay: () => _open(current),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Offset> _spots(Size size, EdgeInsets pad) {
    final compact = size.height - pad.vertical < 380;
    // Reserve room for the guide above, and island, stars and footer below.
    final minimum = pad.top + (compact ? 188 : 202);
    final maximum = math.max(minimum, size.height - pad.bottom - 150);
    final span = math.min(168.0, maximum - minimum);
    final center = (pad.top + (size.height - pad.vertical) * .58).clamp(minimum + span / 2, maximum - span / 2);
    final top = center - span / 2;
    final bottom = center + span / 2;
    final step = (size.width * .215).clamp(172.0, 220.0);
    return [for (var i = 0; i < _levels.length; i++) Offset(pad.left + 144 + step * i, top + (bottom - top) * (.5 + .5 * math.cos(i * 1.45)))];
  }

  void _placeOn(int i, List<Offset> spots, Size size, EdgeInsets pad) {
    final placement = (i, size, pad);
    if (_placement == placement) return;
    _placement = placement;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _placement != placement) return;
      _scroll.jumpTo((spots[i].dx - size.width * .32).clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.stars, required this.total, required this.onBack});
  final int stars, total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Back to games',
          child: PushButton(
            key: const ValueKey('ms-levels-back'),
            onTap: onBack,
            color: SmashMapColors.cream,
            edgeColor: SmashMapColors.lilacEdge,
            edge: 3,
            width: 48,
            height: 48,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            shadows: const [BoxShadow(color: SmashMapColors.shadow, blurRadius: 14, offset: Offset(0, 5))],
            child: const Icon(Symbols.arrow_back_rounded, size: 25, weight: 700, color: SmashMapColors.ink),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 48,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monster Smash',
                    style: LikhoFonts.title(size: 29, weight: FontWeight.w800, color: SmashMapColors.ink),
                  ),
                  Text(
                    'Letter Land  /  CRYSTAL SKY',
                    style: LikhoFonts.body(size: 10, weight: FontWeight.w900, color: SmashMapColors.muted).copyWith(letterSpacing: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Semantics(
          label: '$stars of $total stars collected',
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: SmashMapColors.cream.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: LikhoColors.surface, width: 1.5),
                boxShadow: const [BoxShadow(color: SmashMapColors.shadow, blurRadius: 16, offset: Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.star_rounded, fill: 1, color: SmashMapColors.goldEdge, size: 30),
                  const SizedBox(width: 7),
                  Text(
                    '$stars / $total',
                    key: const ValueKey('ms-levels-stars'),
                    style: LikhoFonts.title(size: 23, weight: FontWeight.w800, color: SmashMapColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChapterLabel extends StatelessWidget {
  const _ChapterLabel({required this.chapter});
  final int chapter;

  @override
  Widget build(BuildContext context) {
    const names = ['FIRST FLIGHT', 'CLOUD HOP', 'STAR SUMMIT'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 23,
          height: 23,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: SmashMapColors.cream.withValues(alpha: .72), shape: BoxShape.circle),
          child: Text(
            '0${chapter + 1}',
            style: LikhoFonts.body(size: 10, weight: FontWeight.w900, color: SmashMapColors.violetDeep),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          names[chapter],
          style: LikhoFonts.body(size: 10, weight: FontWeight.w900, color: SmashMapColors.violetDeep).copyWith(letterSpacing: 1.8),
        ),
      ],
    );
  }
}

class _LevelStop extends StatelessWidget {
  const _LevelStop({
    super.key,
    required this.number,
    required this.stars,
    required this.open,
    required this.current,
    required this.guideHeight,
    required this.frame,
    required this.onTap,
  });
  final int number, stars;
  final bool open, current;
  final double guideHeight;
  final ValueNotifier<double> frame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final face = !open ? SmashMapColors.lilac : (stars > 0 ? SmashMapColors.teal : SmashMapColors.gold);
    final rim = !open ? SmashMapColors.lilacEdge : (stars > 0 ? SmashMapColors.tealDeep : SmashMapColors.goldEdge);
    final ink = !open ? SmashMapColors.muted : (stars > 0 ? LikhoColors.surface : SmashMapColors.goldInk);
    return Semantics(
      button: true,
      enabled: open,
      label:
          'Level $number, ${!open
              ? 'locked'
              : current
              ? 'next adventure'
              : '$stars of 3 stars'}',
      onTap: open ? onTap : null,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 84,
          height: 118,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              if (current)
                Positioned(
                  top: -9,
                  child: Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: SmashMapColors.cream.withValues(alpha: .8), width: 2),
                      boxShadow: [BoxShadow(color: SmashMapColors.goldLight.withValues(alpha: .55), blurRadius: 26, spreadRadius: 6)],
                    ),
                  ),
                ),
              PushButton(
                onTap: onTap,
                color: rim,
                edgeColor: rim,
                edge: 6,
                width: 84,
                height: 84,
                shape: const CircleBorder(),
                shadows: const [BoxShadow(color: SmashMapColors.shadow, blurRadius: 12, offset: Offset(0, 7))],
                child: Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(face, LikhoColors.surface, .38)!, face]),
                    border: Border.all(color: (open ? SmashMapColors.cream : SmashMapColors.islandTop).withValues(alpha: .85), width: 3),
                  ),
                  child: Text(
                    '$number',
                    style: LikhoFonts.title(size: 38, weight: FontWeight.w800, color: ink).copyWith(height: 1),
                  ),
                ),
              ),
              if (!open)
                Positioned(
                  top: 62,
                  right: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: SmashMapColors.violet,
                      shape: BoxShape.circle,
                      border: Border.all(color: SmashMapColors.islandTop, width: 2),
                    ),
                    child: const Icon(Symbols.lock_rounded, size: 14, fill: 1, color: SmashMapColors.cream),
                  ),
                ),
              if (open)
                Positioned(
                  top: 88,
                  child: Row(
                    children: [
                      for (var k = 0; k < 3; k++)
                        Icon(Symbols.star_rounded, fill: 1, size: k == 1 ? 24 : 20, color: stars > k ? SmashMapColors.goldEdge : SmashMapColors.lilacEdge),
                    ],
                  ),
                ),
              if (current)
                Positioned(
                  top: -guideHeight + 2,
                  left: -22,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<double>(
                      valueListenable: frame,
                      child: Image.asset(SmashMapArt.guide, width: 128, height: guideHeight, fit: BoxFit.contain, excludeFromSemantics: true),
                      builder: (context, t, child) => Transform.translate(offset: Offset(0, -math.sin(t * 2.4) * 4), child: child),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFooter extends StatelessWidget {
  const _MapFooter({required this.completed, required this.total, required this.current, required this.allDone, required this.onPlay});
  final int completed, total, current;
  final bool allDone;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 480;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: narrow ? 120 : 188,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: SmashMapColors.cream.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: LikhoColors.surface.withValues(alpha: .9)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          allDone ? 'Sky explorer!' : '$completed / $total levels complete',
                          maxLines: 1,
                          style: LikhoFonts.body(size: narrow ? 10 : 12, weight: FontWeight.w900, color: SmashMapColors.ink),
                        ),
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completed / total,
                          minHeight: 5,
                          color: SmashMapColors.violet,
                          backgroundColor: SmashMapColors.lilac,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (box.maxWidth > 650)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.swipe_rounded, size: 19, color: SmashMapColors.muted),
                    const SizedBox(width: 7),
                    Text(
                      'Swipe to explore',
                      style: LikhoFonts.body(size: 12, weight: FontWeight.w800, color: SmashMapColors.muted),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: '${allDone ? 'Replay' : 'Play'} level $current',
              child: ExcludeSemantics(
                child: PushButton(
                  key: const ValueKey('ms-levels-play'),
                  onTap: onPlay,
                  color: SmashMapColors.gold,
                  edgeColor: SmashMapColors.goldEdge,
                  edge: 4,
                  width: narrow ? 146 : 190,
                  height: 50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                  innerHighlight: true,
                  shadows: const [BoxShadow(color: SmashMapColors.shadow, blurRadius: 18, offset: Offset(0, 5))],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${allDone ? 'Replay' : 'Play'} level $current',
                            style: LikhoFonts.title(size: narrow ? 19 : 23, weight: FontWeight.w800, color: SmashMapColors.goldInk),
                          ),
                          const SizedBox(width: 7),
                          const Icon(Symbols.play_arrow_rounded, size: 25, fill: 1, color: SmashMapColors.goldInk),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
