// Renders the mascot to PNG files in build/mascot_renders/ so they can be
// compared with the reference art (assets/reference/). Run:
//   flutter test test/mascot_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/mascot/mascot.dart';
import 'package:likho/mascot/mascot_animations.dart';
import 'package:likho/mascot/mascot_pose.dart';
import 'package:likho/mascot/rig/part_library.dart';

Future<void> _render(WidgetTester tester, MascotController c, String name, {double height = 680}) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(color: Colors.white, child: Padding(padding: EdgeInsets.all(height * 120 / 680), child: PencilMascot(controller: c, size: height))),
      ),
    ),
  ));
  await tester.runAsync(() => MascotParts.load());
  await tester.pump();
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final f = File('build/mascot_renders/$name.png');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes!);
  // ignore: avoid_print
  print('rendered $name');
}

void main() {
  testWidgets('idle at rest matches the master framing', (tester) async {
    tester.view.physicalSize = const Size(740, 920);
    tester.view.devicePixelRatio = 1;
    final c = MascotController()..freezeAtRest();
    await _render(tester, c, 'idle_rest');
    expect(File('build/mascot_renders/idle_rest.png').existsSync(), isTrue);
  });

  testWidgets('every state renders', (tester) async {
    tester.view.physicalSize = const Size(740, 920);
    tester.view.devicePixelRatio = 1;
    const moments = MascotAnimations.referenceMoments;
    for (final e in moments.entries) {
      final c = MascotController()..debugShow(e.key, e.value, talkMouth: MouthShape.openSmall);
      await _render(tester, c, 'state_${e.key.name}');
    }
    for (final (i, col) in [0xFFFFC83D, 0xFF4D9DE0, 0xFF3BB273, 0xFFFF8A5B, 0xFFB79CED, 0xFFFF9EB5].indexed) {
      final c = MascotController()
        ..freezeAtRest()
        ..setBodyColor(Color(col));
      await _render(tester, c, 'color_$i', height: 340);
    }
    for (final a in MascotAccessory.all) {
      final c = MascotController()
        ..freezeAtRest()
        ..wear(a);
      await _render(tester, c, 'acc_$a', height: 340);
    }
  });
}
