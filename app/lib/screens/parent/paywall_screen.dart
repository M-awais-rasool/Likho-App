import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/billing.dart';
import '../../data/family.dart';
import '../../feedback/app_feedback.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import '../gameplay/widgets/game_buttons.dart';
import 'parent_widgets.dart';
import '../../data/app_controls.dart';

/// 22 Paywall (Likho Plus), from the prototype: what Plus unlocks, yearly or
/// monthly, and the free trial. With a store ([store]: Google Play) the
/// prices and the trial are the store's ([plans]) and [onStartTrial] buys
/// the chosen plan; without one it starts the server's free trial. Which
/// plans show, the "best value" one, the list of what Plus gives and the
/// server's trial come from the App controls ([BillingRules]).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.onClose,
    required this.onStartTrial,
    required this.onRestore,
    this.store = false,
    this.plans = const {},
    this.busy = false,
    this.current,
    this.onManage,
    this.rules = const BillingRules(),
  });
  final VoidCallback onClose, onRestore;

  /// The family's Likho Plus when it has it: shown instead of the plans.
  final PlusNow? current;

  /// Opens the store's subscription page (change plan, cancel).
  final VoidCallback? onManage;
  final ValueChanged<Plan> onStartTrial;
  final bool store, busy;
  final Map<Plan, StorePlan> plans;

  /// Likho Plus as the team set it up.
  final BillingRules rules;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late Plan _plan = _firstPlan;

  /// The plans offered, in the paywall's order.
  List<Plan> get _offered => [
    if (widget.rules.yearly || !widget.rules.monthly) Plan.yearly,
    if (widget.rules.monthly) Plan.monthly,
  ];

  Plan get _firstPlan => switch (widget.rules.bestValue) {
    'monthly' when widget.rules.monthly => Plan.monthly,
    _ => _offered.first,
  };

  /// Without a store, Plus comes only from the server's free trial.
  bool get _canStart => widget.store || widget.rules.serverTrial;

  void _pick(Plan p) {
    if (p != _plan) AppFeedback.of(context).select();
    setState(() => _plan = p);
  }

  /// Free days for [plan]: the store's (the team's before it answers), or
  /// the server's trial without a store.
  int _trial(Plan plan) {
    if (!widget.store) return widget.rules.serverTrial ? widget.rules.trialDays : 0;
    return widget.plans.isEmpty ? widget.rules.trialDays : widget.plans[plan]?.trialDays ?? 0;
  }

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
    if (!widget.store) {
      return _canStart ? 'Your free trial starts now. Nothing is charged.' : 'Likho Plus can be bought in Likho from Google Play.';
    }
    final trial = _trial(_plan);
    final every = _plan == Plan.yearly ? 'year' : 'month';
    final then = trial > 0 ? 'Free for $trial days, then ${_price(_plan)} a $every' : '${_price(_plan)} a $every';
    return '$then, renewing automatically until you cancel. Cancel anytime in Google Play › Payments & subscriptions.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.current case final now?) return _Current(now: now, onClose: widget.onClose, onManage: widget.onManage);
    if (!_offered.contains(_plan)) _plan = _firstPlan; // the team changed the plans meanwhile
    final trial = _trial(_plan);
    final benefits = widget.rules.benefits;
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
          child: benefits.isNotEmpty
              ? Column(
                  children: [
                    for (final (i, text) in benefits.indexed) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _Feature.styled(i, text),
                    ],
                  ],
                )
              : const _DefaultFeatures(),
        ),
        Column(
          children: [
            for (final (i, plan) in _offered.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              plan == Plan.yearly
                  ? _PlanCard(
                      selected: _plan == Plan.yearly,
                      title: 'Yearly',
                      note: '$_yearlyPerMonth / month',
                      price: _price(Plan.yearly),
                      badge: widget.rules.bestValue == 'yearly' ? 'BEST VALUE · SAVE $_save' : null,
                      onTap: () => _pick(Plan.yearly),
                    )
                  : _PlanCard(
                      selected: _plan == Plan.monthly,
                      title: 'Monthly',
                      note: 'Billed monthly',
                      price: _price(Plan.monthly),
                      badge: widget.rules.bestValue == 'monthly' ? 'BEST VALUE' : null,
                      onTap: () => _pick(Plan.monthly),
                    ),
            ],
          ],
        ),
        if (_canStart)
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

/// The family's Likho Plus, as the paywall shows it once they have it.
@immutable
class PlusNow {
  const PlusNow({this.plan, this.until, this.renews = false, this.store = false, this.trialLevels});

