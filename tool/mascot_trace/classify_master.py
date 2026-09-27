import pickle, sys, time
from tracelib import *
from PIL import Image
im, px = load(WORK + '/master.png')
PAL = {
 'bg':['#FFFFFF','#FCFCFC'], 'shadow':'#E5E5EB',
 'er_fill':['#FC999C','#FE9DA0'], 'er_shade':['#F2828A','#EF7D85'], 'er_line':['#CD6067','#D0666A'],
 'band':'#CBD3DC', 'band_hi':'#E8EEF6', 'band_sh':'#B6C1CC', 'band_line':'#8898A6',
 'body':'#FEC344', 'body_l':'#FBD065', 'body_d':'#F5AA36', 'body_line':'#C27A28',
 'cone_l':'#F4CA98', 'cone_m':'#ECB57D', 'cone_d':'#DB9A67', 'cone_line':'#BC7540',
 'graph':'#323447', 'brow':'#9B5618', 'cheek':'#F78A5C', 'mouth':'#6E3227',
}
t=time.time()
C = Classifier(px, (470, 80, 940, 700), PAL)
print('classified in', round(time.time()-t,1),'s')
pickle.dump(C, open('master_cls.pkl','wb'))
vis = Image.new('RGB', (C.w, C.h))
cols = {n: hexrgb(v if isinstance(v,str) else v[0]) for n,v in PAL.items()}
vp = vis.load()
for j,row in enumerate(C.lab):
    for i,v in enumerate(row): vp[i,j] = cols[C.names[v]]
vis.save(WORK + '/master_labels.png')
