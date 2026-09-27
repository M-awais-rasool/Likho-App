"""Tiny raster -> vector tracing toolkit (pure Python + PIL).

Used to trace the Pencil mascot master image into layered SVG parts.
Pipeline: classify pixels by nearest palette colour -> binary mask -> 3x3 blur
-> marching squares at iso 0.5 (sub-pixel) -> RDP simplify -> smooth cubic path.
"""
import math
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
MDIR = os.path.join(ROOT, "mascot's") + "/"
WORK = os.path.join(HERE, '.work')        # intermediate files (git-ignored)
os.makedirs(WORK, exist_ok=True)


def load(path):
    im = Image.open(path).convert('RGB')
    return im, im.load()


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def dist2(a, b):
    # perceptual-ish weighting
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return 2 * dr * dr + 4 * dg * dg + 3 * db * db


class Classifier:
    """Nearest-colour labelling inside a rectangular ROI."""

    def __init__(self, px, roi, palette):
        self.x0, self.y0, self.x1, self.y1 = roi
        self.w, self.h = self.x1 - self.x0, self.y1 - self.y0
        self.names = list(palette.keys())
        cols = [[hexrgb(c) for c in (v if isinstance(v, list) else [v])] for v in palette.values()]
        lab = []
        for y in range(self.y0, self.y1):
            row = []
            for x in range(self.x0, self.x1):
                p = px[x, y]
                best, bi = 1 << 30, 0
                for i, cs in enumerate(cols):
                    for c in cs:
                        d = dist2(p, c)
                        if d < best:
                            best, bi = d, i
                row.append(bi)
            lab.append(row)
        self.lab = lab

    def mask(self, names, where=None):
        ids = {self.names.index(n) for n in names}
        m = []
        for j, row in enumerate(self.lab):
            y = self.y0 + j
            mr = []
            for i, v in enumerate(row):
                ok = v in ids
                if ok and where is not None:
                    ok = where(self.x0 + i, y)
                mr.append(1.0 if ok else 0.0)
            m.append(mr)
        return Mask(m, self.x0, self.y0)


