import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/course_models.dart';

/// Rules of play, independent of how rounds look (ported from the prototype):
///
/// * a right answer shows the "correct" celebration, then moves on after
///   [GameTiming.afterCorrect]; the last round finishes the level
/// * a wrong answer counts a mistake, shows the hint, and clears the red
///   state after [GameTiming.afterWrong]
/// * stars by the share of mistakes ([starsFor]): a 5-round level gives 3
///   for none, 2 for 1–2, else 1; longer levels allow more
/// * a level can go on from a saved round ([LevelSession.resumeAt])
abstract final class GameTiming {
  static const afterCorrect = Duration(milliseconds: 1350);
  static const afterWrong = Duration(milliseconds: 1300);
  static const orderSettle = Duration(milliseconds: 250); // last tile -> correct
  static const listening = Duration(milliseconds: 1800); // simulated voice check
  static const matchPeek = Duration(milliseconds: 900); // two cards that are not a pair stay up
}

enum RoundFeedback { none, correct, wrong }

/// Stars for [mistakes] in a level of [rounds] rounds: 3 for up to one
/// mistake in 6 rounds, 2 for up to two in 5, else 1.
int starsFor(int mistakes, {int rounds = 5}) => mistakes <= rounds ~/ 6 ? 3 : (mistakes <= rounds * 2 ~/ 5 ? 2 : 1);

/// Long levels get a cheer halfway through ([SessionState.isHalfway]).
const halfwayFrom = 8;

