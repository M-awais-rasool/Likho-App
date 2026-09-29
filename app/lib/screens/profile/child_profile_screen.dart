import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../design/icon_registry.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';

/// 16 Child profile, from the prototype: Pencil, the child's name, three
/// counters that count up (stars, levels, days), the six worlds of the
/// journey, and the Sticker Book. Editing is for parents ([onEdit] goes
/// through the parent gate).
class ChildProfileScreen extends ConsumerStatefulWidget {
  const ChildProfileScreen({super.key, required this.onBack, required this.onEdit, required this.onStickers});
  final VoidCallback onBack, onEdit, onStickers;

  @override
  ConsumerState<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends ConsumerState<ChildProfileScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _count = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final course = ref.watch(courseProvider).value;
    final p = family.active, r = family.record;
    final done = r.levelStars.length;
    return StatusBar(
      child: Material(
        child: CssRadialBackground(
          center: const Offset(.5, 0),
          colors: [p.swatch.tint, LikhoColors.background],
          stops: const [0, .55],
          child: MaxWidth(
            width: 460,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, frameTop(context, 56), 24, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleIconButton.back(onTap: widget.onBack, size: 56, iconSize: 28),
                      CircleIconButton(
                        icon: Symbols.edit_rounded,
                        onTap: widget.onEdit,
                        size: 44,
                        iconSize: 22,
                        color: UiColors.white80,
                        iconColor: LikhoColors.inkMuted,
                        shadow: null,
                      ),
                    ],
                  ),
                  Transform.translate(offset: const Offset(0, -6), child: const PencilFigure(width: 160, height: 226)),
                  Text(p.name, style: LikhoFonts.title(size: 40, weight: FontWeight.w800).copyWith(height: 1)),
                  const SizedBox(height: 22),
                  AnimatedBuilder(
                    animation: _count,
                    builder: (context, _) {
                      final k = 1 - (1 - _count.value) * (1 - _count.value) * (1 - _count.value);
                      int c(int v) => (v * k).round();
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Stat(
                              icon: Symbols.star_rounded,
                              value: c(r.stars),
                              bg: ChildProfileColors.starBg,
                              inset: ChildProfileColors.starInset,
                              fg: LikhoColors.primary,
                            ),
                            const SizedBox(width: 18),
                            _Stat(
                              icon: Symbols.flag_rounded,
                              value: c(done),
                              bg: ChildProfileColors.flagBg,
                              inset: ChildProfileColors.flagInset,
                              fg: LikhoColors.success,
                            ),
                            const SizedBox(width: 18),
                            _Stat(
                              icon: Symbols.wb_sunny_rounded,
                              value: c(r.days),
                              bg: ChildProfileColors.sunBg,
                              inset: ChildProfileColors.sunInset,
                              fg: LikhoColors.hint,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Mera safar', style: LikhoFonts.title(size: 22, weight: FontWeight.w800).copyWith(height: 1.6)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var w = 0; w < 6; w++) ...[
                        if (w > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Center(
                            child: _WorldDot(
                              world: w,
                              icon: course?.worlds[w].icon ?? 'star',
                              themeId: course?.worlds[w].themeId ?? '',
                              done: [for (var k = 1; k <= 6; k++) r.isDone(w * 6 + k)].where((x) => x).length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _StickerBookCard(count: done, onTap: widget.onStickers),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.bg, required this.inset, required this.fg});
  final IconData icon;
  final int value;
  final Color bg, inset, fg;

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    height: 96,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: CustomPaint(
      painter: InsetShadowPainter([(const Offset(0, -6), inset)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SymbolIcon(icon, size: 30, fill: true, color: fg),
          Text('$value', style: LikhoFonts.title(size: 28, weight: FontWeight.w800).copyWith(height: 1)),
        ],
      ),
    ),
  );
}

class _WorldDot extends StatelessWidget {
  const _WorldDot({required this.world, required this.icon, required this.themeId, required this.done});
  final int world, done;
  final String icon, themeId;

  @override
  Widget build(BuildContext context) {
    final theme = LikhoWorlds.byId(themeId);
    final started = done > 0;
    return Opacity(
      opacity: started ? 1 : .8,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: started ? theme.accent : ChildProfileColors.worldOff,
          shape: BoxShape.circle,
          boxShadow: [if (done == 6) const BoxShadow(color: LikhoColors.primary, spreadRadius: 3)],
        ),
        child: Center(child: SymbolIcon(IconRegistry.of(icon), size: 26, fill: true, color: started ? LikhoColors.surface : UiColors.chevron)),
      ),
    );
  }
}

class _StickerBookCard extends StatelessWidget {
  const _StickerBookCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Press(
      onTap: onTap,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LikhoRadius.card),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ChildProfileColors.bookTop, ChildProfileColors.bookBottom],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(color: UiColors.white10, shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -6 * 3.14159265 / 180,
                    child: Container(
                      width: 84,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: StickerColors.page,
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(10), right: Radius.circular(18)),
                      ),
                      foregroundDecoration: const _SpineDecoration(),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: LikhoColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: GameColors.black18, offset: Offset(0, 3), blurRadius: 8),
                              BoxShadow(color: LikhoColors.surface, spreadRadius: 4),
                            ],
                          ),
                          child: const Center(child: SymbolIcon(Symbols.star_rounded, size: 26, fill: true, color: LikhoColors.surface)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Sticker Book',
                            style: LikhoFonts.title(size: 28, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Opacity(
                          opacity: .85,
                          child: Text(
                            '$count/36 stickers',
                            style: LikhoFonts.body(size: 16, weight: FontWeight.w700, color: LikhoColors.surface),
                          ),
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
}

/// Purple 3D card: sinks 4 px into its 8 px edge when pressed.
class _Press extends StatefulWidget {
  const _Press({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: withSound(context, ButtonSound.press, widget.onTap),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LikhoRadius.card),
        boxShadow: [BoxShadow(color: ChildProfileColors.bookEdge, offset: Offset(0, _down ? 4 : 8))],
      ),
      child: widget.child,
    ),
  );
}

/// inset 8px 0 0 #E7D9BF: the book's spine.
class _SpineDecoration extends Decoration {
  const _SpineDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _SpinePainter();
}

class _SpinePainter extends BoxPainter {
  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.horizontal(left: Radius.circular(10), right: Radius.circular(18)),
  );

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    const InsetShadowPainter([(Offset(8, 0), ChildProfileColors.bookSpine)], shape: _shape).paint(canvas, configuration.size ?? Size.zero);
    canvas.restore();
  }
}
