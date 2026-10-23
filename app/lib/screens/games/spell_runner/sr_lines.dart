import '../../../data/models/course_models.dart';

/// Pencil's lines in Spell Runner, kept in the app (recorded by
/// `tools/voice/generate_voice.py --app`, RUNNER_LINES there: the same
/// words, which his bubble shows). The tasks name their own lines
/// (SrTask.audio, SrTask.doneAudio), and every letter has one ([letter]).
abstract final class SrLines {
  static const intro = Prompt(text: 'Hop on my skateboard! Swipe to catch the letters, and jump over the bumps!', audio: 'assets/voice/sr_intro.m4a');
  static const count = [
    Prompt(text: 'One!', audio: 'assets/voice/sr_1.m4a'),
    Prompt(text: 'Two!', audio: 'assets/voice/sr_2.m4a'),
    Prompt(text: 'Three!', audio: 'assets/voice/sr_3.m4a'),
  ];
  static const go = Prompt(text: 'Go!', audio: 'assets/voice/sr_go.m4a');
  static const great = [
    Prompt(text: 'Yes!', audio: 'assets/voice/sr_great_1.m4a'),
    Prompt(text: 'You spelled it!', audio: 'assets/voice/sr_great_2.m4a'),
    Prompt(text: 'Awesome!', audio: 'assets/voice/sr_great_3.m4a'),
  ];
  static const oops = Prompt(text: 'Oops! Not that letter.', audio: 'assets/voice/sr_oops.m4a');
  static const bump = Prompt(text: 'Whoa! Jump over it!', audio: 'assets/voice/sr_bump.m4a');
  static const jumpHint = Prompt(text: 'Swipe up to jump!', audio: 'assets/voice/sr_jump_hint.m4a');
  static const record = Prompt(text: 'Wow! A new best score!', audio: 'assets/voice/sr_record.m4a');
  static const longer = Prompt(text: 'Super! Now longer words!', audio: 'assets/voice/sr_longer.m4a');
  static const heart = Prompt(text: 'A heart!', audio: 'assets/voice/sr_heart.m4a');
  static const crash = Prompt(text: 'Oops! What a great run!', audio: 'assets/voice/sr_crash.m4a');

  /// A caught letter, said by its name.
  static Prompt letter(String l) => Prompt(text: '$l!', audio: 'assets/voice/sr_letter_${l.toLowerCase()}.m4a');
}
