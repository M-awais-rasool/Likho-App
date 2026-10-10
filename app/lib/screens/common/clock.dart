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

/// A world boss (lib/bosses), [width] x [height] (the art is 120 x 100).
/// When [awake] turns true it first plays the wake-up (eyes flutter, a big
/// yawn and stretch, a happy hop), then dances or idles. Asleep and
/// [dozing], it peeks around now and then; each time [pokes] goes up it
/// startles (a flutter, a yawn, a "wow") and nods off again.
class BossFigure extends StatefulWidget {
  const BossFigure({
    super.key,
    required this.world,
    this.awake = true,
    this.dance = false,
    this.dozing = false,
    this.pokes = 0,
    this.width = 120,
    this.height = 100,
  });
  final int world; // BossPainter.indexOf(bossId)
  final bool awake, dance, dozing;
  final int pokes;
  final double width, height;

  @override
  State<BossFigure> createState() => _BossFigureState();
}

class _BossFigureState extends State<BossFigure> with SingleTickerProviderStateMixin, ClockMixin {
  double? _wokeAt, _pokedAt;

  @override
  void didUpdateWidget(BossFigure old) {
    super.didUpdateWidget(old);
    if (widget.awake && !old.awake) _wokeAt = clock.value;
    if (widget.pokes > old.pokes && !widget.awake) _pokedAt = clock.value;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: CustomPaint(
      painter: BossPainter(
        world: widget.world,
        awake: widget.awake,
        dance: widget.dance,
        dozing: widget.dozing,
        time: clock,
        wokeAt: _wokeAt,
        pokedAt: _pokedAt,
      ),
    ),
  );
}
