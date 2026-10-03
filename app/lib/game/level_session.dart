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
/// * stars: 0 mistakes = 3, 1–2 = 2, more = 1
abstract final class GameTiming {
  static const afterCorrect = Duration(milliseconds: 1350);
  static const afterWrong = Duration(milliseconds: 1300);
  static const orderSettle = Duration(milliseconds: 250); // last tile -> correct
  static const listening = Duration(milliseconds: 1800); // simulated voice check
}

enum RoundFeedback { none, correct, wrong }

int starsFor(int mistakes) => mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1);

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

  final bool finished;

  Round get current => level.rounds[round];
  int get roundCount => level.rounds.length;
  bool get isLastRound => round == roundCount - 1;
  bool get correct => feedback == RoundFeedback.correct;
  int get stars => starsFor(mistakes);

  List<int> get tiles {
    final r = current;
    return r is OrderRound ? tileOrder(level: level.number, round: round, count: r.tiles.length) : const [];
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
