// flutter test --no-pub tool/letter_slice_preview/render_slice.dart
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
import 'package:likho/game/letter_slice/ls_engine.dart';
import 'package:likho/screens/games/letter_slice/letter_slice_screen.dart';
import 'package:likho/screens/games/letter_slice/ls_scene.dart';

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

Future<void> _save(WidgetTester t, GlobalKey key, String name) async {
  expect(t.takeException(), isNull);
  await t.runAsync(() async {
    final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/letter-slice-preview/$name.png');
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
  for (final shot in [
    ('phone', const Size(430, 932), 1.0, LsTask.letter('B')),
    ('compact', const Size(320, 640), 1.3, LsTask.letter('m')),
    ('spelling', const Size(390, 844), 1.0, LsTask.spell('sun')),
    ('first-sound', const Size(320, 640), 1.3, LsTask.first('cat')),
    ('tablet', const Size(768, 1024), 1.0, LsTask.letter('B')),
  ]) {
    testWidgets('Letter Slice ${shot.$1}', (t) async {
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
              home: LetterSliceScreen(onDone: () {}, tasks: LsList([shot.$4]), random: math.Random(2)),
            ),
          ),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await _pump(t, 300);
      await _save(t, key, '${shot.$1}-start');
      final play = find.byKey(const ValueKey('ls-play'));
      await t.ensureVisible(play);
      await t.tap(play);
      await _pump(t, 4500);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      final state = t.state(find.byType(LetterSliceScreen)) as dynamic;
      final g = state.debugGame as LsGame;
      final view = state.debugView as LsView;
      final taskBottom = t.getBottomLeft(find.byKey(const ValueKey('ls-task'))).dy;
      expect(view.at(5, g.height).dy, greaterThan(taskBottom));
      g.flying.clear();
      g.score = 120;
      g.sliced = 12;
      g.got = 1;
      g.left = 54;
      final need = g.need!;
      for (final f in [
        (1, 'orange', 2.0, .68, need),
        (2, 'apple', 5.2, .52, need),
        (3, 'plum', 8.1, .72, shot.$4.spelling ? 's' : 'R'),
        (4, 'watermelon', 2.4, .27, 'A'),
        (5, 'peach', 7.7, .23, need),
      ]) {
        g.flying.add(
          LsFruit(id: 100 + f.$1, art: f.$2, kind: LsKind.fruit, x: f.$3, y: view.height * f.$4, vx: 0, vy: 0, spin: 0, r: LsGame.radius, letter: f.$5)
            ..born = g.time - 1,
        );
      }
      await _pump(t, 300);
      await _save(t, key, '${shot.$1}-playing');
      final fruit = g.flying.firstWhere((f) => f.letter == g.need);
      g.bladeDown(fruit.x - 1.3, fruit.y);
      g.bladeMove(fruit.x + 1.3, fruit.y, dt: .05);
      g.bladeUp();
      await _pump(t, 150);
      expect(fruit.cut, isTrue);
      await _save(t, key, '${shot.$1}-slice');
      await t.tap(find.byKey(const ValueKey('ls-pause')));
      await _pump(t, 300);
      await _save(t, key, '${shot.$1}-pause');
      await t.tap(find.byKey(const ValueKey('ls-resume')));
      await _pump(t, 200);
      g.flying.clear();
      g.left = .01;
      await _pump(t, 3000);
      expect(find.byKey(const ValueKey('ls-result')), findsOneWidget);
      await _save(t, key, '${shot.$1}-result');
      await t.pumpWidget(const SizedBox());
      await _pump(t, 100);
      debugDisableShadows = true;
    });
  }
}
