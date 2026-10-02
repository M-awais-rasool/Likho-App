import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/grades.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../feedback/app_feedback.dart';
import '../common/kid_widgets.dart';

/// Parents pick a child's class: [title], an optional [message], the four
/// classes (each with its line) with [selected] picked, and [save] / "Baad
/// mein". Completes with the class picked, or null when closed. Used by
/// the dashboard ("Badlein") and the class check on Who's playing.
Future<Grade?> showGradeDialog(BuildContext context, {required String title, String? message, required Grade selected, String save = 'Save karein'}) =>
    Navigator.of(context).push<Grade>(
      PageRouteBuilder<Grade>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (context, _, _) => GradeDialog(title: title, message: message, selected: selected, save: save),
        transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );

class GradeDialog extends StatefulWidget {
  const GradeDialog({super.key, required this.title, this.message, required this.selected, this.save = 'Save karein'});
  final String title;
  final String? message;
  final Grade selected;
  final String save;

  @override
  State<GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends State<GradeDialog> {
  late Grade _picked = widget.selected;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: ColoredBox(
        color: UiColors.scrimSoft,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: BubbleIn(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: LikhoColors.surface, borderRadius: BorderRadius.circular(LikhoRadius.card)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.title, style: LikhoFonts.parent(size: 19, weight: FontWeight.w800)),
                    if (widget.message case final m?) ...[
                      const SizedBox(height: 8),
                      Text(m, style: LikhoFonts.parent(size: 14, weight: FontWeight.w600, color: UiColors.inkBody).copyWith(height: 1.4)),
                    ],
                    const SizedBox(height: 14),
                    for (final g in Grade.values) ...[
                      if (g != Grade.kg) const SizedBox(height: 8),
                      _Option(
                        grade: g,
                        picked: g == _picked,
                        onTap: () {
                          AppFeedback.of(context).select();
                          setState(() => _picked = g);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FlatButton(label: 'Baad mein', color: UiColors.chip, onTap: () => Navigator.of(context).pop()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FlatButton(label: widget.save, color: LikhoColors.ink, textColor: LikhoColors.surface, onTap: () => Navigator.of(context).pop(_picked)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.grade, required this.picked, required this.onTap});
  final Grade grade;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: picked,
    label: '${grade.label}. ${grade.hint}',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: picked ? ParentColors.gradePicked : UiColors.chipAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: picked ? LikhoColors.primaryDeep : LikhoColors.clear, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(grade.label, style: LikhoFonts.parent(size: 15, weight: FontWeight.w800)),
                  Text(grade.hint, style: LikhoFonts.parent(size: 12, weight: FontWeight.w600, color: LikhoColors.inkMuted)),
                ],
              ),
            ),
            SymbolIcon(
              picked ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
              size: 22,
              color: picked ? LikhoColors.ink : UiColors.chevron,
            ),
          ],
        ),
      ),
    ),
  );
}
