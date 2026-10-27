// Likho sound palette: every sound effect in the app, synthesised from
// scratch (no samples), so the set is original and consistent.
//
//   dart run tool/sound_design/generate_sfx.dart
//
// writes assets/sfx/*.wav (44.1 kHz, 16-bit, mono). See
// docs/sound_and_haptics.md for the design rules behind each sound.
//
// Identity: everything sits in D major pentatonic (D E F# A B), so any two
// sounds that overlap stay in harmony. Timbres: a glassy bell (rewards), a
// warm kalimba (progress), soft wood (UI and gentle mistakes), bubbly pops
// (choices), paper and pencil noise (Likho = "write"). The signature motif
// is D - A - D' ("Li-kh-o"), used by the splash, level complete and
// milestones.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sr = 44100;

// ------------------------------------------------------------------ notes
const _names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2};

/// 'F#6' -> Hz (A4 = 440).
double hz(String n) {
  var semis = _names[n[0]]!;
  var i = 1;
  if (n[i] == '#') {
    semis++;
    i++;
  }
  final octave = int.parse(n.substring(i));
  return 440.0 * math.pow(2, (semis + (octave - 4) * 12) / 12);
}

/// D major pentatonic from D4 upwards; index 5 = D5.
final List<double> scale = [
  for (var o = 4; o <= 7; o++)
    for (final n in ['D', 'E', 'F#', 'A', 'B']) hz('$n$o'),
];
double deg(int i) => scale[i];

// ------------------------------------------------------------------ buffer
class Snd {
  Snd(double seconds) : s = Float64List((seconds * sr).ceil() + 1);
  Float64List s;

  double get seconds => s.length / sr;

  /// Adds [o] at [at] seconds, scaled by [gain]; grows as needed.
  Snd mix(Snd o, {double at = 0, double gain = 1}) {
    final off = (at * sr).round();
    if (off + o.s.length > s.length) {
      final n = Float64List(off + o.s.length);
      n.setAll(0, s);
      s = n;
    }
    for (var i = 0; i < o.s.length; i++) {
      s[off + i] += o.s[i] * gain;
    }
    return this;
  }

  Snd scale(double g) {
    for (var i = 0; i < s.length; i++) {
      s[i] *= g;
    }
    return this;
  }
}

final _rnd = math.Random(7);
double noise() => _rnd.nextDouble() * 2 - 1;

double _env(double t, double attack, double tau) => t < attack ? t / attack : math.exp(-(t - attack) / tau);

/// Additive partials: (ratio, amplitude, decay factor).
Snd partials(double f, double dur, List<(double, double, double)> ps, {double attack = .002, double detune = 0}) {
  final out = Snd(dur);
  final tauBase = dur / 4.5;
  for (final (ratio, amp, df) in ps) {
    final fr = f * ratio * (1 + detune);
    if (fr > sr / 2 - 500) continue;
    final w = 2 * math.pi * fr / sr;
    final tau = tauBase * df;
    for (var i = 0; i < out.s.length; i++) {
      final t = i / sr;
      out.s[i] += amp * math.sin(w * i) * _env(t, attack, tau);
    }
  }
  return out;
}

// ------------------------------------------------------------------ filters
class Biquad {
  double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0, x1 = 0, x2 = 0, y1 = 0, y2 = 0;

  void _set(double nb0, double nb1, double nb2, double a0, double na1, double na2) {
    b0 = nb0 / a0;
    b1 = nb1 / a0;
    b2 = nb2 / a0;
    a1 = na1 / a0;
    a2 = na2 / a0;
  }

  void lowpass(double f, [double q = .707]) {
    final w = 2 * math.pi * f / sr, c = math.cos(w), al = math.sin(w) / (2 * q);
    _set((1 - c) / 2, 1 - c, (1 - c) / 2, 1 + al, -2 * c, 1 - al);
  }