class Mask:
    def __init__(self, m, x0, y0):
        self.m, self.x0, self.y0 = m, x0, y0
        self.h, self.w = len(m), len(m[0])

    def copy(self):
        return Mask([r[:] for r in self.m], self.x0, self.y0)

    def union(self, o):
        r = self.copy()
        for j in range(self.h):
            for i in range(self.w):
                r.m[j][i] = max(r.m[j][i], o.m[j][i])
        return r

    def subtract(self, o):
        r = self.copy()
        for j in range(self.h):
            for i in range(self.w):
                if o.m[j][i] > 0.5:
                    r.m[j][i] = 0.0
        return r

    def clip(self, fn):
        r = self.copy()
        for j in range(self.h):
            for i in range(self.w):
                if not fn(self.x0 + i, self.y0 + j):
                    r.m[j][i] = 0.0
        return r

    def morph(self, n=1, grow=True):
        """binary dilate / erode with a 3x3 cross, n times"""
        r = self.copy()
        for _ in range(n):
            s = r.copy()
            for j in range(self.h):
                for i in range(self.w):
                    vals = [s.m[j][i]]
                    if j > 0: vals.append(s.m[j - 1][i])
                    if j < self.h - 1: vals.append(s.m[j + 1][i])
                    if i > 0: vals.append(s.m[j][i - 1])
                    if i < self.w - 1: vals.append(s.m[j][i + 1])
                    r.m[j][i] = max(vals) if grow else min(vals)
        return r

    def close(self, n=1):
        return self.morph(n, True).morph(n, False)

    def open(self, n=1):
        return self.morph(n, False).morph(n, True)

    def fill_holes(self):
        """flood from border; anything not reached and 0 becomes 1"""
        h, w = self.h, self.w
        seen = [[False] * w for _ in range(h)]
        stack = [(i, 0) for i in range(w)] + [(i, h - 1) for i in range(w)] + \
                [(0, j) for j in range(h)] + [(w - 1, j) for j in range(h)]
        while stack:
            i, j = stack.pop()
            if i < 0 or j < 0 or i >= w or j >= h or seen[j][i] or self.m[j][i] > 0.5:
                continue
            seen[j][i] = True
            stack += [(i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)]
        r = self.copy()
        for j in range(h):
            for i in range(w):
                if not seen[j][i]:
                    r.m[j][i] = 1.0
        return r

    def largest(self, k=1):
        """keep k largest 4-connected components"""
        h, w = self.h, self.w
        lab = [[0] * w for _ in range(h)]
        comps = []
        cid = 0
        for j in range(h):
            for i in range(w):
                if self.m[j][i] > 0.5 and not lab[j][i]:
                    cid += 1
                    stack = [(i, j)]
                    lab[j][i] = cid
                    n = 0
                    while stack:
                        a, b = stack.pop()
                        n += 1
                        for c, d in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                            if 0 <= c < w and 0 <= d < h and not lab[d][c] and self.m[d][c] > 0.5:
                                lab[d][c] = cid
                                stack.append((c, d))
                    comps.append((n, cid))
        comps.sort(reverse=True)
        keep = {c for _, c in comps[:k]}
        r = self.copy()
        for j in range(h):
            for i in range(w):
                r.m[j][i] = 1.0 if lab[j][i] in keep else 0.0
        return r

    def blur(self):
        h, w = self.h, self.w
        o = [[0.0] * w for _ in range(h)]
        for j in range(h):
            for i in range(w):
                s = 0.0
                n = 0
                for dj in (-1, 0, 1):
                    jj = j + dj
                    if 0 <= jj < h:
                        for di in (-1, 0, 1):
                            ii = i + di
                            if 0 <= ii < w:
                                s += self.m[jj][ii]
                                n += 1
                o[j][i] = s / n
        return Mask(o, self.x0, self.y0)

    def area(self):
        return sum(sum(1 for v in r if v > 0.5) for r in self.m)

    def bbox(self):
        xs, ys = [], []
        for j in range(self.h):
            for i in range(self.w):
                if self.m[j][i] > 0.5:
                    xs.append(i)
                    ys.append(j)
        return (self.x0 + min(xs), self.y0 + min(ys), self.x0 + max(xs), self.y0 + max(ys))

    def contours(self, iso=0.5, min_len=12):
        """marching squares -> list of closed loops in image coords (float)."""
        m = self.m
        h, w = self.h, self.w
        # pad with zeros so all contours close
        def v(i, j):
            if i < 0 or j < 0 or i >= w or j >= h:
                return 0.0
            return m[j][i]
        segs = {}

        def interp(p1, p2, v1, v2):
            t = (iso - v1) / (v2 - v1) if v2 != v1 else 0.5
            return (p1[0] + t * (p2[0] - p1[0]), p1[1] + t * (p2[1] - p1[1]))

        edges = []
        for j in range(-1, h):
            for i in range(-1, w):
                a, b, c, d = v(i, j), v(i + 1, j), v(i + 1, j + 1), v(i, j + 1)
                idx = (a > iso) * 8 + (b > iso) * 4 + (c > iso) * 2 + (d > iso)
                if idx in (0, 15):
                    continue
                P = {
                    't': ((i, j), (i + 1, j), a, b), 'r': ((i + 1, j), (i + 1, j + 1), b, c),
                    'b': ((i + 1, j + 1), (i, j + 1), c, d), 'l': ((i, j + 1), (i, j), d, a)}
                key = lambda e: (('h', i, j) if e == 't' else ('v', i + 1, j) if e == 'r' else ('h', i, j + 1) if e == 'b' else ('v', i, j))
                pt = lambda e: interp(*P[e])
                # oriented so that inside (>iso) is on the left when walking
                table = {
                    1: [('l', 'b')], 2: [('b', 'r')], 3: [('l', 'r')], 4: [('r', 't')],
                    5: [('l', 't'), ('r', 'b')], 6: [('b', 't')], 7: [('l', 't')], 8: [('t', 'l')],
                    9: [('t', 'b')], 10: [('t', 'r'), ('b', 'l')], 11: [('t', 'r')], 12: [('r', 'l')],
                    13: [('r', 'b')], 14: [('b', 'l')]}
                for e1, e2 in table[idx]:
                    edges.append((key(e1), key(e2), pt(e1), pt(e2)))
        nxt = {}
        pos = {}
        for k1, k2, p1, p2 in edges:
            nxt[k1] = k2
            pos[k1] = p1
            pos[k2] = p2
        loops = []
        used = set()
        for start in list(nxt.keys()):
            if start in used:
                continue
            loop = []
            k = start
            while k not in used and k in nxt:
                used.add(k)
                loop.append(pos[k])
                k = nxt[k]
            if len(loop) >= min_len:
                loops.append([(x + self.x0 + 0.5, y + self.y0 + 0.5) for x, y in loop])
        return loops


