"""Compose reference and loadout review boards from the saved, unchanged renders."""
from pathlib import Path
import json,sys
from PIL import Image,ImageDraw,ImageFont,ImageChops,ImageStat
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'artifacts/miner-convergence'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
views=['front','side','back','three_quarter']
reference=Image.open(ROOT/'characters/miner/ChatGPT Image Sep 9, 2026, 08_30_08 PM (1).png')
crops=[(0,122,435,969),(440,122,731,969),(735,122,1075,969),(1078,122,1448,969)]
def fit(board,im,box):
    x,y,w,h=box;im=im.convert('RGB');im.thumbnail((w,h),Image.Resampling.LANCZOS);board.paste(im,(x+(w-im.width)//2,y+(h-im.height)//2))
latest=int(sys.argv[1]) if len(sys.argv)>1 else 8
for stage in ([latest] if latest>8 else [6,7,8]):
    board=Image.new('RGB',(1760,1750),'#dedbd4');d=ImageDraw.Draw(board)
    d.text((20,15),f'1848 / PASS {stage} — CORE CHARACTER AND DETACHABLE EQUIPMENT',font=font,fill='#29241e')
    for i,view in enumerate(views):d.text((i*440+15,55),view.replace('_',' ').upper(),font=small,fill='#514a40')
    for row,label in enumerate(['PRIMARY TURNAROUND — silhouette, proportions and placement','BASE CLOTHING — no pack, hip equipment or carried tools','EXPEDITION — complete equipment assembly']):
        y=90+row*550;d.text((20,y),label,font=small,fill='#514a40')
        for i,view in enumerate(views):
            if row==0:im=reference.crop(crops[i])
            else:im=Image.open(OUT/f'pass_{stage:02}_{"base" if row==1 else "expedition"}_{view}.png').crop((25,58,625,842))
            fit(board,im,(i*440+8,y+32,424,510))
    board.save(OUT/f'loadout_comparison_pass_{stage:02}.jpg',quality=94)
    board=Image.new('RGB',(1600,1190),'#dedbd4');d=ImageDraw.Draw(board)
    d.text((20,15),f'PASS {stage} / BLACK SILHOUETTES',font=font,fill='#29241e')
    for row,kit in enumerate(['base','expedition']):
        y=60+row*555;d.text((20,y),kit.upper(),font=small,fill='#514a40')
        for i,view in enumerate(views):fit(board,Image.open(OUT/f'pass_{stage:02}_{kit}_silhouette_{view}.png'),(i*400+5,y+28,390,510))
    board.save(OUT/f'loadout_silhouettes_pass_{stage:02}.jpg',quality=93)
if not (OUT/f'pass_{latest:02}_field_three_quarter.png').exists():
    print(f'Created structural pass {latest} reference and silhouette boards.');sys.exit(0)
board=Image.new('RGB',(1560,800),'#dedbd4');d=ImageDraw.Draw(board)
for i,(kit,title) in enumerate([('base','BASE CLOTHING'),('field','LIGHT FIELD KIT'),('expedition','FULL EXPEDITION KIT')]):
    d.text((i*520+22,22),title,font=font,fill='#29241e')
    fit(board,Image.open(OUT/f'pass_{latest:02}_{kit}_three_quarter.png').crop((25,58,625,842)),(i*520+8,78,504,680))
board.save(OUT/'current_loadouts.jpg',quality=95)
board=Image.new('RGB',(1040,780),'#dedbd4');d=ImageDraw.Draw(board)
for i,(stage,title) in enumerate([(50,'BEFORE / GEAR REMOVED'),(latest,f'PASS {latest} / GEAR REMOVED')]):
    d.text((i*520+18,20),title,font=font,fill='#29241e')
    fit(board,Image.open(OUT/f'pass_{stage:02}_base_three_quarter.png').crop((25,58,625,842)),(i*520+8,75,504,680))
board.save(OUT/'core_character_progress.jpg',quality=94)
qa={}
for kit in ['base','expedition']:
    for view in views:
        a=Image.open(OUT/f'pass_{latest:02}_{kit}_{view}.png').convert('RGB')
        packaged=OUT/f'pass_{latest*10:02}_{kit}_{view}.png' if latest>=9 else OUT/f'pass_08_packaged_{kit}_{view}.png'
        if not packaged.exists():packaged=OUT/f'pass_09_{kit}_{view}.png'
        b=Image.open(packaged).convert('RGB')
        qa[kit+'_'+view]=ImageStat.Stat(ImageChops.difference(a,b)).mean
(OUT/'loadout_packaging_render_check.json').write_text(json.dumps(qa,indent=2))
(OUT/f'pass_{latest:02}_packaging_render_check.json').write_text(json.dumps(qa,indent=2))
if latest==9:
    board=Image.new('RGB',(1600,1180),'#dedbd4');d=ImageDraw.Draw(board)
    d.text((22,15),'PASS 8 TO PASS 9 / SAME CAMERAS AND LIGHTING',font=font,fill='#29241e')
    for row,(label,suffix) in enumerate([('BASE CHARACTER','base_three_quarter'),('FACE STRUCTURE','face')]):
        for i,stage in enumerate([8,9]):
            d.text((i*800+22,55+row*555),f'PASS {stage} / {label}',font=small,fill='#514a40')
            fit(board,Image.open(OUT/f'pass_{stage:02}_{suffix}.png'),(i*800+15,85+row*555,770,510))
    board.save(OUT/'pass_09_before_after.jpg',quality=94)
print(f'Created pass {latest} comparison boards and packaging check.')
if latest>9:
    board=Image.new('RGB',(1560,1500),'#dedbd4');d=ImageDraw.Draw(board)
    for row,kit in enumerate(['base','expedition']):
        for i,stage in enumerate([9,13,latest]):
            title=f'PASS {stage} / {kit.upper()}'
            d.text((i*520+18,row*750+20),title,font=font,fill='#29241e')
            fit(board,Image.open(OUT/f'pass_{stage:02}_{kit}_three_quarter.png').crop((25,58,625,842)),(i*520+8,row*750+65,504,675))
    board.save(OUT/f'pass_{latest:02}_progress.jpg',quality=95)
