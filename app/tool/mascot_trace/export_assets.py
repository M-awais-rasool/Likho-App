"""Write assets/mascot/*.svg (artboard-space layered parts) + assets/reference/*.png overlays."""
import json, os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MDIR = os.path.join(ROOT, '..', 'design', 'mascot') + '/'  # <repo>/design/mascot
OUT = ROOT + '/assets/mascot'
REF = ROOT + '/assets/reference'
os.makedirs(OUT + '/accessories', exist_ok=True)
os.makedirs(OUT + '/fx', exist_ok=True)
os.makedirs(REF, exist_ok=True)
parts = json.load(open('parts_all.json'))
rig = json.load(open('rig.json'))

# default (yellow master) colours per role — the app maps class names to its palette
ROLE = {'eraser-line': '#CF6168', 'eraser': '#FC999C', 'eraser-shade': '#F18087', 'band-line': '#8898A6', 'band': '#CBD3DC',
        'band-shade': '#B6C1CC', 'band-hi': '#E8EEF6', 'body-line': '#C27A28', 'body': '#FEC344', 'body-light': '#FBD065',
        'body-dark': '#F5AA36', 'cone-line': '#BC7540', 'cone': '#ECB57D', 'cone-light': '#F4CA98', 'cone-dark': '#DB9A67',
        'graphite': '#323447', 'brow': '#9B5618', 'cheek': '#F78A5C', 'mouth': '#6E3227', 'mouth-teeth': '#FFFFFF',
        'tongue': '#EF8882', 'tongue-line': '#B8545A', 'fx': '#A8908A'}

FILES = {
    'body.svg': ['body'], 'eraser.svg': ['eraser'], 'cone.svg': ['cone'],
    'leg_left.svg': ['leg_left'], 'leg_right.svg': ['leg_right'],
    'cheek.svg': ['cheek_left', 'cheek_right'], 'brow_left.svg': ['brow_left'], 'brow_right.svg': ['brow_right'],
    'mouth_closed.svg': ['mouth_closed'], 'mouth_open_small.svg': ['mouth_open_small'], 'mouth_open_a.svg': ['mouth_open_a'],
    'mouth_o.svg': ['mouth_o'], 'mouth_ee.svg': ['mouth_ee'], 'mouth_laugh.svg': ['mouth_laugh'],
    'mouth_gentle.svg': ['mouth_gentle'], 'mouth_yawn.svg': ['mouth_yawn'],
    'hand_rest_left.svg': ['hand_rest_left'], 'hand_rest_right.svg': ['hand_rest_right'],
    'hand_open.svg': ['hand_open'], 'hand_wave.svg': ['hand_wave'], 'hand_thumbs_up.svg': ['hand_thumbs_up'],
    'hand_point.svg': ['hand_point'], 'hand_fist.svg': ['hand_fist'], 'hand_star.svg': ['hand_star'],
    'accessories/cap.svg': ['acc_cap'], 'accessories/wizard_hat.svg': ['acc_wizard'], 'accessories/party_hat.svg': ['acc_party'],
    'accessories/round_glasses.svg': ['acc_round'], 'accessories/star_glasses.svg': ['acc_stars'], 'accessories/cape.svg': ['acc_cape'],
    'accessories/scarf.svg': ['acc_scarf'], 'accessories/crown.svg': ['acc_crown'], 'accessories/headphones.svg': ['acc_phones'],
    'accessories/bow.svg': ['acc_bowtie'],
    'fx/zzz_1.svg': ['fx_z1'], 'fx/zzz_2.svg': ['fx_z2'], 'fx/zzz_3.svg': ['fx_z3'],
}
HEADER = ('<!-- Likho "Pencil" mascot part. Traced from the master art in mascot\'s/ (Gemini_Generated_Image_*).\n'
          '     Artboard 500x680 = master image px (x-454, y-36). Every part is drawn in its rest position.\n'
          '     class = colour role (body* roles are recoloured by setBodyColor); paths without class use their fill. -->\n')
for fn, names in FILES.items():
    out = [HEADER, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 680" width="500" height="680">']
    for n in names:
        out.append('  <g id="%s">' % n)
        for l in parts[n]:
            if l['role'] in ROLE and not l.get('fill'):
                out.append('    <path class="%s" fill="%s" fill-rule="evenodd" d="%s"/>' % (l['role'], ROLE[l['role']], l['d']))
            else:
                out.append('    <path fill="%s" fill-rule="evenodd" d="%s"/>' % (l.get('fill') or ROLE[l['role']], l['d']))
        out.append('  </g>')
    out.append('</svg>\n')
    open(os.path.join(OUT, fn), 'w').write('\n'.join(out))
print('wrote', len(FILES), 'svg files')


def white_to_alpha(im, lo=236, hi=252):
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            m = min(r, g, b)
            if m >= hi:
                px[x, y] = (r, g, b, 0)
            elif m >= lo:
                px[x, y] = (r, g, b, int(255 * (hi - m) / (hi - lo)))
    return im


OX, OY = rig['origin']
master = Image.open(MDIR + 'Gemini_Generated_Image_ic1bzvic1bzvic1b.jpeg').convert('RGB')
white_to_alpha(master.crop((OX, OY, OX + 500, OY + 680))).save(REF + '/master_idle.png', optimize=True)
cap = Image.open(MDIR + 'Gemini_Generated_Image_4cnmtm4cnmtm4cnm.jpeg').convert('RGB')
white_to_alpha(cap.crop((OX, OY, OX + 500, OY + 680))).save(REF + '/accessory_cap.png', optimize=True)

# expression sheet cells -> artboard space. One scale for the whole sheet (from the idle cell's
# eraser-top -> shadow-bottom height), each cell pinned to the ground at its shadow centre.
sheet = Image.open(MDIR + 'Gemini_Generated_Image_y5imh7y5imh7y5im.jpeg').convert('RGB')
sp = sheet.load()
cells = ['idle', 'talking', 'watching', 'happy', 'encourage', 'wow', 'dance', 'sleepy']


def cell_marks(i):
    cx0, cy0 = (i % 4) * 352, (i // 4) * 384
    er, sh = [], []
    for y in range(cy0, cy0 + 384):
        for x in range(cx0, cx0 + 352):
            r, g, b = sp[x, y]
            if r > 225 and 110 < g < 175 and 120 < b < 185 and r - g > 60:
                er.append((x, y))
            if 212 < r < 240 and 212 < g < 240 and 218 < b < 245 and b >= r and y > cy0 + 250:
                sh.append((x, y))
    shx = [p[0] for p in sh]
    return min(p[1] for p in er), (min(shx) + max(shx)) / 2, max(p[1] for p in sh)


M_ERASER_TOP, M_GROUND, M_CX = 86, 692, 704
top0, _, g0 = cell_marks(0)
S = (M_GROUND - M_ERASER_TOP) / (g0 - top0)
rig['sheet_to_master_scale'] = S
print('sheet->master scale', round(S, 3))
for i, name in enumerate(cells):
    top, gx, gy = cell_marks(i)
    a = 1 / S
    c = gx + (OX - M_CX) / S
    f = gy + (OY - M_GROUND) / S
    im = sheet.transform((500, 680), Image.AFFINE, (a, 0, c, 0, a, f), resample=Image.BICUBIC, fillcolor=(255, 255, 255))
    white_to_alpha(im).save(REF + '/sheet_%s.png' % name, optimize=True)
    print(name, 'ground', round(gx, 1), gy)
json.dump(rig, open('rig.json', 'w'), indent=1)
