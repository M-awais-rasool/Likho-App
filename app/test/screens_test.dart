import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/auth.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/progress.dart';
import 'package:likho/data/shop_items.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/dev/dev_launch.dart';
import 'package:likho/screens/app_flow.dart';
import 'package:likho/screens/auth/sign_in_sheet.dart';
import 'package:likho/screens/auth/welcome_screen.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/parent/parent_gate.dart';
import 'package:likho/screens/profiles/child_setup_screen.dart';
import 'package:likho/screens/profiles/whos_playing_screen.dart';
import 'package:likho/screens/world_map/world_map_screen.dart';

import 'fake_backend.dart';
import 'test_course.dart';

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// The app with the bundled course, a phone-sized screen and the flow's
/// navigator observer. Returns the provider container. The family is the
/// sample one unless [overrides] says otherwise (e.g. a fake backend).
Future<ProviderContainer> _app(WidgetTester t, Widget home, {List<Override>? overrides}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final container = ProviderContainer(
    overrides: overrides ?? [courseProvider.overrideWith((ref) async => testCourse), familyProvider.overrideWith(DemoFamilyNotifier.new)],
  );
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: likhoTheme(), navigatorObservers: [AppFlow.observer], home: home),
    ),
  );
  await container.read(courseProvider.future);
  await t.pump();
  return container;
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 3));
}

