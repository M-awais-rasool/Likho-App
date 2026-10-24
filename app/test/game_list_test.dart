import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/api/likho_api.dart';
import 'package:likho/data/app_controls.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/games.dart';
import 'package:likho/data/story.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/app_flow.dart';
import 'package:likho/screens/parent/paywall_screen.dart';

import 'fake_backend.dart';
import 'test_course.dart';

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

AppControls _controls(Map<String, dynamic> gameList, {Map<String, dynamic> stories = const {}}) => AppControls.fromJson({
  'features': {'stories': 'on'},
  'stories': {
    'episodes': {'a': 'on'},
    ...stories,
  },
  'gameList': gameList,
});

ProviderContainer _container(AppControls c, {bool plus = false}) {
  final container = ProviderContainer(
    overrides: [
      localFilesProvider.overrideWithValue(MemoryFiles()),
      familyProvider.overrideWith(() => DemoFamilyNotifier(FamilyState.demo().copyWith(subscribed: plus))),
      appControlsProvider.overrideWith(() => FixedControls(c)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('games follow the team: order, off, Plus-only and NEW', () {
    final c = _controls({
      'order': ['slice', 'smash'],
      'modes': {'runner': 'off', 'smash': 'plus'},
      'new': ['smash', 'monsters'],
    });
    final free = _container(c);
    expect(free.read(shownGamesProvider), [GameIds.slice, GameIds.smash, GameIds.monsters], reason: 'ordered, the rest after, Spell Runner off');
    expect(c.playGameOn(GameIds.smash), isFalse, reason: 'Plus-only: shown with a lock');
    expect(c.playGameOn(GameIds.smash, subscribed: true), isTrue);
    expect(free.read(newGamesProvider), {GameIds.smash, GameIds.monsters});
    expect(free.read(gamesShownProvider), isTrue);

    // nothing left to show: no Games
    final none = _container(
      _controls({
        'modes': {for (final id in GameIds.all) id: 'off'},
      }),
    );
    expect(none.read(gamesShownProvider), isFalse);

    // an older server sends no list: every game, in the app's order
    final old = _container(AppControls.fromJson(const {}));
    expect(old.read(shownGamesProvider), GameIds.all);
    expect(old.read(newGamesProvider), isEmpty);
  });

  test('NEW goes away once the child has played the game or the story', () async {
    final c = _container(
      _controls(
        {
          'new': [GameIds.runner],
        },
        stories: {
          'new': ['a'],
        },
      ),
    );
    expect(c.read(newGamesProvider), {GameIds.runner});
    expect(c.read(newEpisodesProvider), {'a'});
    c.read(gameProgressProvider.notifier).record(c.read(familyProvider).active.id, GameIds.runner, score: 10, stars: 1);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(newGamesProvider), isEmpty);
  });

  testWidgets('the Games tab shows the team order with NEW and the Plus lock; a locked game opens the paywall', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          courseProvider.overrideWith((ref) async => testCourse),
          familyProvider.overrideWith(() => DemoFamilyNotifier(FamilyState.demo().copyWith(subscribed: false))),
          appControlsProvider.overrideWith(
            () => FixedControls(
              _controls({
                'order': ['smash', 'slice'],
                'modes': {'smash': 'plus', 'monsters': 'off', 'runner': 'off'},
                'new': ['slice'],
              }),
            ),
          ),
        ],
        child: MaterialApp(
          theme: likhoTheme(),
          navigatorObservers: [AppFlow.observer],
          home: const Builder(builder: AppFlow.mapScreen),
        ),
      ),
    );
    await _pumpFor(t, const Duration(milliseconds: 1500));
    await t.tap(find.byKey(const ValueKey('tab-games')));
    await _pumpFor(t, const Duration(milliseconds: 800));

    expect(find.byKey(const ValueKey('game-monsters')), findsNothing);
    final smash = t.getTopLeft(find.byKey(const ValueKey('game-smash')));
    final slice = t.getTopLeft(find.byKey(const ValueKey('game-slice')), warnIfMissed: false);
    expect(smash.dy, lessThan(slice.dy), reason: 'Monster Smash is at the top');
    expect(find.descendant(of: find.byKey(const ValueKey('game-smash')), matching: find.byKey(const ValueKey('plus-tag'))), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('game-slice')), matching: find.byKey(const ValueKey('new-tag'))), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('game-smash')));
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.byType(PaywallScreen), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
