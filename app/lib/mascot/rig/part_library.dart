import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'svg_part.dart';

/// Loads and caches the layered SVG parts in assets/mascot/.
class MascotParts {
  MascotParts._(this._parts);

  final Map<String, List<PartShape>> _parts;

  List<PartShape> operator [](String name) => _parts[name] ?? const [];
  bool has(String name) => _parts.containsKey(name);

  static const Map<String, String> files = {
    'body': 'body.svg',
    'eraser': 'eraser.svg', // eraser + metal band
    'cone': 'cone.svg', // wooden cone + graphite
    'leg_left': 'leg_left.svg',
    'leg_right': 'leg_right.svg',
    'cheeks': 'cheek.svg',
    'brow_left': 'brow_left.svg',
    'brow_right': 'brow_right.svg',
    'mouth_closed': 'mouth_closed.svg',
    'mouth_open_small': 'mouth_open_small.svg',
    'mouth_open_a': 'mouth_open_a.svg',
    'mouth_o': 'mouth_o.svg',
    'mouth_ee': 'mouth_ee.svg',
    'mouth_laugh': 'mouth_laugh.svg',
    'mouth_gentle': 'mouth_gentle.svg',
    'mouth_yawn': 'mouth_yawn.svg',
    'hand_rest_left': 'hand_rest_left.svg',
    'hand_rest_right': 'hand_rest_right.svg',
    'hand_open': 'hand_open.svg',
    'hand_wave': 'hand_wave.svg',
    'hand_thumbs_up': 'hand_thumbs_up.svg',
    'hand_fist': 'hand_fist.svg',
    'acc_cap': 'accessories/cap.svg',
    'acc_wizard_hat': 'accessories/wizard_hat.svg',
    'acc_party_hat': 'accessories/party_hat.svg',
    'acc_round_glasses': 'accessories/round_glasses.svg',
    'acc_star_glasses': 'accessories/star_glasses.svg',
    'acc_cape': 'accessories/cape.svg',
    'acc_scarf': 'accessories/scarf.svg',
    'acc_crown': 'accessories/crown.svg',
    'acc_headphones': 'accessories/headphones.svg',
    'acc_bow': 'accessories/bow.svg',
    'fx_z1': 'fx/zzz_1.svg',
    'fx_z2': 'fx/zzz_2.svg',
    'fx_z3': 'fx/zzz_3.svg',
  };

  static MascotParts? _loaded;
  static Future<MascotParts>? _pending;

  /// Parts already parsed, if any (lets a second mascot draw on its first frame).
  static MascotParts? get cached => _loaded;

  /// Parses every part once per app run. Safe to call from many widgets.
  static Future<MascotParts> load([AssetBundle? bundle]) {
    final done = _loaded;
    if (done != null) return SynchronousFuture(done);
    return _pending ??= _load(bundle ?? rootBundle).then((p) {
      _loaded = p;
      _pending = null;
      return p;
    });
  }

  static Future<MascotParts> _load(AssetBundle bundle) async {
    final entries = await Future.wait(files.entries.map((e) async {
      final svg = await bundle.loadString('assets/mascot/${e.value}');
      return MapEntry(e.key, parsePartSvg(svg));
    }));
    return MascotParts._(Map.fromEntries(entries));
  }
}
