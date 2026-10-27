import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/likho_api.dart';
import 'app_controls.dart';
import 'family.dart';

/// Games: arcade games that practise what the child has learned (Monster
/// Defense first), opened from the map like Stories. Each child's best
/// score, best stars and number of plays per game are kept on the phone.

/// The games made so far.
abstract final class GameIds {
  static const monsters = 'monsters';
  static const runner = 'runner';
  static const smash = 'smash';
  static const slice = 'slice';
  static const all = [monsters, runner, smash, slice];
}

@immutable
class GameRecord {
  const GameRecord({this.best = 0, this.stars = 0, this.plays = 0, this.levels = const {}});
  final int best, stars, plays;

  /// A game with levels (Monster Smash): the best stars of each level
  /// played to its end (level number -> 1..3).
  final Map<int, int> levels;

  /// Whether level [n] can be played: the first, or the one after a
  /// finished one.
  bool opens(int n) => n <= 1 || (levels[n - 1] ?? 0) > 0;

  Map<String, dynamic> toJson() => {
    'best': best,
    'stars': stars,
    'plays': plays,
    if (levels.isNotEmpty) 'levels': {for (final e in levels.entries) '${e.key}': e.value},
  };

  static GameRecord fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return const GameRecord();
    int n(String k) => j[k] is int ? j[k] as int : 0;
    final l = j['levels'];
    return GameRecord(
      best: n('best'),
      stars: n('stars'),
      plays: n('plays'),
      levels: l is Map<String, dynamic> ? {for (final e in l.entries) if (int.tryParse(e.key) != null && e.value is int) int.parse(e.key): e.value as int} : const {},
    );
  }
}

/// child id -> game id -> record, kept in [file].
class GameProgress extends Notifier<Map<String, Map<String, GameRecord>>> {
  static const file = 'game_progress.json';

  bool _loaded = false, _dirty = false;

  @override
  Map<String, Map<String, GameRecord>> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final text = await ref.read(localFilesProvider).read(file);
    if (!ref.mounted) return;
    _loaded = true;
    try {
      final j = text == null ? null : jsonDecode(text);
      if (j is Map<String, dynamic>) {
        state = {
          for (final e in j.entries)
            if (e.value is Map<String, dynamic>) e.key: {for (final g in (e.value as Map<String, dynamic>).entries) g.key: GameRecord.fromJson(g.value)},
          ...state, // played while loading
        };
      }
    } catch (_) {}
    if (_dirty) _persist();
  }

  /// A game was played to its end: one more play, the better score and
  /// stars kept. True when [score] beats the child's best (not their first
  /// game).
  /// [level]: a game with levels keeps each level's best stars too.
  bool record(String childId, String game, {required int score, required int stars, int? level}) {
    final mine = state[childId] ?? const {};
    final old = mine[game] ?? const GameRecord();
    final next = GameRecord(
      best: score > old.best ? score : old.best,
      stars: stars > old.stars ? stars : old.stars,
      plays: old.plays + 1,
      levels: level == null ? old.levels : {...old.levels, level: math.max(stars, old.levels[level] ?? 0)},
    );
    state = {
      ...state,
      childId: {...mine, game: next},
    };
    _persist();
    return old.plays > 0 && score > old.best;
  }

  void _persist() {
    if (!_loaded) {
      _dirty = true; // written once the file is read (saving now would drop it)
      return;
    }
    ref
        .read(localFilesProvider)
        .write(
          file,
          jsonEncode({
            for (final c in state.entries) c.key: {for (final g in c.value.entries) g.key: g.value.toJson()},
          }),
        );
  }
}

final gameProgressProvider = NotifierProvider<GameProgress, Map<String, Map<String, GameRecord>>>(GameProgress.new);

/// The active child's records per game.
final myGamesProvider = Provider<Map<String, GameRecord>>((ref) {
  final child = ref.watch(familyProvider.select((f) => f.active.id));
  return ref.watch(gameProgressProvider)[child] ?? const {};
});

/// The games the Games screen shows, in the team's order (App controls):
/// each on, or Plus-only while Plus is sold (its card then has a lock).
final shownGamesProvider = Provider<List<String>>((ref) {
  final c = ref.watch(appControlsProvider);
  final plus = ref.watch(familyProvider.select((f) => f.subscribed));
  return [for (final id in AppControls.ordered(GameIds.all, c.playGameOrder)) if (c.playGameShown(id, subscribed: plus)) id];
});

/// Whether Games shows (App controls: on unless the team switched it off,
/// or Plus-only while Plus is sold), with a game to show.
final gamesShownProvider = Provider<bool>((ref) => ref.watch(featureShownProvider(Feature.games)) && ref.watch(shownGamesProvider).isNotEmpty);

/// The games tagged NEW that this child has not played yet (their cards,
/// and the Games tab or button, say NEW).
final newGamesProvider = Provider<Set<String>>((ref) {
  final tagged = ref.watch(appControlsProvider.select((c) => c.newPlayGames));
  final mine = ref.watch(myGamesProvider);
  return {for (final id in ref.watch(shownGamesProvider)) if (tagged.contains(id) && (mine[id]?.plays ?? 0) == 0) id};
});
