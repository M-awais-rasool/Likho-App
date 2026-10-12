import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../../../game/level_session.dart';
import '../widgets/game_buttons.dart';
import '../widgets/illustration.dart';
import 'pick_round_view.dart';

/// "beats" rounds (clap the beats): the word (and its picture), or the
/// sentence, over a big drum. Tap the drum once for every beat (each tap
/// puts a note on the line), then "Done". Too many taps: the small "again"
/// button starts over. When it is right, or after a wrong count, the word
/// shows split into its beats ("ap · ple") with a note over each.
class BeatsRoundView extends StatelessWidget {
  const BeatsRoundView({
    super.key,
    required this.state,
    required this.round,
    required this.onDrum,
    required this.onDone,
    required this.onAgain,
    required this.time,
  });
  final SessionState state;
  final BeatsRound round;
  final VoidCallback onDrum, onDone, onAgain;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    final split = state.correct || state.hint;
    final pic = round.picture;
    final busy = state.correct;
    return SoftField(
      correct: state.correct,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: LayoutBuilder(
          builder: (context, box) {
            final drum = math.min(box.maxWidth * .5, box.maxHeight * .36).clamp(90.0, 170.0);
            final picSide = math.min(box.maxHeight * .2, 92.0);
            return Column(
              children: [
                if (pic != null && box.maxHeight > 330) ...[
                  Illustration(picture: pic, width: picSide, height: picSide, radius: 18),
                  const SizedBox(height: 6),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: split ? _parts(box.maxWidth) : _whole(box.maxWidth),
                ),
                const SizedBox(height: 8),
                _Notes(count: state.beats, of: round.count, correct: state.correct, wrong: state.feedback == RoundFeedback.wrong),
                Expanded(
                  child: Center(
                    child: _Drum(key: ValueKey('${round.id}-drum'), size: drum, hits: state.beats, onTap: busy ? null : onDrum),
                  ),
                ),
                Row(
                  children: [
                    PushButton(
                      onTap: busy || state.beats == 0 ? null : onAgain,
                      color: LikhoColors.surface,
                      edgeColor: GameColors.ink14,
                      edge: 4,
                      width: 58,
                      height: 58,
                      shape: const CircleBorder(),
                      child: Icon(Symbols.replay_rounded, size: 28, weight: 700, color: state.beats == 0 ? GameColors.ink35 : LikhoColors.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: state.beats == 0 && !busy ? .45 : 1,
                        child: PushButton(
                          onTap: busy || state.beats == 0 ? null : onDone,
                          color: LikhoColors.success,
                          edgeColor: GameColors.successDeep,
                          edge: 6,
                          height: 58,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          innerHighlight: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.check_circle_rounded, size: 28, fill: 1, color: LikhoColors.surface),
                              const SizedBox(width: 8),
                              Text('Done', style: LikhoFonts.title(size: 24, weight: FontWeight.w800, color: LikhoColors.surface)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The word or sentence as it is written.
  Widget _whole(double width) => SizedBox(
    key: const ValueKey('whole'),
    width: width,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(round.text, style: LikhoFonts.letter(size: round.words ? 34 : 48).copyWith(height: 1.15)),
    ),
  );

  /// Split into its beats, a note over each.
  Widget _parts(double width) => SizedBox(
    key: const ValueKey('parts'),
    width: width,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < round.parts.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(round.words ? ' ' : '·', style: LikhoFonts.letter(size: 40, color: GameColors.ink35).copyWith(height: 1.15)),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.music_note_rounded, size: 22, fill: 1, color: state.correct ? LikhoColors.success : LikhoColors.hint),
                Text(round.parts[i], style: LikhoFonts.letter(size: round.words ? 34 : 48, color: state.correct ? GameColors.successDeep : LikhoColors.ink).copyWith(height: 1.1)),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

/// A note per drum tap so far.
class _Notes extends StatelessWidget {
  const _Notes({required this.count, required this.of, required this.correct, required this.wrong});
  final int count, of;
  final bool correct, wrong;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: Center(
      child: count == 0
          ? Text('Tap the drum!', style: LikhoFonts.title(size: 18, weight: FontWeight.w800, color: GameColors.ink35))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count; i++)
                    TweenAnimationBuilder<double>(
                      key: ValueKey(i),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 280),
                      curve: const Cubic(.34, 1.56, .64, 1),
                      builder: (context, k, child) => Transform.scale(scale: k, child: child),
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: correct ? LikhoColors.success : (wrong ? LikhoColors.hint : LikhoColors.secondary),
                        ),
                        child: const Icon(Symbols.music_note_rounded, size: 18, fill: 1, color: LikhoColors.surface),
                      ),
                    ),
                ],
              ),
            ),
    ),
  );
}

/// The big drum: bounces and ripples on every tap.
class _Drum extends StatefulWidget {
  const _Drum({super.key, required this.size, required this.hits, required this.onTap});
  final double size;
  final int hits;
  final VoidCallback? onTap;

  @override
  State<_Drum> createState() => _DrumState();
}

class _DrumState extends State<_Drum> with SingleTickerProviderStateMixin {
  late final AnimationController _hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void dispose() {
    _hit.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.onTap == null) return;
    _hit.forward(from: 0);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(),
      child: SizedBox(
        width: s * 1.3,
        height: s * 1.1,
        child: AnimatedBuilder(
          animation: _hit,
          builder: (context, _) {
            final v = _hit.value;
            final squash = _hit.isAnimating ? math.sin(v * math.pi) : 0.0;
            return CustomPaint(painter: _DrumPainter(squash: squash, ripple: _hit.isAnimating ? v : 0));
          },
        ),
      ),
    );
  }
}

