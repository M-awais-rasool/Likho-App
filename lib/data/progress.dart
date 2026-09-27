import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';

/// One child's progress. Stars per finished level (1..3).
@immutable
class ChildProgress {
  const ChildProgress({
    required this.name,
    required this.color,
    required this.stars,
    required this.levelStars,
    this.accessory,
  });

  final String name;
  final BodySwatch color;
  final int stars;
  final Map<int, int> levelStars;
  final String? accessory;

  bool isDone(int n) => levelStars.containsKey(n);
  bool isUnlocked(int n) => n <= 1 || isDone(n - 1) || isDone(n);

  /// First level without stars (the prototype's current()).
  int get current {
    for (var n = 1; n <= 36; n++) {
      if (!isDone(n)) return n;
    }
    return 36;
  }
}

/// Demo data until accounts and saving exist: the prototype's first child
/// ("Ayaan", 38 stars, levels 1–7 done). The prototype also puts a beanie on
/// him; the Gemini accessory set has no beanie, so none is worn here.
class ProgressNotifier extends Notifier<ChildProgress> {
  @override
  ChildProgress build() => ChildProgress(
        name: 'Ayaan',
        color: BodySwatch.yellow,
        stars: 38,
        levelStars: const {1: 3, 2: 2, 3: 3, 4: 2, 5: 3, 6: 3, 7: 2},
      );

  /// A level was finished (prototype finish()): keep the best stars; the
  /// child earns the extra stars, plus 2 for a first-time finish.
  void recordResult(int level, int stars) {
    final old = state.levelStars[level];
    final gain = math.max(0, stars - (old ?? 0)) + (old == null ? 2 : 0);
    state = ChildProgress(
      name: state.name,
      color: state.color,
      stars: state.stars + gain,
      levelStars: {...state.levelStars, level: math.max(stars, old ?? 0)},
      accessory: state.accessory,
    );
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ChildProgress>(ProgressNotifier.new);
