import 'dart:async';

import 'package:flutter/material.dart';

import '../../feedback/game_feedback.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';

/// 09 Placement done, from the prototype: "Chalo shuru karein!" and Pencil
/// cheering; moves on to the World Map after 2.6 s or on tap. [message]
/// replaces the line when the warm-up picked another start ("Small Letter
/// Cove se shuru karte hain!").
class PlacementDoneScreen extends StatefulWidget {
  const PlacementDoneScreen({super.key, required this.onDone, this.message = 'Chalo shuru karein!'});
  final VoidCallback onDone;
  final String message;

  static const length = Duration(milliseconds: 2600);

  @override
  State<PlacementDoneScreen> createState() => _PlacementDoneScreenState();
}

class _PlacementDoneScreenState extends State<PlacementDoneScreen> {
  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(PlacementDoneScreen.length, _leave);
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
                  BubbleIn(delay: .3, seconds: .4, alignment: Alignment.bottomCenter, child: _Bubble(widget.message)),
                  FeedbackCue(at: .3, play: (f) => f.done()),
                  const SizedBox(height: 10 + 10),
                  const PencilFigure(width: 180, height: 254, state: MascotState.happy, holdEnd: true),
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
  const _Bubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.bottomCenter,
    children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: LikhoColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: GameColors.ink10, offset: Offset(0, 8), blurRadius: 20)],
        ),
        child: Text(text, textAlign: TextAlign.center, style: LikhoFonts.title(size: 30, weight: FontWeight.w800).copyWith(height: 1.1)),
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
