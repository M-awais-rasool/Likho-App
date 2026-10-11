import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'api/api_client.dart';
import 'api/likho_api.dart';
import 'family.dart';

/// Likho Plus plans: the base plans of the `likho_plus` subscription in
/// Play Console (base plan IDs "yearly" and "monthly").
enum Plan { yearly, monthly }

/// The Likho Plus subscription's product ID in Play Console.
const plusProductId = 'likho_plus';

/// A plan as the store sells it to this account.
@immutable
class StorePlan {
  const StorePlan({required this.plan, required this.price, required this.priceMicros, this.trialDays = 0});
  final Plan plan;

  /// The price after any trial, as the store writes it ("Rs 4,999").
  final String price;
  final int priceMicros;

  /// Free days before the first payment (0: no trial for this account).
  final int trialDays;
}

enum StoreStatus { bought, restored, pending, failed, canceled }

/// A purchase the store reports (just bought, restored, or left unfinished).
@immutable
class StorePurchase {
  const StorePurchase({required this.productId, required this.token, required this.status, this.raw});
  final String productId;

  /// Google Play's purchase token (the server checks it at Google).
  final String token;
  final StoreStatus status;

  /// The plugin's own object, to finish the purchase.
  final Object? raw;
}

/// The phone's app store. [PlayStore] on Android; fakes in tests.
abstract interface class Store {
  Future<bool> available();

  /// The plans this account can buy, with their prices and trials.
  Future<Map<Plan, StorePlan>> plans();

  /// Opens the store's purchase sheet; false when it could not open. The
  /// result comes through [purchases].
  Future<bool> buy(Plan plan, {required String accountId});

  /// Asks the store for this account's purchases (they come through
  /// [purchases] as restored).
  Future<void> restore({required String accountId});

  /// Purchases the app has not finished (e.g. the app closed during one).
  Future<List<StorePurchase>> unfinished();
  Stream<List<StorePurchase>> get purchases;

  /// Tells the store the purchase is delivered (Google Play acknowledges it).
  Future<void> complete(StorePurchase purchase);
}

/// Google Play Billing through the in_app_purchase plugin.
class PlayStore implements Store {
  final _iap = InAppPurchase.instance;
  final Map<Plan, GooglePlayProductDetails> _details = {};

  @override
  Future<bool> available() => _iap.isAvailable();

  @override
  Future<Map<Plan, StorePlan>> plans() async {
    final res = await _iap.queryProductDetails({plusProductId});
    if (res.error != null) throw StateError('store: ${res.error!.message}');
    final out = <Plan, StorePlan>{};
    _details.clear();
    for (final d in res.productDetails.whereType<GooglePlayProductDetails>()) {
      final i = d.subscriptionIndex;
      final offers = d.productDetails.subscriptionOfferDetails;
      if (i == null || offers == null || i >= offers.length) continue;
      final offer = offers[i];
      final plan = Plan.values.asNameMap()[offer.basePlanId];
      if (plan == null || offer.pricingPhases.isEmpty) continue;
      final free = offer.pricingPhases.where((p) => p.priceAmountMicros == 0).firstOrNull;
      final recurring = offer.pricingPhases.last;
      final candidate = StorePlan(
        plan: plan,
        price: recurring.formattedPrice,
        priceMicros: recurring.priceAmountMicros,
        trialDays: free == null ? 0 : periodDays(free.billingPeriod) * (free.billingCycleCount == 0 ? 1 : free.billingCycleCount),
      );
      // Play lists only the offers this account can get: prefer the trial
      if (out[plan] == null || candidate.trialDays > out[plan]!.trialDays) {
        out[plan] = candidate;
        _details[plan] = d;
      }
    }
    return out;
  }

  @override
  Future<bool> buy(Plan plan, {required String accountId}) async {
    if (_details[plan] == null) await plans();
    final d = _details[plan];
    if (d == null) return false;
    return _iap.buyNonConsumable(purchaseParam: GooglePlayPurchaseParam(productDetails: d, applicationUserName: accountId));
  }

