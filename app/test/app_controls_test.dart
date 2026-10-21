import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/api/api_client.dart';
import 'package:likho/data/app_controls.dart';
import 'package:likho/data/auth.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/shop_items.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/app_flow.dart';
import 'package:likho/screens/app_shell.dart';
import 'package:likho/screens/parent/paywall_screen.dart';
import 'package:likho/screens/room/mascot_room_screen.dart';
import 'package:likho/screens/world_map/world_map_screen.dart';

import 'fake_backend.dart';
import 'test_course.dart';

/// What GET /v1/config sends, with [patch] laid over the defaults.
Map<String, dynamic> _config({Map<String, String> features = const {}, Map<String, dynamic> billing = const {}, Map<String, dynamic> extra = const {}}) => {
  'revision': 3,
  'features': {'stories': 'off', 'room': 'on', 'stickers': 'on', 'certificate': 'on', 'placement': 'on', 'guest': 'on', 'sfx': 'on', 'voice': 'on', 'haptics': 'on', ...features},
  'stories': {
    'comingSoon': true,
    'episodes': {'a': 'on'},
  },
  'room': {'items': <String, dynamic>{}},
  'games': <String, dynamic>{},
  'pencilColors': ['#FFC83D', '#4D9DE0', '#3BB273', '#FF8A5B', '#B79CED', '#FF9EB5'],
  'billing': {'enabled': true, 'freeLevels': 30, 'guestLevels': 1, 'trialLevels': 0, 'serverTrial': true, 'trialDays': 7, 'monthly': true, 'yearly': true, 'bestValue': 'yearly', 'benefits': <String>[], 'plusFree': false, 'freeForAll': false, ...billing},
  'app': {
    'minVersion': '',
    'maintenance': {'on': false, 'title': '', 'text': '', 'id': 'm1'},
    'parentMessage': {'on': false, 'title': '', 'text': '', 'id': 'p1'},
  },
  ...extra,
};

AppControls _controls({Map<String, String> features = const {}, Map<String, dynamic> billing = const {}, Map<String, dynamic> extra = const {}}) =>
    AppControls.fromJson(_config(features: features, billing: billing, extra: extra));

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _phone(WidgetTester t, Widget child, {required List<Override> overrides}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(key: UniqueKey(), overrides: overrides, child: MaterialApp(theme: likhoTheme(), navigatorObservers: [AppFlow.observer], home: child)));
  await _pumpFor(t, const Duration(milliseconds: 1500));
}

