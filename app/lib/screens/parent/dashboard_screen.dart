import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/course_providers.dart';
import '../../data/family.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';
import 'parent_widgets.dart';

/// 19 Parent dashboard, from the prototype: the child's week, letters
/// learnt, first-day vs today handwriting, quick settings and Likho Plus.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.onClose,
    required this.onSettings,
    required this.onSwitchChild,
    required this.onCourse,
    required this.onPlans,
    required this.onRestore,
    required this.onShare,
  });

  final VoidCallback onClose, onSettings, onSwitchChild, onCourse, onPlans, onRestore, onShare;

  /// Each letter A–Z from its own levels ("Letter A", "Small a"): 0 strong
  /// (2 or 3 stars), 1 needs practice (1 star in its capital or small
  /// level), 2 not learned yet (no level of it finished).
  static Map<String, int> letterStatus(ChildRecord r, Course? course) {
    final weakest = <String, int>{};
    for (final l in course?.levels ?? const <CourseLevel>[]) {
      final letter = _letterLevel.firstMatch(l.name)?[1]?.toUpperCase();
      final stars = r.levelStars[l.number];
      if (letter == null || stars == null) continue;
      weakest[letter] = math.min(weakest[letter] ?? 3, stars);
    }
    return {
      for (var i = 0; i < 26; i++)
        String.fromCharCode(65 + i): switch (weakest[String.fromCharCode(65 + i)]) {
          null => 2,
          1 => 1,
          _ => 0,
        },
    };
  }

  static final _letterLevel = RegExp(r'^(?:Letter|Small) ([A-Za-z])$');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);
    final current = ref.watch(progressProvider).current;
    final course = ref.watch(courseProvider).value;
    final total = course?.levels.length ?? 36;
    final worldNo = course == null ? (current - 1) ~/ 6 + 1 : course.worldOf(course.level(current.clamp(1, total))).order;
    final p = family.active, r = family.record;
    final letters = letterStatus(r, course);
    final label = LikhoFonts.parent(size: 13, weight: FontWeight.w600, color: LikhoColors.inkMuted);
    return ParentPage(
      children: [
        ParentHeader(
          icon: Symbols.close_rounded,
          onTap: onClose,
          title: 'Parents',
          trailing: ParentIconButton(icon: Symbols.settings_rounded, onTap: onSettings),
        ),
        ParentCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: p.swatch.tint, shape: BoxShape.circle),
                    child: const ClipOval(
                      child: Stack(children: [Positioned(left: 9, top: 5, child: PencilFigure(width: 34, height: 48, still: 0))]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: LikhoFonts.parent(size: 19, weight: FontWeight.w800)),
                        Text(
                          'Age ${p.age} · World $worldNo',
                          style: LikhoFonts.parent(size: 14, weight: FontWeight.w600, color: LikhoColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: withSound(context, ButtonSound.tap, onSwitchChild),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: UiColors.chipAlt, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Text('Switch', style: LikhoFonts.parent(size: 13, weight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          const SymbolIcon(Symbols.expand_more_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Stat(value: '${r.minutes}', unit: ' min', label: 'practice this week', style: label),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(value: '${r.levelStars.length}', unit: ' / $total', label: 'levels completed', style: label),
                  ),
                ],
              ),
            ],
          ),
        ),
        ParentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Letters', style: LikhoFonts.parent(size: 17, weight: FontWeight.w800)),
                  ),
                  GestureDetector(
                    onTap: withSound(context, ButtonSound.tap, onCourse),
                    child: Row(
                      children: [
                        Text(
                          'Course progress',
                          style: LikhoFonts.parent(size: 14, weight: FontWeight.w700, color: UiColors.link),
                        ),
                        const SymbolIcon(Symbols.chevron_right_rounded, size: 18, color: UiColors.link),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, box) {
                  final cell = (box.maxWidth - 6 * 6) / 7;
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < 26; i++)
                        _LetterTile(ch: String.fromCharCode(65 + i), size: cell, status: letters[String.fromCharCode(65 + i)]!),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Legend(color: LikhoColors.success, text: 'Strong'),
                  _Legend(color: LikhoColors.hint, text: 'Needs practice'),
                  _Legend(color: UiColors.toggleOff, text: 'Not learned yet'),
                ],
              ),
            ],
          ),
        ),
        _Journey(name: p.name, onShare: onShare),
        ParentCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: UiColors.chip)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Session length', style: LikhoFonts.parent(size: 16, weight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    SegmentedMinutes(
                      value: family.settings.sessionMinutes,
                      options: AppSettings.sessionOptions,
                      onChanged: (m) => ref.read(familyProvider.notifier).updateSettings((s) => s.copyWith(sessionMinutes: m)),
                    ),
                  ],
                ),
              ),
              SettingsRow(
                label: 'Music',
                trailing: ParentSwitch(
                  value: family.settings.music,
                  onChanged: (v) => ref.read(familyProvider.notifier).updateSettings((s) => s.copyWith(music: v)),
                ),
              ),
              SettingsRow(
                label: 'Left-handed mode',
                last: true,
                trailing: ParentSwitch(
                  value: family.settings.leftHanded,
                  onChanged: (v) => ref.read(familyProvider.notifier).updateSettings((s) => s.copyWith(leftHanded: v)),
                ),
              ),
            ],
          ),
        ),
        _PlusCard(worlds: course?.worlds.length ?? 6, levels: total, onPlans: onPlans, onRestore: onRestore),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit, required this.label, required this.style});
  final String value, unit, label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: UiColors.parentBg, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            style: LikhoFonts.parent(size: 36, weight: FontWeight.w800).copyWith(height: 1),
            children: [
              TextSpan(
                text: unit,
                style: LikhoFonts.parent(size: 16, weight: FontWeight.w700, color: LikhoColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: style),
      ],
    ),
  );
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.ch, required this.size, required this.status});
  final String ch;
  final double size;
  final int status; // 0 strong, 1 practise, 2 not yet

  @override
  Widget build(BuildContext context) {
    final (bg, fg, bd) = switch (status) {
      0 => (ParentColors.strongBg, ParentColors.strongFg, LikhoColors.success),
      1 => (ParentColors.practiceBg, ParentColors.practiceFg, LikhoColors.hint),
      _ => (UiColors.chip, ParentColors.notYetFg, LikhoColors.clear),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bd, width: 1.5),
      ),
      child: Text(ch, style: LikhoFonts.letter(size: 17, color: fg)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(
        text,
        style: LikhoFonts.parent(size: 12, weight: FontWeight.w600, color: LikhoColors.inkMuted),
      ),
    ],
  );
}

