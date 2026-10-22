import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/app_controls.dart';
import '../../data/course_providers.dart';
import '../../data/media.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../data/games.dart';
import '../../data/story.dart';
import '../../game/monster_defense/md_engine.dart';
import '../games/monster_defense/md_scene.dart';
import '../stories/story_art.dart';
import '../../design/icon_registry.dart';
import '../../design/tokens.dart';
import '../../dev/reference_overlay.dart';
import '../../mascot/mascot.dart';
import 'boss_painter.dart';
import 'map_geometry.dart';
import 'map_painters.dart';

/// 10 World map, from export/Likho-Prototype.html (screen "map", 390 x 844).
///
/// One tall scroll (world 1 at the bottom, the last world at the top), each
/// world in its own colours and scenery. On open it
/// starts at the bottom and, after 250 ms, glides so the current level sits
/// at 55 % of the screen. Nodes pop in, staggered by distance from the
/// current level; the mascot stands on the current level.
class WorldMapScreen extends ConsumerStatefulWidget {
  const WorldMapScreen({super.key, this.onOpenLevel, this.onProfile, this.onRoom, this.onSettings, this.onStories, this.onGames});

  /// Tapped an unlocked level (Gameplay is the next screen to build).
  final ValueChanged<int>? onOpenLevel;
  final VoidCallback? onProfile;
  final VoidCallback? onRoom;
  final VoidCallback? onSettings;

  /// Stories (the button under Pencil's room).
  final VoidCallback? onStories;

  /// Games (the button under Stories).
  final VoidCallback? onGames;

  static const String reference = 'assets/reference/screens/world_map.png';

