"""Trace mouths / hands / accessories from the reference sheets into artboard-space layered parts."""
import os
import json, math, pickle, sys
from collections import Counter
from tracelib import *

MDIR = os.path.join(ROOT, '..', 'design', 'mascot') + '/'  # <repo>/design/mascot
rig = json.load(open('rig.json'))
parts = json.load(open('parts_master.json'))
C = pickle.load(open('master_cls.pkl', 'rb'))
OX, OY = rig['origin']


def xf(scale, src_anchor, dst_anchor, rot=0.0, mirror=False):
    ca, sa = math.cos(rot), math.sin(rot)

    def T(p):
        x, y = (p[0] - src_anchor[0]) * scale, (p[1] - src_anchor[1]) * scale
        if mirror:
            x = -x
        return (dst_anchor[0] + x * ca - y * sa, dst_anchor[1] + x * sa + y * ca)
    return T


def trace_roles(px, box, palette, stack, T, pad=4, grow=None, eps=0.9, min_area=12):
    """palette: role -> colours; stack: list of (role, [roles in region], opts) bottom->top.
    First entry is the silhouette (all non-bg, holes filled)."""
    x0, y0, x1, y1 = box
    Cl = Classifier(px, (x0 - pad, y0 - pad, x1 + pad, y1 + pad), palette)
    out = []
    for role, members, opt in stack:
        if members == '*':
            m = Cl.mask([n for n in Cl.names if n != 'bg']).close(1)
            if opt.get('fill_holes', True):
                m = m.fill_holes()
        else:
            m = Cl.mask(members)
            if opt.get('close'):
                m = m.close(opt['close'])
            if opt.get('open'):
                m = m.open(opt['open'])
            if opt.get('inside') is not None:
                m = m.clip(opt['inside'])
        if opt.get('grow'):
            m = m.morph(opt['grow'], True)
        if opt.get('keep'):
            m = m.largest(opt['keep'])
        d = mask_to_path(m, T, eps=opt.get('eps', eps), min_area=opt.get('min_area', min_area), smooth=opt.get('smooth', 1))
        if d:
            L = {'role': role, 'd': d}
            if opt.get('fill'):
                L['fill'] = opt['fill']
            out.append(L)
    return out, Cl


# ------------------------------------------------------------------ MOUTHS
im, px = load(MDIR + 'Gemini_Generated_Image_wv35jtwv35jtwv35.jpeg')
mouth_pal = {'bg': ['#FFFFFF', '#F8F8F8'], 'ink': ['#2D314C', '#20243D', '#242A40', '#12172B'],
             'tongue': ['#F89097', '#F68D92'], 'tline': ['#A64B54', '#A84858']}
M_BOX = {'closed_sheet': (173, 190, 350, 246), 'open_small': (470, 180, 662, 262), 'open_a': (748, 152, 986, 293),
         'o': (1116, 155, 1215, 274), 'yawn': (1084, 440, 1248, 662), 'ee': (130, 497, 395, 602),
         'laugh': (442, 475, 694, 628), 'gentle': (778, 521, 952, 576)}
# master closed mouth geometry (artboard) for scale/anchor
mm = C.mask(['mouth'], where=lambda x, y: 350 < y < 390 and 660 < x < 750).largest()
mb = mm.bbox()
m_w = mb[2] - mb[0] + 1
m_anchor = ((mb[0] + mb[2] + 1) / 2 - OX, mb[1] - OY)          # top-centre of the smile
sheet_closed_w = 350 - 173
# the sheet's closed mouth has dimple ticks; its arc (without ticks) is ~0.83 of the box width
S_MOUTH = m_w / (sheet_closed_w * 0.83)
print('master mouth bbox', mb, 'scale', round(S_MOUTH, 3), 'anchor', m_anchor)
rig['mouth'] = {'anchor': m_anchor, 'scale_from_sheet': S_MOUTH}
for name, b in M_BOX.items():
    anchor = ((b[0] + b[2]) / 2, b[1])
    T = xf(S_MOUTH, anchor, m_anchor)
    stack = [('mouth', '*', {}),
             ('mouth-teeth', ['bg'], {'inside': None}),
             ('tongue-line', ['tongue', 'tline'], {'close': 1}),
             ('tongue', ['tongue'], {'open': 1})]
    # teeth = background pixels enclosed by the ink silhouette
    x0, y0, x1, y1 = b
    Cl = Classifier(px, (x0 - 4, y0 - 4, x1 + 4, y1 + 4), mouth_pal)
    sil = Cl.mask(['ink', 'tongue', 'tline']).close(1)
    filled = sil.fill_holes()
    teeth = filled.subtract(sil).open(1)
    layers = []
    for role, m, kw in (('mouth', filled, {}), ('mouth-teeth', teeth, {'min_area': 20}),
                        ('tongue-line', Cl.mask(['tongue', 'tline']).close(1), {'min_area': 20}),
                        ('tongue', Cl.mask(['tongue']).open(1), {'min_area': 20})):
        d = mask_to_path(m, T, eps=0.8, **kw)
        if d:
            layers.append({'role': role, 'd': d})
    parts['mouth_' + name] = layers
    print('mouth', name, [l['role'] for l in layers])

