// Made by tools/games/cut_smash_art.py: do not edit.
import 'dart:ui';

/// Where Pencil is in each pose picture (fractions of the picture).
const msArtBoxes = <String, Rect>{
  'pencil_stand': Rect.fromLTRB(0.025, 0.011, 0.980, 0.995),
  'pencil_ready': Rect.fromLTRB(0.505, 0.111, 0.985, 0.984),
  'pencil_pull': Rect.fromLTRB(0.261, 0.111, 0.765, 0.993),
  'pencil_throw': Rect.fromLTRB(0.072, 0.109, 0.684, 0.984),
  'pencil_cheer': Rect.fromLTRB(0.385, 0.020, 0.958, 0.870),
  'pencil_oops': Rect.fromLTRB(0.330, 0.039, 0.717, 0.936),
  'pencil_point': Rect.fromLTRB(0.017, 0.036, 0.662, 0.936),
};

/// Where he stands in each pose picture: his pencil tip's x and the
/// ground line (fractions of the picture).
const msPencilFeet = <String, Offset>{
  'pencil_stand': Offset(0.540, 0.995),
  'pencil_ready': Offset(0.678, 0.984),
  'pencil_pull': Offset(0.578, 0.993),
  'pencil_throw': Offset(0.234, 0.984),
  'pencil_cheer': Offset(0.690, 0.936),
  'pencil_oops': Offset(0.517, 0.936),
  'pencil_point': Offset(0.283, 0.936),
};
