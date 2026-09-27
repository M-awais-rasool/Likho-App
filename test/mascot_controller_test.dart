import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/mascot/mascot.dart';
import 'package:likho/mascot/mascot_animations.dart';
import 'package:likho/mascot/mascot_pose.dart';

/// Advances the controller by [seconds] in 60 fps steps.
void run(MascotController c, double seconds, {double start = 0}) {
  final frames = (seconds * 60).round();
  for (var i = 0; i <= frames; i++) {
    c.advance(Duration(microseconds: ((start + i / 60) * 1e6).round()));
  }
}

double poseDistance(MascotPose a, MascotPose b) {
  final d = [
    a.x - b.x, a.y - b.y, (a.rotation - b.rotation) * 100, (a.scaleX - b.scaleX) * 100, (a.scaleY - b.scaleY) * 100,
    a.lean - b.lean, (a.armLeft.raise - b.armLeft.raise) * 50, (a.armRight.raise - b.armRight.raise) * 50,
    a.armLeft.bend - b.armLeft.bend, a.armRight.bend - b.armRight.bend, (a.lid - b.lid) * 20,
  ];
  return d.fold(0.0, (m, v) => v.abs() > m ? v.abs() : m);
}

void main() {
  test('every one-shot returns to idle by itself', () {
    for (final s in MascotState.values.where((s) => !s.loop)) {
      final c = MascotController();
      run(c, 0.2);
      c.play(s);
      expect(c.state, s);
      run(c, s.duration + 0.1, start: 0.2);
      expect(c.state, MascotState.idle, reason: '$s should end in idle');
      expect(s.duration, lessThanOrEqualTo(2.5));
    }
  });

  test('state switches never pop (blend over ~150 ms)', () {
    for (final s in MascotState.values) {
      final c = MascotController();
      run(c, 0.5);
      final before = c.pose;
      c.play(s);
      c.advance(const Duration(microseconds: 516667)); // one frame later
      expect(poseDistance(before, c.pose), lessThan(8), reason: 'jump into $s');
    }
  });

  test('one-shots end on the idle pose (no pop when handing over)', () {
    for (final s in MascotState.values.where((s) => !s.loop)) {
      final end = MascotAnimations.sample(s, s.duration - 1e-4, clock: 10);
      final idle = MascotAnimations.sample(MascotState.idle, 0, clock: 10);
      expect(poseDistance(end, idle), lessThan(0.05), reason: '$s end');
    }
  });

  testWidgets('eyes follow a finger (lookAt) and come back (lookReset)', (tester) async {
    final c = MascotController();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: PencilMascot(controller: c, size: 400)),
    ));
    final box = tester.getRect(find.byType(PencilMascot));
    c.lookAt(Offset(box.right + 300, box.center.dy - 100));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(c.look.dx, greaterThan(0.6));
    expect(c.look.dy, lessThan(0));
    c.lookReset();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(c.look.distance, lessThan(0.05));
  });

  test('setBodyColor uses measured swatches for the six brief colours', () {
    final c = MascotController();
    for (final hex in [0xFFFFC83D, 0xFF4D9DE0, 0xFF3BB273, 0xFFFF8A5B, 0xFFB79CED, 0xFFFF9EB5]) {
      c.setBodyColor(Color(hex));
      expect(c.swatch.key.toARGB32(), hex);
      // outline is always a darker shade of the body colour
      expect(c.swatch.line.computeLuminance(), lessThan(c.swatch.base.computeLuminance()));
    }
    c.setBodyColor(const Color(0xFF00AA88));
    expect(c.swatch.base.toARGB32(), 0xFF00AA88);
    expect(BodySwatch.yellow.base.toARGB32(), 0xFFFEC344);
  });

  test('wear / removeAccessory', () {
    final c = MascotController();
    c.wear(MascotAccessory.cap);
    expect(c.accessory, MascotAccessory.cap);
    c.wear(MascotAccessory.crown);
    expect(c.accessory, MascotAccessory.crown);
    c.removeAccessory();
    expect(c.accessory, isNull);
  });
}
