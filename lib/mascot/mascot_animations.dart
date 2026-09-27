import 'dart:math' as math;

import 'package:flutter/animation.dart';

import 'mascot_pose.dart';

/// Inputs that come from outside the timeline (lip-sync).
class TalkInput {
  const TalkInput({this.level = 0, this.mouth = MouthShape.closed});
  final double level; // 0..1 loudness
  final MouthShape mouth;
}

/// Pure functions: state + seconds since the state started -> pose.
/// One-shot states ease back into [idle] during their last [_settle] seconds,
/// so the hand-off to idle never pops.
abstract final class MascotAnimations {
  static const double _settle = 0.25;

  /// The moment of each state that corresponds to its expression-sheet cell
  /// (mascot's/y5imh7…jpeg). Used by the overlay check and render tests.
  static const Map<MascotState, double> referenceMoments = {
    MascotState.idle: 0.0,
    MascotState.talking: 0.4,
    MascotState.watching: 1.0,
    MascotState.happy: 0.42,
    MascotState.encourage: 0.5,
    MascotState.wow: 0.3,
    MascotState.dance: 0.25,
    MascotState.sleepy: 0.9,
  };

  /// [t] = seconds since the state started, [clock] = global seconds (idle
  /// breathes on the global clock so leaving a one-shot never jumps phase).
  static MascotPose sample(MascotState s, double t, {double? clock, TalkInput talk = const TalkInput()}) {
    final c = clock ?? t;
    final pose = switch (s) {
      MascotState.idle => idle(c),
      MascotState.talking => talking(t, talk),
      MascotState.watching => watching(t),
      MascotState.happy => happy(t),
      MascotState.encourage => encourage(t),
      MascotState.wow => wow(t),
      MascotState.dance => dance(t),
      MascotState.sleepy => sleepy(t),
      MascotState.wave => wave(t),
      MascotState.think => think(t),
    };
    if (s.loop) return pose;
    final k = _seg(t, s.duration - _settle, s.duration);
    return k <= 0 ? pose : MascotPose.lerp(pose, idle(c), Curves.easeInOut.transform(k));
  }

  // ------------------------------------------------------------------ idle
  /// Gentle breathing (stretch from the feet), tiny arm sway. Blinks are
  /// layered on by the controller.
  static MascotPose idle(double t) {
    final b = _breath(t, 2.8);
    return MascotPose(
      scaleY: 1 + 0.013 * b,
      scaleX: 1 - 0.006 * b,
      armLeft: ArmPose(raise: 0.035 * _wave(t, 2.8, 0.9), bend: 1.2 * b),
      armRight: ArmPose(raise: 0.035 * _wave(t, 2.8, 1.4), bend: 1.2 * b),
    );
  }

  // ------------------------------------------------------------------ talking
  /// Loop while audio plays: mouth from lip-sync, the right hand gestures.
  static MascotPose talking(double t, TalkInput talk) {
    final b = _breath(t, 2.2);
    final g = _wave(t, 1.3);
    final lvl = talk.level.clamp(0.0, 1.0);
    return MascotPose(
      rotation: 0.03 * _wave(t, 2.6),
      scaleY: 1 + 0.01 * b + 0.018 * lvl,
      scaleX: 1 - 0.005 * b - 0.008 * lvl,
      lookX: 0.35,
      lookY: -0.25,
      browY: -3 - 3 * lvl,
      mouth: talk.mouth,
      mouthScale: 0.94 + 0.12 * lvl,
      blush: 0.2,
      armLeft: ArmPose(raise: 0.05 + 0.03 * _wave(t, 2.2), bend: 1),
      armRight: ArmPose(
        raise: 1.45 + 0.1 * g,
        bend: -26 + 4 * g,
        reach: 0.9,
        handTurn: 0.25 + 0.15 * _wave(t, 1.3, 0.8),
        hand: HandShape.open,
      ),
    );
  }

  // ------------------------------------------------------------------ watching
  /// Loop: leans forward a little, hands together in front, eyes follow the
  /// finger (the look target is applied by the controller).
  static MascotPose watching(double t) {
    final b = _breath(t, 2.6);
    final lean = _ease(Curves.easeOutBack, _seg(t, 0, 0.45));
    return MascotPose(
      lean: -16 * lean,
      rotation: -0.025 * lean,
      scaleY: 1 - 0.025 * lean + 0.01 * b,
      scaleX: 1 + 0.012 * lean,
      faceOffset: 4 * lean,
      browY: -4 * lean,
      mouth: MouthShape.o,
      mouthScale: 0.5,
      armLeft: ArmPose(raise: -1.3 * lean, bend: 28 * lean, reach: 1 - 0.02 * lean, handTurn: -0.9 * lean, hand: HandShape.fist, front: t > 0.08),
      armRight: ArmPose(raise: -1.3 * lean, bend: 28 * lean, reach: 1 - 0.02 * lean, handTurn: -0.9 * lean, hand: HandShape.fist, front: t > 0.08),
    );
  }

