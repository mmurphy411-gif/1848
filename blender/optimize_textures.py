"""Final bake packing. Run with Python + Pillow after the Blender builders.
Palette PNG keeps the requested pixel dimensions and 8-bit samples while
bounding the palette to 256 colors. Flat ORM maps remain grayscale R8.
The CC0 scan sets from build_textures.py are skipped: photographic albedo bands
visibly at 256 colours and normal maps lose precision, so they stay 8-bit RGB.
"""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SCAN_SETS=('gravel_','sand_','granite_','talus_','duff_','bedrock_','soil_')
for folder in ['textures','miner']:
    for path in (ROOT/'assets'/folder).glob('*.png'):
        if path.name.startswith('miner_') or path.name == 'pan_pan_scuffs.png':continue
        if folder=='textures' and path.name.startswith(SCAN_SETS):continue
        im=Image.open(path)
        if im.mode in ['P','L']:continue
        packed=im.quantize(colors=256,method=Image.Quantize.FASTOCTREE if im.mode=='RGBA' else Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
        packed.save(path,optimize=True)
        print(path.relative_to(ROOT),path.stat().st_size)
