import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/family.dart';
import '../../feedback/pencil_lines.dart';
import '../../mascot/mascot.dart';
import '../../data/app_controls.dart';

/// Pencil in a box of the prototype's size ([width] x [height], e.g. 170 x
/// 240), like the prototype's `<Mascot color expr wear>` tag: change [state],
/// [color] or [accessory] and the figure follows. The figure is [height] tall
/// and may paint outside the box (raised arms, hats, "zzz").
///
/// [color] null = the active child's colour. [accessory] null with
/// [childAccessory] = what the active child wears.
///
/// [say] (one of [PencilLines]) is spoken [sayAt] after the figure appears,
/// with lip-sync; then the figure goes back to [state]. A new [state] while
/// speaking stops the line (a tap answers it). [onSaid] runs once when the
/// line is over, stopped, or at once when Pencil's voice is off.
class PencilFigure extends ConsumerStatefulWidget {
  const PencilFigure({
    super.key,
    required this.width,
    required this.height,
    this.state = MascotState.idle,
    this.color,
    this.accessory,
    this.childAccessory = true,
    this.replay = 0,
    this.repeat = false,
    this.lookDown = false,
    this.still,
    this.holdEnd = false,
    this.say,
    this.sayAt = Duration.zero,
    this.onSaid,
  });

  final double width, height;
  final MascotState state;
  final Color? color;
  final String? accessory;
  final bool childAccessory;

  /// Change to play a one-shot [state] again.
  final int replay;

  /// Play a one-shot [state] again each time it ends (dance on the certificate).
  final bool repeat;

  /// Eyes look down at what is below (the name field on onboarding).
  final bool lookDown;

  /// Hold one frame of [state] at this many seconds instead of animating.
  final double? still;

  /// A one-shot [state] stays on its last frame instead of returning to
  /// idle (the prototype's "happy": jump, then keep cheering).
  final bool holdEnd;

  final String? say;
  final Duration sayAt;
  final VoidCallback? onSaid;

  @override
  ConsumerState<PencilFigure> createState() => _PencilFigureState();
}

class _PencilFigureState extends ConsumerState<PencilFigure> {
  final MascotController _c = MascotController();
  Timer? _hold, _sayTimer;
  bool _said = false, _spoke = false;

  @override
  void initState() {
    super.initState();
    _c.stateListenable.addListener(_onState);
    _c.speakingListenable.addListener(_onSpeaking);
    _start();
    if (widget.lookDown) WidgetsBinding.instance.addPostFrameCallback((_) => _look());
    final line = widget.say;
    if (line == null) return;
    if (!ref.read(voiceOnProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _done());
      return;
    }
    _sayTimer = Timer(widget.sayAt, () => _speak(line));
  }

  Future<void> _speak(String line) async {
    if (!mounted || _said) return;
    _hold?.cancel(); // a held last frame would stop the line
    await _c.say(line); // returns when done, or at once if it cannot play
    _done();
  }

  void _onSpeaking() {
    if (_c.speakingListenable.value) {
      _spoke = true;
    } else if (_spoke) {
      _done(); // over, or stopped by a new state
    }
  }

  /// The line is over: back to [PencilFigure.state].
  void _done() {
    if (_said || !mounted) return;
    _said = true;
    _sayTimer?.cancel();
    if (_spoke) _start();
    widget.onSaid?.call();
  }

  void _start() {
    _hold?.cancel();
    final still = widget.still;
    final s = widget.state;
    if (still != null) {
      _c.showFrame(s, still);
      return;
    }
    _c.play(s);
    if (widget.holdEnd && !s.loop) {
      // last frame before the one-shot eases back into idle
      final end = s.duration - .25;
      _hold = Timer(Duration(milliseconds: (end * 1000).round()), () {
        if (mounted && _c.state == s) _c.showFrame(s, end);
      });
    }
  }

  void _onState() {
    if (widget.repeat && !widget.state.loop && _c.state == MascotState.idle && mounted) _c.play(widget.state);
  }

  void _look() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    _c.lookAt(box.localToGlobal(box.size.center(Offset.zero)) + const Offset(0, 420));
  }

  @override
  void didUpdateWidget(PencilFigure old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state || old.replay != widget.replay || old.still != widget.still || old.holdEnd != widget.holdEnd) {
      _start();
      _done(); // a line not started yet is not said over the new state
    }
    if (old.lookDown != widget.lookDown) {
      if (widget.lookDown) {
        _look();
      } else {
        _c.lookReset();
      }
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _sayTimer?.cancel();
    _c.stateListenable.removeListener(_onState);
    _c.speakingListenable.removeListener(_onSpeaking);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final color = widget.color ?? family.active.color;
    if (_c.swatch.key.toARGB32() != color.toARGB32()) _c.setBodyColor(color);
    final acc = widget.accessory ?? (widget.childAccessory ? ref.watch(appControlsProvider).accessoryFor(family.record.wearing) : null);
    if (_c.accessory != acc) {
      if (acc == null) {
        _c.removeAccessory();
      } else {
        _c.wear(acc);
      }
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: PencilMascot(controller: _c, size: widget.height),
      ),
    );
  }
}
