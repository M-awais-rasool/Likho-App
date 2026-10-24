import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/app_controls.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../game/monster_defense/md_engine.dart';
import '../games/monster_defense/md_scene.dart';
import '../games/spell_runner/sr_scene.dart';
import '../stories/story_art.dart';

/// The bottom bar: Map, Stories, Games and Parents, drawn the way the team
/// set it up in the admin panel (style, colours, order, animation).
///
/// - Candy: the open tab pops up as a chunky 3D button.
/// - Jelly: a colour blob stretches across to the tab that was tapped.
/// - Island: Map is a big round button in the middle, raised off the bar.
///
/// A tab with "NEW" hops now and then (rules.wiggle), and every tab
/// squashes when tapped. Reduce motion: no hops, no springs.
class LikhoTabBar extends StatefulWidget {
  const LikhoTabBar({
    super.key,
    required this.rules,
    required this.tabs,
    required this.selected,
    required this.onTap,
    this.fresh = const {},
    this.reduceMotion = false,
  });

  final TabBarRules rules;

  /// The tabs that show, in order.
  final List<TabSpec> tabs;
  final String selected;
  final ValueChanged<String> onTap;

  /// Tabs with "NEW" on them.
  final Set<String> fresh;
  final bool reduceMotion;

  static const barHeight = 72.0;

  /// The gap under a floating bar (at least the phone's own safe area).
  static double bottomGap(TabBarRules r, EdgeInsets safe) => r.floating ? math.max(safe.bottom, 14) : 0;

  /// How much of the screen's bottom the bar covers.
  static double inset(TabBarRules r, EdgeInsets safe) => barHeight + (r.floating ? bottomGap(r, safe) : safe.bottom);

  @override
  State<LikhoTabBar> createState() => _LikhoTabBarState();
}

class _LikhoTabBarState extends State<LikhoTabBar> with TickerProviderStateMixin {
  /// 0..1 every few seconds: the NEW tabs' hop.
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  /// The jelly blob going from [_from] to the selected tab.
  late final AnimationController _blob = AnimationController(vsync: this, value: 1);
  int _from = 0;

