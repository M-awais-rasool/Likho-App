import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// What a projectile flying at the boss looks like.
enum ShotKind { star, bell, pillow, bubble, letter, wave, sun }

/// The score of a boss battle, read by the arena's widgets. A boss level's
/// rounds are its "sleep": every round won lands a wake-up hit (when the
/// projectile arrives), rounds won in a row without a mistake build a
/// combo, and the sleep meter is split in three phases. Times are seconds
/// on the screen's clock.
class BossBattle extends ChangeNotifier {
  BossBattle({required this.rounds, int hits = 0}) : _hits = hits.clamp(0, rounds);

  final int rounds;
  int _hits;
  int _combo = 0;

  /// Rounds won, i.e. hits landed.
  int get hits => _hits;

  /// Rounds won in a row without a mistake.
  int get combo => _combo;

  /// Sleep left, 1 (fast asleep) .. 0 (ready to wake).
  double get sleep => rounds == 0 ? 0 : 1 - _hits / rounds;

  /// 0, 1 or 2: asleep, stirring, restless.
  int get phase => phaseFor(_hits);

  int phaseFor(int hits) => rounds == 0 ? 0 : math.min(2, hits * 3 ~/ rounds);

  /// Clock time of the last hit, miss, phase change and wake-up.
  double? hitAt, missAt, phaseAt, wokeAt;

  /// The last hit was a combo hit.
  bool bigHit = false;

  /// Number of the last hit (picks its "BONK!" word).
  int get hitNumber => _hits;

  /// A round was won: [clean] when it had no mistake.
  void won({required bool clean}) {
    _combo = clean ? _combo + 1 : 0;
    notifyListeners();
  }

  /// A wrong answer: the combo breaks and the boss snores at the child.
  void missed(double now) {
    _combo = 0;
    missAt = now;
    notifyListeners();
  }

  /// A wake-up hit lands. Returns true when it starts a new phase.
  bool hit(double now, {required bool big}) {
    final before = phase;
    _hits = math.min(rounds, _hits + 1);
    hitAt = now;
    bigHit = big;
    final next = phase > before;
    if (next) phaseAt = now;
    notifyListeners();
    return next;
  }

  /// A poke without a hit (each ring of the alarm): the boss startles.
  void poke(double now) {
    hitAt = now;
    bigHit = false;
    notifyListeners();
  }

  /// The alarm rang: the boss wakes up.
  void wake(double now) {
    wokeAt = now;
    notifyListeners();
  }
}
