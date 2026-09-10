"""Assemble comparison boards from unaltered Blender renders and supplied references."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageStat

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/miner-convergence'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
reference=Image.open(ROOT/'characters/miner/ChatGPT Image Sep 9, 2026, 08_30_08 PM (1).png').convert('RGB')
views=['front','side','back','three_quarter']
crops=[(0,122,435,969),(440,122,731,969),(735,122,1075,969),(1078,122,1448,969)]

def fitted(board,im,box):
    x,y,w,h=box;im=im.copy();im.thumbnail((w,h),Image.Resampling.LANCZOS)
    board.paste(im,(x+(w-im.width)//2,y+(h-im.height)//2))

for stage in range(6):
    board=Image.new('RGB',(2080,1340),'#dedbd4');draw=ImageDraw.Draw(board)
    draw.text((28,16),f'1848 — REFERENCE CONVERGENCE / '+('BASELINE' if stage==0 else f'PASS {stage}'),font=font,fill='#24211c')
    draw.text((28,55),'PRIMARY turnaround above · neutral orthographic Blender renders below · intermediate asset',font=small,fill='#514a40')
    for i,(view,crop) in enumerate(zip(views,crops)):
        x=i*520
        draw.text((x+18,89),view.replace('_',' ').upper(),font=small,fill='#514a40')
        fitted(board,reference.crop(crop),(x+8,118,504,580))
        im=Image.open(OUT/f'pass_{stage:02}_{view}.png').convert('RGB').crop((0,58,650,842))
        fitted(board,im,(x+8,716,504,598))
    board.save(OUT/f'comparison_pass_{stage:02}.jpg',quality=93)
    if stage:
        sil=Image.new('RGB',(1600,620),'#dedbd4');d=ImageDraw.Draw(sil)
        d.text((20,15),f'PASS {stage} / BLACK SILHOUETTE CHECK',font=font,fill='#24211c')
        for i,view in enumerate(views):
            d.text((i*400+15,53),view.replace('_',' ').upper(),font=small,fill='#514a40')
            fitted(sil,Image.open(OUT/f'pass_{stage:02}_silhouette_{view}.png'),(i*400+5,83,390,530))
        sil.save(OUT/f'silhouette_pass_{stage:02}.jpg',quality=93)

board=Image.new('RGB',(1560,750),'#dedbd4');d=ImageDraw.Draw(board)
for i,(title,path) in enumerate([('ORIGINAL SCENE',OUT/'pass_00_three_quarter.png'),('CURRENT WORKING ASSET',OUT/'pass_06_three_quarter.png'),('PRIMARY TARGET',None)]):
    d.text((i*520+20,20),title,font=font,fill='#24211c')
    if path:im=Image.open(path).crop((25,58,625,842))
    else:im=reference.crop(crops[3])
    fitted(board,im,(i*520+8,80,504,630))
board.save(OUT/'before_current_target.jpg',quality=94)

qa={}
for view in views:
    a=Image.open(OUT/f'pass_05_{view}.png').convert('RGB');b=Image.open(OUT/f'pass_06_{view}.png').convert('RGB')
    qa[view]={'mean_absolute_difference_0_255':ImageStat.Stat(ImageChops.difference(a,b)).mean}
(OUT/'packaging_render_check.json').write_text(json.dumps(qa,indent=2))
print('Wrote six primary-reference boards, five silhouette boards, before/current/target and packaging verification.')