  bool get _hopping => widget.rules.wiggle && !widget.reduceMotion && widget.fresh.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _from = _index;
    if (_hopping) _idle.repeat();
  }

  int get _index => math.max(0, widget.tabs.indexWhere((t) => t.id == widget.selected));

  @override
  void didUpdateWidget(LikhoTabBar old) {
    super.didUpdateWidget(old);
    if (_hopping && !_idle.isAnimating) _idle.repeat();
    if (!_hopping && _idle.isAnimating) _idle.reset();
    if (old.selected != widget.selected) {
      final was = old.tabs.indexWhere((t) => t.id == old.selected);
      _from = was < 0 ? _index : was;
      final motion = _Motion.of(widget.rules, widget.reduceMotion);
      _blob.duration = motion.duration * 1.15;
      _blob.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _blob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rules;
    final safe = MediaQuery.paddingOf(context);
    final gap = LikhoTabBar.bottomGap(r, safe);
    final radius = r.floating ? BorderRadius.circular(r.roundness) : BorderRadius.vertical(top: Radius.circular(r.roundness));
    final motion = _Motion.of(r, widget.reduceMotion);
    final look = _Look(r);

    Widget tab(TabSpec t, int i, Widget Function(BuildContext, _TabState) draw) => _Tab(
      key: ValueKey('tab-${t.id}'),
      spec: t,
      active: t.id == widget.selected,
      motion: motion,
      hop: widget.fresh.contains(t.id) && _hopping ? _idle : null,
      hopPhase: i * .17,
      onTap: () => widget.onTap(t.id),
      draw: draw,
    );

    final Widget row = switch (r.style) {
      TabBarStyle.candy => Row(
        children: [
          for (final (i, t) in widget.tabs.indexed)
            Expanded(
              child: tab(t, i, (c, s) => _CandyTab(spec: t, s: s, look: look, labels: r.labels, fresh: widget.fresh.contains(t.id))),
            ),
        ],
      ),
      TabBarStyle.jelly => LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: [
            _JellyBlob(
              animation: _blob,
              tabs: widget.tabs,
              from: _from,
              to: _index,
              width: box.maxWidth,
              motion: motion,
              labels: r.labels,
              ring: look.onColour,
            ),
            Row(
              children: [
                for (final (i, t) in widget.tabs.indexed)
                  Expanded(
                    child: tab(t, i, (c, s) => _JellyTab(spec: t, s: s, look: look, labels: r.labels, fresh: widget.fresh.contains(t.id))),
                  ),
              ],
            ),
          ],
        ),
      ),
      TabBarStyle.island => _islandRow(tab, look),
    };

    // the bar's surface is a layer of its own, so a glass blur can be
    // clipped to it while an open Candy tab pops out above it
    final glass = r.surface == TabSurface.glass;
    final Widget surface = glass
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [BoxShadow(color: Color(0x262B2D42), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: look.barFill,
                    borderRadius: radius,
                    border: Border.all(color: const Color(0x99FFFFFF), width: 1.2),
                  ),
                ),
              ),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: look.barFill,
              borderRadius: radius,
              boxShadow: look.barShadows(floating: r.floating),
            ),
          );

    return Padding(
      padding: r.floating ? EdgeInsets.fromLTRB(14, 0, 14, gap) : EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          height: LikhoTabBar.barHeight + (r.floating ? 0 : safe.bottom),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: surface),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(left: 6, right: 6, bottom: r.floating ? 0 : safe.bottom),
                  child: row,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Island: Map raised in the middle, the other tabs split around it (the
  /// first half of them on the left).
  Widget _islandRow(Widget Function(TabSpec, int, Widget Function(BuildContext, _TabState)) tab, _Look look) {
    final r = widget.rules;
    final others = [
      for (final t in widget.tabs)
        if (t.id != TabIds.map) t,
    ];
    final map = widget.tabs.where((t) => t.id == TabIds.map).firstOrNull;
    final left = others.take(others.length ~/ 2).toList(), right = others.skip(others.length ~/ 2).toList();
    Widget side(List<TabSpec> ts) => Expanded(
      child: Row(
        children: [
          for (final t in ts)
            Expanded(
              child: tab(t, widget.tabs.indexOf(t), (c, s) => _IslandTab(spec: t, s: s, look: look, labels: r.labels, fresh: widget.fresh.contains(t.id))),
            ),
        ],
      ),
    );
    return Row(
      children: [
        side(left),
        if (map != null)
          SizedBox(
            width: 92,
            child: tab(map, widget.tabs.indexOf(map), (c, s) => _IslandMap(spec: map, s: s, look: look, labels: r.labels)),
          ),
        side(right),
      ],
    );
  }
}

// ------------------------------------------------------------------ motion

/// The team's animation choice as a curve and a duration.
class _Motion {
  const _Motion(this.curve, this.duration, this.kind);
  final Curve curve;
  final Duration duration;
  final TabAnimation kind;

  factory _Motion.of(TabBarRules r, bool reduceMotion) {
    final kind = reduceMotion ? TabAnimation.none : r.animation;
    return switch (kind) {
      TabAnimation.bounce => _Motion(springOut, r.time(520), kind),
      TabAnimation.slide => _Motion(Curves.easeOutCubic, r.time(360), kind),
      TabAnimation.pop => _Motion(Curves.elasticOut, r.time(640), kind),
      TabAnimation.none => _Motion(Curves.linear, Duration.zero, kind),
    };
  }
}

/// One tab's moving parts: [on] (0 closed .. 1 open; it overshoots with a
/// springy curve), [squash] (a tap), [hop] (pixels up, NEW tabs).
class _TabState {
  const _TabState(this.on, this.squash, this.hop, this.kind);
  final double on, squash, hop;
  final TabAnimation kind;

  /// [on] kept within 0..1 (for colours and opacity).
  double get onClamped => on.clamp(0.0, 1.0);

  /// The tap's squash and stretch: down, up a little past 1, back.
  double get press => keyframes(squash, const [(0, 1), (.3, .82), (.65, 1.08), (1, 1)]);
}

class _Tab extends StatefulWidget {
  const _Tab({super.key, required this.spec, required this.active, required this.motion, required this.onTap, required this.draw, this.hop, this.hopPhase = 0});

  final TabSpec spec;
  final bool active;
  final _Motion motion;
  final VoidCallback onTap;
  final Widget Function(BuildContext, _TabState) draw;
  final Animation<double>? hop;
  final double hopPhase;

  @override
  State<_Tab> createState() => _TabWidgetState();
}

