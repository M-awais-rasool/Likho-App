import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family.dart';

/// The prototype's CSS keyframe animations as widgets, so every screen moves
/// the same way. One-shot entrances ([Entrance] and its presets) run once
/// after a delay; loops ([Loop] and its presets) stop while the parent has
/// "Reduce motion" on.

/// CSS cubic-bezier(.34,1.56,.64,1): the prototype's springy ease.
const Curve springOut = Cubic(.34, 1.56, .64, 1);

/// CSS cubic-bezier(.3,.7,.4,1) (splashIn, starDrop, dropIn).
const Curve dropEase = Cubic(.3, .7, .4, 1);

/// CSS cubic-bezier(.2,.8,.3,1) (stickIn, page flips).
const Curve settleEase = Cubic(.2, .8, .3, 1);

/// Value of a keyframe track at progress [p] (0..1). Like CSS, [curve] eases
/// each segment between two keyframes separately.
double keyframes(double p, List<(double, double)> keys, [Curve curve = Curves.linear]) {
  if (p <= keys.first.$1) return keys.first.$2;
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i], b = keys[i + 1];
    if (p <= b.$1) {
      final k = curve.transform(((p - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0));
      return a.$2 + (b.$2 - a.$2) * k;
    }
  }
  return keys.last.$2;
}

/// True while the parent turned on "Reduce motion".
final reduceMotionProvider = Provider<bool>((ref) => ref.watch(familyProvider.select((f) => f.settings.reduceMotion)));

typedef MotionBuilder = Widget Function(BuildContext context, double t, Widget child);

/// Runs [builder] from t = 0 to 1 over [duration], after [delay]. Before the
/// delay the widget shows t = 0 (CSS `animation-fill-mode: both`).
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.duration, required this.builder, required this.child, this.delay = Duration.zero});

  final Duration duration, delay;
  final MotionBuilder builder;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, child: widget.child, builder: (context, child) => widget.builder(context, _c.value, child!));
}

Duration _ms(num s) => Duration(milliseconds: (s * 1000).round());

/// popIn: scale 0 -> 1.1 (70 %) -> 1.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = 0, this.seconds = .4, this.alignment = Alignment.center});
  final Widget child;
  final double delay, seconds; // seconds
  final Alignment alignment;

  static double scaleAt(double p) => p < .7 ? 1.1 * springOut.transform(p / .7) : 1.1 - .1 * springOut.transform((p - .7) / .3);

  @override
  Widget build(BuildContext context) => Entrance(
    delay: _ms(delay),
    duration: _ms(seconds),
    child: child,
    builder: (context, t, child) => t >= 1 ? child : Transform.scale(scale: scaleAt(t), alignment: alignment, child: child),
  );
}

/// bubbleIn: scale 0 + 10 px low + clear -> 1.08 (70 %) -> 1, opaque.
class BubbleIn extends StatelessWidget {
  const BubbleIn({super.key, required this.child, this.delay = 0, this.seconds = .3, this.alignment = Alignment.center});
  final Widget child;
  final double delay, seconds;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Entrance(
    delay: _ms(delay),
    duration: _ms(seconds),
    child: child,
    builder: (context, t, child) {
      if (t >= 1) return child;
      final s = keyframes(t, const [(0, 0), (.7, 1.08), (1, 1)], springOut);
      final y = keyframes(t, const [(0, 10), (.7, 0)], springOut);
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, y),
          child: Transform.scale(scale: s, alignment: alignment, child: child),
        ),
      );
    },
  );
}

/// scrIn: fades in while rising 24 px (ease-out).
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.child, this.delay = 0, this.seconds = .3, this.distance = 24});
  final Widget child;
  final double delay, seconds, distance;

  @override
  Widget build(BuildContext context) => Entrance(
    delay: _ms(delay),
    duration: _ms(seconds),
    child: child,
    builder: (context, t, child) {
      if (t >= 1) return child;
      final k = Curves.easeOut.transform(t);
      return Opacity(
        opacity: k,
        child: Transform.translate(offset: Offset(0, distance * (1 - k)), child: child),
      );
    },
  );
}

