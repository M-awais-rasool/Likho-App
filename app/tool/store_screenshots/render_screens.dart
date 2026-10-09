// Renders real Likho screens for the store screenshots: the app's own
// widgets with the sample family, the bundled course, the course pictures
// from ../media and the real fonts. Run from app/:
//
//   flutter test tool/store_screenshots/render_screens.dart
//
// Writes 1170 x 2532 PNGs (a 390 x 844 phone at 3x) into
// ../design/store-screenshots/screens/. compose.html frames them.
import 'dart:convert';
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
import 'package:likho/data/models/course_models.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/dev/dev_launch.dart';
import 'package:likho/dev/reference_overlay.dart';
import 'package:likho/screens/app_flow.dart';
import 'package:likho/screens/app_shell.dart';
import 'package:likho/screens/gameplay/gameplay_screen.dart';
import 'package:likho/screens/gameplay/rounds/write_round_view.dart';

const _phone = Size(390, 844);
const _dpr = 3.0;
const _top = 44.0; // status bar
const _bottom = 24.0; // gesture bar
final _out = Directory('../design/store-screenshots/screens');
final _media = Directory('../media').absolute.path;
final Course _course = Course.fromJson(jsonDecode(File('test/fixtures/english-handwriting.json').readAsStringSync()) as Map<String, dynamic>);

/// The course pictures straight from ../media (no server).
class _LocalMedia extends MediaStore {
  _LocalMedia() : super(baseUrl: '', files: const LocalFiles());
  String? _file(String path) => File('$_media/$path').existsSync() ? '$_media/$path' : null;
  @override
  String? hashOf(String path) => _file(path) == null ? null : 'local';
  @override
  String? keptFile(String path) => _file(path);
  @override
  Future<void> load() async {}
  @override
  void prefetch(Iterable<String> paths) {}
  @override
  Future<(String, String?)?> voice(String audio, {Duration wait = const Duration(seconds: 4)}) async => null;
}

Future<void> _fonts() async {
  final dir = Directory('tool/store_screenshots/.fonts');
  final byFamily = <String, FontLoader>{};
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    final family = f.uri.pathSegments.last.replaceAll('.ttf', '');
    (byFamily[family] ??= FontLoader(family)).addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  final home = Platform.environment['HOME'];
  final symbols = File('$home/.pub-cache/hosted/pub.dev/material_symbols_icons-4.2960.0/lib/fonts/MaterialSymbolsRounded.ttf');
  byFamily['packages/material_symbols_icons/MaterialSymbolsRounded'] = FontLoader('packages/material_symbols_icons/MaterialSymbolsRounded')
    ..addFont(Future.value(ByteData.sublistView(symbols.readAsBytesSync())));
  final roboto = File('${Platform.environment['FLUTTER_ROOT'] ?? '$home/development/flutter'}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  if (roboto.existsSync()) {
    byFamily['Roboto'] = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(roboto.readAsBytesSync())));
  }
  for (final l in byFamily.values) {
    await l.load();
  }
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Lets real file IO (pictures) finish, then draws again.
Future<void> _settleImages(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await t.pump(const Duration(milliseconds: 50));
  }
}

final _shot = GlobalKey();

