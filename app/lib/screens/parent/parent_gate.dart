import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/motion.dart';
import '../../feedback/app_feedback.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';

/// 23 Parent gate: a multiplication a child cannot guess, over a blurred
/// screen. Completes with true when the parent picks the right answer, false
/// when closed.
Future<bool> showParentGate(BuildContext context, {math.Random? random}) async {
  final ok = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => ParentGate(random: random),
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
  return ok ?? false;
}

class ParentGate extends StatefulWidget {
  const ParentGate({super.key, this.random});
  final math.Random? random;

  /// Questions from the prototype (openGate).
  static const questions = [(7, 3), (6, 4), (8, 2), (5, 5), (9, 3)];

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate> {
  late final math.Random _rnd = widget.random ?? math.Random();
  late final (int, int) _q = ParentGate.questions[_rnd.nextInt(ParentGate.questions.length)];
  late final List<int> _opts;
  bool _err = false;
  int _shake = 0;

  int get _answer => _q.$1 * _q.$2;

  @override
  void initState() {
    super.initState();
    _opts = [_answer - _q.$1, _answer, _answer + _q.$2]..shuffle(_rnd);
  }

  void _pick(int v) {
    final fb = AppFeedback.of(context);
    if (v == _answer) {
      fb.unlock();
      Navigator.of(context).pop(true);
      return;
    }
    fb.nope();
    setState(() {
      _err = true;
      _shake++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: ColoredBox(
          color: UiColors.scrim,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: BubbleIn(
                  child: Shake(
                    trigger: _shake,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(color: LikhoColors.surface, borderRadius: BorderRadius.circular(LikhoRadius.card)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Parents only', style: LikhoFonts.parent(size: 17, weight: FontWeight.w800)),
                              ),
                              CircleIconButton(
                                icon: Symbols.close_rounded,
                                onTap: () => Navigator.of(context).pop(false),
                                sound: ButtonSound.back,
                                size: 36,
                                iconSize: 20,
                                color: UiColors.chip,
                                shadow: null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Choose the correct answer to continue:',
                            style: LikhoFonts.parent(size: 15, weight: FontWeight.w600, color: UiColors.inkBody),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              '${_q.$1} × ${_q.$2} = ?',
                              textAlign: TextAlign.center,
                              style: LikhoFonts.parent(size: 44, weight: FontWeight.w800).copyWith(height: 1),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (final (i, n) in _opts.indexed) ...[
                                if (i > 0) const SizedBox(width: 10),
                                Expanded(
                                  child: _Answer(n: n, onTap: () => _pick(n)),
                                ),
                              ],
                            ],
                          ),
                          if (_err) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Wrong answer. Please try again.',
                              textAlign: TextAlign.center,
                              style: LikhoFonts.parent(size: 13, weight: FontWeight.w700, color: UiColors.inkLabel),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Answer extends StatefulWidget {
  const _Answer({required this.n, required this.onTap});
  final int n;
  final VoidCallback onTap;

  @override
  State<_Answer> createState() => _AnswerState();
}

class _AnswerState extends State<_Answer> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down ? .95 : 1,
      duration: const Duration(milliseconds: 100),
      child: Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _down ? UiColors.chipPressed : UiColors.chipAlt, borderRadius: BorderRadius.circular(16)),
        child: Text('${widget.n}', style: LikhoFonts.parent(size: 22, weight: FontWeight.w800)),
      ),
    ),
  );
}
