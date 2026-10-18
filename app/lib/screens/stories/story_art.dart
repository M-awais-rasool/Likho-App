import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// The pictures of a story episode (`assets/stories/<id>/`, cut from the
/// Gemini art by tools/stories/cut_art.py) and the pieces every story scene
/// is made of: the background fitted to the phone, people who change pose,
/// breathe and bob while they talk, and the speech bubble.
abstract final class StoryArt {
  static String bg(String episode, String place) => 'assets/stories/$episode/bg_$place.webp';
  static String pose(String episode, String who, String pose) => 'assets/stories/$episode/${who}_$pose.webp';
  static String prop(String episode, String name) => 'assets/stories/$episode/$name.webp';

  /// The backgrounds' size (9:16).
  static const bgSize = Size(1080, 1935);
}

/// Where a 9:16 background lands on the screen: it covers the screen, its
/// bottom (the ground people stand on) always shows. [at] turns a point of
/// the picture (0..1 of its width and height) into a screen point.
@immutable
class BgFrame {
  const BgFrame(this.screen);
  final Size screen;

  double get scale => math.max(screen.width / StoryArt.bgSize.width, screen.height / StoryArt.bgSize.height);
  Size get size => StoryArt.bgSize * scale;
  Offset get origin => Offset((screen.width - size.width) / 2, screen.height - size.height);

  Offset at(double fx, double fy) => origin + Offset(fx * size.width, fy * size.height);
  Rect rect(double l, double t, double r, double b) => Rect.fromPoints(at(l, t), at(r, b));

  @override
  bool operator ==(Object other) => other is BgFrame && other.screen == screen;
  @override
  int get hashCode => screen.hashCode;
}

/// A background, covering the screen with its bottom showing (see
/// [BgFrame]); a new one fades in over the old.
class StoryBackground extends StatelessWidget {
  const StoryBackground({super.key, required this.asset});
  final String asset;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 600),
    child: SizedBox.expand(
      key: ValueKey(asset),
      child: Image.asset(asset, fit: BoxFit.cover, alignment: Alignment.bottomCenter, gaplessPlayback: true, filterQuality: FilterQuality.medium),
    ),
  );
}

/// A person of the story, standing with their feet at the bottom middle of
/// the box: [pose] picks the picture (all poses share one frame, so they
/// swap without a jump). They breathe gently, bob while [talking],
/// and can face the other way ([flip]).
class StoryPerson extends StatelessWidget {
  const StoryPerson({super.key, required this.episode, required this.who, required this.pose, required this.time, this.talking = false, this.flip = false});
  final String episode, who, pose;
  final ValueNotifier<double> time;
  final bool talking, flip;

