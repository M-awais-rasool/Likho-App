// Made by tools/games/cut_smash_layers.py: do not edit.
import 'dart:ui';

/// A background layer picture: its width over its height, and where
/// its hill tops (or the grass top) run, a fraction of its height.
class MsLayerLine {
  const MsLayerLine(this.aspect, this.line);
  final double aspect, line;
}

/// Meadow: the sky, far hills, near hills and the ground.
const msMeadowSky = MsLayerLine(3.0000, 0.0000);
const msMeadowFar = MsLayerLine(5.5408, 0.2832);
const msMeadowNear = MsLayerLine(5.7158, 0.2605);
const msMeadowGround = MsLayerLine(5.0162, 0.0647);

/// Where the windmill stood on meadow's far hills: its foot and its
/// height (foot to roof top), fractions of the picture.
const msMeadowMill = Offset(0.6413, 0.2245);
const msMeadowMillSize = 0.1607;
