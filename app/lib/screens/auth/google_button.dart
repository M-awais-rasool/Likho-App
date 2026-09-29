import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';

/// "Continue with Google": the app's only way to sign in. The yellow main
/// button with the Google mark on a white disc; a spinner while waiting.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onTap, this.loading = false, this.label = 'Continue with Google', this.height = 78, this.fontSize = 22});

  final VoidCallback onTap;
  final bool loading;
  final String label;
  final double height, fontSize;

  @override
  Widget build(BuildContext context) => BigButton(
    label: label,
    height: height,
    fontSize: fontSize,
    onTap: loading ? null : onTap,
    leading: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? const SizedBox.square(key: ValueKey('spin'), dimension: 34, child: Center(child: ButtonSpinner()))
          : const PopIn(
              key: ValueKey('g'),
              seconds: .3,
              child: DecoratedBox(
                decoration: BoxDecoration(color: LikhoColors.surface, shape: BoxShape.circle),
                child: Padding(padding: EdgeInsets.all(5), child: GoogleDot(size: 24)),
              ),
            ),
    ),
  );
}

/// The prototype's stand-in Google mark: a four-colour ring.
class GoogleDot extends StatelessWidget {
  const GoogleDot({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // conic-gradient starts at 12 o'clock
        gradient: SweepGradient(
          transform: GradientRotation(-math.pi / 2),
          colors: [
            UiColors.googleBlue,
            UiColors.googleBlue,
            UiColors.googleGreen,
            UiColors.googleGreen,
            UiColors.googleYellow,
            UiColors.googleYellow,
            UiColors.googleCoral,
            UiColors.googleCoral,
          ],
          stops: [0, .25, .25, .5, .5, .75, .75, 1],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 14 / 26,
          height: size * 14 / 26,
          decoration: const BoxDecoration(color: LikhoColors.surface, shape: BoxShape.circle),
        ),
      ),
    ),
  );
}
