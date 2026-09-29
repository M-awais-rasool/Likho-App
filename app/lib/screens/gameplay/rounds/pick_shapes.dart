import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../data/models/course_models.dart';
import '../../../design/tokens.dart';
import '../widgets/illustration.dart';

/// Pick item shapes from the prototype's shapeStyle(): balloon, bubble,
/// kite, fish, mushroom, shell, pad, basket, jar, bucket, card, cloud, planet.
/// Unknown shapes fall back to card.
class PickShape {
  const PickShape._(this.name);
  final String name;

  static const known = {'balloon', 'bubble', 'kite', 'fish', 'mushroom', 'shell', 'pad', 'basket', 'jar', 'bucket', 'card', 'cloud', 'planet'};
  static const floating = {'balloon', 'bubble', 'kite', 'fish'};

  static String resolve(String? s) => known.contains(s) ? s! : 'card';
}

/// Body size of each shape (card grows with a picture).
Size pickBodySize(String shape, {bool hasPic = false}) => switch (shape) {
  'balloon' => const Size(80, 96),
  'bubble' => const Size(84, 84),
  'kite' => const Size(76, 76),
  'fish' => const Size(100, 62),
  'mushroom' => const Size(96, 62),
  'shell' => const Size(96, 88),
  'pad' => const Size(112, 112),
  'basket' => const Size(100, 96),
  'jar' => const Size(88, 112),
  'bucket' => const Size(86, 92),
  'cloud' => const Size(132, 80),
  'planet' => const Size(110, 110),
  _ => Size(100, hasPic ? 130 : 76),
};

/// One tappable item: optional parts above (lid, crab eyes), the body with
/// picture and label, optional parts below (stem, string, kite tail).
class PickItemBody extends StatelessWidget {
  const PickItemBody({super.key, required this.shape, required this.color, required this.option, required this.label, this.ring});

  final String shape;
  final Color color;
  final PickOption option;
  final String label;

  /// Drawn around the body (ok / hint rings), 8 px outside, radius 40.
  final Widget? ring;

  bool get _light => color == LikhoColors.primary;
  Color get _labelColor => _light ? LikhoColors.ink : LikhoColors.surface;

