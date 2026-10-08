import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/media.dart';
import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';

/// A picture from course content: the real image when there is one (from
/// the server's media folder by key, kept on the phone, see [MediaStore];
/// or by URL), otherwise the prototype's placeholder — a striped card with
/// the picture's name in small monospace text. The images have a
/// transparent background, so they sit on whatever card or shape holds
/// them. They are decoded at the size they are shown (less memory, faster).
class Illustration extends ConsumerWidget {
  const Illustration({
    super.key,
    required this.picture,
    required this.width,
    required this.height,
    this.radius = 18,
    this.fontSize = 10,
    this.stripe = 6,
    this.padding = 6,
  });

  final Picture picture;
  final double width, height, radius, fontSize, stripe, padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaProvider);
    final path = MediaStore.picturePath(picture.key);
    final cache = (math.max(width, height) * MediaQuery.devicePixelRatioOf(context)).round();
    final Widget child;
    if (picture.url != null) {
      child = Image.network(picture.url!, fit: BoxFit.contain, filterQuality: FilterQuality.high, errorBuilder: (_, _, _) => _placeholder());
    } else if (media.hashOf(path) == null) {
      child = _placeholder();
    } else if (kIsWeb) {
      child = Image.network(media.url(path), fit: BoxFit.contain, filterQuality: FilterQuality.high, errorBuilder: (_, _, _) => _placeholder());
    } else if (media.keptFile(path) case final kept?) {
      child = _file(kept, cache);
    } else {
      // first time: download it (the levels ahead are usually fetched already)
      child = FutureBuilder<String?>(
        future: media.local(path),
        builder: (context, snap) => switch (snap) {
          AsyncSnapshot(:final data?) => _file(data, cache, fadeIn: true),
          AsyncSnapshot(connectionState: ConnectionState.done) => _placeholder(),
          _ => const SizedBox.shrink(),
        },
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    );
  }

  Widget _file(String file, int cacheSize, {bool fadeIn = false}) {
    final image = Image.file(File(file), fit: BoxFit.contain, filterQuality: FilterQuality.high, cacheWidth: cacheSize, semanticLabel: picture.label,
        errorBuilder: (_, _, _) => _placeholder());
    return fadeIn
        ? TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 200), builder: (_, t, c) => Opacity(opacity: t, child: c), child: image)
        : image;
  }

  Widget _placeholder() => CustomPaint(
    painter: StripePainter(stripe: stripe),
    child: Padding(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: Text(
          picture.label,
          textAlign: TextAlign.center,
          style: LikhoFonts.placeholder(size: fontSize),
        ),
      ),
    ),
  );
}

/// repeating-linear-gradient(135deg, ink 7% 0 [stripe], transparent [stripe] [2*stripe]) over warm paper.
class StripePainter extends CustomPainter {
  const StripePainter({this.stripe = 6, this.paper = GameColors.paperWarm});
  final double stripe;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = paper);
    final d = 2 * stripe / math.sqrt2;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [GameColors.ink07, GameColors.ink07, GameColors.ink00, GameColors.ink00],
          stops: const [0, .5, .5, 1],
          tileMode: TileMode.repeated,
        ).createShader(Rect.fromPoints(Offset.zero, Offset(d, d))),
    );
  }

  @override
  bool shouldRepaint(StripePainter old) => old.stripe != stripe || old.paper != paper;
}
