import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../feedback/app_feedback.dart';
import '../gameplay/widgets/game_buttons.dart';

/// Building blocks shared by the account, profile, room and parent screens.
/// The 3D buttons reuse the gameplay [PushButton].

/// The prototype frame is 844 px tall with a 47 px status bar; its screens
/// place content from the top of the frame. This turns such a y into a
/// top padding under the real status bar.
double frameTop(BuildContext context, double y) => MediaQuery.paddingOf(context).top + y - 47;

/// A screen column that fills the height (so its Spacers push the buttons
/// down) and scrolls instead of overflowing on short phones.
class ScrollFill extends StatelessWidget {
  const ScrollFill({super.key, required this.padding, required this.child});
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - padding.vertical)),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}

/// Screen body limited to the prototype's `max-width` (tablets), centred,
/// filling the height.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Center(
      child: SizedBox(width: math.min(width, box.maxWidth), height: box.maxHeight, child: child),
    ),
  );
}

/// Dark status bar icons on light screens, white on the night screens.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.child, this.light = false});
  final Widget child;
  final bool light;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: light ? LikhoSystemBars.light : LikhoSystemBars.dark,
    child: child,
  );
}

/// Material Symbols Rounded icon, filled like the prototype's
/// `font-variation-settings:'FILL' 1` when [fill] is set.
class SymbolIcon extends StatelessWidget {
  const SymbolIcon(this.icon, {super.key, required this.size, this.color = LikhoColors.ink, this.fill = false, this.weight, this.shadows});
  final IconData icon;
  final double size;
  final Color color;
  final bool fill;
  final double? weight;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size, color: color, fill: fill ? 1 : 0, weight: weight, opticalSize: math.min(48, math.max(20, size)), shadows: shadows);
}

/// A filled icon on its own line, in a box as tall as the prototype's icon
/// spans (1.2 x the icon size), so text under it lines up.
class IconLine extends StatelessWidget {
  const IconLine(this.icon, {super.key, required this.size, required this.color});
  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size * 1.2,
    child: Center(
      child: SymbolIcon(icon, size: size, fill: true, color: color),
    ),
  );
}

/// What a button sounds like when pressed.
enum ButtonSound { press, tap, back, none }

/// Wraps [onTap] so the press is heard (and felt, for main buttons).
VoidCallback? withSound(BuildContext context, ButtonSound sound, VoidCallback? onTap) {
  if (onTap == null || sound == ButtonSound.none) return onTap;
  return () {
    final fb = AppFeedback.of(context);
    switch (sound) {
      case ButtonSound.press:
        fb.press();
      case ButtonSound.tap:
        fb.tap();
      case ButtonSound.back:
        fb.back();
      case ButtonSound.none:
    }
    onTap();
  };
}

/// Big kid button: yellow "Start" style (edge #E0A21A) or white
/// secondary (soft grey edge). [icon] goes before the label.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconAfter,
    this.iconFill = false,
    this.height = 80,
    this.fontSize = 24,
    this.iconSize = 28,
    this.white = false,
    this.textColor,
    this.leading,
    this.opacity = 1,
    this.color,
    this.edgeColor,
    this.sound = ButtonSound.press,
  });

  final ButtonSound sound;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon, iconAfter;
  final bool iconFill;
  final double height, fontSize, iconSize;
  final bool white;
  final Color? textColor;

  /// Extra widget before the label (loading spinner / check).
  final Widget? leading;
  final double opacity;

  /// Overrides the face / edge colour.
  final Color? color, edgeColor;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? (white ? UiColors.link : LikhoColors.ink);
    return Opacity(
      opacity: opacity,
      child: PushButton(
        onTap: withSound(context, sound, onTap),
        color: color ?? (white ? LikhoColors.surface : LikhoColors.primary),
        edgeColor: edgeColor ?? (white ? GameColors.ink10 : LikhoColors.primaryDeep),
        edge: opacity < 1 ? 2 : 6,
        height: height,
        width: double.infinity,
        pressScale: .97,
        innerHighlight: !white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LikhoRadius.button)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            if (icon != null) ...[SymbolIcon(icon!, size: iconSize, color: fg, fill: iconFill), const SizedBox(width: 10)],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: LikhoFonts.title(size: fontSize, color: fg).copyWith(height: 1),
                ),
              ),
            ),
            if (iconAfter != null) ...[const SizedBox(width: 10), SymbolIcon(iconAfter!, size: iconSize, color: fg)],
          ],
        ),
      ),
    );
  }
}

