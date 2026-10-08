import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/course_providers.dart';
import '../../data/media.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../gameplay/widgets/illustration.dart';

/// 11 Level intro, from the prototype: level name, the big letters/word,
/// its picture and Pencil talking. Everything is in place by 2.3 s; then,
/// once Pencil has said the intro's line (`intro.audio`, from 0.55 s), it
/// all lifts away in 0.4 s and the level starts (or at once on tap).
/// Without a recording Pencil only moves his mouth, as in the prototype.
class LevelIntroScreen extends ConsumerStatefulWidget {
  const LevelIntroScreen({super.key, required this.level, required this.onDone});
  final CourseLevel level;
  final VoidCallback onDone;

  /// When Pencil starts talking (after the letters pop and sparkle).
  static const voiceAt = Duration(milliseconds: 550);

  /// The longest a line may hold the intro (a recording that never ends).
  static const maxVoice = Duration(seconds: 8);

  @override
  ConsumerState<LevelIntroScreen> createState() => _LevelIntroScreenState();
}

class _LevelIntroScreenState extends ConsumerState<LevelIntroScreen> with TickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  final _mascot = MascotController();
  final List<Timer> _timers = [];
  bool _left = false, _shown = false, _said = false;

  @override
  void initState() {
    super.initState();
    _mascot.setBodyColor(ref.read(progressProvider).color.key);
    final audio = widget.level.intro.audio;
    if (audio == null) {
      _mascot.play(MascotState.talking);
      _said = true;
    } else {
      _timers
        ..add(Timer(LevelIntroScreen.voiceAt, () => _speak(audio)))
        ..add(Timer(LevelIntroScreen.voiceAt + LevelIntroScreen.maxVoice, _saidIt));
    }
    _t.forward().whenComplete(() {
      _shown = true;
      _maybeOut();
    });
  }

  Future<void> _speak(String audio) async {
    if (!mounted) return;
    final voice = await ref.read(mediaProvider).voice(audio);
    if (!mounted) return;
    if (voice != null) await _mascot.say(voice.$1, lipFile: voice.$2);
    _saidIt();
  }

  void _saidIt() {
    if (_said || !mounted) return;
    _said = true;
    _maybeOut();
  }

  void _maybeOut() {
    if (!_shown || !_said || !mounted || _out.isAnimating || _out.isCompleted) return;
    _out.forward().whenComplete(_leave);
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    _mascot.play(MascotState.idle); // stops the voice when skipped
    widget.onDone();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _t.dispose();
    _out.dispose();
    _mascot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseProvider).value;
    final world = course?.worldOf(widget.level);
    final theme = LikhoWorlds.byId(world?.themeId ?? 'letterLand');
    final color = theme.accent;
    final intro = widget.level.intro;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (theme.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: LikhoColors.clear),
      child: Material(
        color: theme.bg,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(center: Alignment(0, -.2), radius: .9, colors: [GameColors.white55, GameColors.white00], stops: [0, .6]),
            ),
            child: AnimatedBuilder(
              animation: Listenable.merge([_t, _out]),
              builder: (context, _) {
                final sec = _t.value * 2.3;
                double seg(double a, double b) => ((sec - a) / (b - a)).clamp(0.0, 1.0);
                final outK = Curves.easeInOut.transform(_out.value);
                final lift = Matrix4.identity()
                  ..translateByDouble(0, -150 * outK, 0, 1)
                  ..scaleByDouble(1 - .65 * outK, 1 - .65 * outK, 1, 1);
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: seg(0, .4) * (1 - (_out.value / .75).clamp(0.0, 1.0)),
                        child: Text(
                          widget.level.name.toUpperCase(),
                          style: LikhoFonts.title(size: 16, color: color).copyWith(letterSpacing: 16 * .06),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: 1 - outK,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: lift,
                          child: _BigPop(
                            t: seg(0, .6),
                            child: Text(
                              intro.text,
                              style: LikhoFonts.letter(size: intro.text.length > 3 ? 96 : 180, color: color).copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1,
                                shadows: const [Shadow(color: GameColors.black08, offset: Offset(0, 8))],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: 1 - outK,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: lift,
                          child: Transform.scale(
                            scale: _popIn(seg(.35, .8)),
                            // the picture on a white card (the prototype's 170 x 130 frame)
                            child: Container(
                              width: 170,
                              height: 130,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: LikhoColors.surface,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [BoxShadow(color: GameColors.ink12, offset: Offset(0, 10), blurRadius: 24)],
                              ),
                              child: Illustration(
                                picture: Picture(key: intro.picture?.key ?? intro.word, label: 'illustration: ${intro.word}', url: intro.picture?.url),
                                width: 150,
                                height: 110,
                                radius: 20,
                                fontSize: 12,
                                stripe: 7,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18 + 10),
                      Opacity(
                        opacity: seg(.5, .9),
                        child: Transform.translate(
                          offset: Offset(0, 24 * (1 - Curves.easeOut.transform(seg(.5, .9)))),
                          child: SizedBox(width: 140, height: 198, child: OverflowBox(maxWidth: 160, child: PencilMascot(controller: _mascot, size: 198))),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static double _popIn(double p) {
    const c = Cubic(.34, 1.56, .64, 1);
    // (1 - .7) / .3 is a hair above 1 in floating point: clamp for Curve.transform
    return p < .7 ? 1.1 * c.transform(p / .7) : 1.1 - .1 * c.transform(((p - .7) / .3).clamp(0.0, 1.0));
  }
}

/// bigPop .6 s: scale .2 -> 1.12 (60 %) -> 1, fading in.
class _BigPop extends StatelessWidget {
  const _BigPop({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const c = Cubic(.34, 1.56, .64, 1);
    final s = t < .6 ? .2 + .92 * c.transform(t / .6) : 1.12 - .12 * c.transform((t - .6) / .4);
    return Opacity(opacity: (t / .6).clamp(0.0, 1.0), child: Transform.scale(scale: s, child: child));
  }
}

