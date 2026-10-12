import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/game_bits.dart';
import '../widgets/illustration.dart';
import 'pick_round_view.dart';

/// "sounds" rounds (sound buttons): the word with a dot under each of its
/// sounds. Tap the dots left to right (Pencil says each sound, the letters
/// light up; the next dot glows), then slide the arrow under the word to
/// read it: Pencil says the word and three pictures come up. Tap the word's
/// picture. A wrong picture fades; after a mistake the right one pulses.
class SoundsRoundView extends StatelessWidget {
  const SoundsRoundView({
    super.key,
    required this.state,
    required this.round,
    required this.onSound,
    required this.onBlend,
    required this.onChoice,
    required this.time,
  });
  final SessionState state;
  final SoundsRound round;
  final ValueChanged<int> onSound;
  final VoidCallback onBlend;
  final ValueChanged<int> onChoice;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final ready = state.found.length >= round.parts.length;
    return SoftField(
      correct: state.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: LayoutBuilder(
          builder: (context, box) {
            final n = round.parts.length;
            // tiles of a sound: wider for a letter pair ("sh"), all fitting the width
            final units = [for (final p in round.parts) math.max(1, p.text.length).toDouble()].fold(0.0, (a, b) => a + b);
            final unit = math.min(78.0, (box.maxWidth - 10.0 * (n - 1) - 8) / (units * .92 + .08 * n));
            return Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < n; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            _Sound(
                              key: ValueKey('${round.id}-s$i'),
                              text: round.parts[i].text,
                              width: unit * (math.max(1, round.parts[i].text.length) * .92 + .08),
                              height: unit * 1.15,
                              lit: state.found.contains(i),
                              next: !state.blended && i == state.found.length,
                              read: state.blended,
                              time: time,
                              onTap: state.correct || state.blended ? null : () => onSound(i),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      _BlendArrow(
                        key: ValueKey('${round.id}-arrow'),
                        width: math.min(box.maxWidth - 16, unit * units + 10.0 * (n - 1) + 40),
                        ready: ready && !state.blended,
                        done: state.blended,
                        time: time,
                        onBlend: onBlend,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: const Cubic(.34, 1.56, .64, 1),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(scale: Tween(begin: .8, end: 1.0).animate(a), child: child),
                    ),
                    child: state.blended ? _choices() : _readMe(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Before reading: what to do, in a word.
  Widget _readMe() => Center(
    key: const ValueKey('read'),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Symbols.touch_app_rounded, size: 26, fill: 1, color: GameColors.ink35),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            state.found.length >= round.parts.length ? 'Slide to read!' : 'Tap each sound!',
            style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: GameColors.ink40),
          ),
        ),
      ],
    ),
  );

  Widget _choices() {
    final order = tileOrder(level: state.level.number, round: state.round + 11, count: round.choices.length);
    return LayoutBuilder(
      key: const ValueKey('choices'),
      builder: (context, box) {
        const gap = 12.0;
        final n = order.length;
        final side = math.min((box.maxWidth - gap * (n - 1)) / n, box.maxHeight - 6).clamp(48.0, 130.0);
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (k, i) in order.indexed) ...[
                if (k > 0) const SizedBox(width: gap),
                _Choice(
                  key: ValueKey('${round.id}-c$i'),
                  thing: round.choices[i],
                  side: side,
                  wrong: state.wrongOptions.contains(i),
                  right: state.correct && state.picked == i,
                  hint: state.hint && !state.correct && i == round.answer,
                  time: time,
                  onTap: state.correct || state.wrongOptions.contains(i) ? null : () => onChoice(i),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One sound: its letters in a tile and the round button under them.
class _Sound extends StatefulWidget {
  const _Sound({
    super.key,
    required this.text,
    required this.width,
    required this.height,
    required this.lit,
    required this.next,
    required this.read,
    required this.time,
    required this.onTap,
  });
  final String text;
  final double width, height;
  final bool lit, next, read;
  final ValueNotifier<double> time;
  final VoidCallback? onTap;

  @override
  State<_Sound> createState() => _SoundState();
}

class _SoundState extends State<_Sound> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(_Sound old) {
    super.didUpdateWidget(old);
    if (widget.lit && !old.lit) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lit = widget.lit || widget.read;
    final color = widget.read ? LikhoColors.success : LikhoColors.ink;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.read ? GameColors.successPale : (widget.lit ? GameColors.hintBox : LikhoColors.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.read ? LikhoColors.success : (lit ? LikhoColors.primary : GameColors.ink08), width: 3, strokeAlign: BorderSide.strokeAlignInside),
        boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 4))],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(widget.text, style: LikhoFonts.letter(size: 54, color: lit ? color : GameColors.ink60).copyWith(height: 1.1)),
        ),
      ),
    );
    final dot = SizedBox.square(
      dimension: 34,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.next)
            ValueListenableBuilder<double>(
              valueListenable: widget.time,
              builder: (context, t, _) {
                final k = const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t * 1.2 % 1.0) - 1).abs());
                return Container(
                  width: 34 + 16 * k,
                  height: 34 + 16 * k,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: GameColors.glowYellowSoft.withValues(alpha: .6 * (1 - k * .5))),
                );
              },
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.read ? LikhoColors.success : (widget.lit ? LikhoColors.primary : (widget.next ? LikhoColors.surface : GameColors.ink10)),
              border: Border.all(color: widget.read ? GameColors.successDeep : (widget.lit || widget.next ? LikhoColors.primaryDeep : GameColors.ink14), width: 3),
            ),
            child: widget.lit || widget.read ? const Icon(Symbols.volume_up_rounded, size: 15, fill: 1, color: LikhoColors.surface) : null,
          ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pop,
        builder: (context, child) {
          final v = _pop.value;
          final s = _pop.isAnimating ? 1 + .14 * math.sin(v * math.pi) : 1.0;
          return Transform.scale(scale: s, child: child);
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [tile, const SizedBox(height: 10), dot]),
      ),
    );
  }
}

