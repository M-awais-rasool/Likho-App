"""Step 0: copy the reference JPEGs the other scripts read into .work/ as PNG."""
from PIL import Image
from tracelib import MDIR, WORK

Image.open(MDIR + 'Gemini_Generated_Image_ic1bzvic1bzvic1b.jpeg').convert('RGB').save(WORK + '/master.png')
Image.open(MDIR + 'Gemini_Generated_Image_y5imh7y5imh7y5im.jpeg').convert('RGB').save(WORK + '/sheet.png')
print('ok')
