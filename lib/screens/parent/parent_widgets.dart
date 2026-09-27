import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';

/// Pieces of the parent screens (19–22): calmer, Nunito, white cards on
/// #F7F4EE.

/// Page frame: 56 px top, 20 px sides, max 560 wide, scrolling.
class ParentPage extends StatelessWidget {
  const ParentPage({super.key, required this.children, this.gap = 16, this.background = UiColors.parentBg, this.gradient});
  final List<Widget> children;
  final double gap;
  final Color background;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => StatusBar(
    child: Material(
      color: background,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: MaxWidth(
          width: 560,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, frameTop(context, 56), 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in children.indexed) ...[if (i > 0) SizedBox(height: gap), c],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Title row: square icon button + title (+ trailing button).
class ParentHeader extends StatelessWidget {
  const ParentHeader({super.key, required this.icon, required this.onTap, required this.title, this.trailing});
  final IconData icon;
  final VoidCallback onTap;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ParentIconButton(icon: icon, onTap: onTap),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title, style: LikhoFonts.parent(size: 22, weight: FontWeight.w800)),
      ),
      ?trailing,
    ],
  );
}

/// 44 px white rounded-square button.
class ParentIconButton extends StatelessWidget {
  const ParentIconButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Press(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: LikhoColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: GameColors.ink10, offset: Offset(0, 1), blurRadius: 3)],
      ),
      child: Center(child: SymbolIcon(icon, size: 22)),
    ),
  );
}

/// White card. [soft] adds the dashboard's wide soft shadow.
class ParentCard extends StatelessWidget {
  const ParentCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 24, this.soft = true});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool soft;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: LikhoColors.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        const BoxShadow(color: GameColors.ink06, offset: Offset(0, 1), blurRadius: 3),
        if (soft) const BoxShadow(color: UiColors.ink05, offset: Offset(0, 8), blurRadius: 24),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

/// Uppercase grey label above a settings group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
    child: Text(
      text.toUpperCase(),
      style: LikhoFonts.parent(size: 12, weight: FontWeight.w800, color: UiColors.inkLabel).copyWith(letterSpacing: 12 * .08),
    ),
  );
}

/// One 56 px settings row with a divider under it (unless [last]).
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.label, this.trailing, this.onTap, this.last = false, this.labelColor = LikhoColors.ink, this.height = 56});
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;
  final Color labelColor;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      height: height,
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: UiColors.chip)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: LikhoFonts.parent(size: 15, weight: FontWeight.w700, color: labelColor),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return onTap == null ? row : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

/// iOS-like switch: 52 x 32, green when on, springy knob.
class ParentSwitch extends StatelessWidget {
  const ParentSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 52,
      height: 32,
      decoration: BoxDecoration(color: value ? LikhoColors.success : UiColors.toggleOff, borderRadius: BorderRadius.circular(16)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 250),
        curve: springOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(2),
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: LikhoColors.surface,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: GameColors.black20, offset: Offset(0, 2), blurRadius: 4)],
          ),
        ),
      ),
    ),
  );
}

/// Segmented control for the session length (5 / 10 / 15 min).
class SegmentedMinutes extends StatelessWidget {
  const SegmentedMinutes({super.key, required this.value, required this.options, required this.onChanged, this.compact = false});
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 3.0 : 4.0;
    return Container(
      padding: EdgeInsets.all(gap),
      decoration: BoxDecoration(color: UiColors.chip, borderRadius: BorderRadius.circular(compact ? 12 : 14)),
      child: Row(
        children: [
          for (final (i, m) in options.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: compact ? 32 : 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m == value ? LikhoColors.surface : UiColors.chip,
                    borderRadius: BorderRadius.circular(compact ? 9 : 11),
                    boxShadow: [if (m == value) const BoxShadow(color: GameColors.ink12, offset: Offset(0, 2), blurRadius: 6)],
                  ),
                  child: Text(
                    '$m min',
                    style: LikhoFonts.parent(size: compact ? 13 : 15, weight: m == value ? FontWeight.w800 : FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Press extends StatefulWidget {
  const _Press({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(scale: _down ? .92 : 1, duration: const Duration(milliseconds: 100), child: widget.child),
  );
}
