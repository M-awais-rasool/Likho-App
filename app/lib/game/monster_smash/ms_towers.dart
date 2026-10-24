import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Monster Smash's towers: where each block and monster stands before the
/// first shot. World units are metres; x runs right from the left edge of
/// the screen (16 m wide), y up from the ground. Pencil and his slingshot
/// stand on the left, the towers between x 9 and 15.

enum MsMaterial { wood, ice, stone }

enum MsShape { square, plank, triangle, disc }

/// The sizes of the shapes (the art's proportions).
abstract final class MsSize {
  static const square = .8;
  static const plankW = 2.4, plankH = .56;
  static const triW = .8, triH = .71;
  static const disc = .4; // radius

  /// A monster's body: a box with cut corners, this half size.
  static const monster = .34;
}

@immutable
class MsPiece {
  const MsPiece(this.shape, this.material, this.x, this.y, {this.letter = false});
  final MsShape shape;
  final MsMaterial material;

  /// The centre.
  final double x, y;

  /// A square that can carry a letter: one the ball can reach (not one
  /// hidden behind another under a plank).
  final bool letter;
}

@immutable
class MsSpot {
  const MsSpot(this.x, this.y);

  /// The centre of the monster's body.
  final double x, y;
}

@immutable
class MsPlan {
  const MsPlan(this.pieces, this.monsters);
  final List<MsPiece> pieces;
  final List<MsSpot> monsters;

  MsPlan operator +(MsPlan o) => MsPlan([...pieces, ...o.pieces], [...monsters, ...o.monsters]);

  int get letterSpots => pieces.where((p) => p.letter).length;
}

/// The tower kinds, built around a centre [c] on the ground.
abstract final class MsTowers {
  static const _gap = .01; // between stacked blocks, so nothing starts squeezed
  static const _s = MsSize.square, _ph = MsSize.plankH, _m = MsSize.monster;

  /// The y of a square's centre in row [row] of squares (0 on the ground).
  static double _row(int row, {int planks = 0}) => _s / 2 + row * (_s + _gap) + planks * (_ph + _gap);

  /// Two columns of two squares, a plank across, a monster on it
  /// (triangles beside him when [roof]).
  static MsPlan gate(double c, MsMaterial col, MsMaterial plank, {bool roof = false}) {
    const dx = .75;
    final top = _row(2) - _s / 2 + _ph / 2;
    final above = top + _ph / 2 + _gap;
    return MsPlan(
      [
        MsPiece(MsShape.square, col, c - dx, _row(0), letter: true),
        MsPiece(MsShape.square, col, c - dx, _row(1), letter: true),
        MsPiece(MsShape.square, col, c + dx, _row(0)),
        MsPiece(MsShape.square, col, c + dx, _row(1)),
        MsPiece(MsShape.plank, plank, c, top),
        if (roof) ...[MsPiece(MsShape.triangle, plank, c - .78, above + MsSize.triH / 2), MsPiece(MsShape.triangle, plank, c + .78, above + MsSize.triH / 2)],
      ],
      [MsSpot(c, above + _m)],
    );
  }

  /// Three squares, two on them, one on top, a monster on the top one.
  static MsPlan pyramid(double c, MsMaterial a, MsMaterial b) {
    const d = _s + .02;
    return MsPlan(
      [
        MsPiece(MsShape.square, a, c - d, _row(0), letter: true),
        MsPiece(MsShape.square, b, c, _row(0)),
        MsPiece(MsShape.square, a, c + d, _row(0)),
        MsPiece(MsShape.square, b, c - d / 2, _row(1), letter: true),
        MsPiece(MsShape.square, b, c + d / 2, _row(1), letter: true),
        MsPiece(MsShape.square, a, c, _row(2), letter: true),
      ],
      [MsSpot(c, _row(3) - _s / 2 + _m)],
    );
  }

  /// Two floors: columns, a plank, columns, a plank, a monster on top and
  /// one hiding on the ground inside.
  static MsPlan tall(double c, MsMaterial col, MsMaterial plank, {bool disc = false}) {
    const dx = .75;
    final p1 = _row(1) - _s / 2 + _ph / 2;
    final top = _row(2, planks: 1) - _s / 2 + _ph / 2;
    final above = top + _ph / 2 + _gap;
    return MsPlan(
      [
        MsPiece(MsShape.square, col, c - dx, _row(0), letter: true),
        MsPiece(MsShape.square, col, c + dx, _row(0)),
        MsPiece(MsShape.plank, plank, c, p1),
        MsPiece(MsShape.square, col, c - dx, _row(1, planks: 1), letter: true),
        MsPiece(MsShape.square, col, c + dx, _row(1, planks: 1)),
        MsPiece(MsShape.plank, plank, c, top),
        if (disc) MsPiece(MsShape.disc, MsMaterial.stone, c + .75, above + MsSize.disc),
      ],
      [MsSpot(c - (disc ? .3 : 0), above + _m), MsSpot(c, _m + _gap)],
    );
  }

  /// A column of [n] squares with a monster on top.
  static MsPlan column(double c, MsMaterial m, int n) =>
      MsPlan([for (var i = 0; i < n; i++) MsPiece(MsShape.square, m, c, _row(i), letter: true)], [MsSpot(c, _row(n) - _s / 2 + _m)]);

  /// Tower [round] of a game (0, 1, 2 …): bigger and harder each time.
  /// [r] moves things a little, so no two games look the same.
  static MsPlan forRound(int round, math.Random r) {
    double jiggle(double x) => x + (r.nextDouble() - .5) * .5;
    MsMaterial pick(List<MsMaterial> ms) => ms[r.nextInt(ms.length)];
    const wood = MsMaterial.wood, ice = MsMaterial.ice, stone = MsMaterial.stone;
    switch (round % 3) {
      case 0:
        return r.nextBool()
            ? gate(jiggle(10.4), wood, wood) + column(jiggle(13.4), wood, 2)
            : column(jiggle(9.8), wood, 2) + gate(jiggle(12.8), wood, wood, roof: true);
      case 1:
        return r.nextBool()
            ? pyramid(jiggle(10.2), wood, ice) + gate(jiggle(13.4), pick([wood, ice]), wood, roof: true)
            : gate(jiggle(10.0), ice, wood) + pyramid(jiggle(13.3), ice, wood);
      default:
        return r.nextBool()
            ? tall(jiggle(10.4), pick([stone, wood]), ice, disc: true) + pyramid(jiggle(13.6), ice, stone)
            : pyramid(jiggle(10.0), stone, ice) + tall(jiggle(13.4), wood, stone, disc: true);
    }
  }
}
