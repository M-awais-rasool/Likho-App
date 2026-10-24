import '../../../data/models/course_models.dart';

/// Pencil's lines in Letter Slice, kept in the app (recorded by
/// `tools/voice/generate_voice.py --app`, SLICE_LINES there: the same
/// words, which his bubble shows). The tasks name their own lines
/// (LsTask.audio, LsTask.doneAudio), and a sliced letter is said by its
/// name ([letter]).
abstract final class LsLines {
  static const intro = Prompt(text: 'Swipe to slice the fruit with the letter I ask for!', audio: 'assets/voice/ls_intro.m4a');
  static const count = [
    Prompt(text: 'One!', audio: 'assets/voice/sr_1.m4a'),
    Prompt(text: 'Two!', audio: 'assets/voice/sr_2.m4a'),
    Prompt(text: 'Three!', audio: 'assets/voice/sr_3.m4a'),
  ];
  static const go = Prompt(text: 'Go!', audio: 'assets/voice/sr_go.m4a');
  static const great = [
    Prompt(text: 'Juicy!', audio: 'assets/voice/ls_great_1.m4a'),
    Prompt(text: 'Super slicer!', audio: 'assets/voice/ls_great_2.m4a'),
    Prompt(text: 'Yes! All done!', audio: 'assets/voice/ls_great_3.m4a'),
  ];
  static const oops = Prompt(text: 'Oops! Not that letter.', audio: 'assets/voice/sr_oops.m4a');
  static const combo = Prompt(text: 'Combo!', audio: 'assets/voice/ls_combo.m4a');
  static const star = Prompt(text: 'A golden star!', audio: 'assets/voice/ls_star.m4a');
  static const freeze = Prompt(text: 'Slow motion!', audio: 'assets/voice/ls_freeze.m4a');
  static const frenzy = Prompt(text: 'Fruit party! Slice them all!', audio: 'assets/voice/ls_frenzy.m4a');
  static const hurry = Prompt(text: 'Ten seconds left!', audio: 'assets/voice/ls_hurry.m4a');
  static const timeUp = Prompt(text: "Time's up! Great slicing!", audio: 'assets/voice/ls_time_up.m4a');
  static const record = Prompt(text: 'Wow! A new best score!', audio: 'assets/voice/sr_record.m4a');

  /// A sliced letter, said by its name.
  static Prompt letter(String l) => Prompt(text: '$l!', audio: 'assets/voice/sr_letter_${l.toLowerCase()}.m4a');
}