  @override
  Widget build(BuildContext context) {
    final picture = Image.asset(StoryArt.pose(episode, who, pose), fit: BoxFit.contain, alignment: Alignment.bottomCenter, gaplessPlayback: true, filterQuality: FilterQuality.medium);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // a soft shadow under the feet
          Positioned(
            bottom: -box.maxHeight * .015,
            child: Container(
              width: box.maxWidth * .62,
              height: box.maxHeight * .05,
              decoration: BoxDecoration(color: StoryColors.shadow, borderRadius: BorderRadius.all(Radius.elliptical(box.maxWidth, box.maxHeight * .05))),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: time,
            child: Transform.flip(flipX: flip, child: picture),
            builder: (context, t, child) {
              final seed = who.hashCode % 7;
              final breathe = 1 + math.sin(t * 2.2 + seed) * .012;
              final bob = talking ? -(math.sin(t * 8).abs() * box.maxHeight * .018) : 0.0;
              return Transform.translate(
                offset: Offset(0, bob),
                child: Transform.scale(scaleY: breathe, alignment: Alignment.bottomCenter, child: child),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A thing of the story (an apple, a basket) at its natural shape.
class StoryProp extends StatelessWidget {
  const StoryProp({super.key, required this.episode, required this.name, this.fit = BoxFit.contain});
  final String episode, name;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(StoryArt.prop(episode, name), fit: fit, gaplessPlayback: true, filterQuality: FilterQuality.medium);
}

/// What is being said: the speaker's name and their words, word for word,
/// in a bubble whose tail points to the speaker ([tailX]: 0..1 across the
/// bubble). While writing, a stroke step shows instead ([step]).
class StoryBubble extends StatelessWidget {
  const StoryBubble({super.key, required this.name, required this.text, this.tailX = .2, this.step});
  final String? name;
  final String text;
  final double tailX;
  final int? step;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(text),
    tween: Tween(begin: .82, end: 1),
    duration: const Duration(milliseconds: 280),
    curve: const Cubic(.34, 1.56, .64, 1),
    builder: (context, v, child) => Transform.scale(scale: v, alignment: Alignment(tailX * 2 - 1, 1), child: child),
    child: CustomPaint(
      painter: _BubbleTail(tailX),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: StoryColors.bubble,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: StoryColors.bubbleShadow, offset: Offset(0, 6), blurRadius: 14)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name != null && step == null)
              Text(name!.toUpperCase(), style: LikhoFonts.body(size: 12, weight: FontWeight.w800, color: StoryColors.name).copyWith(letterSpacing: 1.2)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step != null) ...[
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: LikhoColors.secondary, shape: BoxShape.circle),
                    child: Text('$step', style: LikhoFonts.title(size: 14, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(height: 1)),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: LikhoFonts.title(size: text.length > 48 ? 17 : 19, weight: FontWeight.w800).copyWith(height: 1.2)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _BubbleTail extends CustomPainter {
  const _BubbleTail(this.x);
  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = (size.width * x).clamp(28.0, size.width - 28);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 12, size.height - 14)
        ..lineTo(cx + 12, size.height - 14)
        ..lineTo(cx, size.height)
        ..close(),
      Paint()..color = StoryColors.bubble,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.x != x;
}

/// A picture asset, decoded, for painting parts of it (the market sign,
/// cut from its background and stretched without bending its corners).
class ArtImage extends StatefulWidget {
  const ArtImage({super.key, required this.asset, required this.builder});
  final String asset;
  final Widget Function(BuildContext context, ui.Image? image) builder;

  @override
  State<ArtImage> createState() => _ArtImageState();
}

class _ArtImageState extends State<ArtImage> {
  ui.Image? _image;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _image = info.image);
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = AssetImage(widget.asset).resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _image);
}

/// Paints [src] of [image] into the box as a 9-slice: the corners ([inset]
/// of the source) stay as drawn, the edges and middle stretch.
class NineSlicePainter extends CustomPainter {
  const NineSlicePainter({required this.image, required this.src, required this.inset});
  final ui.Image image;
  final Rect src;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final i = inset, s = src;
    final d = Offset.zero & size;
    final di = math.min(i * 2.2, math.min(size.width, size.height) / 3); // corner size on screen
    final xs = [s.left, s.left + i, s.right - i, s.right], ys = [s.top, s.top + i, s.bottom - i, s.bottom];
    final dx = [d.left, d.left + di, d.right - di, d.right], dy = [d.top, d.top + di, d.bottom - di, d.bottom];
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        canvas.drawImageRect(image, Rect.fromLTRB(xs[c], ys[r], xs[c + 1], ys[r + 1]), Rect.fromLTRB(dx[c], dy[r], dx[c + 1], dy[r + 1]), paint);
      }
    }
  }

  @override
  bool shouldRepaint(NineSlicePainter old) => old.image != image || old.src != src;
}

/// Completes with the first of several taps' answers.
class TapGate<T> {
  final _c = Completer<T>();
  bool get done => _c.isCompleted;
  Future<T> get future => _c.future;
  void open(T v) {
    if (!_c.isCompleted) _c.complete(v);
  }
}
