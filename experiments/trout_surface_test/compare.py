"""Assemble labeled evidence from real renders; no synthetic or retouched renders."""
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[1]
BG='#e8e5dd';INK='#252d2b';MUTED='#5c6560';ACCENT='#186957'
FONT='C:/Windows/Fonts/arial.ttf'
def font(size):return ImageFont.truetype(FONT,size)
def fitted(canvas,im,box):
    im=im.copy().convert('RGBA');im.thumbnail((box[2],box[3]),Image.Resampling.LANCZOS)
    canvas.paste(im,(round(box[0]+(box[2]-im.width)/2),round(box[1]+(box[3]-im.height)/2)),im)
def paired(view):
    ims=[Image.open(OUT/f'{label}_{view}.png').convert('RGBA') for label in ['baseline','candidate']]
    boxes=[im.getchannel('A').getbbox() for im in ims]
    box=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
    return [im.crop(box) for im in ims]

hero=Image.open(next((ROOT/'characters/rainbow trout').glob('*(1).png')))
turn=Image.open(next((ROOT/'characters/rainbow trout').glob('*(2).png')))
board=Image.new('RGB',(1800,1030),BG);d=ImageDraw.Draw(board)
d.text((32,22),'TROUT / ONE SURFACE TEST',font=font(35),fill=INK)
d.text((32,72),'Same geometry, pose, cameras and lights. Original concept pixels mapped onto the mesh.',font=font(23),fill=MUTED)
for col,title in enumerate(['CONCEPT ART','CURRENT MATERIAL','REFERENCE-PROJECTED MATERIAL']):
    d.text((col*600+28,130),title,font=font(23),fill=ACCENT if col==2 else INK)
for row,view,ref in [(0,'side',hero.crop((19,483,1065,894))),
                    (1,'three_quarter',turn.crop((1085,322,1418,560)))]:
    y=180+row*360
    d.text((30,y),view.replace('_',' ').upper(),font=font(18),fill=MUTED)
    fitted(board,ref,(18,y+40,565,290))
    for i,im in enumerate(paired(view)):fitted(board,im,(618+i*600,y+40,565,290))
d.line((32,925,1768,925),fill='#c4c8c0',width=2)
d.text((32,946),'Visible gain: cheek color, scales, stripe and fin detail. Limits: mouth registration, stretched back texture.',font=font(22),fill=INK)
d.text((32,980),'Concept panels fitted independently. Both render panels share a common crop and scale. Blender study; no game replacement.',font=font(19),fill=MUTED)
board.save(OUT/'comparison.png')

details=Image.new('RGB',(1600,1580),BG);d=ImageDraw.Draw(details)
d.text((30,20),'DIAGNOSTICS / KEEP THE FAILURES VISIBLE',font=font(30),fill=INK)
for i,t in enumerate(['CURRENT MATERIAL','REFERENCE-PROJECTED MATERIAL']):d.text((30+800*i,76),t,font=font(22),fill=INK)
for row,view in enumerate(['head','opposite','dorsal']):
    y=125+row*455
    d.text((30,y),view.upper(),font=font(20),fill=MUTED)
    for i,im in enumerate(paired(view)):fitted(details,im,(20+800*i,y+35,760,390))
d.text((30,1510),'Head: doubled contours and stretched throat. Dorsal: mirrored side projection stretches across the back.',font=font(21),fill=INK)
details.save(OUT/'diagnostics.png')

small=Image.new('RGB',(1200,520),BG);d=ImageDraw.Draw(small)
d.text((28,20),'SCREEN-SIZE CHECK / BLENDER PROXY',font=font(29),fill=INK)
d.text((28,65),'65 degree vertical FOV, 1080p, 0.40 m fish. Neutral background; no water or engine effects.',font=font(19),fill=MUTED)
for i,title in enumerate(['CURRENT','PROJECTED']):d.text((425+i*420,120),title,font=font(22),fill=INK)
for row,distance in enumerate([4.6,2.3]):
    width=round(.4*1080/(2*distance*math.tan(math.radians(65/2))))
    y=190+row*145
    d.text((30,y+10),f'{distance:.1f} m proxy / {width} pixels',font=font(22),fill=INK)
    for i,im in enumerate(paired('side')):
        im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS)
        small.paste(im,(470+i*420-width//2,y),im)
d.text((28,465),'Open at 100% to judge pixel size. Distances are assumed camera-to-fish distances, not live gameplay measurements.',font=font(18),fill=MUTED)
small.save(OUT/'screen_size.png')

check={}
for view in ['side','three_quarter','dorsal','opposite','head']:
    a=np.asarray(Image.open(OUT/f'baseline_{view}.png'))
    b=np.asarray(Image.open(OUT/f'candidate_{view}.png'))
    check[view]={'changed_alpha_pixels':int(np.count_nonzero(a[:,:,3]!=b[:,:,3])),
                 'changed_subject_rgb_pixels':int(np.count_nonzero(np.any(a[:,:,:3]!=b[:,:,:3],axis=2)&(a[:,:,3]>0)))}
(OUT/'pixel_check.json').write_text(json.dumps(check,indent=2))
print(json.dumps(check,indent=2))