  @override
  ConsumerState<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends ConsumerState<WorldMapScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0); // seconds since the map opened
  final ScrollController _scroll = ScrollController();
  MapGeometry? _geometry;
  List<List<MapDeco>>? _decosByWorld;
  bool _scrolled = false;

  /// Boss levels already seen beaten (for [_seenFor]) while the app runs. A
  /// boss beaten since (the child just won it) wakes up and dances once.
  static Set<int>? _seenBeaten;
  static String? _seenFor;

  /// Boss level -> clock time it wakes up on this map.
  final Map<int, double> _celebrations = {};

  void _noteBeaten(Course course, ChildProgress progress) {
    final beaten = {for (final l in course.levels) if (l.isBoss && progress.isDone(l.number)) l.number};
    final seen = _seenBeaten;
    if (seen == null || _seenFor != progress.name) {
      _seenBeaten = beaten;
      _seenFor = progress.name;
      return;
    }
    for (final n in beaten.difference(seen)) {
      // only the boss just won: its world's next level is the current one
      if (progress.current == n + 1) _celebrations[n] = _time.value + 1.0; // once the glide has ended
    }
    seen.addAll(beaten);
  }

  final MascotController _mapMascot = MascotController();
  final MascotController _avatarMascot = MascotController();
  final MascotController _roomMascot = MascotController();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
    // the room button shows Pencil cheering (prototype expr "happy"): arms up, laughing
    _roomMascot.showFrame(MascotState.happy, .9);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _scroll.dispose();
    _mapMascot.dispose();
    _avatarMascot.dispose();
    _roomMascot.dispose();
    super.dispose();
  }

  MapGeometry _geometryFor(double width, Course course) {
    final perWorld = [for (final w in course.worlds) course.levelsOf(w).length];
    final g = _geometry;
    if (g != null && g.width == width && listEquals(g.levelsPerWorld, perWorld)) return g;
    final ng = MapGeometry(width, levelsPerWorld: perWorld, decoKinds: [for (final w in course.worlds) LikhoWorlds.indexOf(w.themeId)]);
    final decos = ng.decorations();
    _decosByWorld = [for (var w = 0; w < ng.worlds; w++) decos.where((d) => d.world == w).toList()];
    return _geometry = ng;
  }

  /// Reverse list: offset 0 = bottom of the map. Glide to the current level.
  void _scrollToCurrent(MapGeometry g, double viewport, int current) {
    if (_scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted || !_scroll.hasClients) return;
        final fromTop = g.scrollFor(current, viewport);
        final target = g.height - viewport - fromTop;
        _scroll.animateTo(target, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      });
    });
  }

  /// The levels whose pictures and recordings are being fetched ahead.
  int? _fetchedFrom;

  /// Downloads the current level's and the next two levels' media in the
  /// background, so they start without waiting (and play offline later).
  void _fetchAhead(Course course, int current) {
    if (_fetchedFrom == current) return;
    _fetchedFrom = current;
    final media = ref.read(mediaProvider);
    for (final l in course.levels.where((l) => l.number >= current && l.number < current + 3)) {
      media.prefetchLevel(l);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final current = progress.current;
    final course = ref.watch(courseProvider).value;
    // App controls: Pencil's room and Stories can be switched off
    final roomOn = ref.watch(featureShownProvider(Feature.room));
    final storiesOn = ref.watch(storiesShownProvider);
    final gamesOn = ref.watch(gamesShownProvider);
    if (course != null) {
      _fetchAhead(course, current);
      _noteBeaten(course, progress);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: LikhoColors.clear),
      child: ReferenceOverlay(
        asset: WorldMapScreen.reference,
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(builder: (context, box) {
            // still loading (Splash normally preloads it): plain app background
            if (course == null) return const SizedBox.expand(child: ColoredBox(color: LikhoColors.background));
            final g = _geometryFor(box.maxWidth, course);
            _scrollToCurrent(g, box.maxHeight, current);
            final sections = [for (var w = 0; w < g.worlds; w++) g.section(w)];
            return Stack(
              children: [
                ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: EdgeInsets.zero,
                  itemCount: g.worlds,
                  itemExtentBuilder: (i, _) => i < g.worlds ? sections[i].$2 : null,
                  itemBuilder: (context, w) => RepaintBoundary(
                    child: _WorldSection(
                      course: course,
                      world: w,
                      top: sections[w].$1,
                      height: sections[w].$2,
                      geometry: g,
                      decos: _decosByWorld![w],
                      progress: progress,
                      time: _time,
                      mascot: _mapMascot,
                      celebrations: _celebrations,
                      onOpenLevel: widget.onOpenLevel,
                    ),
                  ),
                ),
                const _TopFade(),
                _Header(
                  progress: progress,
                  avatar: _avatarMascot,
                  room: _roomMascot,
                  onProfile: widget.onProfile,
                  onRoom: roomOn ? widget.onRoom : null,
                  showRoom: roomOn,
                  onSettings: widget.onSettings,
                ),
                if (widget.onStories != null && storiesOn)
                  Positioned(
                    right: 74,
                    // under Pencil's room, or in its place when the room is off
                    top: MediaQuery.paddingOf(context).top + 5 + (roomOn ? 64 + 14 : 0),
                    child: _StoriesButton(time: _time, fresh: ref.watch(myStoryStarsProvider).isEmpty, onTap: widget.onStories!),
                  ),
                if (widget.onGames != null && gamesOn)
                  Positioned(
                    right: 74,
                    // under Stories (and the room), moving up when they are off
                    top: MediaQuery.paddingOf(context).top + 5 + (roomOn ? 64 + 14 : 0) + (widget.onStories != null && storiesOn ? 64 + 14 : 0),
                    child: _GamesButton(time: _time, fresh: ref.watch(myGamesProvider).isEmpty, onTap: widget.onGames!),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ world section

class _WorldSection extends StatelessWidget {
  const _WorldSection({
    required this.course,
    required this.world,
    required this.top,
    required this.height,
    required this.geometry,
    required this.decos,
    required this.progress,
    required this.time,
    required this.mascot,
    required this.celebrations,
    required this.onOpenLevel,
  });

  final Course course;
  final int world;
  final double top, height;
  final MapGeometry geometry;
  final List<MapDeco> decos;
  final ChildProgress progress;
  final ValueNotifier<double> time;
  final MascotController mascot;
  final Map<int, double> celebrations;
  final ValueChanged<int>? onOpenLevel;

  @override
  Widget build(BuildContext context) {
    final info = course.worlds[world];
    final theme = LikhoWorlds.byId(info.themeId);
    final current = progress.current;
    // the world sits on a cloud bank (its bottom edge); the bank on its top
    // edge is the next world's
    final bankY = geometry.worldBottom(world) - top;
    final seams = [(bankY, world), if (world < geometry.worlds - 1) (0.0, world + 1)];
    // the world's sign sits on its cloud bank, beside the path
    final cross = geometry.crossingX(world);
    final signLeft = cross >= geometry.width / 2;
    final room = (signLeft ? cross - 16 : geometry.width - cross - 16) - 13 - 10;
    final levels = course.levelsOf(info);
    final inWorld = levels.isNotEmpty && current >= levels.first.number && current <= levels.last.number;
    final children = <Widget>[
      Positioned.fill(child: CustomPaint(painter: SectionBackgroundPainter(color: theme.bg, sky: theme.sky))),
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: SceneryPainter(theme: theme, seed: world, contentLeft: geometry.offsetX, contentWidth: geometry.contentWidth)),
        ),
      ),
      Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: DecorationPainter(decos: decos, sectionTop: top, time: time)))),
      Positioned.fill(child: CustomPaint(painter: MapPathPainter(geometry: geometry, sectionTop: top))),
      Positioned.fill(child: CustomPaint(painter: CloudBankPainter(seams: seams))),
      Positioned(
        left: signLeft ? 16 : null,
        right: signLeft ? null : 16,
        top: bankY - 58,
        height: 52,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.max(room, 120)),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: signLeft ? Alignment.centerLeft : Alignment.centerRight, child: _WorldSign(index: world, world: info, theme: theme)),
        ),
      ),
    ];
    Widget? mascotOnTop;
    for (final level in levels) {
      final n = level.number;
      final c = geometry.node(n) - Offset(0, top);
      final done = progress.isDone(n);
      final isCur = n == current && !done;
      if (level.isBoss) {
        children.add(Positioned(
          left: c.dx + (c.dx > geometry.width / 2 ? -150 : 60),
          top: c.dy - 66,
          width: 96,
          height: 80,
          child: _MapBoss(
            boss: BossPainter.indexOf(info.bossId),
            beaten: done,
            // the boss of the child's world dozes and peeks; later ones sleep
            dozing: inWorld,
            wokeAt: celebrations[n],
            time: time,
          ),
        ));
      }
      if (isCur) {
        children.add(Positioned(
          left: c.dx - 44,
          top: c.dy - 44,
          width: 88,
          height: 88,
          child: IgnorePointer(child: CustomPaint(painter: PulsePainter(time: time))),
        ));
      }
      children.add(_LevelNode(
        level: level,
        centre: c,
        theme: theme,
        done: done,
        isCurrent: isCur,
        unlocked: progress.isUnlocked(n),
        stars: progress.levelStars[n] ?? 0,
        popDelay: math.min((n - current).abs() * .055, .7),
        time: time,
        onOpen: onOpenLevel,
      ));
      if (n == current) {
        // stands on the current level: box 60 x 86, feet on the node's top
        // edge. When the next level is just above, he steps to the other
        // side of the node so it never covers him.
        final r = level.isBoss ? 50.0 : (isCur ? 44.0 : 36.0); // _LevelNode sizes
        final ahead = n < geometry.levels ? geometry.node(n + 1) - Offset(0, top) : null;
        final dx = ahead == null || (ahead.dx - c.dx).abs() > 90 ? 0.0 : (ahead.dx >= c.dx ? -22.0 : 22.0);
        final rim = math.sqrt(r * r - dx * dx);
        mascotOnTop = Positioned(
          left: c.dx + dx - 30,
          top: c.dy - rim - 86 + 2,
          width: 60,
          height: 86,
          child: IgnorePointer(
            child: _PopIn(
              time: time,
              delay: .5,
              seconds: .5,
              child: OverflowBox(maxWidth: 80, child: PencilMascot(controller: mascot, size: 86)),
            ),
          ),
        );
      }
    }
    // Pencil goes over every node of the section
    if (mascotOnTop != null) children.add(mascotOnTop);
    return SizedBox(height: height, child: Stack(clipBehavior: Clip.none, children: children));
  }
}