/// fadeIn (ease-out unless [curve] says otherwise).
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.delay = 0, this.seconds = .3, this.curve = Curves.easeOut});
  final Widget child;
  final double delay, seconds;
  final Curve curve;

  @override
  Widget build(BuildContext context) => Entrance(
    delay: _ms(delay),
    duration: _ms(seconds),
    child: child,
    builder: (context, t, child) => t >= 1 ? child : Opacity(opacity: curve.transform(t), child: child),
  );
}

/// bigPop: scale .2 -> 1.12 (60 %) -> 1 while fading in.
class BigPop extends StatelessWidget {
  const BigPop({super.key, required this.child, this.delay = 0, this.seconds = .6});
  final Widget child;
  final double delay, seconds;

  @override
  Widget build(BuildContext context) => Entrance(
    delay: _ms(delay),
    duration: _ms(seconds),
    child: child,
    builder: (context, t, child) {
      if (t >= 1) return child;
      final s = keyframes(t, const [(0, .2), (.6, 1.12), (1, 1)], springOut);
      return Opacity(
        opacity: (t / .6).clamp(0.0, 1.0),
        child: Transform.scale(scale: s, child: child),
      );
    },
  );
}

/// dropIn: falls 320 px, squashes on landing, small bounce.
class DropIn extends StatelessWidget {
  const DropIn({super.key, required this.child, this.delay = 0, this.seconds = .6});
  final Widget child;
  final double delay, seconds;

  @override
  Widget build(BuildContext context) => Entrance(
    delay: _ms(delay),
    duration: _ms(seconds),
    child: child,
    builder: (context, t, child) {
      if (t >= 1) return child;
      final y = keyframes(t, const [(0, -320), (.6, 0), (.8, -10), (1, 0)], dropEase);
      final sy = keyframes(t, const [(0, 1), (.6, .86), (.8, 1), (1, 1)], dropEase);
      return Transform.translate(
        offset: Offset(0, y),
        child: Transform(alignment: Alignment.bottomCenter, transform: Matrix4.diagonal3Values(1, sy, 1), child: child),
      );
    },
  );
}

/// stickIn: a sticker slapped onto the page (scale 2.6, tilted, fading in).
class StickIn extends StatelessWidget {
  const StickIn({super.key, required this.child, this.delay = 0, this.seconds = .8});
  final Widget child;
  final double delay, seconds;

  @override
  Widget build(BuildContext context) => Entrance(
    delay: _ms(delay),
    duration: _ms(seconds),
    child: child,
    builder: (context, t, child) {
      if (t >= 1) return child;
      final s = keyframes(t, const [(0, 2.6), (.8, .92), (1, 1)], settleEase);
      final r = keyframes(t, const [(0, -24), (.8, 4), (1, 0)], settleEase);
      return Opacity(
        opacity: (t / .45).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: r * math.pi / 180,
          child: Transform.scale(scale: s, child: child),
        ),
      );
    },
  );
}

/// Repeats [builder] with t going 0 -> 1 every [seconds]; [phase] is the
/// CSS negative delay (seconds already played). Frozen at [restT] while
/// "Reduce motion" is on, or after [iterations] runs.
class Loop extends ConsumerStatefulWidget {
  const Loop({super.key, required this.seconds, required this.builder, required this.child, this.phase = 0, this.delay = 0, this.restT = 0, this.iterations});

  final double seconds, phase, delay, restT;
  final int? iterations;
  final MotionBuilder builder;
  final Widget child;

  @override
  ConsumerState<Loop> createState() => _LoopState();
}

