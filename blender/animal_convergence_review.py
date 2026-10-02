"""Pack real renders alongside unmodified reference crops; never synthesize art."""
import sys,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
species=sys.argv[1];stage=int(sys.argv[2]);out=ROOT/'artifacts'/f'{species}-convergence'
views=['front','side','back','three_quarter']
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
if species=='deer':
    ref=Image.open(next((ROOT/'characters/deer').glob('*(2).png')))
    crops=[(25,170,259,844),(262,170,803,844),(807,170,1019,844),(1040,170,1434,850)]
else:
    ref=Image.open(next((ROOT/'characters/rainbow trout').glob('*(2).png')))
    crops=[(60,288,285,580),(284,301,873,578),(895,278,1058,584),(1084,312,1420,574)]
# Coordinates were inspected against the supplied 1448 x 1086 image display.
crops=[tuple(round(c*(ref.width/1448)) for c in box) for box in crops]

def fitted(board,im,box,trim=False):
    im=im.convert('RGBA')
    if trim and im.getbbox():im=im.crop(im.getbbox())
    im.thumbnail((box[2],box[3]),Image.Resampling.LANCZOS)
    board.paste(im,(box[0]+(box[2]-im.width)//2,box[1]+(box[3]-im.height)//2),im)

b=Image.new('RGB',(1920,1260),'#e2dfd7');d=ImageDraw.Draw(b)
d.text((25,15),f'1848 / {species.upper()} / '+('BASELINE' if stage==0 else f'PASS {stage:02}'),font=font,fill='#29271f')
d.text((25,52),'Supplied turnaround above | Actual Blender geometry below | Panels fitted for comparison; source render cameras fixed',font=small,fill='#514b40')
for i,v in enumerate(views):
    d.text((i*480+20,88),v.replace('_',' ').upper(),font=small,fill='#514b40')
    fitted(b,ref.crop(crops[i]),(i*480+10,120,460,500))
    render_view='dorsal' if species=='trout' and v=='back' and (out/f'pass_{stage:02}_dorsal.png').exists() else v
    fitted(b,Image.open(out/f'pass_{stage:02}_{render_view}.png'),(i*480+12,650,456,500),True)
b.save(out/f'comparison_pass_{stage:02}.jpg',quality=94)
sil=Image.new('RGB',(1920,560),'#e2dfd7');d=ImageDraw.Draw(sil)
d.text((20,15),f'{species.upper()} / PASS {stage:02} / BLACK SILHOUETTES',font=font,fill='#29271f')
for i,v in enumerate(views):
    d.text((i*480+15,55),v.replace('_',' ').upper(),font=small,fill='#514b40')
    fitted(sil,Image.open(out/f'pass_{stage:02}_silhouette_{v}.png'),(i*480+5,88,470,470))
sil.save(out/f'silhouette_pass_{stage:02}.jpg',quality=94)
progress=Image.new('RGB',(1800,800),'#e2dfd7');d=ImageDraw.Draw(progress)
for i,(title,im,trim) in enumerate([
 ('ORIGINAL',Image.open(out/'pass_00_three_quarter.png'),True),
 (f'CURRENT / PASS {stage:02}',Image.open(out/f'pass_{stage:02}_three_quarter.png'),True),
 ('SUPPLIED TARGET',ref.crop(crops[3]),False)]):
    d.text((i*600+20,20),title,font=font,fill='#29271f');fitted(progress,im,(i*600+15,80,570,685),trim)
progress.save(out/'before_current_target.jpg',quality=94)
print('Built',species,stage)
