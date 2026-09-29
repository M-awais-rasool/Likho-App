# grid-search eye geometry against the master (supersampled PIL drawing)
from PIL import Image, ImageDraw, ImageChops, ImageStat
import itertools, json
m=Image.open(WORK + '/master.png').convert('RGB')
SS=4
def render(cx,cy, rim, white, pupil, hl, side):
    # region 90x90 around the white centre
    x0,y0=int(cx-45),int(cy-45)
    im=Image.new('RGB',(90*SS,90*SS),(0xFE,0xC3,0x44)); d=ImageDraw.Draw(im)
    def circ(c,r,col):
        X=(c[0]-x0)*SS; Y=(c[1]-y0)*SS; R=r*SS; d.ellipse((X-R,Y-R,X+R,Y+R),fill=col)
    circ(rim[:2],rim[2],(0xA0,0x5C,0x1B)); circ((cx,cy),white,(255,255,255)); circ(pupil[:2],pupil[2],(0x2A,0x2E,0x4A)); circ(hl[:2],hl[2],(255,255,255))
    return im.resize((90,90),Image.LANCZOS),(x0,y0)
def score(img,org):
    ref=m.crop((org[0],org[1],org[0]+90,org[1]+90))
    # mask: only pixels within 36px of centre
    df=ImageChops.difference(img,ref).convert('L'); px=df.load(); s=0;n=0
    for y in range(90):
        for x in range(90):
            if (x-45)**2+(y-45)**2<36*36: s+=px[x,y]; n+=1
    return s/n
res={}
for side,(wx,wy,px_,py_,rx,ry) in {'L':(646.27,328.78,651.12,327.99,643.63,326.74),'R':(761.94,328.74,757.12,328.01,764.77,326.67)}.items():
    best=(1e9,None)
    for wr in (31.0,31.5,32.0):
        for pr in (23.0,23.5,24.0,24.5):
            for hr in (5.5,6.0,6.5,7.0):
                for hd in (9.0,10.0,11.0):
                    for rr in (34.0,34.5,35.0):
                        img,org=render(wx,wy,(rx,ry,rr),wr,(px_,py_,pr),(px_-hd,py_-hd,hr),side)
                        sc=score(img,org)
                        if sc<best[0]: best=(sc,(wr,pr,hr,hd,rr))
    print(side,'best',best)
    res[side]=best[1]
json.dump(res,open('eyes_fit.json','w'))
