import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/game_buttons.dart';
import 'garden_art.dart';

class GardenPickRound extends ConsumerWidget {
  const GardenPickRound({super.key, required this.state, required this.round, required this.onPick, required this.time});
  final SessionState state;
  final PickRound round;
  final ValueChanged<int> onPick;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pictures = round.options.any((o) => o.picture != null);
    final reduce = ref.watch(reduceMotionProvider) || MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final cols = pictures ? 3 : 2;
        final rows = (round.options.length / cols).ceil();
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        final h = (box.maxHeight - (rows - 1) * 10) / rows;
        final size = math.min(w, h).clamp(48.0, pictures ? 150.0 : 155.0);
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < round.options.length; i++)
                SizedBox(
                  width: w,
                  height: pictures ? math.min(h, size + 36) : h,
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: round.options[i].label,
                      child: ValueListenableBuilder<double>(
                        valueListenable: time,
                        builder: (context, t, _) {
                          final selected = state.correct && state.picked == i;
                          final hint = state.hint && round.options[i].label == round.answer;
                          return Transform.translate(
                            offset: Offset(0, reduce || pictures ? 0 : math.sin(t * 1.6 + i * 1.3) * 3),
                            child: AnimatedScale(
                              scale: selected && !reduce ? 1.09 : 1,
                              duration: Duration(milliseconds: reduce ? 0 : 350),
                              curve: Curves.easeOutBack,
                              child: GestureDetector(
                                key: ValueKey('${round.id}-$i'),
                                behavior: HitTestBehavior.opaque,
                                onTap: state.correct ? null : () => onPick(i),
                                child: Container(
                                  width: pictures ? w : size + 8,
                                  height: pictures ? size + 32 : size,
                                  decoration: pictures
                                      ? BoxDecoration(
                                          color: selected ? GardenStyle.pale : Colors.white,
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(color: selected || hint ? GardenStyle.green : GardenStyle.line, width: hint ? 3 : 2),
                                          boxShadow: const [BoxShadow(color: GardenStyle.line, offset: Offset(0, 4))],
                                        )
                                      : null,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (pictures)
                                        Padding(padding: const EdgeInsets.all(9), child: GardenProp(round.options[i].picture!.key, word: true))
                                      else ...[
                                        const Positioned.fill(child: GardenProp('apple')),
                                        Padding(
                                          padding: EdgeInsets.only(top: size * .15),
                                          child: Text(
                                            round.options[i].label,
                                            style: LikhoFonts.letter(size: size * .49, color: Colors.white).copyWith(
                                              shadows: const [Shadow(color: Color(0x777C2A24), offset: Offset(0, 3))],
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (hint && !pictures)
                                        Positioned(
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(color: GardenStyle.pale, shape: BoxShape.circle),
                                            child: const Icon(Symbols.touch_app_rounded, size: 24, color: GardenStyle.green),
                                          ),
                                        ),
                                      if (selected)
                                        const Positioned(
                                          right: 3,
                                          top: 3,
                                          child: Icon(Symbols.check_circle_rounded, fill: 1, color: GardenStyle.green, size: 28),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class GardenFixRound extends ConsumerWidget {
  const GardenFixRound({super.key, required this.state, required this.round, required this.onTap});
  final SessionState state;
  final FixRound round;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = ref.watch(reduceMotionProvider) || MediaQuery.disableAnimationsOf(context);
    final hint = state.hint
        ? List.generate(round.items.length, (i) => i).where((i) => round.items[i].wrong != null && !state.found.contains(i)).firstOrNull
        : null;
    return LayoutBuilder(
      builder: (context, box) {
        const cols = 3;
        final rows = (round.items.length / cols).ceil();
        final width = (box.maxWidth - 24) / cols;
        final height = math.min(130.0, (box.maxHeight - 14 * (rows - 1)) / rows);
        return Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < round.items.length; i++)
                SizedBox(
                  width: width,
                  height: height,
                  child: Semantics(
                    button: true,
                    label: '${round.items[i].text} garden sign ${i + 1}',
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 0,
                          width: 9,
                          height: height * .65,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(color: Color(0xFFB58A51), borderRadius: BorderRadius.all(Radius.circular(4))),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: height * .78,
                          child: PushButton(
                            key: ValueKey('${round.id}-$i'),
                            onTap: state.correct ? null : () => onTap(i),
                            color: state.found.contains(i) ? GardenStyle.pale : const Color(0xFFF2DCAB),
                            edgeColor: const Color(0xFFC4A06B),
                            edge: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(color: hint == i ? GardenStyle.green : const Color(0xFFD1AF79), width: hint == i ? 3 : 2),
                            ),
                            child: AnimatedRotation(
                              turns: round.items[i].wrong == FixWrong.upside && !state.found.contains(i) ? .5 : 0,
                              duration: Duration(milliseconds: reduce ? 0 : 450),
                              curve: Curves.easeOutBack,
                              child: Text(
                                round.items[i].text,
                                style: LikhoFonts.letter(size: math.min(width * .6, height * .51), color: GardenStyle.ink),
                              ),
                            ),
                          ),
                        ),
                        if (state.found.contains(i))
                          const Positioned(right: 0, top: 0, child: Icon(Symbols.check_circle_rounded, fill: 1, color: GardenStyle.green, size: 23)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class GardenConnectRound extends ConsumerWidget {
  const GardenConnectRound({super.key, required this.state, required this.round, required this.onTap});
  final SessionState state;
  final ConnectRound round;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = ref.watch(reduceMotionProvider) || MediaQuery.disableAnimationsOf(context);
    final done = state.found.length == round.labels.length;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(370.0, math.min(box.maxWidth, box.maxHeight));
        const dot = 38.0;
        final points = [for (final p in round.points) Offset(dot / 2 + p.dx * (side - dot), dot / 2 + p.dy * (side - dot))];
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _AppleOutline(points, state.found.length))),
                Center(
                  child: AnimatedScale(
                    scale: done ? 1 : .4,
                    duration: Duration(milliseconds: reduce ? 0 : 700),
                    curve: Curves.elasticOut,
                    child: AnimatedOpacity(
                      opacity: done ? 1 : 0,
                      duration: Duration(milliseconds: reduce ? 0 : 300),
                      child: GardenProp('apple', size: side * .6),
                    ),
                  ),
                ),
                for (var i = 0; i < round.labels.length; i++)
                  Positioned(
                    left: points[i].dx - dot / 2,
                    top: points[i].dy - dot / 2,
                    width: dot,
                    height: dot,
                    child: Semantics(
                      button: true,
                      label: round.labels[i],
                      child: GestureDetector(
                        key: ValueKey('${round.id}-$i'),
                        behavior: HitTestBehavior.opaque,
                        onTap: done ? null : () => onTap(i),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: reduce ? 0 : 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < state.found.length ? GardenStyle.green : (i == state.found.length ? const Color(0xFFFFE4A0) : Colors.white),
                            border: Border.all(color: i == state.found.length ? const Color(0xFFD0A44B) : GardenStyle.line, width: 2),
                          ),
                          child: Text(round.labels[i], style: LikhoFonts.letter(size: 20, color: i < state.found.length ? Colors.white : GardenStyle.ink)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppleOutline extends CustomPainter {
  const _AppleOutline(this.points, this.joined);
  final List<Offset> points;
  final int joined;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = GardenStyle.pale);
    final line = Paint()
      ..color = GardenStyle.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < joined; i++) {
      canvas.drawLine(points[i - 1], points[i], line);
    }
    if (joined == points.length) {
      canvas.drawLine(points.last, points.first, line);
    }
  }

  @override
  bool shouldRepaint(_AppleOutline old) => old.joined != joined || old.points != points;
}
