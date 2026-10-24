import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../game/letter_slice/ls_engine.dart';

/// Letter Slice's pictures (`assets/games/slice/`: stand-ins drawn by
/// tools/games/make_slice_placeholders.py until the Gemini art is cut into
/// the same names) and where the board is on the screen.
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
  LsView(this.screen) : scale = screen.width / LsGame.width;
  final Size screen;
  final double scale;

  /// The board's height in its units.
  double get height => screen.height / scale;

  Offset at(double x, double y) => Offset(x * scale, screen.height - y * scale);

  /// The board point under a finger at [p].
  (double, double) board(Offset p) => (p.dx / scale, (screen.height - p.dy) / scale);
}

/// Pictures decoded once, for painting (a picture not ready yet is skipped
/// for that frame).
class LsSprites {
  static final Map<String, ui.Image> _images = {};
  static final Set<String> _loading = {};

  static ui.Image? of(String asset) => _images[asset];

  static void load([ImageConfiguration config = ImageConfiguration.empty]) {
    for (final a in LsArt.all) {
      if (_images.containsKey(a) || !_loading.add(a)) continue;
      final stream = AssetImage(a).resolve(config);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          _images[a] = info.image.clone();
          info.dispose();
          _loading.remove(a);
          stream.removeListener(listener);
        },
        onError: (_, _) {
          _loading.remove(a);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    }
  }
}