  // ------------------------------------------------------------------ happy
  /// 1.2 s: anticipation squash, jump with both arms up, land, settle.
  static MascotPose happy(double t) {
    final up = _ease(Curves.easeOutCubic, _seg(t, 0.12, 0.5));
    final down = _ease(Curves.easeInCubic, _seg(t, 0.5, 0.78));
    final jump = up - down; // 0 -> 1 -> 0
    final squash = _pulse(t, 0.0, 0.06, 0.12) - _pulse(t, 0.12, 0.2, 0.3) * 0.6 + _pulse(t, 0.76, 0.82, 0.95);
    final arms = _ease(Curves.easeOutBack, _seg(t, 0.06, 0.34));
    final air = _pulse(t, 0.14, 0.4, 0.78);
    final wiggle = _wave(t, 0.36) * arms;
    return MascotPose(
      y: -70 * jump,
      scaleY: 1 - 0.1 * squash,
      scaleX: 1 + 0.07 * squash,
      eraserDrop: 5 * _pulse(t, 0.76, 0.84, 1.0) - 4 * air,
      eyes: t < 0.04 ? EyeStyle.normal : EyeStyle.happy,
      mouth: MouthShape.laugh,
      browY: -6 * arms,
      blush: 1,
      armLeft: ArmPose(raise: 1.9 * arms + 0.12 * wiggle, bend: 8 * arms, handTurn: 0.25 * wiggle, hand: HandShape.open),
      armRight: ArmPose(raise: 1.9 * arms - 0.12 * wiggle, bend: 8 * arms, handTurn: -0.25 * wiggle, hand: HandShape.open),
      legLeft: 0.38 * air,
      legRight: 0.38 * air,
    );
  }

  // ------------------------------------------------------------------ encourage
  /// 1.2 s: head tilt, thumbs-up, gentle smile. Never sad.
  static MascotPose encourage(double t) {
    final inn = _ease(Curves.easeOutBack, _seg(t, 0, 0.3));
    final pump = _pulse(t, 0.34, 0.46, 0.6) + 0.6 * _pulse(t, 0.6, 0.7, 0.82);
    return MascotPose(
      rotation: -0.075 * inn,
      y: -4 * pump,
      scaleY: 1 + 0.02 * pump,
      mouth: MouthShape.gentle,
      browY: -4 * inn,
      browTilt: -0.08 * inn,
      blush: 0.6 * inn,
      lookX: -0.12 * inn,
      armLeft: ArmPose(raise: 0.06 * inn, bend: 1),
      armRight: ArmPose(
        raise: 0.95 * inn + 0.06 * pump,
        bend: -6 * inn,
        handTurn: -0.1 * pump,
        hand: t < 0.1 ? HandShape.rest : HandShape.thumbsUp,
      ),
    );
  }

  // ------------------------------------------------------------------ wow
  /// 1.0 s: sparkly big eyes, "O" mouth, small hop.
  static MascotPose wow(double t) {
    final hop = _ease(Curves.easeOutCubic, _seg(t, 0.08, 0.3)) - _ease(Curves.easeInCubic, _seg(t, 0.3, 0.5));
    final squash = _pulse(t, 0.0, 0.04, 0.08) + _pulse(t, 0.48, 0.54, 0.66);
    final open = _ease(Curves.easeOutBack, _seg(t, 0.04, 0.22));
    return MascotPose(
      y: -28 * hop,
      scaleY: 1 - 0.08 * squash + 0.04 * hop,
      scaleX: 1 + 0.05 * squash,
      eraserDrop: 3 * _pulse(t, 0.48, 0.56, 0.7),
      eyes: t < 0.04 ? EyeStyle.normal : EyeStyle.wow,
      eyeScale: 1 + 0.12 * open,
      browY: -12 * open,
      mouth: t < 0.04 ? MouthShape.closed : MouthShape.o,
      mouthScale: 0.7 + 0.3 * open,
      surprise: _pulse(t, 0.06, 0.18, 0.8),
      armLeft: ArmPose(raise: 0.3 * open, bend: 3 * open),
      armRight: ArmPose(raise: 0.3 * open, bend: 3 * open),
      legLeft: -0.08 * hop,
      legRight: -0.08 * hop,
    );
  }

