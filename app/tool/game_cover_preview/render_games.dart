// flutter test --no-pub tool/game_cover_preview/render_games.dart
// Renders the real cards with bundled artwork and local preview fonts.
// Output: build/game-cover-preview/*.png. No backend is needed.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likho/data/api/likho_api.dart';
import 'package:likho/data/app_controls.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/games.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/games/game_ui.dart';
import 'package:likho/screens/games/games_screen.dart';
import 'package:likho/screens/games/monster_defense/md_scene.dart';

import '../../test/fake_backend.dart';

Future<void> _fonts() async {
  for (final file in Directory('tool/store_screenshots/.fonts').listSync().whereType<File>()) {
    if (!file.path.endsWith('.ttf')) continue;
    final family = file.uri.pathSegments.last.replaceAll('.ttf', '');
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())))).load();
  }
  final home = Platform.environment['HOME'];
  final symbols = File('$home/.pub-cache/hosted/pub.dev/material_symbols_icons-4.2960.0/lib/fonts/MaterialSymbolsRounded.ttf');
  await (FontLoader('packages/material_symbols_icons/MaterialSymbolsRounded')..addFont(Future.value(ByteData.sublistView(symbols.readAsBytesSync())))).load();
}

Future<void> _save(WidgetTester t, GlobalKey key, String name) async {
  // Let asset decoding complete outside the test's fake clock.
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(t.takeException(), isNull);
  await t.runAsync(() async {
    final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/game-cover-preview/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _fonts();
  });

  for (final shot in [('iphone-15-plus', const Size(430, 932), 1.0), ('compact-large-text', const Size(320, 640), 1.3)]) {
    testWidgets('game posters ${shot.$1}', (t) async {
      t.view.physicalSize = shot.$2 * 2;
      t.view.devicePixelRatio = 2;
      t.view.padding = const FakeViewPadding(top: 100, bottom: 48);
      addTearDown(t.view.reset);
      final key = GlobalKey();
      String? opened;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            localFilesProvider.overrideWithValue(MemoryFiles()),
            familyProvider.overrideWith(() => DemoFamilyNotifier(FamilyState.demo().copyWith(subscribed: false))),
            appControlsProvider.overrideWith(
              () => FixedControls(
                AppControls.fromJson({
                  'gameList': {
                    'new': GameIds.all,
                    'modes': {'smash': 'plus'},
                  },
                }),
              ),
            ),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: likhoTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(shot.$3)),
                child: child!,
              ),
              home: GamesScreen(onOpen: (id) => opened = id),
            ),
          ),
        ),
      );
      await _save(t, key, '${shot.$1}-top');
      for (final id in GameIds.all) {
        final card = find.byKey(ValueKey('game-$id'));
        await Scrollable.ensureVisible(t.element(card), alignment: .15);
        await _save(t, key, '${shot.$1}-$id');
        final poster = find.descendant(of: card, matching: find.byType(Image)).first;
        final size = t.getSize(poster);
        expect(size.width / size.height, closeTo(1.5, .001), reason: 'full composition at every viewport size');
        await t.tap(poster);
        expect(opened, id, reason: 'poster still opens its game');
      }
      await t.pumpWidget(const SizedBox());
    });
  }

  for (final size in [const Size(430, 932), const Size(852, 393)]) {
    testWidgets('intro cover ${size.width}', (t) async {
      t.view.physicalSize = size * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: likhoTheme(),
            home: Scaffold(
              backgroundColor: const Color(0xFFB6DBAA),
              body: GameStartCard(
                id: 'md',
                title: 'Monster Defense',
                cover: MdArt.cover,
                hint: 'Catch the matching letter!',
                best: 0,
                onPlay: () {},
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      await _save(t, key, 'intro-${size.width.toInt()}');
      await t.pumpWidget(const SizedBox());
    });
  }
}
