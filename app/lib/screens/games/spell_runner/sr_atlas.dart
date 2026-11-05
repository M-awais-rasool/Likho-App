import 'dart:ui';

import 'sr_scene.dart';

/// Source rectangles retain the generated alpha. No individual pose is resized
/// to its bounds: a shared scale and a measured rear axle keep the board planted.
abstract final class SrAtlas {
  static const _props = <String, Rect>{
    'apple_tree': Rect.fromLTRB(48, 49, 381, 397),
    'tree': Rect.fromLTRB(468, 48, 781, 397),
    'flowers': Rect.fromLTRB(868, 124, 1211, 390),
    'sunflower': Rect.fromLTRB(868, 124, 1211, 390),
    'flowerbox': Rect.fromLTRB(868, 124, 1211, 390),
    'bush': Rect.fromLTRB(868, 124, 1211, 390),
    'cone': Rect.fromLTRB(74, 469, 361, 785),
    'barrier': Rect.fromLTRB(435, 493, 817, 752),
    'log': Rect.fromLTRB(852, 514, 1217, 740),
    'cart': Rect.fromLTRB(33, 862, 392, 1205),
    'ramp': Rect.fromLTRB(432, 890, 817, 1187),
    'pine': Rect.fromLTRB(887, 843, 1188, 1209),
  };

  static Rect? prop(String asset) => _props[asset.split('/').last.split('.').first];

  static const _anchors = [Offset(260, 478), Offset(790, 480), Offset(1238, 480), Offset(259, 955), Offset(762, 987), Offset(1276, 988)];

  static void rider(Canvas canvas, String pose, Offset foot, double height, {double rotation = 0, double alpha = 1}) {
    final image = SrSprites.of(SrArt.moves);
    if (image == null) return;
    final name = pose.split('/').last.replaceAll('rider_', '').replaceAll('.webp', '');
    final cell = switch (name) {
      'carve_left' => 1,
      'carve_right' || 'stumble' => 2,
      'jump' || 'trick' => 3,
      'slide' || 'crouch' || 'land' => 4,
      'cheer' => 5,
      _ => 0,
    };
    final source = Rect.fromLTWH((cell % 3) * 512, (cell ~/ 3) * 512, 512, 512);
    final anchor = _anchors[cell] - source.topLeft;
    final scale = height / 420;
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.rotate(rotation);
    canvas.drawImageRect(
      image,
      source,
      Rect.fromLTWH(-anchor.dx * scale, -anchor.dy * scale, 512 * scale, 512 * scale),
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );
    canvas.restore();
  }
}
