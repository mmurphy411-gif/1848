"""Camp props, arranged at runtime on the original oak clearing."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
import numpy as np
reset()
out=ASSETS/'camp';out.mkdir(exist_ok=True)
n=2048
y,x=np.mgrid[0:n,0:n]/n
noise=np.random.default_rng(184809).random((n,n))
value=.75+.035*np.sin(x*950)*np.sin(y*1030)+.05*noise+.03*np.sin(x*19+y*3)
pix=np.stack([value*.86,value*.78,value*.60,np.ones_like(value)],axis=2).astype(np.float32)
im=bpy.data.images.new('Camp canvas and paper',n,n);im.pixels.foreach_set(pix.ravel());im.filepath_raw=str(out/'camp_atlas.png');im.file_format='PNG';im.save()
canvas=material('Weathered canvas',(.72,.65,.48));tex=canvas.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;canvas.node_tree.links.new(tex.outputs['Color'],canvas.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
wood=material('Driftwood',(.25,.16,.085));iron=material('Iron',(.055,.052,.046));rock=material('River granite',(.37,.39,.38));wool=material('Blanket',(.24,.26,.20))
def cube(name,pos,scale,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return o
def pole(a,b,r=.04,mat=wood):
    a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r,depth=(b-a).length,location=(a+b)*.5)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat);return o
def group(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return objects[0]
objs=[pole((-1,0,0),(-1,0,1.65)),pole((1,0,0),(1,0,1.65)),pole((-1,0,1.65),(1,0,1.65))]
v=[];f=[]
for i in range(13):
    for j in range(9):
        u=i/12;t=j/8;v.append((-1.1+u*2.2,t*1.8,1.65-t*1.30-.08*math.sin(u*math.pi)+.025*math.sin(u*math.pi*9)))
for i in range(12):
    for j in range(8):
        a=i*9+j;f.append((a,a+9,a+10,a+1))
objs.append(mesh_object('Canvas',v,f,[(i/12,j/8) for i in range(13) for j in range(9)],materials=[canvas]));group('LeanTo',objs)
group('Bedroll',[cube('Wool roll',(0,0,.07),(.7,1.65,.14),wool),pole((-.35,.7,.19),(.35,.7,.19),.15,wool)])
objs=[]
for i in range(13):
    a=i*math.tau/13;r=.55+.03*math.sin(i*4)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(math.cos(a)*r,math.sin(a)*r,.08))
    o=bpy.context.object;o.scale=(.17+.03*math.sin(i),.13,.11);o.data.materials.append(rock)
    for p in o.data.polygons:p.use_smooth=True
    objs.append(o)
group('FireRing',objs)
objs=[pole((-.28,0,0),(0,0,.85),.015,iron),pole((.28,0,0),(0,0,.85),.015,iron),pole((0,.3,0),(0,0,.85),.015,iron)]
bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.18,depth=.20,location=(0,0,.40));o=bpy.context.object;o.data.materials.append(iron);objs.append(o)
group('Pot',objs)
bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.19,depth=.045,location=(0,0,.04));o=bpy.context.object;o.data.materials.append(iron)
group('Skillet',[o,pole((.15,0,.045),(.48,0,.045),.022,iron)])
group('Rack',[pole((-.6,0,0),(-.6,0,1.3)),pole((.6,0,0),(.6,0,1.3)),pole((-.68,0,1.2),(.68,0,1.2))])
group('Crate',[cube('Crate',(0,0,.22),(.65,.48,.44),wood),cube('Ledger',(0,0,.46),(.28,.36,.04),canvas)])
bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=(0,0,-.25));o=bpy.context.object;o.scale=(.24,.18,.38);o.data.materials.append(canvas)
group('Cache',[o,pole((0,0,0),(0,0,.8),.012,wood)])
group('Driftwood',[pole((-.35,-.15+i*.09,.08),( .35,.02+i*.08,.1),.045) for i in range(4)])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out/'camp.glb'),export_format='GLB',export_animations=False)
save('build_camp')
reset()
o=group('Handline',[cube('Spindle',(0,0,0),(.13,.026,.035),wood),cube('End',(-.065,0,0),(.025,.07,.025),wood),cube('End',(.065,0,0),(.025,.07,.025),wood),cube('Coil',(0,0,0),(.075,.04,.045),canvas)])
export(o,'miner/handline.glb');save('build_handline')
