import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'sfx.dart';

/// Plays sound effects. The app uses [JustAudioSoundEngine]; tests get the
/// silent default (see soundEngineProvider).
abstract class SoundEngine {
  /// Loads [sounds] so their first play starts at once.
  Future<void> preload(Iterable<Sfx> sounds);

  /// Fire and forget. [volume] 0..1 on top of the file's own level.
  void play(Sfx sound, {double volume = 1});

  /// Starts [sound] looping (no-op if it already loops).
  void loop(Sfx sound, {double volume = 1});

  void stopLoop(Sfx sound);

  void dispose();
}

class SilentSoundEngine implements SoundEngine {
  const SilentSoundEngine();
  @override
  Future<void> preload(Iterable<Sfx> sounds) async {}
  @override
  void play(Sfx sound, {double volume = 1}) {}
  @override
  void loop(Sfx sound, {double volume = 1}) {}
  @override
  void stopLoop(Sfx sound) {}
  @override
  void dispose() {}
}

/// Short effects on just_audio (already used for Pencil's voice, so the app
/// keeps one audio stack and one audio session).
///
/// * One preloaded player per sound. Frequent sounds come in rotating
///   variants (tap_1..3, select_1..3, step_1..6), so quick repeats land on
///   different players and overlap naturally.
/// * Players never take the audio session or react to interruptions:
///   effects mix with the voice prompts and never pause other audio.
/// * Small load buffers so a play starts with the least delay.
/// * At most [maxSounds] sounds stay loaded; the least recently used ones
///   are released, except the answer sounds ([pinned]).
/// Swap for a low-latency game audio engine (e.g. flutter_soloud) behind
/// the same interface if device testing shows lag.
class JustAudioSoundEngine implements SoundEngine {
  JustAudioSoundEngine({this.maxSounds = 20});

  final int maxSounds;

  /// Never released: everything a round of play needs.
  static final Set<String> pinned = {
    for (final s in [
      Sfx.tap(0),
      Sfx.tap(1),
      Sfx.tap(2),
      Sfx.select(0),
      Sfx.back,
      Sfx.correct(1),
      Sfx.correct(2),
      Sfx.correct(3),
      Sfx.wrong,
      Sfx.step(1),
      Sfx.step(2),
      Sfx.step(3),
    ])
      s.name,
  };

  final Map<String, _Sound> _loaded = {};
  int _clock = 0;
  bool _disposed = false;

  static AudioPlayer _newPlayer() => AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
    audioLoadConfiguration: const AudioLoadConfiguration(
      darwinLoadControl: DarwinLoadControl(automaticallyWaitsToMinimizeStalling: false),
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(milliseconds: 500),
        maxBufferDuration: Duration(seconds: 2),
        bufferForPlaybackDuration: Duration(milliseconds: 40),
        bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 100),
      ),
    ),
  );

  _Sound _sound(Sfx s) {
    final v = _loaded.putIfAbsent(s.name, () => _Sound(s, _newPlayer()));
    v.used = ++_clock;
    _evict();
    return v;
  }

  void _evict() {
    if (_loaded.length <= maxSounds) return;
    final victims = _loaded.values.where((v) => !pinned.contains(v.sfx.name) && !v.looping).toList()..sort((a, b) => a.used.compareTo(b.used));
    for (final v in victims.take(_loaded.length - maxSounds)) {
      _loaded.remove(v.sfx.name);
      v.dispose();
    }
  }

  @override
  Future<void> preload(Iterable<Sfx> sounds) async {
    if (_disposed) return;
    await Future.wait([for (final s in sounds) _sound(s).loaded]);
  }

  @override
  void play(Sfx sound, {double volume = 1}) {
    if (_disposed) return;
    final v = _sound(sound);
    unawaited(
      v.loaded.then((ok) async {
        if (!ok || _disposed || v.disposed) return;
        try {
          final p = v.player;
          await p.setVolume(volume);
          await p.seek(Duration.zero);
          unawaited(p.play().catchError((Object _) {}));
        } catch (e) {
          debugPrint('Sfx ${sound.name}: $e');
        }
      }),
    );
  }

  @override
  void loop(Sfx sound, {double volume = 1}) {
    if (_disposed) return;
    final v = _sound(sound);
    if (v.looping) return;
    v.looping = true;
    unawaited(
      v.loaded.then((ok) async {
        if (!ok || !v.looping || _disposed || v.disposed) return;
        try {
          await v.player.setLoopMode(LoopMode.one);
          await v.player.setVolume(volume);
          if (v.looping) unawaited(v.player.play().catchError((Object _) {}));
        } catch (e) {
          debugPrint('Sfx loop ${sound.name}: $e');
        }
      }),
    );
  }

  @override
  void stopLoop(Sfx sound) {
    final v = _loaded[sound.name];
    if (v == null || !v.looping) return;
    v.looping = false;
    unawaited(v.player.pause().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _disposed = true;
    for (final v in _loaded.values) {
      v.dispose();
    }
    _loaded.clear();
  }
}

class _Sound {
  _Sound(this.sfx, this.player)
    : loaded = player.setAsset(sfx.asset).then((_) => true).catchError((Object e) {
        debugPrint('Sfx ${sfx.name} failed to load: $e');
        return false;
      });

  final Sfx sfx;
  final AudioPlayer player;

  /// Completes with false if the file could not be loaded.
  final Future<bool> loaded;
  int used = 0;
  bool looping = false;
  bool disposed = false;

  void dispose() {
    disposed = true;
    unawaited(player.dispose().catchError((Object _) {}));
  }
}
