import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../feedback/app_feedback.dart';
import '../../feedback/game_feedback.dart';
import '../../design/icon_registry.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../common/effects.dart';
import '../common/kid_widgets.dart';

/// 17 Sticker book, from the prototype: one page per world with a sticker
/// per level (the boss level earns a gold medal). Pages flip like a book.
/// A sticker earned since the book was last opened is slapped on
/// (stickIn) and the book opens on its page.
class StickerBookScreen extends ConsumerStatefulWidget {
  const StickerBookScreen({super.key, required this.onBack, this.page});
  final VoidCallback onBack;

  /// World page to open on (0..5); defaults to the new sticker's world or
  /// the current level's.
  final int? page;

  @override
  ConsumerState<StickerBookScreen> createState() => _StickerBookScreenState();
}

class _StickerBookScreenState extends ConsumerState<StickerBookScreen> with SingleTickerProviderStateMixin {
  late int _page;
  int? _newSticker;
  late final AnimationController _flip = AnimationController(vsync: this);
  bool _flipOut = true;
  int _dir = 1;

  @override
  void initState() {
    super.initState();
    _newSticker = ref.read(playSessionProvider).newSticker;
    final current = _newSticker ?? ref.read(progressProvider).current;
    _page = widget.page ?? ((current - 1) ~/ 6).clamp(0, 5);
    if (_newSticker != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(playSessionProvider.notifier).stickerSeen();
      });
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Future<void> _turn(int dir) async {
    final np = (_page + dir).clamp(0, 5);
    if (np == _page || _flip.isAnimating) return;
    ref.read(feedbackProvider).pageFlip();
    _dir = dir;
    setState(() => _flipOut = true);
    _flip.duration = const Duration(milliseconds: 230);
    await _flip.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _page = np;
      _flipOut = false;
    });
    _flip.duration = const Duration(milliseconds: 260);
    await _flip.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseProvider).value;
    final record = ref.watch(familyProvider.select((f) => f.record));
    final count = record.levelStars.length;
    return StatusBar(
      light: true,
      child: Material(
        color: StickerColors.bg,
        child: MaxWidth(
          width: 480,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, frameTop(context, 56), 20, 36),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleIconButton.back(onTap: widget.onBack, size: 56, iconSize: 28, shadow: GameColors.black12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Sticker Book',
                            style: LikhoFonts.title(size: 28, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: GameColors.white20, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '$count/36',
                        style: LikhoFonts.title(size: 18, weight: FontWeight.w800, color: LikhoColors.surface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _flip,
                    builder: (context, child) {
                      final v = _flip.value;
                      double deg = 0;
                      if (_flip.isAnimating || (_flipOut && v == 1)) {
                        deg = _flipOut ? -90 * _dir * Curves.easeIn.transform(v) : 90 * _dir * (1 - settleEase.transform(v));
                      }
                      return Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 1 / 1400)
                          ..rotateY(deg * math.pi / 180),
                        child: child,
                      );
                    },
                    child: course == null ? const SizedBox.expand() : _Page(course: course, world: _page, record: record, newSticker: _newSticker),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Opacity(
                      opacity: _page > 0 ? 1 : .35,
                      child: CircleIconButton(
                        icon: Symbols.chevron_left_rounded,
                        onTap: () => _turn(-1),
                        size: 64,
                        iconSize: 34,
                        shadow: GameColors.black12,
                        shadowY: 5,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 6; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 8,
                              width: i == _page ? 22 : 8,
                              decoration: BoxDecoration(
                                color: i == _page ? LikhoWorlds.byId(course?.worlds[i].themeId ?? '').accent : GameColors.ink15,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Opacity(
                      opacity: _page < 5 ? 1 : .35,
                      child: CircleIconButton(
                        icon: Symbols.chevron_right_rounded,
                        onTap: () => _turn(1),
                        size: 64,
                        iconSize: 34,
                        shadow: GameColors.black12,
                        shadowY: 5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.course, required this.world, required this.record, required this.newSticker});
  final Course course;
  final int world;
  final ChildRecord record;
  final int? newSticker;

  static const _shape = BorderRadius.only(
    topLeft: Radius.circular(14),
    bottomLeft: Radius.circular(14),
    topRight: Radius.circular(30),
    bottomRight: Radius.circular(30),
  );

  @override
  Widget build(BuildContext context) {
    final w = course.worlds[world];
    final theme = LikhoWorlds.byId(w.themeId);
    final levels = course.levelsOf(w);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: StickerColors.page,
        borderRadius: _shape,
        boxShadow: [
          BoxShadow(color: StickerColors.paperEdge, offset: Offset(0, 14)),
          BoxShadow(color: StickerColors.pageEdge, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: _shape,
        child: Stack(
          children: [
            // inset 16px 0 20px -12px rgba(0,0,0,.25): the fold at the spine
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 26,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [UiColors.black25, LikhoColors.clear])),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(30, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          w.name,
                          overflow: TextOverflow.ellipsis,
                          style: LikhoFonts.title(size: 24, weight: FontWeight.w800).copyWith(height: 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, box) {
                      final cell = (box.maxWidth - 14) / 2;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 18,
                        children: [
                          for (final (k, l) in levels.indexed)
                            SizedBox(
                              width: cell,
                              child: l.isBoss
                                  ? _Medal(level: l, got: record.isDone(l.number), isNew: l.number == newSticker)
                                  : _Sticker(level: l, index: k + 1, color: theme.accent, got: record.isDone(l.number), isNew: l.number == newSticker),
                            ),
                        ],
                      );
                    },
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

class _Sticker extends StatelessWidget {
  const _Sticker({required this.level, required this.index, required this.color, required this.got, required this.isNew});
  final CourseLevel level;
  final int index;
  final Color color;
  final bool got, isNew;

  @override
  Widget build(BuildContext context) {
    final icon = IconRegistry.of(level.icon);
    Widget badge;
    if (got) {
      badge = Transform.rotate(
        angle: ((index * 37) % 13 - 6) * math.pi / 180,
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: UiColors.ink18, offset: Offset(0, 6), blurRadius: 14),
              BoxShadow(color: LikhoColors.surface, spreadRadius: 6),
            ],
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(child: _Shine(seconds: 3.5, color: StickerColors.shine)),
                SymbolIcon(icon, size: 46, fill: true, color: LikhoColors.surface),
              ],
            ),
          ),
        ),
      );
      if (isNew) badge = _NewSticker(child: badge);
    } else {
      badge = SizedBox.square(
        dimension: 92,
        child: CustomPaint(
          painter: const DashedBorderPainter(color: UiColors.ink18),
          child: Center(child: SymbolIcon(icon, size: 44, fill: true, color: StickerColors.missIcon)),
        ),
      );
    }
    return Column(
      children: [
        badge,
        const SizedBox(height: 6),
        Text(
          level.name,
          textAlign: TextAlign.center,
          style: LikhoFonts.body(size: 13, weight: FontWeight.w700, color: UiColors.inkBody),
        ),
      ],
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.level, required this.got, required this.isNew});
  final CourseLevel level;
  final bool got, isNew;

  @override
  Widget build(BuildContext context) {
    Widget badge;
    if (got) {
      badge = Container(
        width: 100,
        height: 100,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [StickerColors.goldLight, LikhoColors.primary, StickerColors.goldDeep],
            stops: [0, .5, 1],
          ),
          boxShadow: [
            BoxShadow(color: StickerColors.goldGlow, offset: Offset(0, 8), blurRadius: 18),
            BoxShadow(color: LikhoColors.primary, spreadRadius: 9),
            BoxShadow(color: LikhoColors.surface, spreadRadius: 6),
          ],
        ),
        child: const ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: _Shine(seconds: 2.5, color: StickerColors.shineBoss)),
              SymbolIcon(Symbols.workspace_premium_rounded, size: 52, fill: true, color: LikhoColors.surface),
            ],
          ),
        ),
      );
      if (isNew) badge = _NewSticker(child: badge);
    } else {
      badge = const SizedBox.square(
        dimension: 100,
        child: CustomPaint(
          painter: DashedBorderPainter(color: StickerColors.goldGlow),
          child: Center(child: SymbolIcon(Symbols.workspace_premium_rounded, size: 50, fill: true, color: StickerColors.goldFaint)),
        ),
      );
    }
    return Column(
      children: [
        badge,
        const SizedBox(height: 6),
        Text(
          level.name,
          textAlign: TextAlign.center,
          style: LikhoFonts.body(size: 13, weight: FontWeight.w800, color: StickerColors.bossName),
        ),
      ],
    );
  }
}

