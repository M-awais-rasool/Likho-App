import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/app_controls.dart';
import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../data/media.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../data/games.dart';
import '../../data/story.dart';
import '../../game/monster_defense/md_engine.dart';
import '../games/monster_defense/md_scene.dart';
import '../home/home_tabs.dart';
import '../stories/story_art.dart';
import '../../design/icon_registry.dart';
import '../../design/motion.dart' show reduceMotionProvider;
import 'journey_scenery.dart';
import '../../design/tokens.dart';
import '../../dev/reference_overlay.dart';
import '../../mascot/mascot.dart';
import 'boss_painter.dart';
import 'map_geometry.dart';
import 'map_painters.dart';

/// A continuous storybook journey. The route, scenery and character share
/// one coordinate system; world colours blend as the camera crosses a seam.
class WorldMapScreen extends ConsumerStatefulWidget {
  const WorldMapScreen({super.key, this.onOpenLevel, this.onProfile, this.onRoom, this.onSettings, this.onStories, this.onGames});

  /// Opens an unlocked lesson through the existing app flow.
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
  Duration _lastTick = Duration.zero;
  final ValueNotifier<double> _time = ValueNotifier(0); // seconds since the map opened
  // The drifting fireflies and seam haze, stepped ~20 times a second. They
  // move far too slowly to be worth a repaint of the whole world section on
  // every frame, and that repaint was costing a mid-range phone half its
  // frame budget while the map scrolled.
  final ValueNotifier<double> _ambient = ValueNotifier(0);
  double _ambientAt = 0;
  final ScrollController _scroll = ScrollController();
  MapGeometry? _geometry;
  final ValueNotifier<int> _visibleWorld = ValueNotifier(0);
  final ValueNotifier<bool> _awayFromCurrent = ValueNotifier(false);
  bool _reduceMotion = false;
  double _viewport = 0;
  double _focusY = 0;
  double _safeTop = 180;
  int _current = 1;
  String? _cameraKey;
  MapGeometry? _cameraGeometry;

  /// Boss levels already seen beaten (for [_seenFor]) while the app runs. A
  /// boss beaten since (the child just won it) wakes up and dances once.
  static Set<int>? _seenBeaten;
  static String? _seenFor;

  /// Boss level -> clock time it wakes up on this map.
  final Map<int, double> _celebrations = {};

  void _noteBeaten(Course course, ChildProgress progress, String learner) {
    final beaten = {
      for (final l in course.levels)
        if (l.isBoss && progress.isDone(l.number)) l.number,
    };
    final seen = _seenBeaten;
    if (seen == null || _seenFor != learner) {
      _seenBeaten = beaten;
      _seenFor = learner;
      return;
    }
    for (final n in beaten.difference(seen)) {
      // only the boss just won: its world's next level is the current one
      if (progress.current == n + 1) _celebrations[n] = _time.value + 1.0;
    }
    seen.addAll(beaten);
  }