  @override
  Future<void> restore({required String accountId}) => _iap.restorePurchases(applicationUserName: accountId);

  @override
  Future<List<StorePurchase>> unfinished() async {
    final res = await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().queryPastPurchases();
    return [
      for (final p in res.pastPurchases)
        if (!p.billingClientPurchase.isAcknowledged) _purchase(p, StoreStatus.bought),
    ];
  }

  @override
  Stream<List<StorePurchase>> get purchases => _iap.purchaseStream.map((list) => [for (final p in list) _purchase(p, _status(p.status))]);

  @override
  Future<void> complete(StorePurchase purchase) async {
    final raw = purchase.raw;
    if (raw is PurchaseDetails && raw.pendingCompletePurchase) await _iap.completePurchase(raw);
  }

  static StorePurchase _purchase(PurchaseDetails p, StoreStatus status) =>
      StorePurchase(productId: p.productID, token: p.verificationData.serverVerificationData, status: status, raw: p);

  static StoreStatus _status(PurchaseStatus s) => switch (s) {
    PurchaseStatus.purchased => StoreStatus.bought,
    PurchaseStatus.restored => StoreStatus.restored,
    PurchaseStatus.pending => StoreStatus.pending,
    PurchaseStatus.error => StoreStatus.failed,
    PurchaseStatus.canceled => StoreStatus.canceled,
  };
}

/// Days in an ISO 8601 billing period ("P7D", "P1W", "P1M", "P1Y").
int periodDays(String period) {
  final m = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$').firstMatch(period);
  if (m == null) return 0;
  int n(int g) => int.tryParse(m.group(g) ?? '') ?? 0;
  return n(1) * 365 + n(2) * 30 + n(3) * 7 + n(4);
}

