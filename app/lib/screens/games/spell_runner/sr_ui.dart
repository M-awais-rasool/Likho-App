import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../design/tokens.dart';
import '../../gameplay/widgets/game_buttons.dart';
import 'sr_scene.dart';

abstract final class SrStyle {
  static const ink = Color(0xFF254A5B);
  static const teal = Color(0xFF15B6AF);
  static const tealDeep = Color(0xFF087F86);
  static const cream = Color(0xFFFFFDF3);
  static const purple = Color(0xFF7561D9);
  static const shadow = Color(0x25234E64);
}

class SrPill extends StatelessWidget {
  const SrPill({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: SrStyle.cream,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [BoxShadow(color: SrStyle.shadow, blurRadius: 12, offset: Offset(0, 4))],
    ),
    child: Align(widthFactor: 1, child: child),
  );
}

Widget srButton({required Key key, required String label, required IconData icon, required VoidCallback onTap, bool primary = true}) => PushButton(
  key: key,
  onTap: onTap,
  height: 58,
  color: primary ? SrStyle.teal : const Color(0xFFF0F6F3),
  edgeColor: primary ? SrStyle.tealDeep : const Color(0xFFD9E9E3),
  edge: 5,
  innerHighlight: true,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 27, fill: 1, color: primary ? Colors.white : SrStyle.ink),
      const SizedBox(width: 8),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: LikhoFonts.title(size: 23, weight: FontWeight.w800, color: primary ? Colors.white : SrStyle.ink),
          ),
        ),
      ),
    ],
  ),
);

class SrWelcome extends StatelessWidget {
  const SrWelcome({super.key, required this.hint, required this.best, required this.onPlay, required this.onBack});
  final String hint;
  final int best;
  final VoidCallback onPlay, onBack;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: Image.asset(SrArt.valley, fit: BoxFit.cover)),
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x0DFFFFFF), Color(0x00FFFFFF), Color(0xE6F6FFF0)], stops: [0, .5, 1]),
          ),
        ),
      ),
      SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 680;
                return Padding(
                  padding: EdgeInsets.fromLTRB(22, compact ? 10 : 22, 22, 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xEFFFFFF3), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          'SUNSHINE VALLEY',
                          style: LikhoFonts.body(size: 11, weight: FontWeight.w900, color: SrStyle.tealDeep).copyWith(letterSpacing: 2.2),
                        ),
                      ),
                      const SizedBox(height: 9),
                      FittedBox(
                        child: Text(
                          'Spell Runner',
                          style: LikhoFonts.title(size: compact ? 44 : 52, weight: FontWeight.w800, color: Colors.white).copyWith(
                            shadows: const [
                              Shadow(color: Color(0xFF158B9D), offset: Offset(0, 4)),
                              Shadow(color: Color(0x40157891), blurRadius: 16, offset: Offset(0, 6)),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        'Little letters. Big adventure.',
                        textAlign: TextAlign.center,
                        style: LikhoFonts.body(size: 15, weight: FontWeight.w800, color: const Color(0xFF21677C)),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: compact ? 0 : 8),
                          child: Image.asset(SrArt.hero, fit: BoxFit.contain, excludeFromSemantics: true),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 16 : 20),
                        decoration: BoxDecoration(
                          color: SrStyle.cream,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: SrStyle.shadow, blurRadius: 24, offset: Offset(0, 10))],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hint,
                              textAlign: TextAlign.center,
                              style: LikhoFonts.body(size: compact ? 13 : 15, weight: FontWeight.w800, color: SrStyle.ink),
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              children: [
                                Expanded(
                                  child: _GestureHint(icon: Symbols.swipe_rounded, label: 'Steer'),
                                ),
                                Expanded(
                                  child: _GestureHint(icon: Symbols.swipe_up_rounded, label: 'Jump'),
                                ),
                                Expanded(
                                  child: _GestureHint(icon: Symbols.swipe_down_rounded, label: 'Slide'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            srButton(key: const ValueKey('sr-play'), label: 'Let’s ride!', icon: Symbols.play_arrow_rounded, onTap: onPlay),
                            if (best > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Your best: $best',
                                  style: LikhoFonts.body(size: 13, weight: FontWeight.w800, color: SrStyle.tealDeep),
                                ),
                              ),
                          ],
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
      Positioned(
        left: 16,
        top: MediaQuery.paddingOf(context).top + 10,
        child: PushButton(
          key: const ValueKey('sr-back'),
          onTap: onBack,
          color: SrStyle.cream,
          width: 44,
          height: 44,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Symbols.arrow_back_rounded, color: SrStyle.ink),
        ),
      ),
    ],
  );
}

class _GestureHint extends StatelessWidget {
  const _GestureHint({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 38,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFE6F5ED), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 22, color: SrStyle.tealDeep),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: LikhoFonts.body(size: 11, weight: FontWeight.w800, color: SrStyle.ink),
      ),
    ],
  );
}

/// A matching, scrollable pause/result sheet for small phones and large type.
class SrRunCard extends StatelessWidget {
  const SrRunCard({
    super.key,
    required this.title,
    required this.primaryLabel,
    required this.primaryKey,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.secondaryKey,
    required this.onSecondary,
    this.detail,
    this.score,
    this.stars = 0,
    this.record = false,
  });
  final String title, primaryLabel, secondaryLabel;
  final Key primaryKey, secondaryKey;
  final VoidCallback onPrimary, onSecondary;
  final String? detail;
  final int? score;
  final int stars;
  final bool record;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x94214457),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
            decoration: BoxDecoration(
              color: SrStyle.cream,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: SrStyle.shadow, blurRadius: 32, offset: Offset(0, 16))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 152, child: Image.asset(SrArt.hero, excludeFromSemantics: true)),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: LikhoFonts.title(size: 32, weight: FontWeight.w800, color: SrStyle.ink),
                ),
                if (score != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [for (var i = 0; i < 3; i++) Icon(Symbols.star_rounded, size: 36, fill: 1, color: i < stars ? const Color(0xFFFFC44C) : const Color(0xFFDAE7DE))],
                  ),
                  Text(
                    '$score',
                    style: LikhoFonts.title(size: 46, weight: FontWeight.w800, color: SrStyle.tealDeep),
                  ),
                ],
                if (detail != null)
                  Text(
                    detail!,
                    textAlign: TextAlign.center,
                    style: LikhoFonts.body(size: 16, weight: FontWeight.w800, color: SrStyle.ink),
                  ),
                if (record)
                  Text(
                    'New best!',
                    style: LikhoFonts.title(size: 20, weight: FontWeight.w800, color: SrStyle.purple),
                  ),
                const SizedBox(height: 20),
                srButton(key: primaryKey, label: primaryLabel, icon: Symbols.play_arrow_rounded, onTap: onPrimary),
                const SizedBox(height: 14),
                srButton(key: secondaryKey, label: secondaryLabel, icon: Symbols.arrow_back_rounded, onTap: onSecondary, primary: false),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