  final MascotController _mapMascot = MascotController();
  final MascotController _avatarMascot = MascotController();
  final MascotController _roomMascot = MascotController();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      final step = (e - _lastTick).inMicroseconds / 1e6;
      _lastTick = e;
      // Resume gently after a lesson or another tab has muted this ticker.
      if (!_reduceMotion) {
        _time.value += step.clamp(0.0, .1);
        if (_time.value - _ambientAt >= .05) {
          _ambientAt = _time.value;
          _ambient.value = _time.value;
        }
      }
    })..start();
    _scroll.addListener(_trackCamera);
    // the room button shows Pencil cheering (prototype expr "happy"): arms up, laughing
    _roomMascot.showFrame(MascotState.happy, .9);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _ambient.dispose();
    _scroll.dispose();
    _visibleWorld.dispose();
    _awayFromCurrent.dispose();
    _mapMascot.dispose();
    _avatarMascot.dispose();
    _roomMascot.dispose();
    super.dispose();
  }

  MapGeometry _geometryFor(double width, Course course) {
    final perWorld = [for (final w in course.worlds) course.levelsOf(w).length];
    final g = _geometry;
    if (g != null && g.width == width && listEquals(g.levelsPerWorld, perWorld)) return g;
    return _geometry = MapGeometry(width, levelsPerWorld: perWorld);
  }

  void _trackCamera() {
    final g = _geometry;
    if (g == null || !_scroll.hasClients || g.levels == 0) return;
    final focus = g.height - _viewport - _scroll.offset + _focusY;
    _visibleWorld.value = g.worldAt(focus);
    final currentY = g.node(_current.clamp(1, g.levels)).dy - focus + _focusY;
    _awayFromCurrent.value = currentY < _safeTop + 40 || currentY > _viewport - 50;
  }

  void _goToCurrent({bool entrance = false}) {
    final g = _geometry;
    if (g == null || !_scroll.hasClients || g.levels == 0) return;
    final target = (g.height - _viewport - g.scrollFor(_current, _viewport, focusY: _focusY)).clamp(0.0, _scroll.position.maxScrollExtent);
    if (_reduceMotion) {
      _scroll.jumpTo(target);
    } else {
      // Start close to the learner; don't fly through hundreds of lessons.
      final arrivingInWorld = entrance && _celebrations.containsKey(_current - 1);
      if (entrance) {
        final start = arrivingInWorld ? g.height - _viewport - g.scrollFor(_current - 1, _viewport, focusY: _focusY) : target - 56;
        _scroll.jumpTo(start.clamp(0.0, _scroll.position.maxScrollExtent));
      }
      _scroll.animateTo(
        target,
        duration: Duration(
          milliseconds: arrivingInWorld
              ? 1800
              : entrance
              ? 850
              : 1100,
        ),
        curve: Curves.easeInOutCubic,
      );
    }
    _trackCamera();
  }

  void _scrollToCurrent(MapGeometry g, double viewport, int current, String learner) {
    // On short phones the HUD and bottom tabs leave less space. Keep
    // Pencil's entire silhouette below the card, including accessories.
    _focusY = math.max(viewport * .55, math.min(_safeTop + 120, viewport - 100));
    final key = '$learner:$current:$viewport:$_focusY';
    _viewport = viewport;
    _current = current;
    // Progress arrives while the lesson route still covers the map. Save
    // the camera journey for the moment the child returns to this screen.
    if (!TickerMode.valuesOf(context).enabled) return;
    if (_cameraKey == key && _cameraGeometry == g) return;
    _cameraKey = key;
    _cameraGeometry = g;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goToCurrent(entrance: true);
    });
  }

  void _dressMascots(ChildProgress progress) {
    for (final mascot in [_mapMascot, _avatarMascot, _roomMascot]) {
      if (mascot.swatch.key != progress.color.key) mascot.setBodyColor(progress.color.key);
      if (mascot.accessory != progress.accessory) {
        if (progress.accessory case final accessory?) {
          mascot.wear(accessory);
        } else {
          mascot.removeAccessory();
        }
      }
    }
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
    _reduceMotion = ref.watch(reduceMotionProvider) || MediaQuery.disableAnimationsOf(context);
    _dressMascots(progress);
    final course = ref.watch(courseProvider).value;
    final learner = '${ref.watch(familyProvider.select((f) => f.activeId))}:${course?.id}';
    _safeTop = MediaQuery.paddingOf(context).top + 180;
    // App controls: Pencil's room and Stories can be switched off
    final roomOn = ref.watch(featureShownProvider(Feature.room));
    final storiesOn = ref.watch(storiesShownProvider);
    final gamesOn = ref.watch(gamesShownProvider);
    // Secondary shortcuts sit below the journey card.
    const sideRight = 16.0;
    if (course != null) {
      _fetchAhead(course, current);
      _noteBeaten(course, progress, learner);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LikhoSystemBars.dark,
      child: ReferenceOverlay(
        asset: WorldMapScreen.reference,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: _reduceMotion),
          child: TickerMode(
            enabled: !_reduceMotion,
            child: Material(
              type: MaterialType.transparency,
              child: LayoutBuilder(
                builder: (context, box) {
                  // still loading (Splash normally preloads it): plain app background
                  if (course == null) return const SizedBox.expand(child: ColoredBox(color: LikhoColors.background));
                  final g = _geometryFor(box.maxWidth, course);
                  // the bottom bar covers the map's bottom: the levels stay above it
                  final barInset = TabBarInset.of(context);
                  _scrollToCurrent(g, box.maxHeight - barInset, current, learner);
                  final sections = [for (var w = 0; w < g.worlds; w++) g.section(w)];
                  return Stack(
                    children: [
                      // The ground behind the map: the strip the bottom bar
                      // leaves free (and an overscroll bounce) would show the
                      // bare window — black on a phone — without it.
                      Positioned.fill(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _visibleWorld,
                          builder: (context, visible, _) {
                            final info = course.worlds[visible.clamp(0, course.worlds.length - 1)];
                            return ColoredBox(color: JourneyPalette.of(LikhoWorlds.byId(info.themeId)).ground);
                          },
                        ),
                      ),
                      ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: EdgeInsets.only(bottom: barInset),
                        itemCount: g.worlds,
                        itemExtentBuilder: (i, _) => i < g.worlds ? sections[i].$2 : null,
                        itemBuilder: (context, w) => RepaintBoundary(
                          child: _WorldSection(
                            course: course,
                            world: w,
                            top: sections[w].$1,
                            height: sections[w].$2,
                            geometry: g,
                            progress: progress,
                            time: _time,
                            ambient: _ambient,
                            mascot: _mapMascot,
                            celebrations: _celebrations,
                            onOpenLevel: widget.onOpenLevel,
                          ),
                        ),
                      ),
                      const _TopFade(),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: MediaQuery.paddingOf(context).top + 68,
                        child: ValueListenableBuilder<int>(
                          valueListenable: _visibleWorld,
                          builder: (context, visible, _) => _JourneyCard(
                            course: course,
                            world: visible.clamp(0, math.max(0, course.worlds.length - 1)),
                            progress: progress,
                            reduceMotion: _reduceMotion,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 18,
                        bottom: barInset + 22 + (barInset == 0 ? MediaQuery.paddingOf(context).bottom : 0),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _awayFromCurrent,
                          builder: (context, away, _) => IgnorePointer(
                            ignoring: !away,
                            child: AnimatedOpacity(
                              opacity: away ? 1 : 0,
                              duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
                              child: Semantics(
                                button: true,
                                label: 'Return to current level',
                                child: _Pressable(
                                  onTap: _goToCurrent,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFCF2),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: const [BoxShadow(color: Color(0x263D4932), blurRadius: 16, offset: Offset(0, 5))],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Symbols.near_me_rounded, size: 22, color: Color(0xFF527C59), fill: 1),
                                        const SizedBox(width: 6),
                                        Text('My level', style: LikhoFonts.body(size: 13, weight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                          right: sideRight,
                          // under Pencil's room, or in its place when the room is off
                          top: MediaQuery.paddingOf(context).top + 170,
                          child: _StoriesButton(time: _time, fresh: ref.watch(newEpisodesProvider).isNotEmpty, onTap: widget.onStories!),
                        ),
                      if (widget.onGames != null && gamesOn)
                        Positioned(
                          right: sideRight,
                          // under Stories (and the room), moving up when they are off
                          top: MediaQuery.paddingOf(context).top + 170 + (widget.onStories != null && storiesOn ? 78 : 0),
                          child: _GamesButton(time: _time, fresh: ref.watch(newGamesProvider).isNotEmpty, onTap: widget.onGames!),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
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
    required this.progress,
    required this.time,
    required this.ambient,
    required this.mascot,
    required this.celebrations,
    required this.onOpenLevel,
  });

  final Course course;
  final int world;
  final double top, height;
  final MapGeometry geometry;
  final ChildProgress progress;
  final ValueNotifier<double> time;
  final ValueNotifier<double> ambient;
  final MascotController mascot;
  final Map<int, double> celebrations;
  final ValueChanged<int>? onOpenLevel;

  @override
  Widget build(BuildContext context) {
    final info = course.worlds[world];
    final theme = LikhoWorlds.byId(info.themeId);
    final current = progress.current;
    final bankY = geometry.worldBottom(world) - top;
    final levels = course.levelsOf(info);
    final inWorld = levels.isNotEmpty && current >= levels.first.number && current <= levels.last.number;
    final children = <Widget>[
      Positioned.fill(
        child: CustomPaint(
          painter: JourneyGroundPainter(
            theme: theme,
            above: world + 1 < course.worlds.length ? LikhoWorlds.byId(course.worlds[world + 1].themeId) : null,
            below: world > 0 ? LikhoWorlds.byId(course.worlds[world - 1].themeId) : null,
          ),
        ),
      ),
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: MapPathPainter(geometry: geometry, sectionTop: top),
          ),
        ),
      ),
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: JourneySceneryPainter(theme: theme, geometry: geometry, world: world, sectionTop: top),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: bankY - 64,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: geometry.contentWidth - 32),
            child: _WorldSign(index: world, world: info, theme: theme),
          ),
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
        children.add(
          Positioned(
            left: c.dx + (c.dx > geometry.width / 2 ? -125 : 52),
            top: c.dy - 66,
            width: 76,
            height: 68,
            child: _MapBoss(
              boss: BossPainter.indexOf(info.bossId),
              beaten: done,
              // the boss of the child's world dozes and peeks; later ones sleep
              dozing: inWorld,
              wokeAt: celebrations[n],
              time: time,
            ),
          ),
        );
      }
      if (isCur) {
        children.add(
          Positioned(
            left: c.dx - 44,
            top: c.dy - 44,
            width: 88,
            height: 88,
            child: IgnorePointer(
              child: CustomPaint(painter: PulsePainter(time: time)),
            ),
          ),
        );
      }
      children.add(
        _LevelNode(
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
        ),
      );
      if (n == current) {
        // Feet land inside the tile's upper rim. The taller route spacing
        // leaves a clear silhouette, including hats, below the next node.
        mascotOnTop = Positioned(
          left: c.dx - 33,
          top: c.dy - 112,
          width: 66,
          height: 86,
          child: IgnorePointer(
            child: _PopIn(
              time: time,
              delay: .35,
              seconds: .55,
              origin: Alignment.bottomCenter,
              child: OverflowBox(maxWidth: 80, child: PencilMascot(controller: mascot, size: 86)),
            ),
          ),
        );
      }
    }
    // Pencil goes over every node of the section
    if (mascotOnTop != null) children.add(mascotOnTop);
    children.add(
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: JourneyAtmospherePainter(theme: theme, world: world, geometry: geometry, sectionTop: top, time: ambient),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: height,
      child: Stack(clipBehavior: Clip.hardEdge, children: children),
    );
  }
}

/// A porcelain wayfinding sign marks the entrance to each world.
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
        color: const Color(0xFFFFFCF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MapColors.cloudWhite, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x1F414F38), blurRadius: 12, offset: Offset(0, 4))],
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
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORLD ${index + 1}',
                  style: LikhoFonts.body(size: 10.5, weight: FontWeight.w800, color: t.deep).copyWith(height: 1.1, letterSpacing: 1.2),
                ),
                Text(
                  world.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LikhoFonts.title(size: 17, color: LikhoColors.ink).copyWith(height: 1.1),
                ),
              ],
            ),
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
    if (MediaQuery.disableAnimationsOf(context)) {
      if (widget.unlocked) widget.onOpen?.call(widget.level.number);
      return;
    }
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
    if (open != null) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) open(widget.level.number);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final boss = widget.level.isBoss;
    final size = boss
        ? 86.0
        : widget.isCurrent
        ? 80.0
        : 68.0;
    final dark = widget.theme.dark;
    final bg = widget.isCurrent
        ? const Color(0xFFFFD56B)
        : widget.done
        ? const Color(0xFF79A979)
        : dark
        ? const Color(0xFF66758C)
        : const Color(0xFFF2EDDC);
    final deep = widget.isCurrent
        ? LikhoColors.primaryDeep
        : widget.done
        ? const Color(0xFF527F58)
        : dark
        ? const Color(0xFF47576D)
        : const Color(0xFFB9B39E);
    final fg = widget.isCurrent
        ? LikhoColors.ink
        : widget.done
        ? LikhoColors.surface
        : dark
        ? const Color(0xFFDBE1EE)
        : const Color(0xFF7E8D75);
    final iconSize = boss
        ? 36.0
        : widget.isCurrent
        ? 32.0
        : 28.0;
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
              child: Semantics(
                button: true,
                enabled: widget.unlocked,
                label:
                    'Level ${widget.level.number}, ${widget.level.name}${widget.done
                        ? ', completed, ${widget.stars} stars'
                        : widget.isCurrent
                        ? ', current level'
                        : widget.unlocked
                        ? ''
                        : ', locked'}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
                    // A layer of its own: the tile's drop shadow is a blur,
                    // and a world section is far too tall to be kept as one
                    // raster, so without this every tile blurs again on
                    // every frame the map scrolls.
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: NodePainter(color: bg, deep: deep),
                        child: Center(
                          child: ExcludeSemantics(
                            child: widget.done
                                ? Icon(Symbols.check_rounded, size: iconSize + 6, weight: 800, color: fg)
                                : widget.isCurrent || (boss && widget.unlocked)
                                ? Icon(
                                    widget.isCurrent ? Symbols.play_arrow_rounded : IconRegistry.of(widget.level.icon),
                                    size: iconSize + 6,
                                    fill: 1,
                                    color: fg,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${widget.level.number}',
                                            maxLines: 1,
                                            style: LikhoFonts.title(size: 25, weight: FontWeight.w800, color: fg).copyWith(height: 1.1),
                                          ),
                                          if (!widget.unlocked) Icon(Symbols.lock_rounded, size: 12, fill: 1, color: fg.withValues(alpha: .65)),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.isCurrent)
              Positioned(
                top: size + 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF0),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Color(0x15414F38), offset: Offset(0, 2), blurRadius: 5)],
                    ),
                    child: Text(
                      'LET’S PLAY',
                      style: LikhoFonts.body(size: 10, weight: FontWeight.w900, color: const Color(0xFF80602B)).copyWith(letterSpacing: 1),
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
    if (_p >= 1 || MediaQuery.disableAnimationsOf(context)) return widget.child;
    final s = _p < .7 ? 1.1 * _curve.transform(_p / .7) : 1.1 - .1 * _curve.transform((_p - .7) / .3);
    return Transform.scale(scale: s, alignment: widget.origin, child: widget.child);
  }
}