/// shine: a light band (110°, 120 px wide) sweeping across, left to right.
class _Shine extends StatelessWidget {
  const _Shine({required this.seconds, required this.color});
  final double seconds;
  final Color color;

  @override
  Widget build(BuildContext context) => Loop(
    seconds: seconds,
    restT: 0,
    child: const SizedBox.expand(),
    builder: (context, t, _) {
      // background-position -120px -> 220px, ease-in-out
      final x = -120 + 340 * Curves.easeInOut.transform(t);
      return CustomPaint(painter: _ShinePainter(x, color));
    },
  );
}

class _ShinePainter extends CustomPainter {
  const _ShinePainter(this.x, this.color);
  final double x;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final band = Rect.fromLTWH(x, 0, 120, size.height);
    final g = LinearGradient(
      begin: const Alignment(-.94, -.34), // 110°
      end: const Alignment(.94, .34),
      colors: [LikhoColors.clear, LikhoColors.clear, color, LikhoColors.clear, LikhoColors.clear],
      stops: const [0, .3, .45, .6, 1],
    );
    canvas.drawRect(band, Paint()..shader = g.createShader(band));
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.x != x;
}

/// A sticker earned since the last visit: slapped on (stickIn) with a
/// sparkle burst, a "thwack" and a bump.
class _NewSticker extends StatelessWidget {
  const _NewSticker({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      StickIn(child: child),
      const SparkleBurst(size: 180, delay: .45, count: 12),
      FeedbackCue(at: .4, play: (f) => f.sticker()),
    ],
  );
}
