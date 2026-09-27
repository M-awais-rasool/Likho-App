import 'dart:ui';

import 'package:xml/xml.dart';

import '../../design/tokens.dart';

/// Maps a point in part space to canvas space (used for the body bend).
typedef PointWarp = Offset Function(Offset p);

/// A parsed SVG path kept as absolute segments, so it can be rebuilt through a
/// non-linear [PointWarp] (the torso "lean" bend) as well as drawn as-is.
class PathData {
  PathData._(this._ops, this._pts);

  // op codes: 0 moveTo(1 pt), 1 lineTo(1 pt), 2 cubicTo(3 pts), 3 close
  final List<int> _ops;
  final List<Offset> _pts;

  Path build([PointWarp? warp]) {
    final path = Path();
    var i = 0;
    Offset w(Offset p) => warp == null ? p : warp(p);
    for (final op in _ops) {
      switch (op) {
        case 0:
          final p = w(_pts[i++]);
          path.moveTo(p.dx, p.dy);
        case 1:
          final p = w(_pts[i++]);
          path.lineTo(p.dx, p.dy);
        case 2:
          final a = w(_pts[i++]), b = w(_pts[i++]), c = w(_pts[i++]);
          path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
        case 3:
          path.close();
      }
    }
    return path;
  }

  /// Parses SVG path data. Supports M L H V C S Q T Z (absolute and relative).
  /// Elliptical arcs (A) are approximated by a line to their end point; the
  /// traced mascot parts never use them.
  static PathData parse(String d) {
    final ops = <int>[];
    final pts = <Offset>[];
    final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
    var i = 0;
    var cur = Offset.zero, start = Offset.zero, lastCtrl = Offset.zero;
    String cmd = 'M';
    String prev = '';
    double num() => double.parse(tokens[i++]);
    bool isNum() => i < tokens.length && !RegExp(r'^[A-Za-z]$').hasMatch(tokens[i]);
    void cubic(Offset a, Offset b, Offset c) {
      ops.add(2);
      pts..add(a)..add(b)..add(c);
      lastCtrl = b;
      cur = c;
    }

    while (i < tokens.length) {
      if (!isNum()) cmd = tokens[i++];
      final rel = cmd == cmd.toLowerCase();
      Offset pt(double x, double y) => rel ? cur + Offset(x, y) : Offset(x, y);
      switch (cmd.toUpperCase()) {
        case 'M':
          cur = pt(num(), num());
          start = cur;
          ops.add(0);
          pts.add(cur);
          cmd = rel ? 'l' : 'L'; // implicit lineTo for following pairs
        case 'L':
          cur = pt(num(), num());
          ops.add(1);
          pts.add(cur);
        case 'H':
          final x = num();
          cur = Offset(rel ? cur.dx + x : x, cur.dy);
          ops.add(1);
          pts.add(cur);
        case 'V':
          final y = num();
          cur = Offset(cur.dx, rel ? cur.dy + y : y);
          ops.add(1);
          pts.add(cur);
        case 'C':
          final a = pt(num(), num()), b = pt(num(), num()), c = pt(num(), num());
          cubic(a, b, c);
        case 'S':
          final a = 'CcSs'.contains(prev) ? cur * 2 - lastCtrl : cur;
          final b = pt(num(), num()), c = pt(num(), num());
          cubic(a, b, c);
        case 'Q':
          final q = pt(num(), num()), c = pt(num(), num());
          cubic(cur + (q - cur) * (2 / 3), c + (q - c) * (2 / 3), c);
          lastCtrl = q;
        case 'T':
          final q = 'QqTt'.contains(prev) ? cur * 2 - lastCtrl : cur;
          final c = pt(num(), num());
          cubic(cur + (q - cur) * (2 / 3), c + (q - c) * (2 / 3), c);
          lastCtrl = q;
        case 'A':
          for (var k = 0; k < 5; k++) {
            num();
          }
          cur = pt(num(), num());
          ops.add(1);
          pts.add(cur);
        case 'Z':
          ops.add(3);
          cur = start;
      }
      prev = cmd;
    }
    return PathData._(ops, pts);
  }
}

/// One filled shape of a mascot part.
class PartShape {
  PartShape({required this.role, required this.fill, required this.data, required this.evenOdd}) : path = data.build() {
    path.fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
  }

  /// Colour role (the SVG `class`), e.g. `body-line`. Null = use [fill].
  final String? role;
  final Color fill;
  final PathData data;
  final bool evenOdd;

  /// Cached path for the un-warped case.
  final Path path;

  Path warped(PointWarp warp) => data.build(warp)..fillType = path.fillType;
}

/// Reads the constrained SVG the mascot parts are written in: `<path>` elements
/// (optionally inside `<g>`), with `d`, `fill`, `class` and `fill-rule`.
List<PartShape> parsePartSvg(String svg) {
  final doc = XmlDocument.parse(svg);
  final out = <PartShape>[];
  for (final el in doc.findAllElements('path')) {
    final d = el.getAttribute('d');
    if (d == null || d.isEmpty) continue;
    out.add(PartShape(
      role: el.getAttribute('class'),
      fill: _parseColor(el.getAttribute('fill')),
      data: PathData.parse(d),
      evenOdd: el.getAttribute('fill-rule') == 'evenodd',
    ));
  }
  return out;
}

Color _parseColor(String? v) {
  if (v == null || !v.startsWith('#')) return MascotColors.debugMissing;
  var h = v.substring(1);
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  return Color(int.parse('FF$h', radix: 16));
}
