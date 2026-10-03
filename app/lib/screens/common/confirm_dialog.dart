import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import 'kid_widgets.dart';

/// "Are you sure?" card over a blurred screen (same look as the profile
/// delete confirm). Completes with true for [yes], false otherwise.
Future<bool> showConfirm(BuildContext context, {required String title, required String message, required String yes, String no = 'Cancel'}) async {
  final ok = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, _, _) => ConfirmDialog(title: title, message: message, yes: yes, no: no),
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
  return ok ?? false;
}

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({super.key, required this.title, required this.message, required this.yes, this.no = 'Cancel'});
  final String title, message, yes, no;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: ColoredBox(
        color: UiColors.scrimSoft,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: BubbleIn(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(color: LikhoColors.surface, borderRadius: BorderRadius.circular(LikhoRadius.card)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: LikhoFonts.body(size: 20, weight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(message, style: LikhoFonts.body(size: 15, color: UiColors.inkBody, height: 1.5)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FlatButton(label: no, color: UiColors.chip, onTap: () => Navigator.of(context).pop(false)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FlatButton(label: yes, color: LikhoColors.ink, textColor: LikhoColors.surface, onTap: () => Navigator.of(context).pop(true)),
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
