import 'package:flutter/material.dart';

/// The orchard palette is local to Letter Slice.
abstract final class LsTheme {
  static const ink = Color(0xFF174D48);
  static const muted = Color(0xFF587C75);
  static const teal = Color(0xFF168B76);
  static const mint = Color(0xFFE5F5EC);
  static const line = Color(0xFFD4E9DF);
  static const cream = Color(0xFFFFFCF4);
  static const coral = Color(0xFFF06A50);
  static const coralDeep = Color(0xFFC84D39);
  static const gold = Color(0xFFFFC452);
  static const shadow = Color(0x15174D48);

  static BoxDecoration panel({double radius = 24, Color color = cream}) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: .9), width: 1.5),
    boxShadow: const [BoxShadow(color: shadow, blurRadius: 22, offset: Offset(0, 8))],
  );
}
