import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../feedback/game_feedback.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';

/// 14 Session end, from the prototype: the sky slowly turns to evening, the
/// moon comes out, stars twinkle and Pencil falls asleep in bed. "Ghar"
/// goes back to the map (and starts a new session).
class SessionEndScreen extends StatelessWidget {
  const SessionEndScreen({super.key, required this.stars, required this.onHome});
  final int stars; // stars earned in this session
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final top = frameTop(context, 0);
    Widget dot(double size, double seconds, double delay) => Twinkle(
      seconds: seconds,
      delay: delay,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: LikhoColors.surface, shape: BoxShape.circle),
      ),
    );
    return StatusBar(
      light: true,
      child: Material(
        color: LikhoColors.background,
        child: Stack(
          children: [
            // Pencil nods off: a music-box lullaby as the title fades in
            FeedbackCue(at: .6, play: (f) => f.lullaby()),
            const Positioned.fill(
              child: FadeIn(
                seconds: 2.2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [SessionEndColors.skyTop, SessionEndColors.skyMid, SessionEndColors.skyBottom],
                      stops: [0, .45, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 56,
              top: top + 110,
              child: FadeIn(
                delay: 1,
                seconds: 2,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: SessionEndColors.moon,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: SessionEndColors.moonGlow, blurRadius: 50)],
                  ),
                  child: const CustomPaint(painter: InsetShadowPainter([(Offset(-14, -6), SessionEndColors.moonShade)])),
                ),
              ),
            ),
            Positioned(left: 60, top: top + 150, child: dot(5, 3, 1.5)),
            Positioned(left: 150, top: top + 90, child: dot(4, 4, 2)),
            Positioned(right: 140, top: top + 230, child: dot(4, 3.4, 1.2)),
            MaxWidth(
              width: 440,
              child: ScrollFill(
                padding: EdgeInsets.fromLTRB(24, top + 230, 24, 44),
                child: Column(
                  children: [
                    FadeIn(
                      delay: .6,
                      seconds: 1,
                      child: Text(
                        'Aaj ke liye bas!',
                        textAlign: TextAlign.center,
                        style: LikhoFonts.title(size: 36, weight: FontWeight.w800, color: LikhoColors.surface),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: .9,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SymbolIcon(Symbols.star_rounded, size: 28, fill: true, color: SessionEndColors.star),
                          const SizedBox(width: 6),
                          Text(
                            '$stars stars aaj',
                            style: LikhoFonts.title(size: 22, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 200,
                      height: 120,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned(
                            bottom: 0,
                            left: -10,
                            right: -10,
                            height: 70,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: SessionEndColors.bed,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(40), bottom: Radius.circular(20)),
                              ),
                              child: const CustomPaint(
                                painter: InsetShadowPainter(
                                  [(Offset(0, -8), GameColors.black06)],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(40), bottom: Radius.circular(20)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 42,
                            left: 10,
                            child: Container(
                              width: 80,
                              height: 36,
                              decoration: BoxDecoration(color: LikhoColors.surface, borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          const Positioned(bottom: 26, child: PencilFigure(width: 130, height: 184, state: MascotState.asleep)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    _HomeButton(onTap: onHome),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BigButton(
    label: 'Ghar',
    icon: Symbols.home_rounded,
    iconFill: true,
    iconSize: 30,
    white: true,
    color: UiColors.white92,
    edgeColor: SessionEndColors.buttonEdge,
    textColor: LikhoColors.ink,
    onTap: onTap,
  );
}
