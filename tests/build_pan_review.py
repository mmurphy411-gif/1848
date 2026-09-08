"""Build ordered contact sheets and 12 fps previews from the recorded frames."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

root=Path(__file__).resolve().parents[1]/'artifacts'
angles=sys.argv[1:] or ['player','side','front']
assert set(angles)<= {'player','side','front'},angles
for angle in angles:
    directory=root/('pan-sequence' if angle=='player' else 'pan-sequence-'+angle)
    manifest=json.loads((directory/'manifest.json').read_text())
    if angle!='front':assert len(manifest)==144,(angle,len(manifest))
    frames=[]
    for entry in manifest:
        im=Image.open(directory/f'frame-{entry["frame"]:03}.png').convert('RGB')
        assert im.size==(1920,1080)
        if angle!='front':assert abs(entry['time']-(entry['frame']+1)/12)<.035,entry
        frames.append(im)
    for start in range(0,len(frames),24):
        sheet=Image.new('RGB',(1920,6*296),(24,24,24))
        draw=ImageDraw.Draw(sheet)
        for k,im in enumerate(frames[start:start+24]):
            entry=manifest[start+k];x=(k%4)*480;y=(k//4)*296
            small=im.resize((480,270),Image.Resampling.LANCZOS)
            sheet.paste(small,(x,y+26))
            draw.text((x+8,y+6),f'{entry["frame"]:03}  {entry["time"]:05.2f}s  {entry["segment"]}',fill='white')
        sheet.save(root/f'notes-6-{angle}-contact-{start//24+1:02}.png')
    previews=[im.resize((960,540),Image.Resampling.LANCZOS) for im in frames]
    previews[0].save(root/f'notes-6-{angle}-preview.webp',save_all=True,append_images=previews[1:],duration=[83,83,84]*(len(previews)//3)+[83]*(len(previews)%3),loop=0,quality=84,method=4)
    print(angle,len(frames),'frames; contact sheets and preview written')
