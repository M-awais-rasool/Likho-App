import 'dart:ui';

import '../../../game/monster_smash/ms_engine.dart';

/// Measured opaque bounds and body pivots of the generated atlases.
/// One scale per character prevents pose changes from changing body size.
abstract final class MsCrystalArt {
  static const _heroBounds = <MsHero, List<Rect>>{
    MsHero.rubby: [
      Rect.fromLTRB(111, 16, 454, 486),
      Rect.fromLTRB(598, 26, 952, 482),
      Rect.fromLTRB(1057, 28, 1451, 436),
      Rect.fromLTRB(87, 573, 471, 988),
      Rect.fromLTRB(575, 526, 961, 997),
      Rect.fromLTRB(1118, 522, 1472, 997),
    ],
    MsHero.inky: [
      Rect.fromLTRB(98, 40, 455, 456),
      Rect.fromLTRB(599, 43, 943, 455),
      Rect.fromLTRB(1086, 39, 1471, 425),
      Rect.fromLTRB(58, 553, 487, 953),
      Rect.fromLTRB(571, 541, 969, 963),
      Rect.fromLTRB(1103, 548, 1483, 960),
    ],
    MsHero.crayo: [
      Rect.fromLTRB(149, 19, 390, 484),
      Rect.fromLTRB(659, 23, 904, 481),
      Rect.fromLTRB(1056, 156, 1504, 367),
      Rect.fromLTRB(38, 674, 482, 881),
      Rect.fromLTRB(622, 532, 929, 988),
      Rect.fromLTRB(1125, 526, 1436, 990),
    ],
  };

  static Rect heroBounds(MsHero h, int pose) => _heroBounds[h]![pose];

  /// Body centres, rather than the centre of the scarf or extended arms.
  static Offset pivot(MsHero h, int pose) {
    final cell = Offset((pose % 3) * 512, (pose ~/ 3) * 512);
    return cell +
        switch (h) {
          MsHero.rubby => Offset(pose == 2 ? 278 : 258, pose == 3 ? 285 : 280),
          MsHero.inky => const Offset(273, 272),
          MsHero.crayo => Offset(pose == 2 || pose == 3 ? 260 : 270, pose == 2 || pose == 3 ? 260 : 280),
        };
  }

  /// Pixels in the source per world collision radius. The art includes feet,
  /// arms and the crayon tip around the circular physics body.
  static double sourceRadius(MsHero h) => switch (h) {
    MsHero.rubby => 142,
    MsHero.inky => 137,
    MsHero.crayo => 130,
  };

  static const _monsters = [
    Rect.fromLTRB(42, 12, 333, 345),
    Rect.fromLTRB(389, 33, 702, 347),
    Rect.fromLTRB(764, 16, 1039, 349),
    Rect.fromLTRB(1117, 54, 1404, 343),
    Rect.fromLTRB(36, 373, 332, 702),
    Rect.fromLTRB(375, 394, 711, 703),
    Rect.fromLTRB(744, 379, 1066, 703),
    Rect.fromLTRB(1112, 415, 1413, 699),
    Rect.fromLTRB(35, 734, 328, 1051),
    Rect.fromLTRB(374, 757, 706, 1057),
    Rect.fromLTRB(738, 741, 1083, 1054),
    Rect.fromLTRB(1116, 772, 1412, 1047),
  ];

  static Rect monster(String kind, String pose) {
    final column = switch (kind) {
      'fuzz' => 1,
      'bonk' => 2,
      'boo' => 3,
      _ => 0,
    };
    final row = switch (pose) {
      'surprised' || 'bonked' => 1,
      'friendly' || 'roar' => 2,
      _ => 0,
    };
    return _monsters[row * 4 + column];
  }
}
