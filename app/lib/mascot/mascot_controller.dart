import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../design/tokens.dart';
import 'lip_sync.dart';
import 'mascot_animations.dart';
import 'mascot_pose.dart';
import 'rig/pencil_rig.dart';

/// Accessory ids accepted by [MascotController.wear].
abstract final class MascotAccessory {
  static const cap = 'cap';
  static const wizardHat = 'wizard_hat';
  static const partyHat = 'party_hat';
  static const roundGlasses = 'round_glasses';
  static const starGlasses = 'star_glasses';
  static const cape = 'cape';
  static const scarf = 'scarf';
  static const crown = 'crown';
  static const headphones = 'headphones';
  static const bow = 'bow';
  static const all = [cap, wizardHat, partyHat, roundGlasses, starGlasses, cape, scarf, crown, headphones, bow];
}

/// Drives one [PencilMascot]. Notifies listeners once per frame; the painter
/// repaints from it directly, so no widgets rebuild while animating.
class MascotController extends ChangeNotifier {
  MascotController({math.Random? random}) : _rnd = random ?? math.Random() {
    _mouth = MouthPicker(_rnd);
    _scheduleBlink(0);
  }

  final math.Random _rnd;
  late final MouthPicker _mouth;

  // ------------------------------------------------------------ public state
  MascotState get state => _state;

  /// Fires only when the state changes (not every frame), for UI that shows it.
  ValueListenable<MascotState> get stateListenable => _stateValue;

  /// True while [say] is playing audio.
  ValueListenable<bool> get speakingListenable => _speakingValue;
  MascotPose get pose => _pose;
  BodySwatch get swatch => _swatch;
  String? get accessory => _accessory;

  /// Final eye look after smoothing (-1..1), used by the painter.
  Offset get look => _look;

  /// Current blink amount 0..1, combined with the pose's own lid by the painter.
  double get blink => _blink;

  /// Seconds since the controller started ticking (drives looping effects).
  double get time => _time;

  // ------------------------------------------------------------ public API
  /// Switches to [state]. Loops run until the next call; one-shots return to
  /// idle on their own. Every switch blends over ~150 ms.
  void play(MascotState state) {
    _frozen = false;
    if (state != MascotState.talking && _speaking) _stopAudio();
    _switchTo(state);
  }

