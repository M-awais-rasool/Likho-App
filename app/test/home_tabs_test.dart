import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/app_controls.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/app_flow.dart';
import 'package:likho/screens/games/games_screen.dart';
import 'package:likho/screens/parent/parent_gate.dart';
import 'package:likho/screens/stories/stories_screen.dart';

import 'test_course.dart';

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Home (the map with the bottom bar) with [features] and [tabBar] from
/// the server.
Future<void> _home(WidgetTester t, {Map<String, String> features = const {'stories': 'on'}, Map<String, dynamic>? tabBar}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final controls = AppControls.fromJson({
    'features': features,
    'stories': {
      'episodes': {'a': 'on'},
    },
    'tabBar': ?tabBar,
  });
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        courseProvider.overrideWith((ref) async => testCourse),
        familyProvider.overrideWith(DemoFamilyNotifier.new),
        appControlsProvider.overrideWith(() => FixedControls(controls)),
      ],
      child: MaterialApp(
        theme: likhoTheme(),
        navigatorObservers: [AppFlow.observer],
        home: const Builder(builder: AppFlow.mapScreen),
      ),
    ),
  );
  await _pumpFor(t, const Duration(milliseconds: 1500));
}

Finder _tab(String id) => find.byKey(ValueKey('tab-$id'));

void main() {
  test('the bottom bar keeps the order the team set and fills what is missing', () {
    final r = TabBarRules.fromJson({
      'style': 'island',
      'animation': 'pop',
      'speed': 'slow',
      'roundness': 90,
      'start': 'parents',
      'tabs': [
        {'id': 'games', 'shown': true, 'label': ' Play ', 'color': '#ff6fa8', 'badge': true},
        {'id': 'map', 'shown': false, 'label': 'Home', 'color': 'violet'},
        {'id': 'rockets', 'shown': true, 'label': 'Rockets', 'color': '#000000'},
        {'id': 'games', 'shown': false, 'label': 'Again', 'color': '#000000'},
      ],
    });
    expect(r.style, TabBarStyle.island);
    expect(r.animation, TabAnimation.pop);
    expect(r.speed, greaterThan(1));
    expect(r.roundness, 36);
    expect(r.start, TabIds.map, reason: 'Parents is behind the gate, never first');
    expect([for (final t in r.tabs) t.id], [TabIds.games, TabIds.map, TabIds.stories, TabIds.parents]);
    expect(r.tabs[0].label, 'Play');
    expect(r.tabs[0].color, const Color(0xFFFF6FA8));
    expect(r.tabs[1].shown, isTrue, reason: 'Map always shows');
    expect(r.tabs[1].color, LikhoColors.primary, reason: 'a bad colour keeps the default');

    // an older server sends no bar: the app's own
    final old = TabBarRules.fromJson(const {});
    expect(old.style, TabBarStyle.candy);
    expect([for (final t in old.tabs) t.id], TabIds.all);
  });

  testWidgets('Stories and Games open as tabs; the map loses their buttons and Settings', (t) async {
    await _home(t);
    for (final id in TabIds.all) {
      expect(_tab(id), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('stories-button')), findsNothing);
    expect(find.byKey(const ValueKey('games-button')), findsNothing);

    await t.tap(_tab(TabIds.games));
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(t.widget<GamesScreen>(find.byType(GamesScreen)).onBack, isNull, reason: 'a tab has no back button');

    await t.tap(_tab(TabIds.stories));
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.byType(StoriesScreen), findsOneWidget);

    // back on a tab goes to the map first
    await t.binding.handlePopRoute();
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.byType(StoriesScreen).hitTestable(), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Parents asks for the parent gate', (t) async {
    await _home(t);
    await t.tap(_tab(TabIds.parents));
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(find.byType(ParentGate), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a tab the bar leaves out gets its button back on the map', (t) async {
    await _home(
      t,
      features: const {'stories': 'off'},
      tabBar: {
        'style': 'jelly',
        'tabs': [
          {'id': 'map', 'shown': true, 'label': 'Map', 'color': '#FFC83D'},
          {'id': 'games', 'shown': false, 'label': 'Games', 'color': '#7C5CFF'},
          {'id': 'parents', 'shown': true, 'label': 'Parents', 'color': '#3BB273'},
        ],
      },
    );
    expect(_tab(TabIds.stories), findsNothing, reason: 'the Stories switch is off');
    expect(_tab(TabIds.games), findsNothing);
    expect(_tab(TabIds.parents), findsOneWidget);
    expect(find.byKey(const ValueKey('games-button')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('with only Map left there is no bar and Settings is back on the map', (t) async {
    await _home(
      t,
      features: const {'stories': 'off', 'games': 'off'},
      tabBar: {
        'tabs': [
          {'id': 'map', 'shown': true, 'label': 'Map', 'color': '#FFC83D'},
          {'id': 'parents', 'shown': false, 'label': 'Parents', 'color': '#3BB273'},
        ],
      },
    );
    expect(_tab(TabIds.map), findsNothing);
    expect(find.byIcon(Symbols.settings_rounded), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
