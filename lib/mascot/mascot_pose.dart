import 'dart:ui' show lerpDouble;

/// The eight animation states from the brief.
enum MascotState {
  idle(loop: true),
  talking(loop: true),
  watching(loop: true),
  happy(duration: 1.2),
  encourage(duration: 1.2),
  wow(duration: 1.0),
  dance(duration: 2.0),
  sleepy(duration: 2.5),

  /// Extra loop used by the Splash screen (the prototype's "wave" pose).
  wave(loop: true),

  /// Extra loop used by Fix-It (the prototype's "think" pose): fist at the
  /// chin, looking up, head tilted.
  think(loop: true);

  const MascotState({this.loop = false, this.duration = 0});
  final bool loop;

  /// Seconds, for one-shot states.
  final double duration;
}

enum EyeStyle { normal, happy, wow }

enum MouthShape {
  closed('mouth_closed'),
  openSmall('mouth_open_small'),
  openA('mouth_open_a'),
  o('mouth_o'),
  ee('mouth_ee'),
  laugh('mouth_laugh'),
  gentle('mouth_gentle'),
  yawn('mouth_yawn');

  const MouthShape(this.part);
  final String part;
}

enum HandShape {
  rest(''),
  open('hand_open'),
  wave('hand_wave'),
  thumbsUp('hand_thumbs_up'),
  point('hand_point'),
  fist('hand_fist'),
  star('hand_star');

  const HandShape(this.part);
  final String part;
}

double _l(double a, double b, double t) => lerpDouble(a, b, t)!;

/// Pose of one arm, relative to its rest pose.
class ArmPose {
  const ArmPose({this.raise = 0, this.bend = 0, this.reach = 1, this.handTurn = 0, this.hand = HandShape.rest, this.front = false});

  /// Rotation at the shoulder in radians; positive lifts the arm outward/up.
  final double raise;

  /// Extra bulge of the noodle (artboard units); positive bulges outward.
  final double bend;

  /// Length multiplier.
  final double reach;

  /// Extra hand rotation at the wrist in radians (mirrored for the left hand).
  final double handTurn;
  final HandShape hand;

  /// Draw the arm in front of the body (e.g. hands together while watching).
  /// On the master both arms sit behind the body, so rest poses keep false.
  final bool front;

  static const rest = ArmPose();

  ArmPose copyWith({double? raise, double? bend, double? reach, double? handTurn, HandShape? hand, bool? front}) => ArmPose(
        raise: raise ?? this.raise,
        bend: bend ?? this.bend,
        reach: reach ?? this.reach,
        handTurn: handTurn ?? this.handTurn,
        hand: hand ?? this.hand,
        front: front ?? this.front,
      );

  static ArmPose lerp(ArmPose a, ArmPose b, double t) => ArmPose(
        raise: _l(a.raise, b.raise, t),
        bend: _l(a.bend, b.bend, t),
        reach: _l(a.reach, b.reach, t),
        handTurn: _l(a.handTurn, b.handTurn, t),
        hand: t < 0.5 ? a.hand : b.hand,
        front: t < 0.5 ? a.front : b.front,
      );
}

/// Every animatable value of the rig. Numbers blend; shapes switch half-way.
class MascotPose {
  const MascotPose({
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.lean = 0,
    this.eraserDrop = 0,
    this.faceOffset = 0,
    this.lookX = 0,
    this.lookY = 0,
    this.lid = 0,
    this.lidTilt = 0,
    this.eyes = EyeStyle.normal,
    this.eyeScale = 1,
    this.browY = 0,
    this.browTilt = 0,
    this.mouth = MouthShape.closed,
    this.mouthScale = 1,
    this.blush = 0,
    this.armLeft = ArmPose.rest,
    this.armRight = ArmPose.rest,
    this.legLeft = 0,
    this.legRight = 0,
    this.zzz = 0,
    this.surprise = 0,
    this.motionLines = 0,
  });

  // whole body, around the feet
  final double x, y, rotation, scaleX, scaleY;

  /// Body bend: horizontal shift at the top of the eraser (artboard units).
  final double lean;

  /// Follow-through of the eraser "hat" (artboard units, + = down).
  final double eraserDrop;

  /// Face shift down (+) / up (-) on the body.
  final double faceOffset;