def poly_area(p):
    s = 0.0
    for i in range(len(p)):
        x1, y1 = p[i]
        x2, y2 = p[(i + 1) % len(p)]
        s += x1 * y2 - x2 * y1
    return s / 2


def rdp(points, eps):
    if len(points) < 3:
        return points
    a, b = points[0], points[-1]
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy) or 1e-9
    dmax, idx = 0, 0
    for i in range(1, len(points) - 1):
        p = points[i]
        d = abs(dy * p[0] - dx * p[1] + b[0] * a[1] - b[1] * a[0]) / L
        if d > dmax:
            dmax, idx = d, i
    if dmax > eps:
        l = rdp(points[:idx + 1], eps)
        r = rdp(points[idx:], eps)
        return l[:-1] + r
    return [a, b]


def rdp_closed(loop, eps):
    # split at the two farthest-apart points for a stable closed simplification
    n = len(loop)
    i0 = 0
    far = max(range(n), key=lambda i: (loop[i][0] - loop[0][0]) ** 2 + (loop[i][1] - loop[0][1]) ** 2)
    a = rdp(loop[i0:far + 1], eps)
    b = rdp(loop[far:] + [loop[0]], eps)
    return a[:-1] + b[:-1]


def smooth_loop(loop, window=2):
    """moving-average smoothing of a closed polyline (reduces pixel stair noise)"""
    n = len(loop)
    out = []
    for i in range(n):
        sx = sy = 0.0
        for k in range(-window, window + 1):
            x, y = loop[(i + k) % n]
            sx += x
            sy += y
        out.append((sx / (2 * window + 1), sy / (2 * window + 1)))
    return out


def to_cubic_path(pts, T, corner_deg=55, tension=1.0, prec=2):
    """Closed Catmull-Rom through pts -> cubic bezier SVG path. Sharp corners kept."""
    n = len(pts)
    P = [T(p) for p in pts]

    def ang(i):
        a, b, c = P[i - 1], P[i], P[(i + 1) % n]
        v1 = (a[0] - b[0], a[1] - b[1])
        v2 = (c[0] - b[0], c[1] - b[1])
        l1, l2 = math.hypot(*v1) or 1e-9, math.hypot(*v2) or 1e-9
        cos = (v1[0] * v2[0] + v1[1] * v2[1]) / (l1 * l2)
        return math.degrees(math.acos(max(-1, min(1, cos))))
    corner = [ang(i) < (180 - corner_deg) for i in range(n)]
    f = lambda v: ('%.*f' % (prec, v)).rstrip('0').rstrip('.') if '.' in ('%.*f' % (prec, v)) else '%.*f' % (prec, v)
    d = ['M%s %s' % (f(P[0][0]), f(P[0][1]))]
    for i in range(n):
        p0, p1, p2, p3 = P[i - 1], P[i], P[(i + 1) % n], P[(i + 2) % n]
        if corner[i]:
            c1 = p1
        else:
            c1 = (p1[0] + (p2[0] - p0[0]) / 6 * tension, p1[1] + (p2[1] - p0[1]) / 6 * tension)
        j = (i + 1) % n
        if corner[j]:
            c2 = p2
        else:
            c2 = (p2[0] - (p3[0] - p1[0]) / 6 * tension, p2[1] - (p3[1] - p1[1]) / 6 * tension)
        if corner[i] and corner[j]:
            d.append('L%s %s' % (f(p2[0]), f(p2[1])))
        else:
            d.append('C%s %s %s %s %s %s' % (f(c1[0]), f(c1[1]), f(c2[0]), f(c2[1]), f(p2[0]), f(p2[1])))
    d.append('Z')
    return ''.join(d)


def mask_to_path(mask, T, eps=0.9, smooth=1, min_area=30, corner_deg=55, holes=True, poly=False):
    loops = mask.blur().contours()
    out = []
    for lp in loops:
        a = poly_area(lp)
        if abs(a) < min_area:
            continue
        if not holes and a < 0:
            continue
        if smooth:
            lp = smooth_loop(lp, smooth)
        s = rdp_closed(lp, eps)
        if len(s) < 3:
            continue
        if poly:
            P = [T(p) for p in s]
            out.append('M' + ' L'.join('%.2f %.2f' % p for p in P) + 'Z')
        else:
            out.append(to_cubic_path(s, T, corner_deg=corner_deg))
    return ' '.join(out)