class _LoopState extends ConsumerState<Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _ms(widget.seconds));
  Timer? _wait;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _wait = Timer(_ms(widget.delay), () {
      if (!mounted) return;
      _started = true;
      _run();
    });
  }

  void _run() {
    if (!_started || ref.read(reduceMotionProvider)) return;
    final start = (widget.phase / widget.seconds) % 1.0;
    final n = widget.iterations;
    if (n == null) {
      _c.repeat(min: 0, max: 1, period: _ms(widget.seconds));
      _c.value = start;
    } else {
      var runs = 0;
      void once() {
        if (!mounted || runs++ >= n) return;
        _c.forward(from: 0).whenComplete(once);
      }

      once();
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(reduceMotionProvider, (_, reduce) {
      if (reduce) {
        _c.stop();
      } else {
        _run();
      }
    });
    if (ref.watch(reduceMotionProvider)) return widget.builder(context, widget.restT, widget.child);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => widget.builder(context, _started ? _c.value : widget.restT, child!),
    );
  }
}

/// floatY: bobs 14 px up and tilts -2° .. 2°.
class FloatY extends StatelessWidget {
  const FloatY({super.key, required this.child, this.seconds = 6, this.phase = 0});
  final Widget child;
  final double seconds, phase;

  @override
  Widget build(BuildContext context) => Loop(
    seconds: seconds,
    phase: phase,
    child: child,
    builder: (context, t, child) {
      final y = keyframes(t, const [(0, 0), (.5, -14), (1, 0)], Curves.easeInOut);
      final r = keyframes(t, const [(0, -2), (.5, 2), (1, -2)], Curves.easeInOut);
      return Transform.translate(
        offset: Offset(0, y),
        child: Transform.rotate(angle: r * math.pi / 180, child: child),
      );
    },
  );
}

/// sway: rocks -[degrees] .. [degrees] around [alignment].
class Sway extends StatelessWidget {
  const Sway({super.key, required this.child, this.seconds = 4, this.degrees = 4, this.phase = 0, this.alignment = Alignment.center});
  final Widget child;
  final double seconds, degrees, phase;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Loop(
    seconds: seconds,
    phase: phase,
    child: child,
    builder: (context, t, child) => Transform.rotate(
      alignment: alignment,
      angle: keyframes(t, [(0, -degrees), (.5, degrees), (1, -degrees)], Curves.easeInOut) * math.pi / 180,
      child: child,
    ),
  );
}

/// drift: slides 16 px right and back.
class Drift extends StatelessWidget {
  const Drift({super.key, required this.child, this.seconds = 8, this.distance = 16});
  final Widget child;
  final double seconds, distance;

  @override
  Widget build(BuildContext context) => Loop(
    seconds: seconds,
    child: child,
    builder: (context, t, child) => Transform.translate(offset: Offset(keyframes(t, [(0, 0), (.5, distance), (1, 0)], Curves.easeInOut), 0), child: child),
  );
}

/// twinkle: opacity .25 -> 1, scale .8 -> 1.15.
class Twinkle extends StatelessWidget {
  const Twinkle({super.key, required this.child, this.seconds = 3, this.delay = 0});
  final Widget child;
  final double seconds, delay;

  @override
  Widget build(BuildContext context) => Loop(
    seconds: seconds,
    delay: delay,
    restT: .5,
    child: child,
    builder: (context, t, child) => Opacity(
      opacity: keyframes(t, const [(0, .25), (.5, 1), (1, .25)], Curves.easeInOut),
      child: Transform.scale(scale: keyframes(t, const [(0, .8), (.5, 1.15), (1, .8)], Curves.easeInOut), child: child),
    ),
  );
}

/// spin: one turn every [seconds] (loading spinners).
class Spin extends StatelessWidget {
  const Spin({super.key, required this.child, this.seconds = .8});
  final Widget child;
  final double seconds;

  @override
  Widget build(BuildContext context) => Loop(
    seconds: seconds,
    child: child,
    builder: (context, t, child) => Transform.rotate(angle: 2 * math.pi * t, child: child),
  );
}