/// Answers the parent gate ("7 × 3 = ?") correctly.
Future<void> _passGate(WidgetTester t) async {
  final q = t.widget<Text>(find.textContaining(' × ')).data!;
  final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
  await t.tap(find.text('${int.parse(m[1]!) * int.parse(m[2]!)}'));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  ProviderContainer demo() {
    final c = ProviderContainer(overrides: [familyProvider.overrideWith(DemoFamilyNotifier.new)]);
    addTearDown(c.dispose);
    return c;
  }

  group('family data', () {
    test('finishing a level keeps the best stars and pays the difference (+2 the first time)', () {
      final c = demo();
      final n = c.read(familyProvider.notifier);
      expect(c.read(progressProvider).current, 8);
      final first = n.recordResult(8, 2);
      expect((first.gain, first.firstTime), (4, true));
      expect(c.read(progressProvider).stars, 42);
      final again = n.recordResult(8, 3);
      expect((again.gain, again.firstTime), (1, false));
      expect(c.read(progressProvider).levelStars[8], 3);
      expect(c.read(familyProvider).record.minutes, 42 + 6, reason: '3 minutes each (default time)');
    });

    test('mascot room: buy, wear one accessory at a time, cannot overspend', () {
      final c = demo();
      final n = c.read(familyProvider.notifier);
      final crown = ShopItem.byId('crown')!, party = ShopItem.byId('party')!, rug = ShopItem.byId('rug')!;
      expect(n.tapItem(crown), isFalse, reason: 'Ayaan has 38 stars, the crown costs 40');
      expect(c.read(familyProvider).record.stars, 38);
      expect(n.tapItem(party), isTrue);
      expect(c.read(familyProvider).record.stars, 30);
      expect(c.read(progressProvider).accessory, 'party_hat');
      expect(n.tapItem(rug), isTrue);
      expect(c.read(familyProvider).record.room, containsAll(['lamp', 'rug']));
      n.tapItem(party); // owned: take it off
      expect(c.read(progressProvider).accessory, isNull);
      expect(c.read(familyProvider).record.stars, 14);
    });

    test('children: add (max 4), edit, delete, switch', () async {
      final c = demo();
      final n = c.read(familyProvider.notifier);
      await n.addChild(name: ' Sara ', age: 7, color: LikhoColors.success);
      expect(c.read(familyProvider).active.name, 'Sara');
      expect(c.read(progressProvider).current, 1, reason: 'a new child starts at level 1');
      await n.editActive(name: 'Sarah', age: 8, color: LikhoColors.secondary);
      expect((c.read(familyProvider).active.name, c.read(familyProvider).active.age), ('Sarah', 8));
      await n.addChild(name: 'D', age: 5, color: LikhoColors.hint);
      expect(c.read(familyProvider).canAddChild, isFalse);
      await n.deleteActive();
      expect(c.read(familyProvider).profiles.length, 3);
      n.selectChild('p2');
      expect(c.read(progressProvider).name, 'Zara');
    });

    test('session length decides how many levels before "Aaj ke liye bas!"', () {
      expect(const AppSettings(sessionMinutes: 5).levelsPerSession, 2);
      expect(const AppSettings().levelsPerSession, 3);
      expect(const AppSettings(sessionMinutes: 15).levelsPerSession, 4);
    });

    test('signed out = a guest child whose progress stays on the phone', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final f = c.read(familyProvider);
      expect((f.guest, f.active.name, f.profiles.length), (true, 'Dost', 1));
      expect(c.read(progressProvider).current, 1);
    });

    test('the account from GET /v1/me becomes the family', () {
      final f = FamilyState.fromMe({
        'account': {'id': 'a', 'email': 'ammi@gmail.com', 'name': 'Ammi', 'pictureUrl': ''},
        'settings': {'sessionMinutes': 15, 'music': false, 'sfx': true, 'haptics': true, 'leftHanded': true, 'reduceMotion': false},
        'subscription': {'active': true, 'plusUntil': null, 'trialUsed': true},
        'children': [
          {
            'id': 'k1',
            'name': 'Ayaan',
            'age': 6,
            'color': '#B79CED',
            'stars': 12,
            'wearing': 'party',
            'owned': ['party'],
            'room': [],
            'daysPlayed': 2,
            'minutesThisWeek': 9,
            'progress': {
              'english-handwriting': {
                'levelStars': {'1': 3, '2': 1},
              },
              'another-course': {
                'levelStars': {'1': 1, '2': 1, '3': 1},
              },
            },
          },
        ],
      });
      expect((f.online, f.account!.email, f.subscribed, f.settings.sessionMinutes, f.settings.leftHanded), (true, 'ammi@gmail.com', true, 15, true));
      expect((f.active.name, f.active.color, f.record.stars, f.record.wearing), ('Ayaan', BodySwatch.options[4].key, 12, 'party'));
      expect(f.record.levelStars, {1: 3, 2: 1}, reason: 'the map shows this app\'s course only');
      expect(colorToHex(f.active.color), '#B79CED');
    });

    test('the placement warm-up is exposed and played in the first world', () {
      expect(testCourse.placement?.number, 0);
      expect(testCourse.placement?.worldId, testCourse.worlds.first.id);
      expect(testCourse.levels.any((l) => l.number == 0), isFalse);
    });
  });

  testWidgets('every screen opens without errors', (t) async {
    for (final key in AppFlowJump.screens) {
      await _app(t, DevScreenLauncher(screen: key));
      await _pumpFor(t, const Duration(milliseconds: 1500));
      expect(t.takeException(), isNull, reason: key);
      await _close(t);
    }
  });

  Widget opener(Route<void> Function() route) => Builder(
    builder: (c) => TextButton(onPressed: () => Navigator.of(c).push(route()), child: const Text('go')),
  );

  testWidgets('welcome -> Continue with Google: a new account adds its first child', (t) async {
    final backend = FakeBackend();
    final c = await _app(t, opener(AppFlow.welcomeRoutePage), overrides: fakeBackendOverrides(backend));
    await c.read(authProvider.notifier).ready;
    await t.tap(find.text('go'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    expect(find.text('Shuru karein'), findsNothing, reason: 'no sign up / login buttons any more');
    await t.tap(find.text('Continue with Google'));
    await _pumpFor(t, const Duration(milliseconds: 900));
    expect(c.read(authProvider).signedIn, isTrue);
    expect(find.byType(ChildSetupScreen), findsOneWidget, reason: 'new account, no children yet');

    await t.enterText(find.byType(TextField), 'Sara');
    await t.tap(find.text('Aage'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    await t.tap(find.text('7'));
    await _pumpFor(t, const Duration(milliseconds: 800));
    await t.tap(find.text('Ho gaya!'));
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(backend.children.single['name'], 'Sara', reason: 'saved on the server');
    expect(c.read(familyProvider).active.id, backend.children.single['id']);
    expect(find.byType(GameplayScreen), findsOneWidget, reason: 'placement warm-up');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('welcome -> Continue with Google: an existing account goes to Who\'s playing', (t) async {
    final backend = FakeBackend()
      ..newAccount = false
      ..addChild('Ayaan', levels: {'1': 3});
    final c = await _app(t, opener(AppFlow.welcomeRoutePage), overrides: fakeBackendOverrides(backend));
    await c.read(authProvider.notifier).ready;
    await t.tap(find.text('go'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    await t.tap(find.text('Continue with Google'));
    await _pumpFor(t, const Duration(milliseconds: 900));
    expect(find.byType(WhosPlayingScreen), findsOneWidget);
    expect(c.read(progressProvider).current, 2, reason: 'the child\'s own progress from the server');
    await _close(t);
  });

  testWidgets('welcome -> Test User: signs in without Google and continues the saved family', (t) async {
    final backend = FakeBackend()
      ..newAccount = false
      ..addChild('Tester', levels: {'1': 3, '2': 2});
    // Google would be cancelled: the test user must not need it
    final c = await _app(t, opener(AppFlow.welcomeRoutePage), overrides: fakeBackendOverrides(backend, google: FakeGoogle()..cancel = true));
    await c.read(authProvider.notifier).ready;
    await t.tap(find.text('go'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    await t.tap(find.text('Test User se login'));
    await _pumpFor(t, const Duration(milliseconds: 900));
    expect(c.read(authProvider).signedIn, isTrue);
    expect(backend.idTokens, ['dev:${TestUser.email}']);
    expect(find.byType(WhosPlayingScreen), findsOneWidget);
    expect(c.read(progressProvider).current, 3, reason: 'the test child\'s progress from the server');
    await _close(t);
  });

  testWidgets('closing the Google sheet keeps Welcome', (t) async {
    final backend = FakeBackend();
    final c = await _app(t, opener(AppFlow.welcomeRoutePage), overrides: fakeBackendOverrides(backend, google: FakeGoogle()..cancel = true));
    await c.read(authProvider.notifier).ready;
    await t.tap(find.text('go'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    await t.tap(find.text('Continue with Google'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    expect(c.read(authProvider).signedIn, isFalse);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(backend.calls, isEmpty);
    await _close(t);
  });

  testWidgets('try first: the warm-up plays without an account', (t) async {
    final backend = FakeBackend();
    final c = await _app(t, opener(AppFlow.welcomeRoutePage), overrides: fakeBackendOverrides(backend));
    await c.read(authProvider.notifier).ready;
    await t.tap(find.text('go'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    await t.tap(find.text('Abhi nahi, pehle try karein'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    expect(t.widget<GameplayScreen>(find.byType(GameplayScreen)).level.number, 0);
    expect(c.read(familyProvider).guest, isTrue);
    expect(backend.calls, isEmpty);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a guest may play level 1', (t) async {
    final c = await _app(t, DevScreenLauncher(screen: 'map'), overrides: fakeBackendOverrides(FakeBackend()));
    await _pumpFor(t, const Duration(milliseconds: 600));
    expect(c.read(familyProvider).guest, isTrue);
    AppFlow.openLevel(t.element(find.byType(WorldMapScreen)), 1, skipIntro: true);
    await _pumpFor(t, const Duration(milliseconds: 600));
    expect(find.byType(GameplayScreen), findsOneWidget);
    expect(find.byType(SignInSheet), findsNothing);
    await _close(t);
  });

  testWidgets('a guest\'s level 2 asks to sign in; signing in starts the saved family', (t) async {
    final backend = FakeBackend();
    final c = await _app(t, DevScreenLauncher(screen: 'map'), overrides: fakeBackendOverrides(backend));
    await _pumpFor(t, const Duration(milliseconds: 600));
    c.read(familyProvider.notifier).recordResult(1, 3);
    expect(c.read(progressProvider).current, 2);
    expect(backend.calls, isEmpty, reason: 'a guest\'s progress stays on the phone');
    AppFlow.openLevel(t.element(find.byType(WorldMapScreen)), 2, skipIntro: true);
    await _pumpFor(t, const Duration(milliseconds: 600));
    expect(find.byType(GameplayScreen), findsNothing);
    expect(find.byType(SignInSheet), findsOneWidget);
    await t.tap(find.text('Continue with Google'));
    await _pumpFor(t, const Duration(milliseconds: 900));
    expect(c.read(authProvider).signedIn, isTrue);
    expect(find.byType(ChildSetupScreen), findsOneWidget, reason: 'new account: add the first child');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('Who\'s playing: picking a child opens the map as that child', (t) async {
    final c = await _app(t, DevScreenLauncher(screen: 'whos'));
    await _pumpFor(t, const Duration(milliseconds: 800));
    await t.tap(find.text('Zara'));
    await _pumpFor(t, const Duration(milliseconds: 1200));
    expect(c.read(familyProvider).active.name, 'Zara');
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(find.byType(WhosPlayingScreen, skipOffstage: false), findsOneWidget, reason: 'the map sits above Who\'s playing');
    await _close(t);
  });

  testWidgets('parent gate: a wrong answer shakes, the right one opens', (t) async {
    await _app(t, const SizedBox());
    final ctx = t.element(find.byType(SizedBox));
    bool? result;
    showParentGate(ctx).then((v) => result = v);
    await _pumpFor(t, const Duration(milliseconds: 400));
    final q = t.widget<Text>(find.textContaining(' × ')).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
    final a = int.parse(m[1]!), b = int.parse(m[2]!);
    await t.tap(find.text('${a * b - a}'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Dobara koshish karein'), findsOneWidget);
    expect(result, isNull);
    await _passGate(t);
    expect(result, isTrue);
    await _close(t);
  });

  testWidgets('add a child: name -> age -> colour -> placement warm-up', (t) async {
    final c = await _app(t, DevScreenLauncher(screen: 'onb'));
    await _pumpFor(t, const Duration(milliseconds: 800));
    await t.tap(find.text('Aage'));
    await t.pump();
    expect(find.text('Bache ka naam?'), findsOneWidget, reason: 'no name, no next step');
    await t.enterText(find.byType(TextField), 'Sara');
    await t.tap(find.text('Aage'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    await t.tap(find.text('7'));
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.text('Pencil ka rang chuno!'), findsOneWidget);
    await t.tap(find.text('Ho gaya!'));
    await _pumpFor(t, const Duration(milliseconds: 800));
    final f = c.read(familyProvider);
    expect((f.active.name, f.active.age, f.profiles.length), ('Sara', 7, 3));
    expect(t.widget<GameplayScreen>(find.byType(GameplayScreen)).level.number, 0, reason: 'placement warm-up');
    expect(t.takeException(), isNull);
    await _close(t);
  });
}