/// The store on this phone, or null where none is wired (iOS, web,
/// desktop): there the paywall uses the server's free trial.
final storeProvider = Provider<Store?>((ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? PlayStore() : null);

/// What the paywall shows about buying.
@immutable
class BillingState {
  const BillingState({this.plans = const {}, this.busy = false, this.activated = 0});

  /// The store's plans and prices (empty: not known, e.g. offline).
  final Map<Plan, StorePlan> plans;

  /// A purchase or a restore is going on.
  final bool busy;

  /// Goes up each time a purchase turned Likho Plus on (the paywall closes).
  final int activated;

  BillingState copyWith({Map<Plan, StorePlan>? plans, bool? busy, int? activated}) =>
      BillingState(plans: plans ?? this.plans, busy: busy ?? this.busy, activated: activated ?? this.activated);
}

/// Likho Plus through the store: loads the plans, starts purchases and
/// restores, and sends every purchase to the server, which checks it at
/// Google Play and turns Plus on. Only then is the purchase finished
/// (acknowledged); one the server could not check stays unfinished and is
/// sent again the next time the app opens.
class BillingNotifier extends Notifier<BillingState> {
  StreamSubscription<List<StorePurchase>>? _sub;
  Completer<bool>? _restoring;
  final Set<String> _handling = {};

  Store? get _store => ref.read(storeProvider);

  @override
  BillingState build() {
    final store = ref.watch(storeProvider);
    if (store != null) {
      _sub = store.purchases.listen(_onPurchases, onError: (Object e) => debugPrint('store: $e'));
      ref.onDispose(() => _sub?.cancel());
      Future.microtask(loadPlans);
    }
    return const BillingState();
  }

  void _say(String text) => ref.read(syncMessageProvider.notifier).show(text);

  Future<void> loadPlans() async {
    final store = _store;
    if (store == null) return;
    try {
      if (!await store.available()) return;
      final plans = await store.plans();
      if (ref.mounted) state = state.copyWith(plans: plans);
    } catch (e) {
      debugPrint('store plans: $e');
    }
  }

  /// Starts buying [plan]. The parent must be signed in (the purchase
  /// belongs to the account).
  Future<void> buy(Plan plan) async {
    final store = _store;
    final family = ref.read(familyProvider);
    if (store == null || !family.online || state.busy) return;
    state = state.copyWith(busy: true);
    var opened = false;
    try {
      opened = await store.buy(plan, accountId: family.storeAccountId);
    } catch (e) {
      debugPrint('store buy: $e');
    }
    if (!ref.mounted) return;
    if (!opened) {
      state = state.copyWith(busy: false);
      _say("Google Play couldn't open. Please try again.");
    }
  }

  /// Restores purchases made with this account (e.g. on a new phone).
  /// True when Likho Plus came back.
  Future<bool> restore() async {
    final store = _store;
    final family = ref.read(familyProvider);
    if (store == null || !family.online || state.busy) return false;
    state = state.copyWith(busy: true);
    final done = _restoring = Completer<bool>();
    try {
      await store.restore(accountId: family.storeAccountId);
    } catch (e) {
      debugPrint('store restore: $e');
    }
    // restored purchases arrive on the stream; none = nothing to restore
    final restored = await done.future.timeout(const Duration(seconds: 8), onTimeout: () => false);
    _restoring = null;
    if (!ref.mounted) return restored;
    state = state.copyWith(busy: false);
    if (!restored) _say('No previous purchases found.');
    return restored;
  }

  /// Sends purchases left unfinished (the app closed, or the server could
  /// not be reached) to the server again. Called when the app opens.
  Future<void> finishUnfinished() async {
    final store = _store;
    if (store == null || !ref.read(familyProvider).online) return;
    try {
      final list = await store.unfinished();
      if (list.isNotEmpty) await _onPurchases(list, quiet: true);
    } catch (e) {
      debugPrint('store unfinished: $e');
    }
  }

  Future<void> _onPurchases(List<StorePurchase> list, {bool quiet = false}) async {
    var restoredAny = false;
    for (final p in list) {
      if (p.productId != plusProductId) continue;
      switch (p.status) {
        case StoreStatus.pending:
          _say('Your payment is pending. Likho Plus starts when Google Play confirms it.');
        case StoreStatus.failed:
          _say("The purchase didn't go through. Please try again.");
        case StoreStatus.canceled:
          break;
        case StoreStatus.bought || StoreStatus.restored:
          if (!_handling.add(p.token)) continue;
          try {
            if (await _deliver(p, quiet: quiet || p.status == StoreStatus.restored)) restoredAny = true;
          } finally {
            _handling.remove(p.token);
          }
      }
    }
    if (!ref.mounted) return;
    if (_restoring != null && list.any((p) => p.status == StoreStatus.restored)) {
      if (!_restoring!.isCompleted) _restoring!.complete(restoredAny);
      return; // restore() ends busy and says the rest
    }
    state = state.copyWith(busy: false);
  }

  /// Has the server check the purchase and turn Plus on; then finishes it.
  Future<bool> _deliver(StorePurchase p, {required bool quiet}) async {
    final family = ref.read(familyProvider.notifier);
    if (!ref.read(familyProvider).online) return false;
    try {
      final r = await ref.read(apiProvider).verifyGooglePurchase(productId: p.productId, purchaseToken: p.token);
      if (!ref.mounted) return false;
      final active = (r['subscription'] as Map?)?['active'] == true;
      await _store?.complete(p);
      await family.refreshMe();
      if (!ref.mounted || !active) return false;
      state = state.copyWith(activated: state.activated + 1);
      if (!quiet) _say('Welcome to Likho Plus!');
      return true;
    } on ApiException catch (e) {
      _say(switch (e.code) {
        'purchase_other_account' => 'This purchase belongs to another Likho account. Sign in with that account to use it.',
        'purchase_pending' => 'Your payment is pending. Likho Plus starts when Google Play confirms it.',
        'offline' || 'store_unreachable' || 'store_unavailable' => "We couldn't confirm the purchase yet. We'll try again when you open Likho.",
        _ => "We couldn't confirm the purchase. Please try again or contact us.",
      });
      return false;
    }
  }
}

final billingProvider = NotifierProvider<BillingNotifier, BillingState>(BillingNotifier.new);
