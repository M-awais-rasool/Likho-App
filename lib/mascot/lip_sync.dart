import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'mascot_pose.dart';

/// Loudness envelope of an audio asset, 100 values per second, 0..1.
///
/// just_audio exposes no live amplitude, so loudness is computed ahead of time
/// from the asset itself. Only uncompressed PCM WAV (16-bit) can be read here;
/// for other formats [load] returns null and the mouth falls back to random
/// shapes while the audio plays (as the brief specifies).
class LipSyncEnvelope {
  LipSyncEnvelope._(this.values);

  static const int rate = 100; // frames per second
  final Float32List values;

  static final Map<String, Future<LipSyncEnvelope?>> _cache = {};

  static Future<LipSyncEnvelope?> load(String asset, [AssetBundle? bundle]) {
    return _cache[asset] ??= _load(asset, bundle ?? rootBundle);
  }

  static Future<LipSyncEnvelope?> _load(String asset, AssetBundle bundle) async {
    if (!asset.toLowerCase().endsWith('.wav')) return null;
    try {
      final data = await bundle.load(asset);
      return fromWav(data);
    } catch (_) {
      return null;
    }
  }

  /// Parses a RIFF/WAVE PCM16 file and returns its normalised RMS envelope.
  static LipSyncEnvelope? fromWav(ByteData d) {
    String tag(int o) => String.fromCharCodes([d.getUint8(o), d.getUint8(o + 1), d.getUint8(o + 2), d.getUint8(o + 3)]);
    if (d.lengthInBytes < 44 || tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
    var o = 12;
    int? channels, sampleRate, bits, format;
    int dataStart = -1, dataLen = 0;
    while (o + 8 <= d.lengthInBytes) {
      final id = tag(o);
      final len = d.getUint32(o + 4, Endian.little);
      if (id == 'fmt ') {
        format = d.getUint16(o + 8, Endian.little);
        channels = d.getUint16(o + 10, Endian.little);
        sampleRate = d.getUint32(o + 12, Endian.little);
        bits = d.getUint16(o + 22, Endian.little);
      } else if (id == 'data') {
        dataStart = o + 8;
        dataLen = math.min(len, d.lengthInBytes - dataStart);
        break;
      }
      o += 8 + len + (len.isOdd ? 1 : 0);
    }
    if (format != 1 || bits != 16 || channels == null || sampleRate == null || dataStart < 0) return null;
    final frameBytes = 2 * channels;
    final frames = dataLen ~/ frameBytes;
    final win = sampleRate ~/ rate;
    final n = frames ~/ win;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      for (var j = 0; j < win; j++) {
        final s = d.getInt16(dataStart + (i * win + j) * frameBytes, Endian.little) / 32768.0;
        sum += s * s;
      }
      out[i] = math.sqrt(sum / win);
    }
    // normalise by the 95th percentile so a few peaks don't flatten everything
    final sorted = Float32List.fromList(out)..sort();
    final ref = sorted.isEmpty ? 1.0 : math.max(sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)], 1e-4);
    for (var i = 0; i < n; i++) {
      out[i] = (out[i] / ref).clamp(0.0, 1.0);
    }
    return LipSyncEnvelope._(out);
  }

  double levelAt(Duration position) {
    if (values.isEmpty) return 0;
    final i = (position.inMicroseconds * rate / 1e6).floor();
    if (i < 0 || i >= values.length) return 0;
    return values[i];
  }
}

/// Picks mouth shapes for speech: louder = more open. Changes shape every
/// 80–120 ms so the mouth never flickers.
class MouthPicker {
  MouthPicker(this._rnd);
  final math.Random _rnd;
  MouthShape _shape = MouthShape.closed;
  double _next = 0;

  MouthShape get shape => _shape;

  /// [level] null = loudness unknown (random talking shapes).
  MouthShape update(double now, {required bool speaking, double? level}) {
    if (!speaking) {
      _shape = MouthShape.closed;
      _next = now;
      return _shape;
    }
    if (now < _next) return _shape;
    _next = now + 0.08 + _rnd.nextDouble() * 0.04;
    if (level == null) {
      const talk = [MouthShape.openSmall, MouthShape.openA, MouthShape.o, MouthShape.ee, MouthShape.openSmall, MouthShape.closed];
      var s = talk[_rnd.nextInt(talk.length)];
      if (s == _shape) s = talk[(talk.indexOf(s) + 1) % talk.length];
      _shape = s;
    } else if (level < 0.08) {
      _shape = MouthShape.closed;
    } else if (level < 0.3) {
      _shape = MouthShape.openSmall;
    } else if (level < 0.6) {
      _shape = _rnd.nextBool() ? MouthShape.ee : MouthShape.o;
    } else {
      _shape = MouthShape.openA;
    }
    return _shape;
  }
}