/// The world's sign on its cloud bank: a chunky button-like plate in the
/// world's colour (the same 3D edge as the level nodes), the world's icon
/// in a white disc, "WORLD 9" and the name.
class _WorldSign extends StatelessWidget {
  const _WorldSign({required this.index, required this.world, required this.theme});
  final int index;
  final CourseWorld world;
  final WorldTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 6, right: 18, bottom: 4),
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: MapColors.cloudWhite, width: 2.5),
        boxShadow: [BoxShadow(color: t.deep, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: MapColors.cloudWhite, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(IconRegistry.of(world.icon), size: 22, fill: 1, weight: 700, opticalSize: 22, color: t.accent),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WORLD ${index + 1}',
                style: LikhoFonts.body(size: 10.5, weight: FontWeight.w800, color: LikhoColors.surface.withValues(alpha: .85))
                    .copyWith(height: 1.1, letterSpacing: 1.2),
              ),
              Text(world.name, style: LikhoFonts.title(size: 17, color: LikhoColors.surface).copyWith(height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A world boss on the map. Not beaten: asleep, or dozing and peeking when
/// it is the boss of the child's world. Beaten: awake, blinking and waving;
/// just beaten ([wokeAt]): wakes up and dances first. A tap startles it.
class _MapBoss extends StatefulWidget {
  const _MapBoss({required this.boss, required this.beaten, required this.dozing, required this.wokeAt, required this.time});
  final int boss;
  final bool beaten, dozing;
  final double? wokeAt;
  final ValueNotifier<double> time;

  @override
  State<_MapBoss> createState() => _MapBossState();
}

class _MapBossState extends State<_MapBoss> {
  double? _pokedAt;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _pokedAt = widget.time.value);
        },
        child: CustomPaint(
          painter: BossPainter(
            world: widget.boss,
            awake: widget.beaten,
            dance: widget.wokeAt != null,
            danceFor: 6,
            wokeAt: widget.wokeAt,
            dozing: widget.dozing,
            pokedAt: _pokedAt,
            time: widget.time,
          ),
        ),
      );
}