/// The arrow under the word: slide it (or tap it) once every sound was
/// tapped to read the word.
class _BlendArrow extends StatefulWidget {
  const _BlendArrow({super.key, required this.width, required this.ready, required this.done, required this.time, required this.onBlend});
  final double width;
  final bool ready, done;
  final ValueNotifier<double> time;
  final VoidCallback onBlend;

  @override
  State<_BlendArrow> createState() => _BlendArrowState();
}

class _BlendArrowState extends State<_BlendArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  double _drag = 0; // 0..1 along the track

  static const _knob = 44.0;

  @override
  void didUpdateWidget(_BlendArrow old) {
    super.didUpdateWidget(old);
    if (widget.done && !old.done && _drag < 1) _run.forward(from: _drag);
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  void _go() {
    if (!widget.ready) return;
    widget.onBlend();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.width - _knob;
    final on = widget.ready || widget.done;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _go,
      onHorizontalDragUpdate: widget.ready ? (d) => setState(() => _drag = (_drag + d.delta.dx / track).clamp(0.0, 1.0)) : null,
      onHorizontalDragEnd: widget.ready
          ? (_) {
              if (_drag > .55) {
                _drag = 1;
                _go();
              } else {
                setState(() => _drag = 0);
              }
            }
          : null,
      child: SizedBox(
        width: widget.width,
        height: _knob,
        child: AnimatedBuilder(
          animation: Listenable.merge([_run, widget.time]),
          builder: (context, _) {
            final at = widget.done ? (_run.isAnimating ? Curves.easeOut.transform(_run.value) : 1.0) : _drag;
            final nudge = widget.ready && _drag == 0 ? 6 * math.sin(widget.time.value * 5).abs() : 0.0;
            return Stack(
              children: [
                Positioned.fill(
                  top: 15,
                  bottom: 15,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: on ? GameColors.hintTint : GameColors.ink08, borderRadius: BorderRadius.circular(7)),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 15,
                  bottom: 15,
                  width: _knob / 2 + track * at,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: widget.done ? LikhoColors.success : LikhoColors.primary, borderRadius: BorderRadius.circular(7)),
                  ),
                ),
                Positioned(
                  left: track * at + nudge,
                  top: 0,
                  child: Container(
                    width: _knob,
                    height: _knob,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.done ? LikhoColors.success : (on ? LikhoColors.primary : GameColors.ink14),
                      boxShadow: [BoxShadow(color: widget.done ? GameColors.successDeep : (on ? LikhoColors.primaryDeep : GameColors.ink10), offset: const Offset(0, 4))],
                    ),
                    child: Icon(
                      widget.done ? Symbols.check_rounded : Symbols.arrow_forward_rounded,
                      size: 26,
                      weight: 700,
                      color: on ? LikhoColors.surface : GameColors.ink35,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A picture to choose after reading.
class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.thing, required this.side, required this.wrong, required this.right, required this.hint, required this.time, required this.onTap});
  final SortThing thing;
  final double side;
  final bool wrong, right, hint;
  final ValueNotifier<double> time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pic = thing.picture;
    Widget card = Container(
      width: side,
      height: side,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: right ? GameColors.successPale : LikhoColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: right ? LikhoColors.success : GameColors.ink08, width: 3, strokeAlign: BorderSide.strokeAlignInside),
        boxShadow: const [BoxShadow(color: GameColors.ink08, offset: Offset(0, 5))],
      ),
      child: pic != null
          ? Illustration(picture: pic, width: side - 12, height: side - 12, radius: 16)
          : Center(child: Text(thing.label, style: LikhoFonts.title(size: 22, weight: FontWeight.w800))),
    );
    if (hint) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: time,
                builder: (context, t, _) {
                  final k = const Cubic(.42, 0, .58, 1).transform(1 - (2 * (t % 1.0) - 1).abs());
                  return CustomPaint(painter: HintRing(spread: 12 * k));
                },
              ),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(duration: const Duration(milliseconds: 250), opacity: wrong ? .4 : 1, child: card),
    );
  }
}
