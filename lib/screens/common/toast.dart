import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';

/// Short dark message at the bottom of the screen for 1.8 s (prototype
/// toastMsg), e.g. "Help center khulega".
abstract final class Toast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 24,
        right: 24,
        bottom: 48,
        child: IgnorePointer(
          child: Center(
            child: BubbleIn(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: LikhoColors.ink, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  message,
                  style: LikhoFonts.body(size: 14, weight: FontWeight.w700, color: LikhoColors.surface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 1800), hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}
