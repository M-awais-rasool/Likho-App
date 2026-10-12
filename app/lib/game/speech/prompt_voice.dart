import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/media.dart';
import '../../data/models/course_models.dart';
import '../../mascot/mascot.dart';

/// Speaks round prompts through the mascot.
///
/// * prompt with `audio` (a recording on the server, kept on the phone by
///   [MediaStore]): played by [MascotController.say] with lip-sync from the
///   recording
/// * text only: the device's offline text-to-speech voice (like the
///   prototype's speechSynthesis: slower, higher pitch) while the mascot
///   talks with random mouth shapes; also when the recording cannot be had
///   in time (offline and not kept yet)
class PromptVoice {
  PromptVoice(this.media);

  final MediaStore media;

  FlutterTts? _tts;
  bool _ready = false;
  int _session = 0;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      // a little slower than normal, for children. flutter_tts doubles the
      // rate on Android (.42 -> 0.84x), and iOS's normal is .5: the same
      // pace on both (.85 on Android was 1.7x, far too fast)
      await tts.setSpeechRate(.42);
      await tts.setPitch(1.35);
      await tts.awaitSpeakCompletion(true);
      _tts = tts;
    } catch (e) {
      debugPrint('PromptVoice: text-to-speech unavailable: $e');
    }
  }

  /// Speaks [prompt]; completes when done (or at once if speech is off).
  Future<void> speak(Prompt prompt, MascotController mascot, {required MascotState after}) async {
    final session = ++_session;
    await _silence();
    final audio = prompt.audio;
    final voice = audio == null ? null : await media.voice(audio);
    if (session != _session) return;
    if (voice != null) {
      await mascot.say(voice.$1, lipFile: voice.$2);
    } else {
      await _init();
      if (session != _session) return; // stopped (or the screen closed) meanwhile
      final tts = _tts;
      mascot.play(MascotState.talking);
      final started = DateTime.now();
      if (tts != null) {
        try {
          await tts.speak(prompt.spoken.replaceAll(RegExp(r'[/_]'), ' '));
        } catch (_) {}
      }
      // keep the talking pose at least as long as the prototype (1.2 s)
      final spent = DateTime.now().difference(started);
      if (spent < const Duration(milliseconds: 1200)) await Future<void>.delayed(const Duration(milliseconds: 1200) - spent);
    }
    if (session == _session && mascot.state == MascotState.talking) mascot.play(after);
  }

  /// Stops speaking; a line still on its way is dropped.
  Future<void> stop() async {
    _session++;
    await _silence();
  }

  Future<void> _silence() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

final promptVoiceProvider = Provider<PromptVoice>((ref) {
  final v = PromptVoice(ref.watch(mediaProvider));
  ref.onDispose(v.stop);
  return v;
});