  @override
  Widget build(BuildContext context) {
    final pic = option.picture;
    final size = pickBodySize(shape, hasPic: pic != null);
    final painted = CustomPaint(painter: _BodyPainter(shape, color), child: _content(pic, size));
    // cards use min-height in the prototype: they grow with their content
    final body = shape == 'card'
        ? ConstrainedBox(
            constraints: BoxConstraints(minWidth: size.width, maxWidth: size.width, minHeight: size.height),
            child: painted,
          )
        : SizedBox.fromSize(size: size, child: painted);
    final Widget core = shape == 'kite' ? Transform.rotate(angle: math.pi / 4, child: body) : body;
    // Jar lid / crab eyes: a negative bottom margin (-4 / -10) with z-index 1,
    // so they overlap the body's top edge and are drawn over it.
    final (double above, Widget? topper) = switch (shape) {
      'jar' => (
        10.0,
        Container(
          width: 64,
          height: 14,
          decoration: BoxDecoration(color: GameColors.basketB, borderRadius: BorderRadius.circular(6)),
        ),
      ),
      'basket' => (8.0, const Row(mainAxisSize: MainAxisSize.min, children: [_CrabEye(), SizedBox(width: 26), _CrabEye()])),
      _ => (0.0, null),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (above > 0) SizedBox(height: above),
        Stack(
          clipBehavior: Clip.none,
          children: [
            core,
            if (shape == 'fish')
              Positioned(
                right: -18,
                top: size.height / 2 - 16,
                width: 24,
                height: 32,
                child: CustomPaint(painter: _FinPainter(color)),
              ),
            if (ring != null) Positioned(left: -8, top: -8, right: -8, bottom: -8, child: ring!),
            if (topper != null) Positioned(top: -above, left: 0, right: 0, child: Center(child: topper)),
          ],
        ),
        if (shape == 'mushroom')
          Transform.translate(
            offset: const Offset(0, -2),
            child: SizedBox(width: 42, height: 40, child: CustomPaint(painter: _StemPainter())),
          ),
        if (shape == 'balloon')
          Container(
            width: 2,
            height: 44,
            decoration: BoxDecoration(color: GameColors.ink35, borderRadius: BorderRadius.circular(1)),
          ),
        if (shape == 'kite')
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: SizedBox(width: 2, height: 40, child: CustomPaint(painter: _TailPainter())),
          ),
      ],
    );
  }

  Widget _content(Picture? pic, Size size) {
    final smallPic = shape == 'pad' || shape == 'planet';
    final labelWidget = _label();
    final children = <Widget>[
      if (pic != null) Illustration(picture: pic, width: 84, height: smallPic ? 46 : 64, radius: 14, padding: 4),
      if (pic != null && labelWidget != null) const SizedBox(height: 4),
      ?labelWidget,
    ];
    final column = Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: children);
    final padded = Padding(
      padding: EdgeInsets.all(shape == 'card' ? 8 : (shape == 'pad' || shape == 'planet' ? 10 : 0)),
      // fixed-size shapes: long labels shrink to fit instead of spilling out
      child: shape == 'card' ? Center(heightFactor: 1, child: column) : Center(child: FittedBox(fit: BoxFit.scaleDown, child: column)),
    );
    return shape == 'kite' ? Transform.rotate(angle: -math.pi / 4, child: padded) : padded;
  }

  Widget? _label() {
    if (label.isEmpty) return null;
    TextStyle andika(double s, Color c) => LikhoFonts.letter(size: s, color: c).copyWith(fontWeight: FontWeight.w700, height: 1);
    return switch (shape) {
      'balloon' => Text(label, style: andika(42, _labelColor)),
      'bubble' => Text(label, style: andika(42, GameColors.bubbleLabel)),
      'kite' => Text(label, style: andika(26, _labelColor)),
      'fish' => Text(label, style: andika(34, _labelColor)),
      'mushroom' => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(label, style: andika(34, _labelColor)),
      ),
      'shell' => Text(label, style: andika(40, GameColors.shellLabel)),
      'pad' => Text(label, style: andika(20, LikhoColors.surface)),
      'basket' => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: GameColors.black18, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: andika(22, LikhoColors.surface)),
      ),
      'jar' => Text(
        label,
        style: LikhoFonts.title(size: 40, weight: FontWeight.w800, color: GameColors.jarLabel).copyWith(height: 1),
      ),
      'bucket' => Text(label, style: andika(20, _labelColor)),
      'cloud' => Text(label, style: andika(38, GameColors.cloudLabel)),
      'planet' => Text(label, textAlign: TextAlign.center, style: andika(15, LikhoColors.surface).copyWith(height: 1.1)),
      _ => Text(label, textAlign: TextAlign.center, style: andika(22, LikhoColors.ink).copyWith(height: 1.1)),
    };
  }
}

class _CrabEye extends StatelessWidget {
  const _CrabEye();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 18, height: 18, child: CustomPaint(painter: _InsetCircle(LikhoColors.hint, GameColors.hintDeep, const Offset(0, -3))));
}

/// Circle with an inset shadow (CSS inset box-shadow, no blur).
class _InsetCircle extends CustomPainter {
  const _InsetCircle(this.fill, this.shade, this.offset);
  final Color fill, shade;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()..addOval(Offset.zero & size);
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(_insetRegion(p, offset), Paint()..color = shade);
  }

  @override
  bool shouldRepaint(_InsetCircle old) => false;
}

/// CSS `inset X Y 0 color`: the part of the shape not covered by the shape
/// moved by (X, Y).
Path _insetRegion(Path shape, Offset o) => Path.combine(PathOperation.difference, shape, shape.shift(o));

