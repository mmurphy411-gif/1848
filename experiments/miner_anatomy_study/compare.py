"""Presentation boards only. Source images and Blender renders remain unretouched."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
OUT=Path(__file__).resolve().parent
font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',32)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
def board(view,filename):
    ims=[Image.open(OUT/(p+'_'+view+'.png')).convert('RGB') for p in ['baseline','textured']]
    w,h=ims[0].size
    img=Image.new('RGB',(w*2+48,h+146),'#eae7e0');draw=ImageDraw.Draw(img)
    for i,title in enumerate(['BEFORE / EXISTING ART MASTER','AFTER / ANATOMY + PROJECTED TEXTURES']):
        x=16+i*(w+16);draw.text((x,20),title,font=small,fill='#292824');img.paste(ims[i],(x,65))
    draw.text((18,h+88),'Same cameras, lighting and costume. Blender head study; game integration pending.',font=small,fill='#47433d')
    img.save(OUT/filename)
board('face_quarter','comparison.png')
board('full','full_comparison.png')
board('face_side','profile_comparison.png')
# Independent front / three-quarter / profile inspection, all from the saved 3D candidate.
sheet=Image.new('RGB',(1540,590),'#eae7e0');d=ImageDraw.Draw(sheet)
for i,view in enumerate(['face_front','face_quarter','face_side']):
    im=Image.open(OUT/('textured_'+view+'.png'));im.thumbnail((500,500),Image.Resampling.LANCZOS)
    x=10+i*510;d.text((x,14),view.replace('face_','').replace('_',' ').upper(),font=small,fill='#292824');sheet.paste(im,(x,55))
sheet.save(OUT/'turnaround.png')
