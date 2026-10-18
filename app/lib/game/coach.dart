import 'package:flutter/foundation.dart';

import '../data/models/course_models.dart';
import 'level_session.dart';

/// Pencil's step-by-step coaching lines, recorded with the course voice and
/// kept in the app (`tools/voice/generate_voice.py --app`, the coach_ lines
/// in APP_LINES). [words] is what each one says, word for word: his bubble
/// shows it while he says it.
abstract final class CoachLines {
  static const _dir = 'assets/voice';

  static const pick = '$_dir/coach_pick.m4a';
  static const pickChoose = '$_dir/coach_pick_choose.m4a';
  static const hunt = '$_dir/coach_hunt.m4a';
  static const pop = '$_dir/coach_pop.m4a';
  static const fix = '$_dir/coach_fix.m4a';
  static const feed = '$_dir/coach_feed.m4a';
  static const feedBoss = '$_dir/coach_feed_boss.m4a';
  static const baskets = '$_dir/coach_baskets.m4a';
  static const basketsBoss = '$_dir/coach_baskets_boss.m4a';
  static const match = '$_dir/coach_match.m4a';
  static const order = '$_dir/coach_order.m4a';
  static const truth = '$_dir/coach_truth.m4a';
  static const truthBoss = '$_dir/coach_truth_boss.m4a';
  static const connect = '$_dir/coach_connect.m4a';
  static const soundsTap = '$_dir/coach_sounds_tap.m4a';
  static const soundsSlide = '$_dir/coach_sounds_slide.m4a';
  static const soundsPick = '$_dir/coach_sounds_pick.m4a';
  static const trace = '$_dir/coach_trace.m4a';
  static const write = '$_dir/coach_write.m4a';
  static const flash = '$_dir/coach_flash.m4a';
  static const oneMore = '$_dir/coach_one_more.m4a';
  static const startDot = '$_dir/coach_start_dot.m4a';
  static const followArrow = '$_dir/coach_follow_arrow.m4a';
  static const stayOnLine = '$_dir/coach_stay_on_line.m4a';

  /// What each line says (the same words as in APP_LINES).
  static const words = {
    pick: 'Tap the right one!',
    pickChoose: 'Tap the one you like!',
    hunt: 'Tap every one you can find!',
    pop: 'Pop the right bubbles!',
    fix: 'Tap the ones that are wrong!',
    feed: 'Drag the right pictures to the monster!',
    feedBoss: 'Tap the snacks the boss can eat!',
    baskets: 'Drag each picture to the right basket!',
    basketsBoss: 'Tap the right pile for each one!',
    match: 'Tap two cards to find a pair!',
    order: 'Tap them in the right order!',
    truth: 'Is it true? Tap thumbs up. Is it silly? Tap thumbs down.',
    truthBoss: 'Is it true? Tap the sun. Is it silly? Tap the moon.',
    connect: 'Tap the dots in A B C order!',
    soundsTap: 'Tap each dot under the word!',
    soundsSlide: 'Now slide the arrow to read the word!',
    soundsPick: 'Which picture is it? Tap it!',
    trace: 'Start at the blue dot. Follow the arrow!',
    write: 'Write it on the lines. Then tap Done!',
    flash: 'Look at it. It will hide. Then write it!',
    oneMore: 'Just one more!',
    startDot: 'Start at the blue dot!',
    followArrow: 'Follow the arrow!',
    stayOnLine: 'Stay on the line!',
  };

  static List<String> get all => words.keys.toList();

  /// [line] as something Pencil says.
  static Prompt prompt(String line) => Prompt(text: words[line] ?? '', audio: line);
}

/// What Pencil tells the child to do now. A step with a [line] shows that
/// line's words, the same words he says; a step without one is a short
/// count of what is left ("2 more to go!"), shown, not said. [key] names the
/// step: a new key is a new step. When [sayNow] the line is said as the step
/// begins; otherwise it is the "how to play" line said after the round's
/// prompt (the first time a game comes up in a level) and when the child
/// waits.
@immutable
class CoachStep {
  const CoachStep(this.key, {this.line, this.note, this.sayNow = false});
  final String key;
  final String? line;