/// Round white button with an icon (back, close, lock). Press = scale .9.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.iconSize = 26,
    this.color = LikhoColors.surface,
    this.iconColor = LikhoColors.ink,
    this.shadow = GameColors.ink08,
    this.shadowY = 4,
    this.iconFill = false,
    this.sound = ButtonSound.tap,
  });

  /// The prototype's arrow_back button.
  const CircleIconButton.back({super.key, required this.onTap, this.size = 48, this.iconSize = 26, this.shadow = GameColors.ink08, this.shadowY = 4})
    : icon = Symbols.arrow_back_rounded,
      color = LikhoColors.surface,
      iconColor = LikhoColors.ink,
      iconFill = false,
      sound = ButtonSound.back;

  final ButtonSound sound;

  final IconData icon;
  final VoidCallback? onTap;
  final double size, iconSize, shadowY;
  final Color color, iconColor;
  final Color? shadow;
  final bool iconFill;

  @override
  Widget build(BuildContext context) => PushButton(
    onTap: withSound(context, sound, onTap),
    color: color,
    width: size,
    height: size,
    shape: const CircleBorder(),
    pressScale: .9,
    shadows: [if (shadow != null) BoxShadow(color: shadow!, offset: Offset(0, shadowY))],
    child: SymbolIcon(icon, size: iconSize, color: iconColor, fill: iconFill),
  );
}

/// White pill with a star and the child's star count (map, room).
class StarPill extends StatelessWidget {
  const StarPill({super.key, required this.stars, this.height = 46, this.iconSize = 28, this.fontSize = 22});
  final int stars;
  final double height, iconSize, fontSize;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.only(left: 10, right: 16),
    decoration: BoxDecoration(
      color: LikhoColors.surface,
      borderRadius: BorderRadius.circular(height / 2),
      boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 4))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SymbolIcon(Symbols.star_rounded, size: iconSize, fill: true, color: LikhoColors.primary),
        const SizedBox(width: 6),
        Text(
          '$stars',
          style: LikhoFonts.title(size: fontSize, weight: FontWeight.w800).copyWith(height: 1),
        ),
      ],
    ),
  );
}

/// Tappable text (links under forms). Press = slight fade.
class TextLink extends StatefulWidget {
  const TextLink({super.key, required this.text, required this.onTap, this.style, this.padding = const EdgeInsets.all(6), this.underline = false});
  final String text;
  final VoidCallback onTap;
  final TextStyle? style;
  final EdgeInsets padding;
  final bool underline;

  @override
  State<TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<TextLink> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? LikhoFonts.body(size: 15, weight: FontWeight.w700, color: UiColors.link);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: withSound(context, ButtonSound.tap, widget.onTap),
      child: AnimatedOpacity(
        opacity: _down ? .6 : 1,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: widget.padding,
          child: widget.underline
              // text-underline-offset: 4px
              ? Center(
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: style.color ?? LikhoColors.ink, width: 1.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(widget.text, style: style),
                    ),
                  ),
                )
              : Text(widget.text, textAlign: TextAlign.center, style: style),
        ),
      ),
    );
  }
}

