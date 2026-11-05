// flutter test --no-pub tool/smash_map_preview/render_map.dart
// The actual Flutter map, with bundled artwork and local fonts. No backend.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likho/data/games.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/games/monster_smash/smash_levels_screen.dart';

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

/// Expose the existing local preview fonts under Google Fonts' asset names.
/// This keeps capture runs offline without changing the production bundle.
void _previewAssets(WidgetTester tester) {
  const weights = {'regular': 'Regular', '500': 'Medium', '600': 'SemiBold', '700': 'Bold', '800': 'ExtraBold', '900': 'Black'};
  final aliases = <String, File>{};
  for (final file in Directory('tool/store_screenshots/.fonts').listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last.replaceAll('.ttf', '').split('_');
    if (name.length == 2 && weights.containsKey(name.last)) {
      aliases['preview-fonts/${name.first}-${weights[name.last]}.ttf'] = file;
    }
  }
  const codec = StandardMessageCodec();
  final manifest = Map<Object?, Object?>.from(
    codec.decodeMessage(ByteData.sublistView(File('build/unit_test_assets/AssetManifest.bin').readAsBytesSync())) as Map,
  );
  for (final name in aliases.keys) {
    manifest[name] = [
      {'asset': name},
    ];
  }
  tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
    final asset = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
    if (asset == 'AssetManifest.bin') return codec.encodeMessage(manifest);
    final file = aliases[asset] ?? File('build/unit_test_assets/$asset');
    return file.existsSync() ? ByteData.sublistView(file.readAsBytesSync()) : null;
  });
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _fonts();
  });

  for (final shot in [
    ('first-flight', const Size(932, 430), 0, 1.0, const EdgeInsets.only(left: 44, right: 44, bottom: 21)),
    ('cloud-hop', const Size(932, 430), 6, 1.0, const EdgeInsets.only(left: 44, right: 44, bottom: 21)),
    ('small-phone', const Size(667, 375), 0, 1.0, EdgeInsets.zero),
    ('compact-large-text', const Size(740, 360), 6, 1.3, const EdgeInsets.only(left: 24, bottom: 16)),
    ('tablet', const Size(1180, 820), 0, 1.0, const EdgeInsets.only(top: 24, bottom: 20)),
    ('portrait-transition', const Size(390, 844), 0, 1.3, const EdgeInsets.only(top: 44, bottom: 34)),
    ('all-complete', const Size(932, 430), 12, 1.0, EdgeInsets.zero),
  ]) {
    testWidgets('Crystal Sky ${shot.$1}', (t) async {
      _previewAssets(t);
      t.view.physicalSize = shot.$2 * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            myGamesProvider.overrideWithValue({
              GameIds.smash: GameRecord(levels: {for (var i = 1; i <= shot.$3; i++) i: i.isOdd ? 3 : 2}),
            }),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: likhoTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(shot.$4), padding: shot.$5, disableAnimations: true),
                child: child!,
              ),
              home: SmashLevelsScreen(onDone: () {}),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/smash-map-preview/${shot.$1}.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await t.pumpWidget(const SizedBox());
    });
  }
}
