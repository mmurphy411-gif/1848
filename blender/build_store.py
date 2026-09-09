"""Deterministic store kit; Blender coordinates are converted from Godot Y-up."""
import sys, math, random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from common import *
import numpy as np
from png_helpers import png
reset(); rng=random.Random(184810)
out=ASSETS/'store';out.mkdir(exist_ok=True)
# Seven material swatches in one atlas: three scales of wear and a cloth weave.
yy,xx=np.mgrid[:2048,:2048]; nr=np.random.default_rng(184810)
palette=np.array([[.72,.65,.48],[.23,.17,.10],[.38,.29,.17],[.09,.10,.10],[.55,.39,.14],[.84,.81,.67],[.07,.10,.105],[.48,.31,.16]])
slot=(xx//512)+(yy//1024)*4
grain=.035*np.sin(xx*.53)+.025*np.sin(xx*.047+np.sin(yy*.013))+.04*np.sin(xx*.006+yy*.003)+nr.normal(0,.013,xx.shape)
atlas=np.clip(palette[slot]+grain[:,:,None],0,1)
cloth=slot==0
atlas[cloth]*=(.96+.04*np.sin(xx[cloth]*math.pi/2)*np.sin(yy[cloth]*math.pi/2))[:,None]
png(out/'store_atlas.png',atlas*255)
mat=material('Store atlas',(.7,.6,.4));tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(out/'store_atlas.png'))
mat.node_tree.links.new(tex.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
mat.use_backface_culling=False
def uv_atlas(obj,slot):
    if not obj.data.uv_layers:obj.data.uv_layers.new()
    for poly in obj.data.polygons:
        axis=max(range(3),key=lambda a:abs(poly.normal[a]));axes=[a for a in range(3) if a!=axis]
        for li in poly.loop_indices:
            p=obj.data.vertices[obj.data.loops[li].vertex_index].co
            obj.data.uv_layers.active.data[li].uv=((slot%4+.06+.88*(p[axes[0]]%1))/4,1-(slot//4+.06+.88*(p[axes[1]]%1))/2)
    obj.data.materials.clear();obj.data.materials.append(mat)
    return obj
def coord(p):return (p[0],-p[2],p[1])
def cube(name,p,size,slot=2):
    bpy.ops.mesh.primitive_cube_add(size=1,location=coord(p));o=bpy.context.object;o.name=name;o.scale=coord((size[0],size[1],-size[2]));bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=o.modifiers.new('Worn corners','BEVEL');bevel.width=.008;bevel.segments=1;bpy.ops.object.modifier_apply(modifier=bevel.name)
    return uv_atlas(o,slot)
def cylinder(name,a,b,r,slot=1,vertices=10):
    a,b=Vector(coord(a)),Vector(coord(b));d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return uv_atlas(o,slot)
def export_set(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
    print(name,'TRIANGLES',sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects))
kit=[]
for i in range(7):
    kit.append(cylinder('Back log',( -2.5,.18+i*.25,-2.3),(2.5,.18+i*.25,-2.3),.14+rng.random()*.012))
# Side walls stop behind the working marks: the pour camera fits under the awning.
for x in [-2.6,2.6]:
    for i in range(6):kit.append(cylinder('Side log',(x,.16+i*.26,-2.3),(x,.16+i*.26,-1.25),.14))
    for z in [-2.3,1.0]:kit.append(cylinder('Roof post',(x,0,z),(x,2.85,z),.085))
kit.append(cylinder('Ridge',(0,3.4,-2.6),(0,3.4,1.3),.075))
for x in [-1.35,1.35]:kit.append(cube('Counter leg',(x,.48,0),(.14,.96,.64),1))
kit.append(cube('Counter',(0,1.0,0),(3.2,.13,.85)))
for y in [.4,1.15,1.88]:kit.append(cube('Shelf',(0,y,-1.8),(4.5,.085,.55)))
for x in [-2.15,2.15]:kit.append(cube('Shelf upright',(x,1.05,-1.9),(.1,2.2,.1),1))
for side in [-1,1]:
    v=[];f=[]
    for j in range(13):
        for i in range(13):
            x=side*i/12*2.82;z=-2.65+j/12*4.1;y=3.4-abs(x)*.23-.075*math.sin(j/12*math.pi)-.03*math.sin(i*1.1+j*.4)-.012*math.sin(i*3+j)
            v.append(coord((x,y,z)))
    for j in range(12):
        for i in range(12):
            k=j*13+i;f.append((k,k+1,k+14,k+13) if side<0 else (k+13,k+14,k+1,k))
    o=mesh_object('Canvas with sag',v,f);uv_atlas(o,0);kit.append(o)
kit.append(cube('Canvas sign',(0,2.96,1.06),(3.5,.25,.035),0))
kit.append(cube('Board',(-3.25,1.78,1.1),(1.05,1.85,.055),6))
kit.append(cube('Board bracket',(-2.95,1.12,1.06),(.7,.05,.07),3))
kit.append(cube('Slate',(1.2,1.38,.22),(.98,.68,.055),6))
kit.append(cube('Book',(.63,1.10,-.1),(.24,.06,.31),7))
kit.append(cylinder('Fish barrel',(2.45,.0,.6),(2.45,.85,.6),.38,2,16))
kit.append(cube('Fish plank',(2.45,.88,.6),(.92,.08,.7)))
kit.append(cube('Scale base',(-.95,1.10,0),(1.15,.06,.34),4))
kit.append(cylinder('Scale upright',(-.95,1.12,0),(-.95,1.63,0),.035,4))
for x in [-1.37,-.52]:
    kit.append(cylinder('Pan', (x,1.19,0),(x,1.22,0),.18,4,20))
    for dx in [-.11,.11]:kit.append(cylinder('Pan chain',(x+dx,1.22,0),(x,1.64,0),.007,3,6))
kit.append(cylinder('Beam',(-1.47,1.65,0),(-.42,1.65,0),.025,4))
for i in range(3):kit.append(cylinder('Weight',(-.42+i*.12,1.08,-.28),(-.42+i*.12,1.17,-.28),.045,4,8))
for x,z in [(-5,-1),(-5,4),(-5,7)]:kit.append(cylinder('Picket',(x,0,z),(x,1.1,z),.06))
kit.append(cylinder('Picket rope',(-5,.95,-1),(-5,.95,7),.012,7,6))
export_set('store',kit)
goods=[]
for name in ['flour','beans','coffee','salt','pork']:
    for fill in range(4):
        h=.16+fill*.10
        if name=='pork':o=cylinder(name+'_'+str(fill),(0,0,0),(0,h,0),.21,2,12)
        else:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1)
            o=bpy.context.object;o.name=name+'_'+str(fill);o.scale=(.2,.15,h*.5);o.location.z=h*.5;bpy.ops.object.transform_apply(location=True,rotation=False,scale=True);uv_atlas(o,0)
        goods.append(o)
goods.append(cube('hook',(0,.005,0),(.12,.01,.16),5))
bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,major_radius=.10,minor_radius=.014);o=bpy.context.object;o.name='line';goods.append(uv_atlas(o,7))
goods.append(cylinder('rod',(0,0,0),(.09,1.8,0),.014,2,7))
for name in ['crowbar','pick','shovel','spear','rifle']:
    o=cylinder(name,(0,0,0),(0,.64,0),.02,1,7)
    head=cube('head',(.01,.64,0),(.3,.055,.09) if name=='pick' else (.12,.15,.035),3)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);head.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.join();goods.append(o)
goods.append(cube('boots',(0,.12,0),(.22,.24,.3),7))
goods.append(cube('rocker',(0,.12,0),(.32,.24,.4),2))
goods.append(cylinder('powder',(0,0,0),(0,.32,0),.15,2,10))
goods.append(cylinder('tent',(-.2,.10,0),(.2,.10,0),.10,0,12))
export_set('goods',goods)
rod=next(o for o in goods if o.name=='rod');export(rod,'miner/rod.glb')
save('build_store')
