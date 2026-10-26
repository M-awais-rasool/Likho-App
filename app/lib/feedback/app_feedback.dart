import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family.dart';
import 'haptics.dart';
import 'sfx.dart';
import 'sound_engine.dart';
import '../data/app_controls.dart';

/// The sound engine. Silent by default (tests); main() installs
/// [JustAudioSoundEngine].
final soundEngineProvider = Provider<SoundEngine>((ref) => const SilentSoundEngine());

/// The haptics engine. Silent by default (tests); main() installs
/// [SystemHaptics].
final hapticsProvider = Provider<HapticsEngine>((ref) => const SilentHaptics());

final feedbackProvider = Provider<AppFeedback>(AppFeedback.new);

/// Every sound + haptic in the app, by meaning. Screens say what happened
/// ("correct", "star landed", "item bought"); this class decides how it
/// sounds and feels, so the whole app stays one consistent system.
/// Respects the parent's "Sound effects" and "Vibration" settings, and the
/// team's switches for them (App controls).
/// See docs/sound_and_haptics.md.
class AppFeedback {
  AppFeedback(this._ref);
  final Ref _ref;
  final math.Random _rnd = math.Random();
  int _variant = 0;

  /// From any widget below the ProviderScope.
  static AppFeedback of(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(feedbackProvider);

  AppSettings get _settings => _ref.read(familyProvider).settings;
  AppControls get _controls => _ref.read(appControlsProvider);

  bool get _sfx => _settings.sfx && _controls.on(Feature.sfx);
  bool get _haptics => _settings.haptics && _controls.on(Feature.haptics);

  void _go(Sfx? sound, HapticCue? cue, {double volume = 1}) {
    if (sound != null && _sfx) _ref.read(soundEngineProvider).play(sound, volume: volume);
    if (cue != null && _haptics) _ref.read(hapticsProvider).play(cue);
  }

  /// Rotates small pitch variants of frequent sounds so they never feel
  /// mechanical.
  int get _v => _variant = (_variant + 1 + _rnd.nextInt(2)) % 3;

  /// Loads the sounds a screen is about to use (e.g. its celebration
  /// timeline), so they start on the beat.
  void prepare(Iterable<Sfx> sounds) {
    if (_sfx) _ref.read(soundEngineProvider).preload(sounds);
  }

  // ---------------------------------------------------------- UI
  /// Secondary taps (links, small icons): sound only.
  void tap() => _go(Sfx.tap(_v), null);

  /// Main buttons: tap + a light press.
  void press() => _go(Sfx.tap(_v), HapticCue.press);

  void back() => _go(Sfx.back, null);

  /// Picking one of several (age, colour, plan, segment).
  void select() => _go(Sfx.select(_v), HapticCue.select);

  void toggle(bool on) => _go(on ? Sfx.toggleOn : Sfx.toggleOff, HapticCue.select);

  void pageFlip() => _go(Sfx.pageFlip, HapticCue.select);

  void whoosh() => _go(Sfx.whoosh, HapticCue.press);

  // ---------------------------------------------------------- answers
  /// Right answer. [streak] = right answers in a row (the chime climbs).
  void correct({int streak = 1, bool balloon = false}) {
    _go(Sfx.correct(streak), HapticCue.success);
    if (balloon) _go(Sfx.balloonPop, null, volume: .9);
  }

  /// A bubble popped (pop rounds).
  void pop() => _go(Sfx.balloonPop, HapticCue.tick, volume: .9);

  /// Wrong answer: friendly "not yet".
  void wrong() => _go(Sfx.wrong, HapticCue.gentleError);

  /// Not allowed (not enough stars, wrong gate answer, form mistake).
  void nope() => _go(Sfx.nope, HapticCue.nope);

  /// One step of progress within an answer ([n] = 1, 2, 3…).
  void step(int n) => _go(Sfx.step(n), HapticCue.tick);

  void listen() => _go(Sfx.listen, HapticCue.press);

  /// A drum beat (clap the beats).
  void drum() => _go(Sfx.bossDrum, HapticCue.tick);

  void roundNext() => _go(Sfx.roundNext, null, volume: .8);

  // ---------------------------------------------------------- journeys
  void levelStart() => _go(Sfx.levelStart, HapticCue.press);

  void introReveal() => _go(Sfx.introReveal, null);

  void levelComplete() => _go(Sfx.completeTada, HapticCue.celebrate);

  /// Star [n] (1..3) lands; [perfect] = the third of three.
  void star(int n, {bool perfect = false}) => _go(Sfx.star(n), perfect ? HapticCue.landBig : HapticCue.land);

  void coin() => _go(Sfx.coin, HapticCue.tick);

  void confetti() => _go(Sfx.confetti, HapticCue.confetti);

  /// Flourish for a perfect (3 star) level.
  void perfect() => _go(Sfx.perfect, null);

  void bossWake() => _go(Sfx.bossWake, HapticCue.bossWake);

  void milestone() => _go(Sfx.milestone, HapticCue.milestone);

  void lullaby() => _go(Sfx.lullaby, null);

  // boss battle
  void bossStamp() => _go(Sfx.bossStamp, HapticCue.landBig);
  void bossDrum() => _go(Sfx.bossDrum, null);
  void bossHit({bool big = false}) => _go(big ? Sfx.bossSuper : Sfx.bossHit, big ? HapticCue.landBig : HapticCue.land);
  void bossCombo() => _go(Sfx.bossCombo, null);
  void bossPhase() => _go(Sfx.bossPhase, HapticCue.celebrate);
  void bossSnore() => _go(Sfx.bossSnore, null, volume: .9);
  void alarmRing() => _go(Sfx.alarmRing, HapticCue.tick);

  // ---------------------------------------------------------- rewards
  /// Something bought with stars.
  void reward() => _go(Sfx.reward, HapticCue.reward);

  /// Clothes on/off, furniture in/out.
  void wear() => _go(Sfx.wear, HapticCue.tick);

  void sticker() => _go(Sfx.sticker, HapticCue.land);

  void unlock() => _go(Sfx.unlock, HapticCue.unlock);

  /// Gentle "done" (account created, profile saved, trial started).
  void done() => _go(Sfx.successSoft, HapticCue.success);

  void send() => _go(Sfx.send, HapticCue.press);

  void paint() => _go(Sfx.paint, HapticCue.tick);

  void candle() => _go(Sfx.candle, HapticCue.select);

  void catchLetter() => _go(Sfx.catchLetter, HapticCue.tick);

  /// The finger slid out of the tracing lane: a light bump, no sound (it
  /// happens often and is not a mistake yet).
  void offPath() => _go(null, HapticCue.tick);

  // ---------------------------------------------------------- splash
  void splashLand() => _go(Sfx.splashLand, HapticCue.land);

  void splashLetter() => _go(Sfx.scribble(_v), null);

  void splashSwish() => _go(Sfx.splashSwish, null);

  void splashChime() => _go(Sfx.splashChime, HapticCue.press);

  // ---------------------------------------------------------- Monster Defense
  void monsterOut() => _go(Sfx.mdSpawn, null, volume: .7);

  /// Pencil's magic flies at a monster.
  void zap() => _go(Sfx.mdZap, HapticCue.press);

  void bubble() => _go(Sfx.mdBubble, HapticCue.success);

  /// A bubble pops: the monster is a friend.
  void bubblePop() => _go(Sfx.mdPop, HapticCue.tick);

  void roar() => _go(Sfx.mdRoar, HapticCue.gentleError);

  void crack() => _go(Sfx.mdCrack, HapticCue.land);

  /// A monster got to the gate: a heart is lost.
  void gate() => _go(Sfx.mdGate, HapticCue.landBig);

  void wave() => _go(Sfx.mdWave, HapticCue.press);

  void bigBoss() => _go(Sfx.mdBoss, HapticCue.bossWake);

  void hurry() => _go(Sfx.mdHurry, HapticCue.tick, volume: .9);

  void powerUp() => _go(Sfx.mdPower, HapticCue.reward);

  void freeze() => _go(Sfx.mdFreeze, HapticCue.press);

  void potion() => _go(Sfx.mdPotion, HapticCue.press);

  void gameLost() => _go(Sfx.mdLose, null);

  /// The game's music (calm, or [tense]); the other loop stops.
  void music({bool tense = false}) {
    final engine = _ref.read(soundEngineProvider);
    engine.stopLoop(tense ? Sfx.mdMusic : Sfx.mdMusicTense);
    if (_sfx) engine.loop(tense ? Sfx.mdMusicTense : Sfx.mdMusic, volume: .55);
  }

  void stopMusic() {
    final engine = _ref.read(soundEngineProvider);
    engine.stopLoop(Sfx.mdMusic);
    engine.stopLoop(Sfx.mdMusicTense);
  }

  // ---------------------------------------------------------- Spell Runner
  void skateJump() => _go(Sfx.srJump, HapticCue.press);

  void skateLand() => _go(Sfx.srLand, HapticCue.tick, volume: .8);

  void skateBump() => _go(Sfx.srBump, HapticCue.landBig);

  void splash() => _go(Sfx.srSplash, HapticCue.land);

  void slip() => _go(Sfx.srSlip, HapticCue.land);

  void boost() => _go(Sfx.srBoost, HapticCue.celebrate);

  /// A countdown number, or "go".
  void countdown({bool go = false}) => _go(go ? Sfx.srBeepGo : Sfx.srBeep, go ? HapticCue.press : HapticCue.tick);

  /// The runner's music and wheels (on), or quiet (off).
  void riding(bool on) {
    final engine = _ref.read(soundEngineProvider);
    if (on && _sfx) {
      engine.loop(Sfx.srMusic, volume: .5);
      engine.loop(Sfx.srRoll, volume: .45);
    } else {
      engine.stopLoop(Sfx.srMusic);
      engine.stopLoop(Sfx.srRoll);
    }
  }
  // ---------------------------------------------------------- Monster Smash
  /// The slingshot's band is pulled back: [level] 1, 2, 3 as it gets
  /// tighter, each creak higher.
  void stretch([int level = 1]) => _go(switch (level) {
    3 => Sfx.msStretch3,
    2 => Sfx.msStretch2,
    _ => Sfx.msStretch,
  }, HapticCue.tick, volume: .55 + .15 * level);

  /// Pencil drops the next ball into the pouch.
  void reload() => _go(Sfx.msReload, null, volume: .7);

  /// A monster on the tower giggles at Pencil.
  void giggle() => _go(Sfx.msGiggle, null, volume: .55);

  /// A monster squeaks: the ball is coming.
  void eek() => _go(Sfx.msEek, null, volume: .6);

  /// A monster is knocked (dizzy stars).
  void bonk() => _go(Sfx.msBonk, HapticCue.tick, volume: .8);

  void launch() => _go(Sfx.msLaunch, HapticCue.press);

  /// A block knocked ([hard] 0..1), by what it is made of.
  void knock(String material, double hard) => _go(switch (material) {
    'ice' => Sfx.msIce,
    'stone' => Sfx.msStone,
    _ => Sfx.msWood,
  }, hard > .6 ? HapticCue.tick : null, volume: .35 + .6 * hard.clamp(0.0, 1.0));

  /// A block breaks.
  void smash(String material) => _go(switch (material) {
    'ice' => Sfx.msIceBreak,
    'stone' => Sfx.msStoneBreak,
    _ => Sfx.msWoodBreak,
  }, HapticCue.land);

  /// The asked letter's block bursts.
  void pow() => _go(Sfx.msPow, HapticCue.celebrate);

  /// A monster turns into a friend.
  void friend() => _go(Sfx.msFriend, null, volume: .8);

  /// The towers' music (on), or quiet (off).
  void smashMusic(bool on) {
    final engine = _ref.read(soundEngineProvider);
    if (on && _sfx) {
      engine.loop(Sfx.msMusic, volume: .45);
    } else {
      engine.stopLoop(Sfx.msMusic);
    }
  }

  /// The towers' music under Pencil's voice ([quiet]), so his words are
  /// clear, and back up after.
  void smashMusicQuiet(bool quiet) => _ref.read(soundEngineProvider).loopVolume(Sfx.msMusic, quiet ? .12 : .45);
  // ---------------------------------------------------------- Letter Slice
  /// The blade through the air ([fast] 0..1).
  void swish(double fast) => _go(Sfx.lsSwish, null, volume: .45 + .5 * fast.clamp(0.0, 1.0));

  /// A fruit sliced.
  void sliceFruit() => _go(Sfx.lsCut, HapticCue.tick);

  /// A wrong letter bounces off the blade.
  void clonk() => _go(Sfx.lsClonk, HapticCue.nope);

  /// Three or more in one swipe.
  void combo() => _go(Sfx.lsCombo, HapticCue.success);

  /// The ice berry: slow motion.
  void slowMotion() => _go(Sfx.lsFreeze, HapticCue.press);

  /// The banana: a fruit party.
  void frenzy() => _go(Sfx.lsFrenzy, HapticCue.celebrate);

  /// The round's music (on), or quiet (off).
  void sliceMusic(bool on) {
    final engine = _ref.read(soundEngineProvider);
    if (on && _sfx) {
      engine.loop(Sfx.lsMusic, volume: .45);
    } else {
      engine.stopLoop(Sfx.lsMusic);
    }
  }



  // ---------------------------------------------------------- writing
  void startWriting() {
    if (_sfx) _ref.read(soundEngineProvider).loop(Sfx.scribbleLoop, volume: .9);
  }

  void stopWriting() => _ref.read(soundEngineProvider).stopLoop(Sfx.scribbleLoop);
}
