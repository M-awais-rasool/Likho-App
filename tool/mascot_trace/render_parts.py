import json, sys, subprocess
ROLE = {'eraser-line':'#CF6168','eraser':'#FC999C','eraser-shade':'#F18087','band-line':'#8898A6','band':'#CBD3DC','band-shade':'#B6C1CC','band-hi':'#E8EEF6',
 'body-line':'#C27A28','body':'#FEC344','body-light':'#FBD065','body-dark':'#F5AA36','cone-line':'#BC7540','cone':'#ECB57D','cone-light':'#F4CA98','cone-dark':'#DB9A67',
 'graphite':'#323447','brow':'#9B5618','cheek':'#F78A5C','mouth':'#6E3227','shadow':'#E5E5EB'}
def svg(parts, order, w=500, h=680, extra=''):
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">']
    for n in order:
        for l in parts.get(n, []):
            out.append(f'<path fill="{ROLE.get(l["role"], l.get("fill","#f0f"))}" fill-rule="evenodd" d="{l["d"]}"/>')
    out.append(extra+'</svg>'); return '\n'.join(out)
if __name__=='__main__':
    parts=json.load(open(sys.argv[1])); order=sys.argv[2].split(','); o=sys.argv[3]
    open(o+'.svg','w').write(svg(parts, order))
    subprocess.run(['rsvg-convert','-b','white',o+'.svg','-o',o+'.png'],check=True)