// ------------------------------------------------------------------ level node

class _LevelNode extends StatefulWidget {
  const _LevelNode({
    required this.level,
    required this.centre,
    required this.theme,
    required this.done,
    required this.isCurrent,
    required this.unlocked,
    required this.stars,
    required this.popDelay,
    required this.time,
    required this.onOpen,
  });

  final CourseLevel level;
  final Offset centre;
  final WorldTheme theme;
  final bool done, isCurrent, unlocked;
  final int stars;
  final double popDelay;
  final ValueNotifier<double> time;
  final ValueChanged<int>? onOpen;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(vsync: this);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _tap() {
    if (!widget.unlocked) {
      // locked: wiggle 0 -> -10 -> 8 -> -4 -> 0 deg in 400 ms
      _press
        ..duration = const Duration(milliseconds: 400)
        ..forward(from: 0);
      return;
    }
    _press
      ..duration = const Duration(milliseconds: 220)
      ..forward(from: 0);
    final open = widget.onOpen;
    if (open != null) Future.delayed(const Duration(milliseconds: 160), () => open(widget.level.number));
  }

  @override
  Widget build(BuildContext context) {
    final boss = widget.level.isBoss;
    final size = boss ? 100.0 : widget.isCurrent ? 88.0 : 72.0;
    final dark = widget.theme.dark;
    final bg = widget.isCurrent
        ? LikhoColors.primary
        : widget.done
            ? widget.theme.accent
            : dark
                ? MapColors.nodeLockedDark
                : MapColors.nodeLocked;
    final deep = widget.isCurrent
        ? LikhoColors.primaryDeep
        : widget.done
            ? widget.theme.deep
            : dark
                ? MapColors.nodeLockedDarkDeep
                : MapColors.nodeLockedDeep;
    final fg = widget.isCurrent
        ? LikhoColors.ink
        : widget.done
            ? LikhoColors.surface
            : dark
                ? MapColors.iconLockedDark
                : MapColors.iconLocked;
    final iconSize = boss ? 44.0 : widget.isCurrent ? 40.0 : 32.0;
    final c = widget.centre;
    const starsW = 22.0 * 3 + 2;
    return Positioned(
      left: c.dx - size / 2 - starsW,
      top: c.dy - size / 2,
      width: size + 2 * starsW,
      height: size + 36,
      child: _PopIn(
        time: widget.time,
        delay: widget.popDelay,
        seconds: .4,
        origin: Alignment(0, -1 + size / (size + 36)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: starsW,
              top: 0,
              width: size,
              height: size,
              child: GestureDetector(
                onTap: _tap,
                child: AnimatedBuilder(
                  animation: _press,
                  builder: (context, child) {
                    final v = _press.value;
                    if (!widget.unlocked) {
                      const keys = [0.0, -10.0, 8.0, -4.0, 0.0];
                      final i = (v * 4).floor().clamp(0, 3);
                      final deg = keys[i] + (keys[i + 1] - keys[i]) * (v * 4 - i);
                      return Transform.rotate(angle: deg * math.pi / 180, child: child);
                    }
                    const keys = [1.0, .9, 1.06, 1.0];
                    final i = (v * 3).floor().clamp(0, 2);
                    final s = keys[i] + (keys[i + 1] - keys[i]) * (v * 3 - i);
                    return Transform.scale(scale: s, child: child);
                  },
                  child: CustomPaint(
                    painter: NodePainter(color: bg, deep: deep),
                    child: Center(
                      child: widget.unlocked
                          ? Icon(IconRegistry.of(widget.level.icon), size: iconSize, fill: 1, opticalSize: math.min(48, iconSize), color: fg)
                          : Icon(Symbols.lock_rounded, size: 30, fill: 1, opticalSize: 30, color: fg),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.done)
              Positioned(
                left: starsW + size / 2 - starsW / 2,
                top: size + 4,
                width: starsW,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var k = 1; k <= 3; k++) ...[
                      if (k > 1) const SizedBox(width: 1),
                      Transform.translate(
                        offset: Offset(0, k == 2 ? -5 : 0),
                        child: Icon(
                          Symbols.star_rounded,
                          size: 22,
                          fill: 1,
                          opticalSize: 22,
                          color: widget.stars >= k ? LikhoColors.primary : MapColors.starOff,
                          shadows: const [Shadow(color: MapColors.starShadow, offset: Offset(0, 1))],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// popIn: scale 0 -> 1.1 (70 %) -> 1, cubic-bezier(.34,1.56,.64,1).
/// Stops listening to the clock once it has finished.
class _PopIn extends StatefulWidget {
  const _PopIn({required this.time, required this.delay, required this.seconds, required this.child, this.origin = Alignment.center});
  final ValueNotifier<double> time;
  final double delay, seconds;
  final Widget child;
  final Alignment origin;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> {
  static const _curve = Cubic(.34, 1.56, .64, 1);
  double _p = 0;

  @override
  void initState() {
    super.initState();
    _p = _progress();
    if (_p < 1) widget.time.addListener(_tick);
  }

  double _progress() => ((widget.time.value - widget.delay) / widget.seconds).clamp(0.0, 1.0);

  void _tick() {
    final p = _progress();
    if (p >= 1) widget.time.removeListener(_tick);
    if (p != _p) setState(() => _p = p);
  }

  @override
  void dispose() {
    widget.time.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_p >= 1) return widget.child;
    final s = _p < .7 ? 1.1 * _curve.transform(_p / .7) : 1.1 - .1 * _curve.transform((_p - .7) / .3);
    return Transform.scale(scale: s, alignment: widget.origin, child: widget.child);
  }
}

// ------------------------------------------------------------------ header

class _TopFade extends StatelessWidget {
  const _TopFade();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 130,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [MapColors.topFade, MapColors.topFade, MapColors.topFadeClear],
              stops: [0, .4, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar, star count, room button (Pencil cheering), settings.
/// Prototype: row at top 52 px of the 844 frame = 5 px below its 47 px status bar.
class _Header extends StatelessWidget {
  const _Header({
    required this.progress,
    required this.avatar,
    required this.room,
    this.onProfile,
    this.onRoom,
    this.showRoom = true,
    this.onSettings,
  });

  final ChildProgress progress;
  final MascotController avatar, room;
  final VoidCallback? onProfile, onRoom, onSettings;
  final bool showRoom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 5;
    return Positioned(
      left: 20,
      right: 20,
      top: top,
      child: Row(
        children: [
          _Pressable(
            onTap: onProfile,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: progress.color.tint,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: LikhoColors.shadowSoft, offset: Offset(0, 4)),
                  BoxShadow(color: LikhoColors.surface, spreadRadius: 3),
                ],
              ),
              child: ClipOval(
                child: Stack(children: [
                  Positioned(left: 10, top: 6, width: 38, height: 54, child: OverflowBox(maxWidth: 50, child: PencilMascot(controller: avatar, size: 54))),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 46,
            padding: const EdgeInsets.only(left: 10, right: 16),
            decoration: BoxDecoration(
              color: LikhoColors.surface,
              borderRadius: BorderRadius.circular(23),
              boxShadow: const [BoxShadow(color: LikhoColors.shadowFaint, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // inherits font-weight 800 (axis max 700) from the pill in the prototype
                const Icon(Symbols.star_rounded, size: 28, fill: 1, weight: 700, opticalSize: 28, color: LikhoColors.primary),
                const SizedBox(width: 6),
                Text('${progress.stars}', style: LikhoFonts.title(size: 22, weight: FontWeight.w800).copyWith(height: 1)),
              ],
            ),
          ),
          const Spacer(),
          if (showRoom)
            _Pressable(
              onTap: onRoom,
              pressOffset: 3,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: LikhoColors.primary,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [BoxShadow(color: LikhoColors.primaryDeep, offset: Offset(0, 5))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(children: [
                    Positioned(left: 8, top: 6, width: 48, height: 68, child: OverflowBox(maxWidth: 60, child: PencilMascot(controller: room, size: 68))),
                  ]),
                ),
              ),
            ),
          const SizedBox(width: 10),
          _Pressable(
            onTap: onSettings,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: MapColors.settingsBg, shape: BoxShape.circle),
              child: const Icon(Symbols.settings_rounded, size: 22, opticalSize: 22, color: LikhoColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stories, under Pencil's room: a blue button with a shiny apple and
/// "Stories"; "NEW" (and a little hop) until the child has played one.
class _StoriesButton extends StatelessWidget {
  const _StoriesButton({required this.time, required this.fresh, required this.onTap});
  final ValueNotifier<double> time;
  final bool fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Pressable(
    key: const ValueKey('stories-button'),
    onTap: onTap,
    pressOffset: 3,
    child: ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, child) => Transform.translate(offset: Offset(0, fresh ? -math.max(0, math.sin(t * 3)) * 3 : 0), child: child),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: LikhoColors.secondary,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: GameColors.secondaryDeep, offset: Offset(0, 5))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 34, height: 32, child: Image.asset(StoryArt.prop('a', 'apple_leaf'), fit: BoxFit.contain)),
                const SizedBox(height: 1),
                Text('Stories', style: LikhoFonts.title(size: 12.5, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1)),
              ],
            ),
          ),
          if (fresh)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: LikhoColors.hint, borderRadius: BorderRadius.circular(10), border: Border.all(color: LikhoColors.surface, width: 2)),
                child: Text('NEW', style: LikhoFonts.title(size: 11, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1)),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Games, under Stories: a violet button with Gloop waving and "Games";
/// "NEW" (and a little hop) until the child has played one.
class _GamesButton extends StatelessWidget {
  const _GamesButton({required this.time, required this.fresh, required this.onTap});
  final ValueNotifier<double> time;
  final bool fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Pressable(
    key: const ValueKey('games-button'),
    onTap: onTap,
    pressOffset: 3,
    child: ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, child) => Transform.translate(offset: Offset(0, fresh ? -math.max(0, math.sin(t * 3 + 1.5)) * 3 : 0), child: child),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: MonsterColors.ribbon,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: MonsterColors.ribbonDeep, offset: Offset(0, 5))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 36, height: 33, child: Image.asset(MdArt.pose(MdKind.gloop, 'friendly'), fit: BoxFit.contain)),
                const SizedBox(height: 1),
                Text('Games', style: LikhoFonts.title(size: 12.5, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1)),
              ],
            ),
          ),
          if (fresh)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: LikhoColors.hint, borderRadius: BorderRadius.circular(10), border: Border.all(color: LikhoColors.surface, width: 2)),
                child: Text('NEW', style: LikhoFonts.title(size: 11, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1)),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Press feedback from the prototype: scale(.9), or translateY for the room button.
class _Pressable extends StatefulWidget {
  const _Pressable({super.key, required this.child, this.onTap, this.pressOffset});
  final Widget child;
  final VoidCallback? onTap;
  final double? pressOffset;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final off = widget.pressOffset;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: _down
            ? (off != null ? Matrix4.translationValues(0, off, 0) : Matrix4.diagonal3Values(.9, .9, 1))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
