import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../feedback/app_feedback.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';
import 'google_button.dart';

/// 02 Welcome, from design/prototype/Likho-Prototype.html (screen "welcome").
///
/// Letters float in the background. After 1.5 s Pencil (waving) "catches"
/// the orange A: it flies to his hand and he cheers.
///
/// One way in: "Continue with Google" signs a parent in, and makes the
/// account the first time (no sign up, no password). "Try it first"
/// plays without an account.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onGoogle, required this.onTryFirst, this.onTerms, this.onTestUser});

  /// Signs in; true when it worked (the flow then moves on), false when the
  /// parent closed Google or it failed (the flow shows why).
  final Future<bool> Function() onGoogle;

  /// Signs in as the shared test account (test builds only; null hides it).
  final Future<bool> Function()? onTestUser;
  final VoidCallback onTryFirst;
  final VoidCallback? onTerms;

  static const catchDelay = Duration(milliseconds: 1500);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _caught = false;
  bool _busy = false;
  int _oops = 0; // Pencil encourages after a failed sign-in
  Timer? _timer, _land;

  Future<void> _google() => _signIn(widget.onGoogle);

  Future<void> _signIn(Future<bool> Function() signIn) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await signIn();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _oops++;
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(WelcomeScreen.catchDelay, () {
      if (mounted) setState(() => _caught = true);
    });
    _land = Timer(WelcomeScreen.catchDelay + const Duration(milliseconds: 420), () {
      if (mounted) AppFeedback.of(context).catchLetter();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _land?.cancel();
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
                      PencilFigure(
                        width: 170,
                        height: 240,
                        state: _busy
                            ? MascotState.watching
                            : _oops > 0
                            ? MascotState.encourage
                            : _caught
                            ? MascotState.happy
                            : MascotState.wave,
                        replay: _oops,
                        holdEnd: true,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Learn to write\nthrough play.',
                        textAlign: TextAlign.center,
                        style: LikhoFonts.title(size: 36, weight: FontWeight.w800).copyWith(height: 1.12),
                      ),
                      const SizedBox(height: 10),
                      // max-width 290 (as padding, so the scroll fill measures it right)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: math.max(0, math.min(440, w) - 48 - 290) / 2),
                        child: Text(
                          'English handwriting for children aged 5–8.',
                          textAlign: TextAlign.center,
                          style: LikhoFonts.body(size: 17, color: UiColors.inkBody, height: 1.45),
                        ),
                      ),
                      const Spacer(),
                      GoogleButton(loading: _busy, onTap: _google),
                      if (widget.onTestUser case final test?) ...[
                        const SizedBox(height: 10),
                        TestUserButton(onTap: _busy ? null : () => _signIn(test)),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        "First time? We'll create your account.",
                        textAlign: TextAlign.center,
                        style: LikhoFonts.body(size: 14, weight: FontWeight.w600, color: LikhoColors.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      TextLink(
                        text: 'Not now, try it first',
                        underline: true,
                        padding: const EdgeInsets.all(10),
                        style: LikhoFonts.body(size: 16, weight: FontWeight.w700, color: LikhoColors.inkMuted),
                        onTap: _busy ? () {} : widget.onTryFirst,
                      ),
                      if (widget.onTerms != null)
                        TextLink(
                          text: 'By continuing, you agree to the Terms and Privacy Policy',
                          padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                          style: LikhoFonts.body(size: 12, weight: FontWeight.w600, color: LikhoColors.inkMuted),
                          onTap: widget.onTerms!,
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

/// "Test User" (test builds): a quiet outlined button under Google, so it
/// is clearly not the way parents sign in.
class TestUserButton extends StatelessWidget {
  const TestUserButton({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onTap == null
          ? null
          : () {
              AppFeedback.of(context).press();
              onTap!();
            },
      icon: const Icon(Symbols.science_rounded, size: 22, fill: 1, opticalSize: 24),
      label: Text('Sign in as Test User', style: LikhoFonts.title(size: 18, weight: FontWeight.w700, color: LikhoColors.inkMuted).copyWith(height: 1)),
      style: OutlinedButton.styleFrom(
        foregroundColor: LikhoColors.inkMuted,
        side: const BorderSide(color: UiColors.inkHint, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
  );
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
