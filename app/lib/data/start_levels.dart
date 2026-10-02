import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/likho_api.dart';
import 'course_providers.dart';
import 'grades.dart';
import 'models/course_models.dart';

/// Where the warm-up suggested a child start when that is below their
/// class (letters were hard for a Class 1 child: "Small Letter Cove se
/// shuru karte hain"), by child id. The map's current level starts there
/// until the child has played past it. Kept on the phone
/// ([file], per course).
class StartLevels extends Notifier<Map<String, int>> {
  static const file = 'start_levels.json';

  @override
  Map<String, int> build() {
    Future.microtask(_load);
    return const {};
  }

  static String _key(String childId) => '$appCourseId/$childId';

  /// Where a child in class [grade] starts after the warm-up, when that is
  /// below their class: the warm-up checks letters, so a child above the
  /// course's first class who found it hard ([stars] 1 = three or more
  /// mistakes) starts at its last letters world (Small Letter Cove) as
  /// revision. Null otherwise.
  static CourseWorld? afterWarmUp(Course course, Grade grade, int stars) {
    if (stars > 1 || course.worlds.isEmpty) return null;
    final letters = course.worlds.first.grade;
    if (letters == null || grade.index <= letters.index) return null;
    return course.worldsOf(letters).last;
  }

  /// Where child [childId] starts in [state], or null for their class's start.
  static int? lookup(Map<String, int> state, String childId) => state[_key(childId)];

  /// Sets (or with null forgets) where child [childId] starts.
  void set(String childId, int? level) {
    final k = _key(childId);
    if (state[k] == level) return;
    state = {...state}..remove(k);
    if (level != null) state = {...state, k: level};
    unawaited(ref.read(localFilesProvider).write(file, jsonEncode(state)));
  }

  Future<void> _load() async {
    final text = await ref.read(localFilesProvider).read(file);
    if (text == null || !ref.mounted) return;
    try {
      final saved = (jsonDecode(text) as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));
      state = {...saved, ...state}; // a change made while loading wins
    } catch (e) {
      debugPrint('start levels: $e');
    }
  }
}

final startLevelsProvider = NotifierProvider<StartLevels, Map<String, int>>(StartLevels.new);
