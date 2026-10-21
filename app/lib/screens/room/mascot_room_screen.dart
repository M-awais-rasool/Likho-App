import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/app_controls.dart';
import '../../data/family.dart';
import '../../data/shop_items.dart';
import '../../feedback/app_feedback.dart';
import '../../design/icon_registry.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';

/// 15 Mascot room, from the prototype: Pencil in his room, a shelf of things
/// to buy with stars. Buying flies stars from the counter to the item; worn
/// clothes and placed furniture show up at once. Not enough stars: the item
/// shakes and Pencil thinks.
class MascotRoomScreen extends ConsumerStatefulWidget {
  const MascotRoomScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  ConsumerState<MascotRoomScreen> createState() => _MascotRoomScreenState();
}

class _MascotRoomScreenState extends ConsumerState<MascotRoomScreen> {
  final _stackKey = GlobalKey();
  final _pillKey = GlobalKey();
  MascotState _expr = MascotState.idle;
  final List<Timer> _timers = [];
  final Map<String, int> _shakes = {};
  final List<(int, Offset, Offset)> _flights = [];
  int _flightId = 0;

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _say(List<(int, MascotState)> steps) {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    setState(() => _expr = steps.first.$2);
    for (final (ms, s) in steps.skip(1)) {
      _timers.add(
        Timer(Duration(milliseconds: ms), () {
          if (mounted) setState(() => _expr = s);
        }),
      );
    }
  }

