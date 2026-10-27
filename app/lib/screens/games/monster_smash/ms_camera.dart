import 'dart:ui';

import '../game_spring.dart';

/// Monster Smash's camera over the base view ([MsView]: the whole room fits
/// the screen). It looks at [focus] (a point of the base view) with a
/// [zoom] of 1 or more, and never shows past the base frame, so the
/// backdrop always covers the screen. Springs make every move soft.
class MsCamera {
  MsCamera(this.screen) : _x = Spring(screen.width / 2, stiffness: 26, damping: 10), _y = Spring(screen.height / 2, stiffness: 26, damping: 10);

  Size screen;
  final Spring _x, _y;
  final _z = Spring(1, stiffness: 26, damping: 10);

  Offset get centre => Offset(screen.width / 2, screen.height / 2);

  double get zoom => _z.value.clamp(1.0, 2.0);

  /// Where it looks (base view), kept inside the frame for this zoom.
  Offset get focus => _clamp(Offset(_x.value, _y.value), zoom);

  Offset _clamp(Offset f, double z) {
    final hw = screen.width / (2 * z), hh = screen.height / (2 * z);
    return Offset(f.dx.clamp(hw, screen.width - hw), f.dy.clamp(hh, screen.height - hh));
  }

  /// Look at [at] (base view) with [zoom], softly.
  void look(Offset at, double zoom) {
    final f = _clamp(at, zoom);
    _x.target = f.dx;
    _y.target = f.dy;
    _z.target = zoom;
  }

  /// The whole room.
  void wide() => look(centre, 1);

  /// Jump there now (the first frame of a room).
  void snap(Offset at, double zoom) {
    final f = _clamp(at, zoom);
    _x.snap(f.dx);
    _y.snap(f.dy);
    _z.snap(zoom);
  }

  void step(double dt) {
    _x.step(dt);
    _y.step(dt);
    _z.step(dt);
  }

  /// A base-view point on the screen, and back.
  Offset apply(Offset p) => (p - focus) * zoom + centre;
  Offset unapply(Offset s) => (s - centre) / zoom + focus;

  /// Draws what follows as the camera sees it.
  void transform(Canvas c) {
    final f = focus, z = zoom;
    c.translate(screen.width / 2, screen.height / 2);
    c.scale(z);
    c.translate(-f.dx, -f.dy);
  }

  /// The same for a backdrop layer [depth] away (0 the sky, which never
  /// moves, 1 the ground the game stands on): far layers move and zoom less.
  void transformLayer(Canvas c, double depth) {
    final f = centre + (focus - centre) * depth, z = 1 + (zoom - 1) * depth;
    c.translate(screen.width / 2, screen.height / 2);
    c.scale(z);
    c.translate(-f.dx, -f.dy);
  }
}
