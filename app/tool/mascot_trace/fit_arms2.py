import math, json
exec(open('fit_arms.py').read().split('res={}')[0])
from PIL import Image, ImageDraw
def closest_t(pt,S,Cc,W):
    best=(1e9,0)
    for i in range(201):
        t=i/200; x,y=bez(S,Cc,W,t); d=math.hypot(pt[0]-x,pt[1]-y)
        if d<best[0]: best=(d,t)
    return best
res={}
im=Image.open(WORK + '/master.png').convert('RGB'); dr=ImageDraw.Draw(im)
for side in 'LR':
    outer,inner=edges(side)
    oy={p[1]:p[0] for p in outer}; iy={p[1]:p[0] for p in inner}
    centres=[((oy[y]+iy[y])/2,y) for y in sorted(iy) if y in oy and y>431]
    S=(592,404) if side=='L' else (816,404)
    def f(p):
        Cc=(p[0],p[1]);W=(p[2],p[3])
        return sum(closest_t(c,S,Cc,W)[0]**2 for c in centres[::2])
    x0=[545,440,524,494] if side=='L' else [863,440,884,494]
    best,val=nm(f,x0,[10,10,5,5],600)
    Cc=(best[0],best[1]);W=(best[2],best[3])
    # half widths: perpendicular distance from edge points to centreline, as function of t
    hw=[]
    for q in outer+inner:
        d,t=closest_t(q,S,Cc,W); hw.append((round(t,2),round(d,1)))
    hw.sort()
    print(side,'C',[round(v,1) for v in Cc],'W',[round(v,1) for v in W],'rms',round(math.sqrt(val/len(centres[::2])),2))
    # bucket widths
    for a in [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0]:
        b=[d for t,d in hw if a-0.05<=t<a+0.05]
        if b: print('   t=%.1f half-width %.1f (n=%d)'%(a,sum(b)/len(b),len(b)))
    res[side]=dict(S=S,C=Cc,W=W)
    pts=[bez(S,Cc,W,i/40) for i in range(41)]
    dr.line(pts,fill=(255,0,255),width=1)
    for q in outer: dr.point(q,fill=(0,160,255))
    for q in inner: dr.point(q,fill=(0,200,0))
json.dump(res,open('arms_centre.json','w'))
im.crop((470,360,940,580)).resize((940,440),Image.NEAREST).save(WORK + '/armfit.png')