class _DrumPainter extends CustomPainter {
  const _DrumPainter({required this.squash, required this.ripple});
  final double squash, ripple;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 1.3;
    final cx = size.width / 2;
    final top = size.height * .2 + 6 * squash;
    final rx = w / 2, ry = w * .17;
    final h = w * .55 - 6 * squash;
    final body = Path()
      ..moveTo(cx - rx, top)
      ..lineTo(cx - rx * .94, top + h)
      ..arcToPoint(Offset(cx + rx * .94, top + h), radius: Radius.elliptical(rx * .94, ry), clockwise: false)
      ..lineTo(cx + rx, top)
      ..close();
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, top + h + 8), width: w * 1.02, height: ry * 1.4), Paint()..color = GameColors.ink10);
    canvas.drawPath(body, Paint()..color = GameColors.drumShell);
    // the zigzag cords
    final cord = Paint()
      ..color = GameColors.drumCord
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const n = 7;
    final zig = Path();
    for (var i = 0; i <= n; i++) {
      final x = cx - rx * .9 + (rx * 1.8) * i / n;
      final y = i.isEven ? top + ry * .9 : top + h - ry * .2;
      i == 0 ? zig.moveTo(x, y) : zig.lineTo(x, y);
    }
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(zig, cord);
    canvas.restore();
    // rims
    final rim = Paint()
      ..color = GameColors.drumRim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, top + h), width: rx * 1.88, height: ry * 2), 0, math.pi, false, rim);
    // the skin
    final skin = Rect.fromCenter(center: Offset(cx, top), width: w, height: ry * 2);
    canvas.drawOval(skin, Paint()..color = GameColors.drumSkin);
    canvas.drawOval(skin, rim);
    canvas.drawOval(skin.deflate(ry * .5), Paint()..color = GameColors.drumSkinShade);
    // a ripple from the middle
    if (ripple > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, top), width: w * (.3 + .9 * ripple), height: ry * 2 * (.3 + .9 * ripple)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = LikhoColors.primary.withValues(alpha: 1 - ripple),
      );
    }
  }

  @override
  bool shouldRepaint(_DrumPainter old) => old.squash != squash || old.ripple != ripple;
}
