import 'dart:math' as math;
import 'dart:ui';

/// Geometry of the Pencil rig, measured on the master image
/// (mascot's/Gemini_Generated_Image_ic1bzv…jpeg).
///
/// Artboard units: 1 unit = 1 master pixel, origin at master (454, 36).
/// All SVG parts in assets/mascot/ are drawn in this space at their rest pose.
abstract final class PencilRig {
  static const Size artboard = Size(500, 680);

  /// Squash/stretch and whole-body rotation pivot: bottom centre of the feet.
  static const Offset feet = Offset(250, 646);

  /// Top of the eraser, used to normalise the body bend.
  static const double topY = 50;

  static const Offset shadowCentre = Offset(250, 640.5);
  static const Size shadowRadii = Size(164, 16.5);

  // ---------------------------------------------------------------- arms
  // Noodle arms: quadratic Bézier from the shoulder (hidden inside the body)
  // to the wrist, fitted to the master's arm edges (rms error 0.33 units).
  static const armLeft = ArmRest(
    shoulder: Offset(138, 368),
    control: Offset(85.653, 378.628),
    wrist: Offset(70.639, 452.150),
    tangent: Offset(-0.2001, 0.9798),
  );
  static const armRight = ArmRest(
    shoulder: Offset(362, 368),
    control: Offset(414.210, 378.187),
    wrist: Offset(429.794, 452.123),
    tangent: Offset(0.2063, 0.9785),
  );

  /// Half-width of the arm (outline included) along its length.
  static const List<(double, double)> armHalfWidth = [(0, 29), (0.2, 24), (0.35, 20.2), (0.65, 20.0), (1.0, 21.5)];
  static const double armLine = 4.6;
  static const double armLightWidth = 7.5; // light stripe on the outer edge
  static const double armLightFrom = 0.12;
  static const double armDarkWidth = 5.5; // dark stripe on the inner edge
  static const double armDarkFrom = 0.1;

  static double armHalfWidthAt(double s) {
    for (var i = 0; i < armHalfWidth.length - 1; i++) {
      final (a, ha) = armHalfWidth[i];
      final (b, hb) = armHalfWidth[i + 1];
      if (s <= b) return ha + (hb - ha) * ((s - a) / (b - a));
    }
    return armHalfWidth.last.$2;
  }

  // ---------------------------------------------------------------- legs
  static const Offset hipLeft = Offset(182, 518);
  static const Offset hipRight = Offset(318, 518);

  // ---------------------------------------------------------------- face
  static const Offset faceCentre = Offset(250, 300);
  static const eyeLeft = EyeRest(
    white: Offset(192.27, 292.78),
    pupilOffset: Offset(4.85, -0.79),
    rimOffset: Offset(-2.64, -2.04),
  );
  static const eyeRight = EyeRest(
    white: Offset(307.94, 292.74),
    pupilOffset: Offset(-4.82, -0.73),
    rimOffset: Offset(2.83, -2.07),
  );
  static const double eyeWhiteR = 32;
  static const double pupilR = 24.5;
  static const double rimR = 34.5;
  static const Offset highlightOffset = Offset(-11, -11);
  static const double highlightR = 6.5;
  static const double lidLine = 5; // lash line on the eyelid edge
  static const double pupilTravel = 7.0; // max look offset before touching the rim

  static const Offset browLeft = Offset(181.1, 238.0);
  static const Offset browRight = Offset(319.6, 237.9);
  static const Offset cheekLeft = Offset(170.5, 341.9);
  static const Offset cheekRight = Offset(329.4, 341.6);
  static const Offset mouthCentre = Offset(250.1, 333.6);

  // ---------------------------------------------------------------- effects
  /// Centres of the three "z" parts (fx/zzz_*.svg), from the sleepy cell.
  static const List<Offset> zzz = [Offset(401.7, 234.2), Offset(432.9, 210.3), Offset(471.5, 184.6)];

  /// Ends of the metal band: the wow "surprise lines" radiate from here.
  static const Offset bandLeftEnd = Offset(113, 150);
  static const Offset bandRightEnd = Offset(387, 150);

  // ---------------------------------------------------------------- bend
  /// Horizontal displacement of the torso at height [y] for a given lean
  /// (lean = displacement at the top of the eraser). Quadratic, zero at the feet.
  static double bendDx(double lean, double y) {
    final k = ((feet.dy - y) / (feet.dy - topY)).clamp(0.0, 1.5);
    return lean * k * k;
  }

  /// Local rotation of the torso at height [y] caused by the bend (radians,
  /// positive = clockwise on screen).
  static double bendAngle(double lean, double y) {
    final h = feet.dy - topY;
    final k = ((feet.dy - y) / h).clamp(0.0, 1.5);
    return math.atan(2 * lean * k / h);
  }
}

class ArmRest {
  const ArmRest({required this.shoulder, required this.control, required this.wrist, required this.tangent});
  final Offset shoulder;
  final Offset control;
  final Offset wrist;

  /// Direction of the arm at the wrist (unit), i.e. how the hand is attached.
  final Offset tangent;
}

class EyeRest {
  const EyeRest({required this.white, required this.pupilOffset, required this.rimOffset});

  /// Centre of the eye white.
  final Offset white;

  /// Rest position of the pupil relative to the white (the eyes converge slightly).
  final Offset pupilOffset;

  /// The brown rim is a circle offset up and outward, giving a crescent rim.
  final Offset rimOffset;
}
