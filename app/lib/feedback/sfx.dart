import 'package:flutter/foundation.dart';

/// One sound effect of the Likho palette (`assets/sfx/<name>.wav`, made by
/// tool/sound_design/generate_sfx.dart). Families with steps or variants
/// have constructors (`Sfx.correct(streak)`, `Sfx.step(n)`, …).
@immutable
class Sfx {
  const Sfx(this.name);
  final String name;

  String get asset => 'assets/sfx/$name.wav';

  // UI (quiet, frequent)
  static Sfx tap(int variant) => Sfx('tap_${variant % 3 + 1}');
  static Sfx select(int variant) => Sfx('select_${variant % 3 + 1}');
  static const back = Sfx('back');
  static const toggleOn = Sfx('toggle_on');
  static const toggleOff = Sfx('toggle_off');
  static const pageFlip = Sfx('page_flip');
  static const roundNext = Sfx('round_next');
  static const whoosh = Sfx('whoosh');

  // answers
  /// Rises one note per correct answer in a row (1..5).
  static Sfx correct(int streak) => Sfx('correct_${streak.clamp(1, 5)}');
  static const wrong = Sfx('wrong');
  static const nope = Sfx('nope');

  /// One step of progress (order tile, spelled letter), rising (1..6).
  static Sfx step(int n) => Sfx('step_${n.clamp(1, 6)}');
  static const balloonPop = Sfx('balloon_pop');
  static const listen = Sfx('listen');

  // journeys and celebrations
  static const levelStart = Sfx('level_start');
  static const introReveal = Sfx('intro_reveal');
  static const completeTada = Sfx('complete_tada');

  /// Star 1..3 landing on Level Complete (higher each time).
  static Sfx star(int n) => Sfx('star_${n.clamp(1, 3)}');
  static const coin = Sfx('coin');
  static const confetti = Sfx('confetti');
  static const perfect = Sfx('perfect');
  static const milestone = Sfx('milestone');
  static const bossWake = Sfx('boss_wake');
  static const lullaby = Sfx('lullaby');

  // boss battle
  static const bossStamp = Sfx('boss_stamp');
  static const bossDrum = Sfx('boss_drum');
  static const bossHit = Sfx('boss_hit');
  static const bossSuper = Sfx('boss_super');
  static const bossCombo = Sfx('boss_combo');
  static const bossPhase = Sfx('boss_phase');
  static const bossSnore = Sfx('boss_snore');
  static const alarmRing = Sfx('alarm_ring');

  // Monster Defense
  static const mdSpawn = Sfx('md_spawn');
  static const mdZap = Sfx('md_zap');
  static const mdBubble = Sfx('md_bubble');
  static const mdPop = Sfx('md_pop');
  static const mdRoar = Sfx('md_roar');
  static const mdCrack = Sfx('md_crack');
  static const mdGate = Sfx('md_gate');
  static const mdWave = Sfx('md_wave');
  static const mdBoss = Sfx('md_boss');
  static const mdHurry = Sfx('md_hurry');
  static const mdPower = Sfx('md_power');
  static const mdFreeze = Sfx('md_freeze');
  static const mdPotion = Sfx('md_potion');
  static const mdLose = Sfx('md_lose');

  /// The game's music, looped: calm, and tense while a monster is close.
  static const mdMusic = Sfx('md_music');
  static const mdMusicTense = Sfx('md_music_tense');

  static const monsterDefense = [
    mdSpawn, mdZap, mdBubble, mdPop, mdRoar, mdCrack, mdGate, mdWave, mdBoss, mdHurry, mdPower, mdFreeze, mdPotion, mdLose, mdMusic, mdMusicTense,
  ];

  // Spell Runner
  static const srJump = Sfx('sr_jump');
  static const srLand = Sfx('sr_land');
  static const srBump = Sfx('sr_bump');
  static const srSplash = Sfx('sr_splash');
  static const srSlip = Sfx('sr_slip');
  static const srBoost = Sfx('sr_boost');
  static const srBeep = Sfx('sr_beep');
  static const srBeepGo = Sfx('sr_beep_go');

