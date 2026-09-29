"""Second pass: geometric body, hands (rest), shadow. Updates parts_master.json + rig.json"""
import json, math, pickle
from tracelib import *

C = pickle.load(open('master_cls.pkl', 'rb'))
M = pickle.load(open('masks.pkl', 'rb'))
cone_sil = M['cone_sil']
OX, OY = 454, 36
T = lambda p: (p[0] - OX, p[1] - OY)
parts = json.load(open('parts_master.json'))
arms = json.load(open('arms_centre.json'))


def layer(role, mask, **kw):
    d = mask_to_path(mask, T, **kw)
    return {'role': role, 'd': d} if d else None


def fmask(fn, x0=470, y0=80, x1=940, y1=700):
    return Mask([[1.0 if fn(x + 0.5, y + 0.5) else 0.0 for x in range(x0, x1)] for y in range(y0, y1)], x0, y0)


# ------------------------------------------------------------- body (geometric)
BX0, BX1, LINE = 575.5, 832.5, 5.0
BTOP, BBOT = 200, 512          # hidden under band / meets the cone sides
band_bottom = 232
cone_in = cone_sil.morph(1, grow=False)


def body_outline(x, y):
    # slight taper measured on the master: left edge 575.5 -> 577.5, right 832.5 -> 830.5 at the bottom
    k = max(0.0, min(1.0, (y - 236) / (505 - 236)))
    xl, xr = BX0 + 2 * k, BX1 - 2 * k
    return xl <= x <= xr and BTOP <= y <= BBOT


def body_inner(x, y):
    k = max(0.0, min(1.0, (y - 236) / (505 - 236)))
    xl, xr = BX0 + 2 * k + LINE, BX1 - 2 * k - LINE
    return xl <= x <= xr and BTOP - 4 <= y <= BBOT + 6


sil = fmask(body_outline).union(cone_sil.clip(lambda x, y: y < 535 and BX0 < x < BX1))
inn = fmask(body_inner).union(cone_in.clip(lambda x, y: y < 530 and BX0 + LINE < x < BX1 - LINE))
light = inn.clip(lambda x, y: x < 644.5)
dark = inn.clip(lambda x, y: x > 766.5)
# soft shade under the band: traced from the master (dark strip following the band's lower curve)
band_sil = C.mask(['band', 'band_hi', 'band_sh', 'band_line'], where=lambda x, y: 170 < y < 240 and 560 < x < 848).close(2).fill_holes().largest()
_shift = Mask([[0.0] * band_sil.w for _ in range(9)] + [r[:] for r in band_sil.m[:-9]], band_sil.x0, band_sil.y0)
under = _shift.subtract(band_sil).clip(lambda x, y: body_inner(x, y))
under_mid = under.clip(lambda x, y: x >= 644.5)
under_light = under.clip(lambda x, y: x < 644.5)
parts['body'] = [l for l in [
    layer('body-line', sil, eps=0.5, smooth=0, poly=True),
    layer('body', inn, eps=0.5, smooth=0, poly=True),
    layer('body-light', light, eps=0.5, smooth=0, poly=True),
    layer('body-dark', dark, eps=0.5, smooth=0, poly=True),
    layer('body-dark', under_mid, eps=0.6, min_area=20),
    layer('body', under_light, eps=0.6, min_area=20),
] if l]

# ------------------------------------------------------------- hands (rest, from master)
def bez(S, Cc, W, t):
    u = 1 - t
    return (u * u * S[0] + 2 * u * t * Cc[0] + t * t * W[0], u * u * S[1] + 2 * u * t * Cc[1] + t * t * W[1])


def dbez(S, Cc, W, t):
    u = 1 - t
    return (2 * u * (Cc[0] - S[0]) + 2 * t * (W[0] - Cc[0]), 2 * u * (Cc[1] - S[1]) + 2 * t * (W[1] - Cc[1]))


rig = {'artboard': [500, 680], 'origin': [OX, OY], 'arms': {}}
NONBG = [n for n in C.names if n not in ('bg', 'shadow', 'band_hi')]
for side, name in (('L', 'hand_rest_left'), ('R', 'hand_rest_right')):
    S, Cc, W = arms[side]['S'], arms[side]['C'], arms[side]['W']
    # wrist = where the hand starts on the master (y ~ 488)
    tw = 0.0
    for i in range(1001):
        t = i / 1000
        if bez(S, Cc, W, t)[1] >= 488:
            tw = t
            break
    P = bez(S, Cc, W, tw)
    d = dbez(S, Cc, W, tw)
    n = math.hypot(*d)
    ux, uy = d[0] / n, d[1] / n
    # rest arm = sub-curve [0, tw] (de Casteljau)
    C2 = ((1 - tw) * S[0] + tw * Cc[0], (1 - tw) * S[1] + tw * Cc[1])
    rig['arms'][side] = {'S': T(S), 'C': T(C2), 'W': T(P), 'tangent': [ux, uy], 't_w': tw}
    back = 3.0   # the hand overlaps the arm end by 3 units
    beyond = lambda x, y: (x - P[0]) * ux + (y - P[1]) * uy > -back
    xr = (470, 580) if side == 'L' else (830, 940)
    hs = C.mask(NONBG, where=lambda x, y: 470 < y < 580 and xr[0] < x < xr[1] and beyond(x, y)).close(1).fill_holes().largest()
    hi = C.mask(['body', 'body_l', 'body_d'], where=lambda x, y: 470 < y < 580 and xr[0] < x < xr[1] and beyond(x, y))
    hi = hi.largest(4)
    hl = C.mask(['body_l'], where=lambda x, y: 470 < y < 580 and xr[0] < x < xr[1] and beyond(x, y)).open(1)
    hd = C.mask(['body_d'], where=lambda x, y: 470 < y < 580 and xr[0] < x < xr[1] and beyond(x, y)).open(1)
    parts[name] = [l for l in [
        layer('body-line', hs, eps=0.6),
        layer('body', hi, eps=0.6, min_area=10),
        layer('body-light', hl, eps=0.7, min_area=25),
        layer('body-dark', hd, eps=0.7, min_area=25),
    ] if l]
    print(side, 'wrist', [round(v, 1) for v in T(P)], 'dir', round(ux, 3), round(uy, 3), 'tw', tw)

# ------------------------------------------------------------- shadow ellipse
pts = [(x, y) for y in range(660, 700) for x in range(480, 930) if C.names[C.lab[y - C.y0][x - C.x0]] == 'shadow']
xs = [p[0] for p in pts]
ys = [p[1] for p in pts]
print('shadow bbox', min(xs), min(ys), max(xs), max(ys))
rig['shadow'] = {'cx': (min(xs) + max(xs) + 1) / 2 - OX, 'cy': (min(ys) + max(ys) + 1) / 2 - OY,
                 'rx': (max(xs) - min(xs) + 1) / 2, 'ry': (max(ys) - min(ys) + 1) / 2}
rig['eyes'] = {
    'left': {'white': [646.27 - OX, 328.78 - OY, 32.0], 'pupil': [651.12 - OX, 327.99 - OY, 24.5], 'rim': [643.63 - OX, 326.74 - OY, 34.5]},
    'right': {'white': [761.94 - OX, 328.74 - OY, 32.0], 'pupil': [757.12 - OX, 328.01 - OY, 24.5], 'rim': [764.77 - OX, 326.67 - OY, 34.5]},
    'highlight': {'dx': -11, 'dy': -11, 'r': 6.5},
}
json.dump(parts, open('parts_master.json', 'w'), indent=1)
json.dump(rig, open('rig.json', 'w'), indent=1)
print(json.dumps(rig, indent=1))