  Offset? _centerOf(GlobalKey k, {Offset at = Offset.zero}) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null) return null;
    return stack.globalToLocal(box.localToGlobal(at));
  }

  void _tap(ShopItem item, GlobalKey cardKey) {
    final family = ref.read(familyProvider);
    final buying = !family.record.owned.contains(item.id);
    final fb = ref.read(feedbackProvider);
    if (!ref.read(familyProvider.notifier).tapItem(item)) {
      fb.nope();
      setState(() => _shakes[item.id] = (_shakes[item.id] ?? 0) + 1);
      _say([(0, MascotState.think), (1100, MascotState.idle)]);
      return;
    }
    if (buying) {
      final from = _centerOf(_pillKey, at: const Offset(18, 10));
      final card = cardKey.currentContext?.findRenderObject() as RenderBox?;
      final to = _centerOf(cardKey, at: card == null ? Offset.zero : card.size.center(Offset.zero) - const Offset(18, 10));
      if (from != null && to != null && !ref.read(reduceMotionProvider)) setState(() => _flights.add((_flightId++, from, to)));
    }
    buying ? fb.reward() : fb.wear();
    _say([(0, MascotState.wow), (700, MascotState.happy), (2000, MascotState.idle)]);
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final r = family.record;
    return StatusBar(
      child: Material(
        color: RoomColors.wallA,
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                Expanded(child: _room(r)),
                _shelf(r),
              ],
            ),
            for (final (id, from, to) in _flights)
              _FlyingStars(key: ValueKey(id), from: from, to: to, onDone: () => setState(() => _flights.removeWhere((f) => f.$1 == id))),
          ],
        ),
      ),
    );
  }

  Widget _room(ChildRecord r) {
    // furniture the team hid is not shown (App controls)
    final controls = ref.watch(appControlsProvider);
    bool placed(String id) => r.room.contains(id) && !controls.itemHidden(id);
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight, w = box.maxWidth, cx = w / 2;
        return ClipRect(
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _StripesPainter(RoomColors.wallA, RoomColors.wallB, 34, 34))),
              Positioned(left: cx - 80, top: frameTop(context, 110), child: const _Window()),
              for (final dx in [-112.0, 68.0])
                Positioned(
                  left: cx + dx,
                  top: frameTop(context, 92),
                  child: Container(
                    width: 44,
                    height: 180,
                    decoration: const BoxDecoration(
                      color: RoomColors.curtain,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h * .34,
                child: const CustomPaint(painter: _FloorPainter()),
              ),
              if (placed('poster'))
                Positioned(
                  right: 26,
                  top: frameTop(context, 128),
                  child: const DropIn(child: _Poster()),
                ),
              if (placed('lamp'))
                Positioned(
                  left: 30,
                  bottom: h * .18,
                  child: const DropIn(child: _Lamp()),
                ),
              if (placed('plant'))
                Positioned(
                  right: 30,
                  bottom: h * .17,
                  child: const DropIn(child: _Plant()),
                ),
              if (placed('rug'))
                Positioned(
                  left: cx - 110,
                  bottom: h * .09,
                  child: const PopIn(seconds: .5, child: _Rug()),
                ),
              Positioned(
                left: cx - 85,
                bottom: h * .11,
                child: PencilFigure(width: 170, height: 240, state: _expr),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: frameTop(context, 54),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleIconButton.back(onTap: widget.onBack, size: 56, iconSize: 28, shadow: GameColors.ink10),
                    KeyedSubtree(
                      key: _pillKey,
                      child: StarPill(stars: r.stars, height: 48),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shelf(ChildRecord r) {
    // the shop as the team set it up: hidden items left out, their prices
    final controls = ref.watch(appControlsProvider);
    final items = [for (final it in ShopItem.all) ?controls.item(it)];
    return Container(
      height: 236,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [RoomColors.shelfTop, RoomColors.shelfBottom]),
      ),
      foregroundDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoomColors.shelfEdge, width: 8)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 30),
      child: items.isEmpty
          ? Center(child: Text('New things are coming soon!', style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: UiColors.inkBody)))
          : ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = items[i];
          final owned = r.owned.contains(it.id);
          return Shake(
            trigger: _shakes[it.id] ?? 0,
            distance: 5,
            ms: 260,
            child: _ItemCard(
              item: it,
              owned: owned,
              worn: it.isWear ? r.wearing == it.id : r.room.contains(it.id),
              locked: !owned && r.stars < it.price,
              onTap: _tap,
            ),
          );
        },
      ),
    );
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({required this.item, required this.owned, required this.worn, required this.locked, required this.onTap});
  final ShopItem item;
  final bool owned, worn, locked;
  final void Function(ShopItem, GlobalKey) onTap;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  final _key = GlobalKey();
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () => widget.onTap(it, _key),
      child: AnimatedScale(
        scale: _down ? .92 : 1,
        duration: const Duration(milliseconds: 180),
        curve: springOut,
        child: Opacity(
          opacity: widget.locked ? .5 : 1,
          child: Container(
            key: _key,
            width: 104,
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
            decoration: BoxDecoration(
              color: widget.worn ? RoomColors.itemWorn : LikhoColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: widget.worn
                  ? const [BoxShadow(color: LikhoColors.primaryDeep, offset: Offset(0, 6)), BoxShadow(color: LikhoColors.primary, spreadRadius: 3)]
                  : const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 6))],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 84,
                      child: Center(
                        child: it.isWear
                            ? PencilFigure(width: 58, height: 82, accessory: it.accessory, childAccessory: false, still: 0)
                            : SymbolIcon(IconRegistry.of(it.icon ?? ''), size: 52, fill: true, color: RoomColors.roomIcon),
                      ),
                    ),
                    Text(
                      it.name,
                      textAlign: TextAlign.center,
                      style: LikhoFonts.body(size: 13, weight: FontWeight.w700, color: UiColors.inkBody, height: 1.1),
                    ),
                    if (widget.owned)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: LikhoColors.success, shape: BoxShape.circle),
                        child: const Center(child: SymbolIcon(Symbols.check_rounded, size: 20, weight: 700, color: LikhoColors.surface)),
                      )
                    else
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: RoomColors.priceChip, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SymbolIcon(Symbols.star_rounded, size: 18, fill: true, color: LikhoColors.primaryDeep),
                            const SizedBox(width: 3),
                            Text('${it.price}', style: LikhoFonts.title(size: 16, weight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
                if (widget.locked)
                  Positioned(
                    right: 2,
                    top: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: LikhoColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: GameColors.black10, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: const Center(child: SymbolIcon(Symbols.lock_rounded, size: 16, fill: true, color: UiColors.inkLabel)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Five stars fly from the star counter to the bought item (700 ms each,
/// 70 ms apart), arcing up and shrinking.
class _FlyingStars extends StatefulWidget {
  const _FlyingStars({super.key, required this.from, required this.to, required this.onDone});
  final Offset from, to;
  final VoidCallback onDone;

  @override
  State<_FlyingStars> createState() => _FlyingStarsState();
}

class _FlyingStarsState extends State<_FlyingStars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700 + 4 * 70),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.to - widget.from;
    const ease = Cubic(.4, 0, .2, 1);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ms = _c.value * (700 + 4 * 70);
          return Stack(
            children: [
              for (var i = 0; i < 5; i++)
                if (ms >= i * 70 && ms <= i * 70 + 700)
                  () {
                    final t = (ms - i * 70) / 700;
                    final x = keyframes(t, [(0, 0), (.5, d.dx * .5 + (i - 2) * 18), (1, d.dx)], ease);
                    final y = keyframes(t, [(0, 0), (.5, d.dy * .5 - 60), (1, d.dy)], ease);
                    final s = keyframes(t, const [(0, 1), (.5, 1.3), (1, .4)], ease);
                    final o = keyframes(t, const [(0, 1), (.5, .6), (1, .2)], ease);
                    return Positioned(
                      left: widget.from.dx + x,
                      top: widget.from.dy + y,
                      child: Opacity(
                        opacity: o,
                        child: Transform.scale(
                          scale: s,
                          child: const SymbolIcon(
                            Symbols.star_rounded,
                            size: 24,
                            fill: true,
                            color: LikhoColors.primary,
                            shadows: [Shadow(color: LikhoColors.primaryDeep, offset: Offset(0, 2))],
                          ),
                        ),
                      ),
                    );
                  }(),
            ],
          );
        },
      ),
    );
  }
}

