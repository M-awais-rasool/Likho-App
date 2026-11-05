// flutter test --no-pub tool/spell_runner_preview/render_runner.dart
// Captures the actual Flutter screen and painter, offline with local fonts.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/game/spell_runner/sr_engine.dart';
import 'package:likho/screens/games/spell_runner/spell_runner_screen.dart';

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
  final manifest = Map<Object?, Object?>.from(codec.decodeMessage(ByteData.sublistView(File('build/unit_test_assets/AssetManifest.bin').readAsBytesSync())) as Map);
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

Future<void> _save(WidgetTester t, GlobalKey key, String name) async {
  expect(t.takeException(), isNull);
  await t.runAsync(() async {
    final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/spell-runner-preview/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _pump(WidgetTester t, int ms) async {
  for (var i = 0; i < ms; i += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _fonts();
  });
  for (final shot in [('phone', const Size(390, 844), 1.0, 'cat'), ('compact', const Size(320, 640), 1.3, 'pencil'), ('tablet', const Size(768, 1024), 1.0, 'sun')]) {
    testWidgets('Spell Runner ${shot.$1}', (t) async {
      _previewAssets(t);
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
      t.view.physicalSize = shot.$2 * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(
        ProviderScope(
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: likhoTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(shot.$3), padding: const EdgeInsets.only(top: 44, bottom: 24)),
                child: child!,
              ),
              home: SpellRunnerScreen(onDone: () {}, tasks: SrList([SrTask.spell(shot.$4)]), random: math.Random(2)),
            ),
          ),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 350)));
      await _pump(t, 500);
      await _save(t, key, '${shot.$1}-start');
      await t.tap(find.byKey(const ValueKey('sr-play')));
      await _pump(t, 6000);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      final g = (t.state(find.byType(SpellRunnerScreen)) as dynamic).debugGame as SrGame;
      g.things.clear();
      for (final thing in [
        SrThing(id: 900, kind: SrKind.letter, lane: -1, z: g.dist + 6, label: 'c'),
        SrThing(id: 901, kind: SrKind.letter, lane: 0, z: g.dist + 6, label: 'a'),
        SrThing(id: 902, kind: SrKind.letter, lane: 1, z: g.dist + 6, label: 'b'),
        SrThing(id: 903, kind: SrKind.bar, lane: -1, z: g.dist + 14),
        SrThing(id: 904, kind: SrKind.cone, lane: 1, z: g.dist + 13),
        for (var i = 0; i < 5; i++) SrThing(id: 910 + i, kind: SrKind.coin, lane: 0, z: g.dist + 12 + i * 3),
      ]) {
        g.things.add(thing);
      }
      await _pump(t, 50);
      await _save(t, key, '${shot.$1}-playing');
      await t.tap(find.byKey(const ValueKey('sr-jump')));
      await _pump(t, 300);
      await _save(t, key, '${shot.$1}-jump');
      await _pump(t, 900);
      await t.tap(find.byKey(const ValueKey('sr-slide')));
      await _pump(t, 160);
      await _save(t, key, '${shot.$1}-slide');
      await _pump(t, 800);
      g.things.clear();
      g.moveTo(1);
      await _pump(t, 100);
      await _save(t, key, '${shot.$1}-turn');
      await _pump(t, 500);
      await t.tap(find.byKey(const ValueKey('sr-pause')));
      await _pump(t, 400);
      await _save(t, key, '${shot.$1}-pause');
      await t.tap(find.byKey(const ValueKey('sr-resume')));
      await _pump(t, 300);
      g.things.clear();
      g.hearts = 1;
      g.safe = 0;
      g.things.add(SrThing(id: 10000, kind: SrKind.cart, lane: g.targetLane, z: g.dist + .2));
      await _pump(t, 3200);
      expect(find.byKey(const ValueKey('sr-result')), findsOneWidget);
      await _save(t, key, '${shot.$1}-result');
      await t.pumpWidget(const SizedBox());
      await _pump(t, 100);
      debugDisableShadows = true;
    });
  }
}
