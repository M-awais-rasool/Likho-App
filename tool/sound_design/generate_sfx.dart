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

void writeWav(String path, Snd x) {
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
  u32(sr);
  u32(sr * 2);
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
  };
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
  stdout.writeln('${p.length} sounds, ${(bytes / 1024).round()} KB');
}