  /// The text of a step without a line (a count of what is left).
  final String? note;
  final bool sayNow;

  /// What the bubble shows.
  String get text => note ?? CoachLines.words[line] ?? '';

  @override
  bool operator ==(Object other) => other is CoachStep && other.key == key && other.text == text && other.line == line && other.sayNow == sayNow;

  @override
  int get hashCode => Object.hash(key, text, line, sayNow);

  @override
  String toString() => 'CoachStep($key, "$text")';
}

/// The step for [s] (null when there is nothing to tell: the round is won,
/// or a writing pad with a guide, whose strokes Pencil explains himself).
/// [boss]: the round plays as a boss game. [guided]: the writing pad shows
/// guide strokes.
CoachStep? coachStep(SessionState s, {bool boss = false, bool guided = false}) {
  if (s.correct || s.finished) return null;
  final r = s.current;
  CoachStep left(String game, int n) =>
      n == 1 ? CoachStep('$game-1', line: CoachLines.oneMore) : CoachStep('$game-$n', note: '$n more to go!');
  switch (r) {
    case PickRound():
      return CoachStep('pick', line: r.answer == null ? CoachLines.pickChoose : CoachLines.pick);
    case HuntRound():
      return s.found.isEmpty ? const CoachStep('hunt', line: CoachLines.hunt) : left('hunt', r.count - s.found.length);
    case PopRound():
      return s.found.isEmpty ? const CoachStep('pop', line: CoachLines.pop) : left('pop', r.count - s.found.length);
    case FixRound():
      return s.found.isEmpty ? const CoachStep('fix', line: CoachLines.fix) : left('fix', r.count - s.found.length);
    case SortRound():
      if (s.found.isNotEmpty) return left('sort', r.count - s.found.length);
      final monster = r.bins.length == 1;
      return CoachStep('sort', line: monster ? (boss ? CoachLines.feedBoss : CoachLines.feed) : (boss ? CoachLines.basketsBoss : CoachLines.baskets));
    case MatchRound():
      final pairs = (r.cardCount - s.found.length) ~/ 2;
      if (s.open.length == 1) return const CoachStep('match-open', note: 'Now find its partner!');
      if (s.found.isEmpty) return const CoachStep('match', line: CoachLines.match);
      return CoachStep('match-$pairs', note: pairs == 1 ? 'One pair left!' : '$pairs pairs left!');
    case OrderRound():
      return s.placed.isEmpty ? const CoachStep('order', line: CoachLines.order) : left('order', r.tiles.length - s.placed.length);
    case TruthRound():
      return CoachStep('truth', line: boss ? CoachLines.truthBoss : CoachLines.truth);
    case ConnectRound():
      final next = s.found.length;
      if (next >= r.labels.length) return null;
      if (next == 0) return const CoachStep('connect', line: CoachLines.connect);
      return CoachStep('connect-$next', note: 'Now tap ${r.labels[next]}!');
    case SoundsRound():
      if (s.blended) return const CoachStep('sounds-pick', line: CoachLines.soundsPick, sayNow: true);
      if (s.found.length >= r.parts.length) return const CoachStep('sounds-slide', line: CoachLines.soundsSlide, sayNow: true);
      if (s.found.isEmpty) return const CoachStep('sounds', line: CoachLines.soundsTap);
      return const CoachStep('sounds-next', note: 'Now tap the next dot!');
    case WriteRound():
      if (guided) return null;
      return switch (r.mode) {
        WriteMode.flash => const CoachStep('write-flash', line: CoachLines.flash),
        WriteMode.trace || WriteMode.dots => const CoachStep('write-trace', line: CoachLines.trace),
        _ => const CoachStep('write', line: CoachLines.write),
      };
    case BeatsRound():
      // no longer in the course (removed on 2026-10-18); an old copy still plays
      return const CoachStep('beats', note: 'Tap the drum, then tap Done!');
    case UnknownRound():
      return null;
  }
}