class _TabWidgetState extends State<_Tab> with TickerProviderStateMixin {
  late final AnimationController _on = AnimationController(vsync: this, value: widget.active ? 1 : 0);
  late final AnimationController _squash = AnimationController(vsync: this, value: 1, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(_Tab old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      _on.duration = widget.motion.duration;
      _on.reverseDuration = widget.motion.duration * .6; // the old tab gets out of the way quicker
      widget.motion.duration == Duration.zero ? _on.value = widget.active ? 1 : 0 : (widget.active ? _on.forward() : _on.reverse());
    }
  }

  @override
  void dispose() {
    _on.dispose();
    _squash.dispose();
    super.dispose();
  }

  double get _onCurved {
    final v = _on.value;
    // opening follows the team's curve; closing settles without a spring
    return _on.status == AnimationStatus.reverse ? Curves.easeOut.transform(v) : widget.motion.curve.transform(v);
  }

  double _hopNow() {
    final h = widget.hop;
    if (h == null) return 0;
    final t = (h.value + widget.hopPhase) % 1;
    return keyframes(t, const [(0, 0), (.06, -7), (.12, 0), (.17, -3), (.22, 0), (1, 0)], Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.active,
    label: widget.spec.label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (widget.motion.kind != TabAnimation.none) _squash.forward(from: 0);
      },
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_on, _squash, ?widget.hop]),
        builder: (context, _) => widget.draw(context, _TabState(_onCurved, _squash.value, _hopNow(), widget.motion.kind)),
      ),
    ),
  );
}

// ------------------------------------------------------------------ look

/// Colours of the bar and the tabs on it.
class _Look {
  _Look(this.r);
  final TabBarRules r;

  Color get barFill => switch (r.surface) {
    TabSurface.white => LikhoColors.surface,
    TabSurface.glass => const Color(0xB8FFFFFF),
    TabSurface.colour => r.barColor,
  };

  /// A soft drop and a 3D edge under a floating bar; a lift above an edge bar.
  List<BoxShadow> barShadows({required bool floating}) {
    final edge = r.surface == TabSurface.colour ? deep(r.barColor) : const Color(0xFFE6E0F2);
    return floating
        ? [const BoxShadow(color: Color(0x1F2B2D42), blurRadius: 22, offset: Offset(0, 10)), BoxShadow(color: edge, offset: const Offset(0, 4))]
        : const [BoxShadow(color: Color(0x1A2B2D42), blurRadius: 16, offset: Offset(0, -3))];
  }

  bool get onColour => r.surface == TabSurface.colour;

  /// A label on the bar, closed.
  Color get label => onColour ? const Color(0xD9FFFFFF) : LikhoColors.inkMuted;

  /// The tab's colour as a label or a dot on the bar (darker on white).
  /// Light colours (yellow) go much darker so they read on white.
  Color accent(TabSpec t) => onColour ? LikhoColors.surface : deep(t.color, t.color.computeLuminance() > .4 ? .3 : .1);

  static Color deep(Color c, [double by = .15]) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - by).clamp(0.0, 1.0)).toColor();
  }

  /// Ink or white, whichever reads on [c].
  static Color on(Color c) => c.computeLuminance() > .5 ? LikhoColors.ink : LikhoColors.surface;
}

TextStyle _labelStyle(Color color, [double size = 12.5]) => LikhoFonts.title(size: size, weight: FontWeight.w800, color: color).copyWith(height: 1);

/// The tab's picture: the signpost (Map), the apple (Stories), Gloop
/// (Games), a lock (Parents).
class _Art extends StatelessWidget {
  const _Art(this.id, {required this.size, required this.lockColor});
  final String id;
  final double size;
  final Color lockColor;

  @override
  Widget build(BuildContext context) {
    final asset = switch (id) {
      TabIds.map => SrArt.pic('signpost'),
      TabIds.stories => StoryArt.prop('a', 'apple_leaf'),
      TabIds.games => MdArt.pose(MdKind.gloop, 'friendly'),
      _ => null,
    };
    return SizedBox(
      width: size,
      height: size,
      child: asset == null
          ? Icon(Symbols.lock_rounded, size: size * .82, fill: 1, weight: 600, opticalSize: 40, color: lockColor)
          : Image.asset(asset, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
    );
  }
}

/// "NEW" in the corner of a tab's picture.
class _New extends StatelessWidget {
  const _New();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: LikhoColors.hint,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: LikhoColors.surface, width: 1.5),
    ),
    child: Text('NEW', style: _labelStyle(LikhoColors.surface, 9)),
  );
}