  /// The store's base plan ("monthly" / "yearly"); null: a trial or a grant.
  final String? plan;
  final DateTime? until;

  /// The store renews it (false: cancelled, it ends at [until]).
  final bool renews;

  /// Bought in the store (it can be managed there).
  final bool store;

  /// In a free trial that opens only levels up to this one (App controls).
  final int? trialLevels;

  String get title => switch (plan) {
    'monthly' => 'Monthly plan',
    'yearly' => 'Yearly plan',
    _ => 'Likho Plus',
  };

  /// Why some levels wait during the trial (null: they don't).
  String? get trialNote {
    final levels = trialLevels;
    if (levels == null) return null;
    final first = 'The free trial opens levels 1 to $levels.';
    if (!store) return '$first The other levels open with a Likho Plus plan.';
    final day = until == null ? '' : ' on ${formatDay(until!)}';
    return '$first The other levels open when your plan starts$day.';
  }

  String get status {
    final day = until == null ? null : formatDay(until!);
    if (day == null) return 'Active';
    if (!store) return 'Active until $day';
    return renews ? 'Renews on $day' : "Ends on $day. It won't renew.";
  }
}

/// "You have Likho Plus": the plan, when it renews or ends, and the store's
/// page to change or cancel it.
class _Current extends StatelessWidget {
  const _Current({required this.now, required this.onClose, this.onManage});
  final PlusNow now;
  final VoidCallback onClose;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) => ParentPage(
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
          onTap: onClose,
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
          Text('You have Likho Plus', textAlign: TextAlign.center, style: LikhoFonts.title(size: 30, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            now.trialLevels == null ? 'Every world and every level is open.' : 'Your free trial is on.',
            textAlign: TextAlign.center,
            style: LikhoFonts.parent(size: 15, weight: FontWeight.w600, color: UiColors.inkBody),
          ),
        ],
      ),
      ParentCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        radius: 22,
        soft: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(now.title, style: LikhoFonts.parent(size: 17, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(now.status, style: LikhoFonts.parent(size: 13, weight: FontWeight.w600, color: LikhoColors.inkMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: ParentColors.featureGreenBg, borderRadius: BorderRadius.circular(999)),
              child: Text('Active', style: LikhoFonts.parent(size: 12, weight: FontWeight.w800, color: ParentColors.featureGreen)),
            ),
          ],
        ),
      ),
      if (now.trialNote case final note?)
        ParentCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          radius: 22,
          soft: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: ParentColors.featureBlueBg, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: SymbolIcon(Symbols.lock_clock_rounded, size: 22, color: ParentColors.featureBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  note,
                  style: LikhoFonts.parent(size: 14, weight: FontWeight.w700, color: UiColors.inkBody).copyWith(height: 1.45),
                ),
              ),
            ],
          ),
        ),
      if (now.store && onManage != null) ...[
        PushButton(
          onTap: withSound(context, ButtonSound.press, onManage!),
          color: LikhoColors.ink,
          height: 60,
          width: double.infinity,
          pressScale: .98,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Text('Manage subscription', style: LikhoFonts.parent(size: 17, weight: FontWeight.w800, color: LikhoColors.surface)),
        ),
        Text(
          'Change your plan, cancel or update the payment method in Google Play.',
          textAlign: TextAlign.center,
          style: LikhoFonts.parent(size: 13, weight: FontWeight.w600, color: LikhoColors.inkMuted).copyWith(height: 1.55),
        ),
      ],
    ],
  );
}

/// What Likho Plus gives, as the app says it when the team wrote nothing.
class _DefaultFeatures extends StatelessWidget {
  const _DefaultFeatures();

  @override
  Widget build(BuildContext context) => const Column(
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
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.bg, required this.fg, required this.text});

  /// The team's line number [i], in the colours of the app's own list.
  factory _Feature.styled(int i, String text) {
    const looks = [
      (Symbols.public_rounded, ParentColors.featureGreenBg, ParentColors.featureGreen),
      (Symbols.menu_book_rounded, ParentColors.featureBlueBg, ParentColors.featureBlue),
      (Symbols.insights_rounded, ParentColors.featureCoralBg, ParentColors.featureCoral),
      (Symbols.group_rounded, ParentColors.featurePurpleBg, ParentColors.featurePurple),
      (Symbols.auto_awesome_rounded, ParentColors.featureGreenBg, ParentColors.featureGreen),
    ];
    final (icon, bg, fg) = looks[i % looks.length];
    return _Feature(icon: icon, bg: bg, fg: fg, text: text);
  }
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
