import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/bosses/boss_designs.dart';
import 'package:likho/bosses/boss_pose.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/common/clock.dart';
import 'package:likho/screens/world_map/boss_painter.dart';

void main() {
  test('every boss id has a drawing, unknown ids fall back to the snail', () {
    expect(bossDesigns.length, BossPainter.ids.length);
    for (final (i, id) in BossPainter.ids.indexed) {
      expect(BossPainter.indexOf(id), i);
    }
    expect(BossPainter.indexOf('unicorn'), 0);
  });

  test('every boss paints in every mood', () {
    for (var b = 0; b < bossDesigns.length; b++) {
      for (final t in [0.0, .3, .9, 1.4, 1.8, 2.5, 7.1]) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (final p in [
          BossPainter.poseAt(b, t, awake: false),
          BossPainter.poseAt(b, t, awake: true),
          BossPainter.poseAt(b, t, awake: true, dance: true),
          BossPainter.poseAt(b, t, awake: true, dance: true, wokeAt: 0),
        ]) {
          BossPainter.paintPose(c, const Size(120, 100), b, p, t);
        }
        rec.endRecording().dispose();
      }
    }
  });

  test('asleep: eyes shut and z z z; after the wake-up it dances', () {
    final asleep = BossMotion.sample(BossMood.asleep, 1);
    expect(asleep.eyes, BossEyes.closed);
    expect(asleep.zzz, 1);
    expect(BossMotion.waking(.9, 0).mouth, BossMouth.yawn);
    final after = BossMotion.wakeThen(BossMood.dance, BossMotion.wakeSeconds + .1, 5);
    expect(after.mouth, BossMouth.laugh);
    expect(after.zzz, 0);
  });

  test('awake bosses blink now and then', () {
    var shut = 0;
    for (var t = 0.0; t < 20; t += .02) {
      if (BossMotion.blink(t, 3) > .9) shut++;
    }
    expect(shut, greaterThan(3));
    expect(shut, lessThan(60));
  });

  test('fourteen world themes, two of them at night, each in its own colour', () {
    expect(LikhoWorlds.all.length, LikhoWorlds.ids.length);
    expect(LikhoWorlds.all.where((t) => t.dark).length, 2);
    expect({for (final t in LikhoWorlds.all) t.accent}.length, LikhoWorlds.all.length, reason: 'every world has its own colour');
  });

  testWidgets('BossFigure plays the wake-up when it wakes', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: Center(child: BossFigure(world: 3, awake: false))));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: Center(child: BossFigure(world: 3, awake: true, dance: true))));
    final painter = tester.widget<CustomPaint>(find.descendant(of: find.byType(BossFigure), matching: find.byType(CustomPaint))).painter! as BossPainter;
    expect(painter.wokeAt, isNotNull);
    await tester.pump(const Duration(seconds: 3));
  });
}
