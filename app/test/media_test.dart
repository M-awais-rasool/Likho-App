import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:likho/data/media.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/feedback/pencil_lines.dart';
import 'package:likho/game/coach.dart';
import 'package:likho/mascot/lip_sync.dart';

import 'fake_backend.dart';
import 'test_course.dart';

/// The course's pictures and recordings come from the server's media folder
/// (made by tools/illustrations and tools/voice at the repository root, kept
/// in `media/`, not in git or the app). The checks against the folder run
/// where it exists (a developer's computer); the server checks it with
/// `go run ./cmd/content media-check`.
void main() {
  final folder = Directory('../media');
  final allMedia = {for (final l in [...testCourse.levels, ?testCourse.placement]) ...levelMedia(l)};

  test('every intro and prompt has a recording, and every level lists its media', () {
    for (final l in [...testCourse.levels, ?testCourse.placement]) {
      if (l.number > 0) expect(l.intro.audio, isNotNull, reason: 'level ${l.number} intro');
      for (final r in l.rounds) {
        expect(r.prompt.audio, isNotNull, reason: r.id);
        expect(levelMedia(l), containsAll([r.prompt.audio!, MediaStore.lipPath(r.prompt.audio!)]), reason: r.id);
      }
    }
    expect(allMedia.where((p) => p.startsWith('pictures/')).length, greaterThan(90));
    expect(allMedia.where((p) => p.endsWith('.m4a')).length, greaterThan(500));
  });

  test('the media folder has every picture and recording the course uses', () {
    final missing = [for (final p in allMedia) if (!File('${folder.path}/$p').existsSync()) p]..sort();
    expect(missing, isEmpty, reason: 'run tools/illustrations and tools/voice');
  }, skip: folder.existsSync() ? false : 'no media folder here (the server checks it)');

  test('Pencil\'s app lines are in the app, each with its mouth movement', () {
    for (final line in [...PencilLines.all, ...CoachLines.all]) {
      expect(File(line).existsSync(), isTrue, reason: '$line: run tools/voice/generate_voice.py --app');
      expect(File(LipSyncEnvelope.lipFileOf(line)).existsSync(), isTrue, reason: '$line has no .lip');
    }
    // the generator's list (its lock) and the app's are the same lines
    final lock = jsonDecode(File('../tools/voice/app_lines.lock.json').readAsStringSync()) as Map<String, dynamic>;
    final stories = {for (final k in lock.keys) if (k.startsWith('story_')) 'assets/voice/$k.m4a'}; // the stories' lines (story_a_test)
    expect({for (final k in lock.keys) 'assets/voice/$k.m4a'}.difference(stories), {...PencilLines.all, ...CoachLines.all});
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/voice/'));
  });

  test('device voice reads the shown part of a pronunciation', () {
    expect(spokenText('Trace small {a|ˈeɪ}.'), 'Trace small a.');
    expect(spokenText('Which letter says {/b/|bʌ}?'), 'Which letter says /b/?');
    expect(const Prompt(text: 'c _ t', say: 'Cat! Which letter is missing?').spoken, 'Cat! Which letter is missing?');
    expect(const Prompt(text: 'Find B!').spoken, 'Find B!');
  });

  test('a recording\'s mouth movement: one byte per 1/100 s', () {
    final env = LipSyncEnvelope.fromBytes(ByteData.sublistView(Uint8List.fromList([0, 255, 128])))!;
    expect(env.levelAt(Duration.zero), 0);
    expect(env.levelAt(const Duration(milliseconds: 15)), 1);
    expect(env.levelAt(const Duration(milliseconds: 25)), closeTo(.5, .01));
    expect(env.levelAt(const Duration(seconds: 1)), 0, reason: 'after the end: closed');
    expect(MediaStore.lipPath('voice/line-1.m4a'), 'voice/line-1.lip');
  });

  group('MediaStore', () {
    late Directory dir;
    late MemoryFiles files;
    var requests = <String>[];
    var online = true;
    var manifest = {'voice/a.m4a': 'aaaa', 'voice/a.lip': 'llll', 'pictures/cat.png': 'cccc'};

    MediaStore store() => MediaStore(
      baseUrl: 'http://api',
      files: files,
      cacheDir: () async => dir,
      client: MockClient((req) async {
        requests.add('${req.url.path}${req.url.hasQuery ? '?${req.url.query}' : ''}');
        if (!online) throw const SocketException('offline');
        if (req.url.path == '/v1/media') {
          final body = jsonEncode({'files': manifest});
          final etag = '"${body.hashCode}"';
          if (req.headers['If-None-Match'] == etag) return http.Response('', 304);
          return http.Response(body, 200, headers: {'etag': etag, 'content-type': 'application/json; charset=utf-8'});
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return http.Response.bytes(utf8.encode('bytes of ${req.url.path}'), 200);
      }),
    );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('likho_media');
      files = MemoryFiles();
      requests = [];
      online = true;
      manifest = {'voice/a.m4a': 'aaaa', 'voice/a.lip': 'llll', 'pictures/cat.png': 'cccc'};
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('downloads a file once, by its hash, and keeps it', () async {
      final m = store();
      await m.load();
      expect(m.url('pictures/cat.png'), 'http://api/media/pictures/cat.png?v=cccc');
      final (a, b) = await (m.local('pictures/cat.png'), m.local('pictures/cat.png')).wait;
      expect(a, '${dir.path}/cccc.png');
      expect(b, a);
      expect(File(a!).readAsStringSync(), 'bytes of /media/pictures/cat.png');
      expect(requests.where((r) => r.startsWith('/media/')).length, 1, reason: 'one download for both');

      // the next launch, offline: the saved manifest and the kept file
      online = false;
      final again = store();
      await again.load();
      expect(again.keptFile('pictures/cat.png'), a);
      expect(await again.local('voice/a.m4a'), isNull, reason: 'never downloaded, offline');
    });

    test('an unchanged manifest is not downloaded again; a changed file has a new name', () async {
      await store().load();
      requests.clear();
      final m = store();
      await m.load();
      expect(requests, ['/v1/media'], reason: 'asked with its ETag: 304');
      manifest = {...manifest, 'pictures/cat.png': 'dddd'};
      final fresh = store();
      await fresh.load();
      expect(await fresh.local('pictures/cat.png'), '${dir.path}/dddd.png');
    });

    test('a recording comes with its mouth movement; unknown files are null', () async {
      final m = store();
      await m.load();
      final voice = await m.voice('voice/a.m4a');
      expect(voice, ('${dir.path}/aaaa.m4a', '${dir.path}/llll.lip'));
      expect(await m.voice('voice/unknown.m4a'), isNull);
      expect(await m.voice('assets/audio/x.wav'), ('assets/audio/x.wav', null), reason: 'app assets play as they are');
    });

    test('prefetching downloads a few at a time', () async {
      manifest = {for (var i = 0; i < 12; i++) 'pictures/p$i.png': 'h$i'};
      final m = store();
      await m.load();
      m.prefetch(manifest.keys);
      await Future.wait([for (final p in manifest.keys) m.local(p)]);
      expect(dir.listSync().whereType<File>().where((f) => !f.path.contains('.part')).length, 12);
      expect(requests.where((r) => r.startsWith('/media/')).length, 12, reason: 'each file once');
    });
  });
}
