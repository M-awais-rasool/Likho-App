import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../world_map/boss_painter.dart';

/// Seconds since the widget appeared, for painters that animate on a clock
/// (the world bosses).
mixin ClockMixin<T extends StatefulWidget> on State<T>, TickerProvider {
  late final Ticker _ticker;
  final ValueNotifier<double> clock = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => clock.value = e.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    clock.dispose();
    super.dispose();
  }
}

/// A world boss (prototype `<Boss world awake dance>`), [width] x [height]
/// (the art is 120 x 100).
class BossFigure extends StatefulWidget {
  const BossFigure({super.key, required this.world, this.awake = true, this.dance = false, this.width = 120, this.height = 100});
  final int world; // 0..5
  final bool awake, dance;
  final double width, height;

  @override
  State<BossFigure> createState() => _BossFigureState();
}

class _BossFigureState extends State<BossFigure> with SingleTickerProviderStateMixin, ClockMixin {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: CustomPaint(
      painter: BossPainter(world: widget.world, awake: widget.awake, dance: widget.dance, time: clock),
    ),
  );
}
