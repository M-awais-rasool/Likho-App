import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/course_models.dart';

/// Monster Defense's questions. Pencil asks one (a letter, a small letter,
/// a picture's first letter or a word to read) and the monsters on the path
/// carry the choices. Questions only use what the child has learned
/// ([MdKnowledge]), the newest skill most often; a missed answer comes back
/// a little later.

enum MdSkill { capitals, smalls, firstSound, words }

@immutable
class MdQuestion {
  const MdQuestion({required this.skill, required this.answer, required this.choices, required this.say, required this.audio, this.letter, this.picture});
  final MdSkill skill;

  /// The right choice (one of [choices]).
  final String answer;

  /// What the monsters carry, in the order they come.
  final List<String> choices;

  /// What Pencil says (his bubble) and its recording.
  final String say, audio;

  /// The question card: a big letter (capitals, smalls) ...
  final String? letter;

  /// ... or a picture (`assets/games/words/<word>.webp`).
  final String? picture;

  @override
  String toString() => 'MdQuestion(${skill.name} $answer of $choices)';
}

/// The words the questions use (`assets/games/monster_words.json`): the
/// pictures whose first letter makes its usual sound, and words to read.
@immutable
class MdWords {
  const MdWords({required this.first, required this.read});
  final List<String> first, read;

  static const asset = 'assets/games/monster_words.json';

  factory MdWords.fromJson(Map<String, dynamic> j) => MdWords(first: (j['first'] as List).cast<String>(), read: (j['read'] as List).cast<String>());

  static Future<MdWords> load() async => MdWords.fromJson(jsonDecode(await rootBundle.loadString(asset)) as Map<String, dynamic>);

  static String picture(String word) => 'assets/games/words/$word.webp';
}

/// What the child knows: the capitals and small letters of the levels they
/// finished, and whether they have reached the sounds (first letters) and
/// reading words.
@immutable
class MdKnowledge {
  const MdKnowledge({required this.capitals, required this.smalls, this.firstSound = false, this.words = false});

  /// Learned capitals (at least A–E: a new child starts there).
  final List<String> capitals;

  /// Learned small letters (empty before the small letters world).
  final List<String> smalls;
  final bool firstSound, words;

  static const starters = ['A', 'B', 'C', 'D', 'E'];

  static const beginner = MdKnowledge(capitals: starters, smalls: []);

  /// From the course and the levels the child finished ([done]): a level
  /// teaching "B" gives capital B, "Bb" gives small b; finishing a level in
  /// the 5th world (Phonics Island) or later opens first sounds, two there
  /// open reading words. Small letters open first sounds too once ten are
  /// learned.
  factory MdKnowledge.of(Course? course, Iterable<int> done) {
    if (course == null) return beginner;
    final caps = <String>{...starters}, smalls = <String>{};
    var phonics = 0;
    final order = {for (final w in course.worlds) w.id: w.order};
    for (final n in done) {
      final level = course.levels.where((l) => l.number == n).firstOrNull;
      if (level == null) continue;
      final t = level.intro.text.trim();
      if (RegExp(r'^[A-Z]$').hasMatch(t)) caps.add(t);
      final pair = RegExp(r'^([A-Z])([a-z])$').firstMatch(t);
      if (pair != null && pair.group(1)!.toLowerCase() == pair.group(2)) smalls.add(pair.group(2)!);
      if ((order[level.worldId] ?? 0) >= 5) phonics++;
    }
    return MdKnowledge(capitals: caps.toList()..sort(), smalls: smalls.toList()..sort(), firstSound: phonics >= 1 || smalls.length >= 10, words: phonics >= 2);
  }

  /// The skills to ask, easiest first.
  List<MdSkill> get skills => [MdSkill.capitals, if (smalls.length >= 3) MdSkill.smalls, if (firstSound) MdSkill.firstSound, if (words) MdSkill.words];
}

/// Where questions come from (the game asks for one with [count] choices,
/// and says when an answer was missed).
abstract class MdQuestionSource {
  MdQuestion next(int count);
  void missed(MdQuestion q);
}

/// The questions, made from [knowledge] and [words].
class MdQuestions implements MdQuestionSource {
  MdQuestions(this.knowledge, this.words, {math.Random? random}) : _rnd = random ?? math.Random();

  final MdKnowledge knowledge;
  final MdWords words;
  final math.Random _rnd;

  final List<String> _recent = []; // the last answers (not asked again soon)
  final List<(MdSkill, String, int)> _again = []; // missed: (skill, answer, asks to wait)

  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz';

  /// Capitals that look alike: wrong choices that make the child look.
  static const _likeCaps = {
    'A': 'VHR', 'B': 'DPRE', 'C': 'GOU', 'D': 'BOPQ', 'E': 'FBH', 'F': 'EPT', 'G': 'CQO', 'H': 'NMK', 'I': 'LTJ', //
    'J': 'LIU', 'K': 'XRH', 'L': 'IJT', 'M': 'NWH', 'N': 'MHZ', 'O': 'QCDG', 'P': 'BRDF', 'Q': 'OGC', 'R': 'PBK',
    'S': 'ZCG', 'T': 'IFY', 'U': 'VJC', 'V': 'UWY', 'W': 'MVN', 'X': 'KYZ', 'Y': 'VXT', 'Z': 'NSX',
  };
  static const _likeSmalls = {
    'a': 'oed', 'b': 'dpq', 'c': 'eoa', 'd': 'bqp', 'e': 'cao', 'f': 'tlk', 'g': 'qyp', 'h': 'nbk', 'i': 'ljt', //
    'j': 'igy', 'k': 'hxz', 'l': 'itj', 'm': 'nwh', 'n': 'muh', 'o': 'ace', 'p': 'qbd', 'q': 'pdg', 'r': 'nmt',
    's': 'zca', 't': 'fil', 'u': 'vnw', 'v': 'uwy', 'w': 'vmu', 'x': 'kzy', 'y': 'vgj', 'z': 'sxn',
  };