void main() {
  test('before anything is downloaded the app is as it was, with stories off', () {
    const c = AppControls.defaults;
    expect(c.on(Feature.stories), isFalse);
    expect(c.on(Feature.room) && c.on(Feature.sfx) && c.on(Feature.guest), isTrue);
    expect(c.billing.freeLevels, isNull, reason: "each level's own flag decides");
    expect(c.billing.needsPlus(testCourse.level(31)), testCourse.level(31).requiresSubscription);
    expect(c.billing.needsPlus(testCourse.level(5)), isFalse);
    expect(c.needsUpdate(appVersion), isFalse);
  });

  test('switches: on, off, and on with Likho Plus', () {
    final c = _controls(features: {'stories': 'plus', 'room': 'off'});
    expect(c.on(Feature.stories), isFalse);
    expect(c.on(Feature.stories, subscribed: true), isTrue);
    expect(c.on(Feature.room, subscribed: true), isFalse);
    expect(c.on('a-switch-from-a-newer-server'), isTrue);
  });

  test('levels need Plus as the billing says; the trial may open fewer', () {
    final c = _controls(billing: {'freeLevels': 5, 'trialLevels': 10});
    expect(c.billing.needsPlus(testCourse.level(5)), isFalse);
    expect(c.billing.needsPlus(testCourse.level(6)), isTrue);
    expect(c.billing.trialBlocks(testCourse.level(10)), isFalse);
    expect(c.billing.trialBlocks(testCourse.level(11)), isTrue);
    final free = _controls(billing: {'freeLevels': 5, 'plusFree': true});
    expect(free.billing.needsPlus(testCourse.level(100)), isFalse);
  });

  test('switched-off games are left out of a level, never all of it', () {
    final level = testCourse.level(2);
    final types = level.rounds.map((r) => r.type).toSet();
    expect(types, containsAll(['pop', 'write']));
    final c = _controls(extra: {'games': {'pop': false, 'match': false}});
    final played = c.playable(level);
    expect(played.rounds.map((r) => r.type), isNot(contains('pop')));
    expect(played.rounds.map((r) => r.type), contains('write'));
    expect(played.number, level.number);

    final everything = _controls(extra: {
      'games': {for (final t in ['pick', 'order', 'sounds', 'beats', 'connect', 'hunt', 'fix', 'sort', 'match', 'pop', 'truth']) t: false},
    });
    for (final l in testCourse.levels) {
      expect(everything.playable(l).rounds, isNotEmpty, reason: 'level ${l.number} keeps something to play');
    }
  });

  test('room items: hidden ones are gone, prices change', () {
    final c = _controls(extra: {
      'room': {
        'items': {
          'cap': {'hidden': false, 'price': 3},
          'crown': {'hidden': true, 'price': 40},
        },
      },
    });
    expect(c.item(ShopItem.byId('cap')!)!.price, 3);
    expect(c.item(ShopItem.byId('crown')!), isNull);
    expect(c.accessoryFor('crown'), isNull, reason: 'Pencil does not wear a hidden item');
    expect(c.accessoryFor('cap'), isNotNull);
  });

  test('versions compare by numbers and the build', () {
    expect(compareVersions('0.1.0+7', '0.1.0+7'), 0);
    expect(compareVersions('0.1.0+7', '0.1.0+8'), lessThan(0));
    expect(compareVersions('0.2.0', '0.1.9+99'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0'), 0);
    expect(_controls(extra: {'app': {'minVersion': '99.0.0'}}).needsUpdate(appVersion), isTrue);
    expect(_controls(extra: {'app': {'minVersion': '0.0.1'}}).needsUpdate(appVersion), isFalse);
  });

  test('the app follows the server, keeps the controls on the phone, and uses them offline', () async {
    final backend = FakeBackend()..config = _config(features: {'stories': 'on'});
    final files = MemoryFiles();
    var c = ProviderContainer(overrides: [...fakeBackendOverrides(backend, files: files), appControlsSyncProvider.overrideWithValue(const Duration(hours: 1))]);
    expect(c.read(appControlsProvider).on(Feature.stories), isFalse, reason: 'the defaults until the server answers');
    await c.read(authProvider.notifier).ready;
    for (var i = 0; i < 20 && !c.read(appControlsProvider).on(Feature.stories); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(c.read(appControlsProvider).on(Feature.stories), isTrue);
    expect(await files.read(AppControlsNotifier.file), isNotNull);

    // unchanged: a 304, nothing new
    final before = backend.calls.where((x) => x == 'GET /v1/config').length;
    await c.read(appControlsProvider.notifier).refresh(force: true);
    expect(backend.calls.where((x) => x == 'GET /v1/config').length, before + 1);
    expect(c.read(appControlsProvider).on(Feature.stories), isTrue);
    c.dispose();

    // next launch without internet: the saved controls
    backend.offline = true;
    c = ProviderContainer(overrides: [...fakeBackendOverrides(backend, files: files), appControlsSyncProvider.overrideWithValue(const Duration(hours: 1))]);
    c.read(appControlsProvider);
    for (var i = 0; i < 20 && !c.read(appControlsProvider).on(Feature.stories); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(c.read(appControlsProvider).on(Feature.stories), isTrue);
    c.dispose();
  });

  testWidgets('the map shows Stories and the room as the controls say', (t) async {
    Future<void> map(AppControls c) => _phone(t, const WorldMapScreen(onStories: _nothing, onRoom: _nothing), overrides: [
      courseProvider.overrideWith((ref) async => testCourse),
      familyProvider.overrideWith(DemoFamilyNotifier.new),
      appControlsProvider.overrideWith(() => FixedControls(c)),
    ]);

    await map(AppControls.defaults);
    expect(find.byKey(const ValueKey('stories-button')), findsNothing, reason: 'stories wait for the team');

    await map(_controls(features: {'stories': 'on'}));
    expect(find.byKey(const ValueKey('stories-button')), findsOneWidget);

    // no episode switched on: no button
    await map(_controls(features: {'stories': 'on'}, extra: {
      'stories': {
        'comingSoon': true,
        'episodes': {'a': 'off'},
      },
    }));
    expect(find.byKey(const ValueKey('stories-button')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the room shelf leaves out hidden items and shows the new prices', (t) async {
    await _phone(t, MascotRoomScreen(onBack: () {}), overrides: [
      courseProvider.overrideWith((ref) async => testCourse),
      familyProvider.overrideWith(DemoFamilyNotifier.new),
      appControlsProvider.overrideWith(() => FixedControls(_controls(extra: {
        'room': {
          'items': {
            'party': {'hidden': false, 'price': 2},
            'cap': {'hidden': true, 'price': 12},
          },
        },
      }))),
    ]);
    expect(find.text('Cap'), findsNothing);
    expect(find.text('Party hat'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('maintenance and "please update" cover the app', (t) async {
    Future<void> shell(AppControls c) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final key = GlobalKey<NavigatorState>();
      await t.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [familyProvider.overrideWith(DemoFamilyNotifier.new), appControlsProvider.overrideWith(() => FixedControls(c))],
        child: MaterialApp(
          navigatorKey: key,
          builder: (context, child) => AppShell(navigatorKey: key, child: child!),
          home: const Text('the app'),
        ),
      ));
      await _pumpFor(t, const Duration(milliseconds: 600));
    }

    await shell(_controls(extra: {'app': {'maintenance': {'on': true, 'title': 'Back soon', 'text': 'Fixing the swings.', 'id': 'x'}}}));
    expect(find.text('Back soon'), findsOneWidget);
    expect(find.text('Fixing the swings.'), findsOneWidget);

    await shell(_controls(extra: {'app': {'minVersion': '99.0.0'}}));
    expect(find.text('Time for an update!'), findsOneWidget);

    await shell(_controls());
    expect(find.text('Time for an update!'), findsNothing);
    expect(find.text('Back soon'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the paywall offers the plans and words the team chose', (t) async {
    await _phone(t, PaywallScreen(
      onClose: () {},
      onStartTrial: (_) {},
      onRestore: () {},
      rules: _controls(billing: {'yearly': false, 'bestValue': 'monthly', 'trialDays': 14, 'benefits': ['Stories every week']}).billing,
    ), overrides: [familyProvider.overrideWith(DemoFamilyNotifier.new)]);
    expect(find.text('Yearly'), findsNothing);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('BEST VALUE'), findsOneWidget);
    expect(find.text('Stories every week'), findsOneWidget);
    expect(find.text('Start 14-day free trial'), findsOneWidget);

    // no store and no free trial: nothing to start here
    await _phone(t, PaywallScreen(onClose: () {}, onStartTrial: (_) {}, onRestore: () {}, rules: _controls(billing: {'serverTrial': false}).billing),
        overrides: [familyProvider.overrideWith(DemoFamilyNotifier.new)]);
    expect(find.textContaining('free trial'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a level after the free ones opens the paywall', (t) async {
    await _phone(t, const SizedBox(), overrides: [
      courseProvider.overrideWith((ref) async => testCourse),
      familyProvider.overrideWith(DemoFamilyNotifier.new),
      appControlsProvider.overrideWith(() => FixedControls(_controls(billing: {'freeLevels': 5}))),
    ]);
    final ctx = t.element(find.byType(SizedBox).first);
    await t.runAsync(() => ProviderScope.containerOf(ctx).read(courseProvider.future));
    AppFlow.openLevel(ctx, 5);
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.byType(PaywallScreen), findsNothing, reason: 'level 5 is free');
    Navigator.of(ctx).popUntil((r) => r.isFirst);
    await _pumpFor(t, const Duration(milliseconds: 800));
    AppFlow.openLevel(ctx, 6);
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}

void _nothing() {}
