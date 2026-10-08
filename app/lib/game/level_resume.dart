import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/likho_api.dart';
import '../data/models/course_models.dart';

/// Where a child left a level part way: the next round to play, the
/// mistakes so far and the story choices made. Levels are 12–15 rounds, so
/// leaving one (the session timer, a phone call) must not lose the work.
@immutable
class ResumePoint {
  const ResumePoint({required this.round, required this.mistakes, required this.rounds, required this.savedAt, this.choices = const {}});

  final int round, mistakes;

  /// The level's round count when saved: a level whose rounds changed
  /// since starts again.
  final int rounds;
  final DateTime savedAt;
  final Map<String, String> choices;

  Map<String, dynamic> toJson() => {
    'round': round,
    'mistakes': mistakes,
    'rounds': rounds,
    'savedAt': savedAt.toUtc().toIso8601String(),
    if (choices.isNotEmpty) 'choices': choices,
  };

  static ResumePoint? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final round = j['round'], mistakes = j['mistakes'], rounds = j['rounds'], at = DateTime.tryParse('${j['savedAt']}');
    if (round is! int || mistakes is! int || rounds is! int || at == null) return null;
    final c = j['choices'];
    return ResumePoint(
      round: round,
      mistakes: mistakes,
      rounds: rounds,
      savedAt: at,
      choices: c is Map<String, dynamic> ? {for (final e in c.entries) if (e.value is String) e.key: e.value as String} : const {},
    );
  }
}

/// Resume points by child and level, kept on the phone ([file]).
class LevelResume extends Notifier<Map<String, ResumePoint>> {
  static const file = 'level_resume.json';

  /// A resume point older than this is dropped: the child starts again.
  static const keepFor = Duration(days: 7);

  static String keyOf(String childId, CourseLevel level) => '$childId/${level.id}';

  bool _loaded = false, _dirty = false;

  @override
  Map<String, ResumePoint> build() {
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
        final now = DateTime.now();
        state = {
          for (final e in j.entries)
            if (ResumePoint.fromJson(e.value) case final p? when now.difference(p.savedAt) < keepFor) e.key: p,
          ...state, // saved while loading
        };
      }
    } catch (_) {}
    if (_dirty) _persist();
  }

  /// Where [childId] left [level], if they can go on from there.
  ResumePoint? pointFor(String childId, CourseLevel level) {
    final p = state[keyOf(childId, level)];
    if (p == null || p.rounds != level.rounds.length || p.round <= 0 || p.round >= p.rounds) return null;
    return DateTime.now().difference(p.savedAt) < keepFor ? p : null;
  }

  void save(String childId, CourseLevel level, {required int round, required int mistakes, Map<String, String> choices = const {}}) {
    state = {
      ...state,
      keyOf(childId, level): ResumePoint(round: round, mistakes: mistakes, rounds: level.rounds.length, savedAt: DateTime.now(), choices: choices),
    };
    _persist();
  }

  void clear(String childId, CourseLevel level) {
    if (!state.containsKey(keyOf(childId, level))) return;
    state = {...state}..remove(keyOf(childId, level));
    _persist();
  }

  void _persist() {
    if (!_loaded) {
      _dirty = true; // written once the file is read (saving now would drop it)
      return;
    }
    ref.read(localFilesProvider).write(file, jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}));
  }
}

final levelResumeProvider = NotifierProvider<LevelResume, Map<String, ResumePoint>>(LevelResume.new);