// ------------------------------------------------------------------ candy

/// Candy: closed, the picture and its name on the bar; open, a chunky
/// button in the tab's colour pops up out of the bar.
class _CandyTab extends StatelessWidget {
  const _CandyTab({required this.spec, required this.s, required this.look, required this.labels, required this.fresh});
  final TabSpec spec;
  final _TabState s;
  final _Look look;
  final bool labels, fresh;

  @override
  Widget build(BuildContext context) {
    final on = s.on, c = s.onClamped;
    // pop grows the button in place; bounce and slide lift it out of the bar
    final lift = s.kind == TabAnimation.pop ? -14 * c : -14 * on;
    final tile = s.kind == TabAnimation.pop ? on : .55 + .45 * on;
    final ink = _Look.on(spec.color);
    final art = lerpDouble(labels ? 30 : 38, labels ? 34 : 40, c)!;
    return Center(
      child: Transform.translate(
        offset: Offset(0, lift + s.hop),
        child: Transform.scale(
          scale: s.press,
          child: SizedBox(
            width: 66,
            height: 62,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (c > 0)
                  Opacity(
                    opacity: c,
                    child: Transform.scale(
                      scale: tile,
                      child: Container(
                        decoration: BoxDecoration(
                          color: spec.color,
                          borderRadius: BorderRadius.circular(21),
                          border: Border.all(color: LikhoColors.surface, width: 3),
                          boxShadow: [
                            BoxShadow(color: _Look.deep(spec.color), offset: const Offset(0, 5)),
                            BoxShadow(color: spec.color.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 8)),
                          ],
                        ),
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Art(spec.id, size: art, lockColor: Color.lerp(spec.color, ink, c)!),
                    if (labels) ...[
                      const SizedBox(height: 2),
                      Text(spec.label, maxLines: 1, overflow: TextOverflow.visible, softWrap: false, style: _labelStyle(Color.lerp(look.label, ink, c)!)),
                    ],
                  ],
                ),
                if (fresh) const Positioned(right: -4, top: -2, child: _New()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ jelly

/// Jelly: the colour blob behind the open tab's picture. Moving, it
/// stretches like jelly and leans the way it goes; pop grows it in place.
class _JellyBlob extends StatelessWidget {
  const _JellyBlob({
    required this.animation,
    required this.tabs,
    required this.from,
    required this.to,
    required this.width,
    required this.motion,
    required this.labels,
    this.ring = false,
  });

  /// A white ring round the blob (on a coloured bar, where a blob of the
  /// bar's own colour would vanish).
  final bool ring;
  final Animation<double> animation;
  final List<TabSpec> tabs;
  final int from, to;
  final double width;
  final _Motion motion;
  final bool labels;

  static const _w = 50.0, _h = 42.0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      if (tabs.isEmpty) return const SizedBox.shrink();
      final t = animation.value;
      final slot = width / tabs.length;
      final a = from.clamp(0, tabs.length - 1), b = to.clamp(0, tabs.length - 1);
      final pop = motion.kind == TabAnimation.pop;
      final move = pop ? 1.0 : motion.curve.transform(t);
      final x = lerpDouble(slot * (a + .5), slot * (b + .5), move)!;
      // stretch while travelling (most in the middle of the trip)
      final stretch = pop || a == b ? 0.0 : math.sin(math.pi * t.clamp(0.0, 1.0)) * math.min(34, (b - a).abs() * 22.0);
      final grow = pop ? Curves.elasticOut.transform(t) : 1.0;
      final color = _hueLerp(tabs[a].color, tabs[b].color, Curves.easeOut.transform(t));
      final w = (_w + stretch) * grow, h = (_h - stretch * .18) * grow;
      final top = (labels ? 5.0 : (LikhoTabBar.barHeight - _h) / 2) + (_h - h) / 2;
      return Positioned(
        left: x - w / 2,
        top: top,
        width: w,
        height: h,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX((b - a).sign * -.12 * math.sin(math.pi * t.clamp(0.0, 1.0)) * (pop ? 0 : 1)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(17),
              border: ring ? Border.all(color: LikhoColors.surface, width: 2.5) : null,
              boxShadow: [BoxShadow(color: _Look.deep(color), offset: const Offset(0, 4))],
            ),
          ),
        ),
      );
    },
  );
}

/// Blends two colours round the colour wheel the short way, so yellow to
/// violet passes through orange and pink, not a muddy brown.
Color _hueLerp(Color a, Color b, double t) {
  final x = HSLColor.fromColor(a), y = HSLColor.fromColor(b);
  var d = y.hue - x.hue;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return HSLColor.fromAHSL(1, (x.hue + d * t) % 360, lerpDouble(x.saturation, y.saturation, t)!, lerpDouble(x.lightness, y.lightness, t)!).toColor();
}

class _JellyTab extends StatelessWidget {
  const _JellyTab({required this.spec, required this.s, required this.look, required this.labels, required this.fresh});
  final TabSpec spec;
  final _TabState s;
  final _Look look;
  final bool labels, fresh;

  @override
  Widget build(BuildContext context) {
    final c = s.onClamped;
    final art = labels ? 30.0 : 36.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: labels ? 5 : (LikhoTabBar.barHeight - 42) / 2,
          height: 42,
          child: Center(
            child: Transform.translate(
              offset: Offset(0, -1 * s.on + s.hop),
              child: Transform.scale(
                scale: s.press * (1 + .14 * s.on),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Art(spec.id, size: art, lockColor: Color.lerp(look.onColour ? LikhoColors.surface : spec.color, _Look.on(spec.color), c)!),
                    if (fresh) const Positioned(right: -18, top: -8, child: _New()),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (labels)
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Text(
              spec.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: _labelStyle(Color.lerp(look.label, look.accent(spec), c)!),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ island

/// Island: a tab beside the big Map button: its picture, name, and a dot
/// under it when open.
class _IslandTab extends StatelessWidget {
  const _IslandTab({required this.spec, required this.s, required this.look, required this.labels, required this.fresh});
  final TabSpec spec;
  final _TabState s;
  final _Look look;
  final bool labels, fresh;

  @override
  Widget build(BuildContext context) {
    final c = s.onClamped;
    return Center(
      child: Transform.translate(
        offset: Offset(0, -4 * s.on + s.hop),
        child: Transform.scale(
          scale: s.press * (1 + .1 * s.on),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: .7 + .3 * c,
                    child: _Art(spec.id, size: labels ? 32 : 38, lockColor: look.onColour ? LikhoColors.surface : spec.color),
                  ),
                  if (fresh) const Positioned(right: -18, top: -8, child: _New()),
                ],
              ),
              if (labels) ...[
                const SizedBox(height: 3),
                Text(
                  spec.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: _labelStyle(Color.lerp(look.label, look.accent(spec), c)!),
                ),
              ],
              const SizedBox(height: 3),
              Container(
                width: 6 + 10 * c,
                height: 5,
                decoration: BoxDecoration(
                  color: look.accent(spec).withValues(alpha: c),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Island's Map: a big round button raised off the bar, with a white
/// ring; open, it grows a little and its ring turns the tab's colour.
class _IslandMap extends StatelessWidget {
  const _IslandMap({required this.spec, required this.s, required this.look, required this.labels});
  final TabSpec spec;
  final _TabState s;
  final _Look look;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    final c = s.onClamped;
    const d = 70.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: -30 - 4 * s.on,
          child: Transform.rotate(
            angle: math.sin(s.squash * math.pi * 2) * .12 * (1 - s.squash),
            child: Transform.scale(
              scale: s.press * (1 + .06 * s.on),
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  color: spec.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: LikhoColors.surface, width: 4),
                  boxShadow: [
                    // open: a halo ring in the tab's colour round the white one
                    BoxShadow(
                      color: spec.color.withValues(alpha: .45 * c),
                      spreadRadius: 6 * c,
                    ),
                    BoxShadow(color: _Look.deep(spec.color), offset: const Offset(0, 6)),
                    BoxShadow(color: spec.color.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 8)),
                  ],
                ),
                alignment: Alignment.center,
                child: _Art(spec.id, size: 42, lockColor: LikhoColors.surface),
              ),
            ),
          ),
        ),
        if (labels)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Text(spec.label, textAlign: TextAlign.center, style: _labelStyle(Color.lerp(look.label, look.accent(spec), c)!)),
          ),
      ],
    );
  }
}