/// "Handwriting journey": the first "A" the child wrote next to today's.
class _Journey extends StatelessWidget {
  const _Journey({required this.name, required this.onShare});
  final String name;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(LikhoRadius.card),
      gradient: const LinearGradient(
        begin: Alignment(-.34, -.94), // 160°
        end: Alignment(.34, .94),
        colors: [ParentColors.journeyTop, ParentColors.journeyBottom],
      ),
      boxShadow: const [BoxShadow(color: ParentColors.journeyShadow, offset: Offset(0, 8), blurRadius: 24)],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -50,
          top: -50,
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(color: GameColors.white35, shape: BoxShape.circle),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HANDWRITING JOURNEY',
                        style: LikhoFonts.parent(size: 12, weight: FontWeight.w800, color: ParentColors.journeyLabel).copyWith(letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 2),
                      Text('Look how far $name has come!', style: LikhoFonts.title(size: 22, weight: FontWeight.w800).copyWith(height: 1.2)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: withSound(context, ButtonSound.tap, onShare),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: LikhoColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: GameColors.black06, offset: Offset(0, 3))],
                    ),
                    child: const Center(child: SymbolIcon(Symbols.ios_share_rounded, size: 24, color: ParentColors.journeyLabel)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: _Polaroid(shaky: true, label: 'Day 1', tilt: -2)),
                const SizedBox(width: 10),
                const SymbolIcon(Symbols.arrow_forward_rounded, size: 30, color: LikhoColors.hint),
                const SizedBox(width: 10),
                const Expanded(child: _Polaroid(shaky: false, label: 'Today', tilt: 2)),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.shaky, required this.label, required this.tilt});
  final bool shaky;
  final String label;
  final double tilt;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: tilt * math.pi / 180,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LikhoColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: GameColors.black08, offset: Offset(0, 6), blurRadius: 14)],
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _LinedPaper(),
                foregroundPainter: _SampleA(shaky: shaky),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: LikhoFonts.parent(size: 12, weight: FontWeight.w800, color: shaky ? LikhoColors.inkMuted : UiColors.okGreen),
          ),
        ],
      ),
    ),
  );
}