/// Deterministic tile shuffle (the prototype's perm): same order every time
/// for a given level and round, never the solved order.
List<int> tileOrder({required int level, required int round, required int count}) {
  final seed = level * 13 + round * 7 + 3;
  final a = List<int>.generate(count, (i) => i);
  for (var i = count - 1; i > 0; i--) {
    final j = (seed * (i + 3)) % (i + 1);
    final t = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  var identity = true;
  for (var k = 0; k < count; k++) {
    if (a[k] != k) identity = false;
  }
  return identity && count > 1 ? a.reversed.toList() : a;
}

/// What bubble [index] of a pop round says: the target about every other
/// bubble, never three others in a row and never three targets in a row.
/// The same for a given level and round, so the view and the rules agree.
String popLabel(PopRound r, {required int level, required int round, required int index}) {
  var seed = (level * 31 + round * 17 + 11) & 0x7fffffff;
  int next() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  var others = 0, targets = 0;
  String label = r.target;
  for (var i = 0; i <= index; i++) {
    final roll = next() % 100;
    final target = others >= 2 || (targets < 2 && roll < 48) || r.others.isEmpty;
    if (target) {
      targets++;
      others = 0;
      label = r.target;
    } else {
      others++;
      targets = 0;
      label = r.others[next() % r.others.length];
    }
  }
  return label;
}

@immutable
class SessionState {
  const SessionState({
    required this.level,
    this.round = 0,
    this.mistakes = 0,
    this.feedback = RoundFeedback.none,
    this.hint = false,
    this.wrongOptions = const {},
    this.picked,
    this.placed = const [],
    this.spellFilled = 0,
    this.choices = const {},
    this.paint,
    this.listening = false,
    this.found = const {},
    this.open = const [],
    this.finished = false,
  });

  final CourseLevel level;
  final int round;
  final int mistakes;
  final RoundFeedback feedback;
  final bool hint; // after a mistake: show where the answer is

  // pick
  final Set<int> wrongOptions;
  final int? picked;
  final String? paint; // colour name picked on the paint stage

  // order: tile positions (in shuffled order) placed so far
  final List<int> placed;

  // write / spell: letters filled so far
  final int spellFilled;

  // story choices (choiceKey -> label), kept for the whole level
  final Map<String, String> choices;

  // speak
  final bool listening;

  // hunt: cells found so far; fix: items fixed; sort: items in a bin;
  // match: cards matched; pop: bubbles popped
  final Set<int> found;

  // match: cards turned up and not matched yet (at most two)
  final List<int> open;

  final bool finished;

  Round get current => level.rounds[round];
  int get roundCount => level.rounds.length;
  bool get isLastRound => round == roundCount - 1;
  bool get correct => feedback == RoundFeedback.correct;
  int get stars => starsFor(mistakes, rounds: roundCount);

  /// The first round of the second half of a long level.
  bool get isHalfway => roundCount >= halfwayFrom && round == roundCount ~/ 2;

  List<int> get tiles {
    final r = current;
    return r is OrderRound ? tileOrder(level: level.number, round: round, count: r.tiles.length) : const [];
  }

  /// Match rounds: the card at each position (shuffled, see [MatchRound.side]).
  List<int> get cards {
    final r = current;
    return r is MatchRound ? tileOrder(level: level.number, round: round + 5, count: r.cardCount) : const [];
  }

  SessionState copyWith({
    int? round,
    int? mistakes,
    RoundFeedback? feedback,
    bool? hint,
    Set<int>? wrongOptions,
    int? picked,
    bool clearPicked = false,
    List<int>? placed,
    int? spellFilled,
    Map<String, String>? choices,
    String? paint,
    bool clearPaint = false,
    bool? listening,
    Set<int>? found,
    List<int>? open,
    bool? finished,
  }) =>
      SessionState(
        level: level,
        round: round ?? this.round,
        mistakes: mistakes ?? this.mistakes,
        feedback: feedback ?? this.feedback,
        hint: hint ?? this.hint,
        wrongOptions: wrongOptions ?? this.wrongOptions,
        picked: clearPicked ? null : picked ?? this.picked,
        placed: placed ?? this.placed,
        spellFilled: spellFilled ?? this.spellFilled,
        choices: choices ?? this.choices,
        paint: clearPaint ? null : paint ?? this.paint,
        listening: listening ?? this.listening,
        found: found ?? this.found,
        open: open ?? this.open,
        finished: finished ?? this.finished,
      );
}

/// Result of a submitted drawing (from the writing pad).
enum WritingVerdict { accepted, rejected }

/// One level being played. UI calls the action methods; it watches the
/// state and reacts to changes (mascot, sounds, confetti).
class LevelSession extends Notifier<SessionState> {
  LevelSession(this.level);
  final CourseLevel level;

  Timer? _timer;

  @override
  SessionState build() {
    ref.onDispose(() => _timer?.cancel());
    return SessionState(level: level);
  }

  bool get _locked => state.correct || state.finished;

  // ------------------------------------------------------------ pick
  void pick(int index) {
    final r = state.current;
    if (r is! PickRound || _locked || state.wrongOptions.contains(index)) return;
    final o = r.options[index];
    if (r.isCorrect(o)) {
      final key = r.choiceKey;
      state = state.copyWith(
        picked: index,
        paint: o.color,
        choices: key == null ? null : {...state.choices, key: o.label},
      );
      _correct();
    } else {
      state = state.copyWith(wrongOptions: {...state.wrongOptions, index});
      _wrong();
    }
  }

  // ------------------------------------------------------------ order
  /// [position] = index of the tile as shown (shuffled).
  void placeTile(int position) {
    final r = state.current;
    if (r is! OrderRound || _locked || state.placed.contains(position)) return;
    final tile = state.tiles[position];
    if (tile == state.placed.length) {
      final placed = [...state.placed, position];
      state = state.copyWith(placed: placed);
      if (placed.length == r.tiles.length) _after(GameTiming.orderSettle, _correct);
    } else {
      _wrong();
    }
  }

  // ------------------------------------------------------------ write
  /// The pad judged the drawing ("Done" pressed).
  void submitWriting(WritingVerdict verdict) {
    final r = state.current;
    if (r is! WriteRound || _locked) return;
    if (verdict == WritingVerdict.rejected) {
      _wrong();
      return;
    }
    if (r.mode == WriteMode.spell) {
      final filled = state.spellFilled + 1;
      state = state.copyWith(spellFilled: filled);
      if (filled >= (r.word ?? '').length) _correct();
      return;
    }
    _correct();
  }

  // ------------------------------------------------------------ speak
  /// Mic tapped. Voice checking is simulated like the prototype: listens
  /// for [GameTiming.listening], then accepts.
  void listen() {
    if (state.current is! SpeakRound || _locked || state.listening || state.feedback != RoundFeedback.none) return;
    state = state.copyWith(listening: true);
    _after(GameTiming.listening, () {
      state = state.copyWith(listening: false);
      _correct();
    });
  }

  // ------------------------------------------------------------ hunt
  /// Cell [index] of the hunt grid tapped.
  void tapCell(int index) {
    final r = state.current;
    if (r is! HuntRound || _locked || state.found.contains(index) || state.wrongOptions.contains(index)) return;
    if (r.grid[index] == r.target) {
      final found = {...state.found, index};
      state = state.copyWith(found: found);
      if (found.length >= r.count) _correct();
    } else {
      state = state.copyWith(wrongOptions: {...state.wrongOptions, index});
      _wrong();
    }
  }

  // ------------------------------------------------------------ fix
  /// Item [index] of Pencil's notebook tapped: a wrong one is fixed, a right
  /// one is a mistake.
  void fixItem(int index) {
    final r = state.current;
    if (r is! FixRound || _locked || state.found.contains(index) || state.wrongOptions.contains(index)) return;
    if (r.items[index].wrong != null) {
      final found = {...state.found, index};
      state = state.copyWith(found: found);
      if (found.length >= r.count) _correct();
    } else {
      state = state.copyWith(wrongOptions: {...state.wrongOptions, index});
      _wrong();
    }
  }

  // ------------------------------------------------------------ sort
  /// Item [item] dropped on bin [bin]; true when it goes there (the view
  /// sends a wrong one back).
  bool sortItem(int item, int bin) {
    final r = state.current;
    if (r is! SortRound || _locked || state.found.contains(item)) return false;
    if (r.items[item].bin == bin) {
      final found = {...state.found, item};
      state = state.copyWith(found: found);
      if (found.length >= r.count) _after(GameTiming.orderSettle, _correct);
      return true;
    }
    _wrong();
    return false;
  }

  // ------------------------------------------------------------ match
  /// The card at [position] tapped: turns it up; two up that are a pair
  /// stay up, two that are not turn back down (not a mistake: memory games
  /// are about trying).
  void flipCard(int position) {
    final r = state.current;
    if (r is! MatchRound || _locked || state.open.length >= 2 || state.open.contains(position) || state.found.contains(position)) return;
    if (state.open.isEmpty) {
      state = state.copyWith(open: [position]);
      return;
    }
    final first = state.open.first;
    final cards = state.cards;
    if (cards[first] ~/ 2 == cards[position] ~/ 2) {
      final found = {...state.found, first, position};
      state = state.copyWith(found: found, open: const []);
      if (found.length >= r.cardCount) _after(GameTiming.orderSettle, _correct);
    } else {
      state = state.copyWith(open: [first, position]);
      _after(GameTiming.matchPeek, () => state = state.copyWith(open: const []));
    }
  }

  // ------------------------------------------------------------ pop
  /// Bubble [index] popped (see [popLabel]).
  void popBubble(int index) {
    final r = state.current;
    if (r is! PopRound || _locked || state.found.contains(index) || state.wrongOptions.contains(index)) return;
    if (popLabel(r, level: level.number, round: state.round, index: index) == r.target) {
      final found = {...state.found, index};
      state = state.copyWith(found: found);
      if (found.length >= r.count) _correct();
    } else {
      state = state.copyWith(wrongOptions: {...state.wrongOptions, index});
      _wrong();
    }
  }

  // ------------------------------------------------------------ truth
  /// "True" ([value]) or "silly" tapped.
  void answerTruth(bool value) {
    final r = state.current;
    final index = value ? 0 : 1;
    if (r is! TruthRound || _locked || state.wrongOptions.contains(index)) return;
    if (value == r.answer) {
      state = state.copyWith(picked: index);
      _correct();
    } else {
      state = state.copyWith(wrongOptions: {...state.wrongOptions, index});
      _wrong();
    }
  }

  // ------------------------------------------------------------ resume
  /// Goes on from round [round] with the [mistakes] and story [choices] of
  /// an earlier try (the child left the level part way). Only before the
  /// first answer, and only to a round this level has.
  void resumeAt(int round, {int mistakes = 0, Map<String, String> choices = const {}}) {
    if (state.round != 0 || state.feedback != RoundFeedback.none || state.mistakes > 0) return;
    if (round <= 0 || round >= state.roundCount) return;
    state = SessionState(level: level, round: round, mistakes: mistakes, choices: choices);
  }

  // ------------------------------------------------------------ flow
  void _correct() {
    state = state.copyWith(feedback: RoundFeedback.correct, hint: false);
    _after(GameTiming.afterCorrect, _next);
  }

  void _wrong() {
    state = state.copyWith(feedback: RoundFeedback.wrong, mistakes: state.mistakes + 1, hint: true);
    _after(GameTiming.afterWrong, () {
      if (state.feedback == RoundFeedback.wrong) state = state.copyWith(feedback: RoundFeedback.none);
    });
  }

  void _next() {
    if (state.isLastRound) {
      state = state.copyWith(finished: true);
      return;
    }
    state = SessionState(level: level, round: state.round + 1, mistakes: state.mistakes, choices: state.choices);
  }

  void _after(Duration d, void Function() f) {
    _timer?.cancel();
    _timer = Timer(d, f);
  }
}

final levelSessionProvider = NotifierProvider.autoDispose.family<LevelSession, SessionState, CourseLevel>(LevelSession.new);
