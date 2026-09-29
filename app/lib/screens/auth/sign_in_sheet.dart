import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../feedback/app_feedback.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';
import 'google_button.dart';

/// Asks a guest ("pehle try karein") to sign in before going further: the
/// next level, the room, the profile, parent settings. Completes with true
/// once signed in, false when closed.
Future<bool> showSignInSheet(BuildContext context, {required Future<bool> Function() onGoogle}) async {
  AppFeedback.of(context).tap();
  final ok = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => SignInSheet(onGoogle: onGoogle),
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
  return ok ?? false;
}

class SignInSheet extends StatefulWidget {
  const SignInSheet({super.key, required this.onGoogle});
  final Future<bool> Function() onGoogle;

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  bool _busy = false;
  int _oops = 0;

  Future<void> _google() async {
    setState(() => _busy = true);
    final ok = await widget.onGoogle();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _oops++;
    });
  }

  void _close() {
    if (_busy) return;
    AppFeedback.of(context).back();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      type: MaterialType.transparency,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(onTap: _close, child: const ColoredBox(color: UiColors.scrimSoft)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: RiseIn(
                  distance: 90,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(24, 14, 24, 20 + bottom),
                    decoration: const BoxDecoration(
                      color: LikhoColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(LikhoRadius.card)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: CircleIconButton(
                            icon: Symbols.close_rounded,
                            onTap: _close,
                            sound: ButtonSound.back,
                            size: 36,
                            iconSize: 20,
                            color: UiColors.chip,
                            shadow: null,
                          ),
                        ),
                        Center(
                          child: PencilFigure(
                            width: 110,
                            height: 150,
                            state: _busy
                                ? MascotState.watching
                                : _oops > 0
                                ? MascotState.encourage
                                : MascotState.wave,
                            replay: _oops,
                            holdEnd: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Shabash! Aage khelne ke liye\naccount banayein',
                          textAlign: TextAlign.center,
                          style: LikhoFonts.title(size: 24, weight: FontWeight.w800).copyWith(height: 1.15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Walidain Google se sign in karein. Taare, stickers aur har level ki progress save rahegi.',
                          textAlign: TextAlign.center,
                          style: LikhoFonts.body(size: 15, color: UiColors.inkBody, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        GoogleButton(loading: _busy, onTap: _google, height: 72, fontSize: 21),
                        const SizedBox(height: 6),
                        Center(
                          child: TextLink(
                            text: 'Baad mein',
                            padding: const EdgeInsets.all(10),
                            style: LikhoFonts.body(size: 15, weight: FontWeight.w700, color: LikhoColors.inkMuted),
                            onTap: _close,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
