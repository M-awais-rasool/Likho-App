import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/game_bits.dart';
import 'pick_round_view.dart';
import 'pick_shapes.dart';

/// "pop" rounds: bubbles float up from the bottom, one every [gap] seconds,
/// each saying the target or another letter ([popLabel]). Pop the targets:
/// a popped one bursts, a wrong one turns coral and wobbles away. Missed
/// bubbles just float off (no mistake). After a mistake the next target
/// gets the hint ring. When enough are popped no new bubbles come.
class PopRoundView extends StatefulWidget {
  const PopRoundView({super.key, required this.state, required this.round, required this.onPop, required this.time});
  final SessionState state;
  final PopRound round;
  final ValueChanged<int> onPop;
  final ValueNotifier<double> time;

  /// Seconds between bubbles, and for one to cross the field.
  static const gap = .95, rise = 6.4;

  @override
  State<PopRoundView> createState() => _PopRoundViewState();
}

class _PopRoundViewState extends State<PopRoundView> {
  late final double _start = widget.time.value + .35;
  final _poppedAt = <int, double>{};
  double? _doneAt;

  int get _level => widget.state.level.number;

  String _label(int i) => popLabel(widget.round, level: _level, round: widget.state.round, index: i);

  /// Lane (0..4) of bubble [i]: never the lane of the one before it.
  static int _lane(int i) {
    const lanes = [1, 3, 0, 2, 4, 1, 4, 2, 0, 3];
    return lanes[i % lanes.length];
  }

  void _pop(int i) {
    final s = widget.state;
    if (s.correct || s.found.contains(i) || s.wrongOptions.contains(i)) return;
    _poppedAt[i] = widget.time.value;
    widget.onPop(i);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (s.correct) _doneAt ??= widget.time.value;
    return SoftField(
      correct: s.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
        child: Column(
          children: [
            FoundCounter(found: s.found.length, of: widget.round.count),
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, box) => ValueListenableBuilder<double>(
                    valueListenable: widget.time,
                    builder: (context, now, _) => Stack(clipBehavior: Clip.none, children: _bubbles(box.biggest, now)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _bubbles(Size field, double now) {
    final s = widget.state;
    const size = 80.0;
    final t = now - _start;
    final last = (((_doneAt ?? now) - _start) / PopRoundView.gap).floor();
    final first = math.max(0, ((t - PopRoundView.rise) / PopRoundView.gap).floor());
    // after a mistake: the lowest target still on its way up
    int? hint;
    if (s.hint) {
      for (var i = last; i >= first; i--) {
        final age = t - i * PopRoundView.gap;
        if (age > 0 && age < PopRoundView.rise * .8 && !s.found.contains(i) && _label(i) == widget.round.target) hint = i;
      }
    }
    final laneW = (field.width - size) / 4;
    return [
      for (var i = first; i <= last; i++)
        if (t - i * PopRoundView.gap > 0) ?_bubble(i, t - i * PopRoundView.gap, laneW, field, size, now, hint == i),
    ];
  }

  Widget? _bubble(int i, double age, double laneW, Size field, double size, double now, bool hint) {
    final s = widget.state;
    final popped = s.found.contains(i);
    final wrong = s.wrongOptions.contains(i);
    final since = _poppedAt[i] == null ? null : now - _poppedAt[i]!;
    if (popped && (since == null || since > .3)) return null;
    if (wrong && since != null && since > 1.1) return null;
    final p = age / PopRoundView.rise;
    if (p > 1) return null;
    // from below the field to above it, swaying left and right
    final y = field.height - (field.height + size * 1.3) * p;
    final x = laneW * _lane(i) + math.sin(age * 1.7 + i) * 10;
    var scale = 1.0, opacity = 1.0, angle = 0.0;
    if (popped && since != null) {
      scale = 1 + since * 2.2;
      opacity = (1 - since / .3).clamp(0.0, 1.0);
    } else if (wrong && since != null) {
      angle = math.sin(since * 26) * .18 * (1 - since / 1.1);
      opacity = (1.1 - since).clamp(0.0, 1.0);
    }
    final label = _label(i);
    Widget body = PickItemBody(
      shape: 'bubble',
      color: LikhoColors.primary,
      option: PickOption(id: '$i', label: label),
      label: label,
    );
    if (wrong) body = ColorFiltered(colorFilter: ColorFilter.mode(LikhoColors.hint.withValues(alpha: .5), BlendMode.srcATop), child: body);
    if (hint) {
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          Positioned(
            left: -6,
            top: -6,
            right: -6,
            bottom: -6,
            child: IgnorePointer(
              child: CustomPaint(painter: HintRing(spread: 10 * const Cubic(.42, 0, .58, 1).transform(1 - (2 * (now % 1.0) - 1).abs()))),
            ),
          ),
        ],
      );
    }
    return Positioned(
      key: ValueKey('${widget.round.id}-b$i'),
      left: x,
      top: y,
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: (_) => _pop(i), child: FittedBox(child: body)),
          ),
        ),
      ),
    );
  }
}
