import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'course_providers.dart';
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
    this.total = 36,
    this.unlockAll = false,
  });

  final String name;
  final BodySwatch color;
  final int stars;
  final Map<int, int> levelStars;
  final String? accessory;

  /// Map levels in the course (the last level's number).
  final int total;

  /// A test account: every level is open.
  final bool unlockAll;

  bool isDone(int n) => levelStars.containsKey(n);
  bool isUnlocked(int n) => unlockAll || n <= 1 || isDone(n - 1) || isDone(n);

  /// First level without stars (the prototype's current()).
  int get current {
    for (var n = 1; n <= total; n++) {
      if (!isDone(n)) return n;
    }
    return total;
  }
}

/// The active child's progress, read from [familyProvider] (the child picked
/// on "Who's playing"). Demo data lives there until accounts and saving exist.
class ProgressNotifier extends Notifier<ChildProgress> {
  @override
  ChildProgress build() {
    final f = ref.watch(familyProvider);
    final r = f.record;
    final levels = ref.watch(courseProvider).value?.levels.length;
    return ChildProgress(
      total: levels == null || levels == 0 ? 36 : levels,
      name: f.active.name,
      color: f.active.swatch,
      stars: r.stars,
      levelStars: r.levelStars,
      accessory: ShopItem.byId(r.wearing)?.accessory,
      unlockAll: f.account?.tester ?? false,
    );
  }

  /// A level was finished (prototype finish()); see [FamilyNotifier.recordResult].
  void recordResult(int level, int stars) => ref.read(familyProvider.notifier).recordResult(level, stars);
}

final progressProvider = NotifierProvider<ProgressNotifier, ChildProgress>(ProgressNotifier.new);
