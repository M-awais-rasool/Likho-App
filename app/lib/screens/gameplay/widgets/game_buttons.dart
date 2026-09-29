import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../design/tokens.dart';

/// Flat "3D" button from the prototype: a solid edge below ([edge] px) that
/// the button sinks into when pressed (translateY + slight scale).
class PushButton extends StatefulWidget {
  const PushButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    this.edgeColor,
    this.edge = 0,
    this.shape = const StadiumBorder(),
    this.width,
    this.height,
    this.pressScale = .92,
    this.innerHighlight = false,
    this.shadows = const [],
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color? edgeColor;
  final double edge;
  final ShapeBorder shape;
  final double? width, height;
  final double pressScale;
  final bool innerHighlight; // inset 0 2px 0 rgba(255,255,255,.35)
  final List<BoxShadow> shadows;

  @override
  State<PushButton> createState() => _PushButtonState();
}

class _PushButtonState extends State<PushButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final sink = _down ? (widget.edge > 0 ? widget.edge * .6 : 0.0) : 0.0;
    final face = SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: widget.color, shape: widget.shape),
        child: widget.innerHighlight
            ? CustomPaint(
                foregroundPainter: _InsetHighlight(widget.shape),
                child: Center(child: widget.child),
              )
            : Center(child: widget.child),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressScale : 1,
        duration: const Duration(milliseconds: 180),
        curve: const Cubic(.34, 1.56, .64, 1),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: sink),
          duration: const Duration(milliseconds: 120),
          child: face,
          builder: (context, s, face) {
            final edge = widget.edge - s;
            return Transform.translate(
              offset: Offset(0, s),
              child: CustomPaint(
                painter: OuterShadowPainter(widget.shape, [
                  ...widget.shadows,
                  if (widget.edgeColor != null && edge > 0) BoxShadow(color: widget.edgeColor!, offset: Offset(0, edge)),
                ]),
                child: face,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// CSS `box-shadow` (outer): painted only outside the shape, so a
/// see-through face (the 85 % white Home button) does not show it.
class OuterShadowPainter extends CustomPainter {
  const OuterShadowPainter(this.shape, this.shadows);
  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final r = Offset.zero & size;
    canvas
      ..save()
      ..clipPath(Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(r.inflate(100))
        ..addPath(shape.getOuterPath(r), Offset.zero));
    for (final s in shadows) {
      canvas.drawPath(shape.getOuterPath(r.shift(s.offset).inflate(s.spreadRadius)), s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OuterShadowPainter old) => old.shape != shape || !listEquals(old.shadows, shadows);
}

class _InsetHighlight extends CustomPainter {
  const _InsetHighlight(this.shape);
  final ShapeBorder shape;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final outer = shape.getOuterPath(r);
    final shifted = shape.getOuterPath(r.shift(const Offset(0, 2)));
    canvas.drawPath(Path.combine(PathOperation.difference, outer, shifted), Paint()..color = GameColors.white35);
  }

  @override
  bool shouldRepaint(_InsetHighlight old) => false;
}

/// Home (exit to map): 56 white circle.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PushButton(
    onTap: onTap,
    color: GameColors.white85,
    width: 56,
    height: 56,
    shape: const CircleBorder(),
    pressScale: .9,
    shadows: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 4))],
    child: const Icon(Symbols.home_rounded, size: 28, fill: 1, opticalSize: 28, color: LikhoColors.ink),
  );
}

/// Replay the prompt: 64 blue circle with a speaker.
class ReplayButton extends StatelessWidget {
  const ReplayButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PushButton(
    onTap: onTap,
    color: LikhoColors.secondary,
    edgeColor: GameColors.secondaryDeep,
    edge: 5,
    width: 64,
    height: 64,
    shape: const CircleBorder(),
    innerHighlight: true,
    child: const Icon(Symbols.volume_up_rounded, size: 34, fill: 1, opticalSize: 34, color: LikhoColors.surface),
  );
}
