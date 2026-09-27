import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/progress.dart';
import 'package:likho/data/repositories/auth_repository.dart';
import 'package:likho/data/shop_items.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/dev/dev_launch.dart';
import 'package:likho/screens/app_flow.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/parent/parent_gate.dart';
import 'package:likho/screens/profiles/whos_playing_screen.dart';
import 'package:likho/screens/world_map/world_map_screen.dart';

import 'test_course.dart';

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// The app with the bundled course, a phone-sized screen and the flow's
/// navigator observer. Returns the provider container.
Future<ProviderContainer> _app(WidgetTester t, Widget home) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final container = ProviderContainer(overrides: [courseProvider.overrideWith((ref) async => testCourse)]);
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
  group('family data', () {
    test('finishing a level keeps the best stars and pays the difference (+2 the first time)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(familyProvider.notifier);
      expect(c.read(progressProvider).current, 8);
      final first = n.recordResult(8, 2);
      expect((first.gain, first.firstTime), (4, true));
      expect(c.read(progressProvider).stars, 42);
      final again = n.recordResult(8, 3);
      expect((again.gain, again.firstTime), (1, false));
      expect(c.read(progressProvider).levelStars[8], 3);
      expect(c.read(familyProvider).record.minutes, 42 + 6);
    });

    test('mascot room: buy, wear one accessory at a time, cannot overspend', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
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

    test('children: add (max 4), edit, delete, switch', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(familyProvider.notifier);
      n.addChild(name: ' Sara ', age: 7, color: LikhoColors.success);
      expect(c.read(familyProvider).active.name, 'Sara');
      expect(c.read(progressProvider).current, 1, reason: 'a new child starts at level 1');
      n.editActive(name: 'Sarah', age: 8, color: LikhoColors.secondary);
      expect((c.read(familyProvider).active.name, c.read(familyProvider).active.age), ('Sarah', 8));
      n.addChild(name: 'D', age: 5, color: LikhoColors.hint);
      expect(c.read(familyProvider).canAddChild, isFalse);
      n.deleteActive();
      expect(c.read(familyProvider).profiles.length, 3);
      n.selectChild('p2');
      expect(c.read(progressProvider).name, 'Zara');
    });

    test('session length decides how many levels before "Aaj ke liye bas!"', () {
      expect(const AppSettings(sessionMinutes: 5).levelsPerSession, 2);
      expect(const AppSettings().levelsPerSession, 3);
      expect(const AppSettings(sessionMinutes: 15).levelsPerSession, 4);
    });

    test('auth form checks', () {
      expect(AuthValidator.email('naam@gmail.com'), isTrue);
      expect(AuthValidator.email('abc'), isFalse);
      expect(AuthValidator.password('12345'), isFalse);
      expect(AuthValidator.password('123456'), isTrue);
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

  testWidgets('welcome -> sign up with email: checks the form, then Who\'s playing', (t) async {
    await _app(
      t,
      Builder(
        builder: (c) => TextButton(onPressed: () => Navigator.of(c).push(AppFlow.welcomeRoutePage()), child: const Text('go')),
      ),
    );
    await t.tap(find.text('go'));
    await _pumpFor(t, const Duration(milliseconds: 600));
    await t.tap(find.text('Shuru karein'));
    await _pumpFor(t, const Duration(milliseconds: 400));
    await t.tap(find.text('Email se'));
    await _pumpFor(t, const Duration(milliseconds: 400));

    await t.enterText(find.byType(TextField).first, 'abc');
    await t.tap(find.text('Account banayein'));
    await t.pump();
    expect(find.textContaining('Sahi email likhein'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 'ammi@gmail.com');
    await t.enterText(find.byType(TextField).last, '123');
    await t.tap(find.text('Account banayein'));
    await t.pump();
    expect(find.text('Password kam az kam 6 huroof ka ho'), findsOneWidget);

    await t.enterText(find.byType(TextField).last, 'secret1');
    await t.tap(find.text('Account banayein'));
    await _pumpFor(t, const Duration(milliseconds: 2600)); // 1.2 s request + .9 s check + transition
    expect(find.byType(WhosPlayingScreen), findsOneWidget);
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
