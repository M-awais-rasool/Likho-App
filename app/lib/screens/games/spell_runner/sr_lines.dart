import '../../../data/models/course_models.dart';
import '../../../game/spell_runner/sr_engine.dart';

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
  static const slideHint = Prompt(text: 'Swipe down to slide!', audio: 'assets/voice/sr_slide_hint.m4a');
  static const duck = Prompt(text: 'Whoa! Slide under it!', audio: 'assets/voice/sr_duck.m4a');
  static const around = Prompt(text: 'Oops! Go around the cart!', audio: 'assets/voice/sr_around.m4a');
  static const record = Prompt(text: 'Wow! A new best score!', audio: 'assets/voice/sr_record.m4a');
  static const longer = Prompt(text: 'Super! Now longer words!', audio: 'assets/voice/sr_longer.m4a');
  static const heart = Prompt(text: 'A heart!', audio: 'assets/voice/sr_heart.m4a');
  static const crash = Prompt(text: 'Oops! What a great run!', audio: 'assets/voice/sr_crash.m4a');

  /// A power-up picked up.
  static Prompt power(SrKind k) => switch (k) {
    SrKind.magnet => const Prompt(text: 'Magnet! The stars come to you!', audio: 'assets/voice/sr_power_magnet.m4a'),
    SrKind.shield => const Prompt(text: 'A shield! One bump is fine!', audio: 'assets/voice/sr_power_shield.m4a'),
    SrKind.spring => const Prompt(text: 'Super spring! Jump up high!', audio: 'assets/voice/sr_power_spring.m4a'),
    _ => const Prompt(text: 'Double stars!', audio: 'assets/voice/sr_power_double.m4a'),
  };

  /// A new part of the road.
  static const zones = [
    Prompt(text: 'Back to the Apple Orchard!', audio: 'assets/voice/sr_zone_0.m4a'),
    Prompt(text: 'Sunflower Fields ahead!', audio: 'assets/voice/sr_zone_1.m4a'),
    Prompt(text: 'Into the Pine Forest!', audio: 'assets/voice/sr_zone_2.m4a'),
    Prompt(text: 'Here comes Sunset Lane!', audio: 'assets/voice/sr_zone_3.m4a'),
  ];

  /// A caught letter, said by its name.
  static Prompt letter(String l) => Prompt(text: '$l!', audio: 'assets/voice/sr_letter_${l.toLowerCase()}.m4a');
}
