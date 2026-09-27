import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';

/// 02 Welcome, from export/Likho-Prototype.html (screen "welcome").
///
/// Letters float in the background. After 1.5 s Pencil (waving) "catches"
/// the orange A: it flies to his hand and he cheers.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onSignUp, required this.onLogIn, required this.onTryFirst});

  final VoidCallback onSignUp, onLogIn, onTryFirst;

  static const catchDelay = Duration(milliseconds: 1500);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _caught = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(WelcomeScreen.catchDelay, () {
      if (mounted) setState(() => _caught = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final top = frameTop(context, 0);
    TextStyle letter(double size, Color c) => LikhoFonts.letter(size: size, color: c).copyWith(height: 1);
    return StatusBar(
      child: Material(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [WelcomeColors.top, LikhoColors.background],
              stops: [0, .55],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: w * .12,
                top: top + 120,
                child: FloatY(child: Text('b', style: letter(64, WelcomeColors.letterB))),
              ),
              Positioned(
                right: w * .10,
                top: top + 300,
                child: FloatY(seconds: 7, phase: 2, child: Text('c', style: letter(58, WelcomeColors.letterC))),
              ),
              Positioned(
                left: w * .18,
                top: top + 420,
                child: FloatY(seconds: 5.5, phase: 1, child: Text('e', style: letter(48, WelcomeColors.letterE))),
              ),
              MaxWidth(
                width: 440,
                child: ScrollFill(
                  padding: EdgeInsets.fromLTRB(24, top + 96, 24, 44),
                  child: Column(
                    children: [
                      PencilFigure(width: 170, height: 240, state: _caught ? MascotState.happy : MascotState.wave, holdEnd: true),
                      const SizedBox(height: 22),
                      Text(
                        'Likhna seekho,\nkhel khel mein.',
                        textAlign: TextAlign.center,
                        style: LikhoFonts.title(size: 36, weight: FontWeight.w800).copyWith(height: 1.12),
                      ),
                      const SizedBox(height: 10),
                      // max-width 290 (as padding, so the scroll fill measures it right)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: math.max(0, math.min(440, w) - 48 - 290) / 2),
                        child: Text(
                          '5–8 saal ke bachon ke liye English handwriting.',
                          textAlign: TextAlign.center,
                          style: LikhoFonts.body(size: 17, color: UiColors.inkBody, height: 1.45),
                        ),
                      ),
                      const Spacer(),
                      BigButton(label: 'Shuru karein', icon: Symbols.rocket_launch_rounded, iconFill: true, height: 78, onTap: widget.onSignUp),
                      const SizedBox(height: 14),
                      BigButton(
                        label: 'Mera account hai',
                        icon: Symbols.login_rounded,
                        white: true,
                        height: 70,
                        fontSize: 22,
                        iconSize: 26,
                        onTap: widget.onLogIn,
                      ),
                      const SizedBox(height: 14),
                      TextLink(
                        text: 'Abhi nahi, pehle try karein',
                        underline: true,
                        padding: const EdgeInsets.all(10),
                        style: LikhoFonts.body(size: 16, weight: FontWeight.w700, color: LikhoColors.inkMuted),
                        onTap: widget.onTryFirst,
                      ),
                    ],
                  ),
                ),
              ),
              _CatchLetter(caught: _caught, centerX: w / 2, top: top, style: letter(60, WelcomeColors.letterA)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The orange "A": starts top-left tilted -12°, then flies into Pencil's
/// hand (left/top .7 s cubic-bezier(.34,1.3,.64,1)) and shrinks to .8.
class _CatchLetter extends StatelessWidget {
  const _CatchLetter({required this.caught, required this.centerX, required this.top, required this.style});
  final bool caught;
  final double centerX, top;
  final TextStyle style;

  static const _curve = Cubic(.34, 1.3, .64, 1);

  @override
  Widget build(BuildContext context) {
    // prototype: (56, 150) -> (262, 212) on the 390 px frame (centre 195)
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 700),
      curve: _curve,
      left: centerX + (caught ? 67 : -139),
      top: top + (caught ? 212 : 150),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: caught ? 1 : 0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.ease,
        child: Text('A', style: style),
        builder: (context, k, child) => Transform.rotate(
          angle: -12 * (1 - k) * 3.14159265 / 180,
          child: Transform.scale(scale: 1 - .2 * k, child: child),
        ),
      ),
    );
  }
}
