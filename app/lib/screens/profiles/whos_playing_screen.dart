import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/family.dart';
import '../../data/school_year.dart';
import '../../data/shop_items.dart';
import '../../feedback/app_feedback.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';

/// 06 Who's playing, from the prototype: one round avatar per child (up to
/// 4) and "Naya bacha". Picking a child bounces the avatar and floods the
/// screen with the child's colour from it, then [onPicked] (World Map).
/// The lock opens the parent area ([onParent], behind the parent gate).
/// When a class needs a parent's look (guessed from an age, or a new school
/// year), a card for parents asks for it ([onCheckGrades]; not in the
/// prototype).
class WhosPlayingScreen extends ConsumerStatefulWidget {
  const WhosPlayingScreen({super.key, required this.onPicked, required this.onAddChild, required this.onParent, this.onCheckGrades});

  final VoidCallback onPicked, onAddChild, onParent;
  final VoidCallback? onCheckGrades;

  @override
  ConsumerState<WhosPlayingScreen> createState() => _WhosPlayingScreenState();
}

class _WhosPlayingScreenState extends ConsumerState<WhosPlayingScreen> {
  (Offset, Color)? _zoom;
  Timer? _go;

  @override
  void dispose() {
    _go?.cancel();
    super.dispose();
  }

  void _pick(ChildProfile p, GlobalKey key) {
    if (_zoom != null) return;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || me == null) return;
    ref.read(familyProvider.notifier).selectChild(p.id);
    ref.read(playSessionProvider.notifier).reset();
    ref.read(feedbackProvider)
      ..select()
      ..whoosh();
    setState(() => _zoom = (me.globalToLocal(box.localToGlobal(box.size.center(Offset.zero))), p.swatch.tint));
    _go = Timer(const Duration(milliseconds: 560), () {
      if (!mounted) return;
      widget.onPicked();
      // leave the screen clean for when the parent comes back here
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _zoom = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final now = ref.watch(clockProvider)(), month = ref.watch(schoolYearProvider);
    final checks = [for (final p in family.gradeChecks(now, schoolMonth: month)) p.gradeCheck(now, schoolMonth: month)];
    final zoom = _zoom;
    return StatusBar(
      child: Material(
        child: CssRadialBackground(
          center: const Offset(.5, 0),
          colors: const [ProfileColors.glow, LikhoColors.background],
          stops: const [0, .6],
          child: Stack(
            children: [
              MaxWidth(
                width: 520,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, frameTop(context, 120), 24, 40),
                  child: Column(
                    children: [
                      Text(
                        'Kaun khel raha hai?',
                        textAlign: TextAlign.center,
                        style: LikhoFonts.title(size: 36, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: 140 * 2 + 36,
                        child: Wrap(
                          spacing: 36,
                          runSpacing: 30,
                          children: [
                            for (final (i, p) in family.profiles.indexed)
                              _ChildAvatar(
                                key: ValueKey(p.id),
                                profile: p,
                                accessory: ShopItem.byId(family.recordOf(p.id).wearing)?.accessory,
                                delay: i * .09,
                                onTap: _pick,
                              ),
                            if (family.canAddChild) _AddChild(delay: family.profiles.length * .09, onTap: widget.onAddChild),
                          ],
                        ),
                      ),
                      if (checks.isNotEmpty && widget.onCheckGrades != null) ...[
                        const SizedBox(height: 40),
                        _GradeCheckCard(schoolYear: checks.contains(GradeCheck.newSchoolYear), onTap: widget.onCheckGrades!),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 24,
                top: frameTop(context, 58),
                child: CircleIconButton(icon: Symbols.lock_rounded, iconSize: 24, iconColor: LikhoColors.inkMuted, onTap: widget.onParent),
              ),
              if (zoom != null)
                Positioned(
                  left: zoom.$1.dx - 40,
                  top: zoom.$1.dy - 40,
                  child: IgnorePointer(
                    child: Entrance(
                      duration: const Duration(milliseconds: 550),
                      builder: (context, t, child) => Transform.scale(scale: 1 + 27 * const Cubic(.5, 0, .3, 1).transform(t), child: child),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(color: zoom.$2, shape: BoxShape.circle),
                      ),
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

class _ChildAvatar extends StatefulWidget {
  const _ChildAvatar({super.key, required this.profile, required this.accessory, required this.delay, required this.onTap});
  final ChildProfile profile;
  final String? accessory;
  final double delay;
  final void Function(ChildProfile, GlobalKey) onTap;

  @override
  State<_ChildAvatar> createState() => _ChildAvatarState();
}

class _ChildAvatarState extends State<_ChildAvatar> with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return PopIn(
      delay: widget.delay,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _bounce.forward(from: 0);
          widget.onTap(p, _key);
        },
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) => Transform.scale(scale: keyframes(_bounce.value, const [(0, 1), (.5, .9), (1, 1.1)]), child: child),
          child: SizedBox(
            width: 140,
            child: Column(
              children: [
                Container(
                  key: _key,
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: p.swatch.tint,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 8))],
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        const Positioned.fill(child: CustomPaint(painter: InsetShadowPainter([(Offset(0, -10), UiColors.black04)]))),
                        Positioned(
                          left: 28,
                          top: 18,
                          child: PencilFigure(width: 84, height: 118, color: p.color, accessory: widget.accessory, childAccessory: false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(p.name, style: LikhoFonts.title(size: 24).copyWith(height: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// For parents: "Naya school saal! Class check karein" (or, for classes
/// guessed from an age, "Walidain: class check karein"), with the parents'
/// lock. Opens the parent gate, then the class questions.
class _GradeCheckCard extends StatelessWidget {
  const _GradeCheckCard({required this.schoolYear, required this.onTap});
  final bool schoolYear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FadeIn(
    seconds: .3,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withSound(context, ButtonSound.tap, onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: LikhoColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SymbolIcon(Symbols.school_rounded, size: 24, color: LikhoColors.secondary, fill: true),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                schoolYear ? 'Naya school saal! Class check karein' : 'Walidain: class check karein',
                style: LikhoFonts.parent(size: 15, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            const SymbolIcon(Symbols.lock_rounded, size: 18, color: LikhoColors.inkMuted),
          ],
        ),
      ),
    ),
  );
}

class _AddChild extends StatelessWidget {
  const _AddChild({required this.delay, required this.onTap});
  final double delay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PopIn(
    delay: delay,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          children: [
            const SizedBox.square(
              dimension: 140,
              child: CustomPaint(
                painter: DashedBorderPainter(color: UiColors.ink20),
                child: Center(child: SymbolIcon(Symbols.add_rounded, size: 52, color: UiColors.inkAdd)),
              ),
            ),
            const SizedBox(height: 10),
            Text('Naya bacha', style: LikhoFonts.title(size: 20, color: UiColors.inkLabel).copyWith(height: 1)),
          ],
        ),
      ),
    ),
  );
}
