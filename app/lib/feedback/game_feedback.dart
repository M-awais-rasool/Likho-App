import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/course_models.dart';
import '../game/level_session.dart';
import 'app_feedback.dart';

/// Sounds and haptics of a level being played, driven by the level's rules
/// ([levelSessionProvider]) so the gameplay screen itself stays untouched:
///
/// * right answer: a chime that climbs one note per answer in a row
///   (resets after a mistake), + a pop on balloon levels
/// * wrong answer: the friendly "not yet"
/// * each tile placed / letter spelled: a kalimba step, rising
/// * each letter found in a hunt, fixed in Pencil's notebook, sorted or
///   matched: a kalimba step, rising; each bubble popped: a pop
/// * mic opens: a "ready" blip; next round: a paper swish (also halfway
///   through a long level: Pencil cheers on screen, but no fanfare, so it
///   never sounds like the level is over)
/// * (boss levels: the battle plays its own hits and the wake-up, see
///   GameplayScreen's boss battle)
/// * writing: a soft pencil-on-paper texture while the finger moves
class GameFeedback extends ConsumerStatefulWidget {
  const GameFeedback({super.key, required this.level, required this.child});
  final CourseLevel level;
  final Widget child;

  @override
  ConsumerState<GameFeedback> createState() => _GameFeedbackState();
}

class _GameFeedbackState extends ConsumerState<GameFeedback> {
  late final AppFeedback _fb = ref.read(feedbackProvider);
  int _streak = 0;
  int? _pointer;
  Offset _down = Offset.zero;
  bool _writing = false;

  @override
  void dispose() {
    if (_writing) _fb.stopWriting();
    super.dispose();
  }

  void _onSession(SessionState? prev, SessionState next) {
    if (prev == null) return;
    if (next.round != prev.round) {
      _fb.roundNext();
      return;
    }
    if (next.mistakes > prev.mistakes) {
      _streak = 0;
      _fb.wrong();
    }
    if (next.placed.length > prev.placed.length) _fb.step(next.placed.length);
    if (next.found.length > prev.found.length) {
      if (next.current is PopRound) {
        _fb.pop();
      } else if (!next.correct) {
        _fb.step(next.found.length);
      }
    }
    if (next.spellFilled > prev.spellFilled && !next.correct) _fb.step(next.spellFilled);
    if (next.listening && !prev.listening) _fb.listen();
    if (next.correct && !prev.correct) {
      _streak++;
      final r = next.current;
      _fb.correct(streak: _streak, balloon: r is PickRound && (r.shape ?? widget.level.presentation.shape) == 'balloon');
    }
  }

  bool get _writeRound => ref.read(levelSessionProvider(widget.level)).current is WriteRound;

  void _pointerDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _down = e.position;
  }

  void _pointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _writing) return;
    if ((e.position - _down).distance > 6 && _writeRound) {
      _writing = true;
      _fb.startWriting();
    }
  }

  void _pointerUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_writing) {
      _writing = false;
      _fb.stopWriting();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(levelSessionProvider(widget.level), _onSession);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerUp,
      child: widget.child,
    );
  }
}

/// Level intro: a sparkle as the big letters pop (bigPop peaks at ~.36 s;
/// the "let's go" whoosh already played when the level was opened).
class IntroFeedback extends StatelessWidget {
  const IntroFeedback({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => FeedbackCue(at: .18, play: (f) => f.introReveal(), child: child);
}

/// Plays a feedback moment [at] seconds after it appears, so a screen can
/// line sounds up with its animation timeline:
/// `FeedbackCue(at: .75, play: (f) => f.star(1))`. Cancelled if the screen
/// goes away first.
class FeedbackCue extends ConsumerStatefulWidget {
  const FeedbackCue({super.key, required this.at, required this.play, this.child = const SizedBox.shrink()});
  final double at;
  final void Function(AppFeedback f) play;
  final Widget child;

  @override
  ConsumerState<FeedbackCue> createState() => _FeedbackCueState();
}

class _FeedbackCueState extends ConsumerState<FeedbackCue> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final fb = ref.read(feedbackProvider);
    _t = Timer(Duration(milliseconds: (widget.at * 1000).round()), () => widget.play(fb));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