/// Grey/dark rectangle button used in dialogs ("Cancel" / "Delete").
class FlatButton extends StatelessWidget {
  const FlatButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    this.textColor = LikhoColors.ink,
    this.height = 52,
    this.radius = 16,
    this.fontSize = 15,
  });
  final String label;
  final VoidCallback onTap;
  final Color color, textColor;
  final double height, radius, fontSize;

  @override
  Widget build(BuildContext context) => PushButton(
    onTap: withSound(context, ButtonSound.tap, onTap),
    color: color,
    height: height,
    width: double.infinity,
    pressScale: .96,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    child: Text(
      label,
      style: LikhoFonts.body(size: fontSize, weight: FontWeight.w800, color: textColor),
    ),
  );
}

/// Loading spinner inside buttons: 24 px ring, dark top segment.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => const Spin(
    child: SizedBox.square(dimension: 24, child: CustomPaint(painter: _SpinnerPainter())),
  );
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(1.5);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = UiColors.ink20;
    canvas.drawOval(r, p);
    canvas.drawArc(r, -math.pi * .75, math.pi / 2, false, p..color = LikhoColors.ink);
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => false;
}

/// Dashed outline (the empty "Add child" circle and missing stickers).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.color, this.width = 3, this.dash = 9, this.gap = 6, this.radius});
  final Color color;
  final double width, dash, gap;

  /// null = circle.
  final double? radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(width / 2);
    final path = radius == null ? (Path()..addOval(r)) : (Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius!))));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    for (final m in path.computeMetrics()) {
      final n = (m.length / (dash + gap)).floor();
      final step = m.length / n;
      for (var i = 0; i < n; i++) {
        canvas.drawPath(m.extractPath(i * step, i * step + dash), p);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color;
}

/// A short horizontal shake (wrong answer, not enough stars).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child, this.distance = 8, this.ms = 280});
  final int trigger;
  final Widget child;
  final double distance;
  final int ms;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.ms),
  );

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      if (!_c.isAnimating) return child!;
      final d = widget.distance;
      final x = keyframes(_c.value, [(0, 0), (1 / 3, -d), (2 / 3, d), (1, 0)]);
      return Transform.translate(offset: Offset(x, 0), child: child);
    },
  );
}

/// CSS `radial-gradient(circle at <center>, ...)`: a circle reaching the
/// farthest corner, like the prototype's screen backgrounds.
class CssRadialBackground extends StatelessWidget {
  const CssRadialBackground({super.key, required this.center, required this.colors, required this.stops, this.base, this.child});

  /// Centre as a fraction of the box (0.5, 0 = top middle).
  final Offset center;
  final List<Color> colors;
  final List<double> stops;

  /// Painted under the gradient (for see-through gradients).
  final Color? base;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CssRadialPainter(center, colors, stops, base), child: child ?? const SizedBox.expand());
}

class _CssRadialPainter extends CustomPainter {
  const _CssRadialPainter(this.center, this.colors, this.stops, this.base);
  final Offset center;
  final List<Color> colors;
  final List<double> stops;
  final Color? base;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (base != null) canvas.drawRect(rect, Paint()..color = base!);
    final c = Offset(size.width * center.dx, size.height * center.dy);
    final far = [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight].map((p) => (p - c).distance).reduce(math.max);
    canvas.drawRect(rect, Paint()..shader = RadialGradient(colors: colors, stops: stops).createShader(Rect.fromCircle(center: c, radius: far)));
  }

  @override
  bool shouldRepaint(_CssRadialPainter old) => old.center != center || old.colors != colors || old.base != base;
}

/// CSS inset box-shadows without blur (`inset 0 -6px 0 rgba(...)`): the
/// crescent between the shape and the shape moved by the offset.
class InsetShadowPainter extends CustomPainter {
  const InsetShadowPainter(this.shadows, {this.shape = const CircleBorder()});
  final List<(Offset, Color)> shadows;
  final ShapeBorder shape;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final outer = shape.getOuterPath(r);
    for (final (o, c) in shadows) {
      canvas.drawPath(Path.combine(PathOperation.difference, outer, shape.getOuterPath(r.shift(o))), Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(InsetShadowPainter old) => old.shadows != shadows || old.shape != shape;
}