  /// Looped while he rides: the music and the wheels.
  static const srMusic = Sfx('sr_music');
  static const srRoll = Sfx('sr_roll');

  static const spellRunner = [srJump, srLand, srBump, srSplash, srSlip, srBoost, srBeep, srBeepGo, srMusic, srRoll];

  // Monster Smash
  static const msStretch = Sfx('ms_stretch');
  static const msLaunch = Sfx('ms_launch');
  static const msWood = Sfx('ms_wood');
  static const msIce = Sfx('ms_ice');
  static const msStone = Sfx('ms_stone');
  static const msWoodBreak = Sfx('ms_wood_break');
  static const msIceBreak = Sfx('ms_ice_break');
  static const msStoneBreak = Sfx('ms_stone_break');
  static const msPow = Sfx('ms_pow');
  static const msFriend = Sfx('ms_friend');

  /// Looped while the towers stand.
  static const msMusic = Sfx('ms_music');

  /// (the water balloon splashes like Spell Runner's puddle)
  static const monsterSmash = [msStretch, msLaunch, msWood, msIce, msStone, msWoodBreak, msIceBreak, msStoneBreak, msPow, msFriend, msMusic];

  // Letter Slice
  static const lsSwish = Sfx('ls_swish');
  static const lsCut = Sfx('ls_cut');
  static const lsClonk = Sfx('ls_clonk');
  static const lsCombo = Sfx('ls_combo');
  static const lsFreeze = Sfx('ls_freeze');
  static const lsFrenzy = Sfx('ls_frenzy');

  /// Looped while the round runs.
  static const lsMusic = Sfx('ls_music');

  static const letterSlice = [lsSwish, lsCut, lsClonk, lsCombo, lsFreeze, lsFrenzy, lsMusic];

  // rewards, room, profiles
  static const reward = Sfx('reward');
  static const wear = Sfx('wear');
  static const sticker = Sfx('sticker');
  static const unlock = Sfx('unlock');
  static const successSoft = Sfx('success_soft');
  static const send = Sfx('send');
  static const paint = Sfx('paint');
  static const candle = Sfx('candle');
  static const catchLetter = Sfx('catch');

  // splash
  static const splashLand = Sfx('splash_land');
  static Sfx scribble(int variant) => Sfx('scribble_${variant % 3 + 1}');
  static const splashSwish = Sfx('splash_swish');
  static const splashChime = Sfx('splash_chime');

  /// Pencil-on-paper texture, looped while the child writes.
  static const scribbleLoop = Sfx('scribble_loop');

  /// Every sound file the app uses.
  static final List<Sfx> all = [
    for (var i = 0; i < 3; i++) ...[tap(i), select(i), scribble(i)],
    back, toggleOn, toggleOff, pageFlip, roundNext, whoosh, //
    for (var k = 1; k <= 5; k++) correct(k),
    wrong, nope, balloonPop, listen,
    for (var k = 1; k <= 6; k++) step(k),
    levelStart, introReveal, completeTada, coin, confetti, perfect, milestone, bossWake, lullaby,
    bossStamp, bossDrum, bossHit, bossSuper, bossCombo, bossPhase, bossSnore, alarmRing,
    for (var k = 1; k <= 3; k++) star(k),
    reward, wear, sticker, unlock, successSoft, send, paint, candle, catchLetter,
    splashLand, splashSwish, splashChime, scribbleLoop,
    ...monsterDefense,
    ...spellRunner,
    ...monsterSmash,
    ...letterSlice,
  ];

  /// Loaded at start-up: the splash and the sounds of every answer.
  static final List<Sfx> warm = [
    splashLand, scribble(0), scribble(1), scribble(2), splashSwish, splashChime, //
    tap(0), tap(1), select(0), back, correct(1), correct(2), correct(3), wrong, step(1), step(2), step(3),
  ];

  @override
  bool operator ==(Object other) => other is Sfx && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Sfx($name)';
}
