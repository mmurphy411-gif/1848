from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',23)
for view,name in [('torso','comparison.png'),('face_quarter','hair_comparison.png'),('full','full_comparison.png'),('back','back_comparison.png')]:
    ims=[Image.open(OUT/(p+'_'+view+'.png')).convert('RGB') for p in ['prior','refined']]
    w,h=ims[0].size;board=Image.new('RGB',(w*2+48,h+135),'#eae7e0');draw=ImageDraw.Draw(board)
    for i,title in enumerate(['PREVIOUS HEAD STUDY','REFINED HAIR AND COSTUME']):
        x=16+i*(w+16);draw.text((x,19),title,font=font,fill='#292824');board.paste(ims[i],(x,61))
    draw.text((18,h+87),'Matching Blender cameras and lighting. Original renders; game export pending.',font=font,fill='#47433d')
    board.save(OUT/name)
