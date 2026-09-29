import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Rounded, flat Likho button (no ripple). Press feedback = slight squash.
class LikhoButton extends StatefulWidget {
  const LikhoButton({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.height = LikhoSize.kidTapMin,
    this.color = LikhoColors.surface,
    this.selectedColor = LikhoColors.primary,
    this.fontSize = 18,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final double height;
  final Color color;
  final Color selectedColor;
  final double fontSize;

  @override
  State<LikhoButton> createState() => _LikhoButtonState();
}

class _LikhoButtonState extends State<LikhoButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutBack,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.height, minWidth: widget.height),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.selected ? widget.selectedColor : widget.color,
              borderRadius: BorderRadius.circular(LikhoRadius.button),
              border: Border.all(color: widget.selected ? LikhoColors.ink : LikhoColors.inkFaint, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: LikhoSpace.s2),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: LikhoFonts.title(size: widget.fontSize, color: enabled ? LikhoColors.ink : LikhoColors.inkSoft),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round colour swatch, 64pt.
class LikhoSwatch extends StatelessWidget {
  const LikhoSwatch({super.key, required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox.square(
        dimension: LikhoSize.kidTapMin,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: selected ? 56 : 48,
            height: selected ? 56 : 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? LikhoColors.ink : LikhoColors.inkFaint, width: selected ? 4 : 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill toggle, 64pt tap target.
class LikhoToggle extends StatelessWidget {
  const LikhoToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: LikhoSize.kidTapMin,
        width: 80,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 72,
            height: 40,
            padding: const EdgeInsets.all(4),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? LikhoColors.success : LikhoColors.surfaceSunk,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: LikhoColors.surface, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
