import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/billing.dart';
import '../../feedback/app_feedback.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import '../gameplay/widgets/game_buttons.dart';
import 'parent_widgets.dart';

/// 22 Paywall (Likho Plus), from the prototype: what Plus unlocks, yearly or
/// monthly, and the free trial. With a store ([store]: Google Play) the
/// prices and the trial are the store's ([plans]) and [onStartTrial] buys
/// the chosen plan; without one it starts the server's free trial.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.onClose,
    required this.onStartTrial,
    required this.onRestore,
    this.store = false,
    this.plans = const {},
    this.busy = false,
  });
  final VoidCallback onClose, onRestore;
  final ValueChanged<Plan> onStartTrial;
  final bool store, busy;
  final Map<Plan, StorePlan> plans;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Plan _plan = Plan.yearly;

  void _pick(Plan p) {
    if (p != _plan) AppFeedback.of(context).select();
    setState(() => _plan = p);
  }

  /// Free days for [plan]: the store's, or the usual 7 before it answers.
  int _trial(Plan plan) => widget.plans.isEmpty ? 7 : widget.plans[plan]?.trialDays ?? 0;

  String _price(Plan plan) => widget.plans[plan]?.price ?? (plan == Plan.yearly ? 'Rs 4,999' : 'Rs 799');

  /// The yearly price per month, in the store's currency ("Rs 416").
  String get _yearlyPerMonth {
    final y = widget.plans[Plan.yearly];
    if (y == null) return 'Rs 416';
    final symbol = RegExp(r'^[^\d]*').stringMatch(y.price)?.trim() ?? '';
    final perMonth = (y.priceMicros / 12 / 1e6).round();
    return '${symbol.isEmpty ? '' : '$symbol '}${_thousands(perMonth)}';
  }

  String get _save {
    final y = widget.plans[Plan.yearly], m = widget.plans[Plan.monthly];
    if (y == null || m == null || m.priceMicros == 0) return '48%';
    return '${((1 - y.priceMicros / (12 * m.priceMicros)) * 100).round()}%';
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  String get _finePrint {
    if (!widget.store) return 'Your free trial starts now. Nothing is charged.';
    final trial = _trial(_plan);
    final every = _plan == Plan.yearly ? 'year' : 'month';
    final then = trial > 0 ? 'Free for $trial days, then ${_price(_plan)} a $every' : '${_price(_plan)} a $every';
    return '$then, renewing automatically until you cancel. Cancel anytime in Google Play › Payments & subscriptions.';
  }

  @override
  Widget build(BuildContext context) {
    final trial = _trial(_plan);
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
              'Unlock all of Likho',
              textAlign: TextAlign.center,
              style: LikhoFonts.title(size: 30, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              trial > 0 ? 'First $trial days free. Cancel anytime.' : 'Cancel anytime.',
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
              _Feature(icon: Symbols.public_rounded, bg: ParentColors.featureGreenBg, fg: ParentColors.featureGreen, text: 'Every world and every level'),
              SizedBox(height: 12),
              _Feature(
                icon: Symbols.menu_book_rounded,
                bg: ParentColors.featureBlueBg,
                fg: ParentColors.featureBlue,
                text: 'The full course, from phonics to stories',
              ),
              SizedBox(height: 12),
              _Feature(icon: Symbols.insights_rounded, bg: ParentColors.featureCoralBg, fg: ParentColors.featureCoral, text: 'Weekly progress for parents'),
              SizedBox(height: 12),
              _Feature(
                icon: Symbols.group_rounded,
                bg: ParentColors.featurePurpleBg,
                fg: ParentColors.featurePurple,
                text: 'Up to 4 child profiles, no ads',
              ),
            ],
          ),
        ),
        Column(
          children: [
            _PlanCard(
              selected: _plan == Plan.yearly,
              title: 'Yearly',
              note: '$_yearlyPerMonth / month',
              price: _price(Plan.yearly),
              badge: 'BEST VALUE · SAVE $_save',
              onTap: () => _pick(Plan.yearly),
            ),
            const SizedBox(height: 10),
            _PlanCard(
              selected: _plan == Plan.monthly,
              title: 'Monthly',
              note: 'Billed monthly',
              price: _price(Plan.monthly),
              onTap: () => _pick(Plan.monthly),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: PushButton(
            onTap: widget.busy ? null : withSound(context, ButtonSound.press, () => widget.onStartTrial(_plan)),
            color: LikhoColors.ink,
            height: 64,
            width: double.infinity,
            pressScale: .98,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: widget.busy
                ? const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 3, color: LikhoColors.surface))
                : Text(
                    trial > 0 ? 'Start $trial-day free trial' : 'Subscribe',
                    style: LikhoFonts.parent(size: 18, weight: FontWeight.w800, color: LikhoColors.surface),
                  ),
          ),
        ),
        Text(
          _finePrint,
          textAlign: TextAlign.center,
          style: LikhoFonts.parent(size: 13, weight: FontWeight.w600, color: LikhoColors.inkMuted).copyWith(height: 1.55),
        ),
        Center(
          child: TextLink(
            text: 'Restore purchases',
            padding: EdgeInsets.zero,
            style: LikhoFonts.parent(size: 14, weight: FontWeight.w700, color: UiColors.link),
            onTap: widget.busy ? () {} : widget.onRestore,
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
