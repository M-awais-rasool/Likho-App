import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/likho_api.dart';
import 'family.dart';
import 'models/course_models.dart';

/// Stories: one letter an episode, a little story in a real place with
/// people the child helps (story A: Dada's apple garden). An episode's
/// words are in `assets/stories/<id>/story.json` with its art; the voice
/// tool records every line into the app (`assets/voice/story_<id>_<line>`),
/// so stories play offline.

/// Something said in a story by [who] (`pencil` or a character id). The
/// bubble shows [shown]; [text] may give a sound ({a|ˈæː}).
@immutable
class StoryLine {
  const StoryLine({required this.id, required this.who, required this.text, required this.episode});
  final String id, who, text, episode;

  String get shown => spokenText(text);
  String get audio => 'assets/voice/story_${episode}_$id.m4a';
  Prompt get prompt => Prompt(text: text, audio: audio);
}

@immutable
class StoryEpisode {
  const StoryEpisode({required this.id, required this.letter, required this.title, required this.names, required this.lines});
  final String id, letter, title;

  /// Character id -> the name shown over their bubble.
  final Map<String, String> names;
  final Map<String, StoryLine> lines;

  StoryLine line(String id) => lines[id] ?? (throw ArgumentError('Story $this has no line "$id"'));

  static String asset(String id) => 'assets/stories/$id/story.json';

  factory StoryEpisode.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    return StoryEpisode(
      id: id,
      letter: j['letter'] as String,
      title: j['title'] as String,
      names: {for (final e in (j['characters'] as Map<String, dynamic>).entries) e.key: (e.value as Map)['name'] as String},
      lines: {
        for (final l in (j['lines'] as List).cast<Map<String, dynamic>>())
          l['id'] as String: StoryLine(id: l['id'] as String, who: l['who'] as String, text: l['text'] as String, episode: id),
      },
    );
  }

  @override
  String toString() => 'StoryEpisode($id)';
}

/// The episodes made so far, in alphabet order (the rest of A–Z are coming).
const storyEpisodes = ['a'];

/// An episode's words, read from the app.
final storyProvider = FutureProvider.family<StoryEpisode, String>((ref, id) async {
  final text = await rootBundle.loadString(StoryEpisode.asset(id));
  return StoryEpisode.fromJson(jsonDecode(text) as Map<String, dynamic>);
});

/// Stars for a played story: 3 with at most two mistakes, 2 with up to
/// five, else 1 (stories are long and every mistake is gentle).
int storyStars(int mistakes) => mistakes <= 2 ? 3 : (mistakes <= 5 ? 2 : 1);

/// Each child's stories: the best stars of every episode played (child id
/// -> episode -> stars), kept on the phone ([file]).
class StoryProgress extends Notifier<Map<String, Map<String, int>>> {
  static const file = 'story_progress.json';

  bool _loaded = false, _dirty = false;

  @override
  Map<String, Map<String, int>> build() {
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
            if (e.value is Map<String, dynamic>) e.key: {for (final s in (e.value as Map<String, dynamic>).entries) if (s.value is int) s.key: s.value as int},
          ...state, // played while loading
        };
      }
    } catch (_) {}
    if (_dirty) _persist();
  }

  /// Keeps the better of the old and new stars.
  void record(String childId, String episode, int stars) {
    final mine = state[childId] ?? const {};
    if ((mine[episode] ?? 0) >= stars) return;
    state = {...state, childId: {...mine, episode: stars}};
    _persist();
  }

  void _persist() {
    if (!_loaded) {
      _dirty = true; // written once the file is read (saving now would drop it)
      return;
    }
    ref.read(localFilesProvider).write(file, jsonEncode(state));
  }
}

final storyProgressProvider = NotifierProvider<StoryProgress, Map<String, Map<String, int>>>(StoryProgress.new);

/// The active child's stars per story episode.
final myStoryStarsProvider = Provider<Map<String, int>>((ref) {
  final child = ref.watch(familyProvider.select((f) => f.active.id));
  return ref.watch(storyProgressProvider)[child] ?? const {};
});
