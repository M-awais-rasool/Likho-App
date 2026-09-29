"""Trace the 10 accessories into artboard space (literal colours, not recoloured)."""
import os
import json, math, random
from tracelib import *

MDIR = os.path.join(ROOT, "mascot's") + "/"
rig = json.load(open('rig.json'))
parts = json.load(open('parts_all.json'))
OX, OY = rig['origin']
random.seed(7)


def kmeans(cols, k, iters=12):
    cents = random.sample(cols, k)
    for _ in range(iters):
        groups = [[] for _ in range(k)]
        for c in cols:
            i = min(range(k), key=lambda j: dist2(c, cents[j]))
            groups[i].append(c)
        cents = [tuple(sum(v[t] for v in g) / len(g) for t in range(3)) if g else cents[i] for i, g in enumerate(groups)]
    return [(tuple(int(round(v)) for v in c), len(g)) for c, g in zip(cents, groups)]


def trace_object(px, box, k, T, region=None, min_area=18, eps=0.8, drop_small=40, merge=26, holes=False):
    x0, y0, x1, y1 = box
    cols = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if region and not region(x, y):
                continue
            c = px[x, y]
            if min(c) < 236:
                cols.append(c)
    sample = random.sample(cols, min(len(cols), 6000))
    cents = kmeans(sample, k)
    # merge near-duplicate clusters
    pal = []
    for c, n in sorted(cents, key=lambda t: -t[1]):
        if n < 25:
            continue
        if any(max(abs(c[i] - p[i]) for i in range(3)) < merge for p, _ in pal):
            continue
        pal.append((c, n))
    palette = {'bg': ['#FFFFFF', '#F8F8F8', '#FCFCFC']}
    for i, (c, n) in enumerate(pal):
        palette['c%d' % i] = '#%02X%02X%02X' % c
    Cl = Classifier(px, (x0 - 3, y0 - 3, x1 + 3, y1 + 3), palette)
    names = [n for n in Cl.names if n != 'bg']
    inreg = (lambda x, y: region(x, y)) if region else (lambda x, y: True)
    sil = Cl.mask(names, where=inreg).close(1)
    sil = (sil if holes else sil.fill_holes()).largest()
    # outline colour = darkest cluster
    lum = lambda h: sum(hexrgb(h)[i] * w for i, w in enumerate((0.3, 0.59, 0.11)))
    dark = min(names, key=lambda n: lum(palette[n]))
    layers = [{'role': 'acc', 'fill': palette[dark], 'd': mask_to_path(sil, T, eps=eps)}]
    areas = sorted(((Cl.mask([n], where=inreg).area(), n) for n in names if n != dark), reverse=True)
    for a, n in areas:
        if a < drop_small:
            continue
        m = Cl.mask([n], where=inreg).open(1)
        d = mask_to_path(m, T, eps=eps, min_area=min_area)
        if d:
            layers.append({'role': 'acc', 'fill': palette[n], 'd': d})
    return layers


def place(scale, src_anchor, dst_master):
    dst = (dst_master[0] - OX, dst_master[1] - OY)
    return lambda p: (dst[0] + (p[0] - src_anchor[0]) * scale, dst[1] + (p[1] - src_anchor[1]) * scale)


acc_meta = {}
# ---- cap: traced in place from 4cnmtm (same framing as the master)
im, px = load(MDIR + 'Gemini_Generated_Image_4cnmtm4cnmtm4cnm.jpeg')
reds = lambda x, y: (px[x, y][0] - max(px[x, y][1], px[x, y][2]) > 45) or y < 238
capreg = lambda x, y: y < 268 and 555 < x < 860 and min(px[x, y]) < 236 and (reds(x, y) or y < 245)
parts['acc_cap'] = trace_object(px, (555, 55, 860, 268), 7, lambda p: (p[0] - OX, p[1] - OY), region=capreg)
acc_meta['cap'] = {'layer': 'front', 'hides': ['eraser'], 'source': 'traced in place from 4cnmtm (reference placement)'}

im, px = load(MDIR + 'Gemini_Generated_Image_9skjh99skjh99skj.jpeg')
B = {'cap': (52, 115, 298, 282), 'wizard': (344, 94, 594, 297), 'party': (658, 78, 802, 320), 'round': (848, 169, 1107, 249),
     'stars': (1147, 158, 1354, 255), 'cape': (348, 445, 612, 682), 'scarf': (81, 459, 281, 665), 'crown': (649, 507, 811, 617),
     'phones': (862, 460, 1103, 667), 'bowtie': (1162, 522, 1335, 614)}
# placements (master px). ONLY the cap has a reference placement; the rest are marked as placeholders.
P = {
    'wizard': ((469, 262), (704, 104), 1.00, 6, 'front', 'placeholder: brim sits on the eraser top', None),
    'party': ((730, 268), (704, 97), 0.80, 7, 'front', 'placeholder: sits on the eraser top; elastic strap removed', lambda x, y: y < 283),
    'round': ((977, 208), (704, 329), 1.217, 4, 'front', 'lens centres on the eye centres (measured)', None),
    'stars': ((1250, 205), (704, 329), 1.05, 5, 'front', 'star lenses centred on the eyes (measured)', None),
    'cape': ((480, 455), (704, 238), 1.22, 5, 'back', 'placeholder: hangs from the band behind the body', None),
    'scarf': ((181, 490), (704, 402), 1.30, 6, 'front', 'placeholder: below the cheeks, same spot as the HTML prototype scarf', None),
    'crown': ((730, 605), (704, 100), 0.95, 6, 'front', 'placeholder: sits on the eraser top', None),
    'phones': ((982, 465), (704, 5), 1.62, 6, 'front', 'placeholder: cups over the band ends, headband over the eraser', None),
    'bowtie': ((1248, 568), (806, 104), 0.62, 6, 'front', 'placeholder: on the eraser top-right, like the HTML prototype bow', None),
}
for k, (sa, dm, sc, kk, lay, note, reg) in P.items():
    parts['acc_' + k] = trace_object(px, B[k], kk, place(sc, sa, dm), region=reg, holes=(k == 'round'))
    acc_meta[k] = {'layer': lay, 'source': note}
    print(k, len(parts['acc_' + k]), 'layers')
rig['accessories'] = acc_meta
json.dump(parts, open('parts_all.json', 'w'), indent=1)
json.dump(rig, open('rig.json', 'w'), indent=1)
