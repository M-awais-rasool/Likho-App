import '../../../data/models/course_models.dart';

/// Pencil's lines in Monster Defense, kept in the app (recorded by
/// `tools/voice/generate_voice.py --app`, GAME_LINES there: the same
/// words, which his bubble shows while he says them). The questions'
/// lines are named by the questions (MdQuestion.audio).
abstract final class MdLines {
  static const intro = Prompt(text: "Oh no! Silly monsters are coming to our garden! Tap the one I ask for, and I'll catch it in a magic bubble!", audio: 'assets/voice/md_intro.m4a');
  static const go = Prompt(text: 'Here they come!', audio: 'assets/voice/md_go.m4a');
  static const wave = Prompt(text: 'Here comes the next wave!', audio: 'assets/voice/md_wave.m4a');
  static const boss = Prompt(text: 'Uh oh! Big Bonk is coming! Catch him three times!', audio: 'assets/voice/md_boss.m4a');
  static const bossHit = Prompt(text: 'Bonk! Again!', audio: 'assets/voice/md_boss_hit.m4a');
  static const great = [
    Prompt(text: 'Got it!', audio: 'assets/voice/md_great_1.m4a'),
    Prompt(text: 'Great job!', audio: 'assets/voice/md_great_2.m4a'),
    Prompt(text: 'Super!', audio: 'assets/voice/md_great_3.m4a'),
    Prompt(text: "Wow, you're fast!", audio: 'assets/voice/md_great_4.m4a'),
  ];
  static const oops = [Prompt(text: 'Oops! Not that one.', audio: 'assets/voice/md_oops_1.m4a'), Prompt(text: 'Try another one!', audio: 'assets/voice/md_oops_2.m4a')];
  static const hurry = Prompt(text: "Hurry! It's getting close!", audio: 'assets/voice/md_hurry.m4a');
  static const gate = Prompt(text: 'Oh no! It got to the gate!', audio: 'assets/voice/md_gate.m4a');
  static const crack = Prompt(text: "It's a tough one! Again!", audio: 'assets/voice/md_crack.m4a');
  static const power = Prompt(text: 'A power-up! Tap it!', audio: 'assets/voice/md_power.m4a');
  static const freeze = Prompt(text: 'Freeze!', audio: 'assets/voice/md_freeze.m4a');
  static const potion = Prompt(text: 'Double magic!', audio: 'assets/voice/md_potion.m4a');
  static const win = Prompt(text: 'You did it! All the monsters are our friends now!', audio: 'assets/voice/md_win.m4a');
  static const lose = Prompt(text: "Good try! Let's play again!", audio: 'assets/voice/md_lose.m4a');
  static const record = Prompt(text: 'Wow! A new best score!', audio: 'assets/voice/md_record.m4a');
}