  // ------------------------------------------------------------------ dance
  /// 2.0 s: side-to-side dance, arms waving, kicks on the beat.
  static MascotPose dance(double t) {
    final env = _ease(Curves.easeOut, _seg(t, 0, 0.2));
    final side = _wave(t, 1.0) * env; // two sways in 2 s
    final beat = (1 - math.cos(4 * math.pi * t)) / 2 * env; // 4 bounces
    return MascotPose(
      x: 12 * side,
      y: -9 * beat,
      rotation: 0.11 * side,
      lean: 12 * side,
      scaleY: 1 - 0.04 * (1 - beat) * env + 0.02 * beat,
      eyes: EyeStyle.happy,
      mouth: MouthShape.gentle,
      blush: 0.8 * env,
      motionLines: env,
      armLeft: ArmPose(raise: env * (0.95 + 0.3 * _wave(t, 0.5)), bend: 4 * env, handTurn: 0.3 * _wave(t, 0.5, 1), hand: HandShape.open),
      armRight: ArmPose(raise: env * (2.0 - 0.45 * _wave(t, 0.5)), bend: 6 * env, handTurn: -0.3 * _wave(t, 0.5, 1), hand: HandShape.wave),
      legLeft: 0.5 * math.max(0, side) * env,
      legRight: 0.5 * math.max(0, -side) * env,
    );
  }

  // ------------------------------------------------------------------ sleepy
  /// 2.5 s: eyes half-close, big yawn, eyes close, small zzz.
  static MascotPose sleepy(double t) {
    final droop = _ease(Curves.easeInOut, _seg(t, 0, 0.5));
    final yawn = _pulse(t, 0.4, 0.8, 1.35, Curves.easeOutBack);
    final close = _ease(Curves.easeInOut, _seg(t, 1.3, 1.75));
    final b = _breath(t, 3.2);
    return MascotPose(
      rotation: 0.055 * close,
      scaleY: 1 + 0.05 * yawn + 0.012 * b * close,
      scaleX: 1 - 0.02 * yawn,
      lid: 0.52 * droop + 0.08 * yawn * (1 - close) + (1 - 0.52 * droop) * close,
      lidTilt: 0.14 * droop,
      lookY: 0.6 * droop,
      browY: 3 * droop - 5 * yawn,
      browTilt: 0.14 * droop,
      mouth: t > 0.42 && t < 1.34 ? MouthShape.yawn : MouthShape.closed,
      mouthScale: t > 0.42 && t < 1.34 ? 0.6 + 0.4 * yawn : 1,
      zzz: _ease(Curves.easeOut, _seg(t, 0.6, 1.0)),
      armLeft: ArmPose(raise: 0.12 * yawn, bend: 2 * yawn),
      armRight: ArmPose(raise: 0.12 * yawn, bend: 2 * yawn),
    );
  }

  // ------------------------------------------------------------------ wave
  /// Loop: right arm up, waving between 22° and 65° above horizontal every
  /// 0.6 s (the prototype's mWaveR), idle breathing, smile.
  static MascotPose wave(double t) {
    final b = _breath(t, 2.8);
    final up = _ease(Curves.easeOutBack, _seg(t, 0, 0.3));
    final w = _wave(t, 0.6);
    return MascotPose(
      scaleY: 1 + 0.013 * b,
      scaleX: 1 - 0.006 * b,
      blush: 0.3 * up,
      armLeft: ArmPose(raise: 0.035 * _wave(t, 2.8, 0.9), bend: 1.2 * b),
      armRight: ArmPose(
        raise: up * (1.64 + 0.38 * w),
        bend: 5 * up,
        handTurn: up * (0.1 + 0.2 * w),
        hand: t < 0.06 ? HandShape.rest : HandShape.wave,
      ),
    );
  }

  // ------------------------------------------------------------------ think
  static MascotPose think(double t) {
    final b = _breath(t, 3.0);
    final inn = _ease(Curves.easeOutBack, _seg(t, 0, 0.35));
    return MascotPose(
      rotation: 0.087 * inn,
      scaleY: 1 + 0.012 * b,
      scaleX: 1 - 0.006 * b,
      lookX: -0.75 * inn,
      lookY: -0.85 * inn,
      browY: -4 * inn,
      armLeft: ArmPose(raise: 0.035 * _wave(t, 3.0, 0.9), bend: 1.2 * b),
      armRight: ArmPose(raise: -1.9 * inn, bend: 18 * inn, reach: 1 - .15 * inn, handTurn: -1.2 * inn, hand: HandShape.fist, front: t > .05),
    );
  }

  // ------------------------------------------------------------------ helpers
  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
  static double _ease(Curve c, double x) => c.transform(x.clamp(0.0, 1.0));
  static double _wave(double t, double period, [double phase = 0]) => math.sin(2 * math.pi * t / period + phase);
  static double _breath(double t, double period) => 0.5 - 0.5 * math.cos(2 * math.pi * t / period);

  /// 0 -> 1 between [a] and [peak], back to 0 by [b].
  static double _pulse(double t, double a, double peak, double b, [Curve up = Curves.easeOut]) {
    if (t <= a || t >= b) return 0;
    if (t < peak) return _ease(up, _seg(t, a, peak));
    return 1 - _ease(Curves.easeInOut, _seg(t, peak, b));
  }
}
