import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../feedback/app_feedback.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import '../gameplay/widgets/game_buttons.dart';
import 'parent_widgets.dart';

enum Plan { yearly, monthly }

/// 22 Paywall (Likho Plus), from the prototype: what Plus unlocks, yearly or
/// monthly, and a 7 day free trial. Store purchase is not wired yet;
/// [onStartTrial] gets the chosen plan.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.onClose, required this.onStartTrial, required this.onRestore});
  final VoidCallback onClose, onRestore;
  final ValueChanged<Plan> onStartTrial;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Plan _plan = Plan.yearly;

  void _pick(Plan p) {
    if (p != _plan) AppFeedback.of(context).select();
    setState(() => _plan = p);
  }

  @override
  Widget build(BuildContext context) {
    return ParentPage(
      background: UiColors.parentBg,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [ParentColors.journeyTop, UiColors.parentBg],
        stops: [0, .36],
      ),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: CircleIconButton(
            icon: Symbols.close_rounded,
            onTap: widget.onClose,
            size: 44,
            iconSize: 22,
            color: UiColors.white80,
            shadow: null,
            sound: ButtonSound.back,
          ),
        ),
        Column(
          children: [
            const IconLine(Symbols.workspace_premium_rounded, size: 56, color: LikhoColors.primary),
            const SizedBox(height: 8),
            Text(
              'Poora Likho kholein',
              textAlign: TextAlign.center,
              style: LikhoFonts.title(size: 30, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Pehle 7 din bilkul free. Kabhi bhi cancel.',
              textAlign: TextAlign.center,
              style: LikhoFonts.parent(size: 15, weight: FontWeight.w600, color: UiColors.inkBody),
            ),
          ],
        ),
        ParentCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          radius: 22,
          soft: false,
          child: const Column(
            children: [
              _Feature(icon: Symbols.public_rounded, bg: ParentColors.featureGreenBg, fg: ParentColors.featureGreen, text: 'Saare 6 worlds aur 36 levels'),
              SizedBox(height: 12),
              _Feature(
                icon: Symbols.menu_book_rounded,
                bg: ParentColors.featureBlueBg,
                fg: ParentColors.featureBlue,
                text: 'Phonics se kahani tak poora course',
              ),
              SizedBox(height: 12),
              _Feature(icon: Symbols.insights_rounded, bg: ParentColors.featureCoralBg, fg: ParentColors.featureCoral, text: 'Walidain ke liye weekly report'),
              SizedBox(height: 12),
              _Feature(
                icon: Symbols.group_rounded,
                bg: ParentColors.featurePurpleBg,
                fg: ParentColors.featurePurple,
                text: '4 bachon tak ke profiles, koi ads nahi',
              ),
            ],
          ),
        ),
        Column(
          children: [
            _PlanCard(
              selected: _plan == Plan.yearly,
              title: 'Saalana',
              note: 'Rs 416 / mahina',
              price: 'Rs 4,999',
              badge: 'SAB SE BEHTAR · 48% BACHAT',
              onTap: () => _pick(Plan.yearly),
            ),
            const SizedBox(height: 10),
            _PlanCard(
              selected: _plan == Plan.monthly,
              title: 'Mahana',
              note: 'Har mahine bill',
              price: 'Rs 799',
              onTap: () => _pick(Plan.monthly),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: PushButton(
            onTap: withSound(context, ButtonSound.press, () => widget.onStartTrial(_plan)),
            color: LikhoColors.ink,
            height: 64,
            width: double.infinity,
            pressScale: .98,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Text(
              '7 din free shuru karein',
              style: LikhoFonts.parent(size: 18, weight: FontWeight.w800, color: LikhoColors.surface),
            ),
          ),
        ),
        Text(
          'Trial ke baad plan ke mutabiq charge hoga. Cancel karne ke liye: Settings › Apple ID / Google Play › Subscriptions › Likho. '
          'Trial khatam hone se 24 ghante pehle yaad dahani bhejenge.',
          textAlign: TextAlign.center,
          style: LikhoFonts.parent(size: 13, weight: FontWeight.w600, color: LikhoColors.inkMuted).copyWith(height: 1.55),
        ),
        Center(
          child: TextLink(
            text: 'Restore purchases',
            padding: EdgeInsets.zero,
            style: LikhoFonts.parent(size: 14, weight: FontWeight.w700, color: UiColors.link),
            onTap: widget.onRestore,
          ),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.bg, required this.fg, required this.text});
  final IconData icon;
  final Color bg, fg;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Center(child: SymbolIcon(icon, size: 22, color: fg)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text, style: LikhoFonts.parent(size: 15, weight: FontWeight.w700)),
      ),
    ],
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.selected, required this.title, required this.note, required this.price, required this.onTap, this.badge});
  final bool selected;
  final String title, note, price;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? ParentColors.planSelected : LikhoColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? LikhoColors.secondary : GameColors.ink12, width: 2.5, strokeAlign: BorderSide.strokeAlignInside),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: LikhoFonts.parent(size: 17, weight: FontWeight.w800)),
                    Text(
                      note,
                      style: LikhoFonts.parent(size: 13, weight: FontWeight.w600, color: LikhoColors.inkMuted),
                    ),
                  ],
                ),
              ),
              Text(price, style: LikhoFonts.parent(size: 20, weight: FontWeight.w800)),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            right: 16,
            top: -11,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: LikhoColors.success, borderRadius: BorderRadius.circular(11)),
              child: Text(
                badge!,
                style: LikhoFonts.parent(size: 11, weight: FontWeight.w800, color: LikhoColors.surface).copyWith(letterSpacing: .44, height: 1),
              ),
            ),
          ),
      ],
    ),
  );
}
