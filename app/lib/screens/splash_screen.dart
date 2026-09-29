import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_providers.dart';
import '../design/tokens.dart';
import '../dev/reference_overlay.dart';
import '../feedback/app_feedback.dart';
import '../mascot/mascot.dart';
import 'common/effects.dart';

/// 01 Splash, from design/prototype/Likho-Prototype.html (screen "splash", 390 x 844).
///
/// Timeline (seconds): mascot drops in and bounces 0–1.05, "Likho" is written
/// letter by letter 1.0–1.98, the yellow line draws 1.9–2.4, then [onDone]
/// at 2.5. Tapping anywhere skips. While the reference overlay is on, the
/// screen holds its last frame instead of leaving.
///
/// Sound + haptics follow the same timeline: a soft landing thump (and a
/// bump) as Pencil lands at .47 s, a pencil scribble per letter, a swish
/// with the line, and Likho's signature chime (D - A - D') with a sparkle
/// burst as the line is finished.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const Duration length = Duration(milliseconds: 2500);
  static const String reference = 'assets/reference/screens/splash.png';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: SplashScreen.length);
  final MascotController _mascot = MascotController();
  final List<Timer> _cues = [];
  bool _left = false;

  /// (seconds, what happens)
  static final List<(double, void Function(AppFeedback))> timeline = [
    (.47, (f) => f.splashLand()),
    for (final (ch, delay, _, _) in _Wordmark._letters) (delay + .04 * (ch == 'L' ? 0 : 1), (f) => f.splashLetter()),
    (1.9, (f) => f.splashSwish()),
    (2.15, (f) => f.splashChime()),
  ];

  @override
  void initState() {
    super.initState();
    _mascot.play(MascotState.wave);
    ref.read(courseProvider); // start loading the course while the splash plays
    final fb = ref.read(feedbackProvider);
    for (final (at, play) in timeline) {
      _cues.add(Timer(Duration(milliseconds: (at * 1000).round()), () => play(fb)));
    }
    _t.forward().whenComplete(() {
      if (!ref.read(referenceOverlayProvider).enabled) _leave();
    });
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    widget.onDone();
  }

  @override
  void dispose() {
    for (final c in _cues) {
      c.cancel();
    }
    _t.dispose();
    _mascot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: LikhoColors.clear),
      child: ReferenceOverlay(
        asset: SplashScreen.reference,
        child: Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _leave,
            child: CustomPaint(
              painter: const _GlowBackground(),
              child: AnimatedBuilder(
                animation: _t,
                builder: (context, _) => _content(_t.value * SplashScreen.length.inMilliseconds / 1000),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Column centred on screen, gap 10: mascot box 170 x 240, "Likho"
  /// (margin-top 6), line 190 x 22 (margin-top -8).
  Widget _content(double sec) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MascotDrop(
            sec: sec,
            child: PencilMascot(controller: _mascot, size: 240),
          ),
          const SizedBox(height: 10 + 6),
          _Wordmark(sec: sec),
          const SizedBox(height: 10 - 8),
          SizedBox(
            width: 190,
            height: 22,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: CustomPaint(painter: _LinePainter(_seg(sec, 1.9, 2.4, Curves.easeOut)))),
                // sparkles fly off the pen as it finishes the line (182, 9)
                if (sec >= 2.2) const Positioned(left: 182 - 55, top: 9 - 55, child: SparkleBurst(size: 110, count: 11, seed: 5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS cubic-bezier(.3,.7,.4,1), applied per keyframe segment like CSS does.
const Curve _splashEase = Cubic(0.3, 0.7, 0.4, 1.0);

double _seg(double t, double a, double b, Curve c) => c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// splashIn: 1.05 s. translateY 460 -> 0 (squash 1.14/.84 at 45 %) -> -36
/// (stretch .93/1.09 at 60 %) -> 0 (1.05/.95 at 78 %) -> rest. Origin = box centre.
class _MascotDrop extends StatelessWidget {
  const _MascotDrop({required this.sec, required this.child});
  final double sec;
  final Widget child;

  static const _keys = <(double, double, double, double)>[
    // (progress, translateY, scaleX, scaleY)
    (0.00, 460, 1.00, 1.00),
    (0.45, 0, 1.14, 0.84),
    (0.60, -36, 0.93, 1.09),
    (0.78, 0, 1.05, 0.95),
    (1.00, 0, 1.00, 1.00),
  ];

  @override
  Widget build(BuildContext context) {
    final p = (sec / 1.05).clamp(0.0, 1.0);
    var ty = 0.0, sx = 1.0, sy = 1.0;
    for (var i = 0; i < _keys.length - 1; i++) {
      final a = _keys[i], b = _keys[i + 1];
      if (p <= b.$1) {
        final k = _splashEase.transform((p - a.$1) / (b.$1 - a.$1));
        ty = a.$2 + (b.$2 - a.$2) * k;
        sx = a.$3 + (b.$3 - a.$3) * k;
        sy = a.$4 + (b.$4 - a.$4) * k;
        break;
      }
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.translationValues(0, ty, 0)..multiply(Matrix4.diagonal3Values(sx, sy, 1)),
      child: SizedBox(
        width: 170,
        height: 240,
        // the Pencil artboard is a little wider than the prototype's 170 px box
        child: OverflowBox(maxWidth: double.infinity, child: child),
      ),
    );
  }
}

/// "Likho": Baloo 2 800, 78/1, letter-spacing -1, bottom-aligned letters.
/// Each letter "writes in": clip reveals left -> right while rising 6 px.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.sec});
  final double sec;

  // letter, delay, duration (s), colour
  static const _letters = <(String, double, double, Color)>[
    ('L', 1.00, 0.26, LikhoColors.ink),
    ('i', 1.20, 0.22, LikhoColors.ink),
    ('k', 1.36, 0.24, LikhoColors.ink),
    ('h', 1.54, 0.24, LikhoColors.ink),
    ('o', 1.72, 0.26, LikhoColors.hint),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (ch, delay, dur, color) in _letters)
          _WriteIn(
            progress: _seg(sec, delay, delay + dur, Curves.easeOut),
            child: Text(
              ch,
              style: LikhoFonts.title(
                size: 78,
                weight: FontWeight.w800,
                color: color,
              ).copyWith(height: 1, letterSpacing: -1, leadingDistribution: TextLeadingDistribution.even),
            ),
          ),
      ],
    );
  }
}

class _WriteIn extends StatelessWidget {
  const _WriteIn({required this.progress, required this.child});
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, 6 * (1 - progress)),
      child: ClipRect(clipper: _RevealClipper(progress), child: child),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, -20, size.width * progress, size.height + 40);

  @override
  bool shouldReclip(_RevealClipper old) => old.progress != progress;
}

/// SVG path "M8 13 Q52 3 95 12 T182 9", stroke 7, round caps, primary yellow,
/// drawn from start to end as [progress] goes 0 -> 1.
class _LinePainter extends CustomPainter {
  _LinePainter(this.progress);
  final double progress;

  static final Path _path = Path()
    ..moveTo(8, 13)
    ..quadraticBezierTo(52, 3, 95, 12)
    ..quadraticBezierTo(138, 21, 182, 9); // T reflects the previous control point

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = LikhoColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final m = _path.computeMetrics().first;
    canvas.drawPath(m.extractPath(0, m.length * progress), paint);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.progress != progress;
}

/// radial-gradient(circle at 50% 40%, #FFF0CC 0%, #FFF8EC 62%), "circle"
/// sized to the farthest corner like CSS.
class _GlowBackground extends CustomPainter {
  const _GlowBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.4);
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((p) => (p - c).distance).reduce((a, b) => a > b ? a : b);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: const [LikhoColors.backgroundGlow, LikhoColors.background],
          stops: const [0, 0.62],
        ).createShader(Rect.fromCircle(center: c, radius: far)),
    );
  }

  @override
  bool shouldRepaint(_GlowBackground old) => false;
}