  // eyes
  final double lookX, lookY; // -1..1, added to the look-at target
  final double lid; // 0 open .. 1 closed
  final double lidTilt; // radians, + droops the outer corners
  final EyeStyle eyes;
  final double eyeScale;

  // brows
  final double browY; // + = down
  final double browTilt; // radians, + lowers the outer ends

  final MouthShape mouth;
  final double mouthScale;
  final double blush; // 0..1

  final ArmPose armLeft, armRight;
  final double legLeft, legRight; // hip rotation, + = outward

  // effects 0..1
  final double zzz, surprise, motionLines;

  static const idle = MascotPose();

  MascotPose copyWith({
    double? x,
    double? y,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? lean,
    double? eraserDrop,
    double? faceOffset,
    double? lookX,
    double? lookY,
    double? lid,
    double? lidTilt,
    EyeStyle? eyes,
    double? eyeScale,
    double? browY,
    double? browTilt,
    MouthShape? mouth,
    double? mouthScale,
    double? blush,
    ArmPose? armLeft,
    ArmPose? armRight,
    double? legLeft,
    double? legRight,
    double? zzz,
    double? surprise,
    double? motionLines,
  }) =>
      MascotPose(
        x: x ?? this.x,
        y: y ?? this.y,
        rotation: rotation ?? this.rotation,
        scaleX: scaleX ?? this.scaleX,
        scaleY: scaleY ?? this.scaleY,
        lean: lean ?? this.lean,
        eraserDrop: eraserDrop ?? this.eraserDrop,
        faceOffset: faceOffset ?? this.faceOffset,
        lookX: lookX ?? this.lookX,
        lookY: lookY ?? this.lookY,
        lid: lid ?? this.lid,
        lidTilt: lidTilt ?? this.lidTilt,
        eyes: eyes ?? this.eyes,
        eyeScale: eyeScale ?? this.eyeScale,
        browY: browY ?? this.browY,
        browTilt: browTilt ?? this.browTilt,
        mouth: mouth ?? this.mouth,
        mouthScale: mouthScale ?? this.mouthScale,
        blush: blush ?? this.blush,
        armLeft: armLeft ?? this.armLeft,
        armRight: armRight ?? this.armRight,
        legLeft: legLeft ?? this.legLeft,
        legRight: legRight ?? this.legRight,
        zzz: zzz ?? this.zzz,
        surprise: surprise ?? this.surprise,
        motionLines: motionLines ?? this.motionLines,
      );

  static MascotPose lerp(MascotPose a, MascotPose b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return MascotPose(
      x: _l(a.x, b.x, t),
      y: _l(a.y, b.y, t),
      rotation: _l(a.rotation, b.rotation, t),
      scaleX: _l(a.scaleX, b.scaleX, t),
      scaleY: _l(a.scaleY, b.scaleY, t),
      lean: _l(a.lean, b.lean, t),
      eraserDrop: _l(a.eraserDrop, b.eraserDrop, t),
      faceOffset: _l(a.faceOffset, b.faceOffset, t),
      lookX: _l(a.lookX, b.lookX, t),
      lookY: _l(a.lookY, b.lookY, t),
      lid: _l(a.lid, b.lid, t),
      lidTilt: _l(a.lidTilt, b.lidTilt, t),
      eyes: t < 0.5 ? a.eyes : b.eyes,
      eyeScale: _l(a.eyeScale, b.eyeScale, t),
      browY: _l(a.browY, b.browY, t),
      browTilt: _l(a.browTilt, b.browTilt, t),
      mouth: t < 0.5 ? a.mouth : b.mouth,
      mouthScale: _l(a.mouthScale, b.mouthScale, t),
      blush: _l(a.blush, b.blush, t),
      armLeft: ArmPose.lerp(a.armLeft, b.armLeft, t),
      armRight: ArmPose.lerp(a.armRight, b.armRight, t),
      legLeft: _l(a.legLeft, b.legLeft, t),
      legRight: _l(a.legRight, b.legRight, t),
      zzz: _l(a.zzz, b.zzz, t),
      surprise: _l(a.surprise, b.surprise, t),
      motionLines: _l(a.motionLines, b.motionLines, t),
    );
  }
}
