import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_controls.dart';

/// Pencil's spoken lines in the app's own screens (not the course), kept in
/// the app so they play before anything is downloaded. Recorded with the
/// course voice by `tools/voice/generate_voice.py --app` (APP_LINES there),
/// each with its mouth movement next to it (.lip).
abstract final class PencilLines {
  /// Add child, step 1: "Hi, I'm Pencil! What's your name? Ask a grown-up to type it."
  static const name = 'assets/voice/onb_name.m4a';

  /// Add child, step 2: "Nice to meet you! How old are you? Tap your birthday cake."
  static const age = 'assets/voice/onb_age.m4a';

  /// Add child, step 3: "Now pick my colour! Which one do you like?"
  static const colour = 'assets/voice/onb_colour.m4a';

  /// Placement done: "Let's get started!"
  static const letsStart = 'assets/voice/lets_start.m4a';

  static const all = [name, age, colour, letsStart];
}

/// Whether Pencil speaks [PencilLines]. Off by default (tests); main()
/// turns it on.
final pencilVoiceProvider = Provider<bool>((ref) => false);

/// Whether Pencil speaks now: his voice is on in this build and the team
/// has not switched it off (App controls); without it his bubbles still
/// show what he says.
final voiceOnProvider = Provider<bool>((ref) => ref.watch(pencilVoiceProvider) && ref.watch(featureOnProvider(Feature.voice)));
