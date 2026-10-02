"""Compare retained refinement to first projection, at common crops and scales."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parent;PREVIOUS=OUT.parent
BG='#e8e5dd';INK='#29352f';FONT='C:/Windows/Fonts/arial.ttf'
def font(n):return ImageFont.truetype(FONT,n)
def pair(view):
    ims=[Image.open(PREVIOUS/f'candidate_{view}.png').convert('RGBA'),
         Image.open(OUT/f'refined_{view}.png').convert('RGBA')]
    boxes=[im.getchannel('A').getbbox() for im in ims]
    box=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
    return [im.crop(box) for im in ims]
def fitted(board,im,x,y,w,h):
    im=im.copy();im.thumbnail((w,h),Image.Resampling.LANCZOS)
    board.paste(im,(round(x+(w-im.width)/2),round(y+(h-im.height)/2)),im)

board=Image.new('RGB',(1600,1410),BG);d=ImageDraw.Draw(board)
d.text((30,20),'TROUT / MOUTH AND BACK REFINEMENT',font=font(32),fill=INK)
d.text((30,69),'Geometry, original UVs, cameras and lighting preserved. Actual Blender renders.',font=font(21),fill=INK)
for i,label in enumerate(['FIRST PROJECTION','RETAINED REFINEMENT']):d.text((30+i*800,115),label,font=font(25),fill=INK)
for view,y,h,label in [('three_quarter',175,315,'THREE QUARTER'),('head',540,490,'HEAD'),('dorsal',1090,200,'BACK / rotated for display')]:
    d.text((30,y-20),label,font=font(19),fill=INK)
    for i,im in enumerate(pair(view)):
        if view=='dorsal':im=im.transpose(Image.Transpose.ROTATE_90)
        fitted(board,im,20+i*800,y+12,760,h)
d.text((30,1340),'Retained: cleaner mouth, smoother throat, unstretched crown spots. Remaining: simplified jaw and eye anatomy.',font=font(21),fill=INK)
d.text((30,1374),'Back uses a spatial spot shader after two image projections failed; cheek and flank retain concept detail.',font=font(20),fill=INK)
board.save(OUT/'comparison.png')

check={}
for view in ['side','three_quarter','head','dorsal','opposite']:
    a=np.asarray(Image.open(PREVIOUS/f'candidate_{view}.png'))
    b=np.asarray(Image.open(OUT/f'refined_{view}.png'))
    check[view]={'changed_alpha_pixels':int(np.count_nonzero(a[:,:,3]!=b[:,:,3]))}
assert all(v['changed_alpha_pixels']==0 for v in check.values())
(OUT/'pixel_check.json').write_text(json.dumps(check,indent=2))
print(json.dumps(check))
