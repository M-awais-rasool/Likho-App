// Render the real Letter A lesson, offline. Run with flutter test --no-pub.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/level_intro/level_intro_screen.dart';
import 'package:likho/screens/level_complete/level_complete_screen.dart';

import '../../test/test_course.dart';
import '../../test/apple_garden_test.dart' show gardenAnswer;

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
    final file = File('build/apple-garden-preview/$name.png');
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
  for (final size in [const Size(390, 844), const Size(320, 640), const Size(768, 1024)]) {
    testWidgets('capture Apple Garden ${size.width}', (t) async {
      _previewAssets(t);
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
      t.view.physicalSize = size * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      final level = testCourse.level(1);
      Widget app(Widget screen) => ProviderScope(
        overrides: [courseProvider.overrideWith((ref) => testCourse)],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: likhoTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.width == 320 ? 1.3 : 1), padding: const EdgeInsets.only(top: 44, bottom: 24)),
              child: child!,
            ),
            home: screen,
          ),
        ),
      );
      Future<void> shot(String name) async {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await _pump(t, 100);
        await _save(t, key, '${size.width.toInt()}-$name');
      }

      await t.pumpWidget(app(LevelIntroScreen(level: level, onDone: () {})));
      await _pump(t, 2500);
      await shot('welcome');
      await t.pumpWidget(app(GameplayScreen(level: level, onExit: () {}, onFinished: (_) {})));
      await _pump(t, 500);
      for (var i = 0; i < level.rounds.length; i++) {
        await shot('round-${i + 1}');
        await gardenAnswer(t, level.rounds[i]);
        if (i == 0) await shot('apple-earned');
        await _pump(t, 2050);
      }
      await t.pumpWidget(
        app(LevelCompleteScreen(level: level, outcome: const LevelOutcome(level: 1, stars: 3, gain: 3, firstTime: true), onAgain: () {}, onNext: () {})),
      );
      await _pump(t, 2200);
      await shot('harvest');
      await t.pumpWidget(const SizedBox());
      debugDisableShadows = true;
    });
  }
}
