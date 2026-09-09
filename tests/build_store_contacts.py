"""Contact sheets from actual Godot captures; never substitutes for frame review."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'artifacts'
def sheet(paths, name, columns=3):
    width, height = 576, 354
    page = Image.new('RGB', (columns*width, ((len(paths)+columns-1)//columns)*height), '#201f1b')
    draw = ImageDraw.Draw(page)
    for i, path in enumerate(paths):
        with Image.open(path) as source:
            thumbnail = source.convert('RGB').resize((576,324))
        x,y=(i%columns)*width,(i//columns)*height
        page.paste(thumbnail,(x,y));draw.text((x+8,y+332),path.stem,fill='#efe6d0')
    page.save(ROOT/name)

sheet(sorted(ROOT.glob('milestone-10-*.png')), 'milestone-10-contact.png')
for directory in ['store-sequence','trip-sequence']:
    paths=sorted((ROOT/directory).glob('frame-*.png'))
    if paths:
        selected=[paths[round(i*(len(paths)-1)/11)] for i in range(12)]
        sheet(selected,directory+'-sheet.png')
