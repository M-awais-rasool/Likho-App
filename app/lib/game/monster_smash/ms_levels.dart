import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'ms_towers.dart';

/// Monster Smash's levels, like Angry Birds 2: each level is one to three
/// rooms (a room is a tower scene; clearing it moves on to the next), played
/// with a line of heroes. The worlds follow the course's worlds; the first
/// is Letter Land.

/// The Stationery Squad: what the child flings. A tap while one flies uses
/// its power.
enum MsHero {
  /// Rubby the eraser: a tap gives a big "boing" that pushes everything in
  /// front of him.
  rubby,

  /// Inky the ink drop: a tap splits him into three drops.
  inky,

  /// Crayo the crayon: a tap sends him zooming straight on, through wood
  /// and ice.
  crayo,
}

/// One room: its towers (built from the dice, so no two plays look the
/// same), how many letters stand on its blocks and how many are asked.
@immutable
class MsRoom {
  const MsRoom(this.build, {this.letters = 3, this.asks = 2});
  final MsPlan Function(math.Random r) build;
  final int letters, asks;
}

@immutable
class MsLevel {
  const MsLevel({required this.number, required this.rooms, required this.heroes, this.newHero});

  /// 1, 2, 3 … in its world.
  final int number;
  final List<MsRoom> rooms;

  /// The heroes in line at the start (the first goes first); they last the
  /// whole level.
  final List<MsHero> heroes;

  /// A hero met for the first time in this level (shown before it starts).
  final MsHero? newHero;
}

/// The worlds' levels.
abstract final class MsLevels {
  static const wood = MsMaterial.wood, ice = MsMaterial.ice, stone = MsMaterial.stone;
  static const _r = MsHero.rubby, _i = MsHero.inky, _c = MsHero.crayo;

  /// A centre moved a little by the dice.
  static double _j(math.Random r, double x) => x + (r.nextDouble() - .5) * .4;

