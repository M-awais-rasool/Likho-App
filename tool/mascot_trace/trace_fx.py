"""Trace the three 'z' letters from the sleepy cell of the expression sheet."""
import json
from tracelib import *
im, px = load(WORK + '/sheet.png')
rig = json.load(open('rig.json')); parts = json.load(open('parts_all.json'))
OX, OY = rig['origin']
Cl = Classifier(px, (1290, 480, 1370, 545), {'bg': ['#FFFFFF', '#FCFCFC'], 'z': ['#A8908A', '#AC948C', '#A48C84']})
m = Cl.mask(['z']).close(1); comps = []
for i in range(3):
    c = m.largest(1); comps.append(c); m = m.subtract(c)
comps.sort(key=lambda c: c.bbox()[0])
S = 1.836; band_sheet = (1292, 495); band_master = (841, 205)
T = lambda p: (band_master[0] + (p[0] - band_sheet[0]) * S - OX, band_master[1] + (p[1] - band_sheet[1]) * S - OY)
rig['fx'] = {'zzz': []}
for i, c in enumerate(comps):
    b = c.bbox()
    parts['fx_z%d' % (i + 1)] = [{'role': 'fx', 'd': mask_to_path(c, T, eps=0.5)}]
    cx, cy = T(((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)); rig['fx']['zzz'].append([round(cx, 1), round(cy, 1)])
json.dump(parts, open('parts_all.json', 'w'), indent=1); json.dump(rig, open('rig.json', 'w'), indent=1)
print(rig['fx'])