// ------------------------------------------------------------------ header

class _TopFade extends StatelessWidget {
  const _TopFade();
  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: 0,
    height: MediaQuery.paddingOf(context).top + 182,
    child: const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF2FAF6E8), Color(0xD9FAF6E8), Color(0x40FAF6E8), Color(0x00FAF6E8)],
            stops: [0, .4, .7, 1],
          ),
        ),
      ),
    ),
  );
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.course, required this.world, required this.progress, required this.reduceMotion});
  final Course course;
  final int world;
  final ChildProgress progress;
  final bool reduceMotion;
  @override
  Widget build(BuildContext context) {
    if (course.worlds.isEmpty) return const SizedBox.shrink();
    final info = course.worlds[world];
    final levels = course.levelsOf(info);
    final done = levels.where((l) => progress.isDone(l.number)).length;
    final theme = LikhoWorlds.byId(info.themeId);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 550),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(info.id),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
        decoration: BoxDecoration(
          color: const Color(0xF7FFFCF3),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0xBFFFFFFF), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x163D4932), blurRadius: 20, offset: Offset(0, 7))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'YOUR JOURNEY',
                      style: LikhoFonts.body(size: 9, weight: FontWeight.w900, color: const Color(0xFF78816C)).copyWith(letterSpacing: 1.7),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      'WORLD ${world + 1} / ${course.worlds.length}',
                      style: LikhoFonts.body(size: 9, weight: FontWeight.w800, color: const Color(0xFF78816C)).copyWith(letterSpacing: .7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    info.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LikhoFonts.title(size: 25, weight: FontWeight.w800, color: const Color(0xFF344C3D)).copyWith(height: 1.15),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(IconRegistry.of(info.icon), color: theme.accent, size: 27, fill: 1),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: levels.isEmpty ? 0 : done / levels.length,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE5E8D8),
                      color: theme.accent,
                      semanticsLabel: '${info.name}, $done of ${levels.length} levels complete',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$done / ${levels.length}',
                  style: LikhoFonts.body(size: 10, weight: FontWeight.w800, color: const Color(0xFF78816C)).copyWith(height: 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact controls leave the landscape as the main focus.
class _Header extends StatelessWidget {
  const _Header({required this.progress, required this.avatar, required this.room, this.onProfile, this.onRoom, this.showRoom = true, this.onSettings});
  final ChildProgress progress;
  final MascotController avatar, room;
  final VoidCallback? onProfile, onRoom, onSettings;
  final bool showRoom;
  @override
  Widget build(BuildContext context) => Positioned(
    left: 16,
    right: 16,
    top: MediaQuery.paddingOf(context).top + 8,
    child: Row(
      children: [
        Semantics(
          button: true,
          label: '${progress.name}, profile',
          child: _Pressable(
            onTap: onProfile,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: progress.color.tint,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFFCF0), width: 2.5),
                boxShadow: const [BoxShadow(color: Color(0x1F3D4932), blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    Positioned(
                      left: 7,
                      top: 5,
                      width: 30,
                      height: 44,
                      child: OverflowBox(maxWidth: 40, child: PencilMascot(controller: avatar, size: 44)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            progress.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LikhoFonts.title(size: 19, weight: FontWeight.w800, color: const Color(0xFF344C3D)),
          ),
        ),
        const SizedBox(width: 6),
        Semantics(
          label: '${progress.stars} stars',
          excludeSemantics: true,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF0),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x143D4932), blurRadius: 12, offset: Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.star_rounded, size: 23, fill: 1, color: Color(0xFFEFBF50)),
                const SizedBox(width: 5),
                Text('${progress.stars}', style: LikhoFonts.title(size: 19, weight: FontWeight.w800).copyWith(height: 1)),
              ],
            ),
          ),
        ),
        if (showRoom) ...[
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: "Pencil’s room",
            child: _Pressable(
              onTap: onRoom,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDF89),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFF4C8), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x263D4932), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 6,
                        top: 4,
                        width: 32,
                        height: 48,
                        child: OverflowBox(maxWidth: 42, child: PencilMascot(controller: room, size: 48)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        if (onSettings != null) ...[
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Settings',
            child: _Pressable(
              onTap: onSettings,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Color(0xEEFFFCF0), shape: BoxShape.circle),
                child: const Icon(Symbols.settings_rounded, size: 22, color: Color(0xFF63735D)),
              ),
            ),
          ),
        ],
      ],
    ),
  );
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
                Text(
                  'Stories',
                  style: LikhoFonts.title(size: 12.5, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
                ),
              ],
            ),
          ),
          if (fresh)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: LikhoColors.hint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LikhoColors.surface, width: 2),
                ),
                child: Text(
                  'NEW',
                  style: LikhoFonts.title(size: 11, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
                ),
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
                Text(
                  'Games',
                  style: LikhoFonts.title(size: 12.5, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
                ),
              ],
            ),
          ),
          if (fresh)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: LikhoColors.hint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LikhoColors.surface, width: 2),
                ),
                child: Text(
                  'NEW',
                  style: LikhoFonts.title(size: 11, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
                ),
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
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 120),
        transform: _down ? (off != null ? Matrix4.translationValues(0, off, 0) : Matrix4.diagonal3Values(.9, .9, 1)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
