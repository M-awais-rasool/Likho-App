// flutter test --no-pub tool/home_preview/render_home.dart
// Renders the real map at several worlds, a transition and a compact phone.
// Output: build/home-preview/*.png. No backend or network required.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likho/data/api/likho_api.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/media.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/dev/reference_overlay.dart';
import 'package:likho/screens/app_flow.dart';
import 'package:likho/screens/world_map/map_geometry.dart';

import '../../test/test_course.dart';

class _PreviewMedia extends MediaStore {
  _PreviewMedia() : super(baseUrl: '', files: const LocalFiles());
  @override
  void prefetch(Iterable<String> paths) {}
}

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

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    ReferenceOverlay.enabled = false;
    await _fonts();
  });
  for (final shot in [
    ('meadow', 8, const Size(390, 844), false),
    ('autumn', 49, const Size(390, 844), false),
    ('night', 199, const Size(390, 844), false),
    ('transition', 16, const Size(390, 844), true),
    ('compact', 8, const Size(320, 640), false),
  ]) {
    testWidgets('home preview ${shot.$1}', (t) async {
      t.view.physicalSize = shot.$3 * 2;
      t.view.devicePixelRatio = 2;
      t.view.padding = const FakeViewPadding(top: 88, bottom: 48);
      addTearDown(t.view.reset);
      final demo = FamilyState.demo();
      final family = demo.copyWith(
        records: {
          ...demo.records,
          demo.activeId: demo.record.copyWith(levelStars: {for (var n = 1; n < shot.$2; n++) n: 3}),
        },
      );
      final key = GlobalKey();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            courseProvider.overrideWith((ref) => testCourse),
            familyProvider.overrideWith(() => DemoFamilyNotifier(family)),
            mediaProvider.overrideWithValue(_PreviewMedia()),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: likhoTheme(),
              home: Builder(builder: AppFlow.mapScreen),
            ),
          ),
        ),
      );
      for (var i = 0; i < 35; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      if (shot.$4) {
        final geometry = MapGeometry(shot.$3.width, levelsPerWorld: [for (final w in testCourse.worlds) testCourse.levelsOf(w).length]);
        final controller = t.widget<ListView>(find.byType(ListView)).controller!;
        controller.jumpTo(geometry.height - geometry.worldBottom(1) - shot.$3.height * .5);
        await t.pump(const Duration(milliseconds: 600));
      }
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pump();
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/home-preview/${shot.$1}.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }
}
