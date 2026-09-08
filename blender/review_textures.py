"""Diagnostic 3x3 repeats and numerical edge checks; writes only ignored artifacts."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
import numpy as np
for name in ['granite','talus','gravel','sand','duff','bedrock']:
    for suffix in ['albedo','normal','orm']:
        im=bpy.data.images.load(str(ASSETS/'textures'/f'{name}_{suffix}.png'))
        w,h=im.size
        pixels=np.empty(w*h*4,dtype=np.float32); im.pixels.foreach_get(pixels)
        rgb=pixels.reshape(h,w,4)[:,:,:3]
        edge=(np.abs(rgb[0]-rgb[-1]).mean()+np.abs(rgb[:,0]-rgb[:,-1]).mean())*.5
        interior=(np.abs(np.diff(rgb,axis=0)).mean()+np.abs(np.diff(rgb,axis=1)).mean())*.5
        ratio=float(edge/max(interior,1e-6))
        print('SEAM',name,suffix,round(ratio,3),'PASS' if ratio<1.6 else 'FAIL')
        assert ratio<1.6
        if suffix=='albedo':
            im.scale(384,384)
            p=np.empty(384*384*4,dtype=np.float32); im.pixels.foreach_get(p)
            tiled=np.tile(p.reshape(384,384,4),(3,3,1))
            out=bpy.data.images.new(name+' 3x3 repeat',1152,1152,alpha=False)
            out.pixels.foreach_set(tiled.ravel()); out.filepath_raw=str(ROOT/'artifacts'/f'tile-{name}.png'); out.file_format='PNG'; out.save()
