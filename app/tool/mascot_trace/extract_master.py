"""Trace the Pencil master image into layered part definitions (parts.json)."""
import json, math, pickle
from tracelib import *

C = pickle.load(open('master_cls.pkl', 'rb'))
OX, OY = 454, 36          # master px -> artboard units (artboard 500 x 680)
T = lambda p: (p[0] - OX, p[1] - OY)

BODY = ['body', 'body_l', 'body_d']
BODYF = BODY + ['body_line']
parts = {}


def layer(role, mask, **kw):
    d = mask_to_path(mask, T, **kw)
    return {'role': role, 'd': d} if d else None


def add(name, layers):
    parts[name] = [l for l in layers if l]


# ---------------------------------------------------------------- eraser + band
er_all = C.mask(['er_fill', 'er_shade', 'er_line'], where=lambda x, y: y < 200 and 576 < x < 832).open(1)
er_sil = er_all.close(2).fill_holes().largest()
band_all = C.mask(['band', 'band_hi', 'band_sh', 'band_line'], where=lambda x, y: 170 < y < 240 and 560 < x < 848)
band_sil = band_all.close(2).fill_holes().largest()
# eraser continues under the band (hidden) so the eraser can bob independently
er_ext = er_sil.union(band_sil.clip(lambda x, y: y < 200 and 579 < x < 829))
er_int = C.mask(['er_fill', 'er_shade'], where=lambda x, y: y < 200).close(1).largest()
er_int = er_int.union(band_sil.clip(lambda x, y: y < 200 and 585 < x < 823)).fill_holes()
er_shade = C.mask(['er_shade'], where=lambda x, y: y < 185 and 580 < x < 830).open(1)
band_int = C.mask(['band', 'band_hi', 'band_sh'], where=lambda x, y: 170 < y < 240 and 560 < x < 848).close(1).fill_holes().largest()
band_hi = C.mask(['band_hi'], where=lambda x, y: 180 < y < 215 and 580 < x < 700).open(1).largest()
band_sh = C.mask(['band_sh'], where=lambda x, y: 170 < y < 240 and 740 < x < 848).open(1)
add('eraser', [
    layer('eraser-line', er_ext, eps=0.35, poly=True),
    layer('eraser', er_int, eps=0.35, poly=True),
    layer('eraser-shade', er_shade, eps=0.35, min_area=60, poly=True),
    layer('band-line', band_sil),
    layer('band', band_int, eps=0.7),
    layer('band-shade', band_sh, eps=0.8, min_area=40),
    layer('band-hi', band_hi, eps=0.6, min_area=20),
])

# ---------------------------------------------------------------- body
BODY_X0, BODY_X1 = 574, 834
body_vis = C.mask(BODYF, where=lambda x, y: 205 < y < 520 and BODY_X0 - 3 < x < BODY_X1 + 3)
# body extends up under the band and down under the cone (hidden in the master)
cone_all = C.mask(['cone_l', 'cone_m', 'cone_d', 'cone_line', 'graph'], where=lambda x, y: 480 < y < 660 and 560 < x < 850)
cone_sil = cone_all.close(2).fill_holes().largest()
_scallop = C.mask(['body_line', 'cone_line', 'brow'], where=lambda x, y: 488 < y < 535 and 574 < x < 834)
cone_sil = cone_sil.union(_scallop.clip(lambda x, y: True)).union(cone_sil.morph(4, True).clip(lambda x, y: y < 540 and 575 < x < 833 and C.names[C.lab[y - C.y0][x - C.x0]] not in ('bg', 'body', 'body_l', 'body_d'))).close(2).fill_holes().largest()
body_sil = body_vis.union(band_sil.clip(lambda x, y: y > 195 and BODY_X0 < x < BODY_X1))
body_sil = body_sil.union(cone_sil.clip(lambda x, y: y < 530 and BODY_X0 < x < BODY_X1))
body_sil = body_sil.close(2).fill_holes().largest()
# interior: everything inside the body outline stroke
body_int = C.mask(BODY + ['brow', 'cheek', 'mouth', 'bg', 'graph'], where=lambda x, y: 205 < y < 520 and BODY_X0 + 2 < x < BODY_X1 - 2)
body_int = body_int.union(band_sil.clip(lambda x, y: y > 195 and BODY_X0 + 6 < x < BODY_X1 - 6))
body_int = body_int.union(cone_sil.clip(lambda x, y: y < 526 and BODY_X0 + 6 < x < BODY_X1 - 6))
body_int = body_int.close(2).fill_holes().largest()
face = lambda x, y: not (600 < x < 810 and 255 < y < 395)
body_l = C.mask(['body_l'], where=lambda x, y: 214 < y < 515 and BODY_X0 < x < 650).open(1).largest()
body_d = C.mask(['body_d'], where=lambda x, y: 214 < y < 515 and 755 < x < BODY_X1).open(1).largest()
add('body', [
    layer('body-line', body_sil),
    layer('body', body_int),
    layer('body-light', body_l.close(3).fill_holes(), eps=0.8),
    layer('body-dark', body_d.close(3).fill_holes(), eps=0.8),
])

