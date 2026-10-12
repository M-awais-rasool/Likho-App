import 'dart:async';

import 'package:flutter/material.dart';

import '../../feedback/game_feedback.dart';
import '../../feedback/pencil_lines.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';

/// 09 Placement done, from the prototype: "Let's get started!" and Pencil
/// cheering; moves on to the World Map after 2.6 s or on tap. Pencil says
/// the line first, then cheers (so it may stay a little longer).
class PlacementDoneScreen extends StatefulWidget {
  const PlacementDoneScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  static const length = Duration(milliseconds: 2600);

  /// How long the cheer shows after the line, at least.
  static const cheer = Duration(milliseconds: 1400);

  @override
  State<PlacementDoneScreen> createState() => _PlacementDoneScreenState();
}

class _PlacementDoneScreenState extends State<PlacementDoneScreen> {
  Timer? _timer;
  bool _left = false, _cheering = false;
  final _shown = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _timer = Timer(PlacementDoneScreen.length, _leave);
  }

  /// The line is said: cheer, and stay until the cheer has been seen.
  void _said() {
    if (_left || !mounted) return;
    setState(() => _cheering = true);
    final left = PlacementDoneScreen.length - _shown.elapsed;
    _timer?.cancel();
    _timer = Timer(left > PlacementDoneScreen.cheer ? left : PlacementDoneScreen.cheer, _leave);
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    _timer?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatusBar(
      child: Material(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: CssRadialBackground(
            center: const Offset(.5, .5),
            colors: const [ProfileColors.placementGlow, LikhoColors.background],
            stops: const [0, .7],
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BubbleIn(delay: .3, seconds: .4, alignment: Alignment.bottomCenter, child: _Bubble()),
                  FeedbackCue(at: .3, play: (f) => f.done()),
                  const SizedBox(height: 10 + 10),
                  PencilFigure(
                    width: 180,
                    height: 254,
                    state: _cheering ? MascotState.happy : MascotState.idle,
                    holdEnd: true,
                    say: PencilLines.letsStart,
                    sayAt: const Duration(milliseconds: 300),
                    onSaid: _said,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.bottomCenter,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: LikhoColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: GameColors.ink10, offset: Offset(0, 8), blurRadius: 20)],
        ),
        child: Text("Let's get started!", style: LikhoFonts.title(size: 30, weight: FontWeight.w800).copyWith(height: 1)),
      ),
      Positioned(
        bottom: -10,
        child: Transform.rotate(
          angle: .785398,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: LikhoColors.surface, borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    ],
  );
}
