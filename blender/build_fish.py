"""Five readable river silhouettes, shared 1024 atlas, no skeletal animation."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
import numpy as np
reset()
out=ASSETS/'fish';out.mkdir(exist_ok=True)
n=1024
y,x=np.mgrid[0:n,0:n]/n
pixels=np.zeros((n,n,4),dtype=np.float32);pixels[:,:,3]=1
palettes=[(.40,.53,.45),(.40,.38,.28),(.34,.40,.23),(.53,.43,.25),(.42,.33,.22)]
for row,c in enumerate(palettes):
    mask=(y>=row/5)&(y<(row+1)/5);v=(y*5)%1
    belly=.45+.55*np.sin(v*np.pi)
    base=np.stack([belly*a for a in c],axis=2)
    if row==0:
        stripe=np.exp(-((v-.52)/.09)**2)*.4;base[:,:,0]+=stripe;base[:,:,1]-=stripe*.25
        spots=(np.sin(x*161+np.sin(v*83))*np.sin(v*191+np.sin(x*77))>.73)&(v>.35)
        base[spots]*=.28
    if row==4:base[:,:,0]+=.22*np.exp(-((v-.5)/.16)**2)
    scale=(.95+.05*np.sin(x*650+np.sin(v*370)))[:,:,None]
    pixels[mask,:3]=(base*scale)[mask]
im=bpy.data.images.new('River fish atlas',n,n);im.pixels.foreach_set(pixels.ravel());im.filepath_raw=str(out/'fish_atlas.png');im.file_format='PNG';im.save()
mat=material('River scales',(.5,.5,.5));p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.35;p.inputs['Metallic'].default_value=.18
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
for species,row,length,depth in [('trout',0,.36,.073),('sucker',1,.40,.085),('pikeminnow',2,.48,.065),('hardhead',3,.40,.085),('salmon',4,.85,.17)]:
    verts=[];faces=[];uv=[]
    for j in range(13):
        t=j/12;radius=max(.015,math.sin(math.pi*t)**.7)*(1-.35*t)
        for i in range(12):
            a=i*math.tau/12;verts.append(((t-.5)*length,math.cos(a)*depth*.48*radius,math.sin(a)*depth*radius));uv.append((t,(row+i/12*.98)/5))
    for j in range(12):
        for i in range(12):
            a=j*12+i;b=j*12+(i+1)%12;faces.append((a,b,b+12,a+12))
    for points in [[(.43,0,0),(.61,0,.15),(.56,0,0),(.61,0,-.15)], [(-.10,0,.08),(.13,0,.17),(.20,0,.05)], [(-.18,0,-.01),(-.02,.12,-.09),(.04,0,-.02)], [(-.18,0,-.01),(-.02,-.12,-.09),(.04,0,-.02)],[(.23,0,-.04),(.33,0,-.13),(.39,0,-.03)]]:
        start=len(verts)
        for px,py,pz in points:verts.append((px*length,py*length,pz*length));uv.append((px+.5,(row+.3)/5))
        faces.append(tuple(start+i for i in range(len(points))))
    obj=mesh_object(species,verts,faces,uv,materials=[mat]);objects=[obj]
    for sign in [-1,1]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=length*.011,location=(-length*.38,sign*depth*.25,depth*.23))
        eye=bpy.context.object;eye.data.materials.append(material('Eye',(.015,.017,.01)));objects.append(eye)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
for name in ['floating_bait','sunk_bait']:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.018)
    obj=bpy.context.object;obj.name=name;obj.scale=(1.6,.45,.6);obj.data.materials.append(material('Bait ochre',(.40,.23,.055)))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out/'fish.glb'),export_format='GLB',export_animations=False)
save('build_fish')