RRect _rr(Size s, List<double> hx, List<double> hy, {bool percent = true}) {
  // corners: TL, TR, BR, BL
  Radius r(int i) => percent ? Radius.elliptical(s.width * hx[i] / 100, s.height * hy[i] / 100) : Radius.elliptical(hx[i], hy[i]);
  return RRect.fromRectAndCorners(Offset.zero & s, topLeft: r(0), topRight: r(1), bottomRight: r(2), bottomLeft: r(3)).scaleRadii();
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.shape, this.color);
  final String shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    void fill(Path p, Color c) => canvas.drawPath(p, paint..color = c);
    void drop(Path p, Offset o, Color c, [double blur = 0]) {
      // CSS paints a box-shadow only outside the box, so it never shows
      // through see-through bodies (bubble, jar).
      final pp = Paint()..color = c;
      if (blur > 0) pp.maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);
      canvas
        ..save()
        ..clipPath(Path()
          ..fillType = PathFillType.evenOdd
          ..addRect((Offset.zero & size).inflate(80))
          ..addPath(p, Offset.zero))
        ..drawPath(p.shift(o), pp)
        ..restore();
    }

    switch (shape) {
      case 'balloon':
        final p = Path()..addRRect(_rr(size, [50, 50, 48, 48], [56, 56, 44, 44]));
        fill(p, color);
        fill(_insetRegion(p, const Offset(-10, -12)), GameColors.black10);
        fill(_insetRegion(p, const Offset(10, 10)), GameColors.white28);
      case 'bubble':
        final p = Path()..addOval(Offset.zero & size);
        drop(p, const Offset(0, 6), GameColors.bubbleShadow, 16);
        canvas.drawPath(
          p,
          paint
            ..shader = const RadialGradient(
              center: Alignment(-.36, -.44),
              radius: 1.05,
              colors: [GameColors.white95, GameColors.white95, GameColors.white35, GameColors.white35, GameColors.bubbleEdge],
              stops: [0, .08, .09, .6, 1],
            ).createShader(Offset.zero & size),
        );
        paint.shader = null;
        canvas.drawOval(
          (Offset.zero & size).deflate(1.25),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = GameColors.bubbleRim,
        );
      case 'kite':
        final p = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)));
        drop(p, const Offset(0, 8), GameColors.black08);
        fill(p, color);
        canvas.save();
        canvas.clipPath(p);
        // linear-gradient(135deg, col 50%, rgba(255,255,255,.25) 50%): lower-right half lighter
        fill(Path()..addPolygon([Offset(size.width, 0), Offset(size.width, size.height), Offset(0, size.height)], true), GameColors.white25);
        canvas.restore();
      case 'fish':
        final p = Path()..addRRect(_rr(size, [50, 42, 42, 50], [50, 42, 42, 50]));
        fill(p, color);
        fill(_insetRegion(p, const Offset(-8, -8)), GameColors.black10);
      case 'mushroom':
        final p = Path()..addRRect(_rr(size, [60, 60, 18, 18], [60, 60, 18, 18], percent: false));
        fill(p, color);
        paint.color = LikhoColors.surface;
        canvas.drawCircle(Offset(size.width * .25, size.height * .4), 5.5, paint);
        canvas.drawCircle(Offset(size.width * .72, size.height * .3), 6.5, paint);
        fill(_insetRegion(p, const Offset(0, -8)), GameColors.black10);
      case 'shell':
        final p = Path()..addRRect(_rr(size, [50, 50, 42, 42], [64, 64, 36, 36]));
        drop(p, const Offset(0, 6), GameColors.shellShade);
        canvas.save();
        canvas.clipPath(p);
        for (var x = 0.0; x < size.width; x += 20) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 10, size.height), paint..color = GameColors.shellA);
          canvas.drawRect(Rect.fromLTWH(x + 10, 0, 10, size.height), paint..color = GameColors.shellB);
        }
        canvas.restore();
        fill(_insetRegion(p, const Offset(0, -8)), GameColors.shellShade);
      case 'pad':
        final p = Path()..addOval(Offset.zero & size);
        drop(p, const Offset(0, 6), GameColors.lilyPadShadow);
        fill(p, GameColors.lilyPad);
        fill(_insetRegion(p, const Offset(-10, -10)), GameColors.black10);
      case 'basket':
        final p = Path()..addRRect(_rr(size, [14, 14, 30, 30], [14, 14, 30, 30], percent: false));
        drop(p, const Offset(0, 6), GameColors.black08);
        canvas.save();
        canvas.clipPath(p);
        // repeating-linear-gradient(0deg, A 0 8px, B 8px 10px) from the bottom up
        for (var y = size.height; y > -10; y -= 10) {
          canvas.drawRect(Rect.fromLTRB(0, y - 8, size.width, y), paint..color = GameColors.basketA);
          canvas.drawRect(Rect.fromLTRB(0, y - 10, size.width, y - 8), paint..color = GameColors.basketB);
        }
        canvas.restore();
        fill(_insetRegion(p, const Offset(0, 6)), GameColors.white20);
      case 'jar':
        final p = Path()..addRRect(_rr(size, [24, 24, 30, 30], [24, 24, 30, 30], percent: false));
        drop(p, const Offset(0, 8), GameColors.jarShadow, 20);
        canvas.drawPath(
          p,
          paint
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [GameColors.jarTop, GameColors.jarBottom],
            ).createShader(Offset.zero & size),
        );
        paint.shader = null;
        canvas.drawRRect(
          _rr(size, [24, 24, 30, 30], [24, 24, 30, 30], percent: false).deflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = GameColors.bubbleRim,
        );
      case 'bucket':
        final p = Path()..addRRect(_rr(size, [8, 8, 26, 26], [8, 8, 26, 26], percent: false));
        drop(p, const Offset(0, 6), GameColors.black10);
        fill(p, color);
        canvas.save();
        canvas.clipPath(p);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 10), paint..color = GameColors.black12);
        canvas.restore();
        fill(_insetRegion(p, const Offset(10, 0)), GameColors.white20);
      case 'cloud':
        final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(40));
        drop(Path()..addRRect(r), const Offset(0, 8), GameColors.cloudShadow);
        paint.color = LikhoColors.surface;
        // box-shadow puffs: -26px -14px spread -6, 22px -20px spread -2
        canvas.drawRRect(r.shift(const Offset(-26, -14)).deflate(6), paint);
        canvas.drawRRect(r.shift(const Offset(22, -20)).deflate(2), paint);
        canvas.drawRRect(r, paint);
      case 'planet':
        final p = Path()..addOval(Offset.zero & size);
        canvas.drawCircle(size.center(Offset.zero), size.width / 2 + 6, paint..color = GameColors.planetRing);
        fill(p, color);
        canvas.drawPath(
          p,
          paint
            ..shader = const RadialGradient(
              center: Alignment(-.3, -.4),
              radius: .9,
              colors: [GameColors.white35, GameColors.white00],
              stops: [0, .5],
            ).createShader(Offset.zero & size),
        );
        paint.shader = null;
        fill(_insetRegion(p, const Offset(-10, -12)), GameColors.black18);
      default: // card
        final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22));
        final p = Path()..addRRect(r);
        drop(p, const Offset(0, 10), GameColors.ink08, 24);
        drop(p, const Offset(0, 6), GameColors.ink08);
        fill(p, LikhoColors.surface);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.shape != shape || old.color != color;
}

class _FinPainter extends CustomPainter {
  const _FinPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // border-right triangle: base on the right, point on the left
    canvas.drawPath(Path()..addPolygon([Offset(0, size.height / 2), Offset(size.width, 0), Offset(size.width, size.height)], true), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FinPainter old) => old.color != color;
}

class _StemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndCorners(Offset.zero & size, bottomLeft: const Radius.circular(14), bottomRight: const Radius.circular(14));
    final p = Path()..addRRect(r);
    canvas.drawPath(p, Paint()..color = GameColors.mushroomStem);
    canvas.drawPath(_insetRegion(p, const Offset(-6, 0)), Paint()..color = GameColors.black06);
  }

  @override
  bool shouldRepaint(_StemPainter old) => false;
}

class _TailPainter extends CustomPainter {
  const _TailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = GameColors.ink40;
    for (var y = 0.0; y < size.height; y += 9) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, math.min(6, size.height - y)), p);
    }
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}
