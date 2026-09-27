import 'dart:async';

import 'package:flutter/services.dart';

/// The Likho haptic vocabulary. Strength follows importance: frequent
/// actions get the lightest tick, answers a clear confirmation, big moments
/// a short rhythm that lands with the animation and the sound.
enum HapticCue {
  /// Choosing something (option, colour, age, plan, toggle, page).
  select,

  /// A primary button press.
  press,

  /// A small physical event: a tile placed, a letter accepted, paint.
  tick,

  /// Right answer.
  success,

  /// Wrong answer: two soft nudges, never the harsh error buzz.
  gentleError,

  /// Not allowed right now (not enough stars, wrong parent-gate answer).
  nope,

  /// Something lands (Pencil on the splash, a star, a sticker).
  land,

  /// The last star of a perfect score lands.
  landBig,

  /// Level complete "ta-da".
  celebrate,

  /// Confetti poppers: a quick patter.
  confetti,

  /// Stars spent / coin collected: a rising ripple.
  reward,

  /// A boss wakes up / a world is finished.
  bossWake,

  /// Course complete, certificate.
  milestone,

  /// Unlocked (parent gate passed, trial started).
  unlock,
}

enum _H { light, medium, heavy, selection, success }

/// Plays [HapticCue]s. The app uses [SystemHaptics]; tests get the silent
/// default (see hapticsProvider).
abstract class HapticsEngine {
  void play(HapticCue cue);
}

class SilentHaptics implements HapticsEngine {
  const SilentHaptics();
  @override
  void play(HapticCue cue) {}
}

/// Built from the platform's own feedback types (iOS feedback generators,
/// Android HapticFeedbackConstants), which feel crisp on every device;
/// longer cues are short rhythms of them. No raw vibration: it buzzes.
class SystemHaptics implements HapticsEngine {
  const SystemHaptics();

  static const Map<HapticCue, List<(int, _H)>> patterns = {
    HapticCue.select: [(0, _H.selection)],
    HapticCue.press: [(0, _H.light)],
    HapticCue.tick: [(0, _H.light)],
    HapticCue.success: [(0, _H.success)],
    HapticCue.gentleError: [(0, _H.light), (110, _H.light)],
    HapticCue.nope: [(0, _H.light)],
    HapticCue.land: [(0, _H.medium)],
    HapticCue.landBig: [(0, _H.heavy)],
    HapticCue.celebrate: [(0, _H.success), (130, _H.light)],
    HapticCue.confetti: [(0, _H.light), (70, _H.light), (160, _H.light), (240, _H.medium)],
    HapticCue.reward: [(0, _H.light), (80, _H.light), (170, _H.medium)],
    HapticCue.bossWake: [(0, _H.heavy), (260, _H.light), (360, _H.light)],
    HapticCue.milestone: [(0, _H.heavy), (110, _H.medium), (330, _H.light), (440, _H.light), (550, _H.medium)],
    HapticCue.unlock: [(0, _H.medium)],
  };

  @override
  void play(HapticCue cue) {
    for (final (ms, h) in patterns[cue]!) {
      if (ms == 0) {
        _fire(h);
      } else {
        Timer(Duration(milliseconds: ms), () => _fire(h));
      }
    }
  }

  static void _fire(_H h) {
    final f = switch (h) {
      _H.light => HapticFeedback.lightImpact(),
      _H.medium => HapticFeedback.mediumImpact(),
      _H.heavy => HapticFeedback.heavyImpact(),
      _H.selection => HapticFeedback.selectionClick(),
      _H.success => HapticFeedback.successNotification(),
    };
    unawaited(f.catchError((Object _) {}));
  }
}
