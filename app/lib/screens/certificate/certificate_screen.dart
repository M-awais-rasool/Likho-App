import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/family.dart';
import '../../feedback/game_feedback.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/clock.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';

/// 18 Certificate (after level 36), from the prototype: the six woken bosses
/// dance over Pencil in a crown, and the certificate pops in. Print makes a
/// PDF ([onPrint]); "Letter Playground" goes back to the map.
class CertificateScreen extends ConsumerWidget {
  const CertificateScreen({super.key, required this.onPrint, required this.onPlayground, this.date});

  final VoidCallback onPrint, onPlayground;
  final DateTime? date;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(familyProvider.select((f) => f.active.name));
    final top = frameTop(context, 0);
    Widget dot(Color c, double size, double seconds) => Twinkle(
      seconds: seconds,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
    );
    return StatusBar(
      light: true,
      child: Material(
        color: GameColors.spaceBottom,
        child: FadeIn(
          seconds: .4,
          child: CssRadialBackground(
            center: const Offset(.5, .2),
            colors: const [CertificateColors.top, CertificateColors.bottom],
            stops: const [0, .7],
            child: Stack(
              children: [
                // the biggest moment of the course: signature motif as the certificate pops
                FeedbackCue(at: .3, play: (f) => f.milestone()),
                Positioned(left: 40, top: top + 90, child: dot(CertificateColors.star, 5, 2)),
                Positioned(right: 60, top: top + 140, child: dot(LikhoColors.surface, 4, 3)),
                Positioned(left: 120, top: top + 200, child: dot(LikhoColors.surface, 3, 2.4)),
                MaxWidth(
                  width: 460,
                  child: ScrollFill(
                    padding: EdgeInsets.fromLTRB(20, top + 64, 20, 40),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [for (var w = 0; w < 6; w++) BossFigure(world: w, dance: true, width: 52, height: 44)],
                        ),
                        const SizedBox(height: 4),
                        const PencilFigure(width: 110, height: 156, state: MascotState.dance, accessory: MascotAccessory.crown, repeat: true),
                        const SizedBox(height: 14),
                        BigPop(
                          delay: .3,
                          child: _Certificate(name: name, date: formatDate(date ?? DateTime.now())),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            CircleIconButton(
                              icon: Symbols.print_rounded,
                              onTap: onPrint,
                              size: 80,
                              iconSize: 34,
                              iconColor: LikhoColors.secondary,
                              shadow: GameColors.black20,
                              shadowY: 6,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: BigButton(
                                label: 'Letter Playground',
                                icon: Symbols.sports_esports_rounded,
                                iconFill: true,
                                fontSize: 22,
                                onTap: onPlayground,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _Certificate extends StatelessWidget {
  const _Certificate({required this.name, required this.date});
  final String name, date;

  @override
  Widget build(BuildContext context) {
    final small = LikhoFonts.body(size: 12, weight: FontWeight.w700, color: UiColors.inkHint);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LikhoColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: UiColors.black35, offset: Offset(0, 20), blurRadius: 50)],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LikhoColors.primary, width: 3),
        ),
        child: Stack(
          children: [
            // inset 0 0 0 5px #FFF8EC, inset 0 0 0 7px rgba(224,162,26,.4): a thin gold line 5 px inside
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: StickerColors.goldGlow, width: 2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
              child: Column(
                children: [
                  const IconLine(Symbols.workspace_premium_rounded, size: 48, color: LikhoColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    'CERTIFICATE',
                    style: LikhoFonts.body(size: 14, weight: FontWeight.w800, color: UiColors.inkHint).copyWith(letterSpacing: 14 * .14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: LikhoFonts.title(size: 40, weight: FontWeight.w800).copyWith(height: 1),
                  ),
                  const SizedBox(height: 6),
                  // max-width 260 (as padding, so the scroll fill measures it right)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: math.max(0, math.min(460, MediaQuery.sizeOf(context).width) - 40 - 20 - 6 - 36 - 260) / 2),
                    child: Text(
                      'has completed the full Likho English course — 6 worlds, 36 levels!',
                      textAlign: TextAlign.center,
                      style: LikhoFonts.body(size: 15, color: UiColors.inkBody, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 30,
                    children: [
                      Text(date, style: small),
                      Text('Pencil · Likho', style: small),
                    ],
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
