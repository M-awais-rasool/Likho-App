import '../../../data/models/course_models.dart';

/// Pencil's lines in Monster Smash, kept in the app (recorded by
/// `tools/voice/generate_voice.py --app`, SMASH_LINES there: the same
/// words, which his bubble shows). The questions name their own lines
/// (MsAsk.audio), and a hit letter is said by its name (MsAsk.nameAudio).
abstract final class MsLines {
  static const intro = Prompt(text: 'Pull the ball back and let go! Hit the letter I ask for!', audio: 'assets/voice/ms_intro.m4a');
  static const pullHint = Prompt(text: 'Drag the ball back, then let go!', audio: 'assets/voice/ms_pull_hint.m4a');
  static const tower = Prompt(text: 'Look! A monster tower!', audio: 'assets/voice/ms_tower.m4a');
  static const great = [
    Prompt(text: 'Pow! You found it!', audio: 'assets/voice/ms_great_1.m4a'),
    Prompt(text: 'Great shot!', audio: 'assets/voice/ms_great_2.m4a'),
    Prompt(text: 'Yes! Smash!', audio: 'assets/voice/ms_great_3.m4a'),
  ];
  static const miss = Prompt(text: 'So close! Try again!', audio: 'assets/voice/ms_miss.m4a');
  static const oops = Prompt(text: 'Oops! Not that letter.', audio: 'assets/voice/sr_oops.m4a');
  static const hint = Prompt(text: 'Look! Here it is!', audio: 'assets/voice/ms_hint.m4a');
  static const refill = Prompt(text: 'More balls for you!', audio: 'assets/voice/ms_refill.m4a');
  static const cleared = Prompt(text: 'Tower down! The monsters are our friends now!', audio: 'assets/voice/ms_cleared.m4a');
  static const done = Prompt(text: 'You smashed them all!', audio: 'assets/voice/ms_done.m4a');
  static const record = Prompt(text: 'Wow! A new best score!', audio: 'assets/voice/sr_record.m4a');

  /// A letter said by its name ("B!").
  static Prompt letter(String l, String audio) => Prompt(text: '$l!', audio: audio);
}