  void highpass(double f, [double q = .707]) {
    final w = 2 * math.pi * f / sr, c = math.cos(w), al = math.sin(w) / (2 * q);
    _set((1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + al, -2 * c, 1 - al);
  }

  void bandpass(double f, [double q = 1]) {
    final w = 2 * math.pi * f / sr, c = math.cos(w), al = math.sin(w) / (2 * q);
    _set(al, 0, -al, 1 + al, -2 * c, 1 - al);
  }

  void peak(double f, double gainDb, [double q = 1]) {
    final a = math.pow(10, gainDb / 40).toDouble();
    final w = 2 * math.pi * f / sr, c = math.cos(w), al = math.sin(w) / (2 * q);
    _set(1 + al * a, -2 * c, 1 - al * a, 1 + al / a, -2 * c, 1 - al / a);
  }

  double run(double x) {
    final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}

Snd filter(Snd x, void Function(Biquad b) setup) {
  final b = Biquad();
  setup(b);
  for (var i = 0; i < x.s.length; i++) {
    x.s[i] = b.run(x.s[i]);
  }
  return x;
}

/// House EQ: no rumble under 180 Hz (phone speakers cannot play it anyway),
/// a small dip at 4.5 kHz so bright sounds never get harsh.
Snd houseEq(Snd x) {
  filter(x, (b) => b.highpass(180));
  filter(x, (b) => b.peak(4500, -2.5, .9));
  return x;
}

/// Small room (Freeverb-like combs + allpasses), mixed at [wet].
Snd room(Snd x, {double wet = .18, double size = .72, double tail = .6}) {
  final out = Snd(x.seconds + tail)..mix(x);
  final dry = Float64List.fromList(out.s);
  final wetBuf = Float64List(out.s.length);
  for (final ms in [29.7, 37.1, 41.1, 43.7]) {
    final d = (ms / 1000 * sr).round();
    final buf = Float64List(d);
    var idx = 0;
    var lp = 0.0;
    for (var i = 0; i < out.s.length; i++) {
      final y = buf[idx];
      lp = y * .6 + lp * .4; // damping
      buf[idx] = dry[i] + lp * size;
      idx = (idx + 1) % d;
      wetBuf[i] += y * .25;
    }
  }
  for (final ms in [5.0, 1.7]) {
    final d = (ms / 1000 * sr).round();
    final buf = Float64List(d);
    var idx = 0;
    for (var i = 0; i < wetBuf.length; i++) {
      final bo = buf[idx];
      final inp = wetBuf[i];
      buf[idx] = inp + bo * .5;
      wetBuf[i] = bo - inp * .5;
      idx = (idx + 1) % d;
    }
  }
  for (var i = 0; i < out.s.length; i++) {
    out.s[i] = dry[i] + wetBuf[i] * wet;
  }
  return out;
}

// ------------------------------------------------------------------ instruments
/// Glassy bell / celesta: rewards and stars.
Snd bell(double f, {double dur = .7, double bright = 1, double amp = 1}) =>
    partials(f, dur, [(1, 1, 1), (2, .30 * bright, .55), (3, .10 * bright, .35), (4.16, .07 * bright, .22), (5.43, .035 * bright, .15)], attack: .0025)
      ..mix(strike(.004, 3200, .06 * bright))
      ..scale(amp);

/// Warm kalimba tine: progress steps.
Snd kalimba(double f, {double dur = .5, double amp = 1}) => partials(f, dur, [(1, 1, 1), (2, .12, .5), (5.9, .22, .12), (3.01, .05, .3)], attack: .0018)
  ..mix(strike(.003, 2400, .08))
  ..scale(amp);

/// Soft wood (marimba-like): UI taps and gentle "try again".
Snd wood(double f, {double dur = .32, double amp = 1, double bright = 1}) =>
    partials(f, dur, [(1, 1, 1), (4, .30 * bright, .16), (9.8, .08 * bright, .06)], attack: .0015)..scale(amp);

/// A short filtered noise hit (mallet / pencil contact).
Snd strike(double dur, double center, double amp, {double q = 1.2}) {
  final x = Snd(dur + .01);
  for (var i = 0; i < x.s.length; i++) {
    final t = i / sr;
    x.s[i] = noise() * _env(t, .0004, dur / 3) * amp;
  }
  return filter(x, (b) => b.bandpass(center, q));
}

/// Pitch-gliding sine "pop" (bubbles, choices).
Snd pop(double f0, double f1, {double dur = .07, double amp = 1, double body = .2}) {
  final x = Snd(dur);
  var ph = 0.0;
  for (var i = 0; i < x.s.length; i++) {
    final t = i / sr;
    final f = f0 * math.pow(f1 / f0, math.min(1, t / (dur * .6)));
    ph += 2 * math.pi * f / sr;
    x.s[i] = (math.sin(ph) + body * math.sin(2 * ph)) * _env(t, .0006, dur / 3.2) * amp;
  }
  return x..mix(strike(.003, 2600, .12 * amp));
}

/// Soft sine blip with a gentle attack.
Snd blip(double f, {double dur = .09, double amp = 1}) {
  final x = Snd(dur);
  for (var i = 0; i < x.s.length; i++) {
    final t = i / sr;
    final e = t < .008 ? t / .008 : math.exp(-(t - .008) / (dur / 3));
    x.s[i] = (math.sin(2 * math.pi * f * t) + .15 * math.sin(4 * math.pi * f * t)) * e * amp;
  }
  return x;
}

/// Band-passed noise whose centre sweeps [f0] -> [f1], swelling in the
/// middle: swishes, whooshes, page turns.
Snd whoosh(double dur, double f0, double f1, {double amp = 1, double q = 1.4, double peakAt = .6}) {
  final x = Snd(dur);
  final b = Biquad();
  for (var i = 0; i < x.s.length; i++) {
    final p = i / x.s.length;
    if (i % 32 == 0) b.bandpass(f0 * math.pow(f1 / f0, p), q);
    final e = p < peakAt ? math.sin(math.pi / 2 * p / peakAt) : math.cos(math.pi / 2 * (p - peakAt) / (1 - peakAt));
    x.s[i] = b.run(noise()) * e * e * amp;
  }
  return x;
}

/// Pencil on paper: grains of bright noise with a papery band.
Snd scribble(double dur, int seed, {double amp = 1, bool loopable = false}) {
  final r = math.Random(seed);
  final x = Snd(dur);
  var t = 0.0;
  while (t < dur) {
    final g = .018 + r.nextDouble() * .03;
    final a = .45 + r.nextDouble() * .55;
    final grain = Snd(g);
    for (var i = 0; i < grain.s.length; i++) {
      final p = i / grain.s.length;
      grain.s[i] = noise() * math.sin(math.pi * p) * a;
    }
    x.mix(grain, at: t);
    t += g * (.55 + r.nextDouble() * .35);
  }
  x.s = Float64List.fromList(x.s.sublist(0, (dur * sr).ceil()));
  filter(x, (b) => b.highpass(1400));
  filter(x, (b) => b.bandpass(3600, .7));
  if (!loopable) {
    final n = x.s.length;
    for (var i = 0; i < n; i++) {
      final p = i / n;
      x.s[i] *= math.min(1, p / .08) * math.min(1, (1 - p) / .2);
    }
  } else {
    // crossfade the last 60 ms into the start so the loop point is seamless
    final f = (.06 * sr).round(), n = x.s.length;
    for (var i = 0; i < f; i++) {
      final k = i / f;
      x.s[i] = x.s[i] * k + x.s[n - f + i] * (1 - k);
    }
    x.s = Float64List.fromList(x.s.sublist(0, n - f));
  }
  return x.scale(amp);
}

/// Handful of tiny high bells: the sparkle that says "reward".
Snd sparkle(double dur, {int count = 7, int seed = 3, double amp = .35, int lowDeg = 12, int highDeg = 19}) {
  final r = math.Random(seed);
  final x = Snd(dur);
  for (var k = 0; k < count; k++) {
    final at = math.pow(r.nextDouble(), 1.4) * dur * .75;
    final f = deg(lowDeg + r.nextInt(highDeg - lowDeg + 1));
    x.mix(
      bell(f, dur: .16 + r.nextDouble() * .12, bright: .6, amp: .5 + r.nextDouble() * .5),
      at: at.toDouble(),
    );
  }
  // faint air on top
  final air = whoosh(dur * .8, 7000, 9500, amp: .08, q: 2);
  x.mix(air, at: 0);
  return x.scale(amp);
}

/// Low, soft landing thump (felt more than heard).
Snd thump({double f0 = 210, double f1 = 120, double dur = .12, double amp = 1}) {
  final x = Snd(dur);
  var ph = 0.0;
  for (var i = 0; i < x.s.length; i++) {
    final t = i / sr;
    final f = f0 * math.pow(f1 / f0, t / dur);
    ph += 2 * math.pi * f / sr;
    x.s[i] = (math.sin(ph) + .3 * math.sin(2 * ph)) * _env(t, .001, dur / 3.5) * amp;
  }
  return x;
}

/// Cartoon spring: a wobbling sine that rises and settles.
Snd boing({double f0 = 260, double f1 = 420, double dur = .4, double amp = 1}) {
  final x = Snd(dur);
  var ph = 0.0;
  for (var i = 0; i < x.s.length; i++) {
    final t = i / sr;
    final base = f0 + (f1 - f0) * (1 - math.exp(-t / .05));
    final vib = 1 + .06 * math.exp(-t / .12) * math.sin(2 * math.pi * 22 * t);
    ph += 2 * math.pi * base * vib / sr;
    x.s[i] = (math.sin(ph) + .25 * math.sin(2 * ph)) * _env(t, .004, dur / 3) * amp;
  }
  return x;
}

/// Liquid "bloop" (paint).
Snd bloop({double f0 = 280, double f1 = 900, double dur = .12, double amp = 1}) {
  final x = Snd(dur);
  var ph = 0.0;
  for (var i = 0; i < x.s.length; i++) {
    final t = i / sr;
    final f = f0 * math.pow(f1 / f0, math.min(1, t / (dur * .7)));
    ph += 2 * math.pi * f * (1 + .04 * math.sin(2 * math.pi * 40 * t)) / sr;
    x.s[i] = math.sin(ph) * _env(t, .004, dur / 3) * amp;
  }
  return x;
}

/// Sustained soft chord pad (warm sines, slow attack).
Snd pad(List<double> fs, {double dur = 1.2, double amp = .25}) {
  final x = Snd(dur);
  for (final f in fs) {
    for (var i = 0; i < x.s.length; i++) {
      final t = i / sr;
      final e = (t < .05 ? t / .05 : 1) * math.exp(-t / (dur / 3));
      x.s[i] += (math.sin(2 * math.pi * f * t) + .2 * math.sin(4 * math.pi * f * t)) * e * amp / fs.length;
    }
  }
  return x;
}

// ------------------------------------------------------------------ mastering
/// Scales to a target loudness (RMS of the audible part, a practical
/// stand-in for LUFS on short sounds), then soft-limits peaks to -1 dBFS,
/// trims silence and adds a 4 ms fade out.
Snd master(Snd x, double targetDb) {
  var peak = 0.0;
  for (final v in x.s) {
    peak = math.max(peak, v.abs());
  }
  if (peak == 0) return x;
  final gate = peak * .03;
  var sum = 0.0;
  var n = 0;
  for (final v in x.s) {
    if (v.abs() > gate) {
      sum += v * v;
      n++;
    }
  }
  final rms = math.sqrt(sum / math.max(1, n));
  final g = math.pow(10, targetDb / 20) / rms;
  const ceiling = .891; // -1 dBFS
  for (var i = 0; i < x.s.length; i++) {
    final v = x.s[i] * g;
    x.s[i] = v.abs() < .6 ? v : v.sign * (.6 + (ceiling - .6) * _tanh((v.abs() - .6) / (ceiling - .6)));
  }
  var end = x.s.length;
  while (end > 1 && x.s[end - 1].abs() < .001) {
    end--;
  }
  final fade = math.min((.004 * sr).round(), end);
  for (var i = 0; i < fade; i++) {
    x.s[end - 1 - i] *= i / fade;
  }
  x.s = Float64List.fromList(x.s.sublist(0, end));
  return x;
}

double _tanh(double v) {
  final e = math.exp(2 * v);
  return (e - 1) / (e + 1);
}

void writeWav(String path, Snd x, {int rate = sr}) {
  final n = x.s.length;
  final b = BytesBuilder();
  void u32(int v) => b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
  b.add('RIFF'.codeUnits);
  u32(36 + n * 2);
  b.add('WAVEfmt '.codeUnits);
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  b.add('data'.codeUnits);
  u32(n * 2);
  final pcm = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    pcm.setInt16(i * 2, (x.s[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  b.add(pcm.buffer.asUint8List());
  File(path).writeAsBytesSync(b.toBytes());
}

// ------------------------------------------------------------------ music
/// A plucked bass note (warm partials; phone speakers hear its overtones).
Snd pluck(double f, {double dur = .4, double amp = 1}) => partials(f, dur, [(1, 1, 1), (2, .55, .6), (3, .3, .4), (4, .16, .3), (5, .08, .2)], attack: .004)..scale(amp);

/// A game music loop: 4 bars at [bpm] in D major pentatonic (kick, shaker,
/// plucked bass, kalimba tune). [tense] adds a running bass, a snare on 2
/// and 4 and a pulsing pad, for when the monsters get close. The reverb's
/// tail is folded onto the start, so the loop joins without a seam.
Snd gameMusic({required double bpm, required bool tense, int seed = 500, List<List<int?>>? tune, List<double>? roots}) {
  final r = math.Random(seed);
  final eighth = 60 / bpm / 2;
  const bars = 4;
  final n = (bars * 8 * eighth * sr).round();
  final x = Snd(bars * 8 * eighth + 1.6);
  roots ??= [hz('D3'), hz('B2'), hz('E3'), hz('A2')];
  // the tune, an eighth at a time (scale degrees, null = rest)
  tune ??= const [
    [8, null, 7, 8, 10, null, 8, null],
    [7, null, 5, 7, 8, null, null, null],
    [8, null, 9, 10, 9, null, 8, null],
    [7, null, 8, 7, 5, null, null, null],
  ];
  for (var bar = 0; bar < bars; bar++) {
    for (var e = 0; e < 8; e++) {
      final at = (bar * 8 + e) * eighth;
      // kick on 1 and 3
      if (e == 0 || e == 4) x.mix(thump(f0: 170, f1: 70, dur: .16, amp: .9), at: at);
      // snare on 2 and 4 when tense
      if (tense && (e == 2 || e == 6)) x.mix(strike(.06, 1900, .5, q: .7), at: at);
      // shaker, offbeats a little louder
      x.mix(strike(.025, 7500, e.isOdd ? .18 : .1, q: 1.4), at: at + r.nextDouble() * .006);
      // bass
      final root = roots[bar];
      if (tense) {
        x.mix(pluck(e % 4 == 3 ? root * 1.5 : root, dur: eighth * .95, amp: .55), at: at);
      } else if (e == 0 || e == 3 || e == 4 || e == 7) {
        x.mix(pluck(e == 7 ? root * 1.5 : root, dur: eighth * 2.2, amp: .6), at: at);
      }
      // the tune (an octave up, brighter, when tense)
      final d = tune[bar][e];
      if (d != null) {
        final f = deg(d) * (tense && bar.isOdd ? 2 : 1);
        x.mix(kalimba(f, dur: eighth * 2.4, amp: .42), at: at);
        if (tense) x.mix(blip(f * 2, dur: .08, amp: .12), at: at);
      }
    }
    if (tense) {
      // a pad that pulses on every beat
      for (var b = 0; b < 4; b++) {
        x.mix(pad([roots[bar] * 2, roots[bar] * 3, roots[bar] * 4], dur: eighth * 2, amp: .16), at: (bar * 8 + b * 2) * eighth);
      }
    }
  }
  final wet = room(houseEq(x), wet: .14, tail: .3);
  // fold everything after the loop's end onto its start
  for (var i = n; i < wet.s.length; i++) {
    wet.s[i - n] += wet.s[i];
  }
  wet.s = Float64List.fromList(wet.s.sublist(0, n));
  return wet;
}

/// [master] for a loop: the loudness and the soft limit, without trimming
/// or fading its end (that would break the loop).
Snd masterLoop(Snd x, double targetDb) {
  var sum = 0.0;
  for (final v in x.s) {
    sum += v * v;
  }
  final g = math.pow(10, targetDb / 20) / math.sqrt(sum / x.s.length);
  const ceiling = .891;
  for (var i = 0; i < x.s.length; i++) {
    final v = x.s[i] * g;
    x.s[i] = v.abs() < .6 ? v : v.sign * (.6 + (ceiling - .6) * _tanh((v.abs() - .6) / (ceiling - .6)));
  }
  return x;
}

/// Half the sample rate (music needs no more), filtered first.
Snd halfRate(Snd x) {
  filter(x, (b) => b.lowpass(9000, .6));
  return Snd(0)..s = Float64List.fromList([for (var i = 0; i < x.s.length; i += 2) x.s[i]]);
}

// ------------------------------------------------------------------ the palette
/// Loudness targets (dB RMS): quiet UI, clear feedback, big celebrations.
const ui = -27.0, soft = -24.0, feedback = -19.0, celebrate = -17.0;

Map<String, Snd Function()> palette() {
  final d5 = hz('D5'), a5 = hz('A5'), d6 = hz('D6'), fs6 = hz('F#6'), a6 = hz('A6'), b6 = hz('B6'), e7 = hz('E7'), d7 = hz('D7');
  return {
    // ---------------------------------------------------------- UI (quiet, frequent)
    for (final (i, n) in ['A5', 'B5', 'F#5'].indexed)
      'tap_${i + 1}': () => master(houseEq(wood(hz(n), dur: .09, bright: .7)..mix(strike(.003, 3000, .05))), ui),
    for (final (i, f) in [(620.0, 1050.0), (680.0, 1150.0), (560.0, 980.0)].indexed)
      'select_${i + 1}': () => master(houseEq(pop(f.$1, f.$2, dur: .06)), ui + 1),
    'back': () => master(houseEq(pop(1000, 600, dur: .06)), ui),
    'toggle_on': () => master(houseEq(wood(hz('E6'), dur: .06, bright: .6)..mix(wood(a6, dur: .07, bright: .6), at: .035)), ui),
    'toggle_off': () => master(houseEq(wood(a6, dur: .06, bright: .6)..mix(wood(hz('E6'), dur: .07, bright: .6), at: .035)), ui - 1),
    'page_flip': () => master(houseEq(whoosh(.3, 1400, 5200, q: .9, peakAt: .45)..mix(scribble(.12, 11, amp: .5), at: .06)), ui + 1),
    'round_next': () => master(houseEq(whoosh(.24, 1800, 4800, q: 1.1, peakAt: .5)), ui - 1),
    'whoosh': () => master(houseEq(whoosh(.36, 700, 4200, q: 1.2)), soft),

    // ---------------------------------------------------------- answers
    // correct: pencil tick + a quick rising arpeggio that lands on a ringing
    // bell. Each streak step moves the whole figure one note up the scale.
    for (var k = 0; k < 5; k++)
      'correct_${k + 1}': () {
        final r = 5 + k; // D5, E5, F#5, A5, B5
        final x = Snd(.9)
          ..mix(strike(.004, 3400, .25))
          ..mix(kalimba(deg(r), dur: .16, amp: .85))
          ..mix(kalimba(deg(r + 2), dur: .18, amp: .75), at: .055)
          ..mix(bell(deg(r + 5), dur: .75, amp: 1), at: .11)
          ..mix(kalimba(deg(r + 5), dur: .5, amp: .45), at: .11);
        if (k >= 2) x.mix(sparkle(.5, count: 3 + k, seed: 20 + k, amp: .22 + .04 * k), at: .16);
        return master(houseEq(room(x, wet: .14)), feedback + k * .6);
      },
    // wrong: two soft wooden notes stepping down, rounded off. Friendly
    // "not yet", never a buzzer; quieter than success.
    'wrong': () {
      final x = Snd(.5)
        ..mix(wood(hz('B4'), dur: .22, bright: .55))
        ..mix(wood(hz('A4') * .985, dur: .32, bright: .45), at: .12);
      filter(x, (b) => b.lowpass(2600));
      return master(houseEq(room(x, wet: .1)), feedback - 3.5);
    },
    'nope': () {
      final x = Snd(.3)
        ..mix(wood(hz('A4'), dur: .2, bright: .4))
        ..mix(pop(520, 380, dur: .08, amp: .35), at: .01);
      filter(x, (b) => b.lowpass(2200));
      return master(houseEq(x), soft - 1);
    },
    // one step of progress (order tiles, spelled letters): kalimba up the scale
    for (var k = 0; k < 6; k++)
      'step_${k + 1}': () => master(
        houseEq(
          room(
            Snd(.4)
              ..mix(kalimba(deg(5 + k), dur: .35))
              ..mix(pop(700 + 60.0 * k, 1100 + 80.0 * k, dur: .04, amp: .3)),
            wet: .1,
          ),
        ),
        feedback - 2,
      ),
    'balloon_pop': () {
      final x = Snd(.25)
        ..mix(strike(.012, 1800, 1.0, q: .7))
        ..mix(pop(900, 300, dur: .08, amp: .6))
        ..mix(sparkle(.2, count: 2, seed: 5, amp: .15), at: .03);
      return master(houseEq(x), feedback - 1);
    },
    'listen': () => master(
      houseEq(
        Snd(.25)
          ..mix(blip(a5, dur: .08))
          ..mix(blip(d6, dur: .12), at: .09),
      ),
      soft,
    ),

    // ---------------------------------------------------------- journeys
    'level_start': () {
      final x = Snd(1)
        ..mix(whoosh(.42, 600, 5200, amp: .8, q: 1.3))
        ..mix(bell(d6, dur: .7), at: .3)
        ..mix(bell(a6, dur: .6, amp: .5), at: .36)
        ..mix(sparkle(.45, count: 4, seed: 9, amp: .2), at: .34);
      return master(houseEq(room(x)), celebrate - 1.5);
    },
    'intro_reveal': () {
      final x = Snd(.9)
        ..mix(pop(380, 920, dur: .1, amp: .8))
        ..mix(sparkle(.6, count: 6, seed: 13, amp: .3), at: .04)
        ..mix(bell(a6, dur: .6, amp: .55), at: .06);
      return master(houseEq(room(x)), celebrate - 2);
    },
    // Level complete, beat by beat: "ta-da", then one bell per star as it
    // lands (higher each time), a coin for the "+N", confetti poppers, and a
    // rising run for a perfect score.
    'complete_tada': () {
      final x = Snd(1.4)
        ..mix(kalimba(a5, dur: .18, amp: .8))
        ..mix(bell(d6, dur: 1.1), at: .13)
        ..mix(bell(fs6, dur: 1.0, amp: .6), at: .13)
        ..mix(bell(a6, dur: .9, amp: .45), at: .13)
        ..mix(pad([d5, a5, fs6], dur: 1.2, amp: .5), at: .13);
      return master(houseEq(room(x, wet: .2)), celebrate);
    },
    for (final (k, n) in [(1, 'A5'), (2, 'D6'), (3, 'F#6')])
      'star_$k': () {
        final x = Snd(1)
          ..mix(thump(f0: 260, f1: 150, dur: .08, amp: .6))
          ..mix(bell(hz(n), dur: .85))
          ..mix(bell(hz(n) * 2, dur: .4, amp: .18))
          ..mix(sparkle(.45, count: 2 + k, seed: 30 + k, amp: .18), at: .05);
        return master(houseEq(room(x)), feedback + k * .8);
      },
    'coin': () {
      final x = Snd(.7)
        ..mix(bell(b6, dur: .3, amp: .8))
        ..mix(bell(e7, dur: .55), at: .07)
        ..mix(sparkle(.4, count: 3, seed: 41, amp: .2), at: .1);
      return master(houseEq(room(x, wet: .12)), feedback);
    },
    'confetti': () {
      final x = Snd(.8);
      for (final (i, at) in [0.0, .07, .16].indexed) {
        x.mix(strike(.01, 1600 + 400.0 * i, .9, q: .8), at: at);
        x.mix(pop(1100 - 100.0 * i, 420, dur: .05, amp: .35), at: at + .004);
      }
      x.mix(sparkle(.55, count: 6, seed: 51, amp: .28), at: .12);
      return master(houseEq(room(x, wet: .1)), feedback - 1);
    },
    'perfect': () {
      final x = Snd(1.2);
      for (var k = 0; k < 8; k++) {
        x.mix(bell(deg(10 + k), dur: .35, amp: .45 + k * .05, bright: .8), at: k * .045);
      }
      x.mix(sparkle(.8, count: 8, seed: 61, amp: .3), at: .3);
      x.mix(pad([d6, fs6, a6], dur: .9, amp: .35), at: .3);
      return master(houseEq(room(x, wet: .22)), celebrate);
    },
    // big moments: the signature motif D - A - D', carried higher
    'milestone': () {
      final x = Snd(2.6);
      final notes = [d5, a5, d6, fs6, a6, d7];
      for (final (i, f) in notes.indexed) {
        x.mix(
          bell(f, dur: i == notes.length - 1 ? 1.4 : .5, amp: .7 + .05 * i),
          at: i < 3 ? i * .11 : .33 + (i - 3) * .08,
        );
        x.mix(kalimba(f / 2, dur: .3, amp: .25), at: i < 3 ? i * .11 : .33 + (i - 3) * .08);
      }
      x.mix(pad([d5, fs6, a6, d7], dur: 1.8, amp: .45), at: .6);
      x.mix(sparkle(1.4, count: 12, seed: 71, amp: .3), at: .55);
      return master(houseEq(room(x, wet: .24, tail: .8)), celebrate);
    },
    'boss_wake': () {
      final x = Snd(1.2)
        ..mix(boing(f0: 200, f1: 420, dur: .45))
        ..mix(bell(d6, dur: .8, amp: .7), at: .28)
        ..mix(bell(fs6, dur: .8, amp: .55), at: .28)
        ..mix(bell(a6, dur: .8, amp: .45), at: .28)
        ..mix(sparkle(.6, count: 6, seed: 81, amp: .25), at: .3);
      return master(houseEq(room(x)), celebrate - 1);
    },
    'lullaby': () {
      // music box, falling gently: "time to rest"
      final x = Snd(2.6);
      for (final (i, n) in ['D6', 'B5', 'A5', 'F#5', 'E5', 'D5'].indexed) {
        x.mix(bell(hz(n), dur: .9, bright: 1.3, amp: .75), at: i * .28);
      }
      return master(houseEq(room(x, wet: .3, tail: .9)), feedback - 2);
    },

    // ---------------------------------------------------------- rewards & room
    'reward': () {
      final x = Snd(1)
        ..mix(bell(b6, dur: .3, amp: .8))
        ..mix(bell(e7, dur: .6), at: .07)
        ..mix(pad([d6, fs6, a6], dur: .8, amp: .3), at: .1)
        ..mix(sparkle(.6, count: 6, seed: 91, amp: .28), at: .12);
      return master(houseEq(room(x)), celebrate - 1);
    },
    'wear': () => master(
      houseEq(
        Snd(.35)
          ..mix(whoosh(.16, 2200, 6500, amp: .6, peakAt: .4))
          ..mix(pop(600, 1250, dur: .07, amp: .8), at: .1),
      ),
      soft + 1,
    ),
    'sticker': () {
      final x = Snd(.8)
        ..mix(strike(.02, 900, 1.0, q: .6))
        ..mix(thump(f0: 240, f1: 140, dur: .07, amp: .7))
        ..mix(sparkle(.5, count: 5, seed: 101, amp: .3), at: .05);
      return master(houseEq(room(x, wet: .1)), feedback);
    },
    'unlock': () {
      final x = Snd(.8)
        ..mix(wood(hz('E6'), dur: .05, bright: .8))
        ..mix(wood(a6, dur: .05, bright: .8), at: .045)
        ..mix(whoosh(.3, 1500, 7000, amp: .35), at: .05)
        ..mix(bell(a6, dur: .5, amp: .6), at: .16);
      return master(houseEq(room(x)), feedback);
    },
    'success_soft': () => master(
      houseEq(
        room(
          Snd(.9)
            ..mix(bell(a5, dur: .45, amp: .7))
            ..mix(bell(d6, dur: .7), at: .1),
        ),
      ),
      feedback - 1,
    ),
    'send': () => master(
      houseEq(
        room(
          Snd(.8)
            ..mix(whoosh(.5, 700, 6000, amp: .9))
            ..mix(bell(a6, dur: .4, amp: .4), at: .35),
        ),
      ),
      soft + 1,
    ),

    // ---------------------------------------------------------- playful picks
    'paint': () => master(
      houseEq(
        Snd(.3)
          ..mix(bloop())
          ..mix(bloop(f0: 420, f1: 1300, dur: .09, amp: .6), at: .08),
      ),
      soft + 2,
    ),
    'candle': () => master(
      houseEq(
        room(
          Snd(.6)
            ..mix(bell(fs6, dur: .45))
            ..mix(sparkle(.3, count: 2, seed: 111, amp: .15), at: .03),
        ),
      ),
      soft + 2,
    ),
    'catch': () => master(
      houseEq(
        room(
          Snd(.6)
            ..mix(pop(500, 1200, dur: .07))
            ..mix(bell(d6, dur: .45, amp: .7), at: .04),
        ),
      ),
      soft + 2,
    ),

    // ---------------------------------------------------------- splash (2.5 s intro)
    'splash_land': () => master(
      houseEq(
        Snd(.5)
          ..mix(thump(amp: .9))
          ..mix(boing(f0: 300, f1: 360, dur: .3, amp: .35), at: .02),
      ),
      feedback - 1,
    ),
    for (var k = 1; k <= 3; k++) 'scribble_$k': () => master(houseEq(scribble(.16 + .03 * k, 200 + k)), ui + 1),
    'splash_swish': () => master(houseEq(whoosh(.5, 900, 6500, q: 1.1, peakAt: .7)..mix(scribble(.4, 207, amp: .35), at: .05)), soft),
    'splash_chime': () {
      final x = Snd(1.6);
      for (final (i, f) in [d5, a5, d6].indexed) {
        x.mix(kalimba(f, dur: .45, amp: .6), at: i * .11);
        x.mix(bell(f, dur: i == 2 ? 1.1 : .45, amp: .8), at: i * .11);
      }
      x.mix(bell(fs6, dur: .9, amp: .3), at: .22);
      x.mix(sparkle(.9, count: 7, seed: 121, amp: .26), at: .25);
      return master(houseEq(room(x, wet: .22)), celebrate - 1);
    },

    // ---------------------------------------------------------- writing pad loop
    'scribble_loop': () => master(houseEq(scribble(1.26, 301, loopable: true)), ui - 3),

    // ---------------------------------------------------------- boss battle
    // (last, so the shared noise source gives every older sound the same take)
    // the BOSS stamp: a big soft thud and a ring, "here it comes"
    'boss_stamp': () {
      final x = Snd(1.3)
        ..mix(thump(f0: 150, f1: 55, dur: .35, amp: 1))
        ..mix(strike(.05, 700, .8, q: .7))
        ..mix(bell(d5, dur: 1.0, amp: .5, bright: .6), at: .02)
        ..mix(bell(a5, dur: .9, amp: .35, bright: .6), at: .02);
      return master(houseEq(room(x, wet: .3, tail: .9)), celebrate);
    },
    // drum roll speeding up into the countdown's "go"
    'boss_drum': () {
      final x = Snd(1.6);
      var t = 0.0, gap = .11;
      var k = 0;
      while (t < 1.15) {
        x.mix(thump(f0: 190 + (k.isEven ? 0 : 20), f1: 110, dur: .07, amp: .45 + t * .4), at: t);
        x.mix(strike(.012, 2400, .25 + t * .2, q: .9), at: t);
        t += gap;
        gap = math.max(.035, gap * .9);
        k++;
      }
      x.mix(thump(f0: 160, f1: 60, dur: .3, amp: 1), at: 1.2);
      x.mix(strike(.08, 1400, .9, q: .6), at: 1.2);
      x.mix(bell(d6, dur: .5, amp: .6), at: 1.2);
      return master(houseEq(room(x, wet: .2)), celebrate);
    },
    // a wake-up hit lands on the boss: a cartoon "bonk" and a twinkle
    'boss_hit': () {
      final x = Snd(.8)
        ..mix(wood(hz('A4'), dur: .12, amp: .9, bright: 1.2))
        ..mix(boing(f0: 300, f1: 160, dur: .32, amp: .7), at: .01)
        ..mix(pop(900, 400, dur: .06, amp: .6))
        ..mix(sparkle(.35, count: 4, seed: 111, amp: .25), at: .08);
      return master(houseEq(room(x, wet: .12)), feedback);
    },
    // a combo hit: bigger, with a bright rising chord
    'boss_super': () {
      final x = Snd(1.2)
        ..mix(thump(f0: 180, f1: 70, dur: .2, amp: .9))
        ..mix(boing(f0: 260, f1: 520, dur: .4, amp: .6), at: .02);
      for (final (i, f) in [d6, fs6, a6, d7].indexed) {
        x.mix(bell(f, dur: .45, amp: .55, bright: .9), at: .06 + i * .05);
      }
      x.mix(sparkle(.7, count: 8, seed: 121, amp: .3), at: .1);
      return master(houseEq(room(x, wet: .18)), celebrate);
    },
    // the combo counter ticks up
    'boss_combo': () {
      final x = Snd(.5);
      for (final (i, f) in [a5, d6, fs6].indexed) {
        x.mix(blip(f, dur: .07, amp: .7), at: i * .055);
      }
      return master(houseEq(room(x, wet: .1)), feedback - 1);
    },
    // the next phase: a swoosh up into two bells
    'boss_phase': () {
      final x = Snd(1.3)
        ..mix(whoosh(.5, 500, 6000, amp: .7, q: 1.2))
        ..mix(bell(a5, dur: .6, amp: .6), at: .42)
        ..mix(bell(d6, dur: .9, amp: .7), at: .54)
        ..mix(pad([d5, a5, d6], dur: .9, amp: .3), at: .5);
      return master(houseEq(room(x, wet: .24)), celebrate - 1);
    },
    // a sleepy snore when an answer misses: breathe in, rumble out
    'boss_snore': () {
      final x = Snd(1.2)
        ..mix(whoosh(.45, 300, 900, amp: .5, q: 2.5, peakAt: .7))
        ..mix(filter(Snd(.55)..mix(boing(f0: 95, f1: 80, dur: .55, amp: .8)), (b) => b.lowpass(500, .7)), at: .5);
      return master(houseEq(x), soft);
    },
    // the alarm clock rings (one tap of the finale)
    'alarm_ring': () {
      final x = Snd(.5);
      for (var k = 0; k < 6; k++) {
        x.mix(bell(k.isEven ? b6 : d7, dur: .12, amp: .7, bright: 1.4), at: k * .045);
      }
      x.mix(strike(.02, 3500, .4, q: 1.5));
      return master(houseEq(room(x, wet: .08)), feedback);
    },

    // ---------------------------------------------------------- Monster Defense
    // (after the boss battle, for the same reason)
    // a monster comes out of the cave
    'md_spawn': () {
      final x = Snd(.8)
        ..mix(whoosh(.5, 300, 1500, amp: .6, q: 1.2))
        ..mix(boing(f0: 180, f1: 300, dur: .35, amp: .35), at: .2);
      return master(houseEq(room(x, wet: .25)), soft);
    },
    // Pencil's magic flies: a sweep up and four quick notes
    'md_zap': () {
      final x = Snd(.8)..mix(whoosh(.32, 600, 7000, amp: .7, q: 1.6, peakAt: .7));
      for (final (i, f) in [a5, d6, fs6, a6].indexed) {
        x.mix(blip(f, dur: .08, amp: .5), at: .03 + i * .045);
      }
      x.mix(sparkle(.4, count: 5, seed: 401, amp: .25), at: .2);
      return master(houseEq(room(x, wet: .15)), feedback);
    },
    // the magic bubble closes round the monster
    'md_bubble': () {
      final x = Snd(.8)
        ..mix(bloop(f0: 200, f1: 700, dur: .25, amp: .9))
        ..mix(bloop(f0: 400, f1: 1100, dur: .18, amp: .5), at: .12)
        ..mix(bell(d6, dur: .5, amp: .3, bright: .5), at: .2);
      return master(houseEq(room(x, wet: .2)), feedback - 1);
    },
    // the bubble pops up high and the monster is a friend: pop + chime
    'md_pop': () {
      final x = Snd(1.0)
        ..mix(pop(1200, 300, dur: .08, amp: 1))
        ..mix(strike(.01, 4000, .4));
      for (final (i, f) in [d6, a6, d7].indexed) {
        x.mix(bell(f, dur: .5, amp: .5), at: .1 + i * .07);
      }
      x.mix(sparkle(.6, count: 6, seed: 402, amp: .22), at: .12);
      return master(houseEq(room(x, wet: .2)), feedback);
    },
    // a silly monster "rawr" (a wobbly growl through a mouth-like band)
    'md_roar': () {
      final x = Snd(.6);
      var ph = 0.0;
      for (var i = 0; i < x.s.length; i++) {
        final t = i / sr;
        final f = 150 + 60 * math.sin(math.pi * math.min(1, t / .5)) + 18 * math.sin(2 * math.pi * 28 * t);
        ph += 2 * math.pi * f / sr;
        var v = 0.0;
        for (var k = 1; k <= 8; k++) {
          v += math.sin(ph * k) / k;
        }
        final e = t < .04 ? t / .04 : math.max(0.0, 1 - (t - .04) / .5);
        x.s[i] = v * e * .5 + noise() * .08 * e;
      }
      filter(x, (b) => b.bandpass(750, .8));
      filter(x, (b) => b.peak(1600, 4, 1.2));
      return master(houseEq(room(x, wet: .1)), feedback - 1);
    },
    // the stone monster's bubble breaks: a crack and little stones
    'md_crack': () {
      final x = Snd(.6)
        ..mix(thump(f0: 220, f1: 90, dur: .15, amp: .9))
        ..mix(strike(.03, 1800, .9, q: .8))
        ..mix(strike(.02, 3200, .6, q: 1.5), at: .04);
      for (final (k, n) in ['A4', 'D5', 'E5', 'B4', 'F#5'].indexed) {
        x.mix(wood(hz(n), dur: .07, amp: .3, bright: 1.4), at: .08 + k * .05);
      }
      return master(houseEq(room(x, wet: .1)), feedback);
    },
    // a monster got to the gate: a heart is lost
    'md_gate': () {
      final x = Snd(1.0)
        ..mix(thump(f0: 180, f1: 70, dur: .25, amp: .8))
        ..mix(kalimba(hz('A5'), dur: .35, amp: .7), at: .05)
        ..mix(kalimba(hz('E5'), dur: .5, amp: .7), at: .25)
        ..mix(boing(f0: 300, f1: 180, dur: .4, amp: .4), at: .3);
      return master(houseEq(room(x, wet: .16)), feedback);
    },
    // a new wave: two drum hits and a rising call
    'md_wave': () {
      final x = Snd(1.4)
        ..mix(thump(f0: 160, f1: 70, dur: .25, amp: .8))
        ..mix(thump(f0: 160, f1: 70, dur: .25, amp: .8), at: .22);
      for (final (i, f) in [d5, a5, d6].indexed) {
        x.mix(kalimba(f, dur: .4, amp: .7), at: .1 + i * .12);
      }
      x
        ..mix(pad([d5, fs6 / 2, a5], dur: 1.0, amp: .35), at: .34)
        ..mix(bell(d6, dur: .9, amp: .5), at: .34);
      return master(houseEq(room(x, wet: .22)), celebrate - 1);
    },
    // Big Bonk arrives: three stomps and a low chord
    'md_boss': () {
      final x = Snd(1.8);
      for (var k = 0; k < 3; k++) {
        x
          ..mix(thump(f0: 130, f1: 50, dur: .35, amp: 1), at: k * .38)
          ..mix(strike(.05, 600, .7, q: .7), at: k * .38);
      }
      x
        ..mix(pad([hz('D4'), hz('A4'), d5], dur: 1.2, amp: .4), at: .9)
        ..mix(bell(a5, dur: .8, amp: .4, bright: .5), at: 1.0);
      return master(houseEq(room(x, wet: .3, tail: .9)), celebrate);
    },
    // a monster is close: a soft heartbeat
    'md_hurry': () => master(
      houseEq(Snd(.6)
        ..mix(thump(f0: 200, f1: 120, dur: .12, amp: 1))
        ..mix(thump(f0: 190, f1: 110, dur: .12, amp: .7), at: .2)),
      soft,
    ),
    // a power-up is earned
    'md_power': () {
      final x = Snd(.9);
      for (final (i, f) in [d6, fs6, a6, d7].indexed) {
        x.mix(kalimba(f, dur: .25, amp: .6), at: i * .06);
      }
      x.mix(sparkle(.6, count: 6, seed: 403, amp: .3), at: .15);
      return master(houseEq(room(x, wet: .18)), feedback);
    },
    // Freeze: an icy shimmer
    'md_freeze': () {
      final x = Snd(1.3)..mix(whoosh(.6, 9000, 2500, amp: .5, q: 2, peakAt: .3));
      for (var k = 0; k < 8; k++) {
        x.mix(bell(deg(12 + (k * 3) % 6), dur: .5, amp: .4, bright: 1.3), at: k * .04);
      }
      x.mix(pad([d6, a6, e7], dur: 1.0, amp: .2), at: .1);
      return master(houseEq(room(x, wet: .35, tail: .8)), feedback);
    },
    // Double magic: the potion bubbles and sparkles up
    'md_potion': () {
      final x = Snd(1.2);
      for (var k = 0; k < 4; k++) {
        x.mix(bloop(f0: 250 + k * 80.0, f1: 600 + k * 150.0, dur: .1, amp: .6), at: k * .09);
      }
      x.mix(whoosh(.5, 800, 6000, amp: .5), at: .3);
      for (final (i, f) in [a5, d6, fs6, a6, d7].indexed) {
        x.mix(bell(f, dur: .4, amp: .45), at: .4 + i * .05);
      }
      return master(houseEq(room(x, wet: .2)), feedback);
    },
    // the game is lost: a gentle "aww" going down
    'md_lose': () {
      final x = Snd(1.4);
      for (final (i, f) in [a5, fs6 / 2, hz('E5'), d5].indexed) {
        x.mix(kalimba(f, dur: .5, amp: .6), at: i * .16);
      }
      x.mix(pad([d5, a5], dur: 1.0, amp: .25), at: .5);
      return master(houseEq(room(x, wet: .22)), soft + 1);
    },
  };
}

/// The game music loops (half rate, see [halfRate]).
Map<String, Snd Function()> music() => {
  'md_music': () => halfRate(masterLoop(gameMusic(bpm: 112, tense: false), soft - 2)),
  'md_music_tense': () => halfRate(masterLoop(gameMusic(bpm: 132, tense: true, seed: 501), soft - 1)),
};

/// Spell Runner's sounds, made after everything else (the shared noise
/// source then gives every older sound the same take). Loops and music are
/// at half rate.
Map<String, (Snd Function(), bool)> runner() {
  final d5 = hz('D5'), a5 = hz('A5'), d6 = hz('D6'), fs6 = hz('F#6'), a6 = hz('A6');
  Map<String, Snd Function()> sfx() => {
    // up on the skateboard: a springy hop and a swish
    'sr_jump': () {
      final x = Snd(.6)
        ..mix(boing(f0: 240, f1: 520, dur: .3, amp: .7))
        ..mix(whoosh(.3, 900, 3800, amp: .5, q: 1.4));
      return master(houseEq(room(x, wet: .1)), feedback - 2);
    },
    // back on the road: a soft thump and the wheels click
    'sr_land': () {
      final x = Snd(.4)
        ..mix(thump(f0: 200, f1: 100, dur: .12, amp: .9))
        ..mix(strike(.012, 2600, .35, q: 1.3), at: .01)
        ..mix(strike(.01, 2900, .25, q: 1.3), at: .06);
      return master(houseEq(x), soft);
    },
    // a bump into a log or a rock: a wooden knock and a dizzy boing down
    'sr_bump': () {
      final x = Snd(.9)
        ..mix(thump(f0: 190, f1: 80, dur: .2, amp: 1))
        ..mix(wood(hz('D5'), dur: .14, amp: .8, bright: 1.3))
        ..mix(boing(f0: 420, f1: 180, dur: .45, amp: .5), at: .08);
      return master(houseEq(room(x, wet: .12)), feedback);
    },
    // into a puddle: a splash with bubbly drops
    'sr_splash': () {
      final x = Snd(.9);
      final n = Snd(.45);
      for (var i = 0; i < n.s.length; i++) {
        final t = i / sr;
        n.s[i] = noise() * _env(t, .004, .09);
      }
      x.mix(filter(n, (b) => b.lowpass(2600, .8)));
      for (var k = 0; k < 4; k++) {
        x.mix(bloop(f0: 500 + k * 120.0, f1: 1100 + k * 160.0, dur: .07, amp: .4), at: .1 + k * .07);
      }
      return master(houseEq(room(x, wet: .14)), feedback - 1);
    },
    // on a banana peel: a squeaky slide
    'sr_slip': () {
      final x = Snd(.6);
      var ph = 0.0;
      for (var i = 0; i < x.s.length; i++) {
        final t = i / sr;
        final f = 700 + 900 * (t / .5) + 60 * math.sin(2 * math.pi * 18 * t);
        ph += 2 * math.pi * f / sr;
        x.s[i] = (math.sin(ph) + .2 * math.sin(2 * ph)) * _env(t, .01, .2) * .7;
      }
      return master(houseEq(room(x, wet: .1)), feedback - 2);
    },
    // a whole word: a rush of speed going up
    'sr_boost': () {
      final x = Snd(1.3)..mix(whoosh(.9, 400, 7000, amp: .7, q: 1.1, peakAt: .75));
      for (final (i, f) in [d5, fs6 / 2, a5, d6, fs6, a6].indexed) {
        x.mix(kalimba(f, dur: .25, amp: .5), at: .1 + i * .07);
      }
      x.mix(sparkle(.6, count: 7, seed: 511, amp: .25), at: .5);
      return master(houseEq(room(x, wet: .18)), celebrate - 1);
    },
    // the countdown: three blips, then a higher one for "go"
    'sr_beep': () => master(houseEq(Snd(.3)..mix(blip(a5, dur: .16, amp: 1))), feedback - 2),
    'sr_beep_go': () => master(houseEq(room(Snd(.6)..mix(blip(d6, dur: .3, amp: 1))..mix(bell(d6, dur: .5, amp: .5)), wet: .15)), feedback),
  };
  return {
    for (final e in sfx().entries) e.key: (e.value, false),
    // Spell Runner: a bright, quick tune
    'sr_music': (() => halfRate(
      masterLoop(
        gameMusic(
          bpm: 140,
          tense: false,
          seed: 510,
          roots: [hz('D3'), hz('A2'), hz('B2'), hz('A2')],
          tune: const [
            [10, 9, 8, null, 10, 9, 8, 7],
            [8, null, 7, 5, 7, null, null, null],
            [9, 10, 12, null, 10, 9, 8, null],
            [7, 8, 9, 8, 10, null, null, null],
          ],
        ),
        soft - 2,
      ),
    ), true),
    // the skateboard's wheels on the road (looped while he rides)
    'sr_roll': (() {
      final n = (1.44 * sr).round();
      final x = Snd(1.44);
      for (var i = 0; i < n; i++) {
        x.s[i] = noise() * .5;
      }
      filter(x, (b) => b.lowpass(420, .7));
      // a click every seam in the road
      for (var k = 0; k < 8; k++) {
        x.mix(strike(.01, 1800, .12, q: 1.5), at: k * .18);
      }
      final out = Snd(0)..s = Float64List.fromList(x.s.sublist(0, n));
      return halfRate(masterLoop(out, ui - 4));
    }, true),
  };
}

/// Monster Smash's sounds, made after Spell Runner's (so every older sound
/// keeps its take). The music is at half rate.
Map<String, (Snd Function(), bool)> smash() {
  final g5 = hz('G5'), b5 = hz('B5'), d6 = hz('D6'), g6 = hz('G6');
  Map<String, Snd Function()> sfx() => {
    // the band pulled back: a rubbery creak going up
    'ms_stretch': () {
      final x = Snd(.55);
      var ph = 0.0;
      for (var i = 0; i < x.s.length; i++) {
        final t = i / sr;
        final f = 180 + 260 * (t / .5) + 25 * math.sin(2 * math.pi * 31 * t);
        ph += 2 * math.pi * f / sr;
        final e = math.min(1.0, t / .04) * math.exp(-math.max(0, t - .35) / .08);
        x.s[i] = (math.sin(ph) + .35 * math.sin(3 * ph) + .15 * noise()) * e * .6;
      }
      return master(houseEq(filter(x, (b) => b.lowpass(2400, .8))), soft);
    },
    // let go: the band twangs and the ball swooshes away
    'ms_launch': () {
      final x = Snd(.8)
        ..mix(partials(hz('G2'), .35, [(1, 1, .3), (2, .5, .2), (3, .3, .12)], attack: .001, detune: 3))
        ..mix(whoosh(.45, 600, 4200, amp: .8, q: 1.2, peakAt: .35), at: .02);
      return master(houseEq(room(x, wet: .1)), feedback - 1);
    },
    // knocks: wood, ice, stone
    'ms_wood': () => master(houseEq(Snd(.35)..mix(wood(hz('D4'), dur: .18, amp: 1, bright: 1.4))..mix(thump(f0: 180, f1: 110, dur: .1, amp: .6))), feedback - 3),
    'ms_ice': () => master(houseEq(room(Snd(.5)..mix(bell(hz('E7'), dur: .25, bright: 1.2, amp: .7))..mix(strike(.02, 5200, .5, q: 2)), wet: .12)), feedback - 4),
    'ms_stone': () => master(houseEq(Snd(.4)..mix(thump(f0: 140, f1: 70, dur: .18, amp: 1))..mix(strike(.05, 900, .5, q: .9))), feedback - 2),
    // breaking: wood cracks and splinters, ice shatters, stone crumbles
    'ms_wood_break': () {
      final x = Snd(.8)
        ..mix(strike(.03, 1700, 1, q: .8))
        ..mix(thump(f0: 170, f1: 90, dur: .16, amp: .8));
      for (var k = 0; k < 5; k++) {
        x.mix(wood(hz('A4') * (1 + k * .23), dur: .09, amp: .45, bright: 1.6), at: .03 + k * .045);
      }
      return master(houseEq(room(x, wet: .12)), feedback);
    },
    'ms_ice_break': () {
      final x = Snd(1.0)..mix(strike(.06, 4200, 1, q: .7));
      for (var k = 0; k < 9; k++) {
        x.mix(bell(deg(12 + (k * 5) % 8), dur: .18, bright: 1.3, amp: .45), at: .01 + k * .035);
      }
      return master(houseEq(room(x, wet: .16)), feedback - 1);
    },
    'ms_stone_break': () {
      final x = Snd(.9)..mix(thump(f0: 120, f1: 55, dur: .3, amp: 1));
      for (var k = 0; k < 6; k++) {
        x.mix(strike(.04, 600 + k * 140.0, .55, q: .9), at: .02 + k * .06);
      }
      return master(houseEq(room(x, wet: .12)), feedback);
    },
    // the asked letter's block bursts: a big pop and sparkles
    'ms_pow': () {
      final x = Snd(1.2)
        ..mix(pop(300, 1300, dur: .12, amp: 1, body: .4))
        ..mix(thump(f0: 220, f1: 90, dur: .2, amp: .8));
      for (final (i, f) in [g5, b5, d6, g6].indexed) {
        x.mix(kalimba(f, dur: .3, amp: .55), at: .08 + i * .06);
      }
      x.mix(sparkle(.6, count: 8, seed: 611, amp: .3), at: .25);
      return master(houseEq(room(x, wet: .18)), celebrate - 1);
    },
    // a monster turns into a friend: a happy spring up
    'ms_friend': () {
      final x = Snd(.8)
        ..mix(boing(f0: 300, f1: 640, dur: .35, amp: .7))
        ..mix(kalimba(d6, dur: .3, amp: .4), at: .12)
        ..mix(kalimba(g6, dur: .35, amp: .4), at: .2);
      return master(houseEq(room(x, wet: .14)), feedback - 2);
    },
  };
  return {
    for (final e in sfx().entries) e.key: (e.value, false),
    // Monster Smash: a bouncy, cheeky tune
    'ms_music': (() => halfRate(
      masterLoop(
        gameMusic(
          bpm: 118,
          tense: false,
          seed: 610,
          roots: [hz('G2'), hz('C3'), hz('D3'), hz('G2')],
          tune: const [
            [7, null, 9, 7, 11, null, 9, null],
            [8, null, 10, 8, 12, null, 10, null],
            [11, 12, 13, null, 12, 11, 9, null],
            [7, 9, 11, 9, 7, null, null, null],
          ],
        ),
        soft - 3,
      ),
    ), true),
  };
}

/// Letter Slice's sounds, made after Monster Smash's (so every older sound
/// keeps its take). The music is at half rate.
Map<String, (Snd Function(), bool)> slicing() {
  final c6 = hz('C6'), e6 = hz('E6'), g6 = hz('G6'), c7 = hz('C7');
  Map<String, Snd Function()> sfx() => {
    // the blade through the air
    'ls_swish': () => master(houseEq(Snd(.3)..mix(whoosh(.2, 1800, 7500, amp: .8, q: 1.6, peakAt: .3))), soft),
    // a fruit cut: a juicy squish and a few drops
    'ls_cut': () {
      final x = Snd(.6);
      final n = Snd(.2);
      for (var i = 0; i < n.s.length; i++) {
        final t = i / sr;
        n.s[i] = noise() * _env(t, .002, .05);
      }
      x
        ..mix(filter(n, (b) => b.bandpass(1500, .9)))
        ..mix(whoosh(.12, 3000, 6000, amp: .4, q: 2))
        ..mix(bloop(f0: 420, f1: 1000, dur: .08, amp: .5), at: .05)
        ..mix(bloop(f0: 600, f1: 1300, dur: .06, amp: .35), at: .12);
      return master(houseEq(room(x, wet: .1)), feedback - 1);
    },
    // a wrong letter bounces off the blade: a hollow clonk and a boing down
    'ls_clonk': () {
      final x = Snd(.7)
        ..mix(wood(hz('G4'), dur: .16, amp: .9, bright: 1.2))
        ..mix(boing(f0: 380, f1: 200, dur: .35, amp: .45), at: .05);
      return master(houseEq(room(x, wet: .1)), feedback - 2);
    },
    // three or more in one swipe
    'ls_combo': () {
      final x = Snd(1.0);
      for (final (i, f) in [c6, e6, g6, c7].indexed) {
        x.mix(kalimba(f, dur: .3, amp: .6), at: i * .06);
      }
      x.mix(sparkle(.5, count: 6, seed: 711, amp: .25), at: .2);
      return master(houseEq(room(x, wet: .16)), celebrate - 2);
    },
    // the ice berry: a frosty shimmer going down
    'ls_freeze': () {
      final x = Snd(1.2)..mix(whoosh(.9, 6000, 1200, amp: .5, q: 3, peakAt: .2));
      for (var k = 0; k < 7; k++) {
        x.mix(bell(deg(19 - k * 2), dur: .3, bright: .8, amp: .4), at: k * .08);
      }
      return master(houseEq(room(x, wet: .25)), feedback - 1);
    },
    // the banana: a fruit party fanfare
    'ls_frenzy': () {
      final x = Snd(1.2)..mix(whoosh(.5, 500, 5000, amp: .6, q: 1.2, peakAt: .7));
      for (final (i, f) in [c6, g6, e6, c7, g6, c7].indexed) {
        x.mix(kalimba(f, dur: .25, amp: .55), at: .05 + i * .08);
      }
      return master(houseEq(room(x, wet: .16)), celebrate - 1);
    },
  };
  return {
    for (final e in sfx().entries) e.key: (e.value, false),
    // Letter Slice: a quick, plucky tune
    'ls_music': (() => halfRate(
      masterLoop(
        gameMusic(
          bpm: 150,
          tense: false,
          seed: 710,
          roots: [hz('C3'), hz('A2'), hz('F2'), hz('G2')],
          tune: const [
            [12, null, 11, 9, 12, null, 14, null],
            [9, 11, 12, null, 11, 9, 7, null],
            [10, null, 9, 7, 10, 12, 14, null],
            [11, 12, 11, 9, 7, null, null, null],
          ],
        ),
        soft - 3,
      ),
    ), true),
  };
}

/// Monster Smash, alive: the band's tighter creaks, the ball dropped into
/// the pouch and the monsters' voices. Made last, so every older sound keeps
/// its take.
Map<String, (Snd Function(), bool)> smashLife() {
  // a rubbery creak from [f0] up to [f1]
  Snd creak(double f0, double f1, double dur, int wobble) {
    final x = Snd(dur + .05);
    var ph = 0.0;
    for (var i = 0; i < x.s.length; i++) {
      final t = i / sr;
      final f = f0 + (f1 - f0) * math.min(1.0, t / dur) + 20 * math.sin(2 * math.pi * wobble * t);
      ph += 2 * math.pi * f / sr;
      final e = math.min(1.0, t / .02) * math.exp(-math.max(0, t - dur * .7) / .05);
      x.s[i] = (math.sin(ph) + .4 * math.sin(2 * ph) + .3 * math.sin(3 * ph) + .12 * noise()) * e * .6;
    }
    return filter(x, (b) => b.lowpass(2800, .8));
  }

  // a little voice: a buzzy tone that slides from [f0] to [f1], with vibrato
  Snd voice(double f0, double f1, double dur, {double vib = 28, double depth = .05}) {
    final x = Snd(dur + .03);
    var ph = 0.0;
    for (var i = 0; i < x.s.length; i++) {
      final t = i / sr;
      final f = (f0 + (f1 - f0) * math.min(1.0, t / dur)) * (1 + depth * math.sin(2 * math.pi * vib * t));
      ph += 2 * math.pi * f / sr;
      final e = math.min(1.0, t / .008) * math.exp(-math.max(0, t - dur * .55) / (dur * .25));
      x.s[i] = (math.sin(ph) + .55 * math.sin(2 * ph) + .35 * math.sin(3 * ph) + .2 * math.sin(4 * ph)) * e * .5;
    }
    return filter(x, (b) => b.bandpass(1400, .7));
  }

  Map<String, Snd Function()> sfx() => {
    // tighter, and tighter: short creaks going higher
    'ms_stretch_2': () => master(houseEq(creak(330, 520, .22, 34)), soft),
    'ms_stretch_3': () => master(houseEq(creak(480, 760, .2, 41)..mix(bell(hz('A6'), dur: .12, bright: .6, amp: .15), at: .12)), soft),
    // the ball dropped into the leather pouch
    'ms_reload': () => master(
      houseEq(
        Snd(.3)
          ..mix(thump(f0: 260, f1: 140, dur: .08, amp: .8))
          ..mix(pop(480, 900, dur: .05, amp: .5, body: .5), at: .01)
          ..mix(wood(hz('D5'), dur: .07, amp: .3, bright: 1.2), at: .03),
      ),
      feedback - 4,
    ),
    // a cheeky monster: "hee-hee-hee"
    'ms_giggle': () {
      final x = Snd(.6);
      for (final (i, f) in [760.0, 700.0, 640.0].indexed) {
        x.mix(voice(f * 1.06, f, .09), at: i * .12);
      }
      return master(houseEq(room(x, wet: .1)), feedback - 3);
    },
    // the ball is coming: a quick squeak up
    'ms_eek': () => master(houseEq(room(Snd(.4)..mix(voice(820, 1700, .18, vib: 34, depth: .04)), wet: .08)), feedback - 3),
    // knocked: a hollow bonk, a boing down and little tweets
    'ms_bonk': () => master(
      houseEq(
        room(
          Snd(.9)
            ..mix(wood(hz('A3'), dur: .2, amp: 1, bright: 1.2))
            ..mix(boing(f0: 520, f1: 240, dur: .35, amp: .5), at: .02)
            ..mix(sparkle(.4, count: 5, seed: 811, amp: .25), at: .16),
          wet: .12,
        ),
      ),
      feedback - 1,
    ),
  };
  return {for (final e in sfx().entries) e.key: (e.value, false)};
}

/// Monster Smash's heroes: a hop into the slingshot, a "wheee" as they fly,
/// each one's power, a bonus hero, a poof. Made last, so every older sound
/// keeps its take.
Map<String, (Snd Function(), bool)> smashHeroes() {
  // a little voice gliding from [f0] to [f1] (the heroes' "hup" and "wheee")
  Snd glide(double f0, double f1, double dur, {double vib = 7, double depth = .03, double formant = 1300}) {
    final x = Snd(dur + .05);
    var ph = 0.0;
    for (var i = 0; i < x.s.length; i++) {
      final t = i / sr;
      final k = math.min(1.0, t / dur);
      final f = (f0 + (f1 - f0) * k) * (1 + depth * math.sin(2 * math.pi * vib * t));
      ph += 2 * math.pi * f / sr;
      final e = math.min(1.0, t / .015) * math.exp(-math.max(0, t - dur * .7) / (dur * .2));
      x.s[i] = (math.sin(ph) + .5 * math.sin(2 * ph) + .3 * math.sin(3 * ph) + .15 * math.sin(4 * ph)) * e * .5;
    }
    return filter(x, (b) => b.bandpass(formant, .7));
  }

  Map<String, Snd Function()> sfx() => {
    // a hero hops from the line into the slingshot
    'ms_hup': () => master(houseEq(Snd(.4)..mix(glide(420, 760, .12, formant: 1500))..mix(bloop(f0: 300, f1: 700, dur: .08, amp: .4), at: .02)), feedback - 4),
    // flung: "wheee!"
    'ms_whee': () => master(houseEq(room(Snd(.9)..mix(glide(880, 620, .55, vib: 9, depth: .05, formant: 1700)), wet: .1)), feedback - 3),
    // Rubby's power: a big rubbery boing and a whomp
    'ms_boing': () => master(
      houseEq(room(Snd(.9)..mix(boing(f0: 180, f1: 520, dur: .45, amp: 1))..mix(thump(f0: 150, f1: 70, dur: .2, amp: .8))..mix(whoosh(.3, 500, 2500, amp: .4, q: 1.2), at: .02), wet: .12)),
      feedback,
    ),
    // Inky splits: three quick plips
    'ms_split': () {
      final x = Snd(.6);
      for (final (i, f) in [900.0, 1200.0, 1500.0].indexed) {
        x.mix(bloop(f0: f * .6, f1: f, dur: .07, amp: .6), at: i * .06);
      }
      return master(houseEq(room(x, wet: .1)), feedback - 2);
    },
    // Crayo zooms: a rising rush and a zing
    'ms_zoom': () => master(houseEq(room(Snd(.8)..mix(whoosh(.5, 400, 6000, amp: 1, q: 1.6, peakAt: .5))..mix(bell(hz('A6'), dur: .2, bright: 1.2, amp: .25), at: .2), wet: .1)), feedback - 1),
    // a bonus hero joins the line
    'ms_bonus': () {
      final x = Snd(1.0);
      for (final (i, n) in ['D6', 'F#6', 'A6', 'D7'].indexed) {
        x.mix(kalimba(hz(n), dur: .3, amp: .6), at: i * .07);
      }
      x.mix(sparkle(.5, count: 7, seed: 911, amp: .3), at: .2);
      return master(houseEq(room(x, wet: .16)), celebrate - 2);
    },
    // a hero vanishes in a puff
    'ms_poof': () => master(houseEq(Snd(.45)..mix(whoosh(.25, 2500, 600, amp: .6, q: 1, peakAt: .2))..mix(pop(600, 300, dur: .06, amp: .4, body: .2))), soft),
  };
  return {for (final e in sfx().entries) e.key: (e.value, false)};
}

void main() {
  final dir = Directory('assets/sfx')..createSync(recursive: true);
  final p = palette();
  var bytes = 0;
  for (final e in p.entries) {
    final snd = e.value();
    final path = '${dir.path}/${e.key}.wav';
    writeWav(path, snd);
    bytes += File(path).lengthSync();
    stdout.writeln('${e.key.padRight(16)} ${(snd.seconds * 1000).round().toString().padLeft(5)} ms');
  }
  for (final e in music().entries) {
    final snd = e.value();
    final path = '${dir.path}/${e.key}.wav';
    writeWav(path, snd, rate: sr ~/ 2);
    bytes += File(path).lengthSync();
    stdout.writeln('${e.key.padRight(16)} ${(snd.seconds * 2000).round().toString().padLeft(5)} ms (loop)');
  }
  for (final e in {...runner(), ...smash(), ...slicing(), ...smashLife(), ...smashHeroes()}.entries) {
    final (make, half) = e.value;
    final snd = make();
    final path = '${dir.path}/${e.key}.wav';
    writeWav(path, snd, rate: half ? sr ~/ 2 : sr);
    bytes += File(path).lengthSync();
    stdout.writeln('${e.key.padRight(16)} ${(snd.seconds * (half ? 2000 : 1000)).round().toString().padLeft(5)} ms');
  }
  stdout.writeln('${p.length + music().length + runner().length + smash().length + slicing().length + smashLife().length + smashHeroes().length} sounds, ${(bytes / 1024).round()} KB');
}
