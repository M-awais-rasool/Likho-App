"""Compose the idle pose (traced parts + procedural noodle arms + code eyes) to SVG/PNG and diff with the master."""
from tracelib import WORK
import json, math, subprocess, sys
from PIL import Image, ImageChops, ImageStat
from render_parts import ROLE

parts = json.load(open('parts_master.json'))
rig = json.load(open('rig.json'))
ROLE.update({'eye-rim': '#A05C1B', 'eye-white': '#FFFFFF', 'pupil': '#2A2E4A'})

LINE = 4.6
HK = [(0, 29), (0.2, 24), (0.35, 20.2), (0.65, 20.0), (1.0, 21.5)]


def hw(s):
    for (a, ha), (b, hb) in zip(HK, HK[1:]):
        if s <= b:
            return ha + (hb - ha) * (s - a) / (b - a)
    return HK[-1][1]


def bez(S, Cc, W, t):
    u = 1 - t
    return (u * u * S[0] + 2 * u * t * Cc[0] + t * t * W[0], u * u * S[1] + 2 * u * t * Cc[1] + t * t * W[1])


def dbez(S, Cc, W, t):
    u = 1 - t
    return (2 * u * (Cc[0] - S[0]) + 2 * t * (W[0] - Cc[0]), 2 * u * (Cc[1] - S[1]) + 2 * t * (W[1] - Cc[1]))


def band(S, Cc, W, outer_sign, off0, off1, s0=0.0, s1=1.0, caps=False, n=48):
    """polygon between offsets off0..off1 (signed, along the outer normal) for s in [s0,s1]"""
    A, B = [], []
    for i in range(n + 1):
        s = s0 + (s1 - s0) * i / n
        x, y = bez(S, Cc, W, s)
        dx, dy = dbez(S, Cc, W, s)
        L = math.hypot(dx, dy)
        nx, ny = -dy / L * outer_sign, dx / L * outer_sign
        h = hw(s)
        o0, o1 = off0(h), off1(h)
        A.append((x + nx * o0, y + ny * o0))
        B.append((x + nx * o1, y + ny * o1))
    pts = A + B[::-1]
    return 'M' + ' L'.join('%.2f %.2f' % p for p in pts) + 'Z'


def arm_svg(side):
    a = rig['arms'][side]
    S, Cc, W = a['S'], a['C'], a['W']
    sg = 1 if side == 'L' else -1
    out = []
    out.append(('body-line', band(S, Cc, W, sg, lambda h: h, lambda h: -h)))
    for p, r in ((S, hw(0)), (W, hw(1))):
        out.append(('body-line', 'M%.2f %.2f m-%.2f 0 a%.2f %.2f 0 1 0 %.2f 0 a%.2f %.2f 0 1 0 -%.2f 0Z' % (p[0], p[1], r, r, r, 2 * r, r, r, 2 * r)))
    out.append(('body', band(S, Cc, W, sg, lambda h: h - LINE, lambda h: -(h - LINE))))
    out.append(('body-light', band(S, Cc, W, sg, lambda h: h - LINE, lambda h: h - LINE - 7.5, 0.12, 1.0)))
    out.append(('body-dark', band(S, Cc, W, sg, lambda h: -(h - LINE), lambda h: -(h - LINE - 5.5), 0.2, 1.0)))
    return out


def circle(cx, cy, r):
    return 'M%.2f %.2f m-%.2f 0 a%.2f %.2f 0 1 0 %.2f 0 a%.2f %.2f 0 1 0 -%.2f 0Z' % (cx, cy, r, r, r, 2 * r, r, r, 2 * r)


def eyes_svg():
    out = []
    hl = rig['eyes']['highlight']
    for k in ('left', 'right'):
        e = rig['eyes'][k]
        out.append(('eye-rim', circle(*e['rim'])))
        out.append(('eye-white', circle(*e['white'])))
        out.append(('pupil', circle(*e['pupil'])))
        out.append(('eye-white', circle(e['pupil'][0] + hl['dx'], e['pupil'][1] + hl['dy'], hl['r'])))
    return out


def compose():
    L = []
    sh = rig['shadow']
    L.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#E5E5EB"/>' % (sh['cx'], sh['cy'], sh['rx'], sh['ry']))

    def P(role, d):
        L.append('<path fill="%s" fill-rule="evenodd" d="%s"/>' % (ROLE[role], d))

    def part(n):
        for l in parts[n]:
            P(l['role'], l['d'])
    part('leg_left'); part('leg_right')
    for r, d in arm_svg('L'): P(r, d)
    for r, d in arm_svg('R'): P(r, d)
    for n in ('body', 'cone', 'eraser', 'cheek_left', 'cheek_right'):
        part(n)
    for r, d in eyes_svg(): P(r, d)
    for n in ('brow_left', 'brow_right', 'mouth_closed', 'hand_rest_left', 'hand_rest_right'):
        part(n)
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 680" width="500" height="680">' + '\n'.join(L) + '</svg>'


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else WORK + '/compose'
    open(out + '.svg', 'w').write(compose())
    subprocess.run(['rsvg-convert', '-b', 'white', out + '.svg', '-o', out + '.png'], check=True)
    a = Image.open(out + '.png').convert('RGB')
    m = Image.open(WORK + '/master.png').crop((454, 36, 954, 716))
    diff = ImageChops.difference(a, m)
    st = ImageStat.Stat(diff)
    print('mean abs diff per channel', [round(v, 2) for v in st.mean])
    # fraction of pixels differing by > 40 in any channel
    dp = diff.load()
    big = sum(1 for y in range(680) for x in range(500) if max(dp[x, y]) > 40)
    print('pixels off by >40:', big, '(%.2f%%)' % (100 * big / (500 * 680)))
    Image.blend(m, a, 0.5).save(out + '_blend.png')
    side = Image.new('RGB', (1000, 680), 'white'); side.paste(m, (0, 0)); side.paste(a, (500, 0)); side.save(out + '_side.png')
    diff.point(lambda v: min(255, v * 3)).save(out + '_diff.png')