  /// Letter Land: 12 levels, one room at first, then two and three; Inky
  /// joins in level 3, Crayo in level 5; ice from level 4, stone from 8.
  static final List<MsLevel> letterLand = [
    MsLevel(number: 1, rooms: [MsRoom((r) => MsTowers.column(_j(r, 10.4), wood, 2) + MsTowers.gate(_j(r, 13.3), wood, wood))], heroes: [_r, _r, _r, _r]),
    MsLevel(
      number: 2,
      rooms: [MsRoom((r) => MsTowers.gate(_j(r, 10.2), wood, wood, roof: true) + MsTowers.column(_j(r, 13.6), wood, 3))],
      heroes: [_r, _r, _r, _r],
    ),
    MsLevel(number: 3, rooms: [MsRoom((r) => MsTowers.pyramid(_j(r, 11.8), wood, wood))], heroes: [_i, _r, _i, _r], newHero: _i),
    MsLevel(
      number: 4,
      rooms: [
        MsRoom((r) => MsTowers.column(_j(r, 10.2), wood, 2) + MsTowers.gate(_j(r, 13.2), ice, wood)),
        MsRoom((r) => MsTowers.pyramid(_j(r, 10.4), wood, ice) + MsTowers.column(_j(r, 13.8), ice, 2)),
      ],
      heroes: [_r, _i, _r, _i, _r, _r],
    ),
    MsLevel(
      number: 5,
      rooms: [
        MsRoom((r) => MsTowers.gate(_j(r, 10.4), wood, wood) + MsTowers.column(_j(r, 13.4), wood, 2)),
        MsRoom((r) => MsTowers.tall(_j(r, 12.0), wood, wood)),
      ],
      heroes: [_c, _r, _c, _i, _r, _c],
      newHero: _c,
    ),
    MsLevel(
      number: 6,
      rooms: [
        MsRoom((r) => MsTowers.pyramid(_j(r, 10.2), ice, wood) + MsTowers.gate(_j(r, 13.4), wood, wood, roof: true)),
        MsRoom((r) => MsTowers.gate(_j(r, 10.0), ice, wood) + MsTowers.pyramid(_j(r, 13.3), ice, wood), letters: 4),
      ],
      heroes: [_i, _c, _r, _i, _c, _r],
    ),
    MsLevel(
      number: 7,
      rooms: [
        MsRoom((r) => MsTowers.column(_j(r, 9.8), wood, 2) + MsTowers.gate(_j(r, 12.8), wood, wood, roof: true)),
        MsRoom((r) => MsTowers.tall(_j(r, 10.4), wood, ice) + MsTowers.column(_j(r, 13.8), ice, 3), letters: 4),
      ],
      heroes: [_c, _i, _r, _c, _i, _r],
    ),
    MsLevel(
      number: 8,
      rooms: [
        MsRoom((r) => MsTowers.pyramid(_j(r, 10.0), stone, ice) + MsTowers.column(_j(r, 13.6), wood, 2)),
        MsRoom((r) => MsTowers.tall(_j(r, 10.4), stone, ice, disc: true) + MsTowers.pyramid(_j(r, 13.6), ice, stone), letters: 4, asks: 3),
      ],
      heroes: [_r, _c, _i, _r, _c, _i, _r],
    ),
    MsLevel(
      number: 9,
      rooms: [
        MsRoom((r) => MsTowers.gate(_j(r, 10.4), wood, wood) + MsTowers.column(_j(r, 13.4), wood, 2)),
        MsRoom((r) => MsTowers.pyramid(_j(r, 10.2), wood, ice) + MsTowers.gate(_j(r, 13.4), ice, wood, roof: true), letters: 4),
        MsRoom((r) => MsTowers.tall(_j(r, 12.0), wood, ice)),
      ],
      heroes: [_i, _r, _c, _i, _r, _c, _r, _i],
    ),
    MsLevel(
      number: 10,
      rooms: [
        MsRoom((r) => MsTowers.column(_j(r, 10.0), ice, 3) + MsTowers.gate(_j(r, 13.0), ice, wood, roof: true)),
        MsRoom((r) => MsTowers.gate(_j(r, 10.0), ice, wood) + MsTowers.pyramid(_j(r, 13.3), ice, wood), letters: 4, asks: 3),
        MsRoom((r) => MsTowers.pyramid(_j(r, 10.0), stone, ice) + MsTowers.tall(_j(r, 13.4), wood, stone, disc: true), letters: 4),
      ],
      heroes: [_c, _i, _r, _c, _i, _r, _c, _i],
    ),
    MsLevel(
      number: 11,
      rooms: [
        MsRoom((r) => MsTowers.pyramid(_j(r, 10.2), wood, ice) + MsTowers.column(_j(r, 13.6), stone, 2)),
        MsRoom((r) => MsTowers.tall(_j(r, 10.4), wood, ice, disc: true) + MsTowers.pyramid(_j(r, 13.6), ice, stone), letters: 4, asks: 3),
        MsRoom((r) => MsTowers.gate(_j(r, 10.0), stone, wood, roof: true) + MsTowers.tall(_j(r, 13.4), ice, wood), letters: 4, asks: 3),
      ],
      heroes: [_r, _c, _i, _r, _c, _i, _r, _c, _i],
    ),
    MsLevel(
      number: 12,
      rooms: [
        MsRoom((r) => MsTowers.gate(_j(r, 10.0), ice, wood, roof: true) + MsTowers.pyramid(_j(r, 13.3), ice, wood), letters: 4),
        MsRoom((r) => MsTowers.tall(_j(r, 10.4), stone, ice, disc: true) + MsTowers.pyramid(_j(r, 13.6), ice, stone), letters: 5, asks: 3),
        MsRoom((r) => MsTowers.pyramid(_j(r, 10.0), stone, ice) + MsTowers.tall(_j(r, 13.4), wood, stone, disc: true), letters: 5, asks: 3),
      ],
      heroes: [_c, _i, _r, _c, _i, _r, _c, _i, _r],
    ),
  ];

  /// The old three-tower game (tests and the web preview): a meadow, a
  /// beach and the snow's towers, bigger each time.
  static MsLevel classic() => MsLevel(
    number: 0,
    rooms: [
      for (var k = 0; k < 3; k++) MsRoom((r) => MsTowers.forRound(k, r), letters: [3, 4, 5][k], asks: [2, 3, 3][k]),
    ],
    heroes: [for (var k = 0; k < 4; k++) _r],
  );
}
