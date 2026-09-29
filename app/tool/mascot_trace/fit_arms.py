import pickle, math, json, random
C = pickle.load(open('master_cls.pkl','rb'))
lab=lambda x,y: C.names[C.lab[y-C.y0][x-C.x0]]
FAM=set(C.names)-{'bg','shadow','band_hi'}
def edges(side):
    outer=[];inner=[]
    for y in range(384, 494):
        if side=='L':
            xs=[x for x in range(480,576) if lab(x,y) in FAM]
            if not xs: continue
            # contiguous run touching the body edge? take the leftmost run
            runs=[];s=xs[0];p=xs[0]
            for x in xs[1:]:
                if x!=p+1: runs.append((s,p)); s=x
                p=x
            runs.append((s,p))
            a,b=runs[0]
            outer.append((a,y+0.5))
            if b<572: inner.append((b+1,y+0.5))
        else:
            xs=[x for x in range(832,930) if lab(x,y) in FAM]
            if not xs: continue
            runs=[];s=xs[0];p=xs[0]
            for x in xs[1:]:
                if x!=p+1: runs.append((s,p)); s=x
                p=x
            runs.append((s,p))
            a,b=runs[-1]
            outer.append((b+1,y+0.5))
            if a>835: inner.append((a,y+0.5))
    return outer, inner
def bez(S,Cc,W,t):
    u=1-t; return (u*u*S[0]+2*u*t*Cc[0]+t*t*W[0], u*u*S[1]+2*u*t*Cc[1]+t*t*W[1])
def dbez(S,Cc,W,t):
    u=1-t; return (2*u*(Cc[0]-S[0])+2*t*(W[0]-Cc[0]), 2*u*(Cc[1]-S[1])+2*t*(W[1]-Cc[1]))
def offset_curves(p, sign):
    S=(p[0],p[1]);Cc=(p[2],p[3]);W=(p[4],p[5]);h0,h1,hm=p[6],p[7],p[8]
    L=[];R=[]
    for i in range(61):
        t=i/60; x,y=bez(S,Cc,W,t); dx,dy=dbez(S,Cc,W,t); n=math.hypot(dx,dy) or 1e-9
        nx,ny=-dy/n,dx/n   # left normal
        h = (h0*(1-t)**2 + 2*hm*t*(1-t) + h1*t*t)
        L.append((x+nx*h,y+ny*h)); R.append((x-nx*h,y-ny*h))
    return L,R
def dist_to_poly(pt, poly):
    best=1e9
    for a,b in zip(poly,poly[1:]):
        vx,vy=b[0]-a[0],b[1]-a[1]; wx,wy=pt[0]-a[0],pt[1]-a[1]
        t=max(0,min(1,(vx*wx+vy*wy)/((vx*vx+vy*vy) or 1e-9)))
        d=math.hypot(wx-t*vx,wy-t*vy); best=min(best,d)
    return best
def cost(p, outer, inner, side):
    L,R = offset_curves(p, 1)
    # for left arm (going down-left), walking S->W, the outer (left of screen) edge is on the ... pick by x
    A,B = (R,L) if side=='L' else (L,R)
    c=sum(dist_to_poly(q,A)**2 for q in outer)+sum(dist_to_poly(q,B)**2 for q in inner)
    return c
def nm(f, x0, step, iters=3000):
    n=len(x0); pts=[x0[:]]
    for i in range(n):
        v=x0[:]; v[i]+=step[i]; pts.append(v)
    vals=[f(v) for v in pts]
    for it in range(iters):
        order=sorted(range(n+1),key=lambda i:vals[i]); pts=[pts[i] for i in order]; vals=[vals[i] for i in order]
        c=[sum(p[i] for p in pts[:-1])/n for i in range(n)]
        xr=[c[i]+(c[i]-pts[-1][i]) for i in range(n)]; fr=f(xr)
        if fr<vals[0]:
            xe=[c[i]+2*(c[i]-pts[-1][i]) for i in range(n)]; fe=f(xe)
            pts[-1],vals[-1]=(xe,fe) if fe<fr else (xr,fr)
        elif fr<vals[-2]: pts[-1],vals[-1]=xr,fr
        else:
            xc=[c[i]+0.5*(pts[-1][i]-c[i]) for i in range(n)]; fc=f(xc)
            if fc<vals[-1]: pts[-1],vals[-1]=xc,fc
            else:
                for j in range(1,n+1):
                    pts[j]=[pts[0][i]+0.5*(pts[j][i]-pts[0][i]) for i in range(n)]; vals[j]=f(pts[j])
    i=min(range(n+1),key=lambda i:vals[i]); return pts[i],vals[i]
res={}
for side in 'LR':
    outer,inner=edges(side)
    if side=='L': x0=[592,398, 540,450, 524,494, 22,20,19]
    else: x0=[816,398, 868,450, 884,494, 22,20,19]
    # shoulder pivot fixed-ish inside the body: optimise all but keep S x inside body via penalty
    def f(p):
        pen = 0
        if side=='L' and p[0] < 584: pen += (584-p[0])**2*50
        if side=='R' and p[0] > 824: pen += (p[0]-824)**2*50
        return cost(p,outer,inner,side)+pen
    best,val=nm(f,x0,[6,6,8,8,4,4,2,2,2],2500)
    rms=math.sqrt(val/(len(outer)+len(inner)))
    print(side, [round(v,1) for v in best], 'rms', round(rms,2), 'n', len(outer), len(inner))
    res[side]=best
json.dump(res, open('arms_fit.json','w'))