  /// The skill for the next question: the newest skill half the time, the
  /// others share the rest.
  MdSkill _skill() {
    final s = knowledge.skills;
    if (s.length == 1 || _rnd.nextBool()) return s.last;
    return s[_rnd.nextInt(s.length - 1)];
  }

  @override
  MdQuestion next(int count) {
    for (final a in [..._again]) {
      if (a.$3 <= 0) {
        _again.remove(a);
        return _remember(_make(a.$1, a.$2, count));
      }
    }
    for (var k = 0; k < _again.length; k++) {
      _again[k] = (_again[k].$1, _again[k].$2, _again[k].$3 - 1);
    }
    final skill = _skill();
    final pool = _answers(skill);
    final fresh = pool.where((a) => !_recent.contains(a)).toList();
    final from = fresh.isEmpty ? pool : fresh;
    return _remember(_make(skill, from[_rnd.nextInt(from.length)], count));
  }

  /// [q]'s answer is asked again after two other questions.
  @override
  void missed(MdQuestion q) {
    if (!_again.any((a) => a.$1 == q.skill && a.$2 == q.answer)) _again.add((q.skill, q.answer, 2));
  }

  MdQuestion _remember(MdQuestion q) {
    _recent.add(q.answer);
    if (_recent.length > 3) _recent.removeAt(0);
    return q;
  }

  /// The answers a skill can ask.
  List<String> _answers(MdSkill skill) => switch (skill) {
    MdSkill.capitals => knowledge.capitals,
    MdSkill.smalls => knowledge.smalls,
    MdSkill.firstSound => () {
      // pictures whose first letter the child knows (all of them before the
      // small letters are learned)
      final known = words.first.where((w) => knowledge.smalls.contains(w[0])).toList();
      return known.length >= 4 ? known : words.first;
    }(),
    MdSkill.words => words.read,
  };

  MdQuestion _make(MdSkill skill, String answer, int count) {
    switch (skill) {
      case MdSkill.capitals:
        final choices = _letters(answer, count, _likeCaps[answer] ?? '', upper: true);
        return MdQuestion(skill: skill, answer: answer, choices: choices, say: 'Find $answer!', audio: _voice('md_find_${answer.toLowerCase()}'), letter: answer);
      case MdSkill.smalls:
        final choices = _letters(answer, count, _likeSmalls[answer] ?? '', upper: false);
        return MdQuestion(skill: skill, answer: answer, choices: choices, say: 'Find small $answer!', audio: _voice('md_small_$answer'), letter: answer.toUpperCase());
      case MdSkill.firstSound:
        final first = answer[0];
        // c and k sound the same at the start: never both
        final avoid = {first, if (first == 'c') 'k', if (first == 'k') 'c'};
        final others = [
          for (final l in _alphabet.split(''))
            if (!avoid.contains(l) && l != 'x') l,
        ]..shuffle(_rnd);
        final known = others.where(knowledge.smalls.contains).toList();
        final wrong = [...known, ...others.where((l) => !known.contains(l))].take(count - 1);
        final choices = [first, ...wrong]..shuffle(_rnd);
        return MdQuestion(
          skill: skill,
          answer: first,
          choices: choices,
          say: '${answer[0].toUpperCase()}${answer.substring(1)}! Which letter does it start with?',
          audio: _voice('md_first_$answer'),
          picture: MdWords.picture(answer),
        );
      case MdSkill.words:
        final choices = [answer, ..._wordsLike(answer, count - 1)]..shuffle(_rnd);
        return MdQuestion(skill: skill, answer: answer, choices: choices, say: 'Find the word $answer!', audio: _voice('md_word_$answer'), picture: MdWords.picture(answer));
    }
  }

  static String _voice(String id) => 'assets/voice/$id.m4a';

  /// [answer] and [count]-1 other letters: half of them look like it.
  List<String> _letters(String answer, int count, String like, {required bool upper}) {
    final similar = like.split('').where((l) => l.isNotEmpty).toList()..shuffle(_rnd);
    final rest = [for (final l in _alphabet.split('')) upper ? l.toUpperCase() : l]
      ..removeWhere((l) => l == answer || similar.contains(l))
      ..shuffle(_rnd);
    final wrong = <String>[];
    while (wrong.length < count - 1) {
      final useLike = similar.isNotEmpty && (wrong.isEmpty || _rnd.nextBool() || rest.isEmpty);
      wrong.add(useLike ? similar.removeAt(0) : rest.removeAt(0));
    }
    return [answer, ...wrong]..shuffle(_rnd);
  }

  /// [n] words that look like [word]: the same length, rhyming or starting
  /// the same first, so the child has to read it.
  List<String> _wordsLike(String word, int n) {
    final same = words.read.where((w) => w != word && w.length == word.length).toList()..shuffle(_rnd);
    final close = same.where((w) => w.substring(1) == word.substring(1) || w[0] == word[0] || w[w.length - 1] == word[word.length - 1]).toList();
    final out = <String>[...close.take(n)];
    for (final w in [...same, ...words.read.where((w) => w != word)]) {
      if (out.length >= n) break;
      if (!out.contains(w)) out.add(w);
    }
    return out;
  }
}
