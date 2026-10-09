// Draws Pencil in the poses the store screenshots use, as large transparent
// PNGs, with the app's own mascot painter. Run from app/:
//
//   flutter test tool/store_screenshots/render_mascot.dart
//
// Writes ../design/store-screenshots/mascot/<name>.png (1600 px tall).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/mascot/mascot_animations.dart';
import 'package:likho/mascot/mascot_controller.dart';
import 'package:likho/mascot/mascot_painter.dart';
import 'package:likho/mascot/mascot_pose.dart';
import 'package:likho/mascot/rig/part_library.dart';
import 'package:likho/mascot/rig/pencil_rig.dart';

const _height = 1600.0;
const _out = '../design/store-screenshots/mascot';

/// Holds one pose: no blinking, no clock.
class _Still extends MascotController {
  _Still(this._pose, this._look);
  final MascotPose _pose;
  final Offset _look;

  @override
  MascotPose get pose => _pose;
  @override
  Offset get look => _look;
  @override
  double get blink => 0;
  @override
  double get time => .3;
}

MascotPose _at(MascotState s, double t, {MouthShape? mouth}) =>
    MascotAnimations.sample(s, t, talk: TalkInput(level: .5, mouth: mouth ?? MouthShape.laugh)).copyWith(x: 0, y: 0, rotation: 0);

/// name, pose, eye look, accessory
final _poses = <(String, MascotPose, Offset, String?)>[
  ('wave', _at(MascotState.talking, .4), Offset.zero, null),
  ('wave-left', _at(MascotState.talking, .4), const Offset(-.6, .1), null),
  ('happy', _at(MascotState.happy, .45), Offset.zero, null),
  ('wow', _at(MascotState.wow, .5), Offset.zero, null),
  ('dance', _at(MascotState.dance, .3), Offset.zero, null),
  ('encourage', _at(MascotState.encourage, .5), Offset.zero, null),
  ('crown', _at(MascotState.happy, .45), Offset.zero, MascotAccessory.crown),
  ('party', _at(MascotState.dance, .3), Offset.zero, MascotAccessory.partyHat),
  ('wizard', _at(MascotState.talking, .4), const Offset(.5, 0), MascotAccessory.wizardHat),
  ('glasses', _at(MascotState.encourage, .5), Offset.zero, MascotAccessory.starGlasses),
  ('watch', _at(MascotState.watching, .5), const Offset(.4, .6), null),
];

void main() {
  testWidgets('draw Pencil for the store screenshots', (tester) async {
    expect(File('pubspec.yaml').existsSync(), isTrue, reason: 'run from app/');
    await tester.runAsync(() async {
      final parts = await MascotParts.load();
      final k = _height / PencilRig.artboard.height;
      final w = PencilRig.artboard.width * k;
      // room around the artboard for arms and effects; trimmed later
      final cw = (w * 1.8).round(), ch = (_height * 1.4).round();
      for (final (name, pose, look, acc) in _poses) {
        final c = _Still(pose, look);
        if (acc != null) c.wear(acc);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..translate((cw - w) / 2, (ch - _height) * .6);
        MascotPainter(controller: c, parts: parts, shadow: false).paint(canvas, Size(w, _height));
        final image = await recorder.endRecording().toImage(cw, ch);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      }
    });
  });
}
