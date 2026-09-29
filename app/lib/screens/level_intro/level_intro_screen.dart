import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/course_providers.dart';
import '../../data/models/course_models.dart';
import '../../data/progress.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../gameplay/widgets/illustration.dart';

/// 11 Level intro, from the prototype: level name, the big letters/word,
/// its picture and Pencil talking. After 2.3 s everything lifts away; at
/// 2.7 s (or on tap) the level starts.
class LevelIntroScreen extends ConsumerStatefulWidget {
  const LevelIntroScreen({super.key, required this.level, required this.onDone});
  final CourseLevel level;
  final VoidCallback onDone;

  @override
  ConsumerState<LevelIntroScreen> createState() => _LevelIntroScreenState();
}

class _LevelIntroScreenState extends ConsumerState<LevelIntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 2700));
  final _mascot = MascotController();
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _mascot
      ..setBodyColor(ref.read(progressProvider).color.key)
      ..play(MascotState.talking);
    _t.forward().whenComplete(_leave);
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _t.dispose();
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
              animation: _t,
              builder: (context, _) {
                final sec = _t.value * 2.7;
                final out = sec >= 2.3;
                double seg(double a, double b) => ((sec - a) / (b - a)).clamp(0.0, 1.0);
                final outK = Curves.easeInOut.transform(seg(2.3, 2.7));
                final lift = Matrix4.identity()
                  ..translateByDouble(0, -150 * outK, 0, 1)
                  ..scaleByDouble(1 - .65 * outK, 1 - .65 * outK, 1, 1);
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: seg(0, .4) * (out ? 1 - seg(2.3, 2.6) : 1),
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
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [BoxShadow(color: GameColors.ink12, offset: Offset(0, 10), blurRadius: 24)],
                              ),
                              child: Illustration(
                                picture: Picture(key: intro.picture?.key ?? intro.word, label: 'illustration: ${intro.word}', url: intro.picture?.url),
                                width: 170,
                                height: 130,
                                radius: 30,
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
    return p < .7 ? 1.1 * c.transform(p / .7) : 1.1 - .1 * c.transform((p - .7) / .3);
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