class _StripesPainter extends CustomPainter {
  const _StripesPainter(this.a, this.b, this.wa, this.wb);
  final Color a, b;
  final double wa, wb;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = a);
    final p = Paint()..color = b;
    for (var x = wa; x < size.width; x += wa + wb) {
      canvas.drawRect(Rect.fromLTWH(x, 0, wb, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) => false;
}

/// Wooden floor: 70 px planks with 2 px seams, a soft shadow along the wall.
class _FloorPainter extends CustomPainter {
  const _FloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = RoomColors.floorA);
    final seam = Paint()..color = RoomColors.floorB;
    for (var x = 70.0; x < size.width; x += 72) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), seam);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 10), Paint()..color = UiColors.black05);
  }

  @override
  bool shouldRepaint(_FloorPainter old) => false;
}

class _Window extends StatelessWidget {
  const _Window();

  @override
  Widget build(BuildContext context) => Container(
    width: 160,
    height: 140,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [RoomColors.skyTop, RoomColors.skyBottom]),
      boxShadow: const [
        BoxShadow(color: GameColors.black06, offset: Offset(0, 12), spreadRadius: 10),
        BoxShadow(color: LikhoColors.surface, spreadRadius: 10),
      ],
    ),
    child: Stack(
      children: [
        Positioned(left: 76, top: 0, bottom: 0, width: 8, child: Container(color: LikhoColors.surface)),
        Positioned(left: 0, right: 0, top: 66, height: 8, child: Container(color: LikhoColors.surface)),
        Positioned(
          left: 18,
          top: 26,
          child: Drift(
            seconds: 7,
            child: Container(
              width: 44,
              height: 16,
              decoration: BoxDecoration(color: LikhoColors.surface, borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Poster extends StatelessWidget {
  const _Poster();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 4 * math.pi / 180,
    child: Container(
      width: 70,
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LikhoColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: GameColors.black06, offset: Offset(0, 6))],
      ),
      child: Text('Aa', style: LikhoFonts.letter(size: 34, color: RoomColors.poster)),
    ),
  );
}

class _Lamp extends StatelessWidget {
  const _Lamp();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 170,
    child: Stack(
      children: [
        Positioned(left: 32, top: 46, child: Container(width: 6, height: 110, color: RoomColors.wood)),
        Positioned(
          left: 14,
          bottom: 0,
          child: Container(
            width: 42,
            height: 12,
            decoration: BoxDecoration(color: RoomColors.wood, borderRadius: BorderRadius.circular(6)),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            width: 70,
            height: 48,
            decoration: const BoxDecoration(
              color: LikhoColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(6)),
              boxShadow: [BoxShadow(color: RoomColors.lampGlow, offset: Offset(0, 10), blurRadius: 40)],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Plant extends StatelessWidget {
  const _Plant();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 110,
    child: Stack(
      children: [
        Positioned(
          left: 8,
          top: 0,
          child: Transform.rotate(
            angle: -20 * math.pi / 180,
            alignment: Alignment.bottomRight,
            child: Sway(
              seconds: 5,
              alignment: Alignment.bottomRight,
              child: Container(
                width: 34,
                height: 52,
                decoration: const BoxDecoration(
                  color: RoomColors.leafLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.elliptical(17, 26),
                    topRight: Radius.elliptical(17, 26),
                    bottomRight: Radius.elliptical(17, 26),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 6,
          child: Container(
            width: 34,
            height: 52,
            decoration: const BoxDecoration(
              color: RoomColors.leafDark,
              borderRadius: BorderRadius.only(topLeft: Radius.elliptical(17, 26), topRight: Radius.elliptical(17, 26), bottomLeft: Radius.elliptical(17, 26)),
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 0,
          child: Container(
            width: 50,
            height: 46,
            decoration: const BoxDecoration(
              color: RoomColors.pot,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(16)),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Rug extends StatelessWidget {
  const _Rug();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 220, height: 50, child: CustomPaint(painter: _RugPainter()));
}

/// repeating-radial-gradient(ellipse, #9B7FE6 0 10px, #B8A4EF 10px 20px)
class _RugPainter extends CustomPainter {
  const _RugPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.save();
    canvas.clipPath(Path()..addOval(r));
    // rings in a circle, squashed to the ellipse
    final c = r.center;
    final rx = size.width / 2 * math.sqrt2, ry = size.height / 2 * math.sqrt2;
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, ry / rx);
    final p = Paint();
    for (var k = (rx / 10).ceil(); k > 0; k--) {
      p.color = k.isOdd ? RoomColors.rugA : RoomColors.rugB;
      canvas.drawCircle(Offset.zero, k * 10.0, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RugPainter old) => false;
}
