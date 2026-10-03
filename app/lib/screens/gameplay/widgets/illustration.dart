import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';

/// Bundled illustrations (`assets/illustrations/<key>.png`, built by
/// tools/illustrations/build_illustrations.py at the repository root), read once from the asset
/// manifest.
final illustrationAssetsProvider = FutureProvider<Set<String>>((ref) async {
  try {
    final m = await AssetManifest.loadFromAssetBundle(rootBundle);
    return m.listAssets().where((a) => a.startsWith('assets/illustrations/')).toSet();
  } catch (_) {
    return const {};
  }
});

/// A picture from course content: the real image when it exists (bundled
/// by key, or by URL), otherwise the prototype's placeholder — a striped
/// card with the picture's name in small monospace text. The images have a
/// transparent background, so they sit on whatever card or shape holds them.
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
    final assets = ref.watch(illustrationAssetsProvider).value ?? const {};
    final asset = 'assets/illustrations/${picture.key}.png';
    final Widget child;
    if (assets.contains(asset)) {
      child = Image.asset(asset, fit: BoxFit.contain, filterQuality: FilterQuality.high, semanticLabel: picture.label);
    } else if (picture.url != null) {
      child = Image.network(picture.url!, fit: BoxFit.contain, filterQuality: FilterQuality.high, errorBuilder: (_, _, _) => _placeholder());
    } else {
      child = _placeholder();
    }
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    );
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
