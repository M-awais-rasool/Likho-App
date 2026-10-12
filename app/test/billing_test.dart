import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/auth.dart';
import 'package:likho/data/billing.dart';
import 'package:likho/data/family.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/parent/paywall_screen.dart';

import 'fake_backend.dart';

/// Likho Plus through Google Play: the app buys in the store, the server
/// checks the purchase and turns Plus on, and only then is it finished.
void main() {
  late FakeBackend backend;
  late FakeStore store;
  late ProviderContainer c;
  final messages = <String>[];

  Future<void> settle() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    backend = FakeBackend();
    store = FakeStore();
    messages.clear();
    c = ProviderContainer(overrides: fakeBackendOverrides(backend, store: store));
    addTearDown(c.dispose);
    c.listen(familyProvider, (_, _) {});
    c.listen(syncMessageProvider, (_, m) => m == null ? null : messages.add(m.text));
    c.listen(billingProvider, (_, _) {});
    await c.read(authProvider.notifier).ready;
    await c.read(authProvider.notifier).signInWithGoogle();
    await settle();
  });

  test('the store\'s plans, prices and trials', () async {
    final plans = c.read(billingProvider).plans;
    expect((plans[Plan.yearly]!.price, plans[Plan.yearly]!.trialDays, plans[Plan.monthly]!.price), ('Rs 5,000', 7, 'Rs 800'));
  });

  test('buying: the server confirms, Plus is on, the purchase is finished', () async {
    expect(c.read(familyProvider).subscribed, isFalse);
    await c.read(billingProvider.notifier).buy(Plan.yearly);
    await settle();
    expect(store.accountIds, ['store-acc1'], reason: 'bought for this account');
    expect(backend.purchases, ['tok-yearly']);
    expect(store.completed, ['tok-yearly'], reason: 'finished only after the server said yes');
    final f = c.read(familyProvider);
    expect((f.subscribed, f.plusPlan), (true, 'yearly'));
    final b = c.read(billingProvider);
    expect((b.activated, b.busy), (1, false));
    expect(messages, ['Welcome to Likho Plus!']);
  });

  test('another account\'s purchase is not finished and Plus stays off', () async {
    store.nextToken = 'tok-other';
    await c.read(billingProvider.notifier).buy(Plan.monthly);
    await settle();
    expect(store.completed, isEmpty);
    expect(c.read(familyProvider).subscribed, isFalse);
    expect(messages.single, contains('another Likho account'));
  });

  test('a pending payment and a failed purchase say so', () async {
    store.nextStatus = StoreStatus.pending;
    await c.read(billingProvider.notifier).buy(Plan.monthly);
    await settle();
    store.nextStatus = StoreStatus.failed;
    await c.read(billingProvider.notifier).buy(Plan.monthly);
    await settle();
    expect(messages, [contains('pending'), contains("didn't go through")]);
    expect(backend.purchases, isEmpty);
    expect(c.read(billingProvider).busy, isFalse);
  });

  test('offline: the purchase stays unfinished and is sent again when the app opens', () async {
    backend.offline = true;
    await c.read(billingProvider.notifier).buy(Plan.monthly);
    await settle();
    expect(store.completed, isEmpty);
    expect(messages.single, contains("We'll try again"));
    backend.offline = false;
    store.left = [const StorePurchase(productId: plusProductId, token: 'tok-monthly', status: StoreStatus.bought)];
    await c.read(billingProvider.notifier).finishUnfinished();
    await settle();
    expect(store.completed, ['tok-monthly']);
    expect(c.read(familyProvider).subscribed, isTrue);
  });

  test('restore: nothing to restore, then a purchase made before', () async {
    expect(await c.read(billingProvider.notifier).restore(), isFalse);
    expect(messages.last, 'No previous purchases found.');
    store.owned = [const StorePurchase(productId: plusProductId, token: 'tok-yearly', status: StoreStatus.bought)];
    expect(await c.read(billingProvider.notifier).restore(), isTrue);
    expect(c.read(familyProvider).subscribed, isTrue);
  });

  test('periodDays reads the store\'s billing periods', () {
    expect([periodDays('P7D'), periodDays('P1W'), periodDays('P1M'), periodDays('P1Y'), periodDays('nope')], [7, 7, 30, 365, 0]);
  });

  testWidgets('the paywall shows the store\'s prices and trial', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Plan? bought;
    final plans = await store.plans();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: likhoTheme(),
          home: PaywallScreen(store: true, plans: plans, onClose: () {}, onRestore: () {}, onStartTrial: (p) => bought = p),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Rs 5,000'), findsOneWidget);
    expect(find.text('Rs 800'), findsOneWidget);
    expect(find.text('Rs 417 / month'), findsOneWidget);
    expect(find.text('BEST VALUE · SAVE 48%'), findsOneWidget);
    expect(find.textContaining('then Rs 5,000 a year'), findsOneWidget);
    await t.tap(find.text('Start 7-day free trial'));
    await t.pump();
    expect(bought, Plan.yearly);
  });

  test('after buying, the family knows the plan, its renewal date and the store', () async {
    await c.read(billingProvider.notifier).buy(Plan.monthly);
    await settle();
    final f = c.read(familyProvider);
    expect((f.subscribed, f.plusPlan, f.plusRenews, f.plusStore), (true, 'monthly', true, 'google_play'));
    expect(f.plusUntil, DateTime.utc(2099).toLocal());
    expect(formatDay(DateTime(2026, 10, 11)), '11 Oct 2026');
  });

  testWidgets('with Likho Plus the plan screen shows the plan and Manage subscription', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var managed = 0;
    Future<void> show(PlusNow now) => t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: likhoTheme(),
          home: PaywallScreen(store: true, current: now, onClose: () {}, onRestore: () {}, onStartTrial: (_) {}, onManage: () => managed++),
        ),
      ),
    );
    await show(PlusNow(plan: 'monthly', until: DateTime(2026, 11, 11), renews: true, store: true));
    await t.pump();
    expect(find.text('You have Likho Plus'), findsOneWidget);
    expect(find.text('Monthly plan'), findsOneWidget);
    expect(find.text('Renews on 11 Nov 2026'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsNothing, reason: 'no plans to buy any more');
    await t.tap(find.text('Manage subscription'));
    await t.pump();
    expect(managed, 1);

    await show(PlusNow(plan: 'yearly', until: DateTime(2027, 10, 11), store: true));
    await t.pump();
    expect(find.text("Ends on 11 Oct 2027. It won't renew."), findsOneWidget);

    await show(PlusNow(until: DateTime(2026, 10, 18)));
    await t.pump();
    expect(find.text('Active until 18 Oct 2026'), findsOneWidget);
    expect(find.text('Manage subscription'), findsNothing, reason: 'a trial or a grant is not in the store');
  });
}
