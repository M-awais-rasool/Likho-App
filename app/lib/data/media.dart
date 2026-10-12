import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api/api_client.dart';
import 'api/likho_api.dart';
import 'models/course_models.dart';

/// The course's pictures and recordings, from the server (they are not in
/// the app). A media path is relative to the server's media folder:
/// "voice/line-3f0c….m4a", "pictures/cat.png" ([picturePath]).
///
/// * The manifest (GET /v1/media: path -> hash of the file) is kept on the
///   phone like the course: the saved copy is used at once, a newer one is
///   picked up within [freshWait], and the ETag means an unchanged
///   manifest is never downloaded again.
/// * A file is downloaded once from `/media/<path>?v=<hash>` and kept on the
///   phone under its hash ([cacheDir]): a changed picture has a new hash,
///   so nothing is ever stale and nothing needs asking again. Offline, the
///   kept files play as usual.
/// * [prefetch] downloads the next levels' files in the background (a few
///   at a time) so a level starts without waiting; [local] gets one file
///   now, downloading it if needed.
/// * On the web (the admin panel's preview) nothing is kept: [url] is used.
class MediaStore {
  MediaStore({required this.baseUrl, required this.files, http.Client? client, Future<Directory?> Function()? cacheDir, this.freshWait = const Duration(milliseconds: 1500)})
      : _client = client ?? http.Client(),
        _cacheDir = cacheDir ?? _defaultCacheDir;

  final String baseUrl;
  final LocalFiles files;
  final Duration freshWait;
  final http.Client _client;
  final Future<Directory?> Function() _cacheDir;

  static const manifestFile = 'media.json', etagFile = 'media.etag';

  /// Downloads at the same time (prefetching and asked-for files together).
  static const parallel = 4;

  Map<String, String> _hashes = const {};
  Directory? _dir;
  final Set<String> _kept = {}; // file names in the cache folder
  final Map<String, Future<String?>> _inFlight = {};
  final Queue<(String, Completer<String?>)> _waiting = Queue();
  int _running = 0;

  static Future<Directory?> _defaultCacheDir() async {
    if (kIsWeb) return null;
    try {
      return Directory('${(await getApplicationSupportDirectory()).path}/media');
    } catch (_) {
      return null; // tests: no platform folders
    }
  }

  /// A picture key's media path.
  static String picturePath(String key) => 'pictures/$key.png';

  /// The mouth-movement file next to a recording.
  static String lipPath(String audio) => audio.replaceFirst(RegExp(r'\.[^./]+$'), '.lip');

  /// Paths in the manifest.
  int get length => _hashes.length;
  String? hashOf(String path) => _hashes[path];

  /// Where the server has [path] (with its hash, so the URL never changes).
  String url(String path) => '$baseUrl/media/$path${_hashes[path] == null ? '' : '?v=${_hashes[path]}'}';

  // ------------------------------------------------------------ manifest

  Future<void>? _loading;

