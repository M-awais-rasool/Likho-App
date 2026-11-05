import 'package:flutter/painting.dart';

import '../../../game/letter_slice/ls_engine.dart';

/// Bundled cover / legacy art references and juice colours. The live game
/// now uses resolution-independent artwork in ls_art.dart.
abstract final class LsArt {
  static const dir = 'assets/games/slice';
  static const cover = '$dir/cover.webp', board = '$dir/bg_board.webp';
  static String whole(String art) => '$dir/$art.webp';
  static String cut(String art) => '$dir/${art}_cut.webp';

  /// Pencil (Monster Smash's poses, until his ninja sheet is made).
  static String pencil(String pose) => 'assets/games/smash/pencil_$pose.webp';
  static const star = 'assets/games/monsters/star.webp';

  static const arts = [...LsGame.fruits, 'star', 'berry', 'banana'];

  /// The colour of each fruit's juice.
  static const juice = {
    'apple': Color(0xFFFFF1C9),
    'orange': Color(0xFFFFA43A),
    'watermelon': Color(0xFFF65262),
    'lemon': Color(0xFFFFE45C),
    'plum': Color(0xFFB46CE0),
    'kiwi': Color(0xFF8CC846),
    'peach': Color(0xFFFFB27A),
    'star': Color(0xFFFFD24D),
    'berry': Color(0xFF7DB8FF),
    'banana': Color(0xFFFFE07A),
  };

  static List<String> get all => [
    for (final a in arts) ...[whole(a), cut(a)],
    for (final p in ['stand', 'cheer', 'oops', 'point', 'throw']) pencil(p),
    board,
  ];
}

/// The board on the screen: 10 units across its width, y up from the
/// bottom.
class LsView {
  LsView(this.screen, {this.topInset = 0}) : scale = screen.width / LsGame.width;
  final Size screen;
  final double scale;

  /// Space reserved above the flight area for controls and the challenge.
  final double topInset;

  /// The board's height in its units.
  double get height => (screen.height - topInset) / scale;

  Offset at(double x, double y) => Offset(x * scale, screen.height - y * scale);

  /// The board point under a finger at [p].
  (double, double) board(Offset p) => (p.dx / scale, (screen.height - p.dy) / scale);
}
