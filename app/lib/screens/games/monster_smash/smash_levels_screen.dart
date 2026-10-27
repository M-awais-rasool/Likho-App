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
import '../game_ui.dart';
import 'monster_smash_screen.dart';
import 'ms_backdrop.dart';
import 'ms_camera.dart';
import 'ms_heroes.dart';
import 'ms_scene.dart';

/// Monster Smash's levels (sideways): Letter Land's twelve levels on a
/// winding path over the moving meadow. A finished level shows its stars,
/// the next one to play bounces with Rubby on it, the rest are locked. A
/// level opens the game; its result goes on to the next.
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
  MsCamera? _cam;

  List<MsLevel> get _levels => MsLevels.letterLand;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _ticker = createTicker((t) => _frame.value = t.inMicroseconds / 1e6)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MsSprites.load(createLocalImageConfiguration(context));
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _open(int i) {
    final fb = AppFeedback.of(context)..press();
    final record = ref.read(myGamesProvider)[GameIds.smash] ?? const GameRecord();
    if (!record.opens(_levels[i].number)) {
      fb.nope();
      return;
    }
    Navigator.of(context).push(_route(i));
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
    final stars = record.levels.values.fold(0, (a, b) => a + b);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: LikhoColors.clear),
      child: Material(
        color: MeadowColors.skyLow,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final view = MsView(size, MsBackground.meadow);
            final cam = _cam ??= MsCamera(size);
            cam.screen = size;
            final spots = _spots(size, pad);
            return Stack(
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _frame,
                    builder: (context, t, _) => CustomPaint(
                      painter: MsBackdropPainter(view: view, camera: cam, time: t, scroll: t * 14),
                      foregroundPainter: _PathPainter(spots),
                    ),
                  ),
                ),
                for (var i = 0; i < _levels.length; i++)
                  Positioned(
                    left: spots[i].dx - 34,
                    top: spots[i].dy - 34,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _frame,
                      builder: (context, t, _) => _LevelButton(
                        key: ValueKey('ms-level-${_levels[i].number}'),
                        number: _levels[i].number,
                        stars: record.levels[_levels[i].number] ?? 0,
                        open: record.opens(_levels[i].number),
                        next: i == next,
                        time: t,
                        onTap: () => _open(i),
                      ),
                    ),
                  ),
                Positioned(
                  top: pad.top + 8,
                  left: 12 + pad.left,
                  right: 12 + pad.right,
                  child: Row(
                    children: [
                      PushButton(
                        key: const ValueKey('ms-levels-back'),
                        onTap: () {
                          AppFeedback.of(context).back();
                          widget.onDone();
                        },
                        color: MonsterColors.panel,
                        width: 46,
                        height: 46,
                        shape: const CircleBorder(),
                        shadows: const [BoxShadow(color: MonsterColors.panelShadow, offset: Offset(0, 3), blurRadius: 6)],
                        child: const Icon(Symbols.arrow_back_rounded, size: 26, weight: 700, fill: 1, color: LikhoColors.ink),
                      ),
                      const SizedBox(width: 10),
                      // shrinks on a narrow screen (a moment before it turns sideways)
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GamePill(
                              child: Text(
                                'Monster Smash · ${SmashLevelsScreen.world}',
                                style: LikhoFonts.title(size: 22, weight: FontWeight.w800).copyWith(height: 1.1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GamePill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(MsArt.star, width: 24, height: 24),
                            const SizedBox(width: 5),
                            Text(
                              '$stars / ${_levels.length * 3}',
                              key: const ValueKey('ms-levels-stars'),
                              style: LikhoFonts.title(size: 20, weight: FontWeight.w800).copyWith(height: 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The levels along a gentle wave, left to right.
  List<Offset> _spots(Size size, EdgeInsets pad) {
    final left = pad.left + 70, right = size.width - pad.right - 70;
    final n = _levels.length;
    return [for (var i = 0; i < n; i++) Offset(left + (right - left) * i / (n - 1), size.height * (.5 + .14 * math.sin(i * .95 + .4)))];
  }
}

/// Dotted path between the levels.
class _PathPainter extends CustomPainter {
  _PathPainter(this.spots);
  final List<Offset> spots;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = MonsterColors.panel.withValues(alpha: .9);
    final shade = Paint()..color = MonsterColors.panelShadow;
    for (var i = 0; i + 1 < spots.length; i++) {
      final a = spots[i], b = spots[i + 1];
      final d = b - a, len = d.distance;
      // in the gap between the two buttons only, when it fits three dots
      if (len < 125) continue;
      final u = d / len;
      final from = a + u * 42, to = b - u * 42;
      for (var k = 0; k < 3; k++) {
        final p = Offset.lerp(from, to, (k + .5) / 3)!;
        canvas.drawCircle(p + const Offset(0, 2), 5, shade);
        canvas.drawCircle(p, 5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.spots != spots;
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({super.key, required this.number, required this.stars, required this.open, required this.next, required this.time, required this.onTap});
  final int number, stars;
  final bool open, next;
  final double time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bounce = next ? math.sin(time * 4).abs() : 0.0;
    return SizedBox(
      width: 68,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Transform.scale(
            scale: next ? 1 + .06 * bounce : 1,
            child: PushButton(
              onTap: onTap,
              color: !open ? HeroColors.locked : (stars > 0 ? LikhoColors.success : MonsterColors.ribbon),
              edgeColor: !open ? GameColors.ink15 : (stars > 0 ? GameColors.successDeep : MonsterColors.ribbonDeep),
              edge: 5,
              width: 68,
              height: 68,
              shape: const CircleBorder(),
              innerHighlight: open,
              child: open
                  ? Text(
                      '$number',
                      style: LikhoFonts.title(size: 30, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
                    )
                  : const Icon(Symbols.lock_rounded, size: 28, fill: 1, color: GameColors.ink60),
            ),
          ),
          if (open)
            Positioned(
              top: 70,
              child: Row(
                children: [
                  for (var k = 1; k <= 3; k++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Opacity(
                        opacity: stars >= k ? 1 : .3,
                        child: Image.asset(MsArt.star, width: k == 2 ? 22 : 18),
                      ),
                    ),
                ],
              ),
            ),
          if (next)
            Positioned(
              top: -46 - 14 * bounce,
              child: IgnorePointer(
                child: SizedBox(width: 50, height: 50, child: CustomPaint(painter: _RubbyPainter(time))),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rubby waiting on the next level.
class _RubbyPainter extends CustomPainter {
  _RubbyPainter(this.time);
  final double time;

  @override
  void paint(Canvas canvas, Size size) =>
      MsHeroArt.paint(canvas, MsHero.rubby, size.center(Offset.zero), size.shortestSide * .38, MsHeroLook(face: MsFace.happy, lid: MsHeroArt.blink(time, 0)));

  @override
  bool shouldRepaint(covariant _RubbyPainter old) => true;
}
