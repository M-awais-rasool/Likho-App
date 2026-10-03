// Builds Likho's app icon for iOS and Android. Pencil is drawn by the app's
// own mascot painter, so the icon always matches the mascot in the app.
// Run from app/ (Flutter's test runner provides the engine that draws):
//
//   flutter test tool/app_icon/build_app_icon.dart
//
// It writes every icon file (see README.md) and fails if Pencil leaves the
// adaptive icon's safe zone, the part that no launcher mask cuts off.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/mascot/mascot_animations.dart';
import 'package:likho/mascot/mascot_controller.dart';
import 'package:likho/mascot/mascot_painter.dart';
import 'package:likho/mascot/mascot_pose.dart';
import 'package:likho/mascot/rig/part_library.dart';
import 'package:likho/mascot/rig/pencil_rig.dart';

// ------------------------------------------------------------------ design
// Positions and sizes are fractions of the visible icon: the whole square on
// iOS, the middle 72 dp of an adaptive icon's 108 dp layers on Android.

/// Violet behind a yellow pencil: the strongest, friendliest contrast.
const _day = [Color(0xFFB9A2FF), Color(0xFF6A48DD)];

/// The same sky at night, for iOS's dark home screen.
const _night = [Color(0xFF3B2D7A), Color(0xFF15122B)];

/// Pencil's artboard height, body centre and tilt (radians, leaning into the wave).
const _height = .88;
const _centre = Offset(.5, .53);
const _tilt = -.10;

/// Sparkles: centre x, centre y, radius.
const _sparkles = [(.80, .20, .05), (.17, .27, .035), (.86, .40, .025)];

/// Android's safe zone: a 66 dp circle in the 72 dp icon survives every mask.
const _safeRadius = 33 / 72;

/// Waving hello with a big smile, eyes on the child.
final MascotPose _wave = MascotAnimations.sample(MascotState.talking, .4, talk: const TalkInput(level: .5, mouth: MouthShape.laugh))
    .copyWith(x: 0, y: 0, rotation: 0, lookX: 0, lookY: 0);

enum _Sky { day, night, black }

/// Holds one pose: no blinking, no clock.
class _Still extends MascotController {
  _Still(this._pose);
  final MascotPose _pose;

  @override
  MascotPose get pose => _pose;
  @override
  Offset get look => Offset.zero;
  @override
  double get blink => 0;
  @override
  double get time => 0;
}

// ------------------------------------------------------------------ drawing
/// Background of an icon of side [s]. It overflows the square, so Android's
/// layers (wider than the visible icon) are covered too.
void _background(Canvas c, double s, _Sky sky) {
  final all = Rect.fromLTWH(-s, -s, 3 * s, 3 * s);
  if (sky == _Sky.black) {
    c.drawRect(all, Paint()..color = const Color(0xFF000000));
    return;
  }
  final day = sky == _Sky.day;
  c.drawRect(all, Paint()..shader = ui.Gradient.linear(Offset(s * .2, 0), Offset(s * .8, s), day ? _day : _night));
  final mid = Offset(s * _centre.dx, s * (_centre.dy - .02));
  final rays = Path();
  const n = 14;
  for (var i = 0; i < n; i++) {
    final a = 2 * math.pi * i / n, b = a + math.pi / n;
    rays
      ..moveTo(mid.dx, mid.dy)
      ..lineTo(mid.dx + math.cos(a) * 2 * s, mid.dy + math.sin(a) * 2 * s)
      ..lineTo(mid.dx + math.cos(b) * 2 * s, mid.dy + math.sin(b) * 2 * s)
      ..close();
  }
  c.drawPath(rays, Paint()..shader = ui.Gradient.radial(mid, s * .75, [Color(day ? 0x30FFFFFF : 0x16FFFFFF), const Color(0x00FFFFFF)]));
  final glow = day ? const Color(0x59FFFFFF) : const Color(0x598E6CFF);
  c.drawCircle(mid, s * .46, Paint()..shader = ui.Gradient.radial(mid, s * .46, [glow, glow.withValues(alpha: 0)]));
}

Path _sparkle(Offset c, double r) {
  final k = r * .16;
  return Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
    ..close();
}

