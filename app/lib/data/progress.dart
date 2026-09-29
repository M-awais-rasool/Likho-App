import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'family.dart';
import 'shop_items.dart';

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

/// The active child's progress, read from [familyProvider] (the child picked
/// on "Who's playing"). Demo data lives there until accounts and saving exist.
class ProgressNotifier extends Notifier<ChildProgress> {
  @override
  ChildProgress build() {
    final f = ref.watch(familyProvider);
    final r = f.record;
    return ChildProgress(
      name: f.active.name,
      color: f.active.swatch,
      stars: r.stars,
      levelStars: r.levelStars,
      accessory: ShopItem.byId(r.wearing)?.accessory,
    );
  }

  /// A level was finished (prototype finish()); see [FamilyNotifier.recordResult].
  void recordResult(int level, int stars) => ref.read(familyProvider.notifier).recordResult(level, stars);
}

final progressProvider = NotifierProvider<ProgressNotifier, ChildProgress>(ProgressNotifier.new);
