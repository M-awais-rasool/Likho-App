// flutter test --no-pub tool/smash_play_preview/render_smash.dart
// Captures the actual Flutter screen and painter, offline with local fonts.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/game/monster_smash/ms_engine.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:likho/screens/games/monster_smash/monster_smash_screen.dart';
import 'package:likho/screens/games/monster_smash/ms_crystal_art.dart';
import 'package:likho/screens/games/monster_smash/ms_heroes.dart';
import 'package:likho/screens/games/monster_smash/ms_scene.dart';

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
    final file = File('build/smash-play-preview/$name.png');
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

/// Uses the production renderer, so the audit exposes atlas clipping and
/// pose-to-pose scale changes rather than only checking the source sheets.
class _ArtAuditPainter extends CustomPainter {
  const _ArtAuditPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF5F0FC));
    const faces = [MsFace.idle, MsFace.ready, MsFace.yell, MsFace.power, MsFace.bonked, MsFace.happy];
    for (final hero in MsHero.values) {
      for (var p = 0; p < faces.length; p++) {
        final at = Offset(90 + p * 165, 76 + hero.index * 158);
        MsHeroArt.paint(canvas, hero, at, 29, MsHeroLook(face: faces[p]));
        _label(canvas, '${hero.name} · ${faces[p].name}', at + const Offset(-65, 61));
      }
    }
    final sheet = MsSprites.of(MsArt.crystalMonsters)!;
    const kinds = ['gloop', 'fuzz', 'bonk', 'boo'];
    const poses = ['idle', 'surprised', 'friendly'];
    for (var k = 0; k < kinds.length; k++) {
      for (var p = 0; p < poses.length; p++) {
        final src = MsCrystalArt.monster(kinds[k], poses[p]);
        final scale = 83 / src.height;
        final x = 80 + k * 250.0, y = 485 + p * 98.0;
        canvas.drawImageRect(sheet, src, Rect.fromLTWH(x - src.width * scale / 2, y, src.width * scale, 83), Paint()..filterQuality = FilterQuality.high);
        _label(canvas, '${kinds[k]}\n${poses[p]}', Offset(x + 62, y + 30));
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: LikhoFonts.body(size: 12, weight: FontWeight.w800, color: const Color(0xFF514477)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _ArtAuditPainter oldDelegate) => false;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _fonts();
  });
  for (final shot in [
    ('phone', const Size(932, 430), 1.0, 4, const EdgeInsets.only(left: 44, right: 44, bottom: 21)),
    ('compact', const Size(740, 360), 1.3, 2, const EdgeInsets.only(left: 24, bottom: 16)),
    ('tablet', const Size(1180, 820), 1.0, 7, const EdgeInsets.only(top: 24, bottom: 20)),
  ]) {
    testWidgets('Monster Smash ${shot.$1}', (t) async {
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
                data: MediaQuery.of(context).copyWith(padding: shot.$5, textScaler: TextScaler.linear(shot.$3)),
                child: child!,
              ),
              home: MonsterSmashScreen(onDone: () {}, level: MsLevels.letterLand[shot.$4], ownOrientation: false, asks: MsLetterList('BDPRMNEFHKST'), seed: 2),
            ),
          ),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 350)));
      await _pump(t, 600);
      await _save(t, key, '${shot.$1}-start');
      await t.tap(find.byKey(const ValueKey('ms-play')));
      await _pump(t, 2500);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await _save(t, key, '${shot.$1}-ready');
      final g = (t.state(find.byType(MonsterSmashScreen)) as dynamic).debugGame as MsGame;
      g.grab(MsGame.rest);
      g.drag(MsGame.rest + Vector2(-1.1, -.65));
      await _pump(t, 250);
      await _save(t, key, '${shot.$1}-aim');
      g.release();
      await _pump(t, 400);
      await _save(t, key, '${shot.$1}-flight');
      g.power();
      await _pump(t, 150);
      await _save(t, key, '${shot.$1}-power');
      await _pump(t, 1000);
      await t.tap(find.byKey(const ValueKey('ms-pause')));
      await _pump(t, 300);
      await _save(t, key, '${shot.$1}-pause');
      await t.pumpWidget(const SizedBox());
      await _pump(t, 100);
      debugDisableShadows = true;
    });
  }
  testWidgets('Crystal character poses', (t) async {
    _previewAssets(t);
    t.view.physicalSize = const Size(2040, 1560);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    MsSprites.load();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    for (final asset in MsArt.all) {
      expect(MsSprites.of(asset), isNotNull, reason: '$asset must decode');
    }
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const CustomPaint(painter: _ArtAuditPainter()),
      ),
    );
    await _save(t, key, 'character-poses');
    await t.pumpWidget(const SizedBox());
  });
}
