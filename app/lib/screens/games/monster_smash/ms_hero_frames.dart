// Made by tools/games/cut_smash_heroes.py: do not edit.
import 'dart:ui';

/// A hero's pose picture, in hero radii: where the ball's middle is (from
/// the top left), the picture's size, how far below the middle the feet
/// are and which way a long pose points (radians, y down).
class MsHeroFrame {
  const MsHeroFrame(this.middle, this.size, {required this.foot, required this.tilt});
  final Offset middle;
  final Size size;
  final double foot, tilt;
}

const msHeroFrames = <String, MsHeroFrame>{
  'rubby_idle': MsHeroFrame(Offset(0.986, 1.193), Size(1.969, 2.281), foot: 1.069, tilt: 1.570),
  'rubby_aim': MsHeroFrame(Offset(1.102, 1.123), Size(2.208, 2.083), foot: 0.941, tilt: -0.027),
  'rubby_fly': MsHeroFrame(Offset(1.395, 1.138), Size(2.698, 2.052), foot: 0.894, tilt: -0.362),
  'rubby_power': MsHeroFrame(Offset(1.304, 0.937), Size(2.604, 1.729), foot: 0.772, tilt: -0.001),
  'rubby_bonked': MsHeroFrame(Offset(1.053, 1.114), Size(2.083, 2.042), foot: 0.906, tilt: 0.039),
  'rubby_happy': MsHeroFrame(Offset(0.950, 1.182), Size(1.875, 2.260), foot: 1.060, tilt: -1.386),
  'inky_idle': MsHeroFrame(Offset(0.999, 1.192), Size(2.000, 2.323), foot: 1.107, tilt: 1.559),
  'inky_aim': MsHeroFrame(Offset(1.148, 0.937), Size(2.292, 1.729), foot: 0.775, tilt: -0.043),
  'inky_fly': MsHeroFrame(Offset(1.430, 1.139), Size(2.729, 2.062), foot: 0.906, tilt: -0.371),
  'inky_power': MsHeroFrame(Offset(1.058, 1.133), Size(2.219, 2.156), foot: 1.007, tilt: -0.055),
  'inky_bonked': MsHeroFrame(Offset(1.047, 1.125), Size(2.073, 2.062), foot: 0.916, tilt: 0.145),
  'inky_happy': MsHeroFrame(Offset(0.948, 1.147), Size(1.917, 2.219), foot: 1.050, tilt: -1.416),
  'crayo_idle': MsHeroFrame(Offset(1.039, 1.478), Size(2.104, 2.667), foot: 1.170, tilt: 1.543),
  'crayo_aim': MsHeroFrame(Offset(1.039, 1.478), Size(2.104, 2.667), foot: 1.170, tilt: 1.543),
  'crayo_fly': MsHeroFrame(Offset(1.572, 0.820), Size(3.229, 1.698), foot: 0.853, tilt: -0.339),
  'crayo_power': MsHeroFrame(Offset(1.649, 0.744), Size(3.479, 1.604), foot: 0.833, tilt: -0.236),
  'crayo_bonked': MsHeroFrame(Offset(1.037, 1.220), Size(2.156, 2.427), foot: 1.186, tilt: -1.117),
  'crayo_happy': MsHeroFrame(Offset(1.208, 1.376), Size(2.427, 2.688), foot: 1.286, tilt: 1.561),
};