Future<void> _save(WidgetTester t, String name) async {
  await _settleImages(t);
  await t.runAsync(() async {
    final boundary = _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    _out.createSync(recursive: true);
    File('${_out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
  });
}

/// The app (sample family, local course + media) showing [home].
Future<ProviderContainer> _app(WidgetTester t, Widget home, {FamilyState? family}) async {
  t.view.physicalSize = _phone * _dpr;
  t.view.devicePixelRatio = _dpr;
  t.view.padding = FakeViewPadding(top: _top * _dpr, bottom: _bottom * _dpr);
  t.view.viewPadding = FakeViewPadding(top: _top * _dpr, bottom: _bottom * _dpr);
  addTearDown(t.view.reset);
  final container = ProviderContainer(overrides: [
    courseProvider.overrideWith((ref) => _course),
    mediaProvider.overrideWithValue(_LocalMedia()),
    familyProvider.overrideWith(() => DemoFamilyNotifier(family)),
  ]);
  addTearDown(container.dispose);
  await t.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: _shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: likhoTheme(),
        navigatorKey: AppFlow.navigatorKey,
        navigatorObservers: [AppFlow.observer],
        builder: (context, child) => AppShell(navigatorKey: AppFlow.navigatorKey, child: child!),
        home: home,
      ),
    ),
  ));
  await container.read(courseProvider.future);
  await t.pump();
  return container;
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await _pumpFor(t, const Duration(seconds: 3));
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    ReferenceOverlay.enabled = false;
    await _fonts();
  });

  final screens = (Platform.environment['SCREENS'] ?? 'map,welcome,whos,complete,boss,room,profile,stickers,dashboard,course,certificate,placementDone,sessionEnd,paywall')
      .split(',')
      .where((s) => s.isNotEmpty);
  for (final key in screens) {
    testWidgets('screen $key', (t) async {
      await _app(t, DevScreenLauncher(screen: key));
      await _pumpFor(t, const Duration(milliseconds: 2500));
      await _save(t, key);
      await _close(t);
    });
  }

  final levels = (Platform.environment['LEVELS'] ?? '').split(',').where((s) => s.isNotEmpty).map(int.parse);
  for (final n in levels) {
    testWidgets('level $n', (t) async {
      await _app(t, GameplayScreen(level: _course.level(n), onExit: () {}, onFinished: (_) {}));
      await _pumpFor(t, const Duration(milliseconds: 2500));
      await _save(t, 'level-$n');
      await _close(t);
    });
  }

  // One round of a level, mid-play: (name, level, round index, strokes to trace).
  const rounds = [
    ('trace-A', 1, 1, 1.55),
    ('trace-l', 45, 1, .6),
    ('pick-cat', 70, 2, 0.0),
    ('order-bed', 70, 3, 0.0),
    ('match-ee', 85, 5, 0.0),
    ('sort-lk', 45, 5, 0.0),
    ('pop-b', 2, 0, 0.0),
    ('hunt-c', 3, 4, 0.0),
    ('truth-f', 7, 2, 0.0),
    ('spell-you', 100, 3, 0.0),
  ];
  final only = (Platform.environment['ROUNDS'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();
  for (final (name, n, i, strokes) in rounds) {
    if (only.isNotEmpty && !only.contains(name)) continue;
    testWidgets('round $name', (t) async {
      final level = _course.level(n);
      final one = CourseLevel(
        id: level.id, number: level.number, worldId: level.worldId, placement: level.placement, name: level.name, skill: level.skill,
        icon: level.icon, isBoss: level.isBoss, requiresSubscription: level.requiresSubscription, intro: level.intro,
        presentation: level.presentation, rounds: [level.rounds[i], ...level.rounds.skip(i + 1)],
      );
      await _app(t, GameplayScreen(level: one, onExit: () {}, onFinished: (_) {}));
      await _pumpFor(t, const Duration(milliseconds: 2600));
      if (strokes > 0) {
        final pad = find.byType(WritePad);
        final origin = t.getTopLeft(pad);
        final lane = t.widget<WritePad>(pad).controller.lane!.strokes;
        var left = strokes;
        for (final s in lane) {
          if (left <= 0) break;
          final upto = left >= 1 ? s.length : (s.length * left).round();
          final g = await t.startGesture(origin + s.first);
          for (var k = 2; k < upto; k += 2) {
            await g.moveTo(origin + s[k]);
          }
          await g.moveTo(origin + s[upto - 1]);
          await t.pump(const Duration(milliseconds: 30));
          if (left >= 1) {
            await g.up();
            await _pumpFor(t, const Duration(milliseconds: 1400));
          } else {
            await _pumpFor(t, const Duration(milliseconds: 300));
            await _save(t, name);
            await g.up();
          }
          left -= 1;
        }
        if (strokes == strokes.floorToDouble()) await _save(t, name);
      } else {
        await _save(t, name);
      }
      await _close(t);
    });
  }
}
