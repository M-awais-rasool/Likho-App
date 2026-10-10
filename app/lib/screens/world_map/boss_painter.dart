import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../bosses/boss_designs.dart';
import '../../bosses/boss_kit.dart';
import '../../bosses/boss_pose.dart';
import '../../design/tokens.dart';

/// A world boss (lib/bosses), animated like Pencil: asleep it breathes,
/// snores a bubble and floats "z z z"; woken it flutters its eyes, yawns,
/// stretches and hops; awake it blinks, looks around and waves; [dance]
/// hops to the beat with its arms up. The art is 120 x 100.
class BossPainter extends CustomPainter {
  BossPainter({
    required this.world,
    required this.awake,
    required this.time,
    this.dance = false,
    this.wokeAt,
    this.dozing = false,
    this.pokedAt,
    this.danceFor,
  }) : super(repaint: time);

  /// Index into [ids] (see [indexOf]).
  final int world;
  final bool awake;
  final bool dance;
  final ValueListenable<double> time; // seconds

  /// Clock time when the boss woke up: the wake-up plays first.
  final double? wokeAt;

  /// Asleep but peeking now and then (the boss of the child's world).
  final bool dozing;

  /// Clock time of the last tap or won round: a short startled reaction.
  final double? pokedAt;

  /// With [wokeAt] and [dance]: dances this long after waking, then idles.
  final double? danceFor;

  /// Boss ids in drawing order (a world in the course or the admin panel
  /// picks one of these).
  static const ids = ['snail', 'fish', 'bear', 'robotBus', 'cloud', 'moon', 'goat', 'crab', 'ladybug', 'monkey', 'turtle', 'frog', 'dragon', 'penguin'];

  /// Which boss drawing a world's boss id is (unknown ids: the snail).
  static int indexOf(String bossId) => ids.contains(bossId) ? ids.indexOf(bossId) : 0;

  static final Paint _shadow = Paint()..color = BossColors.shadow;

  /// The pose at clock [t].
  static BossPose poseAt(
    int world,
    double t, {
    required bool awake,
    bool dance = false,
    double? wokeAt,
    bool dozing = false,
    double? pokedAt,
    double? danceFor,
  }) {
    final BossPose base;
    if (!awake || (wokeAt != null && t < wokeAt)) {
      base = BossMotion.sample(dozing ? BossMood.dozing : BossMood.asleep, t, seed: world);
    } else if (wokeAt != null && danceFor != null && dance) {
      // wakes, dances for a while, then settles into idling
      final since = t - wokeAt - BossMotion.wakeSeconds;
      final idle = BossMotion.sample(BossMood.awake, t, seed: world);
      final k = ((since - danceFor) / .4).clamp(0.0, 1.0);
      base = k >= 1 ? idle : BossPose.lerp(BossMotion.wakeThen(BossMood.dance, t - wokeAt, t, seed: world), idle, k);
    } else if (wokeAt != null) {
      base = BossMotion.wakeThen(dance ? BossMood.dance : BossMood.awake, t - wokeAt, t, seed: world);
    } else {
      base = BossMotion.sample(dance ? BossMood.dance : BossMood.awake, t, seed: world);
    }
    if (pokedAt == null) return base;
    return BossMotion.poked(base, t - pokedAt, sleeping: !awake, seed: world);
  }

  /// Paints boss [world] in [pose] into [size].
  static void paintPose(Canvas canvas, Size size, int world, BossPose pose, double t) {
    final d = bossDesigns[world.clamp(0, bossDesigns.length - 1)];
    canvas.save();
    canvas.scale(size.width / 120, size.height / 100);
    final hover = d.floats ? 5 + 2.5 * math.sin(t * 2 * math.pi / 2.2) : 0.0;
    final lift = pose.lift + hover;
    final k = 1 - math.min(lift, 26) / 52;
    canvas.drawOval(Rect.fromCenter(center: const Offset(60, 96), width: 84 * k, height: 7 * k), _shadow);
    d.ground(canvas, pose, t);
    canvas.save();
    canvas.translate(60, 94 - lift);
    canvas.rotate(pose.tilt);
    canvas.scale(1 + pose.squash * .8, 1 - pose.squash);
    canvas.translate(-60, -94);
    d.body(canvas, pose, t);
    canvas.restore();
    zzzEffect(canvas, d.zzzAt - Offset(0, lift), t, d.night ? BossColors.zzzNight : BossColors.zzz, pose.zzz);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final pose = poseAt(world, t, awake: awake, dance: dance, wokeAt: wokeAt, dozing: dozing, pokedAt: pokedAt, danceFor: danceFor);
    paintPose(canvas, size, world, pose, t);
  }

  @override
  bool shouldRepaint(BossPainter old) =>
      old.world != world ||
      old.awake != awake ||
      old.dance != dance ||
      old.wokeAt != wokeAt ||
      old.dozing != dozing ||
      old.pokedAt != pokedAt ||
      old.danceFor != danceFor;
}