  /// Plays [audio] with lip-sync and returns when it finishes: an app
  /// asset ("assets/…"), a file on the phone (a kept course recording, see
  /// MediaStore, with its mouth movement in [lipFile]) or a URL. True when
  /// the line played to its end (not cut, and it could be played).
  Future<bool> say(String audio, {String? lipFile}) async {
    final session = ++_sayId;
    _stopAudio();
    final player = _player ??= AudioPlayer();
    _envelope = await LipSyncEnvelope.load(audio, lipFile: lipFile);
    if (session != _sayId) return false;
    try {
      if (audio.startsWith('assets/')) {
        await player.setAsset(audio);
      } else if (audio.startsWith('http')) {
        await player.setUrl(audio);
      } else {
        await player.setFilePath(audio);
      }
    } catch (e) {
      debugPrint('PencilMascot.say: cannot load $audio: $e');
      return false;
    }
    if (session != _sayId) return false;
    _frozen = false;
    _speaking = true;
    _speakingValue.value = true;
    _switchTo(MascotState.talking);
    final done = _sayDone = Completer<void>();
    _playerSub = player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && !done.isCompleted) done.complete();
    }, onError: (Object e) {
      if (!done.isCompleted) done.complete();
    });
    unawaited(player.play());
    await done.future;
    if (session != _sayId || !_speaking) return false; // cut
    _stopAudio();
    if (_state == MascotState.talking) _switchTo(MascotState.idle);
    return true;
  }

  /// Stops [say] at once: a line that is playing is cut, one still loading
  /// never starts. A talking pose goes back to idle.
  void hush() {
    _sayId++;
    _stopAudio();
    if (_state == MascotState.talking) _switchTo(MascotState.idle);
  }

  /// Makes the pupils follow [globalPosition] (e.g. the child's finger).
  void lookAt(Offset globalPosition) {
    final toArt = _globalToArtboard;
    if (toArt == null) return;
    final p = toArt(globalPosition);
    final eyes = (PencilRig.eyeLeft.white + PencilRig.eyeRight.white) / 2;
    final v = (p - eyes) / 260;
    final len = v.distance;
    _lookTarget = len > 1 ? v / len : v;
  }

  void lookReset() => _lookTarget = null;

  /// Recolours body, arms, hands and legs (outlines become a darker shade).
  /// The six brief colours use measured swatches; any other colour is derived.
  void setBodyColor(Color c) {
    _swatch = BodySwatch.forColor(c);
    notifyListeners();
  }

  void wear(String accessoryId) {
    assert(MascotAccessory.all.contains(accessoryId), 'Unknown accessory $accessoryId');
    _accessory = accessoryId;
    notifyListeners();
  }

  void removeAccessory() {
    _accessory = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ internals
  MascotState _state = MascotState.idle;
  final ValueNotifier<MascotState> _stateValue = ValueNotifier(MascotState.idle);
  final ValueNotifier<bool> _speakingValue = ValueNotifier(false);
  double _stateStart = 0;
  MascotPose _pose = MascotPose.idle;
  MascotPose? _blendFrom;
  double _blendStart = 0;
  static const double _blendTime = 0.15;

  BodySwatch _swatch = BodySwatch.yellow;
  String? _accessory;

  double _time = 0;
  Duration? _lastElapsed;

  Offset? _lookTarget;
  Offset _look = Offset.zero;

  double _blink = 0;
  double _nextBlink = 0;
  double _blinkStart = -1;
  static const double _blinkTime = 0.16;

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSub;
  Completer<void>? _sayDone; // completes [say] when its line is cut
  LipSyncEnvelope? _envelope;
  bool _speaking = false;
  int _sayId = 0;
  double _level = 0;

  Offset Function(Offset global)? _globalToArtboard;
  bool _frozen = false;

  /// Called by the widget so [lookAt] can convert screen positions.
  void attachView(Offset Function(Offset global) globalToArtboard) => _globalToArtboard = globalToArtboard;

  void detachView(Offset Function(Offset global) globalToArtboard) {
    if (_globalToArtboard == globalToArtboard) _globalToArtboard = null;
  }

  /// Dev tool: freezes the idle pose at rest with eyes open, which is exactly
  /// the master image. Used by render tests and the reference overlay.
  void freezeAtRest() {
    _stopAudio();
    _frozen = true;
    _setState(MascotState.idle);
    _pose = MascotPose.idle;
    _blink = 0;
    _look = Offset.zero;
    notifyListeners();
  }

  /// Dev tool: resumes animation after [freezeAtRest] / [debugShow].
  void unfreeze() {
    _frozen = false;
    _lastElapsed = null;
    _switchTo(_state);
  }

  bool get isFrozen => _frozen;

  /// Holds one still frame of [state] at [t] seconds, e.g. a cheering icon
  /// (the map's room button). Call [play] or [unfreeze] to animate again.
  void showFrame(MascotState state, double t) => debugShow(state, t);

  /// Dev tool: shows [state] frozen at [t] seconds (lip-sync mouth =
  /// [talkMouth]), to compare a pose with its expression-sheet cell.
  void debugShow(MascotState state, double t, {MouthShape talkMouth = MouthShape.openSmall, Offset? look}) {
    _stopAudio();
    _frozen = true;
    _setState(state);
    _pose = MascotAnimations.sample(state, t, talk: TalkInput(level: 0.5, mouth: talkMouth));
    _look = look ?? Offset(_pose.lookX, _pose.lookY);
    _blink = 0;
    _time = t;
    notifyListeners();
  }

  void _setState(MascotState s) {
    _state = s;
    _stateValue.value = s;
  }

  void _switchTo(MascotState s) {
    _blendFrom = _pose;
    _blendStart = _time;
    _setState(s);
    _stateStart = _time;
    if (s != MascotState.talking) _level = 0;
  }

  void _stopAudio() {
    _speaking = false;
    _speakingValue.value = false;
    _playerSub?.cancel();
    _playerSub = null;
    final done = _sayDone;
    _sayDone = null;
    if (done != null && !done.isCompleted) done.complete();
    final p = _player;
    if (p != null && p.playing) unawaited(p.stop());
  }

  void _scheduleBlink(double now) => _nextBlink = now + 3 + _rnd.nextDouble() * 2;

  /// Advances the animation; the widget calls this from its ticker.
  void advance(Duration elapsed) {
    if (_frozen) return;
    final last = _lastElapsed;
    _lastElapsed = elapsed;
    if (last == null) return;
    final dt = ((elapsed - last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _time += dt;

    // one-shots hand over to idle at their end (their last 0.25 s already eased into idle)
    var t = _time - _stateStart;
    if (!_state.loop && t >= _state.duration) {
      _setState(MascotState.idle);
      _stateStart = _time;
      _blendFrom = null;
      t = 0;
    }

    // lip-sync
    var talk = const TalkInput();
    if (_state == MascotState.talking) {
      final env = _envelope;
      final player = _player;
      double? level;
      if (_speaking && env != null && player != null) {
        level = env.levelAt(player.position);
        _level += (level - _level) * (1 - math.exp(-dt * 25));
      } else {
        _level *= math.exp(-dt * 10);
      }
      // play(talking) without audio keeps talking with random shapes
      final speaking = _speaking ? (player?.playing ?? false) : true;
      final mouth = _mouth.update(_time, speaking: speaking, level: _speaking ? level : null);
      talk = TalkInput(level: _speaking && env != null ? _level : 0.45, mouth: mouth);
    }

    var pose = MascotAnimations.sample(_state, t, clock: _time, talk: talk);
    final from = _blendFrom;
    if (from != null) {
      final k = (_time - _blendStart) / _blendTime;
      if (k >= 1) {
        _blendFrom = null;
      } else {
        pose = MascotPose.lerp(from, pose, Curves.easeInOut.transform(k));
      }
    }
    _pose = pose;

    // eyes: follow the finger when there is one, otherwise the pose's own look
    final target = _lookTarget ?? Offset(pose.lookX, pose.lookY);
    _look += (target - _look) * (1 - math.exp(-dt * 14));

    // random blinks every 3–5 s, only while the eyes are open
    if (_blinkStart < 0 && _time >= _nextBlink) {
      if (pose.eyes == EyeStyle.happy || pose.lid > 0.4) {
        _scheduleBlink(_time);
      } else {
        _blinkStart = _time;
      }
    }
    if (_blinkStart >= 0) {
      final k = (_time - _blinkStart) / _blinkTime;
      if (k >= 1) {
        _blink = 0;
        _blinkStart = -1;
        _scheduleBlink(_time);
      } else {
        _blink = math.sin(math.pi * k);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sayId++;
    _playerSub?.cancel();
    _player?.dispose();
    _stateValue.dispose();
    _speakingValue.dispose();
    super.dispose();
  }
}