/// repeating-linear-gradient(180deg, #fff 0 22%, #DDEBF7 22% 23%)
class _LinedPaper extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = LikhoColors.surface);
    final p = Paint()..color = ParentColors.paperLine;
    for (var k = 0; k < 5; k++) {
      final y = size.height * (k * .23 + .22);
      if (y > size.height) break;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, size.height * .01), p);
    }
  }

  @override
  bool shouldRepaint(_LinedPaper old) => false;
}

/// The prototype's handwriting sample (drawSample): an "A" in a 180 box,
/// wobbly on the first day, neat today. Shown until real samples are saved.
class _SampleA extends CustomPainter {
  _SampleA({required this.shaky});
  final bool shaky;

  @override
  void paint(Canvas canvas, Size size) {
    const segs = [
      [Offset(90, 28), Offset(52, 150)],
      [Offset(90, 28), Offset(128, 150)],
      [Offset(66, 106), Offset(114, 106)],
    ];
    var seed = 7;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280 - .5;
    }

    final s = size.width * .9 / 180;
    canvas.translate(size.width * .05, size.height * .05);
    canvas.scale(s);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = shaky ? 7 : 8
      ..color = LikhoColors.ink;
    for (final (k, seg) in segs.indexed) {
      final path = Path();
      for (var i = 0; i <= 14; i++) {
        final t = i / 14;
        var p = Offset.lerp(seg[0], seg[1], t)!;
        if (shaky) p += Offset(rnd() * 9 + (k == 2 ? 6 : 0), rnd() * 9 + (k == 2 ? 8 : 0));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SampleA old) => old.shaky != shaky;
}

class _PlusCard extends ConsumerWidget {
  const _PlusCard({required this.worlds, required this.levels, required this.onPlans, required this.onRestore});
  final int worlds, levels;
  final VoidCallback onPlans, onRestore;

  /// What the card says once Likho Plus is on: the plan and when it renews.
  static String _active(FamilyState f) {
    final plan = switch (f.plusPlan) {
      'monthly' => 'Monthly plan',
      'yearly' => 'Yearly plan',
      _ => 'Likho Plus is on',
    };
    final until = f.plusUntil;
    if (until == null) return '$plan. Every world and level is open.';
    final day = formatDay(until);
    if (f.plusStore != 'google_play') return '$plan until $day. Every world and level is open.';
    return f.plusRenews ? '$plan, renews on $day. Every world and level is open.' : "$plan, ends on $day (it won't renew).";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);
    final on = family.subscribed;
    return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: LikhoColors.ink, borderRadius: BorderRadius.circular(24)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SymbolIcon(Symbols.workspace_premium_rounded, size: 28, fill: true, color: LikhoColors.primary),
            const SizedBox(width: 10),
            Text(
              'Likho Plus',
              style: LikhoFonts.parent(size: 18, weight: FontWeight.w800, color: LikhoColors.surface),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: .8,
          child: Text(
            on ? _active(family) : 'All $worlds worlds, $levels levels and weekly progress. First 7 days free.',
            style: LikhoFonts.parent(size: 14, weight: FontWeight.w600, color: LikhoColors.surface).copyWith(height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: withSound(context, ButtonSound.tap, onPlans),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: LikhoColors.primary, borderRadius: BorderRadius.circular(14)),
                child: Text(on ? 'Your plan' : 'See plans', style: LikhoFonts.parent(size: 15, weight: FontWeight.w800)),
              ),
            ),
            if (!on) GestureDetector(
              onTap: withSound(context, ButtonSound.tap, onRestore),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Opacity(
                  opacity: .75,
                  child: Text(
                    'Restore purchases',
                    style: LikhoFonts.parent(size: 14, weight: FontWeight.w700, color: LikhoColors.surface),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  }
}