# ---------------------------------------------------------------- cone + graphite
cone_int = C.mask(['cone_l', 'cone_m', 'cone_d'], where=lambda x, y: 480 < y < 660 and 560 < x < 850).close(1).largest()
cone_l = C.mask(['cone_l'], where=lambda x, y: 480 < y < 660).open(1).largest()
cone_d = C.mask(['cone_d'], where=lambda x, y: 480 < y < 660).open(1).largest()
graph = C.mask(['graph'], where=lambda x, y: 590 < y < 660 and 650 < x < 760).close(1).fill_holes().largest()
add('cone', [
    layer('cone-line', cone_sil),
    layer('cone', cone_int, eps=0.7),
    layer('cone-light', cone_l, eps=0.7, corner_deg=40),
    layer('cone-dark', cone_d, eps=0.7, corner_deg=40),
    layer('graphite', graph, eps=0.7, corner_deg=40),
])

# ---------------------------------------------------------------- legs
def leg(x0, x1, name):
    vis = C.mask(BODYF, where=lambda x, y: 540 < y < 690 and x0 < x < x1)
    vis = vis.subtract(cone_sil)
    # extend the leg up to the hip, hidden behind the cone
    ext = C.mask(BODYF + ['cone_l', 'cone_m', 'cone_d', 'cone_line', 'graph'],
                 where=lambda x, y: 548 < y < 600 and x0 < x < x1)
    sil = vis.union(ext.clip(lambda x, y: True)).close(2).fill_holes().largest()
    inner = C.mask(BODY, where=lambda x, y: 540 < y < 690 and x0 < x < x1).subtract(cone_sil).largest()
    return sil, inner


legL_sil, legL_int = leg(575, 662, 'leg_left')
legR_sil, legR_int = leg(745, 832, 'leg_right')
pickle.dump({'cone_sil': cone_sil, 'body_sil': body_sil}, open('masks.pkl', 'wb'))
add('leg_left', [layer('body-line', legL_sil), layer('body', legL_int, eps=0.7)])
add('leg_right', [layer('body-line', legR_sil), layer('body', legR_int, eps=0.7)])

# ---------------------------------------------------------------- face features
browL = C.mask(['brow'], where=lambda x, y: 255 < y < 285 and 600 < x < 690).largest()
browR = C.mask(['brow'], where=lambda x, y: 255 < y < 285 and 715 < x < 810).largest()
add('brow_left', [layer('brow', browL, eps=0.5)])
add('brow_right', [layer('brow', browR, eps=0.5)])
cheekL = C.mask(['cheek'], where=lambda x, y: 355 < y < 395 and x < 700).close(1).largest()
cheekR = C.mask(['cheek'], where=lambda x, y: 355 < y < 395 and x > 700).close(1).largest()
add('cheek_left', [layer('cheek', cheekL, eps=0.5)])
add('cheek_right', [layer('cheek', cheekR, eps=0.5)])
mouth = C.mask(['mouth'], where=lambda x, y: 350 < y < 390 and 660 < x < 750).close(1).largest()
add('mouth_closed', [layer('mouth', mouth, eps=0.4, smooth=1)])

json.dump(parts, open('parts_master.json', 'w'), indent=1)
for k, v in parts.items():
    print(k, [(l['role'], len(l['d'])) for l in v])
