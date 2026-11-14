import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../rounds/write_round_view.dart';
import 'garden_art.dart';

class AppleGardenFrame extends StatelessWidget {
  const AppleGardenFrame({
    super.key,
    required this.state,
    required this.time,
    required this.mascot,
    required this.speech,
    required this.onExit,
    required this.onReplay,
    required this.child,
    this.pad,
    this.onErase,
    this.onDone,
    this.letterBoxes,
  });
  final SessionState state;
  final ValueNotifier<double> time;
  final Widget mascot, child;
  final String? speech;
  final VoidCallback onExit, onReplay;
  final WritePadController? pad;
  final VoidCallback? onErase, onDone;
  final Widget? letterBoxes;

  static const missions = [
    'Find the letter',
    'Grow an apple',
    'Listen & choose',
    'Follow the dots',
    'Mend the signs',
    'The missing letter',
    'Remember A',
    'One last apple',
  ];

  @override
  Widget build(BuildContext context) {
    final earned = state.round + (state.correct ? 1 : 0);
    final p = pad;
    return GardenBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 680;
                final sceneHeight = compact ? 88.0 : (box.maxHeight * .21).clamp(120.0, 175.0);
                return Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 8, compact ? 12 : 18, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GardenIconButton(key: const ValueKey('garden-exit'), icon: Symbols.close_rounded, label: 'Leave the garden', onTap: onExit),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                children: [
                                  Text(
                                    'APPLE GARDEN',
                                    style: LikhoFonts.body(size: 11, weight: FontWeight.w900, color: GardenStyle.green).copyWith(letterSpacing: 1.7),
                                  ),
                                  Text(
                                    'My letter A',
                                    style: LikhoFonts.title(size: 25, weight: FontWeight.w800, color: GardenStyle.ink),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GardenIconButton(
                            key: const ValueKey('garden-replay'),
                            icon: Symbols.volume_up_rounded,
                            label: 'Hear the instruction again',
                            onTap: onReplay,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        label: '$earned of ${state.roundCount} garden tasks complete',
                        child: Row(
                          children: [
                            for (var i = 0; i < state.roundCount; i++)
                              Expanded(
                                child: Container(
                                  height: 7,
                                  margin: EdgeInsets.only(right: i == state.roundCount - 1 ? 0 : 5),
                                  decoration: BoxDecoration(
                                    color: i < earned ? GardenStyle.green : Colors.white.withValues(alpha: .8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: sceneHeight,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 6,
                              bottom: 0,
                              child: p == null
                                  ? GardenOrchard(time: time, earned: earned, total: state.roundCount, celebrate: state.correct)
                                  : AnimatedBuilder(
                                      animation: p,
                                      builder: (context, _) => GardenOrchard(
                                        time: time,
                                        earned: earned,
                                        total: state.roundCount,
                                        celebrate: state.correct,
                                        growth: (p.guide?.stroke ?? 0) / math.max(1, p.guides.length),
                                      ),
                                    ),
                            ),
                            Positioned(left: 0, bottom: 0, width: sceneHeight * .55, height: sceneHeight * .85, child: mascot),
                            Positioned(
                              left: sceneHeight * .47,
                              top: compact ? 8 : 16,
                              width: box.maxWidth * .36,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: GardenStyle.panel(radius: 17),
                                child: Text(
                                  state.correct ? 'An apple for you!' : 'Let’s fill our basket!',
                                  textAlign: TextAlign.center,
                                  style: LikhoFonts.body(size: compact ? 12 : 14, weight: FontWeight.w800, color: GardenStyle.ink),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          key: const ValueKey('garden-task-panel'),
                          decoration: GardenStyle.panel(),
                          padding: EdgeInsets.fromLTRB(compact ? 12 : 18, compact ? 12 : 16, compact ? 12 : 18, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${state.round + 1}  /  ${state.roundCount}   •   ${missions[state.round.clamp(0, missions.length - 1)].toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LikhoFonts.body(size: 10, weight: FontWeight.w900, color: GardenStyle.green).copyWith(letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.current.prompt.text,
                                maxLines: 2,
                                style: LikhoFonts.title(size: compact ? 21 : 25, weight: FontWeight.w800, color: GardenStyle.ink).copyWith(height: 1.15),
                              ),
                              if (letterBoxes != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: SizedBox(height: 43, child: letterBoxes!),
                                ),
                              const SizedBox(height: 8),
                              Expanded(child: child),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(minHeight: 46),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: state.correct ? GardenStyle.pale : const Color(0xFFF2F0DF),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    Icon(state.correct ? Symbols.check_circle_rounded : Symbols.lightbulb_rounded, color: GardenStyle.green, size: 21),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        speech ?? 'Each little task grows our garden.',
                                        maxLines: 3,
                                        style: LikhoFonts.body(size: compact ? 12 : 14, weight: FontWeight.w700, color: GardenStyle.ink, height: 1.2),
                                      ),
                                    ),
                                    if (onErase != null) ...[
                                      const SizedBox(width: 4),
                                      Semantics(
                                        button: true,
                                        label: 'Erase and try again',
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: IconButton(
                                            key: const ValueKey('garden-erase'),
                                            tooltip: 'Erase',
                                            onPressed: state.correct ? null : onErase,
                                            icon: const Icon(Symbols.ink_eraser_rounded, color: GardenStyle.muted, size: 23),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Guided letters finish themselves; free writing still needs submission.
                              if (onDone != null && (p?.guides.isEmpty ?? false)) ...[const SizedBox(height: 8), GardenAction(label: 'Done', onTap: onDone!)],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