  /// Reads the manifest (saved copy at once, a fresh one when it comes in
  /// time) and the list of kept files, once. Never throws: without a
  /// manifest pictures show placeholders and the device voice reads the lines.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    _dir = await _cacheDir();
    final dir = _dir;
    if (dir != null) {
      try {
        if (dir.existsSync()) _kept.addAll(dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last));
      } catch (_) {}
    }
    final cached = await files.read(manifestFile);
    if (cached != null) _use(cached);
    final fetch = _download(cached == null ? null : await files.read(etagFile));
    try {
      final fresh = await (cached == null ? fetch : fetch.timeout(freshWait));
      if (fresh != null) _use(fresh);
    } catch (_) {
      // slow or offline: the saved copy; a newer one is kept for next time
      unawaited(fetch.then((fresh) => fresh == null ? null : _use(fresh)).catchError((Object _) {}));
    }
  }

  void _use(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      _hashes = {for (final e in (j['files'] as Map<String, dynamic>).entries) e.key: e.value as String};
    } catch (_) {}
  }

  Future<String?> _download(String? etag) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/v1/media'), headers: {'If-None-Match': ?etag})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      await files.write(manifestFile, res.body);
      final tag = res.headers['etag'];
      if (tag != null) await files.write(etagFile, tag);
      return res.body;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ files

  String? _name(String path) {
    final hash = _hashes[path];
    if (hash == null) return null;
    final dot = path.lastIndexOf('.');
    return '$hash${dot < 0 ? '' : path.substring(dot)}';
  }

  /// The kept copy of [path] if it is on the phone already (no waiting).
  String? keptFile(String path) {
    final name = _name(path), dir = _dir;
    return name != null && dir != null && _kept.contains(name) ? '${dir.path}/$name' : null;
  }

  /// [path] on the phone, downloaded first if needed; null when it cannot
  /// be had (offline, unknown, the web).
  Future<String?> local(String path) {
    final kept = keptFile(path);
    if (kept != null) return Future.value(kept);
    if (_name(path) == null || _dir == null) return Future.value(null);
    return _inFlight[path] ??= _enqueue(path, first: true);
  }

  /// A course recording ready to play: (file on the phone, its .lip file),
  /// or (URL, null) on the web; null when it cannot be had in [wait].
  Future<(String, String?)?> voice(String audio, {Duration wait = const Duration(seconds: 4)}) async {
    if (audio.startsWith('assets/') || audio.startsWith('http')) return (audio, null);
    if (kIsWeb) return _hashes.containsKey(audio) ? (url(audio), null) : null;
    try {
      final (file, lip) = await (local(audio), local(lipPath(audio))).wait.timeout(wait);
      return file == null ? null : (file, lip);
    } catch (_) {
      return null; // too slow: the device voice reads it this time (the download goes on)
    }
  }

  /// Downloads [paths] in the background, a few at a time.
  void prefetch(Iterable<String> paths) {
    for (final p in paths) {
      if (keptFile(p) == null && _name(p) != null && _dir != null && !_inFlight.containsKey(p)) {
        _inFlight[p] = _enqueue(p);
      }
    }
  }

  /// The files [level] shows and plays.
  void prefetchLevel(CourseLevel level) => prefetch(levelMedia(level));

  /// Waits its turn (asked-for files go first), then downloads [path].
  Future<String?> _enqueue(String path, {bool first = false}) {
    final job = (path, Completer<String?>());
    first ? _waiting.addFirst(job) : _waiting.addLast(job);
    _pump();
    // a block body: remove() returns this very future, which must not be awaited by itself
    return job.$2.future.whenComplete(() {
      _inFlight.remove(path);
    });
  }

  void _pump() {
    while (_running < parallel && _waiting.isNotEmpty) {
      final (path, done) = _waiting.removeFirst();
      _running++;
      _fetch(path).then(done.complete).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  Future<String?> _fetch(String path) async {
    final name = _name(path), dir = _dir;
    if (name == null || dir == null) return null;
    try {
      final res = await _client.get(Uri.parse(url(path))).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      await dir.create(recursive: true);
      // write then rename: a half-written file is never taken for a kept one
      final tmp = File('${dir.path}/.$name.part');
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      final file = await tmp.rename('${dir.path}/$name');
      _kept.add(name);
      return file.path;
    } catch (e) {
      debugPrint('MediaStore: $path: $e');
      return null;
    }
  }
}

/// Every media path [level] uses: recordings (and their mouth movement),
/// the intro's and the rounds' pictures, story strips and story choices.
List<String> levelMedia(CourseLevel level) {
  final out = <String>{};
  void audio(String? a) {
    if (a == null || a.startsWith('http') || a.startsWith('assets/')) return;
    out
      ..add(a)
      ..add(MediaStore.lipPath(a));
  }

  void picture(Picture? p) {
    if (p != null && p.url == null) out.add(MediaStore.picturePath(p.key));
  }

  audio(level.intro.audio);
  picture(level.intro.picture);
  for (final r in level.rounds) {
    audio(r.prompt.audio);
    picture(r.card?.picture);
    switch (r) {
      case PickRound(:final options, :final choiceKey):
        for (final o in options) {
          picture(o.picture);
          if (choiceKey != null) out.add(MediaStore.picturePath(o.label));
        }
      case OrderRound(:final tiles, :final slot) when (slot ?? level.presentation.slot) == 'panel':
        out.addAll(tiles.map((t) => MediaStore.picturePath(t.replaceAll(' ', '_'))));
      case SoundsRound(:final parts, :final blend, :final choices):
        for (final p in [...parts, blend]) {
          audio(p.audio);
        }
        for (final c in choices) {
          picture(c.picture);
        }
      case BeatsRound r:
        audio(r.hint?.audio);
        picture(r.picture);
      case ConnectRound r:
        audio(r.done?.audio);
        picture(r.picture);
      default:
    }
  }
  return out.toList();
}

final mediaProvider = Provider<MediaStore>((ref) => MediaStore(baseUrl: ApiConfig.baseUrl, files: ref.watch(localFilesProvider)));