# ------------------------------------------------------------------ HANDS
im, px = load(MDIR + 'Gemini_Generated_Image_o92wdho92wdho92w.jpeg')
hand_pal = {'bg': ['#FFFFFF', '#F8F8F8', '#F8F8E8'], 'line': ['#C88828', '#B87828', '#C87828', '#A87838', '#B88838'],
            'fill': ['#F8C848', '#F8C858', '#F8B848'], 'light': ['#F8D878', '#F8D868'], 'dark': ['#F8A838', '#E8A838', '#F8A848'],
            'star': ['#F8D848', '#FFD940']}
# wrist stubs measured on the sheet: (end point of the sleeve/stub, direction into the hand, mirrored?)
# canonical orientation = the screen-RIGHT hand; mirror=True flips sheet art that is drawn as a left hand
H_BOX = {
    'open': ((165, 89, 374, 355), (250, 330), (0, -1), True),
    'wave': ((591, 81, 830, 364), (680, 262), (0.62, -0.78), False),
    'thumbs_up': ((1069, 91, 1275, 311), (1100, 250), (1, 0), False),
    'point': ((123, 492, 401, 670), (160, 585), (1, 0), False),
    'fist': ((597, 487, 819, 668), (630, 605), (1, 0), False),
    'star': ((1021, 460, 1290, 684), (1068, 640), (0.97, -0.24), False),
}
OVERLAP = 4.0
R = rig['arms']['R']
W_R = R['W']
tan = R['tangent']
# scale: master rest-hand length (wrist -> fingertip) vs sheet open-hand length (stub end -> middle fingertip)
rest = C.mask(['body', 'body_l', 'body_d', 'body_line'], where=lambda x, y: 488 < y < 575 and 850 < x < 930)
rb = rest.bbox()
master_hand_len = rb[3] - (W_R[1] + OY)
S_HAND = 1.2 * master_hand_len / (330 - 89)   # x1.2: match the master mitten's palm width
print('hand scale', round(S_HAND, 3), 'master hand len', master_hand_len)
rig['hand_scale_from_sheet'] = S_HAND
for name, (b, stub, d, mirror) in H_BOX.items():
    # rotate so that sheet direction d maps onto the right arm's rest tangent
    ang_src = math.atan2(d[1], d[0])
    if mirror:
        ang_src = math.atan2(d[1], -d[0])
    ang_dst = math.atan2(tan[1], tan[0])
    T = xf(S_HAND, stub, W_R, rot=ang_dst - ang_src, mirror=mirror)
    x0, y0, x1, y1 = b
    Cl = Classifier(px, (x0 - 4, y0 - 4, x1 + 4, y1 + 4), hand_pal)
    star_zone = (lambda x, y: y < 560 and x > 1140) if name == 'star' else (lambda x, y: False)
    dn = math.hypot(*d)
    ux, uy = d[0] / dn, d[1] / dn
    hand_only = lambda x, y: (not star_zone(x, y)) and ((x - stub[0]) * ux + (y - stub[1]) * uy > -OVERLAP / S_HAND)
    sil = Cl.mask(['line', 'fill', 'light', 'dark', 'star']).clip(hand_only).close(1).fill_holes().largest()
    inner = Cl.mask(['fill', 'light', 'dark', 'star']).clip(hand_only)
    layers = []
    for role, m, kw in (('body-line', sil, {}), ('body', inner, {'min_area': 15}),
                        ('body-light', Cl.mask(['light']).clip(hand_only).open(1), {'min_area': 30}),
                        ('body-dark', Cl.mask(['dark']).clip(hand_only).open(1), {'min_area': 30})):
        dd = mask_to_path(m, T, eps=0.8, **kw)
        if dd:
            layers.append({'role': role, 'd': dd})
    if name == 'star':
        ssil = Cl.mask(['line', 'fill', 'light', 'dark', 'star']).clip(star_zone).close(1).fill_holes().largest()
        sin_ = Cl.mask(['fill', 'light', 'star']).clip(star_zone).largest()
        layers.append({'role': 'star-line', 'd': mask_to_path(ssil, T, eps=0.7), 'fill': '#C88828'})
        layers.append({'role': 'star', 'd': mask_to_path(sin_, T, eps=0.7), 'fill': '#FFD23F'})
    parts['hand_' + name] = layers
    print('hand', name, [l['role'] for l in layers])

json.dump(parts, open('parts_all.json', 'w'), indent=1)
json.dump(rig, open('rig.json', 'w'), indent=1)