/// Pencil (with his ground shadow and the sparkles) in an icon of side [s].
void _pencil(Canvas c, double s, MascotParts parts, {bool shadow = true, bool sparkles = true}) {
  final h = s * _height;
  final k = h / PencilRig.artboard.height;
  final w = PencilRig.artboard.width * k;
  final centre = Offset(s * _centre.dx, s * _centre.dy);
  if (shadow) {
    // artboard (250, 642) = between the feet
    final feet = centre + Offset(-math.sin(_tilt), math.cos(_tilt)) * (302 * k);
    c.drawOval(Rect.fromCenter(center: feet, width: w * .62, height: s * .045),
        Paint()
          ..color = const Color(0x2A000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .008));
  }
  if (sparkles) {
    final white = Paint()..color = const Color(0xFFFFFFFF);
    for (final (x, y, r) in _sparkles) {
      c.drawPath(_sparkle(Offset(s * x, s * y), s * r), white);
    }
  }
  c.save();
  c.translate(centre.dx, centre.dy);
  c.rotate(_tilt);
  c.translate(-w / 2, -340 * k); // artboard (250, 340) = body centre
  MascotPainter(controller: _Still(_wave), parts: parts, shadow: false).paint(c, Size(w, h));
  c.restore();
}

// ------------------------------------------------------------------ pixels
Future<Uint8List> _rgba(int px, void Function(Canvas c) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Grey from luminance (iOS's tinted icon: the system colours it).
Uint8List _grey(Uint8List rgba) {
  final out = Uint8List.fromList(rgba);
  for (var i = 0; i < out.length; i += 4) {
    final y = (.2126 * out[i] + .7152 * out[i + 1] + .0722 * out[i + 2]).round();
    out[i] = out[i + 1] = out[i + 2] = y;
  }
  return out;
}

/// White silhouette (Android 13's themed icon only uses alpha): dark lines,
/// pupils and the mouth become holes, so the face still shows.
Uint8List _stencil(Uint8List rgba) {
  final out = Uint8List(rgba.length);
  for (var i = 0; i < out.length; i += 4) {
    final lum = (.2126 * rgba[i] + .7152 * rgba[i + 1] + .0722 * rgba[i + 2]) / 255;
    final t = ((lum - .42) / .2).clamp(0.0, 1.0);
    out[i] = out[i + 1] = out[i + 2] = 255;
    out[i + 3] = (rgba[i + 3] * t * t * (3 - 2 * t)).round();
  }
  return out;
}

/// PNG with no metadata. [alpha] false drops the alpha channel, which the
/// App Store requires of iOS icons.
Uint8List _png(int px, Uint8List rgba, {required bool alpha}) {
  final ch = alpha ? 4 : 3;
  final stride = px * ch;
  final rows = Uint8List(px * (stride + 1));
  var prev = Uint8List(stride);
  for (var y = 0; y < px; y++) {
    final row = Uint8List(stride);
    for (var x = 0; x < px; x++) {
      for (var k = 0; k < ch; k++) {
        row[x * ch + k] = rgba[(y * px + x) * 4 + k];
      }
    }
    // filter 4 (Paeth): smooth gradients compress well
    final o = y * (stride + 1);
    rows[o] = 4;
    for (var i = 0; i < stride; i++) {
      final a = i >= ch ? row[i - ch] : 0, b = prev[i], c = i >= ch ? prev[i - ch] : 0;
      final p = a + b - c, pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
      final pred = pa <= pb && pa <= pc ? a : (pb <= pc ? b : c);
      rows[o + 1 + i] = (row[i] - pred) & 0xFF;
    }
    prev = row;
  }
  final out = BytesBuilder();
  void chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    out
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(_crc(body)));
  }

  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  chunk('IHDR', [..._u32(px), ..._u32(px), 8, alpha ? 6 : 2, 0, 0, 0]);
  chunk('IDAT', ZLibEncoder(level: 9).convert(rows));
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => [v >> 24 & 0xFF, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF];

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

void _write(String path, List<int> bytes) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

// ------------------------------------------------------------------ files
const _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _res = 'android/app/src/main/res';
const _store = '../design/app-icon';

/// Android density buckets: pixels per dp.
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

const _contents = '''
{
  "images" : [
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "Icon-App-Dark-1024x1024@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "Icon-App-Tinted-1024x1024@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''';

const _adaptive = '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Made by tool/app_icon/build_app_icon.dart -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''';

void main() {
  testWidgets('build the app icon', (tester) async {
    expect(File('pubspec.yaml').existsSync(), isTrue, reason: 'run from app/');
    await tester.runAsync(() async {
      final parts = await MascotParts.load();

      // Pencil must stay inside the safe zone (sparkles may be cut by a mask)
      const probe = 720;
      final only = await _rgba(probe, (c) => _pencil(c, probe.toDouble(), parts, shadow: false, sparkles: false));
      var reach = 0.0;
      for (var i = 0; i < probe * probe; i++) {
        if (only[i * 4 + 3] > 8) {
          reach = math.max(reach, (Offset(i % probe + .5, i ~/ probe + .5) - const Offset(probe / 2, probe / 2)).distance);
        }
      }
      expect(reach / probe, lessThanOrEqualTo(_safeRadius), reason: 'Pencil leaves the safe zone');

      // iOS: 1024 px for each appearance; Xcode makes every other size
      Future<Uint8List> full(int px, _Sky sky) => _rgba(px, (c) {
            _background(c, px.toDouble(), sky);
            _pencil(c, px.toDouble(), parts, shadow: sky != _Sky.black);
          });
      for (final f in Directory(_ios).listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
        f.deleteSync();
      }
      final day = await full(1024, _Sky.day);
      _write('$_ios/Icon-App-1024x1024@1x.png', _png(1024, day, alpha: false));
      _write('$_ios/Icon-App-Dark-1024x1024@1x.png', _png(1024, await full(1024, _Sky.night), alpha: false));
      _write('$_ios/Icon-App-Tinted-1024x1024@1x.png', _png(1024, _grey(await full(1024, _Sky.black)), alpha: false));
      _write('$_ios/Contents.json', _contents.codeUnits);

      // Android: adaptive layers (108 dp, icon in the middle 72 dp) and, for
      // Android 7 and older, a square and a round icon (48 dp)
      for (final MapEntry(key: bucket, value: d) in _densities.entries) {
        final dir = '$_res/mipmap-$bucket';
        final layer = (108 * d).round();
        final edge = 18 * d, s = 72 * d;
        Future<Uint8List> adaptive(void Function(Canvas c) draw) => _rgba(layer, (c) {
              c.translate(edge, edge);
              draw(c);
            });
        _write('$dir/ic_launcher_background.png', _png(layer, await adaptive((c) => _background(c, s, _Sky.day)), alpha: false));
        _write('$dir/ic_launcher_foreground.png', _png(layer, await adaptive((c) => _pencil(c, s, parts)), alpha: true));
        _write('$dir/ic_launcher_monochrome.png', _png(layer, _stencil(await adaptive((c) => _pencil(c, s, parts, shadow: false))), alpha: true));

        final px = (48 * d).round();
        final inset = px / 24; // 2 dp
        final box = Rect.fromLTWH(inset, inset, px - 2 * inset, px - 2 * inset);
        for (final (name, shape) in [
          ('ic_launcher', RRect.fromRectAndRadius(box, Radius.circular(box.width * .22))),
          ('ic_launcher_round', RRect.fromRectAndRadius(box, Radius.circular(box.width / 2))),
        ]) {
          _write('$dir/$name.png', _png(px, await _rgba(px, (c) {
            c.drawRRect(shape.shift(Offset(0, px * .015)), Paint()
              ..color = const Color(0x33000000)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, px * .015));
            c.save();
            c.clipRRect(shape);
            c.translate(box.left, box.top);
            _background(c, box.width, _Sky.day);
            _pencil(c, box.width, parts);
            c.restore();
          }), alpha: true));
        }
      }
      _write('$_res/mipmap-anydpi-v26/ic_launcher.xml', _adaptive.codeUnits);
      _write('$_res/mipmap-anydpi-v26/ic_launcher_round.xml', _adaptive.codeUnits);

      // stores: Google Play takes a 512 px square (it rounds the corners itself)
      _write('$_store/google-play-512.png', _png(512, await full(512, _Sky.day), alpha: false));
      _write('$_store/likho-icon-1024.png', _png(1024, day, alpha: false));
      // ignore: avoid_print
      print('icon written; Pencil reaches ${(reach / probe * 72).toStringAsFixed(1)} of 33 dp from the centre');
    });
  });
}
